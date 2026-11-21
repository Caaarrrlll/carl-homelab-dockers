# Rate Limit Tracker

Live checklist only. Completed tasks are moved to `RATE_LIMIT_TRACKER_HISTORY.md`.

**Maintenance rule:** when a task is confirmed complete, move its checklist
section to `RATE_LIMIT_TRACKER_HISTORY.md` (and its finished `ROADMAP.md` item
to `ROADMAP_HISTORY.md`) as part of the clean boundary. Don't let completed
sections pile up here.

Legend: `[ ]` pending · `[•]` in progress (list the files it touches) · `[✓]`
done and verified · `[✗]` dropped (say why) · `[⏳]` waiting on the maintainer
(live Unraid action or decision).

## Active task — fluxer-aio backup -> upgrade -> verify -> clean up (ROADMAP 17)

Decisions and validation design: ROADMAP item 17 (2026-11-21). Then merge
PR #1 as its first real test.

- [✓] 0. Postgres 18.2 on the converted server (2026-11-21) -> client 18; verification limit 10 min (maintainer: "long, but keep 10 for now").
  (`docker exec <pg-container> psql -U postgres -tAc "SHOW server_version;"`);
  confirm the 10-minute verification limit.
- [✓] 1. Image: pinned `postgresql-client-<major>` (PostgreSQL apt repo, keyring
  checked), image records its Fluxer release (`/etc/fluxer-aio/RELEASE`)
- [✓] 2. `fluxer-aio-backup`: pg_dump -Fc + secrets.env -> `/data/backups/<date>_<old>-to-<new>/`,
  validate (list + full read), SHA-256, `verified` marker; manual use too
- [✓] 3. Init: detect update, run backup, fail-closed; re-check kept backups'
  SHA-256 every start (mark `corrupt`, never delete)
- [✓] 4. Verify step: wait for health, then record release + prune (verified
  only, keep 3, never while newest unverified); time limit
- [✓] 5. Stubbed simulations (update/no-update/first start, backup fail,
  corrupt archive, bit-rot on a kept backup, retention edge cases)
  - Done 2026-11-21 (Windows Git Bash, stub pg_dump/pg_restore, real
    sha256): backup/retention/verify 35/35 PASS; init update section 15/15
    PASS (first start, same release, update, restart while unverified,
    backup failure = exit 1 + no config + release not pending, retry).
- [✓] 6. Docs: fluxer-aio README (backups, restore), docs/operations.md,
  audit, HISTORY; CI build green
  - Docs done 2026-11-21 (README Backups + restore steps, operations.md
    sections 3/4c/5/7, template overview, audit, HISTORY; selftest checks
    pg_dump/pg_restore). Pushed without [skip ci]: CI builds fluxer-aio.
  - CI run 44897925649 GREEN (5b7582a): self-test passed, pg_dump 18.7 linked.
- [⏳] 7. Live test on Unraid: (a) force update to 5b7582a = first start, no
  backup, release recorded when healthy; (b) merge PR #1, force update =
  backup + verify + prune in the log. Confirmed via read-only access.

## Active task — monthly scheduled rebuild (2026-11-21)

Maintainer decision: rebuild **all** images monthly when Debian updates
(debian -> wine -> asa + fluxer-aio; Fedora stays opt-in), since rollback is
easy (`:previous`, date/sha tags, Retag workflow). Small piece of ROADMAP
item 16; the list-driven redesign stays open there.

- [✓] 1. Monthly `schedule` (cron `23 4 2 * *`) added to build-images.yml
  - YAML parsed; `if:` conditions evaluated for event=schedule: debian,
    wine, asa, fluxer-aio (each with keep-:previous) RUN, Fedora and change
    detection skipped. AGENTS/README CI text, ROADMAP 16, HISTORY updated.
- [✓] 2. Committed with `[skip ci]` (no immediate rebuild). First scheduled
  run: 2026-12-02 04:23 UTC. Optional: a manual run (same path) to test now.
- [✓] 3. Operator runbook for anyone (maintainer request, 2026-11-21):
  `docs/operations.md` (how builds happen, manual rebuild, updating on
  Unraid, rollback incl. "monthly rebuild moves latest forward again" + pin
  by tag, Fluxer release PRs, first-time setup, troubleshooting), linked
  from README, ASA + fluxer-aio READMEs. Rule added to AGENTS.md
  (Conventions + docs-alignment row). Links checked; no agent/tool names.

