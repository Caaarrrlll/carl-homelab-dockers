# Audit Log — SteamCMD / ARK: Survival Ascended

## Image

| Item | Value |
|---|---|
| Source repo | `Caaarrrlll/carl-homelab-dockers` (monorepo, renamed from `carl-gaming-dockers` 2026-11-18; imported from `Caaarrrlll/docker-steamcmd`) |
| Docker Hub image | `caaarrrlll/asa-wine:latest` |
| Base image | `caaarrrlll/wine-baseimage:latest` |
| Build context | `images/games/asa-docker/` |
| Game | ARK: Survival Ascended, app id `2430930` |
| Last audited | 2026-11-21 |

## Current snapshot

- Installs `lib32gcc-s1`, `lib32stdc++6`, `lib32z1`, `screen`, `xvfb`, `winbind`.
- Runs as user `steam` with configurable `UID`/`GID` (defaults `99`/`100`).
- Stores data in `/serverdata` (`steamcmd/`, `serverfiles/`).
- Defaults: map `TheIsland_WP`, ports `7777`/`27015`, `VALIDATE=false`,
  `DEBUG=0`, `NTSYNC=0`, `GB_FORCE_RESTART=0`, `LOG_PREFIX=""`.
- Per-server log: the server gets `-LOG=<LOG_PREFIX or MAP>-ShooterGame.log`
  (`LOG_PREFIX` trimmed; blank = map name) and the container follows it with
  `tail -F`; falls back to `ShooterGame.log` after 20 s. `GAME_PARAMS_EXTRA`
  is for ARK flags only; `-LOG=` there is unsupported.
- Server flags come only from `GAME_PARAMS_EXTRA` plus the
  map/session/cluster/mod/restart variables. There is no generic `GAME_PARAMS`.
- `VALIDATE` is a boolean string: only `true` runs SteamCMD `validate`.
- Unraid template: `templates/asa-wine.xml`, a bare template with generic
  defaults (`NTSYNC=0`, no mods, `/mnt/user/appdata/asa-serverfiles`); the
  maintainer's live templates are kept outside this repo.
- `GB_FORCE_RESTART` is always passed to the server as
  `-GBUsageToForceRestart=${GB_FORCE_RESTART}`; `0` (default) disables the
  forced restart.
- `start-server.sh` sets `ulimit -s 8192` before launching Wine.
- Permissions: Unraid style via `UMASK=000` (folders 777, files 666). `start.sh`
  only `chown`s files with the wrong owner/group; no recursive `chmod`
  (`DATA_PERM` removed).
- Launch arguments are built as a bash array (`ARK_ARGS`) and passed as
  `"${ARK_ARGS[@]}"`; the map/session URL is one argument, so server names and
  passwords may contain spaces (but not `?`).
- Template mounts a per-container tmpfs over the shared Wine prefix's
  `AppData/Local/GameAnalytics` (ARK usage statistics), so the servers
  don't share, corrupt or fill one database.
- Graceful stop: `start.sh` sends RCON `SaveWorld` then `DoExit` (via
  `gorcon/rcon-cli` 0.10.3, SHA-256 pinned in the Dockerfile), falling back to
  `SIGTERM`. RCON and autosave are set on the launch URL
  (`RCON_PORT=27020`, internal only; `AUTOSAVE_MINUTES=15`). The template sets
  `--stop-timeout=60`.
- Labels: `source` = this monorepo, `licenses` = MIT (`LICENSE` file added).
- Entrypoint `/opt/scripts/start.sh`; server logic in `start-server.sh`.
- Targets the Unraid Docker template format.

## Change log

