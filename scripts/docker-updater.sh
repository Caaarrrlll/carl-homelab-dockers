#!/usr/bin/env bash
# docker-updater.sh: build and push every image locally, in dependency order
# (debian -> [fedora] -> wine -> asa). Optional: CI on GitHub is the normal
# build path (see AGENTS.md "Building / releasing").
#
# Usage: DOCKERHUB_USER=myuser ./scripts/docker-updater.sh
#        (BUILD_FEDORA=1 also builds the parked Fedora image)

set -euo pipefail

# --- Repository root ---------------------------------------------------------------

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd)"
cd "$SCRIPT_DIR/.."

# --- Docker Hub namespace (required, never defaulted) ------------------------------

if [ -z "${DOCKERHUB_USER:-}" ]; then
    echo "Error: DOCKERHUB_USER is not set." >&2
    echo "Set it to your Docker Hub username, e.g. DOCKERHUB_USER=myuser $0" >&2
    exit 1
fi

# --- Helpers -----------------------------------------------------------------------

# buildpush <context> <tag>: build the image in <context> and push it as <tag>.
buildpush() {
    local context="$1"
    local tag="$2"

    echo
    echo "=== Building $context ==="
    docker image build -t "$tag" "$context"
    docker image push "$tag"
}

error() {
    echo
    echo "Build/push failed." >&2
    exit 1
}

trap error ERR

# --- Images, in dependency order -----------------------------------------------------

buildpush \
    "images/systems/debian-base" \
    "${DOCKERHUB_USER}/debian-slim-baseimage:trixie-latest"

# Fedora is parked: only build it when explicitly asked (BUILD_FEDORA=1), same as CI.
if [ "${BUILD_FEDORA:-0}" = "1" ]; then
    buildpush \
        "images/systems/fedora-base" \
        "${DOCKERHUB_USER}/fedora-baseimage:latest"
else
    echo
    echo "=== Skipping Fedora (set BUILD_FEDORA=1 to build it) ==="
fi

buildpush \
    "images/systems/wine-base" \
    "${DOCKERHUB_USER}/wine-baseimage:latest"

buildpush \
    "images/games/asa-docker" \
    "${DOCKERHUB_USER}/asa-wine:latest"

echo
echo "All images built and pushed."
