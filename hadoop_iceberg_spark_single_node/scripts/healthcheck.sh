#!/usr/bin/env bash
set -euo pipefail

for port in 9820 9083 10000; do
  timeout 1 bash -c "</dev/tcp/127.0.0.1/${port}" >/dev/null 2>&1
done
