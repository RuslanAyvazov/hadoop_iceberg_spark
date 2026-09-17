#!/usr/bin/env bash
set -Eeuo pipefail

timeout 3 bash -c '</dev/tcp/localhost/10000'
