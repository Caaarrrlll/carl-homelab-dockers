# Rate Limit Tracker

Live checklist only. Completed tasks are moved to `RATE_LIMIT_TRACKER_HISTORY.md`.

**Maintenance rule:** when a task is confirmed complete, move its checklist
section to `RATE_LIMIT_TRACKER_HISTORY.md` (and its finished `ROADMAP.md` item
to `ROADMAP_HISTORY.md`) as part of the clean boundary. Don't let completed
sections pile up here.

Legend: `[ ]` pending · `[•]` in progress (list the files it touches) · `[✓]`
done and verified · `[✗]` dropped (say why) · `[⏳]` waiting on the maintainer
(live Unraid action or decision).

## Active task — rename repo to `carl-homelab-dockers` (2026-11-18)

Repo widened from ASA-only to the maintainer's homelab images. Docker Hub
image names do not change; no container needs recreating.

- [✓] 1. GitHub rename (maintainer)
  - Done 2026-11-18: https://github.com/Caaarrrlll/carl-homelab-dockers
- [✓] 2. Repo edits — touched: README.md, AGENTS.md, HISTORY.md,
  templates/asa-wine.xml, images/{systems/debian-base,systems/wine-base,games/asa-docker}/{Dockerfile,audit.md}
  - Old name → new in labels, template URLs, audit "Source repo" rows.
  - README/AGENTS intro: homelab monorepo, ASA chain is the current content.
- [✓] 3. Verify, commit with `[skip ci]`, set remote, push
  - `git diff --check` clean; `templates/asa-wine.xml` parses; old name only
    left in historical rows / rename notes. Commit: see `git log` (rename commit).
- [⏳] 4. Local move (maintainer): close VS Code, rename
  `E:\Code\carl-gaming-dockers` → `E:\Code\carl-homelab-dockers`, copy
  `C:\Users\Carl\.claude\projects\e--Code-carl-gaming-dockers\memory\` to
  `...\e--Code-carl-homelab-dockers\memory\`
- [⏳] 5. Unraid live templates (maintainer): replace the old name in
  `/boot/config/plugins/dockerMan/templates-user/my-*.xml` (command in step 3's reply)
- [ ] 6. Close: move this section to `RATE_LIMIT_TRACKER_HISTORY.md`

Previous (2026-11-18): ROADMAP item 15, GameAnalytics log flood
(see `RATE_LIMIT_TRACKER_HISTORY.md`).

Next after this (maintainer to confirm): ROADMAP item 14, Wine vs Proton / Proton-GE
research (now P1). Item 9 stays blocked until item 14's research is done.
(Old `GameAnalytics.bak-*` folder and `ga-find.txt` removed by the maintainer, 2026-11-18.)
