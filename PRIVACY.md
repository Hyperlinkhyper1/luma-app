# Privacy Policy

**Last updated: September 30, 2026**

luma is a local-first app. This policy explains, plainly, what that means in
practice: what stays on your device, what an optional account sends to the
server, and what a handful of built-in tools talk to on the internet. It
covers the official luma app and the server I operate at
`sync.luma-app.cc`. If you connect the app to a different, self-hosted
server, that server's operator — not me — controls the data sent to it; see
[Self-hosting](#self-hosting) below.

If anything here is unclear, email me — see [Contact](#contact).

## The short version

- **Local features work offline.** Luma-server feature requests require an
  approved account, with account-setup exceptions. Update/catalog requests
  and external integrations have separate network behavior.
- **An account is optional**, and needs only an email address and a
  password. Your password never reaches the server in readable form.
- **Snapshot contents are encrypted before upload.** The ordinary storage
  endpoint does not receive the decryption key. Metadata remains visible,
  and password guessing or a compromised device can defeat confidentiality.
- **Shared features and AI proxies are separate data flows.** Family
  membership/calendars are readable by the server, and AI proxies handle
  submitted prompts. Do not interpret snapshot encryption as a guarantee
  covering every online feature.
- **The AI Assistant** either talks straight from your device to the AI
  provider you choose using your own API key, or — for the built-in modes
  (Aurora, Nebula, Pulsar) — is relayed through my server to Google,
  OpenRouter or Mistral. My server doesn't store what you asked or what you
  got back, only how much you've used. **The AI service that answers can
  keep your messages under its own terms, and Google may use them to
  improve its products.** Don't put anything in a built-in-mode chat that
  you wouldn't want a third party to read. See [The AI Assistant](#the-ai-assistant).
- **No ads, no analytics SDK, no crash reporter, no data broker.** I don't
  sell your data, and I don't share it except with the services listed in
  this policy, for the feature you're using.

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

The ordinary sync endpoint stores that upload as opaque bytes and does not
receive the encryption key. This does not prevent password guessing or a
compromised client from exposing content. Recovery may be possible on a
device retaining the old key; losing all passwords, keys and usable devices
can make data permanently unreadable. See [current limitations](docs/security/SECURITY_ARCHITECTURE.md).

What the server *can* see, because it needs to for the sync protocol to
work at all: your account email, which named feature a given upload
belongs to (e.g. "finance", "passwords"), its size in bytes, a version
number, and the time it was saved — never the content.

Settings sync is enabled for signed-in accounts; other collections are opt-in,
and can turn any of them back off (optionally deleting the server copy) at
any time from Settings.

**Wi-Fi/LAN sync** is a separate, serverless option: your devices exchange
the same encrypted snapshots directly over your local network, and nothing
touches my server at all.

## Family sharing — the one deliberately plain-text feature

The preceding section describes encrypted snapshots. Family sharing is
different: its whole point is letting
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

The Assistant can reach an AI model in three ways. Which one you're using
decides who sees your messages.

### An on-device model

If you download a local model, the whole conversation runs on your own
device. Nothing you type is sent anywhere. The only network traffic is the
one-time model download from Hugging Face.

### Your own API key

The app talks directly from your device to the provider you pick
(Anthropic, OpenAI, Mistral or Google), using a key you enter yourself.
This traffic never passes through my server. Your key is stored on your
device, encrypted at rest, and is sent only to that provider. That
provider's own privacy policy and terms cover what you send it.

### The built-in modes (Aurora, Nebula, Pulsar)

These need an approved account. The app sends your request to my server,
which adds its own provider key and passes the request on to one of these
AI services:

| Service | Run by | Where |
|---|---|---|
| Google AI Studio (Gemini API) | Google | United States |
| OpenRouter | OpenRouter, Inc. | United States. OpenRouter hands the request to the company that runs the chosen model, which can be in the US, the EU, China or elsewhere. |
| Mistral | Mistral AI | France (EU) |

I choose which service and model answers each mode. That can change without
notice, for example when a model is retired or a free quota runs out. The
AI Detector plugin and the "Luma Support" chat use the same relay. Luma
Support always goes to Mistral.

**What the AI service receives:**

- The messages in the conversation you're having, including earlier
  messages in that chat that the app sends along for context.
- The instructions the app adds. These can include your saved Assistant
  memory and the profile notes you wrote in Assistant settings.
- Not your email address, your luma account ID or your IP address. The
  request comes from my server.

**What my server keeps:** not the content of your messages or the replies.
It keeps only usage counts with timestamps, used to enforce your plan's
allowance:

- tokens per mode
- the number of Luma Support messages
- the number of web searches

These counts are deleted with your account.

**What the AI service may keep.** Each service handles your request under
its own terms, not mine:

- **Google:** the built-in modes may run on Google's free (unpaid) tier. On
  that tier, Google keeps prompts and responses, uses them to improve its
  products, and may have human reviewers read them.
- **OpenRouter:** OpenRouter and the model provider it passes your request
  to each apply their own policies. Some providers keep or train on
  prompts, especially for free models.
- **Mistral:** Mistral's API data policy applies.

So treat a built-in-mode chat like any other message sent to an outside
company. **Don't put passwords, health details, financial account numbers
or other people's personal information in it.** If you need a provider's
stricter business terms, use your own API key instead.

**Leaving the EU:** Google and OpenRouter are US companies, and OpenRouter
can pass your request to a provider in another country. Using the built-in
modes therefore sends your messages outside the European Union.

### Web search

When the Assistant searches the web in a built-in mode, it writes a search
query from your conversation. That query goes to a search service
(SearXNG) that I run, which passes it on to public search engines such as
Google, Bing and DuckDuckGo. The engines receive the query text only. They
see it coming from my server, not from your device or IP address. The
search results go back to the AI service answering you, as part of the
conversation.

### Your conversations

Your conversation history is stored only on your device, whichever way you
reach a model. Your Assistant memory and profile notes sync between your
devices through the encrypted sync described above, like any other
collection.

## Secure Chat (the messaging plugin)

If you install the Chat plugin, it lets you exchange end-to-end encrypted
messages with other luma users. Only your public key is ever uploaded; each
message is sealed on your device such that the server relays it without
being able to read it.

If you're on the receiving end of harassment or illegal content through
Secure Chat, Cloud Files, or Family sharing, report it to
**customerservice@luma-app.cc** — see
[Reporting abuse or illegal content](TERMS.md#reporting-abuse-or-illegal-content)
in the Terms for what happens next.

## What the server does not do

No crash reporting, no analytics or telemetry SDK, no advertising network,
and no data broker of any kind is built into luma or its server. I don't
sell or rent your personal data. The only third parties that receive it are
the ones this policy names, for the feature you're using. Note that some of
them apply their own terms to it, as [The AI Assistant](#the-ai-assistant)
explains.

Besides your account and sync data, the server records:

- **Anonymous operational data:** host-level metrics (CPU, memory and disk
  of the server itself) and per-plugin download counts. Neither is tied to
  you.
- **Per-account counters:** AI usage counts (see above) and how many
  requests and bytes your account has sent and received, used to spot
  abuse.
- **An activity log** of account events such as registrations, sign-ins
  and password resets, which names the account's email.

All of these are deleted, or scrubbed of your email, when your account is
deleted.

## Third-party services a handful of features talk to

A few optional tools call other services directly from your device, using
only the minimum needed to do their job:

| Feature | Service | What's sent |
|---|---|---|
| App auto-updater | GitHub Releases | An anonymous check for the latest version |
| Plugin marketplace | GitHub (raw content) | An anonymous fetch of the plugin catalog |
| Finance → Stocks | Yahoo Finance / Stooq | The ticker symbol you're looking up — no account or key |
| AI Assistant (your own key) | Your chosen AI provider | Your prompts, using your own API key |
| AI Assistant (on-device model) | Hugging Face | A one-time model download — not your data |
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
Delete account. Doing so signs out every device and removes from the
server:

- your account record, sign-in links and encrypted sync data
- a family you own, including its members, invites and shared events
- in a family you only belong to: your membership and the events you
  shared
- your Secure Chat key, your chat invites, and every conversation you were
  part of, with its relayed messages
- the recipes you published, with their reviews and photos, and your
  reviews of other people's recipes
- Subway Builder rooms you own, plus your place in anyone else's
- your AI usage and traffic counts

Data already stored locally on your own devices, or on the devices of
people you shared with, isn't touched. Deleting your account only affects
the server.

A few records survive in scrubbed form:

- The activity log keeps its entries, but your email is replaced with "a
  deleted account".
- A deletion request you filed keeps its status and date, but loses your
  email and reason.
- Security records used to prevent abuse, such as blocked IP addresses, are
  kept for a bounded period.

If you'd like help with a specific case, email me and I'll sort it out by
hand.

You can also ask for deletion from Settings instead of deleting the account
yourself. You don't have to give a reason. I'll only decline if the law
allows or requires me to keep something (for example, an ongoing abuse
report), and I'll tell you why.

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

To report abuse or illegal content on the service, email
**customerservice@luma-app.cc**.
