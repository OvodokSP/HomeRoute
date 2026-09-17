#!/usr/bin/env python3
"""Process router/VPS raw preflight logs into sanitized HomeRoute reference artifacts."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import extract_inventory
import extract_packages
import reference_readiness
import render_inventory


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def ensure_output_dir(path: Path, force: bool) -> None:
    if path.exists():
        if not path.is_dir():
            raise ValueError(f"output path is not a directory: {path}")
        if any(path.iterdir()) and not force:
            raise ValueError(f"output directory is not empty: {path}; use --force to overwrite generated files")
    else:
        path.mkdir(parents=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert HomeRoute router/VPS raw preflight logs into sanitized reference artifacts."
    )
    parser.add_argument("router_raw")
    parser.add_argument("vps_raw")
    parser.add_argument("--out-dir", default="reference-output")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    router_path = Path(args.router_raw)
    vps_path = Path(args.vps_raw)
    out_dir = Path(args.out_dir)

    try:
        router_lines = router_path.read_text(encoding="utf-8").splitlines()
        vps_lines = vps_path.read_text(encoding="utf-8").splitlines()
        router = extract_inventory.extract(router_lines)
        vps = extract_inventory.extract(vps_lines)
        if router.get("inventory_type") != "router":
            raise ValueError("router raw input did not produce inventory_type=router")
        if vps.get("inventory_type") != "vps":
            raise ValueError("VPS raw input did not produce inventory_type=vps")
        packages = extract_packages.extract(router_lines)
        ensure_output_dir(out_dir, args.force)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 2

    router_json = out_dir / "router-reference.json"
    vps_json = out_dir / "vps-reference.json"
    package_json = out_dir / "router-packages.json"
    router_md = out_dir / "router-reference.md"
    vps_md = out_dir / "vps-reference.md"
    readiness_txt = out_dir / "reference-readiness.txt"

    write_json(router_json, router)
    write_json(vps_json, vps)
    write_json(package_json, packages)
    router_md.write_text(render_inventory.render(router, "Reference router inventory"), encoding="utf-8")
    vps_md.write_text(render_inventory.render(vps, "Reference VPS inventory"), encoding="utf-8")

    readiness_lines, blocked = reference_readiness.assess(router, vps)
    readiness_txt.write_text("\n".join(readiness_lines) + "\n", encoding="utf-8")

    print(f"[PASS] sanitized router inventory: {router_json}")
    print(f"[PASS] sanitized VPS inventory: {vps_json}")
    print(f"[PASS] sanitized package inventory: {package_json}")
    print(f"[PASS] Markdown reports: {router_md}, {vps_md}")
    print(f"[INFO] readiness report: {readiness_txt}")
    if blocked:
        print("[BLOCKED] Processing succeeded, but required reference fields are still NOT_VALIDATED.")
        return 1
    print("[PASS] Required sanitized reference fields are present for requirements analysis.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
