#!/usr/bin/env python3
"""Validate pinned Amnezia upstream evidence and its determinism boundary."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-awg-upstream.json"

EXPECTED_COMMIT = "de93650a90739b87bb47a632872ea9d0adc9412f"
EXPECTED_BLOBS = {
    "dockerfile": "2287a23ca0531af764277c121d257b058ddccbac",
    "run_container": "af2a1e17c616bb3b82e408f9160b61e385eb8c0e",
    "configure_container": "d551e00249e002e8cd57d05ce2d7ff264b0a5d53",
    "start": "7c60ed6078bf5c8bb20b7eb0a5b462dee2305927",
    "build_container": "b996237fcccd766e3953d5b6194424eed8fa2315",
}

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("AWG upstream schema must be 1")
    if data.get("source_repository") != "amnezia-vpn/amnezia-client":
        fail("unexpected AWG upstream repository")
    if data.get("source_commit") != EXPECTED_COMMIT:
        fail("AWG upstream commit drifted")

    files = data.get("files", {})
    for key, sha in EXPECTED_BLOBS.items():
        if files.get(key, {}).get("blob_sha") != sha:
            fail(f"AWG upstream blob drifted: {key}")

    shape = data.get("confirmed_upstream_shape", {})
    expected_shape = {
        "container_name_variable": "$CONTAINER_NAME",
        "restart_policy": "always",
        "privileged": True,
        "capabilities": ["NET_ADMIN", "SYS_MODULE"],
        "published_port_pattern": "$AWG_SERVER_PORT:$AWG_SERVER_PORT/udp",
        "module_mount": "/lib/modules:/lib/modules",
        "sysctl": "net.ipv4.conf.all.src_valid_mark=1",
        "dns_network": "amnezia-dns-net",
        "state_directory": "/opt/amnezia/awg",
        "startup_script": "/opt/amnezia/start.sh",
        "server_config": "/opt/amnezia/awg/awg0.conf",
    }
    if shape != expected_shape:
        fail("AWG upstream shape drifted")

    determinism = data.get("determinism", {})
    if determinism.get("source_scripts_pinned_to_commit") is not True:
        fail("upstream scripts must remain commit-pinned")
    if determinism.get("dockerfile_base_image") != "amneziavpn/amneziawg-go:latest":
        fail("reviewed upstream base image changed")
    for key in ("base_image_pinned", "exact_reference_image_provenance_verified", "clean_build_deterministic"):
        if determinism.get(key) is not False:
            fail(f"determinism boundary must remain false: {key}")

    policy = data.get("policy", {})
    for key in (
        "pinned_source_recipe_is_not_a_pinned_image",
        "floating_base_blocks_deterministic_clean_build",
        "reference_runtime_image_id_is_observed_evidence_only",
    ):
        if policy.get(key) is not True:
            fail(f"AWG upstream safety policy must remain true: {key}")

    print("[PASS] pinned Amnezia AWG upstream evidence contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
