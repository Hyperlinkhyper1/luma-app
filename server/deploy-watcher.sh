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

# "System updates" button (UpdateCheckConsole) — installs apt upgrades and
# driver updates for the host, then immediately restarts the server and wiki.
# Handled in the same loop so it shares the heartbeat file. It never touches
# deploy.lock: keeping them on separate lock files means a system update in
# flight never makes the deploy button report "already running".
UPDATE_REQUEST_FILE="$DATA_DIR/update-check.request"
UPDATE_LOG_FILE="$DATA_DIR/update-check.log"
UPDATE_LOCK_FILE="$DATA_DIR/update-check.lock"
UPDATE_DONE_FILE="$DATA_DIR/update-check.done"

# "Reboot server" button (UpdateCheckConsole.requestReboot). The container
# drops reboot.request; this script reboots the host with
# `sudo -n systemctl reboot` and writes what happened to reboot.log. Docker
# and this service are both enabled at boot, and the containers carry
# `restart: unless-stopped`, so everything comes back on its own.
# reboot-required mirrors the host's /var/run/reboot-required, which the
# container can't see, so the dashboard can say when a reboot is due.
REBOOT_REQUEST_FILE="$DATA_DIR/reboot.request"
REBOOT_LOG_FILE="$DATA_DIR/reboot.log"
REBOOT_REQUIRED_FILE="$DATA_DIR/reboot-required"

# The header's Start / Restart / Shut down buttons (PowerConsole). The
# container drops power.request holding "<action> <target>":
#   stop wiki | start wiki   the wiki only
#   restart all              the wiki, then the whole server stack
#   shutdown all             the wiki, then `docker compose stop` of the stack
# Output goes to power.log. Every heartbeat also writes wiki.state
# (running / stopped / none) and wiki.start-cmd, the command that starts the
# wiki by hand — the admin shutdown screen shows it, since after that
# nothing is left to ask.
POWER_REQUEST_FILE="$DATA_DIR/power.request"
POWER_LOG_FILE="$DATA_DIR/power.log"
WIKI_STATE_FILE="$DATA_DIR/wiki.state"
WIKI_START_CMD_FILE="$DATA_DIR/wiki.start-cmd"

# Read LUMA_REPO_PATH from server/.env rather than hardcoding it, so this
# can never drift from the same value the container's gate check
# (Api._adminDeploy, via config.repoPathConfigured) is enforcing.
REPO_PATH="$(grep -m1 '^LUMA_REPO_PATH=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2-)"
if [ -z "$REPO_PATH" ]; then
  echo "[deploy-watcher] LUMA_REPO_PATH is not set in $SCRIPT_DIR/.env — exiting." >&2
  exit 1
fi

# Optional: where the wiki's compose file lives, when it isn't
# $REPO_PATH/wiki. Without it the wiki is found by wiki_detect below.
WIKI_COMPOSE_DIR="$(grep -m1 '^LUMA_WIKI_COMPOSE_DIR=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2-)"

# docker without sudo when this user is in the docker group, otherwise
# passwordless sudo — the same two routes check_updates already tries.
docker_cmd() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    sudo -n docker "$@"
  fi
}

# Sets WIKI_KIND (compose / container / systemd) and WIKI_REF (directory,
# container name or unit name). Returns 1 when no wiki is found.
wiki_detect() {
  WIKI_KIND=""
  WIKI_REF=""
  local dir f name svc
  for dir in "$WIKI_COMPOSE_DIR" "$REPO_PATH/wiki"; do
    [ -n "$dir" ] || continue
    for f in compose.yml compose.yaml docker-compose.yml docker-compose.yaml; do
      if [ -f "$dir/$f" ]; then
        WIKI_KIND=compose
        WIKI_REF="$dir"
        return 0
      fi
    done
  done
  for name in wiki wiki.js luma-wiki luma_wiki; do
    if docker_cmd inspect "$name" >/dev/null 2>&1; then
      WIKI_KIND=container
      WIKI_REF="$name"
      return 0
    fi
  done
  for svc in wiki wiki.js luma-wiki; do
    if systemctl cat "$svc.service" >/dev/null 2>&1; then
      WIKI_KIND=systemd
      WIKI_REF="$svc"
      return 0
    fi
  done
  return 1
}

