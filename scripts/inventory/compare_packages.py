#!/usr/bin/env python3
"""Compare two sanitized HomeRoute package inventory JSON files."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load(path: str) -> dict[str, str]:
    data: Any = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path}: package inventory root must be an array")

    packages: dict[str, str] = {}
    for index, item in enumerate(data):
        if not isinstance(item, dict):
            raise ValueError(f"{path}: item {index} must be an object")
        name = item.get("name")
        version = item.get("version")
        if not isinstance(name, str) or not name or not isinstance(version, str) or not version:
            raise ValueError(f"{path}: item {index} must contain non-empty name/version strings")
        if name in packages and packages[name] != version:
            raise ValueError(f"{path}: conflicting duplicate package {name}")
        packages[name] = version
    return packages


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two HomeRoute package inventory JSON files.")
    parser.add_argument("before")
    parser.add_argument("after")
    args = parser.parse_args()

    try:
        before = load(args.before)
        after = load(args.after)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 2

    added = sorted(set(after) - set(before))
    removed = sorted(set(before) - set(after))
    changed = sorted(name for name in set(before) & set(after) if before[name] != after[name])

    for name in added:
        print(f"[ADDED] {name} {after[name]}")
    for name in removed:
        print(f"[REMOVED] {name} {before[name]}")
    for name in changed:
        print(f"[VERSION] {name}: {before[name]} -> {after[name]}")

    total = len(added) + len(removed) + len(changed)
    if total == 0:
        print("[PASS] package inventories match")
    else:
        print(f"[INFO] package_changes={total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
