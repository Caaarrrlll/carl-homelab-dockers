# History

Consolidated, dated record of significant decisions and upgrades for these
Docker images. Detailed working notes live in the referenced files; when a
long-running upgrade finishes, its tracking document is moved under
`docs/history/` with a date-first name (for example
`docs/history/2026-11-07-ntsync-wine11.md`) so entries sort chronologically,
and referenced from this file.

## 2026-11-18 — GameAnalytics log flood, agent tracking setup, repo rename

- **Repo renamed** `carl-gaming-dockers` → `carl-homelab-dockers`. Motivation:
  the maintainer wants one place for all their own homelab images and Unraid
  templates (for example future Fluxer / Stoat templates), not only the ASA
  chain. Plain upstream wrappers (such as Caddy) stay template-only and are not
  built here; larger projects with their own code (a planned multi-platform
  chat bot) get their own repo. Docker Hub image names are unchanged. The
  `org.opencontainers.image.source` labels and the template's
  Support/Project/TemplateURL/Icon now use the new name; the label change was
  committed with `[skip ci]` and ships with the next real build.

- **Problem:** every ASA server logged `SQLITE3 FINALIZE ERROR: database disk
  image is malformed` and `Database too large. Event has been blocked.` every
  ~8 s. Cause: ARK's GameAnalytics database
  (`WINE64/drive_c/users/steam/AppData/Local/GameAnalytics/<key>/ga.sqlite3`,
  6.7 MB) lives in the shared Wine prefix, so all 13 servers wrote to one
  file. Harmless to saves, but it buried the useful log lines.
- **Fix:** the template gives each container its own in-memory copy of that
  folder (`--tmpfs …/GameAnalytics:rw,size=64m,mode=1777`): never shared,
  empty on every start, no host folders, no image rebuild. Rolled out with a
  new `asa-rollout.sh` on the Swap share (stop all with save → move the old
  folder aside → `align-asa-templates.sh` → recreate one at a time with
  Unraid's `update_container`, waiting for each SteamCMD step; only the
  servers that were running are restarted). Verified live the same morning:
  each container has its own `tmpfs` database, the shared folder stays empty,
  and the error flood is gone. ROADMAP item 15 (now in `ROADMAP_HISTORY.md`).
- Agent tracking adopted from the `angular-template` project:
  `RATE_LIMIT_TRACKER.md` (+ history), `ROADMAP_HISTORY.md`, and AGENTS.md
  rules for reading order, the tracker and verification.

## 2026-11-17 — ASA image cleanup, Unraid template, uncached CI

- `images/games/asa-docker` moved further away from the generic ich777-style
  SteamCMD container toward an ASA-only image:
  - Removed the unused `GAME_PARAMS` env. Server flags now come only from
    `GAME_PARAMS_EXTRA` plus the dedicated map/session/cluster/mod variables.
  - `VALIDATE` is now declared once, as `false`. Only `true` triggers
    SteamCMD `validate`.
  - README rewritten to match the current image.
- New `GB_FORCE_RESTART` env (default `0`), always passed as
  `-GBUsageToForceRestart=<value>`. `0` keeps forced restarts disabled.
- `ulimit`: the no-op `ulimit -n 2048` in the Dockerfile `RUN` was removed,
  because limits set during a build don't carry into the running container.
  `start-server.sh` now sets `ulimit -s 8192` before launching Wine. The
  open-files limit, if ever needed, belongs in the template's Extra
  Parameters (`--ulimit nofile=…`).
- **Motivation:** the server was crashing on newer maps (Astraeos, Lost
  Colony) after sitting idle for a long time. The host and container changes
  below are all attempts to prevent that; they are not yet confirmed as a fix
  (tracked in `docs/housekeeping.md`).
- Host `vm.max_map_count` raised to **1048576**. `start-server.sh` and the docs
  now recommend that value; the script's hard minimum stays at 256000.
- Host: a swapfile on the cache drive (`/mnt/cache/swapfile`), enabled by an
  Unraid User Script on every reboot, together with the map count.
