#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T jupyter python3 -m nbconvert \
  --execute \
  --to notebook \
  --ExecutePreprocessor.timeout=240 \
  --output-dir=/tmp \
  --output=scala-ozone-smoke.ipynb \
  /home/bigdata/work/01_spark_scala_ozone.ipynb

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T jupyter python3 -c \
  'import json; n=json.load(open("/tmp/scala-ozone-smoke.ipynb", encoding="utf-8")); outputs=[o.get("text", "") for c in n["cells"] for o in c.get("outputs", []) if o.get("output_type") == "stream"]; text="".join("".join(x) if isinstance(x, list) else x for x in outputs); assert "SCALA_OZONE_OK rows=3" in text; print("JUPYTER_SCALA_OZONE_OK")'

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" \
  exec -T om ozone sh key list /spark/data
