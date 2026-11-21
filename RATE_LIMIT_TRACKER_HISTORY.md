# Rate Limit Tracker — History

Historical record of completed tasks. The live checklist is
`RATE_LIMIT_TRACKER.md`. Archive only: read it when a task needs past context,
not as instructions.

Maintenance rule (see the live tracker): after a task is confirmed complete,
move its checklist section here, newest first.

---

## ROADMAP 14: Wine vs Proton / Proton-GE research (done 2026-11-21)

Research only, no image changes. Scope: the ASA server (maintainer did not
widen it). Output: `docs/asa-proton-research.md`, then a decision.

- [✓] 1. Checklist + research doc
  - `docs/asa-proton-research.md`; listed in AGENTS.md and README.md
- [✓] 2. GE-Proton headless without Steam: `proton run` direct, two env
  vars, no umu/pressure-vessel; Debian -> asa-proton, no middle image
- [✓] 3. Existing images reviewed: mschnitzer, ferment9348, ludix0, azixus,
  sknnr (web sources, not tested)
- [✓] 4. Performance/stability: no Wine-vs-Proton server benchmark exists;
  GE-Proton >= 10-10 uses NTSYNC by default; GE-Proton 11 hang reports
- [✓] 5. Shared install: every image uses per-server installs/prefixes;
  Proton upgrades its prefix itself -> per-container prefix required
- [✓] 6. Recommendation written: don't migrate; park item 14 with a trigger;
  item 9 can be unblocked. ROADMAP 14 points at the doc.
- [✓] 7. Maintainer decided (2026-11-21): item 14 parked with a trigger;
  item 9 unblocked (image size only: unused packages use no RAM). Goal for
  any later experiment is lower RAM per server.

---

## CI driven by one list of images, ROADMAP 16 (done 2026-11-21)

Must keep: dependents rebuild transitively (debian -> wine, asa, fluxer-aio;
wine -> asa); monthly schedule = everything non-opt-in; tag = everything
non-opt-in; Fedora opt-in (built only when named or its own files change);
workflow/CI-file change = everything non-opt-in; `*.md`-only change = none;
`[skip ci]`; keep-`:previous` + date/`sha-` tags (Debian `trixie-` prefix);
a fluxer-aio change rebuilds fluxer-aio (release watch relies on it).

- [✓] 1. `.github/images.json` (name, context, image, tag prefix, parent,
  opt-in) — JSON so the planner needs only the Python stdlib
- [✓] 2. `.github/scripts/plan-builds.py`: push (git diff before..after,
  transitive dependents), schedule/tag (all non-opt-in), manual (named images
  + dependents, or `all`); outputs one matrix per dependency level; run
  summary; checks the Retag workflow lists every image
- [✓] 3. `.github/actions/build-image` composite action (keep :previous,
  build, push latest/date/sha tags) so the steps exist once
- [✓] 4. Rewrite `build-images.yml`: plan job + build jobs per level (matrix,
  fail-fast off); manual inputs `images` (default `all`) + `dry_run`
  replace `fluxer_only` / `build_fedora`
- [✓] 5. Local tests: planner vs today's behaviour for every trigger type;
  YAML parse; re-read `if:`/`needs`
  - Done 2026-11-21: planner 23/23 vs old behaviour (push per image,
    transitive dependents, md/docs/templates ignored, CI-file changes = all,
    Fedora opt-in, new branch, tag, schedule, manual by entry or Docker Hub
    name, unknown name = error) + a real git diff; levels debian -> wine &
    fluxer-aio (parallel) -> asa. Workflow, action, images.json parse.
- [✓] 6. Docs: AGENTS/README CI, operations.md section 2, CLAUDE guardrail,
  HISTORY; ROADMAP 16 -> history
- [✓] 7. Rollout: commit `[skip ci]`; manual dry run (plan matches); real
  run for fluxer-aio only (CI green)
  - Done 2026-11-21: committed 3596ce6 [skip ci]; dry run 44900714021 (plan
    job only; plan = debian, wine, fluxer-aio, asa; fedora opt-in; no Retag
    warning); real run 44900748621 images=fluxer-aio GREEN: level 0 empty,
    level 1 built fluxer-aio (self-test passed), level 2 skipped; Docker Hub:
    previous = old latest, new latest/2026-11-21/sha-3596ce6. Cosmetic:
    skipped level jobs show the literal name "build ${{ matrix.name }}".

