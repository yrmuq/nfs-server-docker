#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

out=$(NFS_DRY_RUN=1 NFS_EXPORTS='/storage a(rw)\n\n/storage/docker b(rw)' sh entrypoint.sh)
expected='/storage a(rw)
/storage/docker b(rw)'
if [ "$out" != "$expected" ]; then
    printf 'escaped newlines:\n%s\n' "$out" >&2
    exit 1
fi

out=$(NFS_DRY_RUN=1 NFS_EXPORTS='/storage a(rw)
/storage/media c(rw)' sh entrypoint.sh)
expected='/storage a(rw)
/storage/media c(rw)'
if [ "$out" != "$expected" ]; then
    printf 'real newlines:\n%s\n' "$out" >&2
    exit 1
fi

if NFS_DRY_RUN=1 NFS_EXPORTS='   ' sh entrypoint.sh >/dev/null; then
    echo "blank exports should fail" >&2
    exit 1
fi
