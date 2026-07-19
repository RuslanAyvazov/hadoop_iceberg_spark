#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" exec -T bigdata /opt/spark/bin/beeline -u "jdbc:hive2://localhost:10000/default;auth=noSasl" -n hive -f /opt/bigdata/tests/smoke-test.sql