## fluxer-aio backup -> upgrade -> verify -> clean up, ROADMAP 17 (done 2026-11-21)

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
- [✓] 7. Live test on Unraid: (a) force update to 5b7582a = first start, no
  backup, release recorded when healthy; (b) merge PR #1, force update =
  backup + verify + prune in the log. Confirmed via read-only access.
  - (a) PASSED 2026-11-21 (verified on Unraid via read-only access): started
    11:15:21 UTC, "first start on fluxer-release@2026.1118.90548: no backup
    needed", recorded as last good at 11:15:52, healthy; state dir 0700 root.
    Cosmetic: doubled [update-verify] prefix, fixed in the script ([skip ci];
    ships with the PR #1 merge build).
  - PR #1 refreshed by release-watch run 44898370151 onto current main:
    now 2026.1118.90548 -> 2026.1120.164141 (5 digests, env unchanged,
    Meilisearch unchanged), test build + self-test passed, MERGEABLE/CLEAN.
  - (b) PASSED 2026-11-21 (verified on Unraid via read-only access): PR #1
    merged (7f754be, build 44899106059 green); force update -> restart
    11:30:00 UTC; before Fluxer started: checksum check, "update
    ...90548 -> ...2026.1120.164141: backing up", backup verified (42871 B;
    dump, secrets.env, SHA256SUMS, INFO, STATUS, all 0600 root); healthy;
    11:30:31 recorded as last good, pending-backup cleared; single log prefix.

## Monthly scheduled rebuild (done 2026-11-21)

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

## Reformat Dockerfiles and scripts to the readability standard (done 2026-11-21)

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
- [✗] 8. Not done (not needed: identical behaviour; the read-only script goes away at fluxer-aio step 10). Was: optional redeploy the reformatted `unraid-readonly.sh` to Unraid
  (same behaviour; only needed to keep the copy identical)

## Fluxer / Stoat: own Dockerfiles or templates only? (done 2026-11-18)

Research only, no code yet. Context: the repo is becoming a homelab
catalogue; a self-written bot (own image) will follow later.

- [✓] 1. Research how Fluxer and Stoat are self-hosted (2026-11-18, web sources only)
  - Both are multi-container stacks with official prebuilt images, shipped
    as Docker Compose: Stoat via `stoatchat/self-hosted` (generate_config.sh
    + compose); Fluxer via a per-release compose bundle (6 to ~25 services
    reported depending on version/source; also `rexctl`). Not verified hands-on.
- [✓] 2. Recommendation (given to the maintainer 2026-11-18)
  - No own Dockerfiles for either; single-container Unraid templates don't
    fit multi-service stacks. Proposed: `stacks/<name>/` with pinned compose +
    `.env.example` (Unraid Compose Manager), own images only for the bot.
- [✓] 3. Maintainer decided: Fluxer first (2026-11-18)
- [✓] 4. Fluxer: template vs wrapper image? (2026-11-18)
  - Read release bundle `fluxer-compose-2026.1118.90548.tar.gz` (scratchpad,
    not in repo): 20 services, 12 Fluxer images (`ghcr.io/fluxerapp/*`, digest
    pinned) + Caddy, Postgres 16, Valkey, NATS, Meilisearch, SeaweedFS, LiveKit;
    `.env.example` ~2.4k lines, ~17 generated secrets. Minimum with overrides
    (`rust-server`, `kv-postgres`, filesystem store, embedded worker) is still
    ~10 containers.
  - Ports: 80/443 (or edge on :8080 with `docker-compose.proxy.yml`), voice
    TCP 7881 + UDP 7882 direct (not via proxy). Proxy override uses `!override`
    (needs Compose >= 2.24).
  - Conclusion: one Unraid template can't deploy it; an all-in-one wrapper
    image would be ~10 processes under a supervisor, rebuilt per release:
    not worth it. Proposed: `stacks/fluxer/` for Unraid Compose Manager.
