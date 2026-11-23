# fluxer-aio: Fluxer (https://github.com/fluxerapp/fluxer) in one container
# for Unraid, using an EXTERNAL Postgres, Redis and reverse proxy.
#
# Nothing is compiled here. Each Fluxer component is copied out of the
# official image pinned by the release's compose bundle (see
# upstream/RELEASE); NATS, LiveKit and Caddy are static binaries copied from
# their official images; Meilisearch's image is musl-linked, so its glibc
# release binary is downloaded instead. All official Fluxer images are Debian
# trixie, the same base as caaarrrlll/debian-slim-baseimage.
#
# Release bump: upstream/bump-release.py (run by the release-watch workflow)
# updates upstream/RELEASE, the *_IMAGE / MEILISEARCH_* ARG lines below and
# upstream/env. Keep those ARG lines as single `ARG NAME=value` lines.

# --- Upstream images (Fluxer release 2026.1123.15517) ------------------------
ARG FLUXER_API_IMAGE=ghcr.io/fluxerapp/fluxer-api@sha256:cb71d2c89cebf99e18681ed7223a440f53f7cb8773470e48a7bdc38e1fcab09d
ARG FLUXER_GATEWAY_IMAGE=ghcr.io/fluxerapp/fluxer-gateway@sha256:ef858c2e4a986e213a21402563b540609f45450ce9f5f073dc6ece4a6a81131a
ARG FLUXER_MEDIA_PROXY_IMAGE=ghcr.io/fluxerapp/fluxer-media-proxy@sha256:984f7a45fc942027ed96245d39963287aeba84d0ca300c5f0e8ad2d04b162411
ARG FLUXER_SERVER_IMAGE=ghcr.io/fluxerapp/fluxer-server@sha256:0210d41ef163cd3b5afe48dc8a8735249eade9cf199b89b394ae1eac5fb5a3d5
ARG FLUXER_STATIC_IMAGE=ghcr.io/fluxerapp/fluxer-static@sha256:178f55b2d9cc0b4daeaa25b75fd67e7af61e86ef49063d6209039f3262b79b14
ARG NATS_IMAGE=nats:2.14-alpine@sha256:311da47e2f31c26e99c623cd78d486a1e8ab039c49b32652770bb91a4f70512e
ARG LIVEKIT_IMAGE=livekit/livekit-server:v1.12.0@sha256:b1281e66e35e8f9749ffbcf0fe6ab4d40d1438aa00f36c2ea7e6975e5e261e2e
ARG CADDY_IMAGE=caddy:2.11-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0

# --- Source stages (files are copied out of these) -----------------------------
FROM ${FLUXER_API_IMAGE} AS api
FROM ${FLUXER_GATEWAY_IMAGE} AS gateway
FROM ${FLUXER_MEDIA_PROXY_IMAGE} AS media-proxy
FROM ${FLUXER_SERVER_IMAGE} AS server
FROM ${FLUXER_STATIC_IMAGE} AS static
FROM ${NATS_IMAGE} AS nats
FROM ${LIVEKIT_IMAGE} AS livekit
FROM ${CADDY_IMAGE} AS caddy

# --- Final image -----------------------------------------------------------------
FROM caaarrrlll/debian-slim-baseimage:trixie-latest

# --- Labels ----------------------------------------------------------------------
# Our scripts are MIT; the bundled Fluxer components are AGPL-3.0-or-later
# (source: https://github.com/fluxerapp/fluxer, release in upstream/RELEASE).
LABEL org.opencontainers.image.authors="Caaarrrlll"
LABEL org.opencontainers.image.source="https://github.com/Caaarrrlll/carl-homelab-dockers"
LABEL org.opencontainers.image.licenses="MIT AND AGPL-3.0-or-later"
LABEL org.opencontainers.image.description="Fluxer chat (unofficial all-in-one) for Unraid; needs external Postgres, Redis and a reverse proxy"

