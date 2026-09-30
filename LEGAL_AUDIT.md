# Legal audit

**Date:** September 30, 2026
**Scope:** the app (`lib/`), the sync server (`server/`), `supermarket-db/`,
bundled assets, dependencies, and the published documents (`TERMS.md`,
`PRIVACY.md`, `SECURITY.md`, `README.md`).

This comes from reading the codebase. It is not legal advice. Check the
🔴 items with a Dutch lawyer before relying on them.

Nothing in the code was changed. Each item is a checklist entry to work
through.

**Overall:** the Terms and Privacy Policy are a solid base. Most problems
are places where the code does more than those documents describe.

---

## 🔴 High: fix first

### 1. Media Downloader (YouTube, and Spotify matched to YouTube)

- [ ] Remove the plugin, or at least the Spotify part, or keep it out of the public marketplace.

`lib/features/plugins/installed/media_downloader/yt_dlp_manager.dart:114`
downloads and runs yt-dlp.

- It breaks YouTube's Terms of Service.
- It risks a claim that you are getting around a copy-protection measure:
  - Netherlands: Auteurswet art. 29a
  - EU: InfoSoc Directive art. 6
  - US: DMCA §1201
- The RIAA used exactly this argument against youtube-dl in 2020.
- Matching Spotify tracks to YouTube makes music ripping the obvious use.
  That weakens any "legitimate use" defence.

This is the biggest single exposure in the project.

### 2. The Privacy Policy is wrong about the AI relay

- [x] Update the "AI Assistant" section of `PRIVACY.md`. Done September 30,
  2026: names Google AI Studio, OpenRouter and Mistral, says what each
  receives and may keep, covers web search, Luma Support and the transfer
  outside the EU.
- [ ] Republish the updated policy at `wiki.luma-app.cc/privacy`.
- [ ] Check which Google tier (free or paid) your relay keys are on.
- [ ] Name the legal safeguard for the transfer outside the EU (for
  example, the EU–US Data Privacy Framework, or the providers' standard
  contractual clauses) once you've checked what Google and OpenRouter offer.

The policy says built-in modes go to Anthropic, OpenAI, Mistral or Google,
and that nothing is stored. `server/lib/ai_mode_routing.dart:8` actually
routes to **OpenRouter**, **Google AI Studio** (free-tier keys) and
**Mistral**.

- **Google's unpaid tier** can use prompts and replies to improve Google's
  products, including human review.
- **Google's terms for EU users:** as far as I know, the Gemini API terms
  require the paid tier when serving users in the EEA, UK or Switzerland.
  You operate from the Netherlands, so verify this.
- **OpenRouter** passes prompts to many upstream providers. Some are outside
  the EU, including Chinese ones. Some free endpoints log or train on data.
- **Web search:** the relay sends queries through SearXNG
  (`server/lib/web_search.dart`) to outside search engines. This is not
  mentioned.
- **"Luma Support" chat** goes to Mistral. This is not mentioned.

**What the policy needs:** name each of these services, say what they can do
with the data, and describe the transfers outside the EU.

### 3. Basic GDPR requirements are missing (Dutch operator)

> **Deferred** until the app is publicly launched (owner's decision,
> September 30, 2026).

The privacy policy is missing the information GDPR Art. 13 requires.

- [ ] **Your identity:** the name and address of the controller. An email
  address alone is not enough.
- [ ] **Legal basis for each kind of processing:**
  - the account, sync, family and chat → contract
  - abuse and security logs → legitimate interest
  - optional features → consent, where relevant
- [ ] **The right to complain** to the Autoriteit Persoonsgegevens.
- [ ] **Services that process data for you:**
  - Cloudflare (tunnel)
  - Resend (verification email)
  - SMTP provider (invites)
  - the AI upstreams from item 2
  - GitHub
- [ ] **International transfers:** which of those services are outside the
  EU, and on what legal basis (for example, the EU–US Data Privacy
  Framework or standard contractual clauses).
- [ ] **Real retention periods.** "Security logs … are kept for a bounded
  period" is too vague. Give actual periods.
