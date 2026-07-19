#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose=(docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml")

printf '\n=== YARN nodes ===\n'
"${compose[@]}" exec -T resourcemanager yarn node -list -states RUNNING

printf '\n=== Spark SQL / Iceberg through JDBC ===\n'
"${compose[@]}" exec -T thriftserver \
  /opt/spark/bin/beeline \
  -u "jdbc:hive2://localhost:10000/default;auth=noSasl" \
  -n hive \
  -f /opt/bigdata/tests/smoke-test.sql

printf '\n=== HDFS replication ===\n'
"${compose[@]}" exec -T namenode \
  hdfs fsck /warehouse/compose_smoke.db/iceberg_test -files -blocks -locations

