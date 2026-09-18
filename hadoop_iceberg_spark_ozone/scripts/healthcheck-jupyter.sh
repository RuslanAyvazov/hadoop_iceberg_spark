#!/usr/bin/env bash
set -Eeuo pipefail

curl --fail --silent --show-error --max-time 3 http://localhost:8888/api >/dev/null
