#!/bin/sh
# Starts luma_server as an unprivileged user.
#
# The container starts as root only long enough to hand /data to that user,
# then drops every privilege for good (setpriv: new uid/gid, no groups, no
# capabilities, no_new_privs) before the server runs. A bug in the server
# then gives an attacker an ordinary user, not root — which matters because
# /data and /wiki are host directories.
#
# The uid is LUMA_SYNC_UID when set. Otherwise it is whoever owns /data on
# the host (or /wiki), so files the server writes stay owned by the same
# account as before and the host-side deploy watcher can keep replacing its
# own files there. Only a root-owned mount falls back to 10001.
set -eu

owner_of() { stat -c %u "$1" 2>/dev/null || echo 0; }
group_of() { stat -c %g "$1" 2>/dev/null || echo 0; }

uid="${LUMA_SYNC_UID:-}"
gid="${LUMA_SYNC_GID:-}"
if [ -z "$uid" ]; then
  for dir in /data /wiki; do
    if [ -d "$dir" ] && [ "$(owner_of "$dir")" != 0 ]; then
      uid="$(owner_of "$dir")"
      gid="$(group_of "$dir")"
      break
    fi
  done
fi
uid="${uid:-10001}"
gid="${gid:-$uid}"
if [ "$uid" = 0 ]; then
  echo "[luma] refusing to run luma_server as root (LUMA_SYNC_UID=0)" >&2
  exit 1
fi

# Files the old root container wrote. Only root-owned ones are touched, so
# anything the host user made there keeps its owner.
for dir in /data /wiki; do
  [ -d "$dir" ] || continue
  if [ "$dir" = /data ] && [ "$(owner_of "$dir")" = 0 ]; then
    chown "$uid:$gid" "$dir"
  fi
  find "$dir" -xdev -user 0 -exec chown -h "$uid:$gid" {} + 2>/dev/null || true
done

export HOME=/tmp
exec setpriv --reuid="$uid" --regid="$gid" --clear-groups \
  --inh-caps=-all --bounding-set=-all --no-new-privs \
  /app/bundle/bin/luma_server