# wiki_ctl start|stop|restart|status — status prints running/stopped/none.
wiki_ctl() {
  if ! wiki_detect; then
    if [ "$1" = status ]; then echo none; return 0; fi
    echo "No wiki found (looked for a compose file in $REPO_PATH/wiki, a wiki container and a wiki systemd unit)."
    return 1
  fi
  case "$WIKI_KIND:$1" in
    compose:status)
      if [ -n "$(cd "$WIKI_REF" && docker_cmd compose ps --status running -q 2>/dev/null)" ]; then
        echo running
      else
        echo stopped
      fi ;;
    compose:start) (cd "$WIKI_REF" && docker_cmd compose up -d 2>&1) ;;
    compose:stop) (cd "$WIKI_REF" && docker_cmd compose stop 2>&1) ;;
    compose:restart) (cd "$WIKI_REF" && { docker_cmd compose restart 2>&1; docker_cmd compose up -d 2>&1; }) ;;
    container:status)
      if [ "$(docker_cmd inspect -f '{{.State.Running}}' "$WIKI_REF" 2>/dev/null)" = true ]; then
        echo running
      else
        echo stopped
      fi ;;
    container:*) docker_cmd "$1" "$WIKI_REF" 2>&1 ;;
    systemd:status)
      if systemctl is-active --quiet "$WIKI_REF"; then echo running; else echo stopped; fi ;;
    systemd:*) sudo -n systemctl "$1" "$WIKI_REF" 2>&1 ;;
  esac
}

wiki_start_cmd() {
  wiki_detect || { echo ""; return; }
  case "$WIKI_KIND" in
    compose) echo "cd $WIKI_REF && docker compose up -d" ;;
    container) echo "docker start $WIKI_REF" ;;
    systemd) echo "sudo systemctl start $WIKI_REF" ;;
  esac
}

sync_wiki_state() {
  wiki_ctl status > "$WIKI_STATE_FILE.tmp" 2>/dev/null &&
    mv -f "$WIKI_STATE_FILE.tmp" "$WIKI_STATE_FILE"
  wiki_start_cmd > "$WIKI_START_CMD_FILE.tmp" 2>/dev/null &&
    mv -f "$WIKI_START_CMD_FILE.tmp" "$WIKI_START_CMD_FILE"
}

# Runs the "<action> <target>" read from power.request.
power() {
  local action="$1" target="$2"
  echo "==> $action $target requested from the admin dashboard ($(date -Is))"
  case "$action:$target" in
    stop:wiki)
      step "Stopping the wiki"
      wiki_ctl stop || return 1 ;;
    start:wiki)
      step "Starting the wiki"
      wiki_ctl start || return 1 ;;
    restart:all)
      step "Restarting the wiki"
      wiki_ctl restart || echo "(wiki restart failed — carrying on with the server)"
      step "Restarting the server stack"
      (cd "$REPO_PATH/server" && docker_cmd compose restart 2>&1) || return 1 ;;
    shutdown:all)
      step "Stopping the wiki"
      wiki_ctl stop || echo "(wiki stop failed — carrying on with the server)"
      step "Stopping the server stack"
      (cd "$REPO_PATH/server" && docker_cmd compose stop 2>&1) || return 1
      echo
      echo "==> Everything is stopped. Start it again with:"
      echo "cd $REPO_PATH/server && docker compose up -d"
      wiki_start_cmd ;;
    *)
      echo "Unknown request: '$action $target'"
      return 1 ;;
  esac
}

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

touch_update_files() {
  : 2>/dev/null > "$UPDATE_LOCK_FILE" || true
  : 2>/dev/null > "$HEARTBEAT_FILE" || true
}

# System updates can also take minutes (apt upgrade + driver autoinstall +
# docker restarts), so keep the update lock and heartbeat fresh the same way.
UPDATE_REFRESHER_PID=""
update_refresher_start() {
  ( while :; do touch_update_files; sleep 5; done ) &
  UPDATE_REFRESHER_PID=$!
}

update_refresher_stop() {
  if [ -n "$UPDATE_REFRESHER_PID" ]; then
    kill "$UPDATE_REFRESHER_PID" 2>/dev/null || true
    wait "$UPDATE_REFRESHER_PID" 2>/dev/null || true
    UPDATE_REFRESHER_PID=""
  fi
}

