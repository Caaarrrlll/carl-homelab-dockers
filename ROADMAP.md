# Roadmap

Live roadmap: open and planned work only. Completed items are moved to
`ROADMAP_HISTORY.md`.

**Maintenance rule:** when an item is confirmed complete, move it to
`ROADMAP_HISTORY.md` (one short entry) and record the fix in the relevant
`audit.md` and, if significant, `HISTORY.md`. Do it as part of the task's
clean boundary (see `RATE_LIMIT_TRACKER.md`), not later. Item numbers are
stable and never reused; gaps are completed items.

This file holds **code or doc changes still to make**. Checks to run on the
live server go in `docs/housekeeping.md`.

## Standing policy

Applies to every item below and to new work.

### Risk legend

Each item has a **Risk** rating: the chance that making the change breaks a
running container or the game data.

| Risk | Meaning | How to roll out |
|---|---|---|
| 🟢 Low | Docs, metadata, or a change that can't affect the running server. | Normal push. |
| 🟡 Medium | Changes start-up or runtime behaviour, but failures are visible and easy to revert. | Push when you can watch one container start; check the log; pin the template to a dated/`sha-` tag to roll back. |
| 🔴 High | Can stop servers from starting, lose progress, or corrupt the shared install. | Test on a single non-cluster container first, and only when you're home. Never during a pending ASA update. |

### Design constraint: shared server files

**Confirmed setup:** all servers (one per map in the cluster) run from the
**same** `/serverdata/serverfiles` install. This is deliberate: ASA is large,
and one shared install means one download per game update. Changes must keep
this working. Today every container start runs
`steamcmd +app_update` against that install. If one container restarts while
others are running, and an ASA update is out, SteamCMD rewrites files that the
running servers are using, which can corrupt the install. **Any automatic
restart must therefore never trigger an update.**

The same sharing also means the servers share:

- `ShooterGame/Saved/Logs/`: solved by per-server `LOG_PREFIX` log names
  (done 2026-11-17).
- `ShooterGame/Saved/Config/WindowsServer/*.ini`: one `GameUserSettings.ini` /
  `Game.ini` for every map; per-server differences must be command-line
  flags.
- The Wine prefix `serverfiles/WINE64`: each container runs its own
  `wineserver` on the same prefix. That's fine for reads, but registry writes
  at first-run or after a Wine upgrade can race.

## High priority

### 1. A crashed server leaves the container "running" (watchdog, done safely)
**Status: ⏸️ PARKED (2026-11-17).** Needs proper planning before any code is
written; that will happen at a later date. Do **not** implement the design
below as-is. Treat it as a starting point for that planning session. Until
then, crashed servers are restarted by hand.

**Risk: 🔴 High.** This changes the core start/stop loop; a mistake means
restart loops or servers that never come up.

`start-server.sh` starts `wine ArkAscendedServer.exe &`, then runs
`tail -F <LOG_PREFIX>-ShooterGame.log` in the foreground. If the server process dies (for
example the idle crashes on Astraeos / Lost Colony), `tail` keeps running, so
the container stays up with no server inside it. `start-watchdog.sh` exists
but is commented out, and simply re-enabling it plus a Docker restart policy
would be **unsafe**: the container would restart, run SteamCMD, and could
update the shared install under the other running servers (see the design
constraint above).

Proposed design: restart **inside** the container, never update:

1. Split `start-server.sh` into a one-time *update/prepare* phase (SteamCMD,
   Wine prefix) and a *run* phase (launch `ArkAscendedServer.exe`).
2. Supervise the server PID with a loop: if it exits unexpectedly, wait
   (for example 60 s), then relaunch **only the run phase**. SteamCMD never
   runs on an automatic restart.
3. Add `AUTO_RESTART` (`0`/`1`, default `0`) and a crash limit (for example
   `AUTO_RESTART_MAX=3` within an hour), after which the container stops
   retrying and logs a clear message, so a broken update can't loop forever.
4. Updates stay deliberate: they only happen when you restart the container
   yourself (all servers, ideally one at a time after stopping the others).
