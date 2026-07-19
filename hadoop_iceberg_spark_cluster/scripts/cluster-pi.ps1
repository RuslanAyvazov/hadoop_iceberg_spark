$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ComposeFile = Join-Path $ProjectDir "compose.yaml"

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T thriftserver /opt/spark/bin/spark-submit `
    --master yarn `
    --deploy-mode cluster `
    --name "Cluster mode SparkPi" `
    --driver-memory 512m `
    --executor-memory 512m `
    --executor-cores 1 `
    --num-executors 1 `
    --class org.apache.spark.examples.SparkPi `
    /opt/spark/examples/jars/spark-examples_2.12-3.5.4.jar `
    20

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

