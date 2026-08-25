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
# Files on the shared volume, all of them read by DeployConsole.status():
#   deploy.request  the container asking for a deploy (deleted when claimed)
#   deploy.log      output of the run in progress, or the last one
#   deploy.status   exit code of the last finished run ("0" = success)
#   deploy.lock     present and freshly touched while a deploy is running
#   deploy.watcher  heartbeat; its mtime proves this script is alive
#
# This script owns every one of those except deploy.request. The container
# only ever asks; it never clears the log or the status, so there is no
# window where a request is pending and the previous run's artifacts have
# already been wiped — a state that read as "finished instantly".
#
# deploy.lock and deploy.watcher are both *freshness* signals, not mere
# presence: a background refresher (see refresher_start) re-touches them
# every few seconds for the whole duration of a deploy. Writing them once
# and walking away made any deploy longer than the container's staleness
# window report itself as dead while it was still going.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="/opt/luma-sync-data"
REQUEST_FILE="$DATA_DIR/deploy.request"
LOG_FILE="$DATA_DIR/deploy.log"
LOCK_FILE="$DATA_DIR/deploy.lock"
STATUS_FILE="$DATA_DIR/deploy.status"
HEARTBEAT_FILE="$DATA_DIR/deploy.watcher"

# "Check for updates" button (system_updates.dart / UpdateCheckConsole) — a
# read-only sibling of the deploy request above, handled in the same loop so
# it shares the heartbeat file. It never touches deploy.lock: a check and a
# deploy can't collide since neither takes long enough to overlap in
# practice, and keeping them on separate lock files means a check in flight
# never makes the deploy button report "already running".
UPDATE_REQUEST_FILE="$DATA_DIR/update-check.request"
UPDATE_LOG_FILE="$DATA_DIR/update-check.log"
UPDATE_LOCK_FILE="$DATA_DIR/update-check.lock"
UPDATE_DONE_FILE="$DATA_DIR/update-check.done"

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

touch_files() {
  : 2>/dev/null > "$LOCK_FILE" || true
  : 2>/dev/null > "$HEARTBEAT_FILE" || true
}

# A deploy runs synchronously in the main loop below, so nothing there can
# keep the freshness files current while `docker compose build` takes its
# several minutes. This subshell does it instead, and is killed the moment
# the deploy returns.
REFRESHER_PID=""
refresher_start() {
  ( while :; do touch_files; sleep 5; done ) &
  REFRESHER_PID=$!
}

refresher_stop() {
  if [ -n "$REFRESHER_PID" ]; then
    kill "$REFRESHER_PID" 2>/dev/null || true
    wait "$REFRESHER_PID" 2>/dev/null || true
    REFRESHER_PID=""
  fi
}

# Leaving the refresher alive after a `systemctl stop` would keep the lock
# looking fresh forever, and the button would refuse every later deploy.
trap 'refresher_stop; exit 0' TERM INT

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

# Read-only: apt package upgrades + graphics driver updates for the host.
# Runs on the host (not in the luma-sync container) for the same reason
# `deploy` does — the container's filesystem has nothing to do with the
# host's installed packages, so an in-container `apt` would just report the
# container's own minimal image as fully up to date.
check_updates() {
  step "Refreshing apt package lists"
  if command -v sudo >/dev/null 2>&1; then
    sudo -n apt-get update -qq 2>&1 || echo "(apt-get update needs passwordless sudo — showing the last cached package list instead)"
  else
    apt-get update -qq 2>&1 || true
  fi

  step "Upgradable packages"
  apt list --upgradable 2>/dev/null | grep -v '^Listing...' || echo "(none, or apt is unavailable on this host)"

  step "Graphics / driver updates"
  if command -v ubuntu-drivers >/dev/null 2>&1; then
    ubuntu-drivers devices 2>&1 || echo "ubuntu-drivers failed to run."
  else
    echo "ubuntu-drivers-common is not installed — skipping driver check."
  fi
}

# systemd restarts this script on failure; a stale lock left behind by a
# killed run would otherwise make the button answer "a deploy is already in
# progress" until it aged out.
rm -f "$LOCK_FILE" "$UPDATE_LOCK_FILE"

SELF_HASH="$(script_hash)"
beat=0
while true; do
  # Heartbeat every ~10s. DeployConsole.status() reports the button as
  # unbacked when this file goes stale, so a stopped watcher says so
  # instead of the deploy just quietly never happening.
  if [ "$beat" -le 0 ]; then
    : 2>/dev/null > "$HEARTBEAT_FILE" || true
    beat=5
  fi
  beat=$((beat - 1))

  if [ -f "$REQUEST_FILE" ]; then
    # Lock first, then drop the request: the container checks the lock
    # before the request, so an instant where both exist reads as "running",
    # whereas an instant where neither exists would read as "idle" and show
    # the previous run's log as if this one had finished already.
    touch_files
    rm -f "$REQUEST_FILE" "$STATUS_FILE"
    refresher_start
    ( deploy ) > "$LOG_FILE" 2>&1
    code=$?
    refresher_stop
    if [ "$code" -eq 0 ]; then
      echo "==> Deploy finished successfully." >> "$LOG_FILE"
    else
      echo "==> Deploy FAILED (exit $code) — nothing was restarted." >> "$LOG_FILE"
    fi
    # Status before lock: the container reads the lock to decide whether a
    # run is still going, so clearing it first would briefly expose a
    # finished deploy with no recorded exit code.
    echo "$code" > "$STATUS_FILE"
    rm -f "$LOCK_FILE"
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

  if [ -f "$UPDATE_REQUEST_FILE" ]; then
    : 2>/dev/null > "$UPDATE_LOCK_FILE" || true
    : 2>/dev/null > "$HEARTBEAT_FILE" || true
    rm -f "$UPDATE_REQUEST_FILE"
    ( check_updates ) > "$UPDATE_LOG_FILE" 2>&1
    date -Is > "$UPDATE_DONE_FILE"
    rm -f "$UPDATE_LOCK_FILE"
    beat=0
  fi
  sleep 2
done
