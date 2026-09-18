#!/usr/bin/env bash
set -Eeuo pipefail

work_dir=/home/bigdata/work
app_dir="${JUPYTERLAB_DIR:-/opt/jupyter/share/jupyter/lab}"
mkdir -p "${work_dir}"

if [[ ! -e "${work_dir}/01_spark_scala_ozone.ipynb" ]]; then
  cp /opt/lab/notebooks/01_spark_scala_ozone.ipynb "${work_dir}/"
fi

exec python3 -m jupyterlab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --LabApp.app_dir="${app_dir}" \
  --MappingKernelManager.default_kernel_name=apache_toree_scala \
  --ServerApp.root_dir="${work_dir}" \
  --ServerApp.allow_remote_access=true \
  --ServerApp.password='' \
  --IdentityProvider.token="${JUPYTER_TOKEN:-}"
