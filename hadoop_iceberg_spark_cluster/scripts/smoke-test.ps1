$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ComposeFile = Join-Path $ProjectDir "compose.yaml"

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T resourcemanager yarn node -list -states RUNNING
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T thriftserver /opt/spark/bin/beeline -u "jdbc:hive2://localhost:10000/default;auth=noSasl" -n hive -f /opt/bigdata/tests/smoke-test.sql
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T namenode hdfs fsck /warehouse/compose_smoke.db/iceberg_test -files -blocks -locations
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

