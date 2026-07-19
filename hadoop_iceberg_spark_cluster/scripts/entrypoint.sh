#!/usr/bin/env bash
set -Eeuo pipefail

export HADOOP_CLIENT_OPTS="${HADOOP_OPTS:-} --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.security.action=ALL-UNNAMED"

ROLE="${SERVICE_ROLE:-unset}"
CHILD_PIDS=()
CLEANING_UP=0

log() {
  printf '[%s] %s\n' "${ROLE}" "$*"
}

wait_for_port() {
  local host="$1"
  local port="$2"
  local timeout_seconds="${3:-60}"
  local elapsed=0

  while (( elapsed < timeout_seconds )); do
    if timeout 1 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

wait_for_listen_port() {
  local port="$1"
  local timeout_seconds="${2:-60}"
  local elapsed=0
  local port_hex
  printf -v port_hex '%04X' "${port}"

  while (( elapsed < timeout_seconds )); do
    if awk -v suffix=":${port_hex}" \
      '$2 ~ suffix "$" && $4 == "0A" { found=1 } END { exit !found }' \
      /proc/net/tcp /proc/net/tcp6; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

wait_for_datanodes() {
  local required="${1:-3}"
  local timeout_seconds="${2:-180}"
  local elapsed=0
  local count=0

  while (( elapsed < timeout_seconds )); do
    count=$(hdfs dfsadmin -report 2>/dev/null | awk -F'[()]' '/Live datanodes/ {print $2; exit}')
    count="${count:-0}"
    if (( count >= required )); then
      log "HDFS has ${count} live DataNodes"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  log "Expected ${required} live DataNodes, found ${count}"
  return 1
}

wait_for_nodemanagers() {
  local required="${1:-3}"
  local timeout_seconds="${2:-180}"
  local elapsed=0
  local count=0

  while (( elapsed < timeout_seconds )); do
    count=$(yarn node -list -states RUNNING 2>/dev/null | awk -F: '/Total Nodes:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
    count="${count:-0}"
    if (( count >= required )); then
      log "YARN has ${count} running NodeManagers"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  log "Expected ${required} running NodeManagers, found ${count}"
  return 1
}

cleanup_children() {
  local exit_code=$?

  if (( CLEANING_UP == 1 )); then
    return
  fi
  CLEANING_UP=1
  trap - EXIT TERM INT
  set +e

  for pid in "${CHILD_PIDS[@]}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill -TERM "${pid}" 2>/dev/null || true
    fi
  done

  for _ in {1..30}; do
    local any_running=0
    for pid in "${CHILD_PIDS[@]}"; do
      if kill -0 "${pid}" 2>/dev/null; then
        any_running=1
      fi
    done
    (( any_running == 0 )) && break
    sleep 1
  done

  for pid in "${CHILD_PIDS[@]}"; do
    kill -KILL "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done

  log "Stopped"
  exit "${exit_code}"
}

monitor_children() {
  while true; do
    for pid in "${CHILD_PIDS[@]}"; do
      if ! kill -0 "${pid}" 2>/dev/null; then
        log "A managed process exited unexpectedly"
        return 1
      fi
    done
    sleep 5
  done
}

prepare_data_dirs() {
  mkdir -p \
    /data/hdfs/namenode \
    /data/hdfs/datanode \
    /data/hdfs/namesecondary \
    /data/yarn/local \
    /data/yarn/logs \
    /data/hadoop-tmp \
    "${HADOOP_LOG_DIR}" \
    "${HIVE_HOME}/logs" \
    "${SPARK_HOME}/logs" \
    /opt/bigdata/logs \
    "${HADOOP_PID_DIR}"
}

start_namenode() {
  if [[ ! -f /data/hdfs/namenode/current/VERSION ]]; then
    log "Formatting a new HDFS NameNode"
    hdfs namenode -format -clusterId hadoop-iceberg-spark-cluster -force -nonInteractive
  fi

  log "Starting HDFS NameNode"
  exec hdfs namenode
}

start_secondarynamenode() {
  log "Waiting for HDFS NameNode"
  wait_for_port namenode 9820 90
  log "Starting HDFS SecondaryNameNode"
  exec hdfs secondarynamenode
}

start_worker() {
  log "Waiting for HDFS NameNode"
  wait_for_port namenode 9820 90

  trap cleanup_children EXIT TERM INT

  log "Starting HDFS DataNode"
  hdfs datanode &
  CHILD_PIDS+=("$!")

  log "Waiting for YARN ResourceManager"
  wait_for_port resourcemanager 8032 180

  log "Starting YARN NodeManager"
  yarn nodemanager &
  CHILD_PIDS+=("$!")

  wait_for_port 127.0.0.1 9866 90
  wait_for_port 127.0.0.1 8042 90
  log "Ready: DataNode and NodeManager are running"
  monitor_children
}

start_resourcemanager() {
  log "Waiting for HDFS NameNode"
  wait_for_port namenode 9820 90
  log "Starting YARN ResourceManager"
  exec yarn resourcemanager
}

initialize_hdfs() {
  wait_for_port namenode 9820 90
  wait_for_datanodes 3 180
  timeout 90 hdfs dfsadmin -safemode wait >/dev/null

  hdfs dfs -mkdir -p /tmp /tmp/logs /user/bigdata /warehouse /spark-history
  hdfs dfs -chmod 1777 /tmp
  hdfs dfs -chmod 777 /warehouse /spark-history
}

start_metastore() {
  : "${POSTGRES_HOST:?POSTGRES_HOST is required}"
  : "${POSTGRES_PORT:?POSTGRES_PORT is required}"
  : "${POSTGRES_DB:?POSTGRES_DB is required}"
  : "${POSTGRES_USER:?POSTGRES_USER is required}"
  : "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

  envsubst < /opt/bigdata/templates/hive-site.xml.template > "${HIVE_HOME}/conf/hive-site.xml"

  log "Initializing HDFS directories"
  initialize_hdfs

  log "Waiting for PostgreSQL"
  wait_for_port "${POSTGRES_HOST}" "${POSTGRES_PORT}" 90

  if ! "${HIVE_HOME}/bin/schematool" -dbType postgres -info >/opt/bigdata/logs/schematool-info.log 2>&1; then
    log "Initializing the Hive Metastore schema"
    "${HIVE_HOME}/bin/schematool" -dbType postgres -initSchema >/opt/bigdata/logs/schematool-init.log 2>&1
  fi

  log "Starting Hive Metastore"
  exec "${HIVE_HOME}/bin/hive" --service metastore \
    --hiveconf hive.metastore.port=9083 \
    --hiveconf hive.metastore.bind.host=0.0.0.0
}

start_thriftserver() {
  log "Waiting for Hive Metastore and YARN"
  wait_for_port metastore 9083 120
  wait_for_port resourcemanager 8032 120
  wait_for_nodemanagers 3 180

  trap cleanup_children EXIT TERM INT

  local iceberg_spark_jar="${SPARK_HOME}/extra-jars/iceberg-spark-runtime-3.5_2.12-1.6.1.jar"
  local iceberg_hive_jar="${SPARK_HOME}/extra-jars/iceberg-hive-runtime-1.6.1.jar"

  log "Starting Spark Thrift Server on YARN in client deploy mode"
  "${SPARK_HOME}/bin/spark-submit" \
    --class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2 \
    --name "Spark Thrift JDBC/ODBC Server" \
    --master yarn \
    --deploy-mode client \
    --driver-memory "${SPARK_DRIVER_MEMORY:-1g}" \
    --executor-memory "${SPARK_EXECUTOR_MEMORY:-512m}" \
    --executor-cores "${SPARK_EXECUTOR_CORES:-1}" \
    --num-executors "${SPARK_EXECUTOR_INSTANCES:-3}" \
    --jars "${iceberg_spark_jar},${iceberg_hive_jar}" \
    --conf spark.driver.host=thriftserver \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.driver.port=35000 \
    --conf spark.blockManager.port=35001 \
    --conf "spark.driver.extraClassPath=${iceberg_spark_jar}:${iceberg_hive_jar}" \
    --conf "spark.executor.extraClassPath=${iceberg_spark_jar}:${iceberg_hive_jar}" \
    spark-internal \
    --hiveconf hive.server2.authentication=NOSASL \
    --hiveconf hive.server2.transport.mode=binary \
    --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
    --hiveconf hive.server2.thrift.port=10000 &
  CHILD_PIDS+=("$!")

  if ! wait_for_listen_port 10000 240; then
    log "Spark Thrift Server did not open port 10000"
    return 1
  fi

  log "Ready: JDBC jdbc:hive2://localhost:10000/default;auth=noSasl"
  log "Spark UI: http://localhost:4040"
  monitor_children
}

start_historyserver() {
  log "Waiting for Spark event log directory"
  wait_for_port namenode 9820 90
  until hdfs dfs -test -d /spark-history >/dev/null 2>&1; do
    sleep 2
  done

  export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=18080 -Dspark.history.fs.logDirectory=hdfs://namenode:9820/spark-history"
  log "Starting Spark History Server"
  exec "${SPARK_HOME}/bin/spark-class" org.apache.spark.deploy.history.HistoryServer
}

prepare_data_dirs

case "${ROLE}" in
  namenode)
    start_namenode
    ;;
  secondarynamenode)
    start_secondarynamenode
    ;;
  worker)
    start_worker
    ;;
  resourcemanager)
    start_resourcemanager
    ;;
  metastore)
    start_metastore
    ;;
  thriftserver)
    start_thriftserver
    ;;
  historyserver)
    start_historyserver
    ;;
  *)
    log "Unknown SERVICE_ROLE: ${ROLE}"
    exit 64
    ;;
esac