- [ ] **Age limit.**
  - `TERMS.md` says 13.
  - In the Netherlands, consent-based processing needs age 16 (UAVG art. 5).
  - Most processing here rests on contract, so this is grey rather than a
    clear violation. Still, either raise the age to 16 or explain why 13 is
    enough.

### 4. Account deletion leaves data behind

- [x] Make `_tearDownAccount` remove everything tied to the user, and update
  the policy to say exactly what stays. Done September 30, 2026: each store
  has a `deleteUser`, `Store.forgetUser` scrubs the email, and
  `server/test/account_deletion_test.dart` covers it.
- [x] Drop the mandatory reason from deletion requests (server and app).
- [ ] When you decline a deletion request, give the legal ground in the
  note.

`_tearDownAccount` (`server/lib/api.dart:2101`) does **not** remove:

- public recipes, reviews and their photos (`server/lib/recipe_store.dart`)
- family memberships and invites (`server/lib/family_store.dart`)
- Secure Chat public keys and queued messages (`server/lib/chat_store.dart`)
- AI usage records (`server/lib/ai_usage_store.dart`)
- Subway Builder data (`server/lib/subway_store.dart`)

After deletion, the activity log keeps the email in plain text:
`'$email deleted their account'`.

The "request deletion" flow (`_requestAccountDeletion`) has two problems:

- It **requires a reason**. GDPR Art. 17 does not.
- It lets the operator **decline**. A refusal is only allowed on specific
  Art. 17(3) grounds.

### 5. Syncfusion is commercial software

> **In progress:** Community License applied for (September 30, 2026);
> waiting for the verification email.

- [ ] Register a Syncfusion Community License if you qualify: under
  $1M revenue and 5 developers or fewer.
- [ ] Otherwise, replace it (for example with `pdf` or `pdfrx`).

`syncfusion_flutter_pdf` is used in:

- `lib/features/plugins/installed/file_viewer/document_extractors.dart`
- `lib/features/plugins/installed/school/logic/quiz_pdf.dart`
- `lib/features/plugins/installed/small_games/bingo_card_export.dart`
- `lib/finance/import/buut_parser.dart`

---

## 🟠 Medium: grey areas

### 6. The privacy policy's third-party table is incomplete

- [ ] Add each service below, with what it receives.

**Services the table does not list:**

| Feature | Service | What it receives |
|---|---|---|
| Sign in (server) | Google, GitHub OAuth | Email, profile (`server/lib/oauth.dart`) |
| Account Overview | Google OAuth + YouTube Analytics | Channel analytics (`account_overview/youtube_oauth.dart`) |
| Account Overview | Spotify Web API | The user's own Spotify data |
| Account Overview | CurseForge API, PlanetMinecraft (scraped) | Member name |
| Steam Tools | Steam Web API | User's API key and SteamID |
| Steam Tools | IsThereAnyDeal (via the luma server) | App IDs |
| Steam Tools | jsDelivr (CSGO-API), Steam Community Market | Item lookups |
| Minecraft Launcher | mc-heads.net | Minecraft UUID (avatar) |
| Minecraft Launcher | CurseForge, Adoptium, Fabric/Quilt/Forge/NeoForge metadata | Version lookups |
| Transport Tracker | aisstream.io | User's API key, map area |
| Transport Tracker | gtfs.ovapi.nl | Transit data requests |
| Transport Tracker, Subway Builder | OpenFreeMap tiles | IP address, map position |
| Gallery | Hugging Face | One-time model download |
| Media Downloader | GitHub (yt-dlp), gyan.dev (ffmpeg), YouTube | Video URLs |
| Price Tracker | Any URL the user pastes | Request sent as if from Chrome |
| Finance | ECB | Exchange-rate fetch |
| Recipe Book | luma server (public catalogue) | Recipes, reviews and photos, visible to every user |
| AI Assistant | Mistral ("Luma Support"), SearXNG web search | Prompts and search queries |

**Other statements that contradict the code:**

- **Google data rules.** For YouTube Analytics, Google's API Services User
  Data Policy requires:
  - an explicit "Limited Use" statement in the privacy policy
  - OAuth app verification for the sensitive scope
