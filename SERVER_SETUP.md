# luma Sync Server — Setup Guide

luma can sync your data (notes, finance, passwords, calendar, …) between
devices through a small server that you run yourself. This guide takes you
from "I have nothing" to a working, secure sync server.

The server code lives in the [`server/`](server/) folder of this repo.

---

## 1. How it works (read this first)

```
┌────────────┐   HTTPS    ┌───────────┐        ┌──────────────────┐
│ luma (PC)  │ ─────────► │   Caddy   │ ─────► │ luma sync server │
└────────────┘            │ (TLS/443) │        │   (port 8080)    │
┌────────────┐            └───────────┘        └────────┬─────────┘
│ luma (web) │ ─────────►      ▲                        │
└────────────┘                 │               ┌────────▼─────────┐
                        Let's Encrypt          │  /data (volume)  │
                        certificate            │ encrypted blobs  │
                                               └──────────────────┘
```

**Security model (zero-knowledge):**

- Every feature's data is encrypted **on the device** with an authenticated
  encrypt-then-MAC cipher (HMAC-SHA256 keystream + HMAC-SHA256 tag, with
  independent sub-keys), using a key derived from the user's account
  password (PBKDF2-HMAC-SHA256, 200,000 iterations). The server only ever
  stores unreadable ciphertext.
- The server never sees the account password either — the app sends a
  separate *auth key* derived from it, which the server hashes again
  before storing.
- Consequence: **a forgotten password means the synced data cannot be
  recovered.** Not by you, not by anyone. Users keep the local copies on
  their devices, but the server-side snapshots are gone for good. Tell
  your users this.
- Login tokens are stored hashed; even someone who steals the server's
  data directory cannot impersonate users or read their data.
- Each account gets **3 GB** of storage by default (configurable).
- Nothing syncs by default: each user turns individual features on in
  *Settings → Sync & account*.

---

## 2. What you need

| Thing | Why | Cost |
|---|---|---|
| A Linux VPS (1 vCPU, 1 GB RAM, 25+ GB disk) | Runs the server 24/7 | ~€4–6/month (Hetzner, Netcup, DigitalOcean, …) |
| A domain or subdomain, e.g. `sync.yourdomain.com` | Needed for automatic HTTPS | ~€10/year (or free subdomain via DuckDNS) |
| 15–30 minutes | | |

Disk sizing: every account can store up to 3 GB, so plan
`25 GB + (3 GB × number of users)` to be safe. In practice luma snapshots
are tiny (kilobytes to a few MB).

> **No VPS? See section 9** for running it on a home PC (LAN-only) instead.

---

## 3. Prepare the VPS

SSH into the fresh server as root, then:

```bash
# Keep the system patched
apt update && apt upgrade -y

# Firewall: only SSH, HTTP and HTTPS are reachable
apt install -y ufw
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Install Docker (official convenience script)
curl -fsSL https://get.docker.com | sh
```

Recommended (not required): disable SSH password login and use SSH keys —
`PasswordAuthentication no` in `/etc/ssh/sshd_config`, then
`systemctl restart ssh`.

---

## 4. Point your domain at the server

At your DNS provider, create an **A record**:

```
sync.yourdomain.com  →  <your VPS's public IPv4 address>
```

Wait until `ping sync.yourdomain.com` answers from the right IP (usually
minutes). HTTPS setup in the next step needs this to be live.

---

## 5. Deploy the server

Copy the `server/` folder from this repo to the VPS (or clone the repo):

```bash
# From your PC, in the repo root:
scp -r server root@<vps-ip>:/opt/luma-sync
```

Then on the VPS:

```bash
cd /opt/luma-sync

# Create your configuration
cp .env.example .env
nano .env
```

Fill in `.env`:

- `LUMA_DOMAIN` — your domain, e.g. `sync.yourdomain.com`
- Leave the rest at the defaults unless you know why you're changing them.
  Registration is **open** by default (anyone who knows the address can
  create an account). Once your accounts exist you can set
  `LUMA_ALLOW_REGISTRATION=false` and restart to close it — see section 7.

Start it:

```bash
docker compose up -d --build
```

That's it. Caddy fetches a Let's Encrypt certificate automatically and
renews it forever. Check that everything is happy:

```bash
docker compose logs -f          # look for "listening on port 8080"
curl https://sync.yourdomain.com/health
# → {"ok":true,"name":"luma-sync-server","registration":"open"}
```

---

## 6. Connect the app

On each device, in luma:

1. **Settings → Sync & account → Sign in or create account**
2. Server address: `https://sync.yourdomain.com`
3. First device: *Create account* tab → email + password. Other devices:
   *Sign in* with the same account.
4. Toggle on the features you want synced (they are all **off** by
   default). The storage bar shows usage against the 3 GB quota.

The **Cloud Files** plugin (install it from the plugin marketplace) uses the
same account to upload arbitrary files. They are end-to-end encrypted on the
device before upload and count against the same 3 GB quota, shown as a usage
bar inside the plugin.

Give the server address to anyone else who should be able to make an
account (each gets their own private, encrypted 3 GB).

**Password advice for users:** the account password is also the
encryption key. Long and unique; a password manager or a diceware phrase
is ideal. There is **no reset** — that's the price of the server not
being able to read anything.

---

## 7. Maintenance

### Backups

All state lives in one Docker volume. Back it up on a schedule:

```bash
# Manual backup
docker run --rm -v luma-sync_luma_data:/data -v /root/backups:/backup \
  debian tar czf /backup/luma-$(date +%F).tar.gz -C /data .

# Automatic: crontab -e, then add (daily at 04:00, keep it simple):
0 4 * * * docker run --rm -v luma-sync_luma_data:/data -v /root/backups:/backup debian tar czf /backup/luma-$(date +\%F).tar.gz -C /data . && find /root/backups -name 'luma-*.tar.gz' -mtime +14 -delete
```

The backups only contain ciphertext — safe to copy anywhere.

### Updating the server

```bash
cd /opt/luma-sync
# copy in the new server/ folder (or git pull), then:
docker compose up -d --build
```

### Changing the quota

Edit `LUMA_QUOTA_BYTES` in `.env` and `docker compose up -d`. This is the
default for **new** accounts; existing accounts keep the quota they were
created with (stored in `users.json` — you can edit it there while the
server is stopped).

### Removing a user / freeing space

Users can delete their own account in the app (Settings → Delete
account). To force-remove one yourself:

```bash
docker compose stop luma-sync
docker run --rm -it -v luma-sync_luma_data:/data debian bash
# inside: edit /data/users.json (remove the user's entry),
#         delete /data/blobs/<their-user-id>/
docker compose start luma-sync
```

### Closing registration

Registration is open by default. Once everyone you care about has an
account, set `LUMA_ALLOW_REGISTRATION=false` in `.env` and restart
(`docker compose up -d`). Existing accounts keep working; no new ones can be
created. Remove the setting (or set it back to `true`) to reopen.

---

## 8. Security checklist

Things the setup above already gives you:

