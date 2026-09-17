#!/usr/bin/env python3
"""Render a sanitized HomeRoute inventory JSON snapshot as Markdown."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ORDER = {
    "router": [
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
        "component_awg",
        "component_awg_quick",
        "component_amneziawg_go",
        "component_hrneo",
        "component_nfqws",
        "component_tg_ws_proxy",
    ],
    "vps": [
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
    ],
}


def load(path: str) -> dict[str, Any]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("inventory root must be an object")
    inventory_type = data.get("inventory_type")
    if inventory_type not in ORDER:
        raise ValueError("inventory_type must be router or vps")
    if data.get("inventory_schema") != "1":
        raise ValueError("inventory_schema must be 1")
    unknown = sorted(set(data) - set(ORDER[inventory_type]))
    if unknown:
        raise ValueError("unknown inventory key(s): " + ", ".join(unknown))
    return data


def escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def render(data: dict[str, Any], title: str | None = None) -> str:
    inventory_type = data["inventory_type"]
    heading = title or f"HomeRoute {inventory_type} inventory"
    lines = [
        f"# {heading}",
        "",
        "> Sanitized inventory. No credentials, public endpoints or VPN secrets are included.",
        "",
        "| Field | Value |",
        "|---|---|",
    ]
    for key in ORDER[inventory_type]:
        if key in data:
            lines.append(f"| `{key}` | `{escape(data[key])}` |")
    lines.extend(
        [
            "",
            "Evidence scope: this snapshot describes one observed system and does not by itself establish minimum hardware requirements or compatibility of other devices.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render sanitized HomeRoute inventory JSON as Markdown.")
    parser.add_argument("path")
    parser.add_argument("--title")
    parser.add_argument("--output", "-o")
    args = parser.parse_args()

    try:
        output = render(load(args.path), args.title)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
