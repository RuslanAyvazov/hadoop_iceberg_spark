#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import json
from urllib.request import urlopen

with urlopen("http://localhost:8090/api/health", timeout=4) as response:
    payload = json.load(response)

if payload.get("status") != "ok" or not payload.get("spark"):
    raise SystemExit(1)
PY
