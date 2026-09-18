#!/usr/bin/env python3
"""Validate the design-only VPS DNS persistence desired-state contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-dns-persistence.json"


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))

    if data.get("schema") != 1:
        fail("unexpected DNS persistence schema")
    if data.get("status") != "DESIGN_ONLY":
        fail("DNS persistence contract must remain design-only")

    evidence = data.get("reference_evidence", {})
    if evidence.get("capture_date") != "2026-09-18":
        fail("reference capture date drifted")
    if evidence.get("timer_schedule_verified") is not True:
        fail("timer schedule evidence must remain verified")
    if evidence.get("observed_helper_sha256") != "96766c14d26edb63877aaf8f2bff5de577e42683b99b86b1b2b7bc382424c2b0":
        fail("observed helper SHA drifted")
    if evidence.get("helper_full_semantics_verified") is not False:
        fail("helper full semantics must not be overstated")

    timer = data.get("timer", {})
    expected_timer = {
        "name": "awg-adguard-dns.timer",
        "service": "awg-adguard-dns.service",
        "schedule_kind": "monotonic",
        "on_boot_sec": 30,
        "on_unit_active_sec": 60,
        "persistent": True,
        "accuracy_sec": 10,
        "randomized_delay_sec": 0,
    }
    if timer != expected_timer:
        fail("timer desired-state contract drifted")

    helper = data.get("helper", {})
    target = helper.get("target_resolution", {})
    if target != {
        "method": "docker_inspect_runtime_ipv4",
        "network": "amnezia-dns-net",
        "adguard_container": "adguard-home",
        "awg_container": "amnezia-awg2",
        "publish_runtime_ip": False,
    }:
        fail("DNS target resolution contract drifted")

    rules = helper.get("rules", {})
    if rules != {
        "execution_scope": "inside_awg_container",
        "table": "nat",
        "chain": "PREROUTING",
        "protocols": ["tcp", "udp"],
        "destination_port": 53,
        "target": "resolved_adguard_ipv4:53",
        "check_before_insert": True,
        "insert_operation": "-I",
    }:
        fail("DNS rule desired-state contract drifted")

    if helper.get("forbidden_operations") != [
        "iptables -F",
        "docker restart",
        "docker rm",
        "reboot",
        "rm",
    ]:
        fail("DNS helper forbidden-operation list drifted")

    policy = data.get("policy", {})
    if policy.get("render_only") is not True:
        fail("DNS persistence renderer must remain render-only")
    if policy.get("live_apply_allowed") is not False:
        fail("DNS persistence live apply must remain blocked")
    if policy.get("no_embedded_secrets") is not True:
        fail("embedded secrets must remain forbidden")
    if policy.get("no_runtime_ip_in_logs") is not True:
        fail("runtime IP logging must remain forbidden")
    if policy.get("helper_source_identity_not_adopted_from_live_until_schema2_capture") is not True:
        fail("live helper source identity must remain pending schema-2 capture")

    print("[PASS] VPS DNS persistence desired-state contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
