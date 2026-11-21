# ARK: Survival Ascended dedicated server (SteamCMD + Wine) for Unraid.
FROM caaarrrlll/wine-baseimage:latest

# --- Labels ------------------------------------------------------------------
LABEL org.opencontainers.image.authors="venter109@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/Caaarrrlll/carl-homelab-dockers"
LABEL org.opencontainers.image.licenses="MIT"

# --- Packages ------------------------------------------------------------------
# 32-bit libraries for SteamCMD, plus screen, xvfb and winbind (see
# ROADMAP item 9 before removing screen/xvfb).
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        lib32gcc-s1 \
        lib32stdc++6 \
        lib32z1 \
        screen \
        winbind \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

# --- RCON client ---------------------------------------------------------------
# gorcon/rcon-cli, used to SaveWorld + DoExit on container stop.
# Pinned version + SHA-256 (verified against the release's checksum.txt on
# 2026-11-17); the build fails if the download doesn't match.
ARG RCON_CLI_VERSION=0.10.3
ARG RCON_CLI_SHA256=6962a641ebf9a5957bd0cda1b8acf3e34a23686ae709f6c6a14ac3898521a5cc
RUN wget -qO /tmp/rcon.tgz \
        "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_CLI_VERSION}/rcon-${RCON_CLI_VERSION}-amd64_linux.tar.gz" \
    && echo "${RCON_CLI_SHA256}  /tmp/rcon.tgz" | sha256sum -c - \
    && tar -xzf /tmp/rcon.tgz -C /tmp \
    && install -m 0755 \
        "/tmp/rcon-${RCON_CLI_VERSION}-amd64_linux/rcon" \
        /usr/local/bin/rcon \
    && rm -rf \
        /tmp/rcon.tgz \
        "/tmp/rcon-${RCON_CLI_VERSION}-amd64_linux"

# --- Paths ---------------------------------------------------------------------
ENV DATA_DIR="/serverdata" \
    XDG_RUNTIME_DIR=/tmp

ENV STEAMCMD_DIR="${DATA_DIR}/steamcmd" \
    SERVER_DIR="${DATA_DIR}/serverfiles"

# --- Server defaults (Unraid template variables) -------------------------------
ENV GAME_ID="2430930" \
    MAP="TheIsland_WP" \
    SERVER_NAME="ASA Docker" \
    SRV_PWD="Docker" \
    SRV_ADMIN_PWD="adminDocker" \
    VALIDATE=false \
    DEBUG=0 \
    NTSYNC=0 \
    GB_FORCE_RESTART=0 \
    LOG_PREFIX="" \
    AUTOSAVE_MINUTES=15 \
    RCON_PORT=27020

ENV GAME_PARAMS_EXTRA="-port=7777 -QueryPort=27015 -WinLiveMaxPlayers=20 -server -log -NoBattlEye" \
    SRV_CLUSTER_INFO="" \
    SRV_MOD_IDS=""

# --- User and permissions ------------------------------------------------------
ENV UMASK=000 \
    UID=99 \
    GID=100 \
    STEAM_USERNAME="" \
    STEAM_PASSWRD="" \
    USER="steam"

RUN mkdir $DATA_DIR \
    && mkdir $STEAMCMD_DIR \
    && mkdir $SERVER_DIR \
    && useradd -d $DATA_DIR -s /bin/bash $USER \
    && chown -R $USER $DATA_DIR

# --- Scripts and start ---------------------------------------------------------
COPY scripts/ /opt/scripts/
RUN chmod -R 750 /opt/scripts/

ENTRYPOINT ["/opt/scripts/start.sh"]
