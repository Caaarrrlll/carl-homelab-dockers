# Rate Limit Tracker — History

Historical record of completed tasks. The live checklist is
`RATE_LIMIT_TRACKER.md`. Archive only: read it when a task needs past context,
not as instructions.

Maintenance rule (see the live tracker): after a task is confirmed complete,
move its checklist section here, newest first.

---

## ROADMAP item 15, GameAnalytics log clutter (done 2026-11-18)

Every server logs `SQLITE3 FINALIZE ERROR: database disk image is malformed`
and `Database too large. Event has been blocked.` every ~8 s. Plan: a
per-container `--tmpfs` over the GameAnalytics folder (details in ROADMAP
item 15).

[✓] Record findings + fix plan in ROADMAP item 15 (2026-11-18)
[✓] Locate the GameAnalytics database on the shared install (2026-11-18)
    - host: `/mnt/cache/appdata/ark-sa-new/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics/7bc6def93c286385a4e1d75fb26f10ad/ga.sqlite3` (6.7 MB, last written 2026-11-18 00:10; folder created 2026-05-19); the only GA file on the install
    - container path to mount over: `/serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics`
    - found via `find … > \\TOWER\Swap\ASA\ga-find.txt` (SSH to Tower is off; appdata isn't shared)
[✓] Add the GameAnalytics `--tmpfs` to Extra Parameters (2026-11-18)
    - `templates/asa-wine.xml`: ExtraParams + Overview; `--tmpfs /serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics:rw,size=64m,mode=1777`
    - `\\TOWER\Swap\ASA\align-asa-templates.sh`: `EXTRA=` + header comment
    - new `\\TOWER\Swap\ASA\asa-rollout.sh` (outside the repo): stop all (save) → move GA folder aside → align `APPLY=1` → `update_container` one at a time, wait for `---Start Server---`, check tmpfs; dry run by default
    - ASA `README.md` (Resource limits), `audit.md` (snapshot + row), `HISTORY.md` (2026-11-18)
[✓] Verify locally (2026-11-18, simulated, not tested on Unraid)
    - template XML parses; both scripts `bash -n` OK (copies on the share have LF endings)
    - rollout dry run + `APPLY=1` with a stub `docker` / `update_container` and 13 synthetic templates: all stopped with save, GA folder moved aside, all 13 templates got the tmpfs, recreated in order (Astraeos first), summary running=true tmpfs=yes; failure path stops cleanly (tested by accident with a missing template folder)
    - align re-run changes 0 lines (idempotent); `git diff --check` clean
    - the redacted exports are gone from the share (deleted by the maintainer), so the dry run used templates generated from `templates/asa-wine.xml`
[✓] Maintainer rollout on Unraid (2026-11-18 ~07:30)
    - dry run done 2026-11-18 07:26: 13 containers, Astraeos first, `update_container` found, GA folder now 12 MB; only LostColony + Ragnarok running
    - script fixed after the dry run: it would have started all 13; now it restarts only the servers that were running (`START_ALL=1` to start all); re-tested with stubs for both `update_container` behaviours
    - `APPLY=1` run done; Lost Colony restarted cleanly (90 s full startup, 15.15 GB, all mods valid, fresh GA database)
[✓] Verify live (2026-11-18): each container has its own tmpfs GA folder (`df -h` shows `tmpfs`; different `ga.sqlite3` per server; host folder stays empty), and no `GameAnalytics` malformed / `db_too_large` lines in the logs; then move item 15 to `ROADMAP_HISTORY.md` and this section to the tracker history
    - result: LostColony + Ragnarok `df -h` = `tmpfs 64M`, own `ga.sqlite3` (07:34 / 07:35), host folder empty, no malformed / `db_too_large` lines
[✓] Clean boundary: item 15 moved to `ROADMAP_HISTORY.md`, this section to the tracker history


## Agent tracking setup (done 2026-11-18)

Task: adopt the tracker + history-archive setup from the sibling
`angular-template` project, to keep agent context lean.

[✓] Added `RATE_LIMIT_TRACKER.md`, `RATE_LIMIT_TRACKER_HISTORY.md`, `ROADMAP_HISTORY.md`
[✓] AGENTS.md: "Related instructions" reading order, archive rule, "Rate Limit Tracker (mandatory)", "Verification" table, updated doc-alignment rows
[✓] ROADMAP.md: lean header + "Standing policy" block; completed items moved to `ROADMAP_HISTORY.md`
[✓] Root README layout updated; `git diff --check` clean

## ASA cleanup, cluster template alignment and rollout (2026-11-17 → 2026-11-18)

Reconstructed after the fact (the tracker didn't exist yet); details are in
`HISTORY.md` (2026-11-17 entry), the audits and `ROADMAP_HISTORY.md`.

[✓] Validated the pending changes (`GB_FORCE_RESTART`, `ulimit`, CI `no-cache`) and fixed the stray `-${GB_FORCE_RESTART}` argument
[✓] Image work: per-map logs (`LOG_PREFIX`, verified `-LOG=` on ASA first), quoted launch arguments, Unraid-style permissions, save on stop over RCON (`gorcon/rcon-cli`, pinned), `AUTOSAVE_MINUTES` / `RCON_PORT`, small script fixes
    - commits `6b930a6` (rework) and `beb0b6b` (stop-handler fix after the first live stop test made no save)
[✓] CI: rollback tags (date / `sha-` / `previous`), Retag image workflow, Fedora opt-in locally, `**/*.md` excluded from rebuilds
[✓] Docs: ROADMAP (risk-rated), AGENTS alignment checklist, READMEs, audits, HISTORY, housekeeping
[✓] Unraid: 26 dead templates removed; 13 ASA templates aligned via `align-asa-templates.sh` (Gen1 port bug, NTSYNC + `--shm-size` + `--stop-timeout` everywhere, stale vars, mods per `Mods.txt`); `templates/asa-wine.xml` made the cluster standard
[✓] Live verification (maintainer, 2026-11-17/18): new image on all 13, per-map logs no longer overlap, NTSYNC, swap, save on stop, cluster up and joinable
    - open follow-ups moved to `docs/housekeeping.md` (item 8 autosave check, item 6 idle crashes)
