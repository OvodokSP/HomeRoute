#!/usr/bin/env python3
"""Validate HomeRoute clean-reproduction and apply promotion gates."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "reproduction-gates.json"

ALLOWED = {
    "PASS",
    "NOT_RUN",
    "PENDING",
    "PENDING_LOCAL_ARTIFACTS",
    "DEFINED",
    "PARTIAL",
    "NOT_IMPLEMENTED",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("reproduction gates schema must be 1")

    if data.get("hl_404_live_backup_restore") != "PASS":
        fail("HL-404 must remain PASS after recorded live evidence")

    hl502 = data.get("hl_502_clean_reproduction")
    if hl502 not in {"NOT_RUN", "PASS"}:
        fail("HL-502 state must be NOT_RUN or PASS")

    stable = data.get("stable_apply_allowed")
    if hl502 != "PASS" and stable is not False:
        fail("stable apply must remain blocked before HL-502 PASS")
    if data.get("stable_apply_blocked_until") != "HL-502":
        fail("stable apply promotion boundary drifted")

    router = data.get("router")
    vps = data.get("vps")
    if not isinstance(router, dict) or not isinstance(vps, dict):
        fail("router/vps gate sections missing")

    for section_name, section in (("router", router), ("vps", vps)):
        for key, value in section.items():
            if value not in ALLOWED:
                fail(f"unknown {section_name} gate value: {key}={value}")

    for key in (
        "reference_runtime_health",
        "reference_semantics_capture",
        "hook_dependency_capture",
        "reference_contract",
        "hrneo_exact_artifact",
        "hrneo_live_reinstall",
        "hrneo_live_rollback",
        "mutable_conffile_model",
    ):
        if router.get(key) != "PASS":
            fail(f"verified router gate regressed: {key}")

    for key in (
        "reference_runtime_health",
        "live_filesystem_restore",
        "live_awg_restore",
        "live_adguard_restore",
        "exact_running_image_rescue",
    ):
        if vps.get(key) != "PASS":
            fail(f"verified VPS gate regressed: {key}")

    expected_router_pending = {
        "exact_hook_source_bundle": "PENDING",
        "telegram_ndm_dependency_targets": "PENDING",
        "exact_chur_artifact_identity": "PENDING",
        "reproduction_apply_engine": "NOT_IMPLEMENTED",
    }
    for key, expected in expected_router_pending.items():
        if router.get(key) != expected:
            fail(f"router blocker unexpectedly changed without evidence: {key}")

    if vps.get("reproduction_apply_engine") != "NOT_IMPLEMENTED":
        fail("VPS reproduction apply engine must remain NOT_IMPLEMENTED until implemented/tested")

    policy = data.get("promotion_policy", {})
    for key in (
        "reproduction_apply_requires_hl_404_pass",
        "stable_apply_requires_hl_502_pass",
        "unknown_required_fact_blocks_apply",
        "undocumented_manual_fix_invalidates_reproduction",
    ):
        if policy.get(key) is not True:
            fail(f"promotion safety policy drifted: {key}")

    print("[INFO] stable apply remains blocked pending HL-502")
    print("[PASS] reproduction gate matrix")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
