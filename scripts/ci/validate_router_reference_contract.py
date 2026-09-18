#!/usr/bin/env python3
"""Validate the public non-secret reference-router reproduction contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "router-reference-contract.json"

EXPECTED_PACKAGES = {
    "chur-amneziawg": "1.0.0-1",
    "chur-amneziawg-go": "f4f4c99-1",
    "chur-amneziawg-tools": "1.0.20260223-2",
    "hrneo": "3.18.3-1",
}

EXPECTED_HOOKS = {
    "init_telegram_awg": {
        "path": "/opt/etc/init.d/S98telegram-awg",
        "sha256": "8165d5be13e57aa13eca8fb38a95bc179e37582f64732bd0e45a013727303504",
        "bytes": 1101,
        "lines": 61,
        "opt_path_refs": 4,
        "renderability": "requires_exact_source_or_reviewed_replacement",
    },
    "init_hrneo": {
        "path": "/opt/etc/init.d/S99hrneo",
        "sha256": "cd39a8804b991ae96995746e090a2b46e953930c7c8b89e27f11d4845abe3ceb",
        "bytes": 222,
        "lines": 11,
        "opt_path_refs": 3,
        "renderability": "requires_exact_source_or_reviewed_replacement",
    },
    "netfilter_telegram_awg": {
        "path": "/opt/etc/ndm/netfilter.d/014-telegram-awg.sh",
        "sha256": "c6766c421171d06a13ed8b30baa8d586a10a1373fce378f51bb94fdd46eff6f1",
        "bytes": 118,
        "lines": 6,
        "opt_path_refs": 2,
        "renderability": "blocked_unresolved_opt_dependencies",
    },
    "netfilter_hrneo": {
        "path": "/opt/etc/ndm/netfilter.d/015-hrneo.sh",
        "sha256": "fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342",
        "bytes": 169,
        "lines": 9,
        "opt_path_refs": 0,
        "renderability": "requires_exact_source_or_reviewed_replacement",
    },
    "ifstate_telegram_awg": {
        "path": "/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh",
        "sha256": "4eafa3bab0b1a1b439ed7eb4bd0ec85705a56d60730f9a46f0e30aa48930d9d2",
        "bytes": 161,
        "lines": 9,
        "opt_path_refs": 2,
        "renderability": "blocked_unresolved_opt_dependencies",
    },
    "ifstate_hrneo": {
        "path": "/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh",
        "sha256": "fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342",
        "bytes": 169,
        "lines": 9,
        "opt_path_refs": 0,
        "renderability": "requires_exact_source_or_reviewed_replacement",
    },
}

FORBIDDEN_KEY_FRAGMENTS = {
    "private_key",
    "preshared_key",
    "secret",
    "password",
    "token",
    "endpoint_value",
    "peer_public_key",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def walk_keys(value: object, prefix: str = "") -> list[str]:
    keys: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            full = f"{prefix}.{key}" if prefix else key
            keys.append(full)
            keys.extend(walk_keys(child, full))
    elif isinstance(value, list):
        for idx, child in enumerate(value):
            keys.extend(walk_keys(child, f"{prefix}[{idx}]"))
    return keys


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))

    if data.get("schema") != 1:
        fail("router reference contract schema must be 1")

    platform = data.get("platform", {})
    if platform != {
        "keenetic_os": "5.00.C.9.0-1",
        "entware_architecture": "mipsel-3.4",
    }:
        fail("reference router platform drifted")

    if data.get("packages") != EXPECTED_PACKAGES:
        fail("reference router package baseline drifted")

    awg = data.get("awg_runtime", {})
    expected_awg = {
        "interface": "opkgtun0",
        "ipv4_prefix": "/32",
        "mtu": 1324,
        "peer_count": 1,
        "handshake_required": True,
        "address_value_embedded": False,
        "peer_material_embedded": False,
        "endpoint_embedded": False,
        "keys_embedded": False,
    }
    if awg != expected_awg:
        fail("reference AWG runtime shape drifted")

    routing = data.get("routing", {})
    expected_routing = {
        "lan_interface": "br0",
        "routing_mark": "0x3001",
        "routing_table": 301,
        "ip_rule_301": True,
        "default_route_opkgtun0": True,
        "forward_br0_opkgtun0": True,
        "masquerade_opkgtun0": True,
        "ipset_opkgtun0": True,
    }
    if routing != expected_routing:
        fail("reference routing/firewall contract drifted")

    hrneo = data.get("hrneo_config", {})
    if hrneo.get("policy_order") != "opkgtun0":
        fail("HRNeo PolicyOrder drifted")
    if hrneo.get("mutable_conffiles") != ["hrneo.conf", "domain.conf", "ip.list"]:
        fail("mutable HRNeo conffile set drifted")
    if hrneo.get("reference_hashes_are_identity_pins") is not False:
        fail("mutable conffile reference hashes must not become identity pins")

    hooks = data.get("hooks")
    if not isinstance(hooks, list) or len(hooks) != len(EXPECTED_HOOKS):
        fail("hook contract count drifted")

    by_id = {item.get("id"): item for item in hooks if isinstance(item, dict)}
    if set(by_id) != set(EXPECTED_HOOKS):
        fail("hook contract IDs drifted")

    for hook_id, expected in EXPECTED_HOOKS.items():
        hook = by_id[hook_id]
        for key, value in expected.items():
            if hook.get(key) != value:
                fail(f"hook contract drift: {hook_id}.{key}")
        if hook.get("executable") is not True or hook.get("shell_syntax") != "valid":
            fail(f"hook executable/syntax contract drift: {hook_id}")

        semantics = hook.get("semantics")
        if not isinstance(semantics, dict):
            fail(f"hook semantics missing: {hook_id}")
        for key in ("direct_ip_rule", "direct_ip_route", "direct_iptables", "direct_ipset"):
            if semantics.get(key) is not False:
                fail(f"NDM/init semantic capture unexpectedly claims direct mutation: {hook_id}.{key}")

    if by_id["netfilter_hrneo"]["sha256"] != by_id["ifstate_hrneo"]["sha256"]:
        fail("HRNeo NDM hook identity relationship drifted")

    unresolved = data.get("unresolved")
    if not isinstance(unresolved, list) or len(unresolved) < 2:
        fail("unresolved renderer gates must remain explicit")

    unresolved_ids = {entry.get("id") for entry in unresolved if isinstance(entry, dict)}
    required_unresolved = {
        "router_hook_exact_source_bundle",
        "telegram_ndm_opt_dependency_targets",
    }
    if not required_unresolved.issubset(unresolved_ids):
        fail("required unresolved router renderer gates are missing")

    for entry in unresolved:
        if entry.get("blocking") != "reproduction_apply":
            fail("unresolved router reference facts must block reproduction_apply")

    security = data.get("security", {})
    for key in (
        "contains_secrets",
        "contains_private_keys",
        "contains_peer_keys",
        "contains_endpoints",
        "contains_ip_addresses",
    ):
        if security.get(key) is not False:
            fail(f"public router reference contract security boundary drift: {key}")

    lowered_keys = "\n".join(walk_keys(data)).lower()
    for fragment in FORBIDDEN_KEY_FRAGMENTS:
        if fragment in lowered_keys:
            fail(f"forbidden secret-bearing key fragment in public contract: {fragment}")

    raw = PATH.read_text(encoding="utf-8")
    if "10.8.1.11" in raw or "192.168.1." in raw:
        fail("public router reference contract must not embed deployment IP values")

    print("[INFO] unresolved router renderer gates remain explicit")
    print("[PASS] router reference reproduction contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
