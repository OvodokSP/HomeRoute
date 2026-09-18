#!/usr/bin/env python3
"""Validate public metadata for the local VPS rescue set."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-rescue-manifest.json"

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or data.get("reference_date") != "2026-09-18":
        fail("unexpected VPS rescue manifest identity")
    if data.get("scope") != "local_vps_rescue_set":
        fail("unexpected rescue manifest scope")

    artifacts = data.get("artifacts", {})
    required = {"awg_state", "adguard_state", "awg_image", "adguard_image"}
    if set(artifacts) != required:
        fail("rescue manifest artifact set drifted")

    for key in ("awg_state", "adguard_state"):
        item = artifacts[key]
        if item.get("live_backup") != "PASS" or item.get("integrity_verify") != "PASS":
            fail(f"state backup evidence not PASS: {key}")
        if item.get("live_restore") != "PASS":
            fail(f"live restore evidence not PASS: {key}")

    for key in ("awg_image", "adguard_image"):
        item = artifacts[key]
        if item.get("export") != "PASS" or item.get("integrity_verify") != "PASS":
            fail(f"image rescue evidence not PASS: {key}")
        if item.get("load") != "NOT_VALIDATED":
            fail(f"image load boundary drifted: {key}")

    policy = data.get("policy", {})
    for key in (
        "artifact_contents_are_local_only",
        "checksum_manifests_are_local_only",
        "public_repository_contains_metadata_only",
        "live_state_restore_validated",
        "image_load_still_requires_separate_validation",
    ):
        if policy.get(key) is not True:
            fail(f"rescue manifest safety policy must remain true: {key}")
    if policy.get("restore_requires_separate_validation") is not False:
        fail("state restore is already live-validated and must not regress to pending")

    print("[PASS] VPS rescue manifest contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
