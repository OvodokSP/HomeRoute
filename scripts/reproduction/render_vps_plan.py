#!/usr/bin/env python3
"""Render the VPS clean-reproduction plan from reviewed public contracts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GATES_PATH = ROOT / "config" / "reproduction-gates.json"
RUNTIME_PATH = ROOT / "config" / "vps-runtime-manifest.json"
SHAPE_PATH = ROOT / "config" / "vps-container-shape.json"

ORDERED_STEPS = [
    ("preflight_platform", "Verify Ubuntu/Docker target prerequisites and clean-device assumptions"),
    ("verify_local_bundle", "Verify exact AWG/AdGuard state and image rescue bundle"),
    ("snapshot_target_state", "Capture any pre-existing managed target objects before mutation"),
    ("load_exact_images", "Load exact verified AWG2 and AdGuard Docker image archives"),
    ("create_network", "Create reviewed amnezia-dns-net bridge/network contract"),
    ("restore_awg_state", "Restore local AWG state without printing secrets"),
    ("restore_adguard_state", "Restore AdGuard conf/work into target-local persistent paths"),
    ("create_awg_container", "Create AWG2 with reviewed privilege/network/module/UDP shape"),
    ("create_adguard_container", "Create AdGuard with reviewed network/mount/restart shape"),
    ("install_dns_persistence", "Install reviewed DNS target-resolution and TCP/UDP 53 persistence"),
    ("verify_runtime", "Require VPS doctor and AWG/DNS runtime invariants"),
    ("reboot_persistence", "Perform controlled VPS reboot persistence validation"),
    ("verify_post_reboot", "Require VPS doctor and real DNS probes after reboot"),
    ("idempotency", "Re-run reproduction apply and require NO CHANGE for matching desired state"),
    ("record_evidence", "Write sanitized HL-502 VPS reproduction evidence"),
]


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def blocker(blocker_id: str, source: str, reason: str) -> dict[str, str]:
    return {"id": blocker_id, "source": source, "reason": reason}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-manifest")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    gates = load(GATES_PATH)
    runtime = load(RUNTIME_PATH)
    shape = load(SHAPE_PATH)

    if gates.get("schema") != 1 or runtime.get("schema") != 1 or shape.get("schema") != 1:
        fail("unsupported VPS reproduction contract schema")

    blockers: list[dict[str, str]] = []
    if gates.get("hl_404_live_backup_restore") != "PASS":
        blockers.append(blocker("hl_404_not_pass", "gates", "live backup/restore gate is not PASS"))

    vps = gates.get("vps", {})
    gate_reasons = {
        "exact_clean_install_image_bundle": "exact image/state artifacts must be supplied locally",
        "dns_helper_semantics": "DNS persistence target-resolution semantics are only partially resolved",
        "deterministic_container_renderer": "container creation renderer is only partially defined",
        "reproduction_apply_engine": "reproduction-only VPS apply engine is not implemented/tested",
    }
    ready_values = {
        "exact_clean_install_image_bundle": {"PASS"},
        "dns_helper_semantics": {"PASS"},
        "deterministic_container_renderer": {"PASS"},
        "reproduction_apply_engine": {"PASS"},
    }
    for key, reason in gate_reasons.items():
        if vps.get(key) not in ready_values[key]:
            blockers.append(blocker(key, "gates", reason))

    bundle_summary = {
        "supplied": False,
        "artifacts": 0,
        "bundle_integrity_ready": False,
    }

    if args.bundle_manifest:
        path = Path(args.bundle_manifest).expanduser().resolve()
        if not path.is_file():
            fail(f"VPS bundle manifest not found: {path}")
        bundle = load(path)
        if bundle.get("schema") != 1 or bundle.get("scope") != "vps":
            fail("invalid VPS bundle manifest schema/scope")
        if bundle.get("artifact_count") != 4 or bundle.get("bundle_integrity_ready") is not True:
            fail("VPS bundle manifest is not integrity-ready")

        artifacts = bundle.get("artifacts")
        if not isinstance(artifacts, dict) or set(artifacts) != {
            "awg_state", "adguard_state", "awg_image", "adguard_image"
        }:
            fail("VPS bundle artifact set drifted")

        bundle_summary = {
            "supplied": True,
            "artifacts": 4,
            "bundle_integrity_ready": True,
        }
        blockers = [b for b in blockers if b["id"] != "exact_clean_install_image_bundle"]

    plan = {
        "schema": 1,
        "scope": "vps",
        "mode": "plan_only",
        "reference_os": {
            "id": runtime["verified"]["os_id"],
            "version": runtime["verified"]["os_version_id"],
            "architecture": runtime["verified"]["architecture"],
        },
        "reference_images": {
            "awg": runtime["provisioning"]["awg_image_id"],
            "adguard": runtime["provisioning"]["adguard_image_id"],
        },
        "steps": [
            {"order": idx + 1, "id": step_id, "description": description}
            for idx, (step_id, description) in enumerate(ORDERED_STEPS)
        ],
        "bundle": bundle_summary,
        "blockers": sorted(blockers, key=lambda x: x["id"]),
        "reproduction_apply_ready": len(blockers) == 0,
        "stable_apply_allowed": gates.get("stable_apply_allowed") is True,
        "mutates_system": False,
    }

    if args.json:
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0

    print("HOMEROUTE_REPRO_PLAN schema=1 scope=vps mode=plan_only")
    print(
        "HOMEROUTE_REPRO_PLAN reference="
        f"{plan['reference_os']['id']}-{plan['reference_os']['version']}-{plan['reference_os']['architecture']}"
    )
    print(f"HOMEROUTE_REPRO_PLAN steps={len(plan['steps'])}")
    print(f"HOMEROUTE_REPRO_PLAN bundle_supplied={'true' if bundle_summary['supplied'] else 'false'}")
    print(f"HOMEROUTE_REPRO_PLAN blockers={len(blockers)}")
    for item in plan["blockers"]:
        print(
            "HOMEROUTE_REPRO_BLOCKER "
            f"id={item['id']} source={item['source']} reason={json.dumps(item['reason'])}"
        )
    print(
        "HOMEROUTE_REPRO_PLAN reproduction_apply_ready="
        + ("true" if plan["reproduction_apply_ready"] else "false")
    )
    print(
        "HOMEROUTE_REPRO_PLAN stable_apply_allowed="
        + ("true" if plan["stable_apply_allowed"] else "false")
    )
    print("HOMEROUTE_REPRO_PLAN mutates_system=false")
    print("[PASS] VPS clean-reproduction plan rendered; no live state changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
