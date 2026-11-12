#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
# A merge of dev into main raises Y and sets Z to 0. The caller builds, then
# pushes. Other pushes to main, including this script's own version commit, do nothing.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

set -- $(git rev-list --parents -n 1 HEAD)
if [ "$#" -lt 3 ]; then
    echo "not a merge"
    exit 0
fi
git fetch origin dev
if ! git merge-base --is-ancestor "$3" origin/dev; then
    echo "merge is not from dev"
    exit 0
fi

file_ver="$(tr -d '[:space:]' < VERSION)"
printf '%s\n' "$file_ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || {
    echo "VERSION is not X.Y.Z" >&2
    exit 1
}
new="$(printf '%s\n' "$file_ver" | awk -F. '{ printf "%d.%d.0\n", $1, $2 + 1 }')"
if git rev-parse -q --verify "refs/tags/v${new}" >/dev/null; then
    echo "tag v${new} already exists"
    exit 0
fi

latest="$(git tag -l 'v*.*.*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
if [ -n "$latest" ]; then
    git log "${latest}..HEAD" --format='%s'
else
    git log --format='%s'
fi | python3 packaging/release/notes.py commits > notes.md

export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-github-actions[bot]}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
printf '%s\n' "$new" > VERSION
git add VERSION
git commit -m "Version ${new}." >&2
git -c core.commentChar=% tag -a "v${new}" -F notes.md >&2
printf '%s\n' "$new"
