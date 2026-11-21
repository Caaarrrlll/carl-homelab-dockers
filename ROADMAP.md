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

## Low priority

### 9. Possibly unused packages in the ASA image
**Status: 🟢 OPEN, low priority (unblocked 2026-11-21).** Item 14's research
is done: a Proton image would be separate with its own package list, so this
no longer waits for it. Gain is image size and build time only: unused
packages use no RAM, so this does **not** lower server memory. Revisit later
(maintainer, 2026-11-21). The maintainer believes `screen`/`xvfb` were added
to silence warnings in the container log: when testing, compare the start-up
log with and without them and keep them if warnings come back.
**Order:** `screen` first (nothing calls it; it can't affect Wine), then
`xvfb` as its own change. **`screen` removed** (`7ce1b33`, tested on Unraid
2026-11-21: no new log errors, joinable, saves on stop). **`xvfb` removal**
in test since 2026-11-21.
**Risk: 🟡 Medium.** Removing a package Wine or SteamCMD quietly relies on
would only show up at runtime.

`screen` and `xvfb` are installed, but no script uses them. Test the server
without them and remove them if nothing breaks (smaller image, faster
`no-cache` builds). Keep `winbind` (Wine uses `ntlm_auth`).

## Future / research

### 14. Chore: Wine vs Proton / Proton-GE for the ASA server
**Status: ⏸️ PARKED (research done 2026-11-21, maintainer decision).**
Findings: [`docs/asa-proton-research.md`](docs/asa-proton-research.md).
No migration and no Proton image for now: no evidence Proton runs ASA better
or uses less RAM than Wine 11 + NTSYNC. **Trigger to restart:** a
Wine-specific problem Wine can't fix (e.g. Astraeos keeps crashing at idle,
or a game update breaks under WineHQ stable). Then follow steps 2-4 below
with the additions in the research doc (no middle image, pinned GE-Proton,
per-container prefix).
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
1. Item 9 (`screen`/`xvfb` removal test), low priority: smaller image only.
2. ⏸️ Item 14 (Wine vs Proton) parked 2026-11-21 until its trigger; research
   in `docs/asa-proton-research.md`.
3. ⏸️ Item 1 stays parked until a dedicated planning session.

Rollback for any of these: ASA README → "Rolling back to an earlier image".
