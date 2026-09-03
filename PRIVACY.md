# Privacy Policy

**Last updated: August 10, 2026**

luma is a local-first app. This policy explains, plainly, what that means in
practice: what stays on your device, what an optional account sends to the
server, and what a handful of built-in tools talk to on the internet. It
covers the official luma app and the server I operate at
`sync.luma-app.cc`. If you connect the app to a different, self-hosted
server, that server's operator — not me — controls the data sent to it; see
[Self-hosting](#self-hosting) below.

If anything here is unclear, email me — see [Contact](#contact).

## The short version

- **Nothing leaves your device by default.** A fresh install of luma works
  fully offline. No account, no server contact, no telemetry.
- **An account is optional**, and needs only an email address and a
  password. Your password never reaches the server in readable form.
- **Sync is end-to-end encrypted.** When you turn a feature's sync on, that
  feature's data is encrypted on your device before upload. The server
  stores unreadable ciphertext — I cannot read your notes, passwords,
  finances, or anything else you sync, and I have no way to recover it if
  you forget your password.
- **Two features are the deliberate exception**: shared Family calendars
  and Family membership are stored in plain text on the server, because the
  point of that feature is for other family members to read it. This is
  called out again in its own section below.
- **The AI Assistant** either talks straight from your device to the AI
  provider you choose using your own API key, or — for the built-in
  free-tier modes — is relayed through my server, which never stores what
  you asked or what you got back, only how much you've used against your
  plan's allowance.
- **No ads, no analytics SDK, no crash reporter, no data broker.** I don't
  sell or share your data with anyone, for any reason.

## Data you keep entirely on your device

By default, everything luma stores lives in a local database on your
device: notes, finances, the password vault, calendar entries, your photo
library view, chat history with the AI Assistant, and every other module
and plugin. None of it is sent anywhere unless you explicitly turn on sync
for that specific feature, and even then it's encrypted first (see below).

A few features never leave your device regardless of sync settings,
because there's nowhere for them to go: your local photo/video library,
your AI Assistant conversation history, and app usage/screen-time stats.

## If you create an account

Creating an account is entirely optional and only unlocks sync, family
sharing, and the free-tier AI modes. To create one, I ask for:

- **An email address**, used to identify your account, deliver optional
  verification links, and for account-related notices.
- **A password**, which is never sent to the server as plain text. Your
  device derives a one-way authentication key from it before sending
  anything, and the server stores only a further-hashed version of that key
  — the same technique used for the encryption described below. I cannot
  see, recover, or reset your password.
- **A device label** (e.g. "Windows", "Android"), shown back to you in the
  app so you can tell your devices apart in "Devices signed in."

New accounts are approved either by hand or by an email verification link,
depending on how the server is configured; until approved, the app does not
contact the server for anything except that approval step.

## Sync — end-to-end encryption

When you switch a feature's sync on in Settings, your device:

1. Compresses that feature's data.
2. Encrypts it with a key derived from your account password, which never
   leaves your device.
3. Adds an authentication tag so tampering is detectable.
4. Uploads the result.

The server stores that upload as opaque bytes. It has no copy of your
encryption key and no way to decrypt it. **If you forget your password,
your synced data cannot be recovered by me or anyone else.**

What the server *can* see, because it needs to for the sync protocol to
work at all: your account email, which named feature a given upload
belongs to (e.g. "finance", "passwords"), its size in bytes, a version
number, and the time it was saved — never the content.

Sync is off for every feature by default; you turn features on individually,
and can turn any of them back off (optionally deleting the server copy) at
any time from Settings.

**Wi-Fi/LAN sync** is a separate, serverless option: your devices exchange
the same encrypted snapshots directly over your local network, and nothing
touches my server at all.

## Family sharing — the one deliberately plain-text feature

Everything above describes zero-knowledge sync, where I cannot read your
data. Family sharing is different on purpose: its whole point is letting
people in your family see what you share with them, so it is **not**
end-to-end encrypted.

If you create or join a family group, the server stores — in plain text,
readable by the server and by other members of the group —
each member's email address and role, pending invite email addresses, and
any calendar events you choose to share with the family (title,
description, location, time, and similar details). Your personal,
non-shared calendar entries stay inside the encrypted sync channel
described above and are never exposed this way.

## The AI Assistant

The Assistant supports Anthropic, OpenAI, Mistral, and Google models,
in two different modes:

- **Your own API key ("bring your own key")**: the app talks directly to
  that provider's API from your device, using a key you enter yourself.
  I never see this traffic; it doesn't pass through my server at all. Your
  key is stored on your device, encrypted at rest, and is never sent
  anywhere except to that provider.
- **The built-in free-tier modes**: requests are relayed through my
  server, which attaches its own provider key so you don't need one. In
  this mode I do not store the content of your messages or the model's
  replies — only a running count of tokens or messages used, to enforce
  your plan's usage allowance. Your conversation history itself is only
  ever stored locally on your device, never on the server, regardless of
  which mode you use.

## Secure Chat (the messaging plugin)

If you install the Chat plugin, it lets you exchange end-to-end encrypted
messages with other luma users. Only your public key is ever uploaded; each
message is sealed on your device such that the server relays it without
being able to read it.

## What the server does not do

No crash reporting, no analytics or telemetry SDK, no advertising network,
and no data broker of any kind is built into luma or its server. I don't
sell, rent, or otherwise share your personal data with third parties for
their own purposes.

The only aggregate, non-personal data the server records is operational:
host-level metrics (CPU/memory/disk of the server itself) and per-plugin
download counts, neither of which is tied to your identity.

## Third-party services a handful of features talk to

A few optional tools call other services directly from your device, using
only the minimum needed to do their job:

| Feature | Service | What's sent |
|---|---|---|
| App auto-updater | GitHub Releases | An anonymous check for the latest version |
| Plugin marketplace | GitHub (raw content) | An anonymous fetch of the plugin catalog |
| Finance → Stocks | Yahoo Finance / Stooq | The ticker symbol you're looking up — no account or key |
| AI Assistant (BYOK mode) | Your chosen AI provider | Your prompts, using your own API key |
| Wi-Fi Speed Test plugin | Cloudflare | A bandwidth test, like any speed-test site |
| Minecraft Launcher plugin | Microsoft/Xbox login, Mojang, Modrinth, and mod-loader metadata services | Your own Microsoft account sign-in (handled entirely by Microsoft) plus public version/mod metadata lookups |
| Groceries plugin | groceries.luma-app.cc | Product search terms, to look up prices |
| Converter / launcher tools | GitHub | One-time downloads of tools like ffmpeg — not your data |

None of these send your luma account credentials, your local data, or any
personal information beyond what's listed above.

## Cookies

The app itself doesn't use cookies. The admin dashboard I use to operate
the server sets one strictly-necessary session cookie when I log in to it
— it isn't set for ordinary users of the app or website, and no tracking or
advertising cookies are used anywhere.

## Data retention and deletion

You can delete your account at any time from Settings → Sync & account →
Delete account. Doing so removes your account record, signs out every
device, and deletes your encrypted sync data from the server. Data already
stored locally on your own devices isn't touched — deleting your account
only affects the server copy.

Some limited records may persist after deletion for operational reasons:
security logs used to prevent abuse are kept for a bounded period, and
records tied to features you shared with other people (for example, a
family group you were a member of) may still reference your former
membership, since removing it entirely could affect data those other
people still legitimately have. If you'd like help with a specific case —
including removing lingering references after account deletion — email me
and I'll sort it out by hand.

Session tokens expire automatically after a period of inactivity and are
stored only as irreversible hashes, never as usable tokens.

## Children's privacy

luma isn't directed at children, and I don't knowingly collect personal
information from anyone under 13. If you believe a child has created an
account, email me and I'll delete it.

## Your rights

Wherever you are, you can ask me at any time to:

- Tell you what data I hold about your account.
- Correct inaccurate account data (e.g. your email address).
- Delete your account and its server-side data (or do this yourself in
  Settings).
- Export your synced data.
- Stop processing your data, by deleting your account.

Since sync data is end-to-end encrypted, I generally can't read it to
answer questions about its *content* — only about account-level metadata
(email, plan, storage used, and similar). Email me at the address below and
I'll respond as quickly as I can.

## Self-hosting

luma's server is open to self-host — anyone can run their own instance and
point the app at it instead of `sync.luma-app.cc`. If you use a
self-hosted server run by someone else (including yourself), that
operator, not me, controls and is responsible for the data your account
sends to it. This policy only describes the server I personally operate.

## Changes to this policy

If this policy changes in a way that meaningfully affects how your data is
handled, I'll note it here with an updated date, and — for account holders
— call it out in the app.

## Contact

Questions, requests, or reports about privacy: **hyperlinkhyper@outlook.com**
