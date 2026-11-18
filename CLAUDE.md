# CLAUDE.md

@AGENTS.md

`AGENTS.md` (imported above) is the source of truth for the layout, build/CI,
conventions, doc-alignment checklist, Rate Limit Tracker and verification
rules. Don't duplicate it here. This file only adds what is specific to
working with Claude Code in this repo.

## Session start

1. Read `RATE_LIMIT_TRACKER.md`. If it has an active task, resume from its
   first unchecked item before doing anything else, and tell the maintainer
   which item you are resuming.
2. Read the "Standing policy" block of `ROADMAP.md` before touching an image,
   template or script.
3. Don't open the archives (`*_HISTORY.md`, `HISTORY.md`, `docs/history/`)
   unless the question is about past decisions.

## Local environment

- Windows host. Use the **Bash** tool (Git Bash) for `bash -n`, `grep`,
  `git` and stubbed shell simulations; PowerShell only for Windows-specific
  things.
- **No local Docker.** Never try to `docker build`/`push`; image builds are
  verified only by a green GitHub Actions run (`gh run list` / `gh run view`).
- **No access to the Unraid server.** Anything that must run there (live
  tests, `align-asa-templates.sh`, `asa-rollout.sh`, reboots) is a `[⏳]`
  tracker step with the exact command for the maintainer. Never mark it `[✓]`
  until they report the result.
- Python is available as `python` for XML checks, e.g.
  `python -c "import xml.etree.ElementTree as E; E.parse('templates/asa-wine.xml')"`.
- `core.autocrlf` is `false` and there is no `.gitattributes`: keep `*.sh`
  files **LF-only** (they run inside Linux containers). Check with
  `file <script>` if an edit tool may have introduced CRLF.

## Guardrails (summary of the rules that are easiest to break)

- Shared install: never add anything that runs SteamCMD automatically while
  other cluster servers might be running (see `AGENTS.md` gotchas and
  `ROADMAP.md`).
- Build scripts must keep requiring `DOCKERHUB_USER`; don't default it to
  `caaarrrlll`. Keep `FROM` lines pointing at `caaarrrlll/...`.
- ASA env var / port / volume changes touch all five places (Dockerfile,
  `start-server.sh`, ASA README, `templates/asa-wine.xml`, ASA `audit.md`).
- `templates/live/` is git-ignored and may hold secrets: read it for
  comparison if present, never commit it or quote secrets from it.
- A workflow-file edit rebuilds debian → wine → asa; add `[skip ci]` to the
  commit message when it shouldn't.

## Git

- Commit or push only when the maintainer asks. Work on `main` is the norm
  here (single-maintainer repo); don't create branches/PRs unless asked.
- Before committing: `git diff --check`, plus the checks for the change type
  from the "Verification" table in `AGENTS.md`. Say in the reply what ran.
- After a commit, replace any `_(this change)_` in `audit.md` change logs
  with the short hash in the next change that touches that file.

## Replies

- Report verification honestly: "CI green", "simulated, not tested on
  Unraid", or "not verified".
- When something is left for the maintainer, end with the exact command(s)
  to run on Unraid and what result to report back.
