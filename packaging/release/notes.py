# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later
"""Release notes from commit subjects or a dependency diff."""

import re
import sys

SECTIONS = ("Added", "Changed", "Fixed", "Removed")


def deps_notes(diff):
    pairs = []
    path = None
    minus = []
    plus = []

    def flush():
        if path == "Dockerfile":
            pairs.extend(_alpine_pairs(minus, plus))
        elif path is not None and path.endswith((".yml", ".yaml")):
            pairs.extend(_action_pairs(minus, plus))

    for line in diff.splitlines():
        if line.startswith("diff --git "):
            flush()
            found = re.search(r" b/(.+)$", line)
            path = found.group(1) if found else None
            minus = []
            plus = []
            continue
        if line.startswith(("---", "+++", "@@", "index ", "new file", "deleted file")):
            continue
        if line.startswith("-"):
            minus.append(line[1:])
        elif line.startswith("+"):
            plus.append(line[1:])
    flush()
    if not pairs:
        return ""
    lines = ["Dependency updates."]
    for name, old, new in sorted(set(pairs)):
        lines.append("- `%s` %s -> %s" % (name, old, new))
    return "\n".join(lines) + "\n"


def commit_notes(subjects):
    buckets = {name: [] for name in SECTIONS}
    for subject in subjects:
        section, text = _classify(subject)
        if section is None:
            continue
        buckets[section].append(text)
    lines = []
    for name in SECTIONS:
        if not buckets[name]:
            continue
        if lines:
            lines.append("")
        lines.append(name)
        for text in buckets[name]:
            lines.append("- %s" % text)
    if not lines:
        return ""
    return "\n".join(lines) + "\n"


def _classify(subject):
    text = subject.strip()
    lowered = text.lower()
    if lowered.startswith("merge ") or lowered.startswith("version "):
        return None, None
    if not text.endswith("."):
        text += "."
    match = re.match(r"^(add|implement|fix|resolve|prevent|remove|change|update|keep)\s+(.+)$", text, re.I)
    if match:
        verb = match.group(1).lower()
        rest = match.group(2)
        rest = rest[0].upper() + rest[1:]
        if verb in ("add", "implement"):
            return "Added", rest
        if verb in ("fix", "resolve", "prevent"):
            return "Fixed", rest
        if verb == "remove":
            return "Removed", rest
        return "Changed", rest
    return "Changed", text


def _alpine_pairs(minus, plus):
    old = _alpine_tags(minus)
    new = _alpine_tags(plus)
    if old and new and old != new:
        return [("alpine", old[0], new[0])]
    return []


def _alpine_tags(lines):
    found = []
    for line in lines:
        match = re.match(r"^FROM alpine:(\S+)", line.strip())
        if match:
            found.append(match.group(1))
    return found


def _action_pairs(minus, plus):
    old = _actions(minus)
    new = _actions(plus)
    pairs = []
    for name in old:
        if name in new and old[name] != new[name]:
            pairs.append((name, old[name], new[name]))
    return pairs


def _actions(lines):
    found = {}
    pattern = re.compile(r"uses:\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@(\S+)")
    for line in lines:
        match = pattern.search(line)
        if match:
            found[match.group(1)] = match.group(2)
    return found


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("deps", "commits"):
        sys.exit(2)
    data = sys.stdin.read()
    if sys.argv[1] == "deps":
        text = deps_notes(data)
    else:
        text = commit_notes(data.splitlines())
    if not text:
        sys.exit(1)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
