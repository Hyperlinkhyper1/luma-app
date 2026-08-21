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
#
# Files on the shared volume, all of them read by Api._adminDeployStatus:
#   deploy.request  the container asking for a deploy (deleted when claimed)
#   deploy.pid      present only while a deploy is running
#   deploy.log      output of the run in progress, or the last one
#   deploy.status   exit code of the last finished run ("0" = success)
#   deploy.watcher  heartbeat; its mtime proves this script is alive
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="/opt/luma-sync-data"
REQUEST_FILE="$DATA_DIR/deploy.request"
LOG_FILE="$DATA_DIR/deploy.log"
PID_FILE="$DATA_DIR/deploy.pid"
STATUS_FILE="$DATA_DIR/deploy.status"
HEARTBEAT_FILE="$DATA_DIR/deploy.watcher"

# Read LUMA_REPO_PATH from server/.env rather than hardcoding it, so this
# can never drift from the same value the container's gate check
# (Api._adminDeploy, via config.repoPathConfigured) is enforcing.
REPO_PATH="$(grep -m1 '^LUMA_REPO_PATH=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2-)"
if [ -z "$REPO_PATH" ]; then
  echo "[deploy-watcher] LUMA_REPO_PATH is not set in $SCRIPT_DIR/.env — exiting." >&2
  exit 1
fi

step() {
  echo
  echo "==> $*"
}

# A deploy can update this script itself, but the running copy keeps
# executing the old file (git swaps the inode, so the open fd survives).
# Comparing the checksum before and after tells us when to re-exec.
script_hash() {
  cksum "$SCRIPT_DIR/deploy-watcher.sh" 2>/dev/null | cut -d' ' -f1,2
}

deploy() {
  cd "$REPO_PATH" || {
    echo "LUMA_REPO_PATH ($REPO_PATH) is not a directory on this host."
    return 1
  }

  git config --global --add safe.directory "$REPO_PATH" >/dev/null 2>&1

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    branch="master"
  fi

  step "Fetching origin/$branch"
  git fetch --prune origin "$branch" || return 1

  # This checkout is a deploy target, not a workspace. A hand-edit to a
  # tracked file (docker-compose.yml, most often) makes `git pull` abort
  # with "Your local changes to the following files would be overwritten by
  # merge", which wedges the button permanently: every later deploy hits the
  # same wall. Park such edits in a stash instead — recoverable with
  # `git stash list` / `git stash show -p stash@{0}` — and carry on.
  if ! git diff --quiet HEAD --; then
    step "Local changes to tracked files — stashing them first"
    git status --short
    git stash push -m "deploy-watcher auto-stash $(date -Is)" ||
      return 1
    echo "Recover them later with: git -C $REPO_PATH stash list"
  fi

  step "Updating to origin/$branch"
  git reset --hard "origin/$branch" || return 1

  step "Rebuilding and restarting luma-sync"
  cd server || return 1
  docker compose up -d --build luma-sync || return 1
}

# systemd restarts this script on failure; a deploy.pid left behind by a
# killed run would otherwise make the button answer "a deploy is already in
# progress" forever.
rm -f "$PID_FILE"

SELF_HASH="$(script_hash)"
beat=0
while true; do
  # Heartbeat every ~10s. Api._adminDeployStatus reports the button as
  # unbacked when this file goes stale, so a stopped watcher says so
  # instead of the deploy just quietly never happening.
  if [ "$beat" -le 0 ]; then
    : 2>/dev/null > "$HEARTBEAT_FILE" || true
    beat=5
  fi
  beat=$((beat - 1))

  if [ -f "$REQUEST_FILE" ]; then
    rm -f "$REQUEST_FILE" "$STATUS_FILE"
    echo $$ > "$PID_FILE"
    ( deploy ) > "$LOG_FILE" 2>&1
    code=$?
    if [ "$code" -eq 0 ]; then
      echo "==> Deploy finished successfully." >> "$LOG_FILE"
    else
      echo "==> Deploy FAILED (exit $code) — nothing was restarted." >> "$LOG_FILE"
    fi
    echo "$code" > "$STATUS_FILE"
    rm -f "$PID_FILE"
    beat=0

    # The deploy just shipped a new version of this script — swap onto it
    # now rather than waiting for someone to remember to restart the
    # service. systemd keeps tracking the same PID across the exec, and if
    # the new copy is broken, Restart=always brings it back.
    if [ "$code" -eq 0 ] && [ "$(script_hash)" != "$SELF_HASH" ]; then
      echo "==> deploy-watcher.sh itself was updated — reloading it." \
        >> "$LOG_FILE"
      exec "$SCRIPT_DIR/deploy-watcher.sh"
    fi
  fi
  sleep 2
done
