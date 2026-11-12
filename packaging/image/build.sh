#!/bin/bash
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
# Build amd64 and arm64, run the entrypoint on each, then push one manifest.

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage: build.sh <tag> [tag...]" >&2
    exit 1
fi

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

cache_from=()
cache_to=()
if [ -n "${GITHUB_ACTIONS:-}" ]; then
    cache_from=(--cache-from "type=gha")
    cache_to=(--cache-to "type=gha,mode=max")
fi

labels=(
    --label "org.opencontainers.image.source=https://github.com/yrmuq/nfs-server-docker"
    --label "org.opencontainers.image.revision=${GITHUB_SHA:-unknown}"
    --label "org.opencontainers.image.licenses=GPL-3.0-or-later"
)
if [ -n "${IMAGE_VERSION:-}" ]; then
    labels+=(--label "org.opencontainers.image.version=${IMAGE_VERSION}")
fi

check() {
    platform="$1"
    image="$2"
    docker buildx build --platform "$platform" --load "${cache_from[@]}" "${labels[@]}" -t "$image" .
    out="$(docker run --rm --platform "$platform" \
        -e NFS_DRY_RUN=1 \
        -e NFS_EXPORTS='/storage *(rw,fsid=0)\n/storage/docker *(rw,fsid=1)' \
        "$image")"
    [[ "$out" == *"/storage/docker"* ]]
}

check linux/amd64 nfs-server:check-amd64
check linux/arm64 nfs-server:check-arm64

tag_args=()
for tag in "$@"; do
    tag_args+=(-t "$tag")
done
docker buildx build --platform linux/amd64,linux/arm64 --push \
    "${cache_from[@]}" "${cache_to[@]}" "${labels[@]}" "${tag_args[@]}" .

docker buildx imagetools inspect "$1" | tee inspect.txt
grep -q 'linux/amd64' inspect.txt
grep -q 'linux/arm64' inspect.txt
