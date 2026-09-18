#!/usr/bin/env python3
"""Render the router clean-reproduction plan from reviewed public contracts.

This tool never mutates a router. It consumes only public gate/reference
metadata plus an optional local bundle manifest and reports the exact remaining
blockers before reproduction-only apply may exist.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GATES_PATH = ROOT / "config" / "reproduction-gates.json"
CONTRACT_PATH = ROOT / "config" / "router-reference-contract.json"

ORDERED_STEPS = [
    ("preflight_platform", "Verify KeeneticOS/Entware architecture and clean-device assumptions"),
    ("verify_local_bundle", "Verify local hook/AWG/HRNeo/package bundle integrity"),
    ("snapshot_preexisting_state", "Capture transaction rollback state before first mutation"),
    ("provision_package_sources", "Provision exact local package artifacts or reviewed pinned sources"),
    ("install_awg_runtime", "Install exact AmneziaWG runtime packages"),
    ("install_hrneo", "Install exact pinned HRNeo 3.18.3-1 artifact"),
    ("stage_awg_config", "Install local opkgtun0 configuration without printing secrets"),
    ("stage_hrneo_mutable_state", "Install hrneo.conf/domain.conf/ip.list from local bundle"),
    ("stage_persistence_hooks", "Install exact/reviewed persistence hooks"),
    ("activate_services", "Activate AWG/HRNeo through reviewed service lifecycle"),
    ("verify_runtime", "Verify interface, mark/table, ipset, FORWARD and MASQUERADE invariants"),
    ("doctor_pre_reboot", "Require router doctor PASS before reboot"),
    ("reboot_persistence", "Perform controlled reboot persistence validation"),
    ("doctor_post_reboot", "Require router doctor PASS after reboot"),
    ("functional_validation", "Verify end-to-end user scenario"),
    ("idempotency", "Re-run reproduction plan/apply and require NO CHANGE where desired state matches"),
    ("record_evidence", "Write sanitized HL-502 reproduction evidence"),
]


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def blocker(blocker_id: str, source: str, reason: str) -> dict[str, str]:
    return {"id": blocker_id, "source": source, "reason": reason}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-manifest", help="optional local router manifest.json")
    parser.add_argument("--json", action="store_true", help="emit JSON instead of line protocol")
    args = parser.parse_args()

    gates = load_json(GATES_PATH)
    contract = load_json(CONTRACT_PATH)

    if gates.get("schema") != 1 or contract.get("schema") != 1:
        fail("unsupported public contract schema")

    blockers: list[dict[str, str]] = []

    if gates.get("hl_404_live_backup_restore") != "PASS":
        blockers.append(blocker("hl_404_not_pass", "gates", "live backup/restore gate is not PASS"))

    router_gates = gates.get("router", {})
    gate_reasons = {
        "exact_hook_source_bundle": "exact reference/reviewed hook source bundle is not yet recorded",
        "telegram_ndm_dependency_targets": "014 NDM hook /opt dependency targets remain unresolved",
        "exact_chur_artifact_identity": "exact Chur/AWG package artifacts are not content-pinned",
        "reproduction_apply_engine": "reproduction-only live apply engine is not implemented/tested",
    }
    for key, reason in gate_reasons.items():
        if router_gates.get(key) not in {"PASS", "DEFINED"}:
            blockers.append(blocker(key, "gates", reason))

    for item in contract.get("unresolved", []):
        if not isinstance(item, dict):
            continue
        item_id = str(item.get("id", "unknown_contract_blocker"))
        if not any(existing["id"] == item_id for existing in blockers):
            blockers.append(
                blocker(item_id, "router_reference_contract", str(item.get("reason", "unresolved")))
            )

    bundle_summary = {
        "supplied": False,
        "files": 0,
        "blockers": [],
        "ready_for_reproduction_apply": False,
    }

    if args.bundle_manifest:
        path = Path(args.bundle_manifest).expanduser().resolve()
        if not path.is_file():
            fail(f"bundle manifest not found: {path}")
        bundle = load_json(path)
        if bundle.get("schema") != 1 or bundle.get("scope") != "router":
            fail("invalid router bundle manifest schema/scope")
        bundle_blockers = bundle.get("blockers")
        if not isinstance(bundle_blockers, list):
            fail("bundle blockers must be a list")
        files = bundle.get("files")
        if not isinstance(files, list):
            fail("bundle files must be a list")

        bundle_summary = {
            "supplied": True,
            "files": len(files),
            "blockers": [
                str(entry.get("id", "unknown"))
                for entry in bundle_blockers
                if isinstance(entry, dict)
            ],
            "ready_for_reproduction_apply": bundle.get("ready_for_reproduction_apply") is True,
        }

        for entry in bundle_blockers:
            if isinstance(entry, dict):
                blockers.append(
                    blocker(
                        str(entry.get("id", "unknown_bundle_blocker")),
                        "local_bundle",
                        str(entry.get("reason", "local bundle blocker")),
                    )
                )

        # An exact verified local hook bundle can satisfy the source-bundle
        # presence gate, but cannot resolve unknown semantics by itself.
        hook_paths = {
            str(entry.get("path"))
            for entry in files
            if isinstance(entry, dict) and entry.get("kind") == "hook"
        }
        expected_hook_paths = {
            "hooks" + str(item["path"])
            for item in contract.get("hooks", [])
            if isinstance(item, dict)
        }
        if hook_paths == expected_hook_paths:
            blockers = [b for b in blockers if b["id"] != "exact_hook_source_bundle"]
            blockers = [b for b in blockers if b["id"] != "router_hook_exact_source_bundle"]

    dedup: dict[tuple[str, str], dict[str, str]] = {}
    for item in blockers:
        dedup[(item["id"], item["source"])] = item
    blockers = sorted(dedup.values(), key=lambda x: (x["source"], x["id"]))

    plan = {
        "schema": 1,
        "scope": "router",
        "mode": "plan_only",
        "reference_architecture": contract["platform"]["entware_architecture"],
        "steps": [
            {"order": idx + 1, "id": step_id, "description": description}
            for idx, (step_id, description) in enumerate(ORDERED_STEPS)
        ],
        "bundle": bundle_summary,
        "blockers": blockers,
        "reproduction_apply_ready": len(blockers) == 0,
        "stable_apply_allowed": gates.get("stable_apply_allowed") is True,
        "mutates_system": False,
    }

    if args.json:
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0

    print("HOMEROUTE_REPRO_PLAN schema=1 scope=router mode=plan_only")
    print(f"HOMEROUTE_REPRO_PLAN architecture={plan['reference_architecture']}")
    print(f"HOMEROUTE_REPRO_PLAN steps={len(plan['steps'])}")
    print(f"HOMEROUTE_REPRO_PLAN bundle_supplied={'true' if bundle_summary['supplied'] else 'false'}")
    print(f"HOMEROUTE_REPRO_PLAN blockers={len(blockers)}")
    for item in blockers:
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
    print("[PASS] router clean-reproduction plan rendered; no live state changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
