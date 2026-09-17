$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ComposeFile = Join-Path $ProjectDir "compose.yaml"

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T spark /opt/spark/bin/beeline `
    -u "jdbc:hive2://localhost:10000/default;auth=noSasl" `
    -n hive `
    -f /opt/lab/tests/smoke-test.sql

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T spark `
    /opt/spark/bin/spark-submit /opt/lab/examples/ozone_dataframe.py

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T om `
    ozone sh key list /spark/data

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T ozone-ui `
    python3 -c 'import json, urllib.request; req=urllib.request.Request("http://localhost:8090/api/preview", data=json.dumps({"path":"ofs://om/spark/data/users-parquet","format":"parquet","limit":10}).encode(), headers={"Content-Type":"application/json"}); r=json.load(urllib.request.urlopen(req, timeout=30)); assert len(r["rows"]) == 3; print("OZONE_EXPLORER_OK", r["command"], "rows=3")'

exit $LASTEXITCODE
