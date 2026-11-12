#!/bin/bash
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
# Make the GHCR package public and pull the published tag without credentials.

set -euo pipefail

tag="${1:?tag}"

ok=0
i=0
while [ "$i" -lt 6 ]; do
    if gh api --method PATCH \
        -H "Accept: application/vnd.github+json" \
        "/users/yrmuq/packages/container/nfs-server-docker" \
        -f visibility=public; then
        ok=1
        break
    fi
    vis="$(gh api /users/yrmuq/packages/container/nfs-server-docker --jq .visibility || true)"
    if [ "$vis" = "public" ]; then
        ok=1
        break
    fi
    i=$((i + 1))
    sleep 5
done
if [ "$ok" != 1 ]; then
    echo "the GHCR package is not public" >&2
    exit 1
fi

docker logout ghcr.io || true

i=0
while [ "$i" -lt 6 ]; do
    if docker pull "$tag"; then
        break
    fi
    i=$((i + 1))
    if [ "$i" -eq 6 ]; then
        exit 1
    fi
    sleep 5
done

out="$(docker run --rm \
    -e NFS_DRY_RUN=1 \
    -e NFS_EXPORTS='/storage *(rw,fsid=0)' \
    "$tag")"
[[ "$out" == *"/storage"* ]]