- [✓] 4a. Stoat size + reuse of maintainer's Caddy/Postgres/Redis (2026-11-18)
  - `stoatchat/self-hosted` compose (v0.16.5): 16 services; MongoDB,
    RabbitMQ, MinIO(silo), Valkey, Caddy, LiveKit (TCP 7881, UDP
    50000-50100) + 9 Stoat images. No Postgres use; Redis + Caddy reusable.
  - Fluxer: `FLUXER_POSTGRES_*` / `FLUXER_KV_URL` allow external Postgres and
    Redis, but compose `depends_on` names the bundled ones -> needs an
    override; Fluxer's own edge Caddy stays behind the maintainer's Caddy.
- [✓] 4b. All-in-one (AIO) image feasibility (2026-11-18)
  - ghcr image configs (release 2026.1118): api (Node 26), gateway (Erlang
    OTP 28 release), media-proxy (Rust + libvips/jemalloc, tini), fluxer-server
    (Rust) all on **Debian trixie**, same as our debian-base; static = Caddy on
    Alpine. Users 65532 / 10001. NATS, Meilisearch, SeaweedFS, LiveKit, Caddy
    are static binaries. -> AIO via multi-stage `COPY --from` + s6/supervisor
    is feasible; cost = per-release rebuilds + replicating compose env wiring.
- [✓] 4c. Shared Postgres: maintainer's is a Postgres + vector-extension image (2026-11-18)
  - Fluxer needs no extensions (bundled PG16 only preloads optional
    `pg_stat_statements`); connects via `FLUXER_POSTGRES_HOST/_PORT/_DATABASE/
    _USERNAME` or `FLUXER_POSTGRES_URL`. Bundled tuning: max_connections 150,
    shared_buffers 512MB. Postgres + VectorChord image is a
    superset; shareable with its own role/DB. Unknown: PG major, max_connections.
  - Maintainer plans (separate project) to replace that PG image with
    plain Postgres + vector extensions. Proposed: Fluxer starts on its bundled
    PG16, migrates to the shared PG later via pg_dump/pg_restore.
  - Maintainer's server runs Postgres 18 with VectorChord/pgvector
    (PG 18). Fluxer bundles 16 -> Fluxer on 18 untested (likely fine; dump
    16 -> restore 18 is the supported direction). Still to get: max_connections,
    connections in use.
- [✓] 4d. Scope of a Fluxer-only AIO (external Caddy/Redis/Postgres) (2026-11-18)
  - Edge Caddyfile is internal path routing (`/api`, `/gateway`, `/media`,
    `/livekit`, `/admin`, static assets, app-proxy fallback, `/_health`);
    a small internal Caddy (no TLS) is still needed as the router and replaces
    `fluxer-static`'s own Caddy. Every service port is configurable
    (`FLUXER_API_PORT`, `_GATEWAY_PORT`, `_MEDIA_PROXY_PORT`, `_ADMIN_PORT`,
    `_APP_PROXY_PORT`, `FLUXER_SERVER_<SVC>__FLUXER_SVC_PORT`), so services
    can share one network namespace without clashing on 8080.
  - Proposed AIO contents: internal router Caddy, api (+embedded worker),
    gateway, media-proxy, fluxer-server (Rust), static files, NATS,
    Meilisearch, LiveKit; uploads on filesystem store (no SeaweedFS).
- [✓] 4e. Postgres connection budget (2026-11-18)
  - Maintainer's Postgres: default max_connections, well under half used.
  - Fluxer pool maxima: api 25, worker 25, users 20, messages 20 (~90).
    -> AIO defaults lowered for homelab scale (proposal: api 10, worker 5,
    users 5, messages 5 = 25) so no PG restart is needed.
  - Networks (2026-11-18): the maintainer's Caddy and Redis are on the
    default `bridge`, Postgres on `host` -> fluxer-aio on bridge, reach
    Postgres and Redis via the host IP; Redis DB index 1 (keep other apps on 0).