- [x] HTTPS everywhere (Caddy + Let's Encrypt, HSTS enabled)
- [x] The app refuses plain-HTTP servers on the public internet
- [x] Zero-knowledge encryption — server stores only authenticated
      (encrypt-then-MAC) ciphertext
- [x] Passwords never reach the server; login secrets are PBKDF2-hashed
      again server-side with per-user salts
- [x] Login tokens stored hashed, 90-day sliding expiry
- [x] Rate limiting on all endpoints (brute-force protection)
- [x] Account enumeration prevented (fake KDF salts for unknown emails)
- [x] Per-account quota + per-upload size cap (disk exhaustion protection)
- [x] Registration can be closed once your accounts exist
      (`LUMA_ALLOW_REGISTRATION=false`)
- [x] Container runs as a non-root user; app port never exposed directly
- [x] Firewall limits the VPS to SSH/80/443

Things that stay on your plate:

- [ ] Keep the VPS patched (`apt upgrade` monthly, or enable
      `unattended-upgrades`)
- [ ] Keep backups (section 7) — the server is the single copy of the
      *synced* snapshots
- [ ] Protect SSH (keys, not passwords)
- [ ] If your server is public, close registration once your accounts exist
      so strangers can't use your storage

---

## 9. Alternative: home server on your own PC (LAN only)

No VPS needed if syncing only needs to work inside your house/network.
The app allows plain `http://` for private addresses
(`192.168.x.x`, `10.x.x.x`, `localhost`) — traffic then stays on your LAN.

On the always-on PC (Windows works fine) the easiest path is the bundled
launcher, which compiles the server to a native exe on first run and starts
it:

```powershell
cd server
# Optionally edit the port at the top of run_local.ps1 first, then:
.\run_local.ps1
```

Or do it by hand:

```powershell
cd server
dart compile exe bin/luma_server.dart -o luma_server.exe

$env:LUMA_DATA_DIR = "C:\luma-sync-data"
.\luma_server.exe
```

> **Always run the compiled `luma_server.exe`, not `dart run`.** The exe reads
> nothing from the Dart pub cache at runtime, so it avoids the intermittent
> Windows "Het systeem kan het opgegeven pad niet vinden" (cannot find path)
> compile errors that antivirus scanning + a running IDE can cause. If the
> one-time `dart compile exe` step itself hits that error, just run it again.
> See section 11.

Allow it through the Windows firewall for private networks when prompted
(or: Settings → Windows Security → Firewall → Allow an app). Then in the
app use `http://<that-pc's-LAN-IP>:8080` as the server address.

To start it automatically: Task Scheduler → Create Task → trigger
"At startup" → action: run `luma_server.exe` (set the environment
variables in a small `.bat` wrapper).

> Don't port-forward this to the internet — that's what the VPS + HTTPS
> setup is for.

---

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `curl https://…/health` fails | DNS not propagated yet, or ports 80/443 blocked. `docker compose logs caddy` shows certificate errors. |
| App says "This server does not accept new accounts" | Registration is closed (`LUMA_ALLOW_REGISTRATION=false`). Set it to `true` (or remove it) and restart to allow sign-ups. |
| App says "Session expired" | Tokens expire after 90 days of inactivity — just sign in again. Data is untouched. |
| "Could not decrypt this snapshot" | The account's data was encrypted under a different password (e.g. password was changed on another device before it finished re-encrypting). Sign in again on the device that has the data and let it re-upload. |
| "Storage quota exceeded" | The account hit its 3 GB. Turn off + "delete from server" for features you don't need synced, or raise the quota (section 7). |
| Two devices edited the same feature while offline | The **newest edit wins** per feature; the older change is overwritten at the next sync. |
| Enabled a feature on a new device and local data disappeared | By design: the first time a device enables a feature that already has synced data, the server copy replaces the local one (prevents a fresh install from wiping real data). |
| Server disk full | Check `docker system df`, prune old images (`docker image prune`), grow the volume, or lower quotas. |

### API quick reference (for the curious)

All endpoints under `https://<server>/api/v1`:

```
POST /auth/params    {email}                        → KDF salt + iterations
POST /auth/register  {email, authKey, kdfSalt, …}   → token
POST /auth/login     {email, authKey}               → token
POST /auth/logout                                    (auth)
POST /auth/change    {currentAuthKey, newAuthKey,…}  (auth)
GET  /account                                        (auth) → usage, quota, collections
POST /account/delete {authKey}                       (auth) → wipes everything
GET  /sync/<name>                                    (auth) → encrypted snapshot
PUT  /sync/<name>    (X-Base-Version header)         (auth) → optimistic-locked upload
DELETE /sync/<name>                                  (auth)
GET  /health                                          public
```

---

## 11. Windows: "cannot find path" / pub-cache build errors

If `dart run` or a Flutter build fails with lots of errors like:

```
Error when reading '.../Pub/Cache/hosted/pub.dev/meta-1.18.3/lib/meta.dart':
Het systeem kan het opgegeven pad niet vinden
Error: Undefined name 'sealed'.  @sealed
```

…for packages that clearly exist, the compiler is being blocked from reading
the Dart **pub cache** mid-build. On Windows this is almost always **antivirus
(Windows Defender) real-time scanning** the cache while a build reads it,
often made worse by an IDE (IntelliJ/VS Code) whose Dart analysis server is
touching the same files at the same time. It is not a code problem — the files
exist and read fine a moment later.

**Fixes, in order of preference:**

1. **Run the server as a compiled exe** (`.\run_local.ps1`, or
   `dart compile exe`). A compiled exe reads nothing from the pub cache at
   runtime, so it never hits this. This is the recommended way to run the
   server locally.

2. **Exclude the dev directories from Windows Defender** (fixes it for the
   Flutter app too, which must read the cache on every debug run). Open
   **PowerShell as Administrator** and run:

   ```powershell
   Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Pub\Cache"
   Add-MpPreference -ExclusionPath "$env:USERPROFILE\flutter"
   Add-MpPreference -ExclusionPath "C:\Users\ayden\Files\Intellij-Programs\luma-app"
   ```

   Excluding your SDK, package cache, and project folder from real-time
   scanning is a common and low-risk developer practice (you still download
   packages over HTTPS from pub.dev, and the rest of the system stays
   protected). Restart the build afterwards.

3. **Don't run two builds at once.** Building from a terminal while the IDE is
   also compiling/analyzing the same project multiplies the contention. Let
   one finish, or stop the app in the IDE before running a terminal build.

4. **Retry.** Because the failure is transient, simply running the command a
   second time often succeeds.
