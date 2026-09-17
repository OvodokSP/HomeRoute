#!/usr/bin/env python3
"""Extract allowlisted HOMEROUTE_INVENTORY lines into sanitized JSON."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINE = re.compile(r"^HOMEROUTE_INVENTORY ([a-z0-9_]+)=(.*)$")

COMMON = {"inventory_schema", "inventory_type", "uname_machine", "ram_total"}
ROUTER = COMMON | {
    "opt_total",
    "opt_free",
    "opkg_arch",
    "component_awg",
    "component_awg_quick",
    "component_amneziawg_go",
    "component_hrneo",
    "component_nfqws",
    "component_tg_ws_proxy",
}
VPS = COMMON | {
    "os_id",
    "os_version_id",
    "kernel_release",
    "vcpu_count",
    "root_total",
    "root_free",
    "component_docker",
    "docker_version",
    "awg_container_status",
    "adguard_container_status",
    "awg_interface_present",
}
ALLOWLIST = {"router": ROUTER, "vps": VPS}


def read_lines(paths: list[str]) -> list[str]:
    if not paths:
        return sys.stdin.read().splitlines()
    lines: list[str] = []
    for raw in paths:
        lines.extend(Path(raw).read_text(encoding="utf-8").splitlines())
    return lines


def extract(lines: list[str]) -> dict[str, str]:
    observed: dict[str, str] = {}
    for line in lines:
        match = LINE.match(line.strip())
        if not match:
            continue
        key, value = match.groups()
        if key in observed and observed[key] != value:
            raise ValueError(f"conflicting duplicate inventory key: {key}")
        observed[key] = value

    inventory_type = observed.get("inventory_type")
    if inventory_type not in ALLOWLIST:
        raise ValueError("inventory_type must be router or vps")
    if observed.get("inventory_schema") != "1":
        raise ValueError("inventory_schema must be 1")

    allowed = ALLOWLIST[inventory_type]
    unknown = sorted(set(observed) - allowed)
    if unknown:
        raise ValueError("unknown inventory key(s): " + ", ".join(unknown))

    return {key: observed[key] for key in sorted(observed)}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract sanitized HomeRoute inventory fields from preflight output."
    )
    parser.add_argument("paths", nargs="*", help="preflight output file(s); stdin when omitted")
    parser.add_argument("--compact", action="store_true", help="emit compact JSON")
    args = parser.parse_args()

    try:
        data = extract(read_lines(args.paths))
    except (OSError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    if args.compact:
        print(json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    else:
        print(json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
