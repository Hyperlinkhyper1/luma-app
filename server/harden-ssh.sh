#!/usr/bin/env bash
# Locks SSH on the server host down to key logins for one account.
#
#   sudo bash harden-ssh.sh           # for the account that ran sudo
#   sudo bash harden-ssh.sh alice     # or name the account
#
# Writes /etc/ssh/sshd_config.d/10-luma-hardening.conf, which sshd reads
# before the main sshd_config, so it wins over what that file says:
#   - public keys only: no passwords, no keyboard-interactive codes
#   - no root login, and nobody but the named account logs in at all
#   - three tries per connection and 20 seconds to finish logging in, so a
#     guessing bot is cut off quickly
#   - no X11 forwarding
#
# Safety: it refuses to run while that account has no key in its
# authorized_keys, checks the new config with `sshd -t` and puts the old
# file back if the check fails, and only then reloads sshd. Sessions that
# are already open stay open. Keep one open while you test a fresh login.
#
# Undo: sudo rm /etc/ssh/sshd_config.d/10-luma-hardening.conf
#       sudo systemctl reload ssh
set -euo pipefail

CONF=/etc/ssh/sshd_config.d/10-luma-hardening.conf
SSHD=/usr/sbin/sshd

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

user="${1:-${SUDO_USER:-}}"
if [ -z "$user" ] || [ "$user" = root ]; then
  echo "Name the account that should keep SSH access: sudo $0 <user>" >&2
  exit 1
fi
if ! home="$(getent passwd "$user" | cut -d: -f6)" || [ -z "$home" ]; then
  echo "No account named $user on this machine." >&2
  exit 1
fi

# A key line may start with options (from="…",no-pty …) before its type.
keys_file="$home/.ssh/authorized_keys"
key_re='(^|[[:space:]])(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)[[:space:]]+AAAA'
key_count="$(grep -cE "$key_re" "$keys_file" 2>/dev/null || true)"
if [ "${key_count:-0}" -lt 1 ]; then
  echo "$keys_file has no SSH key in it. Add yours first (ssh-copy-id from" >&2
  echo "your own computer), or turning passwords off locks you out." >&2
  exit 1
fi
echo "$user has $key_count key(s) in $keys_file:"
while read -r line; do
  printf '  %s\n' "$(printf '%s\n' "$line" | ssh-keygen -lf - 2>/dev/null || echo "(unreadable line)")"
done < <(grep -E "$key_re" "$keys_file")
echo "Remove any of these you don't recognise before relying on this."
echo

mkdir -p "$(dirname "$CONF")"
backup=""
if [ -e "$CONF" ]; then
  backup="$(mktemp)"
  cp -p "$CONF" "$backup"
fi

tmp="$(mktemp "$CONF.XXXXXX")"
cat >"$tmp" <<EOF
# Written by luma's server/harden-ssh.sh. Delete this file and run
# "systemctl reload ssh" to undo it.
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
AllowUsers $user
MaxAuthTries 3
LoginGraceTime 20
X11Forwarding no
EOF
chmod 644 "$tmp"
mv -f "$tmp" "$CONF"

if ! "$SSHD" -t; then
  echo "sshd rejected the new config, so it was not applied." >&2
  if [ -n "$backup" ]; then mv -f "$backup" "$CONF"; else rm -f "$CONF"; fi
  exit 1
fi
[ -z "$backup" ] || rm -f "$backup"

systemctl try-reload-or-restart ssh.service 2>/dev/null ||
  systemctl try-reload-or-restart sshd.service

echo "Applied. sshd now says, for $user:"
"$SSHD" -T -C "user=$user,host=localhost,addr=127.0.0.1" |
  grep -E '^(passwordauthentication|kbdinteractiveauthentication|authenticationmethods|permitrootlogin|allowusers|maxauthtries|logingracetime|x11forwarding) '
echo
echo "Now open a NEW terminal and check you can still log in before closing this one."
