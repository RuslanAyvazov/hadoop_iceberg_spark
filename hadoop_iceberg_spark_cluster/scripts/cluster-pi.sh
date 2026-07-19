#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose --project-directory "${project_dir}" -f "${project_dir}/compose.yaml" exec -T thriftserver \
  /opt/spark/bin/spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --name "Cluster mode SparkPi" \
  --driver-memory 512m \
  --executor-memory 512m \
  --executor-cores 1 \
  --num-executors 1 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.4.jar \
  20

