# Audit Log — fluxer-aio (Fluxer all-in-one)

## Image

| Item | Value |
|---|---|
| Source repo | `Caaarrrlll/carl-homelab-dockers` (monorepo) |
| Docker Hub image | `caaarrrlll/fluxer-aio:latest` |
| Base image | `caaarrrlll/debian-slim-baseimage:trixie-latest` |
| Build context | `images/apps/fluxer-aio/` |
| Upstream | Fluxer `fluxer-release@2026.1118.90548` compose bundle (`upstream/RELEASE`) |
| Last audited | 2026-11-20 |

## Current snapshot

- Copies Fluxer api (Node 26.13.0), gateway (Erlang release with its own
  ERTS 16.4.0.7), media-proxy (+ its `/usr/local/lib`), fluxer-server (all
  Rust services) and the static web files from the official images, each
  pinned by digest in the Dockerfile.
- NATS 2.14, LiveKit 1.12.0, Caddy 2.11 copied from official images (static
  binaries, checked 2026-11-18); Meilisearch 1.53.0 glibc release binary
  (official image is musl-linked), SHA-256 pinned.
- s6-overlay 3.2.3.2 (SHA-256 pinned): oneshot `init-fluxer-aio`, longruns
  `svc-{nats,meilisearch,livekit,caddy,media-proxy,fluxer-server,api,gateway}`.
- Environment: `upstream/env/*.env` generated from the bundle by
  `upstream/gen-env.py`; fixed fluxer-aio values in
  `rootfs/etc/fluxer-aio/overlay/`. Internal addresses rewritten to
  127.0.0.1 ports (README "Ports").
- External Postgres/Redis/reverse proxy; uploads on the filesystem store
  under `/data/objects`; worker embedded in the api process.
- Homelab pool defaults: api 10, users 5, messages 5 (upstream 25/20/20).
- Secrets generated once into `/data/secrets.env` (0600); container settings
  override; setup token logged on the first start.
- Runs as `fluxer` with `UID`/`GID` (default `99`/`100`); `init` fixes
  ownership only when a top-level directory is wrong.
- Published ports: `8080/tcp` (HTTP), `7881/tcp` + `7882/udp` (LiveKit).
- Updates: `fluxer-release-watch` workflow opens a PR per new bundle
  (`upstream/bump-release.py`); nothing is published until it is merged.
- Build-time `fluxer-aio-selftest`: `ldd` on every binary, gateway NIF and
  node native module; versions; `caddy validate`; env evaluation.
- Labels: licenses `MIT AND AGPL-3.0-or-later`.

## Known issues / unverified

- Running on Unraid since 2026-11-18: text chat confirmed by the maintainer,
  bot voice through LiveKit confirmed (botsu roadmap, 2026-11-19).
  Person-to-person calls from outside the LAN not explicitly tested.
- ~~Embedded worker may lack upstream's worker-only settings.~~ Resolved
  2026-11-20 (verified on Unraid): the embedded worker logs
  `workerMode: all_lanes`, `cronSchedulerEnabled: true` and runs jobs.
- The api logs `permission denied to examine "shared_preload_libraries"`
  when the Fluxer role can't read server settings (shared Postgres).
  Harmless; README suggests `GRANT pg_read_all_settings TO fluxer;`.
- Bots verified 2026-11-20 (maintainer): the external bot (botsu) posts
  Twitch-live, YouTube-upload and YouTube-live alerts on this instance via
  the API and gateway, with link previews.
- Optional integrations (Klipy GIFs, YouTube previews) verified working
  2026-11-20. After adding a key, clients must reload: the app reads
  `services.gif_enabled` / `youtube_enabled` only when it starts.
- `FLUXER_SERVER_ADMIN__FLUXER_STORAGE_*` in `overlay/rust.env` assumes the
  combined Rust process reads per-service `FLUXER_SERVER_<SVC>__` overrides
  the same way as for ports (upstream only sets the filesystem store on its
  separate admin container).
- Gateway open-file limit: the template sets `--ulimit nofile=65536:65536`
  (upstream's value); without it the run script's `ulimit -n 65536` may be
  capped by Docker's default and logs a hint.

## Change log

| Date | Commit | Change | Notes |
|---|---|---|---|
| 2026-11-20 | `782aa6b` | Release watch: `upstream/bump-release.py` + `.github/workflows/fluxer-release-watch.yml` | Weekly/manual; bumps to the newest compose bundle (found via docs.fluxer.com/compose/latest), test-builds, opens a PR. Tested on a scratch copy against bundle 2026.1118.162713 (5 image digests, env unchanged) and the up-to-date path. |
| 2026-11-20 | `ee404f9` | Health check: s6 `/command` on PATH; report every failing probe | Docker showed `unhealthy` while all services worked: `docker exec`/HEALTHCHECK lack s6's `/command`, so `with-contenv` failed (`unable to exec ifelse`) in the media-proxy/fluxer-server probes. Confirmed on Unraid: the old script with that PATH passed in reports `healthy`. |
| 2026-11-18 | `63a3295` | Self-test: check only linux-x64 glibc node prebuilds | First CI build (run 44372472991) failed only on argon2's musl prebuild, which Node never loads on glibc. All binaries, versions, Caddyfile and env checks passed. |
| 2026-11-18 | `b144c4a` | New image | Fluxer 2026.1118.90548; see `RATE_LIMIT_TRACKER.md` (fluxer-aio) for the research and simulation record. |

## Review checklist

- [ ] On a release bump: `upstream/RELEASE`, Dockerfile `*_IMAGE` digests,
  `gen-env.py` re-run and diff reviewed, this snapshot updated.
- [x] CI build green (self-test passed) — 2026-11-18, run 44372903547.
- [x] First start on Unraid: services up, setup token works (2026-11-18);
  Docker `healthy` after `ee404f9` (2026-11-20, confirmed on Unraid).
- [ ] Text chat, voice; screen share (optional).
- [ ] `/data/secrets.env` and `objects/` included in backups.
