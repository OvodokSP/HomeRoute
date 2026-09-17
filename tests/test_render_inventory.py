#!/usr/bin/env python3
"""Dependency-free tests for inventory Markdown rendering."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "render_inventory.py"
SPEC = importlib.util.spec_from_file_location("render_inventory", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InventoryRenderTests(unittest.TestCase):
    def write_json(self, data: object) -> str:
        handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False)
        with handle:
            json.dump(data, handle)
        self.addCleanup(lambda: Path(handle.name).unlink(missing_ok=True))
        return handle.name

    def test_router_render_contains_known_fields(self) -> None:
        data = {
            "inventory_schema": "1",
            "inventory_type": "router",
            "router_model": "EXAMPLE_ROUTER",
            "keenetic_release": "EXAMPLE_RELEASE",
            "uname_machine": "mipsel",
            "ram_total": "262144_KiB",
        }
        text = MODULE.render(data, "Reference router")
        self.assertIn("# Reference router", text)
        self.assertIn("`router_model`", text)
        self.assertIn("`EXAMPLE_ROUTER`", text)
        self.assertIn("`keenetic_release`", text)
        self.assertIn("`uname_machine`", text)
        self.assertIn("`mipsel`", text)
        self.assertNotIn("public_ip", text)

    def test_unknown_field_is_rejected_on_load(self) -> None:
        path = self.write_json(
            {
                "inventory_schema": "1",
                "inventory_type": "vps",
                "public_ip": "203.0.113.1",
            }
        )
        with self.assertRaisesRegex(ValueError, "unknown inventory key"):
            MODULE.load(path)

    def test_table_escape(self) -> None:
        text = MODULE.render(
            {
                "inventory_schema": "1",
                "inventory_type": "vps",
                "docker_version": "Docker|Example",
            }
        )
        self.assertIn("Docker\\|Example", text)


if __name__ == "__main__":
    unittest.main()
