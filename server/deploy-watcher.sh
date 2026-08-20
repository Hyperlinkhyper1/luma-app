#!/usr/bin/env bash
# Runs on the host, outside Docker. The admin dashboard's "Update & restart
# server" button can't run `docker compose up -d --build luma-sync` from
# inside the luma-sync container itself: that command tears its own
# container down partway through, killing the very process orchestrating
# the multi-step recreate (stop old -> rename -> create new -> start new ->
# remove old) before it reaches "start new". The result is a container
# stuck at "Created" and the deploy silently going nowhere.
#
# Instead, the container just drops a request file on the shared data
# volume; this script (running as a systemd service directly on the host)
# picks it up and does the actual git pull + rebuild from outside the
# container's blast radius, so it survives the recreate.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="/opt/luma-sync-data"
REQUEST_FILE="$DATA_DIR/deploy.request"
LOG_FILE="$DATA_DIR/deploy.log"
PID_FILE="$DATA_DIR/deploy.pid"

# Read LUMA_REPO_PATH from server/.env rather than hardcoding it, so this
# can never drift from the same value the container's gate check
# (Api._adminDeploy, via config.repoPathConfigured) is enforcing.
REPO_PATH="$(grep -m1 '^LUMA_REPO_PATH=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2-)"
if [ -z "$REPO_PATH" ]; then
  echo "[deploy-watcher] LUMA_REPO_PATH is not set in $SCRIPT_DIR/.env — exiting." >&2
  exit 1
fi

while true; do
  if [ -f "$REQUEST_FILE" ]; then
    rm -f "$REQUEST_FILE"
    echo $$ > "$PID_FILE"
    {
      git config --global --add safe.directory "$REPO_PATH" &&
      cd "$REPO_PATH" && git pull && cd server &&
      docker compose up -d --build luma-sync
    } > "$LOG_FILE" 2>&1
    rm -f "$PID_FILE"
  fi
  sleep 2
done
