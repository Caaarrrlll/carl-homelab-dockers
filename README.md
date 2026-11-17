# carl-gaming-dockers

Monorepo for the Docker images used to run an **ARK: Survival Ascended**
dedicated server under Wine on **Unraid**.

## Images

| Path | Docker Hub image | Base |
|---|---|---|
| `images/systems/debian-base` | `caaarrrlll/debian-slim-baseimage:trixie-latest` | `debian:trixie-slim` |
| `images/systems/fedora-base` | `caaarrrlll/fedora-baseimage:latest` | `fedora:44` |
| `images/systems/wine-base` | `caaarrrlll/wine-baseimage:latest` | `caaarrrlll/debian-slim-baseimage:trixie-latest` |
| `images/games/asa-docker` | `caaarrrlll/asa-wine:latest` | `caaarrrlll/wine-baseimage:latest` |

## Dependency chain

```
debian:trixie-slim
  └─ debian-slim-baseimage
       └─ wine-baseimage
            └─ asa-wine (ARK: Survival Ascended)

fedora:44
  └─ fedora-baseimage
```

Build the Debian → Wine → ASA images in order. The Fedora image is independent.

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
wine → asa, a Wine change rebuilds wine → asa, and a Fedora change rebuilds
Fedora only. Tag pushes and manual dispatches rebuild debian → wine → asa;
Fedora is excluded unless you tick `build_fedora` on a manual run. Markdown
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
- `scripts/` — build/push helpers.
- `docs/` — design notes.
- `templates/` — Unraid Docker templates (`asa-wine.xml` = the standard for the ASA cluster servers).
- `AGENTS.md` — contributor/agent overview, including the doc-alignment checklist.
- `HISTORY.md` — dated record of significant changes and why they were made.
- `ROADMAP.md` — known issues and improvements parked for later.

Each image directory has an `audit.md` tracking its snapshot and changes.
