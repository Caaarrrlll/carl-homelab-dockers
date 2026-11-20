# fluxer-aio

**Unofficial** all-in-one container for [Fluxer](https://github.com/fluxerapp/fluxer),
an open-source chat platform (text, voice, video), built for **Unraid**.

Fluxer's supported self-hosting is a Docker Compose stack of about 20
containers (or the `rexctl` installer). fluxer-aio runs the Fluxer parts in
**one container** and leaves the shared infrastructure to you:

| Inside the container | You provide |
|---|---|
| Fluxer api (+ background worker), gateway, media-proxy, and the Rust services (`fluxer-server`) | **Postgres** (16+, tested target 18) |
| NATS (JetStream), Meilisearch, LiveKit (voice/video) | **Redis** or Valkey |
| A small internal router (Caddy, plain HTTP) and the static web files | A **reverse proxy** with TLS (Caddy, nginx, …) and a domain |
| Uploads stored as files under `/data` (no S3 / SeaweedFS) | |

> **Bring your own Postgres, Redis and reverse proxy.** fluxer-aio does
> **not** include a database or a TLS proxy. It expects them to already run
> as **standalone** services (on Unraid: their own containers), for example
> a Postgres container, a Redis/Valkey container and a Caddy container that
> holds the certificate for your domain. The container will not start
> without the Postgres and Redis settings, and Fluxer is unusable without a
> proxy serving HTTPS. See [Requirements](#requirements).

It is not affiliated with or supported by the Fluxer project. Problems with
this image belong here, not upstream.

## How it is built

Nothing is compiled. The Dockerfile copies each component out of the
**official** Fluxer images pinned by digest by one Fluxer release's compose
bundle (`upstream/RELEASE`). All official Fluxer images are Debian trixie,
like this repo's `debian-slim-baseimage`. NATS, LiveKit and Caddy are static
binaries copied from their official images; Meilisearch's image is
Alpine/musl, so its glibc release binary is downloaded (SHA-256 pinned).
[s6-overlay](https://github.com/just-containers/s6-overlay) supervises the
processes and restarts any that exit.

The ~1,400 environment variables the bundle gives the services are **not
copied by hand**: `upstream/gen-env.py` converts the bundle's compose files
into `upstream/env/*.env`, and `fluxer-aio-env` evaluates them at start
exactly like Compose evaluates `.env`. A build-time self-test
(`fluxer-aio-selftest`) fails the CI build if a copied program is missing a
library or the router config is invalid.

## Requirements

- **Postgres**: an empty database and a role that owns it. Fluxer needs no
  extensions. Example (`psql` as an admin user):

  ```sql
  CREATE ROLE fluxer LOGIN PASSWORD '<strong password>';
  CREATE DATABASE fluxer OWNER fluxer;
  ```

  If the server is shared with other apps, check `max_connections`: with the
  defaults below fluxer-aio uses up to ~20 connections. Optional:
  `GRANT pg_read_all_settings TO fluxer;` silences a harmless api warning
  (`permission denied to examine "shared_preload_libraries"`).
- **Redis/Valkey** reachable from the container. Use a database index no
  other app uses (e.g. `/1`).
- **Reverse proxy** that terminates TLS for your domain and forwards
  **everything** (all paths, websockets) to the container's HTTP port.
  Requirements from upstream: websockets, bodies up to 512 MB, idle timeout
  1 h, `X-Forwarded-For` set to the client IP, no extra
  `Content-Security-Policy`. Caddy needs only:

  ```
  chat.example.com {
      reverse_proxy <unraid-ip>:<host-port>
  }
  ```

- **Voice/video**: forward **TCP 7881** and **UDP 7882** on your router to
  the Unraid host. Calls connect there directly, not through the reverse
  proxy or a tunnel. Screen sharing uses the same ports.

## Settings

Names follow Fluxer's own `.env` so upstream docs apply. Required:

| Variable | Example | Notes |
|---|---|---|
| `FLUXER_DOMAIN` | `chat.example.com` | Public domain (served by your reverse proxy). |
| `FLUXER_POSTGRES_HOST` | `<unraid-ip>` | Host/IP of your Postgres. |
| `POSTGRES_PASSWORD` | | Password of the Fluxer role (upstream name). |
| `FLUXER_KV_URL` | `redis://<unraid-ip>:6379/1` | Redis URL; include a password (`redis://:pw@host:6379/1`) if set. |

Common optional settings:

| Variable | Default | Notes |
|---|---|---|
| `FLUXER_POSTGRES_PORT` | `5432` | |
| `FLUXER_POSTGRES_DATABASE` / `FLUXER_POSTGRES_USERNAME` | `fluxer` | |
| `FLUXER_API_POSTGRES_MAX_CONNECTIONS` | `10` (upstream 25) | Pool of the api + embedded worker. |
| `FLUXER_USERS_POSTGRES_MAX_CONNECTIONS` / `FLUXER_MESSAGES_POSTGRES_MAX_CONNECTIONS` | `5` (upstream 20) | Pools in `fluxer-server`. |
| `FLUXER_LIVEKIT_NODE_IP` + `FLUXER_LIVEKIT_USE_EXTERNAL_IP=false` | (STUN) | Set your public IP if LiveKit can't detect it. |
| `FLUXER_LIVEKIT_TURN_SERVERS` | none | Needed for calls from networks that block UDP. |
| `UID` / `GID` | `99` / `100` | User the services run as (Unraid `nobody:users`). |

Any other variable from Fluxer's `.env.example` (email, SSO, push, limits…)
can be added to the container the same way; see
<https://docs.fluxer.com/operator/environment/>.

**Secrets** (`FLUXER_SUDO_MODE_SECRET`, `FLUXER_ERLANG_COOKIE`, the VAPID pair,
…) are generated on the first start with upstream's documented `openssl`
commands and stored in **`/data/secrets.env`** (mode 0600). Several must
never change once Fluxer has started: back this file up with `/data`. A value
set in the container settings always wins (a warning is logged if it
differs from the file).

## First start

1. Create the Postgres role/database and the reverse-proxy site.
2. Start the container and read its log. The first start prints a **setup
   token** (`[fluxer-aio-init] first start: setup token …`); it is also in
   `/data/secrets.env` as `FLUXER_SETUP_TOKEN`.
3. Open `https://<FLUXER_DOMAIN>` and enter the token to create the first
   admin account. The setup page talks about `rexctl` (Fluxer's own
   installer); ignore that. If the log has scrolled past the token, read it
   with `grep FLUXER_SETUP_TOKEN <data path>/secrets.env` on the host.

Missing required settings stop the container with a message naming them.

## Ports

Published (template):

| Container port | Use |
|---|---|
| `8080/tcp` | HTTP for your reverse proxy (map to any free host port). |
| `7881/tcp`, `7882/udp` | LiveKit voice/video, forwarded from the router. |

Internal only (127.0.0.1, for debugging): router `8080`, api `18080`,
gateway `18081` (Erlang distribution `18082`, epmd `4369`), admin `18083`,
media-proxy `18085`, app-proxy `18086`, Rust services `18090`–`18094`, NATS
`4222`/`8222`, Meilisearch `7700`, LiveKit HTTP `7880`.

## Data (`/data`)

| Path | Contents |
|---|---|
| `secrets.env` | Generated secrets and setup token. **Back up.** |
| `objects/` | Uploaded files (attachments, avatars, …). **Back up.** |
| `meilisearch/` | Search index (rebuildable, but large). |
| `nats/` | JetStream state. |
| `caddy/`, `tmp/`, `home/` | Router state, upload spool, scratch. |

The database itself lives in your Postgres: back it up there
(`pg_dump fluxer`).

## Logs and health

All services log to the container log, prefixed `[api]`, `[gateway]`,
`[fluxer-server]`, `[media-proxy]`, `[nats]`, `[meilisearch]`, `[livekit]`,
`[router]`. The Docker health check (`fluxer-aio-healthcheck`) reports the
first service that fails its own health endpoint.

## Updating to a new Fluxer release

Fluxer publishes releases often; fluxer-aio follows them through a **pull
request**, never automatically:

1. The **Fluxer release watch** workflow runs every Monday (or by hand:
   Actions → Fluxer release watch → Run workflow, optionally with a specific
   bundle tag). If there is a newer compose bundle it runs
   `upstream/bump-release.py`, which updates `upstream/RELEASE`, the
   Dockerfile `*_IMAGE` digests (and Meilisearch, if the bundle moves to a new
   minor version), regenerates `upstream/env/` and adds an `audit.md` row.
2. It test-builds the image (including the self-test) without pushing, then
   opens or updates a pull request whose description lists the changed
   images and every added/removed/changed environment variable.
3. Review it, merge it: the push to `main` rebuilds and publishes
   `fluxer-aio`. Then update the container on Unraid (Advanced View →
   force update).

By hand, the same bump is `python upstream/bump-release.py [--release <tag>]`
(it needs network access; no Docker). It stops with an error rather than
guessing when the bundle changes in a way it doesn't understand (for example
an internal address `gen-env.py` can't map).

Fluxer database migrations run on start; back up Postgres and `/data`
before updating.

## Limitations

- Unofficial: upstream supports only its compose stack and `rexctl`.
- One container means one memory limit; upstream's per-service limits don't
  apply. Upstream suggests at least 4 GB of RAM for an instance.
- The admin panel path is fixed at `/admin`.
- Not covered: the bundled SeaweedFS/S3 store, extra voice servers, ClamAV,
  the NSFW classifier service.

## License

The scripts and configuration in this folder are MIT (see `LICENSE`). The
image also contains Fluxer, licensed **AGPL-3.0-or-later**; its source is
<https://github.com/fluxerapp/fluxer> at the release named in
`upstream/RELEASE`. Third-party components (NATS, Meilisearch, LiveKit,
Caddy, s6-overlay) keep their own licenses.
