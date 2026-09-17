#!/usr/bin/env python3
"""Dependency-free tests for package inventory comparison loading rules."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "compare_packages.py"
SPEC = importlib.util.spec_from_file_location("compare_packages", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PackageCompareTests(unittest.TestCase):
    def write_json(self, data: object) -> str:
        handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False)
        with handle:
            json.dump(data, handle)
        self.addCleanup(lambda: Path(handle.name).unlink(missing_ok=True))
        return handle.name

    def test_valid_list_loads(self) -> None:
        path = self.write_json([{"name": "busybox", "version": "1.0"}])
        self.assertEqual(MODULE.load(path), {"busybox": "1.0"})

    def test_root_must_be_array(self) -> None:
        path = self.write_json({})
        with self.assertRaisesRegex(ValueError, "root must be an array"):
            MODULE.load(path)

    def test_item_requires_name_and_version(self) -> None:
        path = self.write_json([{"name": "busybox"}])
        with self.assertRaisesRegex(ValueError, "name/version"):
            MODULE.load(path)

    def test_conflicting_duplicate_is_rejected(self) -> None:
        path = self.write_json(
            [
                {"name": "busybox", "version": "1.0"},
                {"name": "busybox", "version": "2.0"},
            ]
        )
        with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
            MODULE.load(path)


if __name__ == "__main__":
    unittest.main()
