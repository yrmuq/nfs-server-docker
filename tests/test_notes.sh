#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
notes="sh packaging/release/notes.sh"

out=$(printf '%s\n' \
    "Add an NFSv4.2 server image." \
    "Merge branch 'dev'" \
    "Version 0.1.0." \
    "Fix the export parser." \
    "Remove UDP." \
    "Keep the host port." \
    | $notes commits)
expected='Added
- An NFSv4.2 server image.

Changed
- The host port.

Fixed
- The export parser.

Removed
- UDP.'
if [ "$out" != "$expected" ]; then
    printf 'commit subjects:\n%s\n' "$out" >&2
    exit 1
fi

out=$(printf '%s\n' "Add an export" | $notes commits)
expected='Added
- An export.'
if [ "$out" != "$expected" ]; then
    printf 'missing period:\n%s\n' "$out" >&2
    exit 1
fi

diff='diff --git a/Dockerfile b/Dockerfile
--- a/Dockerfile
+++ b/Dockerfile
@@ -1,2 +1,2 @@
-FROM alpine:3.24 AS nfs
+FROM alpine:3.25 AS nfs
-FROM alpine:3.24
+FROM alpine:3.25
diff --git a/.github/workflows/dev.yml b/.github/workflows/dev.yml
--- a/.github/workflows/dev.yml
+++ b/.github/workflows/dev.yml
@@ -1 +1 @@
-        uses: actions/checkout@v4
+        uses: actions/checkout@v5'
out=$(printf '%s\n' "$diff" | $notes deps)
expected='Dependency updates.
- `actions/checkout` v4 -> v5
- `alpine` 3.24 -> 3.25'
if [ "$out" != "$expected" ]; then
    printf 'dependency diff:\n%s\n' "$out" >&2
    exit 1
fi

if printf '%s\n' "Merge branch 'dev'" | $notes commits >/dev/null; then
    echo "empty commit notes should fail" >&2
    exit 1
fi

if $notes >/dev/null 2>&1; then
    echo "missing mode should fail" >&2
    exit 1
fi