- Container: `--shm-size=4g` added to the template's Extra Parameters
  (Docker's default `/dev/shm` is 64 MB).
- Added `templates/asa-wine.xml`, the Unraid template that is now the
  **standard for the cluster's ASA servers**, verified against all 13 live
  templates: privileged (exposes `/dev/ntsync`, so no `--device` flag and a
  graceful fallback if the module is missing), `--restart=unless-stopped
  --shm-size=4g`, `NTSYNC=1`, `VALIDATE` as a `false|true` dropdown, shared
  paths, one shared cluster ID, ports `7760+n` / `27000+n`, base mods, no
  RCON port.
- Live templates: a dead-template cleanup removed 26 unused Unraid templates
  (Scryer and Weaver kept). The 13 ASA templates get aligned to the standard
  by `align-asa-templates.sh` on the Swap share. That script also fixes Gen1's
  ports (it used Bjarnheim's 7771/27011), adds NTSYNC and `--shm-size=4g`
  everywhere, fixes the "Scorched" spelling, removes stale variables, and
  applies the mod decisions: Lily's Reusables (930436) parked and removed,
  Auto Dino Wipes (947733) added to Gen1. Tracked in housekeeping item 5.
- Permissions aligned to Unraid's convention (`nobody:users`, folders 777,
  files 666 via `UMASK=000`). The recursive `chmod 770` on every start and the
  `DATA_PERM` env were removed (they made every file executable and produced a
  mix of `rwxrwx---` and `rw-rw-rw-` files), and the blanket `chown -R` became
  "only files with the wrong owner", so starting one server no longer
  rewrites the whole shared install. Existing files get a one-time host
  clean-up (see the ASA README, "Permissions").
- Per-server log files: new `LOG_PREFIX` env (blank = map name). Each server
  writes `ShooterGame/Saved/Logs/<prefix>-ShooterGame.log` via `-LOG=`
  (verified on the live `ASAAstraeos` server first), so servers sharing the
  install no longer overwrite one `ShooterGame.log`. The container follows the
  file with `tail -F` and falls back to `ShooterGame.log` if it never
  appears.
- Launch arguments are now built as a bash array, so server names and
  passwords with spaces or `*` reach ARK intact (`?` is still ARK's separator
  and can't be used). The literal quotes around `SessionName` were dropped.
- Rollback tags: CI now also pushes `YYYY-MM-DD` and `sha-<commit>` tags
  (`trixie-…` for Debian) next to `latest`, so the Unraid template can be
  pinned back to a known-good image. Before each rebuild, CI also copies the
  current `latest` to `previous` registry-side, and a manual **Retag image**
  workflow can point any tag (for example `latest`) at an older build, so
  builds, tagging and rollbacks all run on GitHub and Docker is no longer
  needed on the maintainer's PC.
- Cleanup: image `source` labels point at this monorepo; ASA gained a
  `licenses` label and `LICENSE`; local build scripts skip Fedora unless
  `BUILD_FEDORA=1` (matches CI); base image READMEs rewritten; workspace
  lists `templates/`, `docs/`, `scripts/`; template drops the separate
  Cluster Files mapping (cluster data lives in the shared install).
- **Save on stop:** stopping a container used to send ARK a plain `SIGTERM`
  (no reliable save), and Docker force-killed it after 10 s. Now `start.sh`
  sends RCON `SaveWorld` then `DoExit`, with `SIGTERM` only as a fallback;
  the template sets `--stop-timeout=60`. RCON (`RCON_PORT`, 27020, never
  mapped) and the autosave interval (`AUTOSAVE_MINUTES`, 15) are passed on the
  launch URL, so they no longer depend on the shared, partly outdated live
  `GameUserSettings.ini`. RCON client: `gorcon/rcon-cli` 0.10.3, pinned by
  SHA-256. The first live stop test made **no** save: the stop trap ended the
  `su` session before saving, and `pidof` didn't find the Wine process. Fixed
  the same day (save first, `pgrep -f`, session ended last). Re-test on the
  fixed image passed: `SaveWorld: World Saved`, then SIGTERM after `DoExit`
  (ARK under Wine doesn't exit within 15 s, which is harmless once saved).
- Small script fixes: `DEBUG` check no longer errors on an empty value,
  SteamCMD is downloaded over HTTPS, and the Dockerfile uses `COPY`.
- `ROADMAP.md` added (risk-rated open items); `AGENTS.md` gained a
  doc-alignment checklist.
- Decision: automatic crash restarts (ROADMAP item 1) are **parked**. With
  a shared install, a naive watchdog could run SteamCMD under running servers,
  so it needs a proper planning session first. Crashes are restarted by hand
  until then. All of today's changes need a server test before further
  roadmap work (housekeeping item 7).
- CI path filter ignores `**/*.md`, so README/audit/doc edits no longer
  rebuild images.
- CI: every image build now uses `pull: true` + `no-cache: true`, so base
  image and package updates are always picked up.

## 2026-11-07 — Unraid 7.3.4 upgrade + NTSYNC end-to-end

- Unraid upgraded **7.2.9 (kernel 6.12.90) → 7.3.4 (kernel 6.18.58)**, Docker
  engine 28.8.2. Kernel 6.18 ≥ 6.14, so the **NTSYNC** sync driver is available
  on the host for the first time.
- Host: `modprobe ntsync` verified, `/dev/ntsync` created, persistence added to
  `/boot/config/go`.
- `images/systems/wine-base` switched from Debian's packaged Wine (`wine-10.0`,
  no NTSYNC) to the WineHQ repo (`winehq-stable` = **Wine 11.0**, NTSYNC as a
  headline feature). Plain Wine kept on purpose — Proton required Steam logins
  and was painful in early Docker builds.
- `images/games/asa-docker` gained the `NTSYNC` env flag (`0`/`1`, mirrors
  `DEBUG`): validates `/dev/ntsync` at container start, exports
  `WINENTSYNC=1`, and falls back to ESync/FSync with a log warning when the
  device is missing.
- Unraid template: `NTSYNC=1` + Extra Parameters `--device=/dev/ntsync`.
- Result: end-to-end chain verified live (`lsmod` → device → flag → `wine-11.0`
  → `ArkAscendedServer.exe`). Idle CPU ~2.7–2.9% of one core vs ~high-3%
  before. Working notes: `docs/history/2026-11-07-ntsync-wine11.md`; open
  follow-ups: `docs/housekeeping.md`.

## 2026-11-07 — Monorepo migration

- The four image repositories (`docker-debian-baseimage`,
  `docker-fedora-baseimage`, `wine-baseimage`, `docker-steamcmd`) were
  consolidated into this repo via `git subtree` (history preserved under
  `images/`).
- Root CI (`.github/workflows/build-images.yml`) replaces the local
  `docker-updater` scripts for releases; builds/pushes run in dependency order
  (debian → wine → asa) with path-based selective rebuilds; validated with a
  full build and Docker Hub deploy on 2026-11-07.
- Old repositories retired via GitHub archive on 2026-11-07 (tags/releases
  remain on Docker Hub).
- Layout reorganised into `images/systems/` + `images/games/` (commit
  `04d4421`); per-image `audit.md` snapshots live alongside each Dockerfile.

## 2026-04/05 — Initial images (pre-monorepo)

- `caaarrrlll/debian-slim-baseimage:trixie-latest` — slim Debian base en_US
  locale, minimal packages.
- `caaarrrlll/wine-baseimage:latest` — Wine layered on the Debian base
  (`i386` enabled, winbind-friendly).
- `caaarrrlll/asa-wine:latest` — SteamCMD + ARK: Survival Ascended (app id
  `2430930`) for Unraid (`UID`/`GID` remap, `/serverdata` volumes).
- `caaarrrlll/fedora-baseimage:latest` — independent Fedora base, currently
  unused and excluded from CI (parked, see `docs/housekeeping.md`).
