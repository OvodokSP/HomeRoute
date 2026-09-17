#!/usr/bin/env python3
"""End-to-end tests for the one-shot reference processor."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "inventory" / "process_reference.py"

ROUTER_RAW = """\
HOMEROUTE_INVENTORY inventory_schema=1
HOMEROUTE_INVENTORY inventory_type=router
HOMEROUTE_INVENTORY router_model=EXAMPLE_ROUTER
HOMEROUTE_INVENTORY keenetic_release=EXAMPLE_RELEASE
HOMEROUTE_INVENTORY uname_machine=mipsel
HOMEROUTE_INVENTORY ram_total=262144_KiB
HOMEROUTE_INVENTORY opt_total=1048576_KiB
HOMEROUTE_INVENTORY opt_free=524288_KiB
HOMEROUTE_INVENTORY opkg_arch=mipsel-3.4
HOMEROUTE_INVENTORY component_awg=/opt/bin/awg
HOMEROUTE_INVENTORY component_awg_quick=/opt/bin/awg-quick
HOMEROUTE_INVENTORY component_amneziawg_go=/opt/bin/amneziawg-go
HOMEROUTE_INVENTORY component_hrneo=/opt/bin/hrneo
HOMEROUTE_INVENTORY component_nfqws=/opt/bin/nfqws
HOMEROUTE_INVENTORY component_tg_ws_proxy=/opt/bin/tg-ws-proxy
HOMEROUTE_PACKAGE name=busybox version=1.37.0-1
"""

VPS_RAW = """\
HOMEROUTE_INVENTORY inventory_schema=1
HOMEROUTE_INVENTORY inventory_type=vps
HOMEROUTE_INVENTORY os_id=ubuntu
HOMEROUTE_INVENTORY os_version_id=EXAMPLE
HOMEROUTE_INVENTORY kernel_release=EXAMPLE_KERNEL
HOMEROUTE_INVENTORY uname_machine=x86_64
HOMEROUTE_INVENTORY vcpu_count=1
HOMEROUTE_INVENTORY ram_total=2097152_KiB
HOMEROUTE_INVENTORY root_total=31457280_KiB
HOMEROUTE_INVENTORY root_free=15728640_KiB
HOMEROUTE_INVENTORY component_docker=/usr/bin/docker
HOMEROUTE_INVENTORY docker_version=EXAMPLE_DOCKER
HOMEROUTE_INVENTORY awg_container_status=running
HOMEROUTE_INVENTORY adguard_container_status=running
HOMEROUTE_INVENTORY awg_interface_present=yes
"""


class ProcessReferenceTests(unittest.TestCase):
    def test_complete_logs_generate_expected_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            router = base / "router.txt"
            vps = base / "vps.txt"
            out = base / "out"
            router.write_text(ROUTER_RAW, encoding="utf-8")
            vps.write_text(VPS_RAW, encoding="utf-8")

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(router), str(vps), "--out-dir", str(out)],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            expected = {
                "router-reference.json",
                "vps-reference.json",
                "router-packages.json",
                "router-reference.md",
                "vps-reference.md",
                "reference-readiness.txt",
            }
            self.assertEqual({p.name for p in out.iterdir()}, expected)
            router_json = json.loads((out / "router-reference.json").read_text(encoding="utf-8"))
            self.assertEqual(router_json["router_model"], "EXAMPLE_ROUTER")
            packages = json.loads((out / "router-packages.json").read_text(encoding="utf-8"))
            self.assertEqual(packages, [{"name": "busybox", "version": "1.37.0-1"}])
            self.assertIn("[PASS] Reference inventory", (out / "reference-readiness.txt").read_text(encoding="utf-8"))

    def test_nonempty_output_requires_force(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            router = base / "router.txt"
            vps = base / "vps.txt"
            out = base / "out"
            out.mkdir()
            (out / "sentinel.txt").write_text("keep", encoding="utf-8")
            router.write_text(ROUTER_RAW, encoding="utf-8")
            vps.write_text(VPS_RAW, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(router), str(vps), "--out-dir", str(out)],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("output directory is not empty", result.stderr)
            self.assertEqual((out / "sentinel.txt").read_text(encoding="utf-8"), "keep")

    def test_unknown_inventory_key_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            router = base / "router.txt"
            vps = base / "vps.txt"
            router.write_text(ROUTER_RAW + "HOMEROUTE_INVENTORY public_ip=203.0.113.1\n", encoding="utf-8")
            vps.write_text(VPS_RAW, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(router), str(vps), "--out-dir", str(base / "out")],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("unknown inventory key", result.stderr)


if __name__ == "__main__":
    unittest.main()
