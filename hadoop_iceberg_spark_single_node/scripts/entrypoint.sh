#!/usr/bin/env bash
set -Eeuo pipefail

export HADOOP_CLIENT_OPTS="${HADOOP_OPTS:-} --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.security.action=ALL-UNNAMED"

SPARK_PID=""
HMS_PID=""
CLEANING_UP=0

log() {
  printf '[bigdata] %s\n' "$*"
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

cleanup() {
  local exit_code=$?

  if (( CLEANING_UP == 1 )); then
    return
  fi
  CLEANING_UP=1
  trap - EXIT TERM INT
  set +e

  log "Stopping Spark Thrift Server"
  if [[ -n "${SPARK_PID}" ]] && kill -0 "${SPARK_PID}" 2>/dev/null; then
    kill -TERM "${SPARK_PID}" 2>/dev/null
    for _ in {1..30}; do
      kill -0 "${SPARK_PID}" 2>/dev/null || break
      sleep 1
    done
    kill -KILL "${SPARK_PID}" 2>/dev/null || true
    wait "${SPARK_PID}" 2>/dev/null || true
  fi

  log "Stopping Hive Metastore"
  if [[ -n "${HMS_PID}" ]] && kill -0 "${HMS_PID}" 2>/dev/null; then
    kill -TERM "${HMS_PID}" 2>/dev/null
    wait "${HMS_PID}" 2>/dev/null || true
  fi

  log "Stopping HDFS"
  "${HADOOP_HOME}/bin/hdfs" --daemon stop secondarynamenode >/dev/null 2>&1 || true
  "${HADOOP_HOME}/bin/hdfs" --daemon stop datanode >/dev/null 2>&1 || true
  "${HADOOP_HOME}/bin/hdfs" --daemon stop namenode >/dev/null 2>&1 || true

  log "Stopped"
  exit "${exit_code}"
}

trap cleanup EXIT TERM INT

mkdir -p /data/hdfs/namenode /data/hdfs/datanode /data/hdfs/namesecondary /data/hadoop-tmp "${HADOOP_LOG_DIR}" "${HIVE_HOME}/logs" "${SPARK_HOME}/logs" /opt/bigdata/logs "${HADOOP_PID_DIR}"

envsubst < /opt/bigdata/templates/hive-site.xml.template > "${HIVE_HOME}/conf/hive-site.xml"

if [[ ! -f /data/hdfs/namenode/current/VERSION ]]; then
  log "Formatting a new HDFS NameNode"
  "${HADOOP_HOME}/bin/hdfs" namenode -format -clusterId hadoop-iceberg-spark-single-node -force -nonInteractive
fi

log "Starting HDFS"
"${HADOOP_HOME}/bin/hdfs" --daemon start namenode
wait_for_port localhost 9820 60 || {
  log "NameNode did not open port 9820"
  exit 1
}

"${HADOOP_HOME}/bin/hdfs" --daemon start datanode
"${HADOOP_HOME}/bin/hdfs" --daemon start secondarynamenode

timeout 90 "${HADOOP_HOME}/bin/hdfs" dfsadmin -safemode wait >/dev/null
"${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p /tmp /warehouse
"${HADOOP_HOME}/bin/hdfs" dfs -chmod 1777 /tmp
"${HADOOP_HOME}/bin/hdfs" dfs -chmod 777 /warehouse

log "Waiting for PostgreSQL"
wait_for_port "${POSTGRES_HOST}" "${POSTGRES_PORT}" 60 || {
  log "PostgreSQL is not reachable"
  exit 1
}

if ! "${HIVE_HOME}/bin/schematool" -dbType postgres -info >/opt/bigdata/logs/schematool-info.log 2>&1; then
  log "Initializing the Hive Metastore schema"
  "${HIVE_HOME}/bin/schematool" -dbType postgres -initSchema >/opt/bigdata/logs/schematool-init.log 2>&1
fi

log "Starting Hive Metastore"
"${HIVE_HOME}/bin/hive" --service metastore --hiveconf hive.metastore.port=9083 --hiveconf hive.metastore.bind.host=0.0.0.0 >"${HIVE_HOME}/logs/metastore.out" 2>&1 &
HMS_PID=$!

wait_for_port localhost 9083 60 || {
  log "Hive Metastore did not open port 9083"
  tail -n 100 "${HIVE_HOME}/logs/metastore.out" || true
  exit 1
}

log "Starting Spark Thrift Server"
spark_args=(
  --class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2
  --name "Thrift JDBC/ODBC Server"
  --master "local[*]"
  --driver-memory "${SPARK_DRIVER_MEMORY:-2g}"
  --jars "${SPARK_HOME}/extra-jars/iceberg-spark-runtime-3.5_2.12-1.6.1.jar,${SPARK_HOME}/extra-jars/iceberg-hive-runtime-1.6.1.jar"
  --conf "spark.driver.extraClassPath=${SPARK_HOME}/extra-jars/iceberg-spark-runtime-3.5_2.12-1.6.1.jar:${SPARK_HOME}/extra-jars/iceberg-hive-runtime-1.6.1.jar"
  --conf "spark.executor.extraClassPath=${SPARK_HOME}/extra-jars/iceberg-spark-runtime-3.5_2.12-1.6.1.jar:${SPARK_HOME}/extra-jars/iceberg-hive-runtime-1.6.1.jar"
  spark-internal
  --hiveconf hive.server2.authentication=NOSASL
  --hiveconf hive.server2.transport.mode=binary
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0
  --hiveconf hive.server2.thrift.port=10000
)

"${SPARK_HOME}/bin/spark-submit" "${spark_args[@]}" >"${SPARK_HOME}/logs/thriftserver.out" 2>&1 &
SPARK_PID=$!

wait_for_port localhost 10000 120 || {
  log "Spark Thrift Server did not open port 10000"
  tail -n 120 "${SPARK_HOME}/logs/thriftserver.out" || true
  exit 1
}

log "Ready: JDBC jdbc:hive2://localhost:10000/default;auth=noSasl"
log "NameNode UI: http://localhost:9870"
log "Spark UI: http://localhost:4040"

while true; do
  if ! kill -0 "${HMS_PID}" 2>/dev/null; then
    log "Hive Metastore exited unexpectedly"
    exit 1
  fi
  if ! kill -0 "${SPARK_PID}" 2>/dev/null; then
    log "Spark Thrift Server exited unexpectedly"
    exit 1
  fi
  sleep 5
done