- **What an account needs.** The policy says only an email and password.
  Google and GitHub sign-in also exist.
- **Family sharing.** The policy calls it "the one deliberately plain-text
  feature". Public recipes are also plain text and visible to everyone.

### 7. Scraping

- [ ] Look into licensing or official APIs.
- [ ] At minimum, stop pretending to be a browser, respect `robots.txt`,
  and keep request rates low.

**`supermarket-db/` scrapes:**

- Albert Heijn's mobile API (`src/supermarkets/ah/ahClient.js`)
- Jumbo and Hoogvliet, using Playwright
- Lidl
- Picnic

The results are served to users as a paid-tier (Nova) feature through
`groceries.luma-app.cc`.

**Why it's risky:**

- The EU sui generis database right (in the Netherlands, the Databankenwet)
  protects supermarket product databases.
- *Ryanair v PR Aviation* (CJEU C-30/14) means a site's terms that ban
  scraping can be enforced even against a database without that protection.
- Making money from the data increases the exposure.

**Smaller versions of the same risk:**

- Price Tracker (`price_tracker/price_scraper.dart`) sends a fake Chrome
  user agent.
- PlanetMinecraft member pages are scraped (`account_overview/pmc_extract.dart`).
- The Steam Community Market is scraped.

### 8. EU Digital Services Act (you host user content)

User content you host:

- public recipes, reviews and photos
- Cloud Files
- Secure Chat
- Family sharing

The DSA applies to hosting services. Micro and small companies are exempt
from some duties, but not these:

- [x] **Contact point (Art. 11–12).** Covered by `customerservice@luma-app.cc`.
- [ ] **Notice and action (Art. 16).** Add a way to report a specific piece
  of content in the app. The public recipe catalogue needs it most.
- [ ] **Statement of reasons (Art. 17).** Tell a user why their content was
  removed or their account restricted.
- [ ] **Moderation rules in the Terms (Art. 14).** Describe how you moderate.

### 9. Trademarks and names

- [ ] **"luma"** clashes with Luma AI (Luma Labs) and Luma (lu.ma). Search
  EUIPO and TMview in classes 9 and 42 before building more on the name.
- [ ] **Plugin names that match existing commercial games:**
  - "Airline Tycoon" (Spellbound / Kalypso)
  - "Subway Builder" (a 2025 game)
  - "Space Colony" (Firefly Studios)
- [ ] **"Minecraft Launcher"** is Mojang's own product name. Minecraft's
  usage guidelines don't allow using the mark as a product name that
  implies it's official. Rename it (for example "Launcher for Minecraft")
  and add: *"Not an official Minecraft product. Not approved by or
  associated with Mojang or Microsoft."*
- [ ] **Text Library's Minecraft-style hall:** add the same disclaimer.
- [ ] **Vendor logos** in `assets/images/vendors/` and the AI leaderboard
  are fine as nominative use, as long as nothing implies endorsement.
- [ ] **README "modeled after the Modrinth app":** fine as a description,
  but don't copy their branding or distinctive visual style one-to-one.

### 10. Microsoft / Minecraft sign-in

- [ ] Confirm the Azure app registration behind `MICROSOFT_CLIENT_ID`
  (`minecraft_launcher/logic/microsoft_auth_client.dart:59`) is **approved by
  Mojang** for the Minecraft services API. Mojang requires an application
  form for new third-party launchers.

Offline accounts are already limited to devices where a Microsoft account
that owns the game has signed in (`minecraft_launcher_repository.dart:53`).
That part is fine.

---

## 🟡 Low: tidy-ups

### 11. Terms wording (`TERMS.md`)

- [ ] **Reverse engineering.** The ban can't override the EU Software
  Directive (art. 5(3) and 6). Add "except where applicable law permits
  it."
- [ ] **Unfair-terms risk.** These are grey under the EU Unfair Contract
  Terms Directive (and the Dutch "grey list"):
  - "Continuing to use luma … means you accept the updated Terms." Consider
    active re-acceptance for account holders.
  - Capping liability at €0 for free users.
  - The one-sided indemnity.
