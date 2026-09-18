#!/usr/bin/env python3
"""Validate pinned Amnezia Docker-network evidence and HomeRoute DNS policy."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "vps-network-upstream.json"

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        fail("network upstream schema must be 1")
    if data.get("source_repository") != "amnezia-vpn/amnezia-client":
        fail("unexpected upstream repository")
    if data.get("source_commit") != "de93650a90739b87bb47a632872ea9d0adc9412f":
        fail("upstream commit drifted")

    prepare = data.get("prepare_host", {})
    expected_prepare = {
        "path": "client/server_scripts/prepare_host.sh",
        "blob_sha": "1cc56a0115eb1c0a60ce1bdf790cf7c1c7204fa2",
        "network_name": "amnezia-dns-net",
        "driver": "bridge",
        "subnet": "172.29.172.0/24",
        "bridge_name": "amn0",
    }
    if prepare != expected_prepare:
        fail("prepare_host network contract drifted")

    upstream_dns = data.get("upstream_dns", {})
    expected_dns = {
        "path": "client/server_scripts/dns/run_container.sh",
        "blob_sha": "f8ff038097c559d72ea134e3f2d74256f93d2ed1",
        "network_name": "amnezia-dns-net",
        "fixed_ip": "172.29.172.254",
        "role": "upstream_amnezia_dns_not_homeroute_adguard",
    }
    if upstream_dns != expected_dns:
        fail("upstream DNS evidence drifted")

    policy = data.get("homeroute_policy", {})
    expected_policy = {
        "adguard_replaces_upstream_dns_role": True,
        "do_not_assume_upstream_dns_fixed_ip_for_adguard": True,
        "resolve_adguard_ip_from_docker_at_runtime": True,
        "dns_redirect_location": "inside_awg_container_nat_prerouting",
        "protocols": ["tcp", "udp"],
        "destination_port": 53,
    }
    if policy != expected_policy:
        fail("HomeRoute DNS integration policy drifted")

    print("[PASS] pinned Amnezia network / HomeRoute DNS policy contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
