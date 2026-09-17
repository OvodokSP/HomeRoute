#!/usr/bin/env python3
"""Compare two sanitized HomeRoute inventory JSON snapshots."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load(path: str) -> dict[str, Any]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: inventory root must be an object")
    if data.get("inventory_schema") != "1":
        raise ValueError(f"{path}: inventory_schema must be 1")
    if data.get("inventory_type") not in {"router", "vps"}:
        raise ValueError(f"{path}: inventory_type must be router or vps")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two sanitized HomeRoute inventory JSON snapshots."
    )
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument(
        "--strict-type",
        action="store_true",
        help="fail when inventory_type differs instead of reporting it as a change",
    )
    args = parser.parse_args()

    try:
        before = load(args.before)
        after = load(args.after)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 2

    if args.strict_type and before.get("inventory_type") != after.get("inventory_type"):
        print("[FAIL] inventory_type differs", file=sys.stderr)
        return 2

    keys = sorted(set(before) | set(after))
    changed = 0
    for key in keys:
        left = before.get(key, "<MISSING>")
        right = after.get(key, "<MISSING>")
        if left != right:
            changed += 1
            print(f"[CHANGE] {key}: {left} -> {right}")

    if changed == 0:
        print("[PASS] no inventory differences")
    else:
        print(f"[INFO] changed_fields={changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
