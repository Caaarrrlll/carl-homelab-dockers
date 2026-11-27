# Privacy comparison: Discord vs Fluxer (hosted)

ROADMAP item 23, **part 1** (2026-11-27): Discord's latest privacy policy
compared with Fluxer's **hosted** service (fluxer.com, formerly fluxer.app).
Stoat (hosted) and self-hosted fluxer-aio are later parts.

Research from the published documents only; nothing was tested. Each row
says what the documents state; "not stated" means the documents read say
nothing about it.

## Documents read

| Service | Documents | Dates |
|---|---|---|
| Discord | [Privacy Policy](https://discord.com/privacy), compared with the [previous version](https://discord.com/terms/privacy-policy-september-2025) | Effective 2026-12-15 (last updated 2026-11-23); previous effective 2025-09-29 |
| Fluxer | [Privacy](https://fluxer.com/privacy), [Terms](https://fluxer.com/terms), [AI stance](https://fluxer.com/ai-stance), [Security](https://fluxer.com/security), [Company information](https://fluxer.com/company-information), [Licenses](https://fluxer.com/licenses) | Privacy effective 2026-11-03 (updated 2026-11-07); Terms effective 2026-11-03 |

## Comparison

| Topic | Discord (from 2026-12-15) | Fluxer (hosted) |
|---|---|---|
| **Operator and law** | Discord (US company; EU users have a Netherlands entity). Policy text names no hosting provider any more (the old one named Google Cloud). | Fluxer Platform AB, Sweden; Swedish law; supervised by IMY (Swedish data protection authority). |
| **Where data is stored** | Not stated in detail (international transfers under EU/UK safeguards). | Mostly **Vultr, New Jersey (US)**; mobile crash reports at Hetzner, Finland. Data may be processed in the US and Canada; the US CLOUD Act exposure is acknowledged. |
| **Account data** | Account details, birthday/age information; payment details incl. tax information in some cases. | Email or display name; date of birth asked right after sign-up; payments via Stripe (no full card numbers). Phone number only if anti-abuse asks for a text check. |
| **Device / IP** | IP and device information, also used to work out your region for age rules. With sponsored content: **device ID and advertising ID** (IDFA / Android Ad ID). | IP, device, browser and OS. No advertising IDs mentioned. |
| **Analytics / telemetry** | Usage information for product improvement; ad interaction data (impressions, clicks, conversions) from partners. | Web and desktop apps send **no** usage analytics, screen tracking or crash reports. Mobile crash reports are **opt-in** (off by default). Exception: web/desktop send peer-to-peer call-connection reports by default (incl. IP and country). |
| **Age checks** | Age assurance through third-party providers (selfie, ID document or credit card; Discord keeps only the age or age group), plus an **age-estimation model** and age-signal logs kept for legal compliance. | **Never** asks for ID documents, selfies, face videos, facial age estimation or biometrics. UK and Brazil only: optional "unlock mature content" via Apple's / Google's age signal (only "18 or older" is passed on). |
| **Ads and tracking** | Sponsored content (e.g. Quests); outside consent regions **personalized by default** (you can turn it off); information shared with advertising and measurement partners. Discord states it doesn't sell personal information. | **No ads**, no advertising partners, no third-party analytics, no tracking pixels, no fingerprinting. One necessary cookie on the website. Honors Global Privacy Control. |
| **AI / machine learning** | Content and information used for automated safety systems and to "develop features or machine learning models"; models for age groups and for ranking (e.g. notifications). A setting limits use for improvement and ML. No statement about training generative AI. | Content is **never** used to train, fine-tune or evaluate AI/ML models; no generative AI or LLM over messages, files or calls. Only ML: an image classifier (OpenNSFW2) on Fluxer's own servers to flag explicit images. Spam checks are rule-based; people make enforcement decisions. |
| **Message encryption** | Text messages not end-to-end encrypted (not stated as such). | **Not end-to-end encrypted**: "our own systems can technically access the message content and call media". E2EE for calls, DMs and group DMs is on their roadmap, not launched. |
| **Voice / video** | Voice and video "designed to be end-to-end encrypted"; Discord "generally does not access or store" call contents, except Clips and saved live-stream moments that users create. | Call media encrypted in transit (**not** end-to-end). Peer-to-peer calls: the other people in the call see your IP. Screen-share preview thumbnails kept up to 24 hours. |
| **Sharing** | Vendors (no longer named), advertising and analytics partners, related companies, age-verification providers (must delete), parents via Family Center, other gaming platforms and child-safety task forces when enforcing rules, and server content visible in search engines if a server opts in. | Named vendors only: Vultr, Hetzner, Stripe, EBANX (Brazil), Apple/Google (push, store payments, age signals), Klipy (GIF search, relayed so it never sees your IP), YouTube embeds; plus an EU email provider and an SMS provider. No affiliates named. Confirmed child-abuse material is reported to NCMEC. |
| **Law enforcement** | When compelled by a court order or authority. | Same, and **notifies affected users before disclosing** unless the law forbids it or in an emergency. No transparency report yet (planned). |
| **Retention** | Until no longer needed; account deletion deletes identifying information and anonymizes the rest; age-signal logs and transaction records kept for legal reasons. | Deleted messages leave active use within minutes, gone from encrypted backups within 30 days; deleted media within 24 h; account deletion after a 14-day grace period (messages stay, without name or profile); accounts inactive 2 years may be deleted; logs up to 90 days; payment records 7 years (Swedish bookkeeping law). |
| **Your rights** | Data request and account deletion in settings; GDPR/UK rights for those regions. | Access, correction, erasure, restriction, objection, portability (JSON ZIP export), withdrawal of consent, human review of automated decisions; answers usually within 30 days. |
| **Business model** | Paid subscription (Nitro) plus sponsored content and ads. | Paid plan (Plutonium), Operator Pass and donations; "no venture capital and no outside investors". The no-ads statement is current policy, **not** a binding promise; material policy changes need 30 days' notice. |
| **Open source / self-host** | No. | AGPL-3.0; self-hosting is free with no reduced edition (that is what fluxer-aio runs). |

## Findings

**Where Fluxer is clearly better for a privacy-focused group:**

1. No ads, no ad tracking, no advertising IDs, no third-party analytics
   (Discord: personalized sponsored content by default in many regions).
2. No content used for AI/ML training, stated in the terms
   (Discord: content and information used to develop ML models).
3. No ID, selfie or face checks at all (Discord: third-party age checks and
   an age-estimation model).
4. Short, concrete retention periods, named vendors, and a promise to tell
   users before handing data to authorities.
5. Small, independently funded operator under Swedish/EU law, and the code
   is open source, so we can leave the hosted service for our own server
   without changing apps.

**Where Fluxer is weaker or the same:**

1. **Encryption:** nothing is end-to-end encrypted yet; Fluxer's own systems
   can read messages and call media. Discord's voice/video are designed to
   be end-to-end encrypted, so for **calls** Discord is currently stronger.
   Text messages are readable by the operator on both.
2. **Hosting location:** the hosted service stores data in the US (Vultr),
   so US law (CLOUD Act) applies to the data, much like with Discord.
3. **Peer-to-peer calls** expose your IP to the others in the call, and
   web/desktop send call-connection reports (with IP) by default.
4. **No-ads promise** is a statement of current policy, not a contractual
   guarantee; it could change with 30 days' notice. The policy is also very
   new (November 2026) and there is no transparency report yet.

**Part 1 conclusion:** for privacy, hosted Fluxer is a clear step up from
Discord on ads, tracking, AI use and age checks, but not on encryption
(calls are better protected on Discord today) or on where the data lives.
Self-hosting (part 3) is the way to address hosting location and operator
access, since the data would then be on our own server.

## Not checked yet

- Fluxer pages linked but not read: hosting help, regional restrictions,
  roadmap (E2EE timeline), self-host, push relay (whether self-hosted
  instances still send push notifications through Fluxer), changelog.
- Discord's age-estimation explainer and local-laws page.
- **Part 2:** Stoat (hosted). **Part 3:** self-hosted fluxer-aio, incl.
  which parts still depend on upstream services.
