# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "packaging" / "release"))
import notes


class NotesTest(unittest.TestCase):
    def test_commit_subjects(self):
        text = notes.commit_notes([
            "Add an NFSv4.2 server image.",
            "Merge branch 'dev'",
            "Version 0.1.0.",
            "Fix the export parser.",
            "Remove UDP.",
            "Keep the host port.",
        ])
        self.assertIn("Added\n- An NFSv4.2 server image.", text)
        self.assertNotIn("Merge", text)
        self.assertNotIn("Version", text)
        self.assertIn("Fixed\n- The export parser.", text)
        self.assertIn("Removed\n- UDP.", text)
        self.assertIn("Changed\n- The host port.", text)
        self.assertNotIn("- Add ", text)
        self.assertNotIn("- Fix ", text)

    def test_dependency_diff(self):
        diff = """diff --git a/Dockerfile b/Dockerfile
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
+        uses: actions/checkout@v5
"""
        text = notes.deps_notes(diff)
        self.assertIn("`alpine` 3.24 -> 3.25", text)
        self.assertIn("`actions/checkout` v4 -> v5", text)


if __name__ == "__main__":
    unittest.main()
