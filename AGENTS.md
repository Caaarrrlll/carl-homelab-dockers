# AGENTS.md

Overview of this repository for automated/agent contributors.

## What this is

`carl-homelab-dockers` is a monorepo for the maintainer's own Docker images
and Unraid templates for their homelab on an **Unraid** host. Today it holds
the images used to run an **ARK: Survival Ascended** dedicated server cluster
under Wine (Debian → Wine → ASA), so most rules below are about that chain;
treat ASA-specific rules (shared install, ASA env vars, the five-place
alignment) as scoped to `images/games/asa-docker` and `templates/asa-wine.xml`.
Services that only need an Unraid wrapper around an upstream image get a
template in `templates/`, not an image under `images/`.

It was created by importing the original per-image repositories with
`git subtree`, so their history lives under `images/`. The repo was named
`carl-gaming-dockers` until 2026-11-18; GitHub redirects the old URL.

## Related instructions

Read in this order when relevant to the task:

1. This file (`AGENTS.md`): layout, build/CI, conventions, process.
2. `RATE_LIMIT_TRACKER.md`: the active task checklist. Read it **before
   starting any work** and resume from its first unchecked item (see
   "Rate Limit Tracker" below).
3. `ROADMAP.md`: the "Standing policy" block (risk legend, shared-install
   constraint) before changing an image, template or script; then the open
   items.
4. `docs/housekeeping.md`: open checks on the live server, only when the
   task touches the running system.

Do **not** read `RATE_LIMIT_TRACKER_HISTORY.md`, `ROADMAP_HISTORY.md`,
`HISTORY.md` or `docs/history/` unless the task needs past context (for
example "why was X decided" or "when did Y change"). They are archives,
not instructions, and reading them by default only fills the context.

## Layout

| Path | Image | Purpose |
|---|---|---|
| `images/systems/debian-base/` | `caaarrrlll/debian-slim-baseimage:trixie-latest` | Slim Debian base image |
| `images/systems/fedora-base/` | `caaarrrlll/fedora-baseimage:latest` | Slim Fedora base image (independent) |
| `images/systems/wine-base/` | `caaarrrlll/wine-baseimage:latest` | Wine layered on the Debian base |
| `images/games/asa-docker/` | `caaarrrlll/asa-wine:latest` | SteamCMD + ARK: Survival Ascended, layered on Wine |

Supporting files:

- `CLAUDE.md` — Claude Code entry point: imports this file (`@AGENTS.md`) and
  adds only Claude-specific notes (local environment, guardrail summary).
  Keep project rules here, not there.
- `dockers.code-workspace` — VS Code multi-root workspace definition.
- `.github/workflows/build-images.yml` — CI build/push workflow.
- `.github/workflows/retag-image.yml` — manual, registry-side retag on Docker
  Hub (rollback / pin a build) without local Docker.
- `scripts/docker-updater.bat` — builds and pushes all images (Windows).
- `scripts/docker-updater.sh` — builds and pushes all images (Linux/macOS).
- `scripts/unraid-readonly.sh` — SSH forced command for a temporary,
  revocable read-only key on Unraid (allowlisted `docker ps`/`logs`/`inspect`
  without env/`stats`, `ls` under one appdata folder). Runs from the flash
  drive, not from this repo; see the header for install and revocation.
- `docs/housekeeping.md` — open **verification** items on the running system
  (NTSYNC reboot persistence, under-load re-check, parked Fedora work,
  template verification, idle-crash confirmation). **Check/confirm these
  items later**; item 1 is a functional dependency on every Unraid reboot.
- `ROADMAP.md` — known issues and improvement ideas that need a **code or
  doc change** later, grouped by priority, plus the standing policy.
- `ROADMAP_HISTORY.md` — archive of completed roadmap items.
- `RATE_LIMIT_TRACKER.md` — live, resumable checklist of the current
  multi-step task.
- `RATE_LIMIT_TRACKER_HISTORY.md` — archive of completed task checklists.
- `templates/` — **bare** Unraid Docker templates, meant to be copied into
  `/boot/config/plugins/dockerMan/templates-user/` and filled in. They hold
  generic defaults only: no hostnames, share names, real paths, cluster IDs,
  passwords or other details of the maintainer's server (their live
  templates are kept outside this repo). Not watched by CI.
  - `asa-wine.xml` — for `caaarrrlll/asa-wine` (defaults for The Island,
    port slot 0). Keep it in sync when env vars, ports, volumes or Extra
    Parameters change; the maintainer applies the change to their own copies.
  - `caddy.xml` — Caddy with the Cloudflare DNS module
    (`caddybuilds/caddy-cloudflare`, third-party; no image is built here).
