#!/usr/bin/env python3
"""Extract HOMEROUTE_PACKAGE lines from router preflight output."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINE = re.compile(r"^HOMEROUTE_PACKAGE name=([^\s]+) version=(.+)$")


def read_lines(paths: list[str]) -> list[str]:
    if not paths:
        return sys.stdin.read().splitlines()
    lines: list[str] = []
    for raw in paths:
        lines.extend(Path(raw).read_text(encoding="utf-8").splitlines())
    return lines


def extract(lines: list[str]) -> list[dict[str, str]]:
    packages: dict[str, str] = {}
    for line in lines:
        match = LINE.match(line.strip())
        if not match:
            continue
        name, version = match.groups()
        if name in packages and packages[name] != version:
            raise ValueError(f"conflicting package version for {name}")
        packages[name] = version
    return [{"name": name, "version": packages[name]} for name in sorted(packages)]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract sanitized package/version pairs from HomeRoute router preflight output."
    )
    parser.add_argument("paths", nargs="*", help="preflight output file(s); stdin when omitted")
    parser.add_argument("--text", action="store_true", help="emit 'name - version' lines instead of JSON")
    args = parser.parse_args()

    try:
        packages = extract(read_lines(args.paths))
    except (OSError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    if args.text:
        for item in packages:
            print(f"{item['name']} - {item['version']}")
    else:
        print(json.dumps(packages, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
