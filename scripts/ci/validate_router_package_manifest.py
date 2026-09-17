#!/usr/bin/env python3
"""Validate the evidence-backed router package manifest against the reference snapshot."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "inventory/reference-2026-09-17/router-packages.json"
MANIFEST = ROOT / "config/router-package-manifest.json"
ALLOWED = {"CORE", "OPTIONAL", "RESERVE", "TRANSITIVE", "UNCLASSIFIED", "LEGACY"}
EXPECTED_CORE_ROOTS = ["chur-amneziawg", "hrneo"]


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read {path.relative_to(ROOT)}: {exc}")


def main() -> int:
    snapshot = load(SNAPSHOT)
    manifest = load(MANIFEST)

    if manifest.get("schema") != 1:
        fail("router package manifest schema must be 1")

    snapshot_names = [item.get("name") for item in snapshot]
    if any(not isinstance(name, str) or not name for name in snapshot_names):
        fail("reference snapshot contains an invalid package name")
    if len(snapshot_names) != len(set(snapshot_names)):
        fail("reference snapshot contains duplicate package names")

    packages = manifest.get("packages")
    if not isinstance(packages, list):
        fail("manifest packages must be a list")

    by_name: dict[str, dict] = {}
    for item in packages:
        if not isinstance(item, dict):
            fail("manifest package entry must be an object")
        name = item.get("name")
        category = item.get("category")
        if not isinstance(name, str) or not name:
            fail("manifest package has invalid name")
        if name in by_name:
            fail(f"duplicate manifest package: {name}")
        if category not in ALLOWED:
            fail(f"invalid category for {name}: {category}")
        if not isinstance(item.get("required_by", []), list):
            fail(f"required_by must be a list for {name}")
        if not isinstance(item.get("evidence", []), list):
            fail(f"evidence must be a list for {name}")
        if category in {"CORE", "OPTIONAL", "RESERVE", "TRANSITIVE"} and not item.get("evidence"):
            fail(f"classified package lacks evidence: {name}")
        by_name[name] = item

    if set(snapshot_names) != set(by_name):
        missing = sorted(set(snapshot_names) - set(by_name))
        extra = sorted(set(by_name) - set(snapshot_names))
        fail(f"manifest/snapshot package mismatch; missing={missing} extra={extra}")

    profiles = manifest.get("profiles")
    if not isinstance(profiles, dict) or "core" not in profiles:
        fail("manifest profiles.core is required")

    profile_names = set(profiles)
    all_targets = set(by_name) | profile_names

    core_roots = profiles["core"].get("roots")
    if core_roots != EXPECTED_CORE_ROOTS:
        fail(f"core roots must be exactly {EXPECTED_CORE_ROOTS}")
    if profiles["core"].get("default") is not True:
        fail("core profile must be enabled by default")

    for profile_name, profile in profiles.items():
        roots = profile.get("roots")
        if not isinstance(roots, list) or not roots:
            fail(f"profile {profile_name} must contain roots")
        if profile_name != "core" and profile.get("default") is not False:
            fail(f"non-core profile {profile_name} must default to false")
        for root in roots:
            if root not in by_name:
                fail(f"profile {profile_name} references unknown root {root}")
            category = by_name[root]["category"]
            expected = {"core": "CORE", "optional_nfqws": "OPTIONAL", "optional_nfqws_web": "OPTIONAL", "reserve_tg_ws_proxy": "RESERVE"}.get(profile_name)
            if expected and category != expected:
                fail(f"profile {profile_name} root {root} must be {expected}, found {category}")
            if by_name[root].get("role") != "install-root":
                fail(f"profile root {root} must have role=install-root")

    for name, item in by_name.items():
        for dep in item.get("depends_on", []):
            if dep not in by_name:
                fail(f"{name} depends on unknown package {dep}")
            if by_name[dep]["category"] in {"UNCLASSIFIED", "LEGACY"}:
                fail(f"proved dependency {name}->{dep} cannot be {by_name[dep]['category']}")
        for target in item.get("required_by", []):
            if target not in all_targets:
                fail(f"{name} required_by references unknown package/profile {target}")

    installable_roots = {root for profile in profiles.values() for root in profile["roots"]}
    if any(by_name[root]["category"] in {"UNCLASSIFIED", "LEGACY", "TRANSITIVE"} for root in installable_roots):
        fail("install profiles contain a non-root category")

    unclassified = sorted(name for name, item in by_name.items() if item["category"] == "UNCLASSIFIED")
    print(f"[PASS] router package manifest covers {len(by_name)} reference packages")
    print(f"[PASS] core install roots: {', '.join(core_roots)}")
    print(f"[INFO] intentionally unclassified reference packages: {len(unclassified)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