## Active task — reformat Dockerfiles and scripts to the readability standard (2026-11-21)

Maintainer request: reformat every Dockerfile, `.sh`, `.bat`, `.ps1` (and the
extension-less fluxer-aio shell scripts / s6 `run` files) to their global
code-style standard: one statement per line, if/else instead of `&&`/`||`
chains where clearer, 4-space indent (repo currently mixes tabs/spaces, so
normalised to 4 spaces), long commands split one argument per line, commented
sections, Dockerfile package lists one per line and sorted, `&&` at the start
of continuation lines, LF for sh/Dockerfiles, CRLF for bat/ps1.
Scope rule (maintainer, 2026-11-21, also in their global CLAUDE.md): only
files we author ourselves; never vendored/upstream/extracted/generated or
re-downloadable files (e.g. fluxer-aio `upstream/env/*.env`, anything copied
out of Fluxer's images). Checked: every fluxer-aio file reformatted here was
written in this repo (commit b144c4a); `upstream/` untouched.
Rule: **behaviour must not change** (formatting and provably equivalent
rewrites only; ASA scripts run the live cluster).

- [✓] 1. Line endings: `.gitattributes` (sh/Dockerfile LF, bat/ps1 CRLF in the
  working tree, LF in git, so `git diff --check` keeps passing); docs note
  (CLAUDE.md "no .gitattributes" line, AGENTS/README root files)
  - Done 2026-11-21: renormalize changed nothing (all LF already); `.bat`
    gets CRLF when rewritten in step 4. CLAUDE.md also notes the code style.
- [✓] 2. Dockerfiles (debian, wine, fedora, asa, fluxer-aio) + an equivalence
  checker (instruction-by-instruction token comparison, package lists
  order-insensitive)
  - Done 2026-11-21: all 5 EQUIVALENT per the checker (scratchpad
    dfcheck.py; a tampered copy is caught); LF; fluxer-aio's ARG lines and
    release header kept for bump-release.py (10 ARGs + header found).
- [✓] 3. fluxer-aio scripts (`fluxer-aio-{env,init,healthcheck,selftest}`,
  8 s6 `run` files); `bash -n`; re-run the existing stubbed simulations
  - Done 2026-11-21 (simulated on Windows Git Bash, not in a container):
    init: old vs new transcript IDENTICAL over 8 scenarios; env: exported
    env byte-identical for all 5 services + both error paths; healthcheck:
    identical over 4 scenarios; run files: same statements (only multi-var
    `export` split, gateway `ulimit || echo` -> if). selftest: syntax only,
    real test = CI build (it runs inside the image build).
- [✓] 4. `scripts/` (`unraid-readonly.sh`, `docker-updater.sh`/`.bat`); re-run
  the read-only allowlist simulation
  - Done 2026-11-21: unraid-readonly.sh old vs new IDENTICAL over 33 cases
    (output, exit code, syslog audit; inspect template char-for-char).
    docker-updater.sh identical over 4 fake-docker scenarios.
    docker-updater.bat: the OLD file (LF) never worked in cmd.exe ("cannot
    find the batch label specified - buildpush" at the first call); the new
    CRLF file builds/pushes in order, honours BUILD_FEDORA, stops on the
    first failure (tested with a fake docker.exe). Only intended behaviour
    change of this task.
- [✓] 5. ASA scripts (`start.sh`, `start-server.sh`, `start-watchdog.sh`)
  - Done 2026-11-21 (simulated on Windows Git Bash with stubs, not on
    Unraid): start.sh old vs new IDENTICAL over 5 stop-handler scenarios
    (save ok / SaveWorld fails / no server / ignores DoExit / failing user
    script) + RCON_PORT fallback, with real SIGTERM; start-server.sh
    IDENTICAL over 6 scenarios incl. every Wine launch argument; watchdog
    same statements. Original quoting kept (unquoted vars stay unquoted).
- [✓] 6. audit.md rows (each image), HISTORY note
- [✓] 7. Maintainer chose B: `[skip ci]` commit (a1df1be) + fluxer_only build. Was: commit with a CI rebuild (verifies all Dockerfiles,
  publishes new images incl. ASA) or `[skip ci]` (images unchanged until the
  next real change)
- [✓] 7b. Local build scripts removed (maintainer, 2026-11-21): deleted
  `scripts/docker-updater.{sh,bat}`, VS Code build task; AGENTS/README/CLAUDE
  build docs and `DOCKERHUB_USER` guardrails rewritten (CI-only); ROADMAP
  item 16 + HISTORY updated; fedora audit note fixed.
- [✓] 7c. fluxer_only build of the reformatted fluxer-aio: run 44872615929
  GREEN 2026-11-21, self-test "all checks passed" (2 native modules). New
  `fluxer-aio:latest` published (formatting only; old one kept as
  `:previous`). Updating the container on Unraid is optional.
- [ ] 8. [⏳] Optional: redeploy the reformatted `unraid-readonly.sh` to Unraid
  (same behaviour; only needed to keep the copy identical)

## Active task — build `caaarrrlll/fluxer-aio` (2026-11-18)

**Status 2026-11-20:** steps 1-9 done; fluxer-aio runs healthy; release
watch live (PR #1 open). Open: step 10 (revoke the SSH key: NOT yet,
maintainer's call). ROADMAP item 16 (CI redesign) must keep the release
watch working (it relies on a push to main rebuilding fluxer-aio).
**2026-11-21:** maintainer reports the shared-Postgres conversion done.
Verified on Unraid via read-only access: fluxer-aio restarted 10:50 UTC,
`healthy`, both Rust DB pools "connected to Postgres" (database `fluxer`);
only start-up `Connection refused` errors 0.5 s after start (NATS not up yet,
retried). Next: ROADMAP item 17 (needs the new server's Postgres major
version for its `pg_dump` client), then merge PR #1.
**On hold 2026-11-20:** the maintainer is doing the shared-Postgres conversion
(separate project) first, then returns for ROADMAP item 17 (backup -> upgrade
-> verify -> clean up) before merging PR #1. After the conversion: check the
`fluxer` database/role came across and the container's Postgres settings
still match (read-only `logs`/`inspect`/`health`).

Fluxer in one Unraid container, using the maintainer's existing Postgres 18, Redis and
Caddy (reached via the host IP). Research and decisions:
`RATE_LIMIT_TRACKER_HISTORY.md` ("Fluxer / Stoat"). Upstream reference:
release `2026.1118.90548` compose bundle (official images pinned by digest).

- [✓] 1. Read-only Unraid access (revocable SSH key)
  - [✓] 1a. `scripts/unraid-readonly.sh` written (2026-11-18)
    - Allows: help, ps, logs <c> [1-2000], inspect <c> (no env), stats,
      ls [subpath] under /mnt/user/appdata/fluxer-aio, health (`/_health` on the host port mapped to container 8080).
      Containers: fluxer-aio, Caddy, Redis. Requests logged to syslog (tag
      `claude-readonly`).
    - Verified: `bash -n`, LF-only; stubbed simulation (27 cases): allowed
      requests reach docker/curl stubs; refused: other commands/containers,
      `;` `$()` newline, `..`, extra args, line limits, symlink escape.
      Simulated on Windows Git Bash, not tested on Unraid.
  - Key generated by maintainer 2026-11-18 (ed25519, no passphrase; path in
    Claude's memory, not here).
  - Script handed over via the maintainer's network share (not committed at
    the time, maintainer's choice); sha256 checked on arrival.
  - Installed by maintainer 2026-11-18: script at
    `/boot/config/claude-readonly/` (sha256 matched), key line in
    `/root/.ssh/authorized_keys` (-> `/boot/config/ssh/root/`, persists).
  - Live checks 2026-11-18 (via the key): ps, logs, stats, plain login (help
    only) OK; `uname -a`, a non-allowlisted container, port forward refused.
    Bug: `inspect` failed on containers without a healthcheck -> fixed
    (`index .State "Health"`); `health` first used a hard-coded host port.
  - [✓] 1b. Installed + verified on Unraid via read-only access (2026-11-18)
    - Fixed script re-copied (sha256 matched); `inspect` OK without env;
      `health` -> nothing listening yet (expected).
      Syslog shows sshd forced-command sessions + `claude-readonly` entries.
    - Redaction pass (maintainer rule): `health` now looks up the host port
      with `docker port fluxer-aio 8080/tcp`, so the script holds no
      server-specific port. Re-copied and verified on Unraid via read-only
      access 2026-11-18 (`health` -> "port 8080/tcp is not published").
  - [✓] 1c. Docs: CLAUDE.md (read-only access bullet), AGENTS supporting files,
    README layout (2026-11-18)
- [✓] 2. Map the upstream images (2026-11-18, release 2026.1118.90548; registry
  configs + small layers read from ghcr, compose bundle read; nothing run)
  - All Debian trixie (same glibc as our debian-base) except fluxer-static
    (Alpine; only its files + Caddyfile are needed). What to copy:
    - api (`fluxer-api@sha256:35b9…a2c3`): Node 26.13.0 (`/usr/local/bin/node`
      + `/usr/local/lib/node_modules`, layer 2), app `/usr/src/app/fluxer_api`
      (`node_modules` etc. layer 6, `dist` layer 7, `bin`), `/usr/src/app/tsconfigs`.
      Run `node dist/AppEntrypoint.js`; worker = `dist/WorkerEntrypoint.js` or
      `FLUXER_API_EMBEDDED_WORKER=true`. Needs ca-certificates; `/run/fluxer`
      (0700). Health `GET /_health` on its port.
    - gateway (`fluxer-gateway@sha256:824b…313b`): `/opt/fluxer_gateway`
      release incl. its own ERTS (erts-16.4.0.7), so the 79 MB OTP layer is
      not needed. Needs ca-certificates, curl, libstdc++6. Start
      `bin/docker_entrypoint.sh` (sizes schedulers, requires
      `FLUXER_ERLANG_COOKIE`; `FLUXER_ERLANG_NODE_NAME` default
      `fluxer_gateway@127.0.0.1`, dist port `FLUXER_ERLANG_DIST_PORT` 8081,
      epmd 4369). nofile 65536. Health `GET /_health/ready`.
    - media-proxy (`fluxer-media-proxy@sha256:2742…ec65`): binary
      `/usr/local/bin/fluxer-media-proxy` + own libs `/usr/local/lib`
      (custom libheif; run `ldconfig`). apt: tini libcurl4t64 libvips42t64
      libwebp7 libwebpmux3 libwebpdemux2 liblcms2-2 libyuv0 libde265-0
      libdav1d7 libaom3 libjemalloc2, then `rm -f /usr/lib/*/libheif.so.1*`.
      Env LD_PRELOAD=libjemalloc.so.2, MALLOC_CONF, VIPS_CONCURRENCY=1,
      VIPS_DISC_THRESHOLD=1g. Health `fluxer-media-proxy healthcheck`.
    - fluxer-server (`fluxer-server@sha256:43b5…e44`): `/usr/local/bin/fluxer-server`
      + web app `/srv/app/static` (250 MB). apt: libjemalloc2. Runs
      snowflakes,users,messages,gifs,unfurl,push,app-proxy,admin
      (`FLUXER_SERVER_SERVICES`); ports via `FLUXER_SERVER_<SVC>__...` (bundle:
      svc 18090-18094, admin 18083, app-proxy 8080). Health `fluxer-server healthcheck`.
    - static (`fluxer-static@sha256:144c…1d263`): `/srv/fluxer-static`
      (avatars, badges, desktop incl. spellcheck dictionaries, email, emoji,
      web) + its Caddyfile (file_server, `/_health`, cache headers); serve from
      the internal router Caddy instead of a second Caddy. MIME: Debian
      `media-types` instead of Alpine `mailcap`.
    - NATS 2.14 (JetStream `store_dir`, http 8222 `/healthz`), Meilisearch
      v1.53 (`/meili_data`, `/health`), LiveKit v1.12.0 (config via
      `LIVEKIT_CONFIG`/`LIVEKIT_KEYS`, webhook -> api `/webhooks/livekit`).
  - Compose wiring: 188 shared env vars (`x-fluxer-env`); internal addresses
    to rewrite to 127.0.0.1: `FLUXER_INTERNAL_API_ENDPOINT`,
    `FLUXER_INTERNAL_MEDIA_PROXY_ENDPOINT`, `FLUXER_LIVEKIT_INTERNAL_URL`,
    `FLUXER_NATS_URL`, `FLUXER_SEARCH_URL`, `FLUXER_KV_URL` (external Redis),
    admin/unfurl endpoints in rust-server env, LiveKit webhook URL.
  - Filesystem uploads: `FLUXER_STORAGE_BACKEND=filesystem`,
    `FLUXER_STORAGE_ROOT`, media-proxy `FLUXER_MEDIA_PROXY_STORAGE_BACKEND=local`
    + `_STORAGE_ROOT`; init creates `.staging/{tmp,multipart,trash}`, `.meta`,
    `.layout` = `{"v":1}`; `FLUXER_S3_ENDPOINT` must be empty.
  - Open for step 3: run everything as one configurable UID/GID (upstream
    uses 65532 and 10001); exact `NEEDED` libs of node native modules
    unverified (only provable by CI build + first start).
- [✓] 3. Image `images/apps/fluxer-aio/` (written + simulated; first real test is the CI build in step 5)
  - [✓] 3a. Dockerfile + upstream pin/generator (2026-11-18; not built yet)
    - `Dockerfile`: FROM debian-base; `COPY --from` upstream images pinned by
      digest; s6-overlay 3.2.3.2 + Meilisearch 1.53.0 glibc binary with
      SHA-256 checks (Meilisearch image is musl-linked; NATS, LiveKit, Caddy
      verified static); build-time `fluxer-aio-selftest` (ldd etc.).
    - `upstream/RELEASE` (bundle URL + sha256), `upstream/gen-env.py`
      (stdlib-only compose -> `KEY=EXPR` env files; rewrites internal
      addresses to 127.0.0.1 ports; hoists brace-containing defaults to
      `!literal` lines because bash ends `${A:-{..}}` at the first `}`),
      `upstream/env/{api,worker,gateway,media-proxy,rust}.env` (224/223/237/
      244/470 vars). Prototype eval in bash: all OK, no stray braces.
  - [✓] 3b. s6-overlay services (2026-11-18): oneshot `init-fluxer-aio`;
    longruns svc-{nats,meilisearch,livekit,caddy,media-proxy,fluxer-server,
    api,gateway} with start order nats -> fluxer-server -> api -> gateway;
    log lines prefixed per service. `bash -n` OK.
  - [✓] 3c. Start-up + runtime scripts (2026-11-18; simulated on Windows Git
    Bash with stubbed user/chown/install, real openssl; not run in a container)
    - `fluxer-aio-init`: required settings check, homelab pool defaults,
      user/`/data` layout + object-store `.layout`, 16 secrets generated once
      into `/data/secrets.env` (env wins, warns on mismatch), VAPID pair
      validated, setup token logged once, NATS/LiveKit config. Scenarios:
      missing settings, bad KV URL, first start, second start (secrets
      byte-identical), override warning, half VAPID pair, bad UID: all as
      designed; VAPID public key decodes to a P-256 point.
    - `fluxer-aio-env`: per-service env (generated + overlay). Simulated all
      four services: internal addresses 127.0.0.1, external PG/Redis passed,
      secrets present, no leftover container hostnames or :8080; values with
      `$`/`"` kept literal, `$(...)` in a setting not executed.
    - Router `Caddyfile` (edge proxy mode + static files), `fluxer-aio-healthcheck`
      (every service), `fluxer-aio-selftest` (build-time ldd/versions/caddy
      validate/env eval).
  - [✓] 3d. README (requirements, settings, ports, data, update procedure,
    limitations, licensing), audit.md (snapshot, known issues), MIT LICENSE
    (2026-11-18). Redaction grep clean.
- [✓] 4. Template `templates/fluxer-aio.xml` (2026-11-18): bare/generic; ports
  8080/tcp (HTTP), 7881/tcp + 7882/udp (voice); `/data`; required domain,
  PG host/password, Redis URL (masked); optional PG port/db/user, pools
  10/5/5, LiveKit IP/TURN, UID/GID; ExtraParams `--ulimit nofile=65536:65536`
  (gateway) + `--stop-timeout=60`. Parses (19 Config); redaction grep clean.
  AGENTS/README layout, dependency chain and template list updated.
- [✓] 5. CI: build + push `fluxer-aio`; verify green run (CI green 2026-11-18)
  - [✓] 5a. Workflow (2026-11-18): `fluxer` path filter; keep-previous + build
    steps (on debian/fluxer/workflow change, tag, manual); manual input
    `fluxer_only` skips debian -> wine -> asa. Retag workflow lists
    fluxer-aio. YAML parsed (PyYAML in scratchpad), `if:` conditions re-read.
    AGENTS/README CI text, HISTORY entry, template (step 4) committed with
    `[skip ci]` so the workflow edit doesn't rebuild the ASA chain.
  - Pushed 2026-11-18 (`a571720`, all `[skip ci]`, so no run started).
  - gh CLI installed + logged in by maintainer 2026-11-18 (full path
    `C:\Program Files\GitHub CLI\gh.exe` until VS Code restarts).
  - Run 44372472991: only fluxer-aio steps ran (fluxer_only works); build OK
    until the self-test, which failed only on argon2's `prebuilds/linux-x64/
    argon2.musl.node` (never loaded on glibc). Passed: all binary/gateway
    ldd, versions (node 26.13.0, nats 2.14.10, meili 1.53.0, livekit 1.12.0,
    caddy 2.11.9), `caddy validate`, env eval. Fix: self-test skips non
    linux-x64-glibc prebuilds, requires >= 1 checked module.
  - [✓] 5b. Run 44372903547 (`63a3295`, fluxer_only) GREEN 2026-11-18:
    self-test "all checks passed" (native modules checked: argon2 + sharp
    linux-x64 glibc); pushed `fluxer-aio:latest`, `:2026-11-18`,
    `:sha-63a3295` (715 MB compressed, digest sha256:e52e9dc2…417a). Green = build + self-test passed. On failure: read the
    log, fix, push `[skip ci]`, dispatch again.
- [✓] 6. Release watch (2026-11-20; commits `782aa6b`, `6b95855`)
  - Weekly (Mon 05:17 UTC) + manual; finds the newest bundle via
    docs.fluxer.com/compose/latest; bump script updates RELEASE, Dockerfile
    digests (+ Meilisearch on a new minor), env, audit; test-build without
    push; opens/updates a PR from `auto/fluxer-release` (falls back to a
    compare link if Actions may not create PRs: repo setting currently OFF).
  - Tested on a scratch copy: real bump 90548 -> 162713 (5 digests, env
    unchanged), up-to-date re-run (`changed=false`), Meilisearch lookup.
    Workflow YAML parsed; script py_compile OK.
  - Maintainer allowed Actions to create PRs (repo setting, 2026-11-20).
  - First real run 44715287210 GREEN: bump + test build + self-test passed,
    opened PR #1 "fluxer-aio: Fluxer 2026.1118.162713" (5 digests, env
    unchanged). Merging it is the maintainer's call; after merge: CI
    rebuild, force update on Unraid. (The PR's audit row says
    `_(this change)_`; replace with the merge hash in the next audit change.)
- [✓] 7. Maintainer prep on Unraid (2026-11-18): PG role + DB `fluxer`, reverse
  proxy site, DNS, router forwards TCP 7881 + UDP 7882; personal pre-filled
  template + proxy config staged on the maintainer's share (outside the repo).
- [✓] 8. First start + live test (verified on Unraid via read-only access +
  maintainer report)
  - First start: all 8 services up; init OK; `/data` owned 99:100,
    `secrets.env` 0600 root. One problem: PG role password didn't match the
    template -> api fatal "password authentication failed"; fixed by the
    maintainer with `\password fluxer` (no restart needed; s6 retried).
    After that: users/messages connected (pool 5), api serving, gateway got
    its config, embedded worker runs jobs (`sweepVoiceParticipants` OK),
    no errors/warnings in the log; ~545 MB RAM idle.
  - [✓] Setup token accepted, admin account created, maintainer is in a
    channel they created: **text works** (2026-11-18). Note: the setup page
    tells rexctl users how to show the token; fluxer-aio users read it from
    `/data/secrets.env` (now in the README, uncommitted).
  - [✓] Docker health `unhealthy` although every service works (fixed 2026-11-20)
    - Maintainer output 2026-11-20: `unhealthy: media-proxy` (0.45 s). media-proxy
      itself serves avatars with 200 (log). Probe run by hand:
      `execlineb: fatal: unable to exec ifelse` -> `/command/with-contenv`
      needs s6's `/command` on PATH, which `docker exec` and Docker's
      HEALTHCHECK don't have. Same flaw in the fluxer-server probe.
    - Fix: health check sets PATH incl. /command and reports all failures
      with reasons (simulated: all-ok / one / two failures). Confirmed on
      Unraid before building: old script + that PATH -> `healthy`, exit 0.
    - Committed `ee404f9`; push run 44710843941 GREEN 2026-11-20 (only the
      fluxer-aio steps ran; the old image is now `fluxer-aio:previous`).
    - Maintainer force-updated (a plain "Check for updates" kept the old
      container; Unraid's Advanced View "force update" or `docker pull` first).
      Verified on Unraid via read-only access 2026-11-20: started 09:45:26 UTC,
      `healthy`, streak 0, router 200; only a start-up `connection refused`
      4 s after start.
  - [✓] Voice: bot voice through fluxer-aio's LiveKit works (botsu roadmap,
    2026-11-19). Person-to-person call from outside the LAN and screen share
    not explicitly tested; maintainer considers Fluxer finished (2026-11-20).
  - Klipy + YouTube keys: added by the maintainer on 2026-11-20 (in their own
    template, outside the repo); instance reports `gif_enabled`/`youtube_enabled`
    true; GIF picker + previews work after a client reload. Adding both as
    masked optional fields to the bare repo template: offered, not done.
  - Embedded worker verified (`all_lanes`, cron on); `pg_read_all_settings`
    grant noted as optional in the README.
- Maintainer decisions 2026-11-20 (after reviewing how the catalogue holds up):
  - Repo focus stays game servers; apps (Fluxer, bot) are a secondary area:
    light doc touch only.
  - Remove `scripts/docker-updater.{sh,bat}` (+ VS Code task, DOCKERHUB_USER
    docs/guardrails): CI is the build path. Note (not a roadmap item): if the
    repo ever leaves GitHub, expand CI instead of reviving local scripts.
  - fluxer-aio must keep rebuilding when its base (debian-base) changes
    (already true; keep in the CI redesign).
  - Infrastructure docs (shared Postgres/Redis/Caddy) parked; extend later.
  - fluxer-aio itself is considered finished and working; future changes are
    infrastructure-side.
  - Bot = separate public repo `Caaarrrlll/botsu` (Rust, Discord + Fluxer),
    with its own CI/image (`caaarrrlll/botsu`, Debian bookworm base), docs and
    Unraid template. Self-contained: SQLite in `/data`, no Postgres/Redis/
    proxy. Uses fluxer-aio via `FLUXER_URL` -> `/.well-known/fluxer` and
    LiveKit; its roadmap records bot voice through the self-hosted Fluxer's
    LiveKit working on 2026-11-19. Stays in its own repo (matches HISTORY);
    this repo only links to it.
  - Proposed next task: list-driven CI (images list + planner + build levels),
    removing the updater scripts in the same task. Awaiting go-ahead.
- [✓] 9. Doc pass (2026-11-20, light touch per maintainer): README/AGENTS intro
  (game servers main focus, apps secondary, botsu linked as separate repo);
  CLAUDE/AGENTS: workflow edits also rebuild fluxer-aio, doc-only commits
  always `[skip ci]`; ROADMAP item 16 (list-driven CI, monthly Debian
  rebuild, remove docker-updater scripts) + suggested order; HISTORY
  2026-11-20 entry; fluxer-aio folder in `dockers.code-workspace`.
  Infrastructure docs parked (maintainer). Checks: `git diff --check`,
  workspace JSON parses, redaction grep clean.
- [ ] 10. Revoke the SSH key (maintainer), revert CLAUDE.md access note, close
  (NOT yet: maintainer wants the key kept for now, 2026-11-20)

Previous (2026-11-18): Fluxer / Stoat research
(see `RATE_LIMIT_TRACKER_HISTORY.md`).

Next after this (maintainer to confirm): ROADMAP item 14, Wine vs Proton / Proton-GE
research (now P1). Item 9 stays blocked until item 14's research is done.
(Old `GameAnalytics.bak-*` folder and `ga-find.txt` removed by the maintainer, 2026-11-18.)