5. Optional extra guard: an `UPDATE_ON_START` flag (`true`/`false`) so
   containers that share an install can be set so only one "primary" server
   ever runs SteamCMD.
6. Optional extra guard: take a lock file (`flock` on
   `serverfiles/.update.lock`) around SteamCMD, so two containers started at
   the same time don't update simultaneously. This doesn't protect servers
   that are already running; that's what points 2–5 are for.

Directly relevant to housekeeping item 6: while this is parked, an idle crash
needs a manual restart.

### 16. CI driven by one list of images (dependency-aware rebuilds)
**Status: 📋 PLANNED (added 2026-11-20).** Next task after fluxer-aio; plan it
in `RATE_LIMIT_TRACKER.md` first.
**Risk: 🟡 Medium.** Only the build side changes (running containers keep
their image until they are updated), but a planner bug could skip or add
builds. Mitigation: the planner prints its decision in every run summary and
is tested locally (stub git diffs) before it replaces the current steps.

Adding fluxer-aio showed the hand-written workflow doesn't scale: every image
needs copied steps, long `if:` conditions and, to build one image alone, a
special input (`fluxer_only`). Maintainer's requirements (2026-11-20):

- **Dependents always follow their base, transitively**: a Debian change
  rebuilds wine, asa and fluxer-aio; a Wine change rebuilds only asa; a
  fluxer-aio change rebuilds only fluxer-aio.