- [✓] 4f. Read-only Unraid access for the build: approved by maintainer (2026-11-18)
  - Dedicated SSH key from this PC, `restrict,command=` forced to an
    allowlist script (`scripts/unraid-readonly.sh`, in repo): docker ps,
    docker logs --tail, filtered inspect (no env), ls under fluxer appdata.
    No docker group / socket proxy (root-equivalent / leaks env).
    Revoke after the build. Optional read-only PG role on `fluxer` DB.
  - Becomes step 1 of the fluxer-aio plan; CLAUDE.md "no Unraid access"
    updated when the key is installed.
- [✓] 5. Maintainer decisions (2026-11-18): fluxer-aio scope approved; skip
  the Compose test run; voice + text required, screen share optional (same
  LiveKit ports, no extra server config found).

## Rename repo to `carl-homelab-dockers` (done 2026-11-18)

Repo widened from ASA-only to the maintainer's homelab images. Docker Hub
image names do not change; no container needs recreating.

- [✓] 1. GitHub rename (maintainer)
  - Done 2026-11-18: https://github.com/Caaarrrlll/carl-homelab-dockers
- [✓] 2. Repo edits — touched: README.md, AGENTS.md, HISTORY.md,
  templates/asa-wine.xml, images/{systems/debian-base,systems/wine-base,games/asa-docker}/{Dockerfile,audit.md}
  - Old name → new in labels, template URLs, audit "Source repo" rows.
  - README/AGENTS intro: homelab monorepo, ASA chain is the current content.
- [✓] 3. Verify, commit with `[skip ci]`, set remote, push
  - `git diff --check` clean; `templates/asa-wine.xml` parses; old name only
    left in historical rows / rename notes. Commit: see `git log` (rename commit).
- [✓] 4. Local move (maintainer): close VS Code, rename
  the local `carl-gaming-dockers` folder → `carl-homelab-dockers`, and copy
  Claude's per-project memory folder to the new project path
  - Confirmed 2026-11-18: repo opens from the new path; memory dir present.
- [✗] 5. Unraid live templates: dropped. Maintainer moved their live
  templates out of this repo; templates here are now bare, generic copies.
- [✓] 5a. Bare templates, no server-specific references — touched:
  templates/asa-wine.xml, templates/my-Caddy.xml → templates/caddy.xml,
  README.md, AGENTS.md, CLAUDE.md, images/games/asa-docker/{README,audit}.md, HISTORY.md
  - Archives / dated change-log rows left as historical record.
- [✓] 5b. Verify, commit `[skip ci]`, push
  - Verified: `git diff --check` clean; both templates parse; grep of
    templates and current docs finds no hostnames/shares/real paths/secrets.
  - Committed and pushed as d862852; `main` matches `origin/main`.
- [✓] 6. Close: moved this section to `RATE_LIMIT_TRACKER_HISTORY.md`

## ROADMAP item 15, GameAnalytics log clutter (done 2026-11-18)

Every server logs `SQLITE3 FINALIZE ERROR: database disk image is malformed`
and `Database too large. Event has been blocked.` every ~8 s. Plan: a
per-container `--tmpfs` over the GameAnalytics folder (details in ROADMAP
item 15).

