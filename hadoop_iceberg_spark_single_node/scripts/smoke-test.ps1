$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

docker compose --project-directory $ProjectDir -f (Join-Path $ProjectDir "compose.yaml") exec -T bigdata /opt/spark/bin/beeline -u "jdbc:hive2://localhost:10000/default;auth=noSasl" -n hive -f /opt/bigdata/tests/smoke-test.sql

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
