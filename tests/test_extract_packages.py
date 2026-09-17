#!/usr/bin/env python3
"""Dependency-free tests for opkg package inventory extraction."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "extract_packages.py"
SPEC = importlib.util.spec_from_file_location("extract_packages", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PackageExtractTests(unittest.TestCase):
    def test_sorted_package_output(self) -> None:
        packages = MODULE.extract(
            [
                "noise",
                "HOMEROUTE_PACKAGE name=zlib version=1.3.1-1",
                "HOMEROUTE_PACKAGE name=busybox version=1.37.0-1",
            ]
        )
        self.assertEqual(
            packages,
            [
                {"name": "busybox", "version": "1.37.0-1"},
                {"name": "zlib", "version": "1.3.1-1"},
            ],
        )

    def test_identical_duplicate_is_allowed(self) -> None:
        packages = MODULE.extract(
            [
                "HOMEROUTE_PACKAGE name=example version=1.0",
                "HOMEROUTE_PACKAGE name=example version=1.0",
            ]
        )
        self.assertEqual(packages, [{"name": "example", "version": "1.0"}])

    def test_conflicting_duplicate_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "conflicting package version"):
            MODULE.extract(
                [
                    "HOMEROUTE_PACKAGE name=example version=1.0",
                    "HOMEROUTE_PACKAGE name=example version=2.0",
                ]
            )

    def test_unrelated_lines_are_ignored(self) -> None:
        self.assertEqual(MODULE.extract(["PrivateKey = REDACTED", "random text"]), [])


if __name__ == "__main__":
    unittest.main()