- `HISTORY.md` — consolidated, dated record of significant decisions and
  upgrades.
- `docs/history/` — completed long-running-upgrade working docs, kept for
  reference (the NTSYNC/Wine 11 one doubles as a reusable template, e.g.
  `docs/history/2026-11-07-ntsync-wine11.md`).
- `images/*/*/audit.md` — per-image snapshot, change log, and review checklist.

## Image dependency chain

```
debian:trixie-slim
  └─ caaarrrlll/debian-slim-baseimage:trixie-latest   (images/systems/debian-base)
       └─ caaarrrlll/wine-baseimage:latest            (images/systems/wine-base)
            └─ caaarrrlll/asa-wine:latest             (images/games/asa-docker, ARK ASA)

fedora:44
  └─ caaarrrlll/fedora-baseimage:latest               (images/systems/fedora-base)
```

Build order matters for the Debian → Wine → ASA chain: rebuild and push the base
before its dependents. The Fedora image is standalone.

## Building / releasing

Use `scripts/docker-updater.sh` (Linux/macOS) or
`scripts/docker-updater.bat` (Windows); the latter is also exposed as the VS Code
task **Docker: Build & Push All**. They build and push each image in dependency
order (debian → wine → asa-docker), aborting on the first failure. Fedora is
skipped unless `BUILD_FEDORA=1` is set, matching CI.

Both scripts require the `DOCKERHUB_USER` environment variable and exit with an
error if it is not set:

```bash
DOCKERHUB_USER=myuser ./scripts/docker-updater.sh
```

```powershell
$env:DOCKERHUB_USER = "myuser"
.\scripts\docker-updater.bat
```

`DOCKERHUB_USER` replaces the namespace in the tags that are built and pushed;
it deliberately does **not** default to `caaarrrlll`, so contributors cannot
accidentally push to the maintainer's Docker Hub account. The Dockerfiles'
`FROM` lines intentionally keep referencing the maintainer's published images,
so the dependency chain builds on those public bases regardless of which
namespace is being pushed to.

To rebuild a single image manually:

```powershell
docker image build -t caaarrrlll/wine-baseimage:latest .\images\systems\wine-base
docker image push caaarrrlll/wine-baseimage:latest
```

