#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
# Bring deps forward to main. Dependency commits that are only on deps stay.
# VERSION follows main, so the next prerelease continues the current release.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

git fetch origin refs/heads/main
if ! git fetch origin refs/heads/deps; then
    git push origin refs/remotes/origin/main:refs/heads/deps
    exit 0
fi
if git merge-base --is-ancestor origin/main origin/deps; then
    exit 0
fi
if git merge-base --is-ancestor origin/deps origin/main; then
    git push origin refs/remotes/origin/main:refs/heads/deps
    exit 0
fi

git checkout --detach origin/deps
if ! git merge --no-ff origin/main -m "Merge branch 'main' into deps"; then
    git checkout --theirs VERSION
    git add VERSION
    if git diff --name-only --diff-filter=U | grep -q .; then
        echo "merge of main into deps conflicts outside VERSION" >&2
        exit 1
    fi
    git commit -m "Merge branch 'main' into deps"
fi
git push origin HEAD:refs/heads/deps
