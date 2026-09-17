#!/usr/bin/env python3
"""Tests for reference inventory completeness assessment."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "inventory" / "reference_readiness.py"
SPEC = importlib.util.spec_from_file_location("reference_readiness", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def complete_router() -> dict[str, str]:
    return {
        "inventory_schema": "1",
        "inventory_type": "router",
        "router_model": "EXAMPLE_ROUTER",
        "keenetic_release": "EXAMPLE_RELEASE",
        "uname_machine": "mipsel",
        "ram_total": "262144_KiB",
        "opt_total": "1048576_KiB",
        "opt_free": "524288_KiB",
        "opkg_arch": "mipsel-3.4",
        "component_awg": "/opt/bin/awg",
        "component_awg_quick": "/opt/bin/awg-quick",
        "component_amneziawg_go": "/opt/bin/amneziawg-go",
        "component_hrneo": "/opt/bin/hrneo",
        "component_nfqws": "/opt/bin/nfqws",
        "component_tg_ws_proxy": "/opt/bin/tg-ws-proxy",
    }


def complete_vps() -> dict[str, str]:
    return {
        "inventory_schema": "1",
        "inventory_type": "vps",
        "os_id": "ubuntu",
        "os_version_id": "EXAMPLE",
        "kernel_release": "EXAMPLE_KERNEL",
        "uname_machine": "x86_64",
        "vcpu_count": "1",
        "ram_total": "2097152_KiB",
        "root_total": "31457280_KiB",
        "root_free": "15728640_KiB",
        "component_docker": "/usr/bin/docker",
        "docker_version": "EXAMPLE_DOCKER",
        "awg_container_status": "running",
        "adguard_container_status": "running",
        "awg_interface_present": "yes",
    }


class ReferenceReadinessTests(unittest.TestCase):
    def test_complete_reference_is_ready_for_analysis(self) -> None:
        lines, blocked = MODULE.assess(complete_router(), complete_vps())
        self.assertFalse(blocked)
        self.assertIn(
            "[PASS] Reference inventory has the required sanitized fields for requirements analysis.",
            lines,
        )
        self.assertTrue(any("thresholds remain NOT_VALIDATED" in line for line in lines))

    def test_missing_router_identity_blocks(self) -> None:
        router = complete_router()
        router["router_model"] = "NOT_VALIDATED"
        lines, blocked = MODULE.assess(router, complete_vps())
        self.assertTrue(blocked)
        self.assertIn("[BLOCKED] router.router_model=NOT_VALIDATED", lines)

    def test_optional_components_do_not_block(self) -> None:
        router = complete_router()
        router["component_nfqws"] = "NOT_VALIDATED"
        router["component_tg_ws_proxy"] = "NOT_VALIDATED"
        lines, blocked = MODULE.assess(router, complete_vps())
        self.assertFalse(blocked)
        self.assertTrue(any(line.startswith("[INFO] optional router.component_nfqws") for line in lines))

    def test_wrong_type_blocks(self) -> None:
        router = complete_router()
        router["inventory_type"] = "vps"
        lines, blocked = MODULE.assess(router, complete_vps())
        self.assertTrue(blocked)
        self.assertIn("[FAIL] router input is not inventory_type=router", lines)


if __name__ == "__main__":
    unittest.main()