- [ ] **Terms aren't shown before use.** They say they bind anyone who
  downloads or uses the app. But people who never make an account never
  see them. Signup only has "By continuing you agree"
  (`lib/account/login_page.dart:2067`).
- [ ] **Plugin counts disagree.** The Terms say 27 plugins, the README 26,
  and `plugins/registry.json` lists about 40. Use "optional plugins" with
  no number.
- [ ] **No moderation section** (see item 8).

### 12. The public repo contains third-party material

- [ ] **No `LICENSE` file.** That's consistent with the "all rights
  reserved" position in the Terms. Consider adding a short `LICENSE` that
  says so explicitly.
- [ ] **Third-party skills.** `.claude/skills/` and `.agents/skills/`
  contain skills written by others. Only `ui-styling` includes a licence.
  Check each one's licence, or stop tracking them.
- [ ] **`zip/*.zip`.** These are AI model outputs. Check what's in them and
  whether they belong in a public repo.
- [ ] **Screenshots and scratch files** at the repo root: `full.png`,
  `01_initial.png`, `pc_prompt.txt`, `e.txt`. Check them for personal data.

### 13. Third-party licence notices

`lib/app/third_party_licenses.dart` covers MapLibre and three.js.

- [ ] **Gallery ONNX models** (downloaded at runtime; attribution is good
  practice):
  - MobileNetV2: Apache-2.0
  - Ultra-Light-Fast RFB-320: MIT
  - OpenCV SFace: Apache-2.0
- [ ] **ffmpeg.** Keep downloading it at runtime. The gyan.dev build is
  **GPL**, so never bundle it in the installer or APK.
- [ ] **OpenStreetMap attribution** is required by its licence (ODbL).
  - Subway Builder: compact attribution is on. Fine.
  - Transport Tracker: the default is turned off and a compact one added
    back. Fine, but keep it visible.
- [x] **Natural Earth** (`assets/world/`) is public domain.
- [x] **three.js** is documented in `assets/airline_tycoon/scene/LICENSES.md`.

### 14. Face recognition in Gallery

- [ ] Make sure face data never syncs.

SFace face embeddings are biometric data. On-device-only processing is fine,
because users processing their own photos are exempt from GDPR (the
household exemption).

If face data ever reaches a server, three things change:

- GDPR Art. 9 (special-category data) applies.
- US laws like Illinois BIPA can apply.
- You'd need explicit consent.

### 15. Smaller items

- [ ] **Kinetic Hosting affiliate link**
  (`minecraft_launcher/ui/servers_tab.dart:8`). The card already says it
  "supports luma", which is disclosure. A clear "Ad" or "Partner" label
  would fully meet the Dutch advertising code (Reclamecode).
- [ ] **Artificial Analysis** data (used in the AI leaderboard). Its free API
  tier requires visible attribution. Check the leaderboard shows it.
- [ ] **`SECURITY.md`** still says "Owner action required". Publish a real
  way to report vulnerabilities (GitHub private reporting or an email).
- [ ] **Privacy Policy "Last updated" date** is September 12, 2026. Update it
  and notify users in the app once the fixes above land (the policy
  promises that notice itself).
- [ ] **Encryption export controls.** Low risk: publicly available,
  mass-market encryption. No action needed normally.

---

## Already in good shape

- Offline Minecraft accounts require a Minecraft-owning Microsoft account
  first.
- No Mojang assets are bundled. Textures are read from the user's own
  install.
- The server-access gate stops any server traffic before an account is
  approved.
- The rate limiter uses only the last `X-Forwarded-For` entry and doesn't
  store IP addresses long-term.
- API keys you bring yourself (AI providers, Steam, AIS) are stored locally,
  encrypted, and sent only to that provider.
- There's no analytics, advertising or crash-reporting SDK. That matches the
  privacy policy.
- The Terms already have:
  - an abuse-reporting channel
  - a disclaimer that AI output isn't professional advice
  - a governing-law clause (Netherlands)
