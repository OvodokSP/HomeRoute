#!/usr/bin/env python3
"""Dependency-free tests for the sanitized inventory normalizer."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "extract_inventory.py"
SPEC = importlib.util.spec_from_file_location("extract_inventory", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InventoryExtractTests(unittest.TestCase):
    def test_router_allowlist(self) -> None:
        data = MODULE.extract(
            [
                "noise",
                "HOMEROUTE_INVENTORY inventory_schema=1",
                "HOMEROUTE_INVENTORY inventory_type=router",
                "HOMEROUTE_INVENTORY uname_machine=mipsel",
                "HOMEROUTE_INVENTORY ram_total=262144_KiB",
                "HOMEROUTE_INVENTORY opt_total=1048576_KiB",
                "HOMEROUTE_INVENTORY opt_free=524288_KiB",
                "HOMEROUTE_INVENTORY opkg_arch=mipsel-3.4",
                "HOMEROUTE_INVENTORY component_awg=/opt/bin/awg",
            ]
        )
        self.assertEqual(data["inventory_type"], "router")
        self.assertEqual(data["component_awg"], "/opt/bin/awg")

    def test_vps_allowlist(self) -> None:
        data = MODULE.extract(
            [
                "HOMEROUTE_INVENTORY inventory_schema=1",
                "HOMEROUTE_INVENTORY inventory_type=vps",
                "HOMEROUTE_INVENTORY uname_machine=x86_64",
                "HOMEROUTE_INVENTORY ram_total=2097152_KiB",
                "HOMEROUTE_INVENTORY os_id=ubuntu",
                "HOMEROUTE_INVENTORY os_version_id=EXAMPLE",
                "HOMEROUTE_INVENTORY awg_container_status=running",
            ]
        )
        self.assertEqual(data["inventory_type"], "vps")
        self.assertEqual(data["awg_container_status"], "running")

    def test_unknown_key_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown inventory key"):
            MODULE.extract(
                [
                    "HOMEROUTE_INVENTORY inventory_schema=1",
                    "HOMEROUTE_INVENTORY inventory_type=router",
                    "HOMEROUTE_INVENTORY public_ip=203.0.113.1",
                ]
            )

    def test_conflicting_duplicate_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
            MODULE.extract(
                [
                    "HOMEROUTE_INVENTORY inventory_schema=1",
                    "HOMEROUTE_INVENTORY inventory_type=router",
                    "HOMEROUTE_INVENTORY ram_total=1_KiB",
                    "HOMEROUTE_INVENTORY ram_total=2_KiB",
                ]
            )

    def test_wrong_schema_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "inventory_schema must be 1"):
            MODULE.extract(
                [
                    "HOMEROUTE_INVENTORY inventory_schema=2",
                    "HOMEROUTE_INVENTORY inventory_type=router",
                ]
            )

    def test_missing_type_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "inventory_type must be router or vps"):
            MODULE.extract(["HOMEROUTE_INVENTORY inventory_schema=1"])


if __name__ == "__main__":
    unittest.main()