# Leaving the refresher alive after a `systemctl stop` would keep the lock
# looking fresh forever, and the button would refuse every later deploy.
trap 'refresher_stop; update_refresher_stop; exit 0' TERM INT

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

# Installs apt upgrades + graphics driver updates for the host, then
# immediately restarts the server and wiki. Runs on the host (not in the
# luma-sync container) for the same reason `deploy` does — the container's
# filesystem has nothing to do with the host's installed packages, so an
# in-container `apt` would just report the container's own minimal image as
# fully up to date.
check_updates() {
  step "Refreshing apt package lists"
  if command -v sudo >/dev/null 2>&1; then
    sudo -n apt-get update -qq 2>&1 || echo "(apt-get update needs passwordless sudo — showing the last cached package list instead)"
  else
    apt-get update -qq 2>&1 || true
  fi

  step "Upgradable packages (before)"
  apt list --upgradable 2>/dev/null | grep -v '^Listing...' || echo "(none, or apt is unavailable on this host)"

  step "Graphics / driver updates (before)"
  if command -v ubuntu-drivers >/dev/null 2>&1; then
    ubuntu-drivers devices 2>&1 || echo "ubuntu-drivers failed to run."
  else
    echo "ubuntu-drivers-common is not installed — skipping driver check."
  fi

  step "Installing package upgrades"
  if command -v sudo >/dev/null 2>&1; then
    # Not `sudo env DEBIAN_FRONTEND=… apt-get`: a sudoers rule allowing
    # /usr/bin/env allows every command. The sudoers file in
    # SERVER_SETUP.md keeps DEBIAN_FRONTEND across sudo for apt-get instead.
    DEBIAN_FRONTEND=noninteractive sudo -n apt-get upgrade -y 2>&1 || echo "apt-get upgrade needs passwordless sudo or failed — continuing."
    DEBIAN_FRONTEND=noninteractive sudo -n apt-get dist-upgrade -y 2>&1 || true
  else
    env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 || true
    env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y 2>&1 || true
  fi

  step "Installing driver updates"
  if command -v ubuntu-drivers >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -n ubuntu-drivers autoinstall 2>&1 || echo "ubuntu-drivers autoinstall needs passwordless sudo or failed."
    else
      ubuntu-drivers autoinstall 2>&1 || true
    fi
  else
    echo "ubuntu-drivers-common is not installed — skipping driver install."
  fi

  step "Upgradable packages (after)"
  apt list --upgradable 2>/dev/null | grep -v '^Listing...' || echo "(none, or apt is unavailable on this host)"

  step "Cleaning up"
  if command -v sudo >/dev/null 2>&1; then
    sudo -n apt-get autoremove -y 2>&1 || true
  else
    apt-get autoremove -y 2>&1 || true
  fi

  step "Restarting server and wiki"
  echo "Restarting luma-sync stack (server)…"
  if [ -d "$REPO_PATH/server" ]; then
    if (cd "$REPO_PATH/server" && docker compose restart 2>&1); then
      echo "luma-sync restarted via docker compose restart."
    elif (cd "$REPO_PATH/server" && sudo -n docker compose restart 2>&1); then
      echo "luma-sync restarted via sudo docker compose restart."
    elif (cd "$REPO_PATH/server" && docker compose up -d 2>&1); then
      echo "luma-sync restarted via docker compose up -d."
    elif (cd "$REPO_PATH/server" && sudo -n docker compose up -d 2>&1); then
      echo "luma-sync restarted via sudo docker compose up -d."
    else
      echo "Warning: could not restart luma-sync — docker compose not available or needs passwordless sudo."
    fi
    # Ensure caddy (fronting server and wiki) is also fresh
    (cd "$REPO_PATH/server" && (docker compose restart caddy 2>&1 || sudo -n docker compose restart caddy 2>&1)) || true
  else
    echo "Server directory $REPO_PATH/server not found — skipping luma-sync restart."
  fi

  echo "Restarting wiki…"
  if wiki_ctl restart; then
    echo "wiki restarted ($WIKI_KIND $WIKI_REF)."
  else
    echo "No separate wiki container/service restarted — wiki (if served via luma-sync/caddy) was already restarted with the server."
  fi

  # Kernel and driver updates only take effect after the host itself
  # reboots; restarting the containers doesn't load them. Say so rather than
  # rebooting the machine from a button.
  if [ -f /var/run/reboot-required ]; then
    echo
    echo "==> The host needs a reboot for some updates (kernel/drivers) to take effect:"
    cat /var/run/reboot-required.pkgs 2>/dev/null || true
  fi

  echo
  echo "==> System update and restart complete."
}

