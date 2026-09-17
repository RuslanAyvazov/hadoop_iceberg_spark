#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[ozone-init] %s\n' "$*"
}

for _ in {1..120}; do
  if ozone sh volume list / >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

ozone sh volume list / >/dev/null

if ! ozone sh volume info /spark >/dev/null 2>&1; then
  log "Creating volume /spark"
  ozone sh volume create /spark
fi

if ! ozone sh bucket info /spark/warehouse >/dev/null 2>&1; then
  log "Creating FSO bucket /spark/warehouse"
  ozone sh bucket create /spark/warehouse --layout fso
fi

if ! ozone sh bucket info /spark/data >/dev/null 2>&1; then
  log "Creating FSO bucket /spark/data"
  ozone sh bucket create /spark/data --layout fso
fi

if ! ozone sh volume info /s3v >/dev/null 2>&1; then
  log "Creating S3 volume /s3v"
  ozone sh volume create /s3v
fi

if ! ozone sh bucket info /s3v/s3-demo >/dev/null 2>&1; then
  log "Creating S3 bucket /s3v/s3-demo"
  ozone sh bucket create /s3v/s3-demo --layout obs
fi

printf 'ozone cluster is writable\n' >/tmp/ozone-cluster-ready.txt
for _ in {1..120}; do
  rm -f /tmp/ozone-cluster-readback.txt
  ozone sh key delete /spark/data/cluster-ready.txt >/dev/null 2>&1 || true
  if ozone sh key put -t RATIS -r ONE /spark/data/cluster-ready.txt /tmp/ozone-cluster-ready.txt >/dev/null 2>&1 \
      && ozone sh key get /spark/data/cluster-ready.txt /tmp/ozone-cluster-readback.txt >/dev/null 2>&1 \
      && [[ "$(cat /tmp/ozone-cluster-readback.txt)" == "ozone cluster is writable" ]]; then
    ozone sh key delete /spark/data/cluster-ready.txt >/dev/null 2>&1 || true
    break
  fi
  sleep 1
done

test -f /tmp/ozone-cluster-readback.txt
[[ "$(cat /tmp/ozone-cluster-readback.txt)" == "ozone cluster is writable" ]]

log "Ozone learning volumes and buckets are ready"