# --- Runtime libraries -----------------------------------------------------------
# media-proxy's list is copied from its upstream image; like upstream, the
# distro libheif is removed so media-proxy's own build in /usr/local/lib is
# used. gateway needs libstdc++6 + curl; openssl generates the secrets on
# first start; media-types replaces Alpine's mailcap for Caddy.
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        ca-certificates \
        curl \
        libaom3 \
        libcurl4t64 \
        libdav1d7 \
        libde265-0 \
        libjemalloc2 \
        liblcms2-2 \
        libstdc++6 \
        libvips42t64 \
        libwebp7 \
        libwebpdemux2 \
        libwebpmux3 \
        libyuv0 \
        media-types \
        openssl \
        xz-utils \
    && rm -f /usr/lib/*/libheif.so.1* \
    && rm -rf /var/lib/apt/lists/*

# --- PostgreSQL client (pg_dump for the pre-update backups) ---------------------
# From the PostgreSQL project's apt repository. The signing key file is pinned
# by SHA-256 (key fingerprint B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8, checked
# 2026-11-21). The client's major version must be the same as or newer than
# the Postgres server's (pg_dump refuses newer servers): see README "Backups".
ARG PG_CLIENT_MAJOR=18
ARG PGDG_KEY_SHA256=0144068502a1eddd2a0280ede10ef607d1ec592ce819940991203941564e8e76
RUN wget -qO /usr/share/keyrings/pgdg.asc \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "${PGDG_KEY_SHA256}  /usr/share/keyrings/pgdg.asc" | sha256sum -c - \
    && echo "deb [signed-by=/usr/share/keyrings/pgdg.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
        "postgresql-client-${PG_CLIENT_MAJOR}" \
    && rm -rf /var/lib/apt/lists/*
ENV PG_BIN=/usr/lib/postgresql/${PG_CLIENT_MAJOR}/bin

# --- s6-overlay (process supervisor) ---------------------------------------------
# Pinned version + SHA-256 (checked against the release's .sha256 files on
# 2026-11-18); the build fails on mismatch.
ARG S6_OVERLAY_VERSION=3.2.3.2
ARG S6_OVERLAY_NOARCH_SHA256=5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12
ARG S6_OVERLAY_X86_64_SHA256=e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408
RUN wget -qO /tmp/s6-noarch.tar.xz \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && wget -qO /tmp/s6-x86_64.tar.xz \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz" \
    && echo "${S6_OVERLAY_NOARCH_SHA256}  /tmp/s6-noarch.tar.xz" | sha256sum -c - \
    && echo "${S6_OVERLAY_X86_64_SHA256}  /tmp/s6-x86_64.tar.xz" | sha256sum -c - \
    && tar -C / -Jxpf /tmp/s6-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-x86_64.tar.xz \
    && rm -f /tmp/s6-*.tar.xz

# --- Meilisearch -----------------------------------------------------------------
# The official image is musl (Alpine) linked, so use the glibc release binary.
# Pinned version + SHA-256 (GitHub asset digest, 2026-11-18).
ARG MEILISEARCH_VERSION=1.53.0
ARG MEILISEARCH_SHA256=6751577f8e6b7e7399ba4cf644f307242d054778dd1f98129a973f1a1d0531a8
RUN wget -qO /usr/local/bin/meilisearch \
        "https://github.com/meilisearch/meilisearch/releases/download/v${MEILISEARCH_VERSION}/meilisearch-linux-amd64" \
    && echo "${MEILISEARCH_SHA256}  /usr/local/bin/meilisearch" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/meilisearch

# --- Fluxer components (paths documented in README "Upstream layout") ------------
COPY --from=api /usr/local/bin/node /usr/local/bin/node
COPY --from=api /usr/src/app /usr/src/app
COPY --from=gateway /opt/fluxer_gateway /opt/fluxer_gateway
COPY --from=media-proxy /usr/local/lib/ /usr/local/lib/
COPY --from=media-proxy /usr/local/bin/fluxer-media-proxy /usr/local/bin/fluxer-media-proxy
COPY --from=server /usr/local/bin/fluxer-server /usr/local/bin/fluxer-server
COPY --from=server /srv/app/static /srv/app/static
COPY --from=static /srv/fluxer-static /srv/fluxer-static
COPY --from=nats /usr/local/bin/nats-server /usr/local/bin/nats-server
COPY --from=livekit /livekit-server /usr/local/bin/livekit-server
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy

# --- Our files -------------------------------------------------------------------
# s6 services, start-up scripts, router Caddyfile, generated per-service
# environment (upstream/env, from upstream/gen-env.py). The build-time
# self-test fails the build on a missing library or invalid config.
COPY rootfs/ /
COPY upstream/env/ /etc/fluxer-aio/env/
COPY upstream/RELEASE /etc/fluxer-aio/RELEASE
RUN chmod 0755 /usr/local/bin/fluxer-aio-* \
    && find /etc/s6-overlay/s6-rc.d -name run -exec chmod 0755 {} + \
    && ldconfig \
    && /usr/local/bin/fluxer-aio-selftest

# --- Runtime settings ------------------------------------------------------------
ENV UID=99 \
    GID=100 \
    DATA_DIR=/data \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_KILL_GRACETIME=30000 \
    S6_SERVICES_GRACETIME=30000 \
    S6_VERBOSITY=1

VOLUME ["/data"]
EXPOSE 8080/tcp 7881/tcp 7882/udp

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD ["/usr/local/bin/fluxer-aio-healthcheck"]

# --- Start -----------------------------------------------------------------------
ENTRYPOINT ["/init"]
