#!/usr/bin/env python3
"""Print the current HomeRoute clean-reproduction readiness matrix."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GATES = ROOT / "config" / "reproduction-gates.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    data = json.loads(GATES.read_text(encoding="utf-8"))

    router = data["router"]
    vps = data["vps"]

    router_blockers = [
        key for key, value in router.items()
        if value not in {"PASS", "DEFINED"}
    ]
    vps_blockers = [
        key for key, value in vps.items()
        if value not in {"PASS", "DEFINED"}
    ]

    summary = {
        "schema": 1,
        "hl_404": data["hl_404_live_backup_restore"],
        "hl_502": data["hl_502_clean_reproduction"],
        "stable_apply_allowed": data["stable_apply_allowed"],
        "router_blockers": router_blockers,
        "vps_blockers": vps_blockers,
        "router_blocker_count": len(router_blockers),
        "vps_blocker_count": len(vps_blockers),
    }

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0

    print("HOMEROUTE_REPRO_STATUS schema=1")
    print(f"HOMEROUTE_REPRO_STATUS hl_404={summary['hl_404']}")
    print(f"HOMEROUTE_REPRO_STATUS hl_502={summary['hl_502']}")
    print(
        "HOMEROUTE_REPRO_STATUS stable_apply_allowed="
        + ("true" if summary["stable_apply_allowed"] else "false")
    )
    print(f"HOMEROUTE_REPRO_STATUS router_blockers={len(router_blockers)}")
    for key in router_blockers:
        print(f"HOMEROUTE_REPRO_GATE scope=router id={key} state={router[key]}")
    print(f"HOMEROUTE_REPRO_STATUS vps_blockers={len(vps_blockers)}")
    for key in vps_blockers:
        print(f"HOMEROUTE_REPRO_GATE scope=vps id={key} state={vps[key]}")
    print("[PASS] reproduction readiness status rendered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
