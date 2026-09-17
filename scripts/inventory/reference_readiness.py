#!/usr/bin/env python3
"""Assess completeness of sanitized HomeRoute reference inventories without inventing thresholds."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROUTER_REQUIRED = (
    "inventory_schema",
    "inventory_type",
    "router_model",
    "keenetic_release",
    "uname_machine",
    "ram_total",
    "ram_available",
    "opt_total",
    "opt_free",
    "opkg_arch",
)
VPS_REQUIRED = (
    "inventory_schema",
    "inventory_type",
    "os_id",
    "os_version_id",
    "kernel_release",
    "uname_machine",
    "vcpu_count",
    "ram_total",
    "ram_available",
    "root_total",
    "root_free",
    "component_docker",
    "docker_version",
    "awg_container_status",
    "adguard_container_status",
    "awg_interface_present",
)
ROUTER_CORE_COMPONENTS = (
    "component_awg",
    "component_awg_quick",
    "component_amneziawg_go",
    "component_hrneo",
)
ROUTER_OPTIONAL_COMPONENTS = (
    "component_nfqws",
    "component_tg_ws_proxy",
)


def load(path: str) -> dict[str, Any]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: inventory root must be an object")
    if data.get("inventory_schema") != "1":
        raise ValueError(f"{path}: inventory_schema must be 1")
    if data.get("inventory_type") not in {"router", "vps"}:
        raise ValueError(f"{path}: inventory_type must be router or vps")
    return data


def unknown(value: Any) -> bool:
    return value is None or str(value).strip() in {"", "NOT_VALIDATED"}


def assess(router: dict[str, Any], vps: dict[str, Any]) -> tuple[list[str], bool]:
    lines: list[str] = []
    blocked = False

    if router.get("inventory_type") != "router":
        lines.append("[FAIL] router input is not inventory_type=router")
        blocked = True
    if vps.get("inventory_type") != "vps":
        lines.append("[FAIL] VPS input is not inventory_type=vps")
        blocked = True

    for key in ROUTER_REQUIRED:
        if unknown(router.get(key)):
            lines.append(f"[BLOCKED] router.{key}=NOT_VALIDATED")
            blocked = True
        else:
            lines.append(f"[PASS] router.{key} observed")

    for key in ROUTER_CORE_COMPONENTS:
        if unknown(router.get(key)):
            lines.append(f"[WARN] router.{key} not observed in PATH")
        else:
            lines.append(f"[PASS] router.{key} observed")

    for key in ROUTER_OPTIONAL_COMPONENTS:
        if unknown(router.get(key)):
            lines.append(f"[INFO] optional router.{key} not observed")
        else:
            lines.append(f"[PASS] optional router.{key} observed")

    for key in VPS_REQUIRED:
        if unknown(vps.get(key)):
            lines.append(f"[BLOCKED] vps.{key}=NOT_VALIDATED")
            blocked = True
        else:
            lines.append(f"[PASS] vps.{key} observed")

    if vps.get("awg_container_status") not in {"running", "NOT_VALIDATED", None}:
        lines.append(f"[WARN] AWG2 container state is {vps.get('awg_container_status')}")
    if vps.get("adguard_container_status") not in {"running", "NOT_VALIDATED", None}:
        lines.append(f"[WARN] AdGuard container state is {vps.get('adguard_container_status')}")
    if vps.get("awg_interface_present") not in {"yes", "true", "1", "present", "NOT_VALIDATED", None}:
        lines.append(f"[WARN] AWG interface presence reported as {vps.get('awg_interface_present')}")

    lines.append("[INFO] ram_available is an observed runtime headroom value, not a minimum/recommended threshold.")
    lines.append("[INFO] Hardware minimum/recommended thresholds remain NOT_VALIDATED until measured evidence is interpreted.")
    lines.append("[INFO] One reference inventory does not establish compatibility of other router or VPS models.")
    if blocked:
        lines.append("[BLOCKED] Reference inventory is incomplete for requirements analysis.")
    else:
        lines.append("[PASS] Reference inventory has the required sanitized fields for requirements analysis.")
    return lines, blocked


def main() -> int:
    parser = argparse.ArgumentParser(description="Assess completeness of sanitized HomeRoute reference inventories.")
    parser.add_argument("router_json")
    parser.add_argument("vps_json")
    parser.add_argument("--output", "-o")
    args = parser.parse_args()

    try:
        router = load(args.router_json)
        vps = load(args.vps_json)
        lines, blocked = assess(router, vps)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 2

    text = "\n".join(lines) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 1 if blocked else 0


if __name__ == "__main__":
    raise SystemExit(main())
