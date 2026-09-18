#!/usr/bin/env python3
"""Validate sanitized live AWG backup evidence."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "inventory" / "reference-2026-09-17" / "vps-awg-live-backup-2026-09-18.json"

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    expected = {
        "schema": 1,
        "captured_at": "2026-09-18",
        "target": "awg",
        "container": "amnezia-awg2",
        "backup_id": "awg-state-20260918T103646Z",
        "backup_result": "PASS",
        "file_count": 5,
        "size_kib": 40,
        "integrity_verify": "PASS",
        "permissions": {
            "backup_directory": "0700",
            "state_directory": "0700",
            "metadata_file": "0600",
            "manifest_file": "0600",
            "owner": "root:root",
        },
        "live_effects": {
            "container_restart": False,
            "configuration_change": False,
            "restore_performed": False,
        },
        "secret_material_committed": False,
        "note": "Only sanitized verification metadata is stored; backup contents and checksums remain on the reference VPS.",
    }
    if data != expected:
        fail("live AWG backup evidence drifted")
    print("[PASS] sanitized live AWG backup evidence contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
