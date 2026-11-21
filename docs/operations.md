# Operations guide: setup, updates, rebuilds and rollback

Plain step-by-step procedures for running the images in this repository on
**Unraid**. They are written so that **anyone** can follow them: a person
reading this page, or any AI assistant or automation given this page as
instructions. Nothing here depends on a particular tool; where a command line
is optional, the web-page way is given first.

Where things happen:

| Place | What you do there |
|---|---|
| **GitHub** (the repository's web page → **Actions** tab) | Start builds, roll back image tags, see build results |
| **Docker Hub** (`hub.docker.com/r/caaarrrlll/<image>/tags`) | See which image versions (tags) exist |
| **Unraid web UI** → **Docker** tab | Add, update, stop and start containers |
| **Unraid terminal** (web UI, top right `>_`) | Only where a step says so |

Images in this repository:

| Image | Used for | Its own guide |
|---|---|---|
| `caaarrrlll/asa-wine` | ARK: Survival Ascended servers | [`images/games/asa-docker/README.md`](../images/games/asa-docker/README.md) |
| `caaarrrlll/fluxer-aio` | Fluxer chat server | [`images/apps/fluxer-aio/README.md`](../images/apps/fluxer-aio/README.md) |
| `caaarrrlll/wine-baseimage`, `caaarrrlll/debian-slim-baseimage` | Base images (not run directly) | — |

---

## 1. How and when images are built

Images are built **only** by GitHub Actions (workflow **Build and push
images**). Nobody builds them on their own computer. A build happens:

- **when a change is pushed** to the `main` branch (only the images whose
  files changed, plus the images built on top of them);
- **monthly**, on the 2nd at 04:23 UTC: everything built on Debian is
  rebuilt (Debian → Wine → ASA, and fluxer-aio) to pick up Debian security
  fixes;
- **when started by hand** (section 2).

A new build **never changes a running server by itself**. Containers on
Unraid keep their current image until someone updates them (section 3).

Every build is published under several **tags**, so older versions stay
available:

| Tag | Points at |
|---|---|
| `latest` | The newest build (what the Unraid templates use) |
| `previous` | The build that `latest` replaced (**one** step back only) |
| `YYYY-MM-DD` | The last build on that date, e.g. `2026-11-21` |
| `sha-<commit>` | The build from one exact commit, e.g. `sha-abc1234` |

The Debian base image uses the same tags with a `trixie-` prefix
(`trixie-latest`, `trixie-previous`, `trixie-2026-11-21`, …).

## 2. Rebuild images now (manual build)

Use this for an urgent security fix, or after changing settings that a
build needs.

1. GitHub → **Actions** → **Build and push images** → **Run workflow**.
2. Branch: `main`. Options:
   - nothing ticked: rebuilds Debian → Wine → ASA and fluxer-aio;
   - **fluxer_only**: rebuilds only fluxer-aio;
   - **build_fedora**: also builds the (unused) Fedora base image.
3. **Run workflow**, then wait until the run shows a green check (about
   10–30 minutes). A red cross means nothing usable was published for the
   failed image; the previous version is still on `latest`.

Command-line alternative (GitHub CLI, if installed and logged in):
`gh workflow run build-images.yml --ref main -f fluxer_only=false`.

## 3. Update a running container on Unraid

1. Unraid → **Docker** tab.
2. Turn on **Advanced View** (switch at the top right).
3. On the container's row, click **force update**. (A plain *Check for
   Updates* sometimes reports "up to date" for a newer image; *force update*
   always pulls it.)
4. Wait for "Command finished successfully", then check the container's log
   (click its icon → **Logs**).

Image-specific rules:

- **ASA:** all ASA containers share one server install. **Stop all ASA
  containers first**, update them, then start them **one at a time**. Never
  update while a game update is pending. See the ASA README.
- **fluxer-aio:** Fluxer migrates its database when a new **Fluxer release**
  starts. Before updating to a new release, back up its Postgres database and
  its data folder (fluxer-aio README, "Data"). After the update the container
  should show **healthy** within about 3 minutes.

## 4. Roll back to an earlier image

Use this when a new image misbehaves. Nothing needs to be built.

### 4a. Move `latest` back (all containers of that image)

1. GitHub → **Actions** → **Retag image** → **Run workflow**.
2. Fill in:
   - **Image:** the image name, e.g. `asa-wine` or `fluxer-aio`
   - **Source tag:** `previous` (one step back), or a date / `sha-` tag
     (see Docker Hub for the list)
   - **Target tag:** `latest`
3. Wait for the green check.
4. Update the containers on Unraid as in section 3 (ASA: stop all first).

**Important:** this lasts only until the **next build** of that image (the
next push to its files, or the **monthly rebuild on the 2nd**), which moves
`latest` forward again. To stay on the older version longer, also do 4b.

### 4b. Pin a container to one version

1. Unraid → **Docker** → click the container → **Edit**.
2. Change **Repository** from `caaarrrlll/<image>:latest` to a fixed tag,
   e.g. `caaarrrlll/asa-wine:2026-11-17`.
3. **Apply**. The container now stays on that version through every future
   build.
4. To follow new builds again later, change the Repository back to
   `…:latest` and **Apply**.

### 4c. What a rollback does not undo

- **Data is not rolled back.** Game saves, the shared ASA install and
  fluxer-aio's database and files stay as they are.
- **fluxer-aio across Fluxer releases:** if the newer release already
  migrated the database, an older image may not work with it. Restore the
  database backup taken before the update (fluxer-aio README) together with
  the older image.

## 5. Fluxer release updates

New Fluxer releases arrive as a **pull request** on GitHub, opened by the
**Fluxer release watch** workflow (every Monday, or Actions → **Fluxer
release watch** → **Run workflow**). Nothing changes until it is merged.

1. Read the pull request: it lists the changed images and settings, and says
   whether its test build passed.
2. Back up fluxer-aio's database and data folder.
3. **Merge** the pull request. This starts a fluxer-aio build (section 1).
4. When the build is green, update the container (section 3).
5. If it misbehaves: roll back (section 4) and restore the backup (4c).

## 6. Set up an image on Unraid (first time)

1. Copy the image's template from this repository's `templates/` folder
   (e.g. `templates/fluxer-aio.xml`) to the Unraid flash drive folder
   `/boot/config/plugins/dockerMan/templates-user/`, renamed to
   `my-<name>.xml`.
2. Unraid → **Docker** → **Add Container** → choose the template.
3. Fill in the settings the template marks as required. The image's README
   explains each one and any requirement outside the container (database,
   reverse proxy, router ports, host settings).
4. **Apply**, then watch the container's log for the first start.

The templates in this repository contain generic defaults only; keep your
own filled-in copies on your server.

## 7. When something looks wrong

- **Container log:** Unraid → Docker → container icon → **Logs**.
- **Health:** fluxer-aio shows *healthy* / *unhealthy* in the Docker tab; its
  log names the failing part.
- **Builds:** GitHub → Actions → the run → the red step shows the error.
- **Monthly build not running:** GitHub pauses scheduled workflows in a
  repository with no activity for 60 days (it sends an email). Re-enable:
  Actions → **Build and push images** → **Enable workflow**.