sync_reboot_required() {
  if [ -f /var/run/reboot-required ]; then
    cat /var/run/reboot-required.pkgs 2>/dev/null > "$REBOOT_REQUIRED_FILE" ||
      : > "$REBOOT_REQUIRED_FILE"
  else
    rm -f "$REBOOT_REQUIRED_FILE"
  fi
}

reboot_host() {
  echo "==> Reboot requested from the admin dashboard ($(date -Is))"
  if sudo -n systemctl reboot 2>&1; then
    echo "==> Rebooting now."
  else
    echo "==> Reboot FAILED: this user needs passwordless sudo for systemctl reboot."
    echo "See 'System updates and rebooting from the dashboard' in SERVER_SETUP.md."
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
    sync_reboot_required
    sync_wiki_state
    beat=5
  fi
  beat=$((beat - 1))

  # The re-exec after a deploy only covers deploys made through the button.
  # A checkout updated any other way (a manual `git pull` on the host) left
  # the old copy running, and an old copy answers the "System updates"
  # button with whatever that button used to do — for a while that was a
  # read-only listing that never restarted anything, while the dashboard
  # reported "server and wiki restarted". Swap onto the current file before
  # claiming any request, so a request is always handled by the script on
  # disk.
  if { [ -f "$REQUEST_FILE" ] || [ -f "$UPDATE_REQUEST_FILE" ] ||
       [ -f "$REBOOT_REQUEST_FILE" ] || [ -f "$POWER_REQUEST_FILE" ]; } &&
     [ "$(script_hash)" != "$SELF_HASH" ]; then
    echo "[deploy-watcher] script changed on disk — reloading before handling the request." >&2
    exec "$SCRIPT_DIR/deploy-watcher.sh"
  fi

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
    update_refresher_start
    ( check_updates ) > "$UPDATE_LOG_FILE" 2>&1
    update_refresher_stop
    date -Is > "$UPDATE_DONE_FILE"
    rm -f "$UPDATE_LOCK_FILE"
    beat=0
  fi

  # Same two-minute rule as a reboot: a stale shutdown must never fire long
  # after whoever asked for it has moved on.
  if [ -f "$POWER_REQUEST_FILE" ]; then
    fresh="$(find "$POWER_REQUEST_FILE" -mmin -2 2>/dev/null)"
    read -r p_action p_target < "$POWER_REQUEST_FILE" || true
    if [ -n "$fresh" ]; then
      # Log before dropping the request, so the dashboard never sees
      # "no request, empty log" and reads it as finished.
      echo "==> Working on it ($(date -Is))" > "$POWER_LOG_FILE"
      rm -f "$POWER_REQUEST_FILE"
      ( power "${p_action:-}" "${p_target:-}" ) > "$POWER_LOG_FILE" 2>&1
      code=$?
      [ "$code" -eq 0 ] || echo "==> FAILED (exit $code)." >> "$POWER_LOG_FILE"
    else
      rm -f "$POWER_REQUEST_FILE"
      echo "==> Ignored a request older than two minutes ($(date -Is))." > "$POWER_LOG_FILE"
    fi
    sync_wiki_state
    beat=0
  fi

  # Checked last, so a reboot asked for while a deploy or update was running
  # waits for it to finish. A request older than two minutes is dropped
  # rather than acted on: one left over from a time the watcher was down
  # would otherwise reboot the machine long after anyone expected it.
  if [ -f "$REBOOT_REQUEST_FILE" ]; then
    fresh="$(find "$REBOOT_REQUEST_FILE" -mmin -2 2>/dev/null)"
    rm -f "$REBOOT_REQUEST_FILE"
    if [ -n "$fresh" ]; then
      reboot_host > "$REBOOT_LOG_FILE" 2>&1
    else
      echo "==> Ignored a reboot request older than two minutes ($(date -Is))." > "$REBOOT_LOG_FILE"
    fi
  fi
  sleep 2
done
