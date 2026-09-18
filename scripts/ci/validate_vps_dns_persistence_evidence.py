#!/usr/bin/env python3
"""Validate sanitized live DNS persistence evidence."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "inventory" / "reference-2026-09-17" / "vps-dns-persistence-live-2026-09-18.json"

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("DNS persistence evidence schema must be 1")
    if data.get("captured_at") != "2026-09-18":
        fail("unexpected DNS persistence capture date")
    if data.get("scope") != "sanitized_live_dns_persistence":
        fail("unexpected DNS persistence scope")

    rescue = data.get("rescue_set", {})
    if rescue.get("result") != "PASS" or rescue.get("artifacts") != 4:
        fail("complete rescue-set verification must remain PASS")
    if rescue.get("image_load_performed") is not False or rescue.get("state_restore_performed") is not False:
        fail("rescue-set verification must remain non-mutating")

    target = data.get("dns_target", {})
    if target != {
        "result": "PASS",
        "network": "amnezia-dns-net",
        "adguard_ip_exposed": False,
        "resolution": "runtime_docker_inspect",
    }:
        fail("dynamic AdGuard target evidence drifted")

    persistence = data.get("persistence", {})
    expected = {
        "timer": "awg-adguard-dns.timer",
        "service": "awg-adguard-dns.service",
        "timer_active": "active",
        "timer_enabled": "enabled",
        "service_active": "inactive",
        "timer_calendar": "NOT_VALIDATED",
        "next_elapse_state": "NOT_SET",
        "exec_path": "/usr/local/sbin/awg-adguard-dns.sh",
        "exec_sha256": "96766c14d26edb63877aaf8f2bff5de577e42683b99b86b1b2b7bc382424c2b0",
        "helper_contents_committed": False,
    }
    if persistence != expected:
        fail("live DNS persistence evidence drifted")

    interpretation = data.get("interpretation", {})
    if interpretation != {
        "inactive_oneshot_between_timer_runs_is_not_failure": True,
        "schedule_kind_not_yet_identified": True,
        "helper_semantics_not_yet_captured": True,
    }:
        fail("DNS persistence evidence boundary drifted")

    print("[PASS] sanitized live DNS persistence evidence contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
