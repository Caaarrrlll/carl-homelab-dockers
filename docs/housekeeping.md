# Housekeeping

Open **verification work on the running system**. Items 1–4 come from the
NTSYNC / Wine 11 migration (`docs/history/2026-11-07-ntsync-wine11.md`,
closed 2026-11-07); items 5–6 from the 2026-11-17 ASA cleanup (see
`HISTORY.md`). Nothing here needs a code change until an item is confirmed or
discarded. Code/doc work to do later lives in `ROADMAP.md`.

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | Reboot-persistence test for `modprobe ntsync` | **pending** | `/boot/config/go` contains the line (duplicate removed, static check passed 2026-11-07). After the next maintenance reboot, run `lsmod | grep ntsync` and `ls -l /dev/ntsync` **without manual intervention**. Until this passes, a reboot could silently drop the container back to plain wineserver sync. Blocked on server downtime (server actively used). |
| 2 | Re-check CPU at full player load | **optional** | Idle reference (2026-11-07): ~2.7–2.9% of one core vs ~high-3% pre-NTSYNC. Expect the gap to widen with concurrent player/entity load; compare `docker stats` CPU% and tick responsiveness under a full session. |
| 3 | Fedora base image re-activation | **parked** | `images/systems/fedora-base` is unused and excluded from CI tags/manual chains (`build_fedora` defaults to `false`). Re-enable when a workload actually needs it (see AGENTS.md note). |
| 4 | Verify the whole NTSYNC chain survived the first reboot | **same pass as item 1** | After reboot, also confirm the container start log shows `---NTSYNC enabled: /dev/ntsync is available, Wine will use it---`. |
| 6 | Confirm the idle-crash fixes on newer maps | **Lost Colony confirmed 2026-11-21; Astraeos still to confirm** | Crashes seen on Astraeos / Lost Colony after a long idle period. Changes made 2026-11-17: `vm.max_map_count=1048576`, a swapfile on the cache drive, `--shm-size=4g`, `ulimit -s 8192`. Leave a server on one of these maps idle past the old crash window, then check uptime and the log. If it still crashes, note which change to revisit. |
| 8 | Confirm autosave every `AUTOSAVE_MINUTES` (15) | **pending** | ARK receives `?AutoSavePeriodMinutes=15` on its launch line (confirmed in the `Commandline:` log entry 2026-11-17). Still to see: a world-save entry roughly every 15 minutes in a server's `<MAP>-ShooterGame.log` (e.g. `grep -iE "sav(ed|ing)" …/Logs/Astraeos_WP-ShooterGame.log \| tail`). |

## Record

When an item is confirmed, note the date and result below (and delete it from
the table):

- 2026-11-21 — Item 6, Lost Colony: stable since the per-server logging split
  and the NTSYNC/Wine update; its only restarts were for game patches and the
  port migrations (maintainer report). No idle crash since. Astraeos not yet
  reported, so item 6 stays open for it.

- 2026-11-07 — NTSYNC chain verified end-to-end on live server: kernel 6.18.58
  module loaded, `--device=/dev/ntsync`, `NTSYNC=1`, `WINENTSYNC=1`,
  `wine-11.0`, `ArkAscendedServer.exe` idle CPU as above.
- 2026-11-18: items 5 + 7 closed. All 13 live ASA templates aligned with
  `align-asa-templates.sh` (NTSYNC, `--shm-size=4g --stop-timeout=60`, Gen1
  ports 7772/27012, Scorched spelling, stale vars removed, Lily's Reusables
  removed, Auto Dino Wipes on Gen1) and recreated on the new image
  (`6b930a6` + `beb0b6b`). Verified: per-map logs (no more overlap in the
  Unraid log viewer), NTSYNC enabled, swap active, single quoted launch URL
  with RCON/autosave, save on stop (`SaveWorld: World Saved`), whole cluster
  up and joinable. Autosave interval check carried over as item 8.
