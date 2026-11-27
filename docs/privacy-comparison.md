# Privacy comparison: Discord vs Fluxer vs Stoat (hosted), and self-hosted Fluxer

ROADMAP item 23. **Part 1** (2026-11-27): Discord's latest privacy policy
compared with Fluxer's **hosted** service (fluxer.com, formerly fluxer.app).
**Part 2** (2026-11-27): Stoat's hosted service (stoat.chat, formerly
Revolt) added. **Part 3** (2026-11-27): what a self-hosted Fluxer (our
`fluxer-aio` image) still sends to outside services.

Research from the published documents only; nothing was tested. Each cell
says what the documents state; "not stated" means the documents read say
nothing about it.

## Documents read

| Service | Documents | Dates |
|---|---|---|
| Discord | [Privacy Policy](https://discord.com/privacy), compared with the [previous version](https://discord.com/terms/privacy-policy-september-2025) | Effective 2026-12-15 (last updated 2026-11-23); previous effective 2025-09-29 |
| Fluxer | [Privacy](https://fluxer.com/privacy), [Terms](https://fluxer.com/terms), [AI stance](https://fluxer.com/ai-stance), [Security](https://fluxer.com/security), [Company information](https://fluxer.com/company-information), [Licenses](https://fluxer.com/licenses) | Privacy effective 2026-11-03 (updated 2026-11-07); Terms effective 2026-11-03 |
| Stoat | [Privacy](https://stoat.chat/legal/privacy) + [Stoat supplement](https://stoat.chat/legal/privacy-stoat-supplement), [Terms](https://stoat.chat/legal/terms) + [Stoat supplement](https://stoat.chat/legal/terms-stoat-supplement), [Imprint](https://stoat.chat/legal/imprint), [About](https://stoat.chat/about) | Base documents updated 2026-06-30; Stoat supplements effective 2026-07-30 |

## Comparison

| Topic | Discord (from 2026-12-15) | Fluxer (hosted) | Stoat (hosted) |
|---|---|---|---|
| **Operator and law** | Discord (US company; EU users have a Netherlands entity). | Fluxer Platform AB, Sweden; Swedish law; supervised by IMY (Swedish data protection authority). | Revolt Platforms Ltd, England and Wales; English law; complaints to the UK ICO. The documents still use the Revolt name. The operator also runs a second service (Gifbox). |
| **Where data is stored** | Not stated in detail (international transfers under EU/UK safeguards). | Mostly **Vultr, New Jersey (US)**; mobile crash reports at Hetzner, Finland. US CLOUD Act exposure acknowledged. | **EU** cloud providers (Hetzner, Ionos; media on Backblaze), possibly the UK; voice/video may use servers in other countries. Providers or regions may change **without advance notice**. |
| **Account data** | Account details, birthday/age information; payment details incl. tax information in some cases. | Email or display name; date of birth; payments via Stripe (no full card numbers). Phone number only for some anti-abuse checks. | Email, hashed password, username, date of birth; server names. Payment data not stated. |
| **Device / IP** | IP and device information, also used for region and age rules. With sponsored content: **device ID and advertising ID** (IDFA / Android Ad ID). | IP, device, browser and OS. No advertising IDs mentioned. | IP and a short device description per session. No advertising IDs mentioned. |
| **Analytics / telemetry** | Usage information for product improvement; ad interaction data (impressions, clicks, conversions) from partners. | Web and desktop: **no** usage analytics or crash reports. Mobile crash reports **opt-in**. Exception: peer-to-peer call-connection reports (incl. IP) sent by default from web/desktop. | Not stated. hCaptcha (US company) runs anti-bot checks. |
| **Age checks** | Third-party age assurance (selfie, ID or credit card; Discord keeps only the age or age group), an **age-estimation model**, age-signal logs. | **Never** asks for ID, selfies, face scans or biometrics. UK/Brazil only: optional Apple/Google age signal ("18 or older" only). | Date of birth only; no ID or face checks stated. |
| **Ads and tracking** | Sponsored content (e.g. Quests); outside consent regions **personalized by default** (can be turned off); shares with advertising and measurement partners. States it doesn't sell personal information. | **No ads**, no ad partners, no third-party analytics, no tracking pixels, no fingerprinting. Honors Global Privacy Control. | "**NEVER** sell your data"; "no ads" on the About page (marketing, not in the terms). Tracking not stated. |
| **AI / machine learning** | Information used for automated safety systems and to "develop features or machine learning models"; age and ranking models. A setting limits use for improvement and ML. | Content **never** used to train, fine-tune or evaluate AI/ML (in the terms); no LLMs over content. Only an on-server image classifier for explicit images. | **Not stated** at all. |
| **Message encryption** | Text messages not end-to-end encrypted. | **Not** end-to-end encrypted; the operator can read messages and call media. E2EE on the roadmap. | **Not stated** (no E2EE claim). "Encrypted backups" mentioned without detail. |
| **Voice / video** | "Designed to be end-to-end encrypted"; "generally does not access or store" call contents, except user-made Clips. | Encrypted in transit (**not** end-to-end). Peer-to-peer calls show your IP to the others in the call. Screen-share thumbnails kept up to 24 h. | Storage and encryption **not stated**. |
| **Sharing** | Vendors (no longer named), advertising/analytics partners, related companies, age-verification providers, parents via Family Center, gaming platforms and child-safety task forces, search engines for opted-in servers. | Named vendors only (Vultr, Hetzner, Stripe, EBANX, Apple/Google, Klipy relayed, YouTube embeds, an EU email and an SMS provider). No affiliates. CSAM reported to NCMEC. | Named: Cloudflare, Hetzner, Ionos, Backblaze, Scaleway (email), hCaptcha. May transfer to affiliates or in a sale or merger. |
| **Law enforcement** | When compelled by a court order or authority. | Same, and **notifies users before disclosing** unless forbidden or an emergency. Transparency report planned. | "Only if absolutely necessary" for valid legal process or to prevent harm. User notification and transparency reports not stated. |
| **Retention** | Until no longer needed; account deletion removes identifying information and anonymizes the rest; some logs kept for legal reasons. | Concrete: deleted messages out of backups within 30 days; media within 24 h; account deletion after 14 days; inactive accounts after 2 years; logs 90 days; payment records 7 years. | **Not stated** (no periods). Delete via the app or by contacting them. |
| **Your rights** | Data request and account deletion in settings; GDPR/UK rights for those regions. | Full GDPR rights; in-app JSON export; answers usually within 30 days. | GDPR/UK GDPR rights by email; in-app export not stated. |
| **Business model** | Paid subscription (Nitro) plus sponsored content and ads. | Paid plan, Operator Pass, donations; **no investors**. No-ads statement is current policy, not binding; 30 days' notice for changes. | **Not stated** in the documents. No-ads only as marketing; changes typically after 30 days, accepted by continuing to use it. |
| **Open source / self-host** | No. | AGPL-3.0; self-hosting free, full edition (what fluxer-aio runs). | Open source (licence not stated in the pages read); self-hosting possible. |

## Findings

**Discord vs Fluxer (part 1):**

- Fluxer is clearly better on ads, tracking, AI use, age checks and
  transparency (concrete retention, named vendors, users told before data
  goes to authorities, funded without investors, open source).
- Fluxer is weaker on **encryption** (nothing end-to-end encrypted yet;
  Discord's voice/video is) and its hosted data is in the **US**.
- Smaller points: peer-to-peer calls show your IP to others in the call,
  and the no-ads statement is policy, not a contract.

**Stoat vs Fluxer (part 2):**

- **Stoat's one clear advantage: data location.** Its data is in the EU
  (and possibly the UK) instead of the US, so the US CLOUD Act concern
  mostly falls away. It can change providers or regions without notice,
  though.
- **On encryption Stoat is no better:** it makes no end-to-end encryption
  claim and says nothing about how calls are protected.
- **Stoat's documents are much thinner:** no statement on AI use of content,
  no retention periods, no telemetry statement, no user notification before
  disclosure, no stated business model, and the no-ads claim exists only as
  marketing. None of this means Stoat does these things, but nothing
  commits it not to.
- Fluxer's documents are more specific and make more promises, several of
  them in the terms themselves (e.g. no AI training).

**Overall (hosted services):**

| Concern | Best of the three |
|---|---|
| Ads, tracking, AI use, age checks | Fluxer (Stoat probably similar, but not written down) |
| Encryption | Discord, for voice/video only; nothing is E2EE for text anywhere |
| Data location | Stoat (EU/UK) |
| Transparency and written commitments | Fluxer |

So for a privacy-focused group, hosted Fluxer is the strongest on written
commitments, and its two weak points (US hosting, no E2EE) are exactly what
**self-hosting** changes: the data sits on our own server, and only we can
read it. Part 3 checks what self-hosted fluxer-aio still sends to outside
services.

## Part 3: self-hosted Fluxer (fluxer-aio)

Sources: our own image (`images/apps/fluxer-aio`: `upstream/env/*.env`,
`rootfs/`, README, template) and Fluxer's [push relay](https://fluxer.com/push-relay),
[self-host](https://fluxer.com/selfhost), [roadmap](https://fluxer.com/roadmap)
(updated 2026-11-16) and [operator environment docs](https://docs.fluxer.com/operator/environment/).
Some defaults in the operator docs were only read as a summary; they are
marked "(per docs, unconfirmed)".

**What self-hosting fixes:** messages, files, accounts and call media sit on
our server and in our Postgres. Fluxer the company has no access and is not
the controller; there is no licence check and no reduced edition. US hosting
and "the operator can read it" now mean **us**. It is still not end-to-end
encrypted: whoever runs or breaks into the server can read content, so the
server's security and backups are now our job.

**What still leaves the server** (and who sees what):

| Part | Default in fluxer-aio | Who sees what | Our choice |
|---|---|---|---|
| **Voice: LiveKit STUN** (finding the server's public IP) | On: `stun.l.google.com` / `stun1.l.google.com` (`FLUXER_LIVEKIT_STUN_*`, `FLUXER_LIVEKIT_USE_EXTERNAL_IP=true`) | Google sees our **server's** IP, not users' or call content. | Avoid by setting the public IP (`FLUXER_LIVEKIT_NODE_IP`) with `USE_EXTERNAL_IP=false`, or point STUN at another host. |
| **Voice: peer-to-peer STUN** | Empty: no third party | Nobody; P2P calls only work between devices with a direct route. | Keep. |
| **Mobile push** (official iOS/Android apps) | Fluxer's **managed push relay** only if **both** the instance admin (`FLUXER_PUSH_SERVICE_RELAY_CONSENT_ACCEPTED`) and the user turn it on. fluxer-aio doesn't set it. | Relay: notifications are encrypted to the device and padded; Fluxer sees a hashed device ID, app, size, timing and our server's address (logs up to 90 days). Apple/Google see a device token and the encrypted blob. **Unclear:** Fluxer's privacy policy also says that on iOS (and older Android builds) Apple/Google receive sender, conversation and a message preview; which applies to self-hosted iOS is not settled. | Keep off unless the group needs phone notifications; Android's UnifiedPush build doesn't need the relay. Check the iOS case before enabling. |
| **Web/desktop push** (Web Push, VAPID keys generated by fluxer-aio) | On when a user allows notifications | Payload (title, message preview) is encrypted end to end (RFC 8291) to the browser; the browser vendor's push service (Google, Mozilla, Apple) only sees the endpoint and timing. | Fine. |
| **GIF search** (Klipy) | Off unless a key is set (`FLUXER_KLIPY_API_KEY`) | Klipy sees **search terms** and our server's IP (requests are relayed, not from users). | Our choice; we set a key earlier. Remove it to stop. |
| **YouTube embeds/previews** | Only with `FLUXER_YOUTUBE_API_KEY` | Google sees which videos are looked up, from our server; playing an embed loads YouTube in the user's browser (Google cookies). | Our choice; we set a key earlier. |
| **Link previews** (unfurl, media proxy) | On | The linked site sees **our server's** IP fetching the page, not the user's; preview images are proxied. | Exclude hosts with `FLUXER_API_UNFURL_IGNORED_HOSTS` if needed. |
| **Email** | Only if SMTP is configured | The mail provider. | Not configured today. |
| **Meilisearch analytics** | Off (`MEILI_NO_ANALYTICS=true` in our run script) | Nobody. | Keep. |
| **Bluesky sign-in, breached-password check, malware blocklists, ClamAV, Stripe, NSFW classifier** | Off (per docs, unconfirmed) | Nobody unless enabled. | Keep off. |
| **Official apps' own reporting** | Web/desktop: no analytics or crash reports; **peer-to-peer call reports** go to Fluxer by default (incl. IP and country), apparently also when signed in to another instance. Mobile crash reports opt-in, and go to Fluxer even for other instances. | Fluxer. | Ask users to leave mobile crash reports off; the P2P call reports can't be turned off per the documents read. |

**End-to-end encryption (roadmap, updated 2026-11-16):** nothing is E2EE
today. Calls: DAVE-based E2EE "in development" for 2026, with no
unencrypted fallback. DMs, group DMs and personal notes: MLS-based, an
experimental draft in 2026 and "stable in the first half of 2027", with no
setting to turn it off. Community channels: no date. These come with Fluxer
releases, so fluxer-aio gets them through the normal release bumps.

**Part 3 conclusion:** self-hosting removes both hosted-Fluxer concerns
(data location and operator access) as far as Fluxer the company goes; the
remaining outside contacts are small and mostly our choice: Google STUN
(server IP only, avoidable), Klipy and YouTube (keys we set), link-preview
fetches from our server, and push notifications only if we enable the relay.
The real remaining gap is end-to-end encryption, which only arrives with
Fluxer's roadmap (calls first, DMs in 2027).

## Not checked yet

- Fluxer pages not read: hosting help, regional restrictions, roadmap (E2EE
  timeline), self-host, push relay, changelog.
- Stoat pages not read: community guidelines, minimum-age article, licence,
  status page.
- Discord's age-estimation explainer and local-laws page.
- Part 3 open points: the iOS push conflict (relay says encrypted, the
  privacy policy says Apple/Google see a preview); the exact defaults that
  were only read as a summary; whether the desktop app fetches updates from
  Fluxer; our live instance's actual settings (read-only access can't see
  environment variables).
