#!/usr/bin/env python3
"""Validate sanitized VPS container-shape evidence."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-container-shape.json"

EXPECTED_AWG = {
    "container_name": "amnezia-awg2",
    "status": "running",
    "config_image_reference": "amnezia-awg2",
    "repo_tags": ["amnezia-awg2:latest"],
    "repo_digests": [
        "amnezia-awg2@sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d"
    ],
    "networks": ["amnezia-dns-net", "bridge"],
    "mounts": [{"type": "bind", "destination": "/lib/modules", "rw": True}],
    "port_bindings": [{"container_port": "35404/udp", "binding_count": 2}],
    "exposed_ports": ["35404/udp"],
    "auto_remove": False,
    "readonly_rootfs": False,
}

EXPECTED_ADGUARD = {
    "container_name": "adguard-home",
    "status": "running",
    "config_image_reference": "adguard/adguardhome:latest",
    "repo_tags": ["adguard/adguardhome:latest"],
    "repo_digests": [
        "adguard/adguardhome@sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0"
    ],
    "networks": ["amnezia-dns-net"],
    "mounts": [
        {"type": "bind", "destination": "/opt/adguardhome/conf", "rw": True},
        {"type": "bind", "destination": "/opt/adguardhome/work", "rw": True},
    ],
    "port_bindings": [
        {"container_port": "53/tcp", "binding_count": 0},
        {"container_port": "53/udp", "binding_count": 0},
        {"container_port": "67/udp", "binding_count": 0},
        {"container_port": "68/udp", "binding_count": 0},
        {"container_port": "80/tcp", "binding_count": 0},
        {"container_port": "443/tcp", "binding_count": 0},
        {"container_port": "443/udp", "binding_count": 0},
        {"container_port": "853/tcp", "binding_count": 0},
        {"container_port": "853/udp", "binding_count": 0},
        {"container_port": "3000/tcp", "binding_count": 0},
        {"container_port": "3000/udp", "binding_count": 0},
        {"container_port": "5443/tcp", "binding_count": 0},
        {"container_port": "5443/udp", "binding_count": 0},
        {"container_port": "6060/tcp", "binding_count": 0},
    ],
    "exposed_ports": [
        "53/tcp",
        "53/udp",
        "67/udp",
        "68/udp",
        "80/tcp",
        "443/tcp",
        "443/udp",
        "853/tcp",
        "853/udp",
        "3000/tcp",
        "3000/udp",
        "5443/tcp",
        "5443/udp",
        "6060/tcp",
    ],
    "auto_remove": False,
    "readonly_rootfs": False,
}

EXPECTED_EXCLUDED = [
    "environment_values",
    "container_ip_addresses",
    "host_port_numbers",
    "mount_source_paths",
    "labels",
    "command_lines",
    "config_contents",
    "credentials",
]


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("VPS container shape schema must be 1")
    if data.get("captured_at") != "2026-09-18":
        fail("unexpected container-shape capture date")
    if data.get("scope") != "sanitized_reference_container_shape":
        fail("unexpected container-shape scope")
    if data.get("awg") != EXPECTED_AWG:
        fail("AWG container shape drifted from reviewed evidence")
    if data.get("adguard") != EXPECTED_ADGUARD:
        fail("AdGuard container shape drifted from reviewed evidence")
    if data.get("deliberately_not_captured") != EXPECTED_EXCLUDED:
        fail("container-shape exclusion list drifted")

    policy = data.get("policy", {})
    for key in (
        "floating_tags_are_observed_not_install_pins",
        "repo_digests_are_observed_not_verified_pull_sources",
        "host_paths_are_local_parameters",
        "host_ports_are_local_parameters",
        "secrets_are_local_or_generated",
    ):
        if policy.get(key) is not True:
            fail(f"container-shape safety policy must remain true: {key}")

    print("[PASS] VPS container-shape evidence contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
