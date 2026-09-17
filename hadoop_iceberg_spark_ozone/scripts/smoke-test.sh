#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T spark /opt/spark/bin/beeline \
  -u 'jdbc:hive2://localhost:10000/default;auth=noSasl' \
  -n hive \
  -f /opt/lab/tests/smoke-test.sql

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T spark /opt/spark/bin/spark-submit /opt/lab/examples/ozone_dataframe.py

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T om ozone sh key list /spark/data

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T ozone-ui python3 -c \
  'import json, urllib.request; req=urllib.request.Request("http://localhost:8090/api/preview", data=json.dumps({"path":"ofs://om/spark/data/users-parquet","format":"parquet","limit":10}).encode(), headers={"Content-Type":"application/json"}); r=json.load(urllib.request.urlopen(req, timeout=30)); assert len(r["rows"]) == 3; print("OZONE_EXPLORER_OK", r["command"], "rows=3")'
