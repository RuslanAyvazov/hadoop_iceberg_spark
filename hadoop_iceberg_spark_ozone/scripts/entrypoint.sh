#!/usr/bin/env bash
set -Eeuo pipefail

SPARK_PID=""
CLEANING_UP=0

if (( $# > 0 )); then
  exec "$@"
fi

log() {
  printf '[spark-ozone] %s\n' "$*"
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

  log "Stopped"
  exit "${exit_code}"
}

trap cleanup EXIT TERM INT

mkdir -p /data/spark/local-warehouse "${SPARK_HOME}/logs"

log "Waiting for Ozone Manager"
wait_for_port om 9862 120 || {
  log "Ozone Manager did not open RPC port 9862"
  exit 1
}

log "Starting Spark Thrift Server"
spark_args=(
  --class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2
  --name "Spark SQL on Apache Ozone"
  --master "local[*]"
  --driver-memory "${SPARK_DRIVER_MEMORY:-2g}"
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
  tail -n 160 "${SPARK_HOME}/logs/thriftserver.out" || true
  exit 1
}

log "Ready: JDBC jdbc:hive2://localhost:10000/default;auth=noSasl"
log "Iceberg warehouse: ofs://om/spark/warehouse"
log "Spark UI: http://localhost:4040"

while true; do
  if ! kill -0 "${SPARK_PID}" 2>/dev/null; then
    log "Spark Thrift Server exited unexpectedly"
    tail -n 160 "${SPARK_HOME}/logs/thriftserver.out" || true
    exit 1
  fi
  sleep 5
done
