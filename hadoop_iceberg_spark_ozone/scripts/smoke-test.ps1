$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ComposeFile = Join-Path $ProjectDir "compose.yaml"

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T jupyter `
    python3 -m nbconvert `
    --execute `
    --to notebook `
    --ExecutePreprocessor.timeout=240 `
    --output-dir=/tmp `
    --output=scala-ozone-smoke.ipynb `
    /home/bigdata/work/01_spark_scala_ozone.ipynb

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T jupyter `
    python3 -c 'import json; n=json.load(open("/tmp/scala-ozone-smoke.ipynb", encoding="utf-8")); outputs=[o.get("text", "") for c in n["cells"] for o in c.get("outputs", []) if o.get("output_type") == "stream"]; text="".join("".join(x) if isinstance(x, list) else x for x in outputs); assert "SCALA_OZONE_OK rows=3" in text; print("JUPYTER_SCALA_OZONE_OK")'

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker compose --project-directory $ProjectDir -f $ComposeFile exec -T om `
    ozone sh key list /spark/data

exit $LASTEXITCODE
