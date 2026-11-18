# Roadmap History

Historical record of completed roadmap items. The live roadmap is
`ROADMAP.md`. Archive only: read it when a task needs past context, not as
instructions.

Maintenance rule (see `ROADMAP.md`): when an item is confirmed complete, move
it here as one short entry (newest first) and delete it from the live
roadmap. Item numbers are never reused.

---

## Completed 2026-11-18: 15. GameAnalytics log flood

- **Problem:** every server logged `database disk image is malformed` and
  `Database too large. Event has been blocked.` every ~8 s.
- **Cause:** ARK's GameAnalytics database
  (`WINE64/drive_c/users/steam/AppData/Local/GameAnalytics/<key>/ga.sqlite3`)
  sat in the shared Wine prefix, so all 13 servers wrote to one file (6.7 MB
  on 2026-11-18 00:10, 12 MB by 07:26).
- **Fix:** template Extra Parameters `--tmpfs
  /serverdata/serverfiles/WINE64/drive_c/users/steam/AppData/Local/GameAnalytics:rw,size=64m,mode=1777`:
  a private in-memory folder per container, empty on every start; no image
  change. Rolled out with `asa-rollout.sh` + `align-asa-templates.sh` (network
  share); the script only restarts the servers that were running.
- **Rejected:** an image-made symlink to `/tmp` (needs a rebuild; dangling
  link on rollback).
- **Verified live 2026-11-18:** Lost Colony + Ragnarok each show their own
  `tmpfs` with a fresh `ga.sqlite3` (07:34 / 07:35); the host folder is
  empty; no malformed / `db_too_large` lines; normal GA chatter remains, plus
  one harmless `Validation fail … Device:Manufacturer:` warning per start
  (ARK's own bad event, not the database).

## Completed 2026-11-17 (ASA cleanup, commits `6b930a6`, `beb0b6b`)

Found in the 2026-11-17 full-repo review. Full detail: `HISTORY.md`
(2026-11-17) and the ASA `audit.md` change log.

- **2. Per-server logs**: shared `ShooterGame.log` replaced by
  `<LOG_PREFIX or MAP>-ShooterGame.log` via `-LOG=` (verified on ASA first);
  `tail -F` survives rotation; falls back to `ShooterGame.log`. Confirmed live
  2026-11-18: no more overlap in the Unraid log viewer.
- **3. Save on stop**: RCON `SaveWorld` → `DoExit` → `SIGTERM` fallback
  (`gorcon/rcon-cli` 0.10.3, SHA-256 pinned), RCON + autosave on the launch
  URL, template `--stop-timeout=60`. First live test made no save (trap order
  + `pidof`); fixed in `beb0b6b`, re-test passed.
- **4. Argument quoting**: launch arguments built as a bash array; the URL
  stays one argument, so names/passwords with spaces work (`?` still can't be
  used).
- **5. Permissions**: dropped the recursive `chmod 770` and `DATA_PERM`;
  `chown` only for mismatched files; Unraid convention (folders 777, files
  666, `UMASK=000`).
- **6. Image labels**: `source` → this monorepo; ASA got `licenses=MIT` +
  `LICENSE`.
- **7. Rollback tags**: CI pushes `YYYY-MM-DD` / `sha-<commit>`, keeps
  `previous`; manual **Retag image** workflow.
- **8. Fedora opt-in locally**: `BUILD_FEDORA=1` in the build scripts,
  matching CI.
- **10. Small script fixes**: `DEBUG` string compare, SteamCMD over HTTPS,
  `COPY` instead of `ADD` (Steam-credentials-in-`ps` accepted in the audit).
- **11. Base image READMEs**: Debian and Wine READMEs rewritten.
- **12. Unraid template**: `templates/asa-wine.xml` aligned with and verified
  against the 13 live templates; the live ones aligned via
  `align-asa-templates.sh`.
- **13. Workspace file**: `templates/`, `docs/`, `scripts/` added.
