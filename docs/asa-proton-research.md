# Research: Wine vs Proton / GE-Proton for the ASA server (ROADMAP 14)

Started and finished 2026-11-21. Research only: nothing in the images
changed. **Decision (maintainer, 2026-11-21): item 14 parked** as recommended
below. When item 14 is closed for good, move this file to `docs/history/`
(date-first name).

## Question

The ASA image runs `ArkAscendedServer.exe` under plain WineHQ stable
(Wine 11) with NTSYNC (`caaarrrlll/asa-wine`, built on `wine-baseimage`).
Proton was dropped before the monorepo because it needed Steam logins and
was awkward in Docker (`HISTORY.md`, 2026-11-07). Is GE-Proton worth an
experiment now, and what would an image look like?

## Findings

### 1. Running GE-Proton without Steam works

The old blocker is gone. Several maintained ASA images run GE-Proton with no
Steam client and no Steam login:

- The launch is the `proton` script from the GE-Proton tarball, called
  directly: `proton run ArkAscendedServer.exe <params>`. Nobody uses
  `umu-launcher` or the Steam Linux Runtime (pressure-vessel), which would
  need bubblewrap/user namespaces inside Docker.
- Required environment: `STEAM_COMPAT_DATA_PATH` (where Proton keeps the
  prefix, as `<path>/pfx`) and `STEAM_COMPAT_CLIENT_INSTALL_PATH` (any
  existing folder; the script fails with a `KeyError` without it).
- SteamCMD keeps using `+login anonymous`, as today.
- Packages on top of a Debian base: `python3` (the `proton` launcher is a
  Python script) and 32-bit `libgcc`/libc, which our Debian/SteamCMD setup
  already has. Proton brings its own Wine build, so **no middle image** is
  needed: `debian-base` -> `asa-proton` is enough. A shared `proton-base`
  only makes sense once a second game uses Proton.
- The tarball is about 1 GB unpacked. One image is shared by all
  containers, so on disk and in the page cache it counts once.
- Headless display: one image (ludix0/asa) runs Xvfb plus a software Vulkan
  driver (lavapipe), saying the UE5 server "still tries to initialize a
  graphics device"; the others (mschnitzer, azixus, sknnr) run without any.
  Our Wine image runs without Xvfb today, so a Proton image should start
  without it too and add it only if the server needs it.

### 2. GE-Proton versions must be pinned

- GE-Proton 10-9 added NTSYNC; from **10-10** it is on by default when
  `/dev/ntsync` exists (same kernel and Unraid setup we already have;
  `PROTON_NO_NTSYNC=1` turns it off). The log shows
  `wineserver: NTSync up and running!`.
- Conflicting reports on GE-Proton 11 for ASA: one image
  (ferment9348/ark-survival-ascended, tested 2026-08) says GE-Proton 11,
  including 11-5, "hangs `ArkAscendedServer.exe` before it writes a single
  line of engine log" and pins **GE-Proton10-34**; another
  (ludix0/asa, updated 2026-11) pins **GE-Proton11-5**. mschnitzer pins
  GE-Proton10-17. Not verified by us.
- So: pin an exact version (with a checksum), never "latest", and treat a
  version bump like an image update (test first, rollback tag ready).

### 3. No image shares one install between servers

Every image reviewed gives **each server its own server files and its own
prefix**, and shares only the cluster transfer folder
(`-ClusterDirOverride`). Our design (all servers on one
`/serverdata/serverfiles`, one Wine prefix, one SteamCMD update) is unusual
and is the main risk for Proton:

- The `proton` launcher creates and **upgrades** the prefix itself when the
  Proton version changes (it copies its `default_pfx` and updates files on
  the first run of a new version). With one shared prefix, the first server
  to start on a new image would upgrade the prefix under the others.
- A Proton image therefore needs a **per-server prefix**
  (`STEAM_COMPAT_DATA_PATH` per container, outside the shared install),
  about 0.5–1 GB each. The shared install itself could stay.

### 4. Performance and stability: no evidence that Proton is better

- No head-to-head benchmark of plain Wine vs GE-Proton for the ASA
  **server** exists that we could find. ProtonDB reports are about the game
  client, not the dedicated server.
- RAM reported under Proton: "~13 GB per server instance" (mschnitzer),
  "a stock TheIsland_WP server settles around 10GB" (ferment9348). That is
  the game's own memory and the same order as under Wine.
- Known Proton-side issues seen in those projects: GE-Proton 11 hang above;
  a crash avoided by deleting `Win64/steamclient64.dll` before start
  (mschnitzer issue #123); very high CPU on Ubuntu 22.04 hosts. BattlEye is
  called unreliable under Proton (we already run `-NoBattlEye`).
- Our own situation: the idle crashes that motivated item 14 are fixed under
  Wine for Lost Colony (confirmed 2026-11-21, `docs/housekeeping.md`);
  Astraeos is still to be confirmed. NTSYNC already works with Wine 11.

## Recommendation

**Don't migrate, and don't start a Proton image now.** Proton has become
practical to run (no Steam, direct `proton run`), but there is no evidence
it would run ASA better than Wine 11 + NTSYNC, the problems that motivated
the item are fixed under Wine, and a Proton image would need a per-server
prefix and careful version pinning on top of the shared-install rules.

Keep item 14 as **parked with a trigger**: start the experiment only if a
Wine-specific problem appears that Wine can't fix (for example, Astraeos
keeps crashing at idle, or a game update breaks under WineHQ stable). The
experiment plan stays as in `ROADMAP.md` item 14, with these additions:

1. Separate image folder (`images/games/asa-proton-docker`), `FROM`
   `debian-base`, no middle image.
2. Pin GE-Proton (start with the 10.x line known to work, e.g. 10-34) with a
   SHA-512 check at build time, not a download at container start.
3. Per-container prefix via `STEAM_COMPAT_DATA_PATH`; test on one
   non-cluster server with its own copy of the server files.
4. No Xvfb unless the server needs it.

**Item 9 (`screen`/`xvfb`)** no longer needs to wait: a Proton image would
be a separate image with its own package list, so the Wine image can be
tested without `screen` and `xvfb` independently.

## Sources

- mschnitzer, ark-survival-ascended-linux-container-image (README,
  `root/usr/bin/start_server`, `appliance.kiwi`):
  https://github.com/mschnitzer/ark-survival-ascended-linux-container-image
- ferment9348/ark-survival-ascended (GE-Proton 11 warning):
  https://hub.docker.com/r/ferment9348/ark-survival-ascended
- ludix0/asa (GE-Proton11-5, Xvfb + lavapipe): https://hub.docker.com/r/ludix0/asa
- azixus, ARK_Ascended_Docker (Dockerfile, cluster notes):
  https://github.com/azixus/ARK_Ascended_Docker
- jsknnr, ark-ascended-server: https://github.com/jsknnr/ark-ascended-server
- GE-Proton 10-9 NTSYNC: https://www.gamingonlinux.com/2025/07/ge-proton-10-9-released-with-ntsync-and-fsr4-upgrade-support
- GE-Proton 10-10 NTSYNC by default: https://games.slashdot.org/story/25/07/28/0057226/easy-ntsync-arrives-for-steam-users-with-ge-proton-1010
- Proton outside Steam (`STEAM_COMPAT_CLIENT_INSTALL_PATH`):
  https://docs.aws.amazon.com/gameliftstreams/latest/developerguide/troubleshoot-compatibility-wp-proton.html
- ProtonDB, ASA (client reports only): https://protondb.com/app/2399830
