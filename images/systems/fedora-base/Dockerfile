# Slim Fedora base image (parked: not built by default, see AGENTS.md).
FROM fedora:44

# --- Labels ------------------------------------------------------------------
# NOTE: the source label still points at the old debian-slim-baseimage repo
# (copy-paste leftover, see AGENTS.md "Notes / gotchas").
LABEL org.opencontainers.image.authors="Caaarrrlll"
LABEL org.opencontainers.image.source="https://github.com/Caaarrrlll/debian-slim-baseimage"
LABEL org.opencontainers.image.licenses="MIT"

# --- Packages ------------------------------------------------------------------
# Upgrade, install a few basic tools without weak dependencies, refresh the
# CA certificates and clean the dnf cache.
RUN dnf -y --setopt=install_weak_deps=False upgrade \
    && dnf -y --setopt=install_weak_deps=False install \
        ca-certificates \
        glibc-langpack-en \
        procps-ng \
        wget \
    && dnf -y reinstall ca-certificates \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# --- Environment ---------------------------------------------------------------
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
