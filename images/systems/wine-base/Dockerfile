# Wine (WineHQ stable) on the Debian base: the base of the ASA image.
FROM caaarrrlll/debian-slim-baseimage:trixie-latest

# --- Labels ------------------------------------------------------------------
LABEL org.opencontainers.image.authors="venter109@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/Caaarrrlll/carl-homelab-dockers"
LABEL org.opencontainers.image.licenses="MIT"

# --- WineHQ stable -------------------------------------------------------------
# Add the i386 architecture and the WineHQ repository (signed key), then
# install winehq-stable.
RUN dpkg --add-architecture i386 \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key \
    && echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ trixie main" \
        > /etc/apt/sources.list.d/wine.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
        winehq-stable \
    && rm -rf /var/lib/apt/lists/*

# --- Environment ---------------------------------------------------------------
ENV PATH="/opt/wine-stable/bin:${PATH}"
