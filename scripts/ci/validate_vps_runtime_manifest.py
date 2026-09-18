#!/usr/bin/env python3
"""Validate the HomeRoute VPS runtime manifest without inventing provisioning facts."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-runtime-manifest.json"

REQUIRED_VERIFIED = {
    "os_id": "ubuntu",
    "os_version_id": "26.04",
    "architecture": "x86_64",
    "docker_version": "29.1.3",
    "awg_container": "amnezia-awg2",
    "adguard_container": "adguard-home",
    "awg_interface": "awg0",
    "legacy_wg443_test_absent": True,
}

EXPECTED_PROVISIONING = {
    "awg_image_reference": "amnezia-awg2",
    "awg_image_id": "sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d",
    "awg_restart_policy": "always",
    "awg_network_mode": "bridge",
    "awg_network_attachment_count": 2,
    "awg_mount_count": 1,
    "awg_privileged": True,
    "adguard_image_reference": "adguard/adguardhome:latest",
    "adguard_image_id": "sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0",
    "adguard_restart_policy": "unless-stopped",
    "adguard_network_mode": "amnezia-dns-net",
    "adguard_network_attachment_count": 1,
    "adguard_mount_count": 2,
    "adguard_privileged": False,
}

PROVISIONING_KEYS = {
    "awg_image_reference",
    "awg_image_id",
    "awg_restart_policy",
    "awg_network_mode",
    "awg_network_attachment_count",
    "awg_mount_count",
    "awg_privileged",
    "adguard_image_reference",
    "adguard_image_id",
    "adguard_restart_policy",
    "adguard_network_mode",
    "adguard_network_attachment_count",
    "adguard_mount_count",
    "adguard_privileged",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("VPS runtime manifest schema must be 1")

    verified = data.get("verified", {})
    for key, expected in REQUIRED_VERIFIED.items():
        if verified.get(key) != expected:
            fail(f"verified VPS field drift: {key}")

    if verified.get("dns_redirect") != ["tcp/53", "udp/53"]:
        fail("verified DNS redirect contract drifted")

    provisioning = data.get("provisioning", {})
    if set(provisioning) != PROVISIONING_KEYS:
        fail("VPS provisioning field set drifted")
    if provisioning != EXPECTED_PROVISIONING:
        fail("captured VPS runtime shape drifted from reviewed evidence")

    policy = data.get("policy", {})
    for key in (
        "null_provisioning_fields_block_live_apply",
        "container_environment_values_must_not_be_collected",
        "mount_source_paths_must_not_be_collected",
        "container_ip_addresses_must_not_be_collected",
        "runtime_shape_observed_not_full_reproduction",
        "floating_image_tags_do_not_define_deterministic_install",
    ):
        if policy.get(key) is not True:
            fail(f"VPS safety policy must remain true: {key}")

    missing = sorted(k for k, value in provisioning.items() if value is None)
    if missing:
        print("[INFO] VPS live provisioning remains blocked; missing: " + ", ".join(missing))
    else:
        print("[INFO] VPS runtime manifest has no null provisioning fields; live enable still requires separate validation gates")

    print("[PASS] VPS runtime manifest safety contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
