#!/usr/bin/env python3
"""Validate sanitized VPS rescue evidence."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "inventory" / "reference-2026-09-17" / "vps-rescue-live-2026-09-18.json"

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("rescue evidence schema must be 1")
    if data.get("captured_at") != "2026-09-18":
        fail("unexpected rescue evidence date")
    if data.get("scope") != "sanitized_vps_rescue_evidence":
        fail("unexpected rescue evidence scope")

    adg = data.get("adguard_state", {})
    expected_adg = {
        "result": "PASS",
        "file_count": 6,
        "size_kib": 35060,
        "integrity_verify": "PASS",
        "backup_id": "adguard-state-20260918T110820Z",
        "container_restart": False,
        "restore_performed": False,
    }
    if adg != expected_adg:
        fail("AdGuard live backup evidence drifted")

    images = data.get("exact_images", {})
    expected_images = {
        "awg2": {
            "result": "PASS",
            "image_id": "sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d",
            "archive_size_kib": 12204,
            "integrity_verify": "PASS",
            "backup_id": "image-awg2-20260918T110821Z",
            "image_loaded": False,
            "container_restart": False,
        },
        "adguard": {
            "result": "PASS",
            "image_id": "sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0",
            "archive_size_kib": 28828,
            "integrity_verify": "PASS",
            "backup_id": "image-adguard-20260918T110822Z",
            "image_loaded": False,
            "container_restart": False,
        },
    }
    if images != expected_images:
        fail("exact-image rescue evidence drifted")

    if data.get("disk_after") != {
        "filesystem_size_gib": 30,
        "used_gib": 16,
        "available_gib": 13,
        "use_percent": 54,
    }:
        fail("post-backup disk evidence drifted")

    if data.get("secret_material_committed") is not False:
        fail("secret material must not be committed")

    print("[PASS] sanitized VPS rescue evidence contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
