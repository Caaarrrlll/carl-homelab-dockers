# Slim Debian base image: the base of the Wine and fluxer-aio images.
FROM debian:trixie-slim

# --- Labels ------------------------------------------------------------------
LABEL org.opencontainers.image.authors="venter109@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/Caaarrrlll/carl-homelab-dockers"
LABEL org.opencontainers.image.licenses="MIT"

# --- Packages and locale -------------------------------------------------------
# Enable contrib/non-free, upgrade, install a few basic tools, generate the
# en_US.UTF-8 locale and refresh the CA certificates.
RUN echo "deb http://deb.debian.org/debian trixie contrib non-free non-free-firmware" \
        >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends \
        locales \
        procps \
        wget \
    && touch /etc/locale.gen \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && apt-get -y install --reinstall ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Environment ---------------------------------------------------------------
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
