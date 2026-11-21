# carl-homelab-dockers

Monorepo for my homelab's Docker images and **Unraid** templates. Its main
focus is **game servers**: the image chain that runs an **ARK: Survival
Ascended** dedicated server cluster under Wine. A smaller second area holds
self-hosted **apps**, currently `fluxer-aio` (an all-in-one Fluxer chat
server, a Discord alternative). Services that only need an Unraid wrapper
around an upstream image get a template in `templates/` rather than an image
here.

Related project: the chat bot for Discord and Fluxer lives in its own repo,
[Caaarrrlll/botsu](https://github.com/Caaarrrlll/botsu) (own CI, image and
Unraid template).

(Formerly `carl-gaming-dockers`, renamed 2026-11-18; the old GitHub URL
redirects.)

## Images

| Path | Docker Hub image | Base |
|---|---|---|
| `images/systems/debian-base` | `caaarrrlll/debian-slim-baseimage:trixie-latest` | `debian:trixie-slim` |
| `images/systems/fedora-base` | `caaarrrlll/fedora-baseimage:latest` | `fedora:44` |
| `images/systems/wine-base` | `caaarrrlll/wine-baseimage:latest` | `caaarrrlll/debian-slim-baseimage:trixie-latest` |
| `images/games/asa-docker` | `caaarrrlll/asa-wine:latest` | `caaarrrlll/wine-baseimage:latest` |
| `images/apps/fluxer-aio` | `caaarrrlll/fluxer-aio:latest` | `caaarrrlll/debian-slim-baseimage:trixie-latest` |

## Dependency chain

```
debian:trixie-slim
  └─ debian-slim-baseimage
       └─ wine-baseimage
            └─ asa-wine (ARK: Survival Ascended)
       └─ fluxer-aio (Fluxer chat, all-in-one)

fedora:44
  └─ fedora-baseimage
```

Build the Debian → Wine → ASA images (and Debian → fluxer-aio) in order. The Fedora image is independent.

## Build and push

The build scripts push to Docker Hub, so they require the `DOCKERHUB_USER`
environment variable to be set to **your** Docker Hub username. The scripts
refuse to run if it is missing, so they cannot accidentally push to the
repository maintainer's namespace.

Windows (PowerShell or `cmd`):

```powershell
$env:DOCKERHUB_USER = "myuser"
.\scripts\docker-updater.bat
```

Linux / macOS:

```bash
DOCKERHUB_USER=myuser ./scripts/docker-updater.sh
```

The local scripts skip the parked Fedora image unless `BUILD_FEDORA=1` is
also set.

Or in VS Code, run the **Docker: Build & Push All** task from
`dockers.code-workspace` after setting `DOCKERHUB_USER` in your environment.

The `FROM` lines in the Dockerfiles intentionally still reference the
maintainer's published images (for example
`caaarrrlll/debian-slim-baseimage:trixie-latest`). Only the tags that are built
and pushed use `DOCKERHUB_USER`; the base images are pulled from Docker Hub as
usual. If you want to build the whole chain from your own bases, update the
`FROM` lines (or the tags in the scripts) accordingly.

CI uses `.github/workflows/build-images.yml` instead. On a push it rebuilds only
the affected images, in dependency order: a Debian change rebuilds debian →
wine → asa and fluxer-aio, a Wine change rebuilds wine → asa, a fluxer-aio
change rebuilds fluxer-aio only, and a Fedora change rebuilds Fedora only. Tag
pushes and manual dispatches rebuild debian → wine → asa and fluxer-aio; tick
`fluxer_only` on a manual run to build just fluxer-aio. Fedora is excluded
unless you tick `build_fedora` on a manual run. New Fluxer releases arrive as
a pull request from the **Fluxer release watch** workflow (weekly, or Actions →
Fluxer release watch → Run workflow); merging it rebuilds fluxer-aio. Markdown
files (READMEs, `audit.md`, docs) never trigger a rebuild; add `[skip ci]` to a
commit message to skip the workflow entirely. Every
image is pushed as `latest` plus rollback tags `YYYY-MM-DD` and
`sha-<commit>` (Debian: `trixie-` prefixed), and the image it replaces is kept
as `previous`. To roll back, run the **Retag image** workflow
(Actions → Retag image → e.g. `asa-wine`, `previous` → `latest`) and
force-update the containers in Unraid; no local Docker is needed. CI expects
the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets.

## Layout

- `images/systems/` — shared runtime/base images.
- `images/games/` — per-game images layered on the system images.
- `images/apps/` — self-hosted application images (e.g. `fluxer-aio`).
- `scripts/` — build/push helpers, plus `unraid-readonly.sh` (allowlist for
  a temporary read-only SSH key on the Unraid host).
- `docs/` — design notes.
- `templates/` — bare Unraid Docker templates to copy into
  `/boot/config/plugins/dockerMan/templates-user/` and fill in: `asa-wine.xml`
  (this repo's ASA image), `fluxer-aio.xml` (this repo's Fluxer image) and
  `caddy.xml` (Caddy with the Cloudflare DNS module, upstream image). Generic defaults only, no server-specific details.
- `AGENTS.md` — contributor/agent overview, including the doc-alignment checklist.
- `CLAUDE.md` — Claude Code entry point; imports `AGENTS.md` and adds local-environment notes.
- `.gitattributes` — line endings (LF for shell scripts and Dockerfiles,
  CRLF for Windows `.bat`/`.ps1`).
- `.serena/` — config for the Serena code-navigation tool used by coding
  agents (local cache and overrides are git-ignored).
- `HISTORY.md` — dated record of significant changes and why they were made.
- `ROADMAP.md` — known issues and improvements parked for later (completed
  items: `ROADMAP_HISTORY.md`).
- `RATE_LIMIT_TRACKER.md` — live checklist of the current multi-step task
  (completed: `RATE_LIMIT_TRACKER_HISTORY.md`).

Each image directory has an `audit.md` tracking its snapshot and changes.