| Date | Commit | Change | Notes |
|---|---|---|---|
| 2026-11-21 | _(this change)_ | Code-style reformat | Dockerfile and `start.sh` / `start-server.sh` / `start-watchdog.sh` reformatted to the code-style standard (4-space indent, `if` blocks instead of `||`/`&&` shortcuts, split long lines; ARK launch URL assembled from pieces). No behaviour change: Dockerfile equivalence check; old vs new scripts produce identical transcripts in stubbed simulations (5 stop-handler scenarios with a real SIGTERM, 6 start-server scenarios incl. every Wine launch argument). Simulated, not tested on Unraid. |
| 2026-11-18 | `d862852` | template: bare, generic defaults | `templates/asa-wine.xml` no longer mirrors the maintainer's server: no share/script references, Server Files default `/mnt/user/appdata/asa-serverfiles`, Mod IDs empty, `NTSYNC` value `0` (matches the image default). README host-side examples use placeholder paths. No image change. |
| 2026-11-18 | `6a5d2ee` | source label → `carl-homelab-dockers` | Repo renamed on GitHub; `org.opencontainers.image.source` and the template URLs follow. Label-only, committed with `[skip ci]`: ships with the next real build (old URL redirects until then). |
| 2026-11-18 | `2d07cbf` | template: per-container tmpfs over GameAnalytics | Shared `WINE64/.../AppData/Local/GameAnalytics/<key>/ga.sqlite3` (6.7 MB) was corrupt + full (`malformed`, `db_too_large`), flooding every log. Template Extra Parameters add `--tmpfs /serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics:rw,size=64m,mode=1777`; no image change. Rolled out with `asa-rollout.sh` + `align-asa-templates.sh` (network share). |
| 2026-11-17 | `6b930a6`, `beb0b6b` | add `GB_FORCE_RESTART` env flag; move `ulimit`; CI `no-cache` | `GB_FORCE_RESTART` (default `0`) passed as `-GBUsageToForceRestart=<value>`. Removed no-op `ulimit -n 2048` from the Dockerfile `RUN` (build-time limits don't persist); `start-server.sh` now sets `ulimit -s 8192` before `wine`. CI builds now use `pull: true` + `no-cache: true` for all images. Removed the unused `GAME_PARAMS` env and the duplicate `VALIDATE` declaration (now a single `VALIDATE=false`). README rewritten for the current ASA-only image (variables, volumes/ports, `ulimit` notes). Added placeholder Unraid template `templates/asa-wine.xml`. `max_map_count` warning now recommends `1048576` (matches host); minimum check stays `256000`. Template Extra Parameters now include `--shm-size=4g`; README documents it plus the host swapfile/User Script. These changes are attempts to stop idle crashes on Astraeos / Lost Colony. Permissions: removed `DATA_PERM` and the recursive `chmod 770` in `start-server.sh` (it made every file executable and mixed with the `UMASK=000` files ARK creates); `start.sh` now only `chown`s mismatched files instead of `chown -R` on the shared install; scripts are `chmod 750` at build time. New `LOG_PREFIX` env (blank = map name): adds `-LOG=<prefix>-ShooterGame.log` (verified on ASA 2026-11-17), waits for/tails that file with `tail -F` (survives log rotation), and falls back to `ShooterGame.log` if it never appears. Launch arguments built as a bash array (`ARK_ARGS`) instead of an unquoted string; literal quotes around `SessionName` dropped (the URL is one argument, Wine quotes it). Labels: `source` → monorepo, added `licenses=MIT` + `LICENSE`. CI rollback tags `YYYY-MM-DD` / `sha-<commit>`. Template: dropped the separate Cluster Files mapping, added rollback note, then aligned to the live cluster standard (privileged, `--restart=unless-stopped --shm-size=4g`, shared paths, ports 7760/27000, the shared cluster ID, base mods). Small fixes (ROADMAP item 10): `DEBUG` check is now a string compare (no error when empty/non-numeric); SteamCMD downloaded over HTTPS from `steamcdn-a.akamaihd.net`, with a clear message if the download fails, and paths use `STEAMCMD_DIR`; Dockerfile uses `COPY scripts/` instead of `ADD`. Save on stop (ROADMAP item 3): added `rcon` (gorcon/rcon-cli 0.10.3, SHA-256 verified at build), new `AUTOSAVE_MINUTES` (15) and `RCON_PORT` (27020) envs passed on the launch URL, `term_handler` now does SaveWorld → DoExit → SIGTERM fallback; template `--stop-timeout=60`. Fix after the first live stop test (2026-11-17, no save made): the trap killed the `su` session before `term_handler` ran, and `pidof ArkAscendedServer.exe` is unreliable under Wine. Now the trap runs `term_handler` first, the server is found with `pgrep -f`, the session is ended last, and waits are 30 + 5 + 15 + 5 s (≤ 55 s). Re-test passed on the live server (World Saved before stop). |
| 2026-11-07 | `29ef23f` | add `NTSYNC` env flag | `start-server.sh` checks `/dev/ntsync` when `NTSYNC=1`, exports `WINENTSYNC=1`, warns and falls back to ESync/FSync when the device is missing; default `0` (disabled). Host must `modprobe ntsync` and pass `--device=/dev/ntsync`. |
| 2026-08-09 | `6c282ba` | change validation | |
| 2026-08-09 | `8e3499d` | add steam validate | |
| 2026-07-25 | `f104ee0` | add xdg folder | |
| 2026-05-06 | `17bf1a6` | fix naming issue | |
| 2026-05-06 | `d9bf5f8` | server name glitch | |
| 2026-05-06 | `db9667e` | Merge pull request #1 | from `testing-ich-code` |
| 2026-05-06 | `b9ee5f6` | add debug option and split out cluster and mods | |
| 2026-05-06 | `a8db4a4` | cleanup validate | |
| 2026-05-06 | `5c6ba65` | cleanup of scripts and add more env params | |
| 2026-05-06 | `cd0912e` | fix wine64 | |
| 2026-05-06 | `cd24ab8` | ich shells with my base image | |
| 2026-05-04 | `4eda0cc` | ich code with my base image | |
| 2026-05-04 | `00d4980` | latest push | |
| 2026-04-28 | `7b72eaf` | add watchdog and make slight changes | |
| 2026-04-25 | `e119865` | add CA certs to ark container | |
| 2026-04-25 | `b0ccf3f` | refactor to own images | |

## Known issues / follow-ups

- **Accepted:** default game passwords are baked into the Dockerfile
  (`SRV_PWD="Docker"`, `SRV_ADMIN_PWD="adminDocker"`). This image targets
  Unraid, whose template supplies both values at container creation, so the
  defaults are placeholders rather than usable credentials. Revisit if the
  image is ever offered outside Unraid.
- **Accepted:** with `DEBUG=1`, `start-server.sh` prints `SRV_PWD`,
  `SRV_ADMIN_PWD`, `LOGIN_CREDENTIALS`, and `ARK_RUN_STRING` (contains
  passwords) to the log. `DEBUG` defaults to `0`, and the log is only visible to
  someone already logged in to their own Unraid host. Do not enable `DEBUG=1`
  on a shared or publicly accessible system.
- **Accepted:** Steam credentials are passed to SteamCMD on the command line
  (visible in `ps` inside the container). Fine while the login is anonymous;
  revisit if a real Steam account is ever used.
- `NTSYNC=1` only helps when the host kernel provides the NTSYNC driver
  (Linux 6.14+, i.e. Unraid 7.3+ on the target host) **and** the device is
  passed to the container. Without it the container still starts and logs a
  fallback warning — by design, since NTSYNC is an optional performance
  feature.

## Audit checklist

- [ ] Base image tag still exists and builds.
- [ ] SteamCMD downloads and ARK app `2430930` updates successfully.
- [ ] `UID`/`GID` remapping works; file ownership on `/serverdata` is correct.
- [ ] Ports `7777`/`27015` and cluster/mod options behave as documented.
- [ ] `VALIDATE` logic matches the README.
- [ ] No default credentials or secret logging.
- [ ] No secrets or credentials added.
- [ ] `org.opencontainers.image.*` labels are correct.
- [ ] README matches actual behavior.
- [ ] Image builds and pushes successfully.
- [ ] This log is updated with the date, commit, and change summary.
