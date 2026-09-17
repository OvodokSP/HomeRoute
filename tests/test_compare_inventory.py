#!/usr/bin/env python3
"""Dependency-free tests for inventory comparison loading rules."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "compare_inventory.py"
SPEC = importlib.util.spec_from_file_location("compare_inventory", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InventoryCompareTests(unittest.TestCase):
    def write_json(self, data: object) -> str:
        handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False)
        with handle:
            json.dump(data, handle)
        self.addCleanup(lambda: Path(handle.name).unlink(missing_ok=True))
        return handle.name

    def test_valid_inventory_loads(self) -> None:
        path = self.write_json({"inventory_schema": "1", "inventory_type": "router"})
        self.assertEqual(MODULE.load(path)["inventory_type"], "router")

    def test_non_object_is_rejected(self) -> None:
        path = self.write_json([])
        with self.assertRaisesRegex(ValueError, "root must be an object"):
            MODULE.load(path)

    def test_wrong_schema_is_rejected(self) -> None:
        path = self.write_json({"inventory_schema": "2", "inventory_type": "router"})
        with self.assertRaisesRegex(ValueError, "inventory_schema must be 1"):
            MODULE.load(path)

    def test_wrong_type_is_rejected(self) -> None:
        path = self.write_json({"inventory_schema": "1", "inventory_type": "unknown"})
        with self.assertRaisesRegex(ValueError, "inventory_type must be router or vps"):
            MODULE.load(path)


if __name__ == "__main__":
    unittest.main()