[✓] Record findings + fix plan in ROADMAP item 15 (2026-11-18)
[✓] Locate the GameAnalytics database on the shared install (2026-11-18)
    - host: `<serverfiles>/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics/<game-key>/ga.sqlite3` (6.7 MB, last written 2026-11-18 00:10; folder created 2026-05-19); the only GA file on the install
    - container path to mount over: `/serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics`
    - found via `find … > <share>/ASA/ga-find.txt` (SSH to the server was off; appdata isn't shared)
[✓] Add the GameAnalytics `--tmpfs` to Extra Parameters (2026-11-18)
    - `templates/asa-wine.xml`: ExtraParams + Overview; `--tmpfs /serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics:rw,size=64m,mode=1777`
    - `<share>/ASA/align-asa-templates.sh`: `EXTRA=` + header comment
    - new `<share>/ASA/asa-rollout.sh` (outside the repo): stop all (save) → move GA folder aside → align `APPLY=1` → `update_container` one at a time, wait for `---Start Server---`, check tmpfs; dry run by default
    - ASA `README.md` (Resource limits), `audit.md` (snapshot + row), `HISTORY.md` (2026-11-18)
[✓] Verify locally (2026-11-18, simulated, not tested on Unraid)
    - template XML parses; both scripts `bash -n` OK (copies on the share have LF endings)
    - rollout dry run + `APPLY=1` with a stub `docker` / `update_container` and 13 synthetic templates: all stopped with save, GA folder moved aside, all 13 templates got the tmpfs, recreated in order (Astraeos first), summary running=true tmpfs=yes; failure path stops cleanly (tested by accident with a missing template folder)
    - align re-run changes 0 lines (idempotent); `git diff --check` clean
    - the redacted exports are gone from the share (deleted by the maintainer), so the dry run used templates generated from `templates/asa-wine.xml`
[✓] Maintainer rollout on Unraid (2026-11-18 ~07:30)
    - dry run done 2026-11-18 07:26: 13 containers, Astraeos first, `update_container` found, GA folder now 12 MB; only LostColony + Ragnarok running
    - script fixed after the dry run: it would have started all 13; now it restarts only the servers that were running (`START_ALL=1` to start all); re-tested with stubs for both `update_container` behaviours
    - `APPLY=1` run done; Lost Colony restarted cleanly (90 s full startup, 15.15 GB, all mods valid, fresh GA database)
[✓] Verify live (2026-11-18): each container has its own tmpfs GA folder (`df -h` shows `tmpfs`; different `ga.sqlite3` per server; host folder stays empty), and no `GameAnalytics` malformed / `db_too_large` lines in the logs; then move item 15 to `ROADMAP_HISTORY.md` and this section to the tracker history
    - result: LostColony + Ragnarok `df -h` = `tmpfs 64M`, own `ga.sqlite3` (07:34 / 07:35), host folder empty, no malformed / `db_too_large` lines
[✓] Clean boundary: item 15 moved to `ROADMAP_HISTORY.md`, this section to the tracker history


## Agent tracking setup (done 2026-11-18)

Task: adopt the tracker + history-archive setup from the sibling
`angular-template` project, to keep agent context lean.

[✓] Added `RATE_LIMIT_TRACKER.md`, `RATE_LIMIT_TRACKER_HISTORY.md`, `ROADMAP_HISTORY.md`
[✓] AGENTS.md: "Related instructions" reading order, archive rule, "Rate Limit Tracker (mandatory)", "Verification" table, updated doc-alignment rows
[✓] ROADMAP.md: lean header + "Standing policy" block; completed items moved to `ROADMAP_HISTORY.md`
[✓] Root README layout updated; `git diff --check` clean

## ASA cleanup, cluster template alignment and rollout (2026-11-17 → 2026-11-18)

Reconstructed after the fact (the tracker didn't exist yet); details are in
`HISTORY.md` (2026-11-17 entry), the audits and `ROADMAP_HISTORY.md`.

[✓] Validated the pending changes (`GB_FORCE_RESTART`, `ulimit`, CI `no-cache`) and fixed the stray `-${GB_FORCE_RESTART}` argument
[✓] Image work: per-map logs (`LOG_PREFIX`, verified `-LOG=` on ASA first), quoted launch arguments, Unraid-style permissions, save on stop over RCON (`gorcon/rcon-cli`, pinned), `AUTOSAVE_MINUTES` / `RCON_PORT`, small script fixes
    - commits `6b930a6` (rework) and `beb0b6b` (stop-handler fix after the first live stop test made no save)
[✓] CI: rollback tags (date / `sha-` / `previous`), Retag image workflow, Fedora opt-in locally, `**/*.md` excluded from rebuilds
[✓] Docs: ROADMAP (risk-rated), AGENTS alignment checklist, READMEs, audits, HISTORY, housekeeping
[✓] Unraid: 26 dead templates removed; 13 ASA templates aligned via `align-asa-templates.sh` (Gen1 port bug, NTSYNC + `--shm-size` + `--stop-timeout` everywhere, stale vars, mods per `Mods.txt`); `templates/asa-wine.xml` made the cluster standard
[✓] Live verification (maintainer, 2026-11-17/18): new image on all 13, per-map logs no longer overlap, NTSYNC, swap, save on stop, cluster up and joinable
    - open follow-ups moved to `docs/housekeeping.md` (item 8 autosave check, item 6 idle crashes)
