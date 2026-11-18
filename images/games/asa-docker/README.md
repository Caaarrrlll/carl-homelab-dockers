# ARK: Survival Ascended on Wine (Unraid)

`caaarrrlll/asa-wine:latest` runs an **ARK: Survival Ascended** dedicated
server (Steam app `2430930`) under **Wine 11** on Debian. On every start,
SteamCMD installs or updates the server and then launches
`ArkAscendedServer.exe` through Wine.

The image is built for **Unraid**. A bare template is in
[`templates/asa-wine.xml`](../../../templates/asa-wine.xml): copy it to
`/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` (one copy per
map) and add it from **Docker → Add Container**. It sets privileged mode,
`--restart=unless-stopped --shm-size=4g --stop-timeout=60`, shared server
files, cluster `mycluster` (placeholder) and ports `7760+n` / `27000+n`. Its
defaults are filled in for The Island; for another map change the name, map,
server name, both ports (and `-port` / `-QueryPort`) and the mod list, and set
your own paths, passwords and cluster ID. Set `NTSYNC=1` once the host has
the `ntsync` module (see below).

Image chain: `debian:trixie-slim` → `caaarrrlll/debian-slim-baseimage` →
`caaarrrlll/wine-baseimage` (WineHQ stable) → `caaarrrlll/asa-wine`.

## Host requirements