CI (`Build and push images`) runs on pushes to `main`, `v*` tags, and manual
dispatch. On a normal push it only rebuilds affected images and their
dependents: Debian changes trigger debian → wine → asa; Wine changes trigger
wine → asa; a change to the workflow file itself triggers debian → wine → asa;
Fedora is independent and is excluded from tag/manual chains unless the
`build_fedora` input is checked. Every build uses `pull: true` and
`no-cache: true`, so base images and packages are always fresh (and every
rebuild is a full one). Each image is pushed as `latest` (Debian:
`trixie-latest`) **plus** rollback tags `YYYY-MM-DD` and `sha-<short commit>`
(Debian: `trixie-` prefixed). Before each image is rebuilt, the current
`latest` is copied registry-side to `previous` (Debian: `trixie-previous`).
To roll back without local Docker, run the **Retag image** workflow
(source `previous` or a date/`sha-` tag → target `latest`) and force-update
the containers in Unraid, or pin the template's Repository to one of those
tags. GitHub Actions is the primary build path; the maintainer does not
keep Docker installed locally, so the `docker-updater` scripts are optional.
Changes under `templates/`, `docs/`, root files and **any `*.md` file**
(including image READMEs and `audit.md`) do not trigger builds; the path
filter excludes `**/*.md`. A change to the workflow file itself rebuilds
debian → wine → asa, so put `[skip ci]` in the commit message when a workflow
edit shouldn't rebuild anything. It expects repository secrets
`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.

## Conventions

- Each Dockerfile keeps `org.opencontainers.image.*` labels (`authors`,
  `source`, `licenses`).
- Base images install only a minimal set of packages with
  `--no-install-recommends` (Debian) / `--setopt=install_weak_deps=False`
  (Fedora) and clean package caches in the same layer.
- Locale is set to `en_US.UTF-8` in the base images.
- `images/games/asa-docker` targets Unraid: it runs as `steam` with configurable
  `UID`/`GID`, runs the server under Wine, and installs ARK ASA (app id
  `2430930`) into `/serverdata`. It is ASA-only by design; do not
  reintroduce generic, multi-game (ich777-style) variables such as
  `GAME_PARAMS` or `GAME_NAME`.
- `images/games/asa-docker` is designed around the Unraid Docker template format
  (env vars such as `GAME_ID`, `GAME_PARAMS_EXTRA`, `UID`, `GID`, `VALIDATE`,
  `NTSYNC`, `GB_FORCE_RESTART`, `LOG_PREFIX`, `AUTOSAVE_MINUTES`, `RCON_PORT`). Boolean-style toggles use `0`/`1`, except
  `VALIDATE`, which is `false`/`true`.
- Host-side settings that affect the server (kernel modules, `vm.max_map_count`,
  swap, Unraid User Scripts, Extra Parameters such as `--device` /
  `--shm-size` / `--ulimit`) cannot be set by the image. Document them in the
  ASA README ("Host requirements" / "Resource limits") and in the template.
- Each image has an `audit.md`. Update it in the same change that modifies a
  Dockerfile, script, or image tag.

## Keeping docs aligned (checklist for every change)

Apply whatever rows match the change, **in the same commit**:

| If you change… | Also update |
|---|---|
| A Dockerfile, image script, or image tag | That image's `audit.md`: "Current snapshot", a new "Change log" row (newest first), "Last audited" date, and resolve/remove fixed "Known issues". |
| An ASA env var, port, volume, or default | `Dockerfile` `ENV`, `start-server.sh`, ASA `README.md` tables, `templates/asa-wine.xml`, and the ASA `audit.md` snapshot. All five must agree. |
| Host or runtime requirements (Extra Parameters, kernel, `max_map_count`, swap, `ulimit`) | ASA `README.md`, the template's `Overview` / `ExtraParams`, and `HISTORY.md`. |
| CI workflow or build scripts | The CI/build sections of this file and the root `README.md`. |
| Anything a future reader would ask "when/why did this change?" about | A dated entry in `HISTORY.md` (newest first, `## YYYY-MM-DD — <topic>`), with the **motivation** as well as the change. Extend today's entry rather than adding a second one for the same day. |
| Files or folders at the repo root | "Layout" / "Supporting files" in this file and the root `README.md`. |
| Something to verify later on the live server | A row in `docs/housekeeping.md`; move it to "Record" with a date once confirmed. |
| A problem you found but aren't fixing now | An item in `ROADMAP.md` (next free number, with a Risk rating). Once done, move it to `ROADMAP_HISTORY.md` and note the fix in the audit/history. |
| A multi-step task | Its checklist in `RATE_LIMIT_TRACKER.md` first; when done, move it to `RATE_LIMIT_TRACKER_HISTORY.md`. |

Change-log commit column: write `_(this change)_` while uncommitted, then
replace it with the short hash once the commit exists, either in the next
change that touches that `audit.md` or during an audit pass. Never leave
`_(this change)_` on a row older than the current change.

Dates are absolute (`YYYY-MM-DD`). Before finishing, grep for the names you
touched (for example an env var) across `images/`, `templates/`, `README.md`,
`AGENTS.md` and `docs/` so no stale reference is left.
- When a long-running upgrade or migration completes, condense its outcome into
  `HISTORY.md`, then tidy up the tracking docs: move the completed working doc
  under `docs/history/` named **date-first** (`YYYY-MM-DD-<topic>.md`, e.g.
  `2026-11-07-ntsync-wine11.md`) so files sort chronologically, reference it
  from `HISTORY.md`, and delete temp/superseded files. Carry any still-open
  verification work into `docs/housekeeping.md` instead of deleting it.

## Rate Limit Tracker (mandatory)

Applies to every multi-step task (image or script changes, template
rollouts, investigations that lead to changes, research items). Sessions
can end at any time (rate limits, context limits), so the tracker must
always be enough to resume from.

- At the start of every session, read `RATE_LIMIT_TRACKER.md` first. If it
  has unchecked items, continue that task from its first unchecked item
  before starting anything new.