- **Monthly** scheduled rebuild of the Debian base (and so everything on it),
  for upstream security fixes; no weekly schedule. Fedora stays opt-in.
  **Done 2026-11-21** as a `schedule` on the current workflow (all images,
  maintainer's choice); the redesign must keep it.
- **Manual runs** name the images to build (dependents included), replacing
  `fluxer_only` / `build_fedora`.

Design: one list (e.g. `.github/images.yml`: name, context, image, tag
prefix, parent, opt-in) read by a small stdlib-Python planner job; build jobs
by dependency level (bases, then children, then grandchildren), images on the
same level in parallel, all through the same keep-`:previous` / build / push
steps. The retag workflow's image list should come from the same file.

Done separately (2026-11-21): the local `docker-updater` scripts, the VS Code
build task and the `DOCKERHUB_USER` docs/guardrails were removed; CI on GitHub
is the only build path.

### 17. fluxer-aio: back up, upgrade, verify, then clean up (automatic on update)
**Status: 📋 PLANNED (added 2026-11-20).** Plan it in `RATE_LIMIT_TRACKER.md`
before writing code. Ideally ship it **before** merging the first release-watch
PR (#1), so that update is its first real test.
**Risk: 🟡 Medium.** Runs before Fluxer starts; a bug could block start-up
(fail-closed by design) or, worse, prune a backup that is still needed. The
order below exists to prevent the latter.

Fluxer migrates its database when a new release starts, and updates now
arrive regularly (item 16 / the release watch). The container should protect
itself on every **update** (not on a plain restart):

1. **Detect an update.** The image records the Fluxer release it contains
   (from `upstream/RELEASE`); `/data` records the release that last started
   successfully. Different = update. First start: record only, no backup.
2. **Back up**, in `fluxer-aio-init`, before any Fluxer service (and so any
   migration) starts:
   - `pg_dump -Fc` of the Fluxer database only (other databases on a shared
     Postgres are untouched), plus `secrets.env`, into a dated folder named
     `<old>-to-<new>`.
   - Check the dump is readable (`pg_restore --list`) before continuing.
   - On failure: **stop the container before Fluxer starts** (default), with
     a clear message; an option allows "warn and continue".
3. **Upgrade:** start the new release normally (migrations run in the api).
4. **Verify:** wait until the container's own health check
   (`fluxer-aio-healthcheck`) passes, i.e. every service is up on the new
   release, then record the new release as "last started successfully".
   If it doesn't become healthy within a time limit, log loudly, keep the
   backup, and do **not** record the new release (so the next start still
   treats it as an unverified update).
5. **Clean up only after verification:** prune old backups beyond the
   retention count. The backup of the update just verified is always kept;
   nothing is pruned while an update is unverified.

Also: `fluxer-aio-backup` for an on-demand backup (`docker exec`), README
restore steps (`pg_restore` into the Fluxer database + the matching
`secrets.env`, image rollback with the Retag workflow / `:previous`), and
`audit.md` notes.

Technical constraint: `pg_dump` must be the server's major version or newer.
Debian trixie ships client 17; a Postgres 18 server needs the client from the
official PostgreSQL apt repository (pinned major, SHA/keyring verified). If
the server is newer than the client, the backup fails (and so, by default,
the start), never silently skips.

Open decisions (maintainer): backups inside `/data/backups` or a separate
template path; fail-closed default confirmed?; how many backups to keep
(proposal: 3); time limit for verification (proposal: 10 min).

## Low priority

### 9. Possibly unused packages in the ASA image
**Status: ⛔ BLOCKED by item 14 (2026-11-18).** A Proton/Proton-GE image may
need `xvfb` (headless display) or similar, so don't remove anything until
the Proton research says what a future image needs.
**Risk: 🟡 Medium.** Removing a package Wine or SteamCMD quietly relies on
would only show up at runtime.

`screen` and `xvfb` are installed, but no script uses them. Test the server
without them and remove them if nothing breaks (smaller image, faster
`no-cache` builds). Keep `winbind` (Wine uses `ntlm_auth`).

## Future / research

### 14. Chore: Wine vs Proton / Proton-GE for the ASA server
**Status: 🔭 FUTURE (added 2026-11-17).** Research first; no code until the
research says Proton is worth trying.
**Risk: 🟢 Low** for the research; **🔴 High** for any later migration
(new runtime under all 13 servers and the shared install).

Today the server runs under plain WineHQ stable (Wine 11) with NTSYNC. Proton
was tried before the monorepo and dropped because it needed Steam logins and
was painful in Docker (see `HISTORY.md`, 2026-11-07). Proton-GE (GE-Proton)
can run without the Steam client, so it may be worth another look.

1. **Research:** look for benchmarks and stability reports for ASA dedicated
   servers on Wine vs Proton vs Proton-GE: CPU and RAM use at idle and under
   load, tick/FPS, crash reports (especially idle crashes on newer maps like
   Astraeos and Lost Colony), mod compatibility, NTSYNC support, and how each
   is run headless in Docker without Steam (e.g. `umu-launcher` or
   `proton run`). Write the findings down (`docs/`) before deciding.
2. **Only if Proton looks better:** experiment in a **new, separate image
   folder**, for example `images/games/asa-proton-docker` with its own tag
   (e.g. `caaarrrlll/asa-proton`). Never change the working Wine image in
   place. At that point consider renaming `images/games/asa-docker` to
   `images/games/asa-wine-docker` so the two sit side by side. The rename
   touches the CI path filter, the build scripts, the workspace file,
   AGENTS.md, the README and the audit; do it as its own change.
3. **Test** on a single, non-cluster container (its own server files copy,
   not the shared install) before any cluster server uses it.
4. **Migration** (if ever): its own planned change, with the rollback tags in
   place, like ROADMAP item 1.

## Suggested order

0. **Test first:** done 2026-11-18 (housekeeping items 5 + 7 closed). Item 15
   (GameAnalytics log flood) done 2026-11-18, see `ROADMAP_HISTORY.md`.
1. 📋 **Next:** item 16 (list-driven CI), after the fluxer-aio task closes.
   (The local build scripts are gone and the monthly rebuild is live.)
2. 📋 **Before merging fluxer-aio's first release PR:** item 17 (backup ->
   upgrade -> verify -> clean up). The maintainer does the shared-Postgres
   conversion (separate project) first (2026-11-20); item 17 is not blocked
   by it, but its `pg_dump` client must match the server's major version
   after the conversion.
3. 🔭 **P1 (was P2):** item 14 (Wine vs Proton / Proton-GE research).
4. ⛔ Item 9 (`screen`/`xvfb`) stays blocked until item 14's research is
   done.
5. ⏸️ Item 1 stays parked until a dedicated planning session.

Rollback for any of these: ASA README → "Rolling back to an earlier image".
