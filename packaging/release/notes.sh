#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
# Release notes from commit subjects or a dependency diff.
# commits reads one subject per line. deps reads a unified diff.
# Empty notes exit 1. A bad argument exits 2.

set -eu

if [ "$#" -ne 1 ]; then
    exit 2
fi

case "$1" in
commits)
    awk '
        function classify(subject,    text, lower, verb, rest) {
            text = subject
            gsub(/^[ \t\r]+/, "", text)
            gsub(/[ \t\r]+$/, "", text)
            lower = tolower(text)
            if (lower ~ /^merge / || lower ~ /^version /) return 0
            if (text !~ /\.$/) text = text "."
            lower = tolower(text)
            if (match(lower, /^(add|implement|fix|resolve|prevent|remove|change|update|keep)[[:space:]]+/)) {
                verb = substr(lower, 1, RLENGTH)
                gsub(/[[:space:]]+$/, "", verb)
                rest = substr(text, RLENGTH + 1)
                rest = toupper(substr(rest, 1, 1)) substr(rest, 2)
                if (verb == "add" || verb == "implement") sec = "Added"
                else if (verb == "fix" || verb == "resolve" || verb == "prevent") sec = "Fixed"
                else if (verb == "remove") sec = "Removed"
                else sec = "Changed"
                item = rest
                return 1
            }
            sec = "Changed"
            item = text
            return 1
        }
        BEGIN {
            names[1] = "Added"
            names[2] = "Changed"
            names[3] = "Fixed"
            names[4] = "Removed"
        }
        {
            if (classify($0)) {
                n[sec]++
                items[sec, n[sec]] = item
            }
        }
        END {
            blank = 0
            any = 0
            for (i = 1; i <= 4; i++) {
                name = names[i]
                if (n[name] < 1) continue
                if (blank) print ""
                blank = 1
                any = 1
                print name
                for (j = 1; j <= n[name]; j++) print "- " items[name, j]
            }
            if (!any) exit 1
        }
    '
    ;;
deps)
    awk '
        function clear_sides() {
            nminus = 0
            nplus = 0
            delete minus
            delete plus
        }
        function add_pair(name, old, new,    key) {
            key = name SUBSEP old SUBSEP new
            if (seen[key]) return
            seen[key] = 1
            npairs++
            pairs[npairs] = "- `" name "` " old " -> " new
        }
        function first_alpine(side,    i, limit, line, tag, found) {
            found = ""
            limit = (side == "old" ? nminus : nplus)
            for (i = 1; i <= limit; i++) {
                line = (side == "old" ? minus[i] : plus[i])
                gsub(/^[ \t\r]+/, "", line)
                gsub(/[ \t\r]+$/, "", line)
                if (match(line, /^FROM alpine:[^[:space:]]+/)) {
                    tag = substr(line, 13, RLENGTH - 12)
                    if (found == "") found = tag
                }
            }
            return found
        }
        function alpine_pairs(    old, new) {
            old = first_alpine("old")
            new = first_alpine("new")
            if (old != "" && new != "" && old != new) add_pair("alpine", old, new)
        }
        function scan_actions(side,    i, limit, line, chunk, name, ver) {
            limit = (side == "old" ? nminus : nplus)
            for (i = 1; i <= limit; i++) {
                line = (side == "old" ? minus[i] : plus[i])
                if (match(line, /uses:[[:space:]]*[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[^[:space:]]+/)) {
                    chunk = substr(line, RSTART, RLENGTH)
                    sub(/^uses:[[:space:]]*/, "", chunk)
                    name = chunk
                    sub(/@[^[:space:]]*$/, "", name)
                    ver = chunk
                    sub(/^.*@/, "", ver)
                    if (side == "old") oldact[name] = ver
                    else newact[name] = ver
                }
            }
        }
        function action_pairs(    name) {
            delete oldact
            delete newact
            scan_actions("old")
            scan_actions("new")
            for (name in oldact)
                if ((name in newact) && oldact[name] != newact[name])
                    add_pair(name, oldact[name], newact[name])
        }
        function flush() {
            if (path == "Dockerfile") alpine_pairs()
            else if (path ~ /\.yml$/ || path ~ /\.yaml$/) action_pairs()
        }
        /^diff --git / {
            flush()
            path = $0
            if (match(path, / b\/.+$/)) path = substr(path, RSTART + 3, RLENGTH - 3)
            else path = ""
            clear_sides()
            next
        }
        /^---/ || /^\+\+\+/ || /^@@/ || /^index / || /^new file/ || /^deleted file/ { next }
        /^-/ { nminus++; minus[nminus] = substr($0, 2); next }
        /^\+/ { nplus++; plus[nplus] = substr($0, 2); next }
        END {
            flush()
            if (npairs < 1) exit 1
            print "Dependency updates."
            cmd = "sort"
            for (i = 1; i <= npairs; i++) print pairs[i] | cmd
            close(cmd)
        }
    '
    ;;
*)
    exit 2
    ;;
esac
