#!/usr/bin/env python3
"""Re-verify a local VPS reproduction bundle and its saved manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from build_vps_bundle import ARTIFACTS, MARKER, build_manifest


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"VPS reproduction root missing: {root}")
    if not (root / MARKER).is_file():
        fail(f"reproduction marker missing: {MARKER}")

    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        fail("saved VPS reproduction manifest missing")

    saved = json.loads(manifest_path.read_text(encoding="utf-8"))
    if saved.get("schema") != 1 or saved.get("scope") != "vps":
        fail("saved VPS reproduction manifest schema/scope mismatch")

    allowed_top = set(ARTIFACTS.values()) | {MARKER, "manifest.json"}
    unexpected = sorted(
        path.name
        for path in root.iterdir()
        if path.name not in allowed_top
    )
    if unexpected:
        fail("unexpected top-level VPS bundle objects: " + ", ".join(unexpected))

    actual = build_manifest(root)
    if saved != actual:
        fail("VPS reproduction bundle drifted from saved manifest")

    print("HOMEROUTE_VPS_REPRO_BUNDLE_VERIFY schema=1 artifacts=4")
    print("HOMEROUTE_VPS_REPRO_BUNDLE_VERIFY bundle_integrity_ready=true")
    print("HOMEROUTE_VPS_REPRO_BUNDLE_VERIFY content_printed=false")
    print("[PASS] local VPS reproduction bundle integrity re-verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