- Before starting a new big task, write its steps as a checklist in
  `RATE_LIMIT_TRACKER.md` (one `[ ]` per step) and work top-down.
- Size each checkbox as one resumable unit that a session can finish and
  verify. Split bigger steps into indented sub-items up front.
- Mark a step `[•]` **before** its first file edit and list the files it
  touches (for example `[•] Step 3 — touching: start.sh, README.md`), so an
  interrupted session can resume without reverse-engineering `git diff`.
- Steps that need the maintainer (anything run on Unraid, live tests,
  decisions) are marked `[⏳]` with exactly what to run or decide. Never
  mark them `[✓]` until the maintainer has reported the result.
- Update the checklist right after each step (`[•]` → `[✓]`), not in a
  batch at the end.
- Never record an outcome that wasn't verified on the current tree or the
  live server (see "Verification"). If a session ends mid-task, the
  checklist must show exactly what is done, in progress and pending.
- Format: one short summary line per item; details (files, findings,
  commands) go on indented `-` sub-bullets.
- When the task is done, end at a clean boundary (all items checked, next
  steps written down), move the section to `RATE_LIMIT_TRACKER_HISTORY.md`,
  and move any finished `ROADMAP.md` item to `ROADMAP_HISTORY.md`.

## Verification

"Verified" means the checks for the change type were run on the current
tree (or the live server) and passed. Record what was run.

| Change type | Required checks |
|---|---|
| Any change | `git diff --check` |
| Shell script (`*.sh`) | `bash -n <file>`; for changed logic, a stubbed simulation of the affected paths (as done for the stop handler) |
| Unraid template / XML | Parse it (Python `xml.etree`, or `php` on Unraid); grep it for server-specific values (hostnames, share names, real paths, IDs, secrets) |
| Workflow YAML | Parse it and re-read the `if:` conditions / path filters it affects |
| Dockerfile / image script | Only CI can build (no local Docker): the build is verified when the Actions run is green; runtime behaviour only when the maintainer has tested it on Unraid |
| Docs / tracker only | `git diff --check` |

Anything not tested live must be labelled as such (for example "simulated,
not tested on Unraid").

## Notes / gotchas

- If a user reports `DOCKERHUB_USER is not set` (or a build/push fails
  immediately), the build scripts are refusing to run without a Docker Hub
  username. This is intentional: do not "fix" it by defaulting back to
  `caaarrrlll`. Ask them to export `DOCKERHUB_USER` first (see above).
- The Dockerfiles' `FROM` lines intentionally reference `caaarrrlll/...`
  images. Only the tags built/pushed by the scripts use `DOCKERHUB_USER`, so a
  fork builds on the maintainer's public base images rather than its own.
- Fedora CI is intentionally opt-in: the `build_fedora` input defaults to
  `false`, and Fedora is excluded from tag/manual chains because the image is
  not currently used and still consumes Actions job time. Re-enable it when
  Fedora is actually needed by setting the input default to `true` or adding
  Fedora back to the chain conditions.
- **All ASA cluster containers share one `/serverdata/serverfiles` install**
  (deliberate: one download per game update, less disk). Never add behaviour
  that runs SteamCMD automatically while other servers may be running
  (for example, a crash watchdog that restarts the container and so
  re-runs the update). Remember that the servers also share config `.ini`
  files, the Wine prefix, and the `Saved/Logs` folder (hence per-server
  `LOG_PREFIX` log names). See
  `ROADMAP.md` ("Design constraint: shared server files").
- Containers share the Unraid host kernel; no Dockerfile change can upgrade it.
  See `docs/history/2026-11-07-ntsync-wine11.md` for the NTSYNC / kernel 6.18
  context.
- `images/systems/fedora-base` (parked, not updated with the other images) labels/README still reference the Debian base
  (copy-paste leftovers) — verify before relying on image metadata.
- `images/games/asa-docker` ships default game passwords and logs secrets when
  `DEBUG=1`. This is **accepted**: the Unraid template overrides the passwords
  and `DEBUG` defaults to `0`. See its `audit.md` before changing this behavior.
- Builds should run against the local Docker context (`docker context use
  desktop-linux`); do not set `DOCKER_HOST` to the Unraid SSH host for local
  builds.