- **`vm.max_map_count` ≥ 256000; 1048576 recommended.** If it is below 256000, the container logs instructions and
  sleeps. Example: `echo 1048576 > /proc/sys/vm/max_map_count`
  - **Why the higher value:** the server was crashing on some of the newer
    maps (Astraeos, Lost Colony) after sitting idle for a long time. Raising
    the map count is one of several changes made to stop those crashes. The
    others are the swapfile below, `--shm-size=4g`, and `ulimit -s 8192` (see
    [Resource limits](#resource-limits-ulimit-and-shared-memory)).
  (to keep it after a reboot, put this in `/boot/config/go` or a User Script).
- **NTSYNC (optional, recommended):** needs a host kernel ≥ 6.14 (Unraid 7.3+)
  with `modprobe ntsync` in `/boot/config/go`. The container needs access to
  `/dev/ntsync`: the template runs **privileged**, which exposes it.
  Without privileged mode, use `--device=/dev/ntsync`, but then the container
  won't start at all if the module isn't loaded.

> **Optional: swapfile and startup script**
>
> A swapfile on a fast pool/cache drive (for example `/mnt/cache/swapfile`)
> gives the servers headroom when memory runs short. On Unraid, a User
> Script can apply both the map count and the swapfile on every boot:
>
> ```bash
> #!/bin/bash
> echo 1048576 > /proc/sys/vm/max_map_count
> swapon /mnt/cache/swapfile
> ```
>
> `swapon` needs the cache drive to be mounted, so on Unraid schedule the
> script **At Startup of Array** rather than at first boot.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SERVER_NAME` | `ASA Docker` | Session name shown in the server browser. Spaces are fine; `?` is not (it's ARK's option separator; the same goes for both passwords). |
| `MAP` | `TheIsland_WP` | Map to load. |
| `SRV_PWD` | `Docker` | Join password. The template overrides it. |
| `SRV_ADMIN_PWD` | `adminDocker` | Admin password. The template overrides it. |
| `GAME_PARAMS_EXTRA` | `-port=7777 -QueryPort=27015 -WinLiveMaxPlayers=20 -server -log -NoBattlEye` | ARK server flags only, appended after the map/session string. Keep the ports in sync with the port mappings. Settings that have their own variable (log name, mods, cluster, forced restart) go in that variable, not here. |
| `SRV_MOD_IDS` | _(empty)_ | Comma-separated CurseForge mod IDs, passed as `-mods=`. |
| `SRV_CLUSTER_INFO` | _(empty)_ | Cluster ID. When set, the server gets `-clusterid=<id> -clusterDirOverride=/serverdata/serverfiles/clusterfiles`. |
| `GB_FORCE_RESTART` | `0` | Always passed as `-GBUsageToForceRestart=<value>`. `0` disables the forced restart. |
| `AUTOSAVE_MINUTES` | `15` | World autosave interval, passed as `?AutoSavePeriodMinutes=` (overrides `GameUserSettings.ini`). Also the most progress a crash can lose. |
| `RCON_PORT` | `27020` | RCON port **inside** the container, passed as `?RCONEnabled=True?RCONPort=`. Used to save the world on stop. Never map it to the host. |
| `LOG_PREFIX` | _(empty)_ | Log file prefix: the server writes `ShooterGame/Saved/Logs/<prefix>-ShooterGame.log` (via `-LOG=`), and the container follows that file. Leading/trailing spaces are trimmed; blank = the map name (for example `Astraeos_WP-ShooterGame.log`). Set it only if two servers run the same map. This is the only supported way to name the log; don't put `-LOG=` in `GAME_PARAMS_EXTRA`. If the file doesn't appear within 20 s, the container falls back to `ShooterGame.log`. |
| `NTSYNC` | `0` | `1` = use `/dev/ntsync` (exports `WINENTSYNC=1`). If the device is missing, the container logs a warning and Wine uses ESync/FSync instead. |
| `VALIDATE` | `false` | `true` = run SteamCMD `validate` on every start (slow). |
| `DEBUG` | `0` | `1` = print troubleshooting info to the log. **This includes passwords.** |
| `GAME_ID` | `2430930` | Steam app ID. Use `2430930 -beta BRANCH` for a beta branch. |
| `STEAM_USERNAME` / `STEAM_PASSWRD` | _(empty)_ | Steam login. Leave both empty for anonymous login. |
| `UID` / `GID` | `99` / `100` | User and group the server runs as (Unraid `nobody:users`). |
| `UMASK` | `000` | umask for files the server creates (`000` = Unraid style: folders 777, files 666). |

## Permissions

The image follows Unraid's appdata convention: owner `nobody:users`
(`UID`/`GID` 99/100), folders `777`, files `666`, via `UMASK=000`.

- On start, `start.sh` only `chown`s files whose owner or group doesn't match
  `UID`/`GID`. Nothing else is touched, which matters because all cluster
  containers share the install.
- There is no recursive `chmod` any more (the old `DATA_PERM=770` step was
  removed on 2026-11-17). SteamCMD and `tar` keep the execute bits their own
  binaries need, and Wine doesn't need execute bits on `.exe`/`.dll` files.
- To clean up files left with the old `770` permissions, stop **all** ASA
  containers and run once on the host:

  ```bash
  SF=/mnt/user/appdata/asa-serverfiles   # your shared serverfiles path
  chown -R nobody:users "$SF"
  find "$SF" -type d -exec chmod 777 {} +
  find "$SF" -type f -exec chmod 666 {} +
  ```

  Don't run the `666` step on the SteamCMD folder; it contains Linux binaries
  that need their execute bit.

## Volumes and ports

| Container path | Purpose |
|---|---|
| `/serverdata/steamcmd` | SteamCMD install |
| `/serverdata/serverfiles` | Server files, the Wine prefix (`WINE64/`) and saves |

Cluster transfer data lives in `serverfiles/clusterfiles` (set via
`-clusterDirOverride` when `SRV_CLUSTER_INFO` is set), so servers that share
the install automatically share the cluster folder. No separate mapping is
needed.

**Shared install:** on the target server, every cluster container mounts the
**same** host folder at `/serverdata/serverfiles`. ASA is large, so this saves
disk space and means one download per game update. Things to know:

- Every container start runs a SteamCMD update. Restarting one container
  while others are running, when an ASA update is out, can update files under
  the running servers. Stop all servers before restarting for an update, then
  start them one at a time.
- The servers share `ShooterGame/Saved/Config/WindowsServer/*.ini` and the
  Wine prefix (`WINE64/`); per-server differences must be command-line flags
  (template variables).
- The servers share the `ShooterGame/Saved/Logs` folder, so each one writes
  its own `<LOG_PREFIX>-ShooterGame.log` (map name by default) instead of one
  shared `ShooterGame.log`.

| Port | Purpose |
|---|---|
| `7777/udp` | Game (`-port`) |
| `27015/udp` | Query (`-QueryPort`) |

RCON runs on `RCON_PORT` (27020) **inside** each container only. It is
deliberately not mapped to the host, so all servers can use the same port and
it isn't reachable from the network.

## Stopping and saving

When the container is stopped (Unraid stop, update, array stop, reboot),
`start.sh` shuts ARK down in this order:

1. RCON `SaveWorld` (up to 30 s). The log shows `---SaveWorld: World Saved---`.
2. RCON `DoExit`, then up to 15 s for the server to exit.
3. Only if the server is still running (or RCON was unreachable, for example
   during start-up): `SIGTERM`, then up to 5 s. The log then shows a warning
   that no save was made.

Worst case is about 55 s, inside the 60 s stop timeout. The server process is
found by its command line (`pgrep -f ArkAscendedServer.exe`), and the `su`
session that runs `start-server.sh` is ended only after the save.

The template sets `--stop-timeout=60`. Docker's default is 10 s, after which
it force-kills the container mid-save. If saves on a large map ever take
longer, raise both the stop timeout and the 30 s save limit in `start.sh`.

RCON uses `SRV_ADMIN_PWD`, which is on ARK's launch line. Nothing needs to be
set in `GameUserSettings.ini` for this (the launch options override it).

### Updating the shared `GameUserSettings.ini` / `Game.ini`

All servers read one `ShooterGame/Saved/Config/WindowsServer/` folder, and
ARK **rewrites `GameUserSettings.ini` when it shuts down**. So replace these
files only while **all** ASA containers are stopped, otherwise a server that
stops later overwrites your change. On the Unraid host (adjust the source
path to wherever your master copies live):

```bash
LIVE=/mnt/user/appdata/asa-serverfiles/ShooterGame/Saved/Config/WindowsServer
SRC=/path/to/your/master/copies
for f in GameUserSettings.ini Game.ini; do
  cp -a "$LIVE/$f" "$LIVE/$f.bak-$(date +%F)"
  cp "$SRC/$f" "$LIVE/$f"
  chown nobody:users "$LIVE/$f" && chmod 666 "$LIVE/$f"
done
```

To compare before copying, run
`diff "$LIVE/GameUserSettings.ini" "$SRC/GameUserSettings.ini"`.
The live file may contain passwords, so don't paste that output anywhere.

## Resource limits (`ulimit` and shared memory)

- **GameAnalytics (tmpfs):** ARK's built-in usage-statistics database lives
  in the shared Wine prefix (`WINE64/drive_c/users/steam/AppData/Local/GameAnalytics`).
  Shared by all servers, it got corrupted and full, and every server logged
  `database disk image is malformed` / `Database too large` every few
  seconds. The template mounts a small per-container RAM folder over it:
  `--tmpfs /serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics:rw,size=64m,mode=1777`.
  It holds nothing related to saves and starts empty on every container
  start. The old shared file was kept as `GameAnalytics.bak-<time>` on the
  host by the rollout.
- **Shared memory:** Docker gives containers only 64 MB of `/dev/shm` by
  default. The template's Extra Parameters add `--shm-size=4g`, as part of
  the attempt to stop the idle crashes on newer maps (see Host requirements).
  This can't be set from inside the image; it has to be a `docker run` /
  Extra Parameters flag.
- **Stack size:** `start-server.sh` runs `ulimit -s 8192` right before it
  launches Wine.
- **Open files:** the image does not change this limit. Setting a `ulimit`
  inside a Dockerfile `RUN` step only affects that build step, so it has no
  effect on the running container (an earlier `ulimit -n 2048` there was
  removed for this reason). If the server needs more file handles, set the
  limit when the container starts, for example by adding
  `--ulimit nofile=SOFT:HARD` to the Unraid template's Extra Parameters. To
  see the current limit, run `docker exec <container> sh -c 'ulimit -n'`.

## Run example

```bash
docker run --name ASA-Wine -d \
  -p 7777:7777/udp -p 27015:27015/udp \
  --device=/dev/ntsync \
  --shm-size=4g \
  --stop-timeout=60 \
  --env 'SERVER_NAME=My ASA Server' \
  --env 'MAP=TheIsland_WP' \
  --env 'SRV_PWD=changeme' \
  --env 'SRV_ADMIN_PWD=changeme-admin' \
  --env 'NTSYNC=1' \
  --env 'VALIDATE=false' \
  --env 'GB_FORCE_RESTART=0' \
  --env 'UID=99' --env 'GID=100' \
  --volume /mnt/cache/appdata/steamcmd:/serverdata/steamcmd \
  --volume /mnt/cache/appdata/asa:/serverdata/serverfiles \
  caaarrrlll/asa-wine:latest
```

If `/dev/ntsync` does not exist on the host, leave out `--device=/dev/ntsync`;
otherwise Docker refuses to start the container.

## Rolling back to an earlier image

If a new image breaks the servers, go back to an earlier build. Everything
happens on GitHub and Docker Hub; no Docker install is needed on your PC.

### Which tags exist

Every CI build of `caaarrrlll/asa-wine` is pushed under several tags:

| Tag | Points at | Use it for |
|---|---|---|
| `latest` | The newest build | Normal use (the template's default) |
| `previous` | The build that `latest` replaced | One-step rollback |
| `YYYY-MM-DD` | The last build on that date (e.g. `2026-11-17`) | Going back further |
| `sha-<commit>` | The build from that exact commit (e.g. `sha-abc1234`) | Pinning an exact version |

See all tags on Docker Hub: `hub.docker.com/r/caaarrrlll/asa-wine/tags`.
`previous` only remembers **one** build back. If two builds happened since the
good one, use a date or `sha-` tag.

### Option A: move `latest` back (recommended)

The template stays on `:latest`; you change what `latest` points at.

1. On GitHub, open **Actions → Retag image → Run workflow**.
2. Fill in:
   - **Image:** `asa-wine`
   - **Source tag:** `previous` (or a date / `sha-` tag)
   - **Target tag:** `latest`
3. Wait for the run to go green. Its summary shows `…:previous → …:latest`.
4. In Unraid → **Docker**, stop **all** ASA containers (they share the
   install), then use **Force Update** on each. Start them **one at a time**,
   checking each log before starting the next.

The next CI build overwrites `latest` again, so fix the problem (or revert the
commit) before pushing more ASA changes.

### Option B: pin one container to a tag

Use this to test an older or newer build on one server without touching the
others.

1. In Unraid, edit the container and change **Repository** from
   `caaarrrlll/asa-wine:latest` to, for example,
   `caaarrrlll/asa-wine:2026-11-17`.
2. Apply. Unraid pulls that tag and recreates the container.
3. Change it back to `:latest` once the problem is fixed, otherwise the
   container never gets updates.

### Things to keep in mind

- **Game files are not rolled back.** The image holds only Wine and the
  scripts; ARK itself lives in the shared `serverfiles` folder and is updated
  by SteamCMD. A rollback undoes image changes, not ASA game updates.
- **Saves are not touched** by either option. Restore saves from the weekly
  backup if you need to.
- **Base images** (`wine-baseimage`, `debian-slim-baseimage`) can be rolled
  back the same way, but the running server only uses `asa-wine`, which
  already contains them. Rolling back `asa-wine` is almost always enough.

## Credits

This image started from ich777's SteamCMD game-server containers. It has since
been narrowed down to ARK: Survival Ascended only, and runs on this repo's own
Debian and Wine base images.
