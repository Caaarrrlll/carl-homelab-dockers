# Privacy comparison: Discord vs Fluxer vs Stoat (hosted)

ROADMAP item 23. **Part 1** (2026-11-27): Discord's latest privacy policy
compared with Fluxer's **hosted** service (fluxer.com, formerly fluxer.app).
**Part 2** (2026-11-27): Stoat's hosted service (stoat.chat, formerly
Revolt) added. Part 3 (self-hosted fluxer-aio) comes later.

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

## Not checked yet

- Fluxer pages not read: hosting help, regional restrictions, roadmap (E2EE
  timeline), self-host, push relay, changelog.
- Stoat pages not read: community guidelines, minimum-age article, licence,
  status page.
- Discord's age-estimation explainer and local-laws page.
- **Part 3:** self-hosted fluxer-aio, including which parts still depend on
  upstream services (push notifications, GIF search, link previews).
