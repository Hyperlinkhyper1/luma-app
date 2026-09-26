#!/usr/bin/env bash
# Pulls the latest code and rebuilds the api container. Runs on the host,
# never inside a container: the systemd path unit that
# install-deploy-watcher.sh sets up starts it whenever the admin panel's
# "Rebuild api" button drops deploy/request. The request file's contents are
# never read, so nothing the container writes can change what runs here.
set -uo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
mkdir -p deploy
rm -f deploy/request

log=deploy/last.log
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)

write_status() {
  printf '{"state":"%s","startedAt":"%s","finishedAt":%s,"commit":"%s"}\n' \
    "$1" "$started" "$2" "$(git rev-parse --short HEAD 2>/dev/null)" > deploy/status.json.tmp
  mv deploy/status.json.tmp deploy/status.json
}

write_status running null
{
  echo "== $started git pull --ff-only"
  git pull --ff-only &&
    echo "== docker compose up -d --build api" &&
    docker compose up -d --build api
} > "$log" 2>&1
code=$?

finished="\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
if [ "$code" -eq 0 ]; then
  write_status success "$finished"
else
  write_status failed "$finished"
fi
exit "$code"
