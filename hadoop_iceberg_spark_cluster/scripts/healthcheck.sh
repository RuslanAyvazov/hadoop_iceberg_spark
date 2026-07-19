#!/usr/bin/env bash
set -euo pipefail

check_port() {
  local host="$1"
  local port="$2"
  timeout 2 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

check_listen_port() {
  local port="$1"
  local port_hex
  printf -v port_hex '%04X' "${port}"
  awk -v suffix=":${port_hex}" \
    '$2 ~ suffix "$" && $4 == "0A" { found=1 } END { exit !found }' \
    /proc/net/tcp /proc/net/tcp6
}

case "${SERVICE_ROLE:-unset}" in
  namenode)
    check_port 127.0.0.1 9820
    check_port 127.0.0.1 9870
    ;;
  secondarynamenode)
    check_port 127.0.0.1 9868
    ;;
  worker)
    check_port 127.0.0.1 9866
    check_port 127.0.0.1 8042
    ;;
  resourcemanager)
    check_port 127.0.0.1 8032
    check_port 127.0.0.1 8088
    ;;
  metastore)
    check_port 127.0.0.1 9083
    ;;
  thriftserver)
    check_listen_port 10000
    ;;
  historyserver)
    check_port 127.0.0.1 18080
    ;;
  *)
    exit 1
    ;;
esac
