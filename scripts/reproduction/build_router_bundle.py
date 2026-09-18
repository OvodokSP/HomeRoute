#!/usr/bin/env python3
"""Build a local-only HomeRoute router reproduction manifest.

The tool never prints file contents. It hashes an allow-listed input layout and
writes manifest metadata inside the user-supplied local reproduction root.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
from pathlib import Path

MARKER = ".homeroute-reproduction-inputs"

REQUIRED = {
    "hooks/opt/etc/init.d/S98telegram-awg": {"kind": "hook", "sensitive": False, "executable": True},
    "hooks/opt/etc/init.d/S99hrneo": {"kind": "hook", "sensitive": False, "executable": True},
    "hooks/opt/etc/ndm/netfilter.d/014-telegram-awg.sh": {"kind": "hook", "sensitive": False, "executable": True},
    "hooks/opt/etc/ndm/netfilter.d/015-hrneo.sh": {"kind": "hook", "sensitive": False, "executable": True},
    "hooks/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh": {"kind": "hook", "sensitive": False, "executable": True},
    "hooks/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh": {"kind": "hook", "sensitive": False, "executable": True},
    "awg/opkgtun0.conf": {"kind": "awg_config", "sensitive": True, "executable": False},
    "hrneo/hrneo.conf": {"kind": "hrneo_mutable", "sensitive": True, "executable": False},
    "hrneo/domain.conf": {"kind": "hrneo_mutable", "sensitive": True, "executable": False},
    "hrneo/ip.list": {"kind": "hrneo_mutable", "sensitive": True, "executable": False},
    "packages/hrneo_3.18.3-1_mipsel-3.4.ipk": {"kind": "package", "sensitive": False, "executable": False},
}

OPTIONAL = {
    "packages/chur-amneziawg.ipk": {
        "kind": "package", "sensitive": False, "executable": False, "artifact_pin": "NOT_DEFINED"
    },
    "packages/chur-amneziawg-go.ipk": {
        "kind": "package", "sensitive": False, "executable": False, "artifact_pin": "NOT_DEFINED"
    },
    "packages/chur-amneziawg-tools.ipk": {
        "kind": "package", "sensitive": False, "executable": False, "artifact_pin": "NOT_DEFINED"
    },
}

EXPECTED_HOOK_SHA256 = {
    "hooks/opt/etc/init.d/S98telegram-awg": "8165d5be13e57aa13eca8fb38a95bc179e37582f64732bd0e45a013727303504",
    "hooks/opt/etc/init.d/S99hrneo": "cd39a8804b991ae96995746e090a2b46e953930c7c8b89e27f11d4845abe3ceb",
    "hooks/opt/etc/ndm/netfilter.d/014-telegram-awg.sh": "c6766c421171d06a13ed8b30baa8d586a10a1373fce378f51bb94fdd46eff6f1",
    "hooks/opt/etc/ndm/netfilter.d/015-hrneo.sh": "fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342",
    "hooks/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh": "4eafa3bab0b1a1b439ed7eb4bd0ec85705a56d60730f9a46f0e30aa48930d9d2",
    "hooks/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh": "fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342",
}

EXPECTED_HRNEO_SHA256 = "811fe75ee6a566dc0404dfb5943f9a1f6d102459c3b9cbd4d340b5d4f1aeb450"


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    raise SystemExit(f"[FAIL] {message}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def file_entry(root: Path, rel: str, meta: dict[str, object]) -> dict[str, object]:
    path = root / rel
    if not path.exists():
        fail(f"required file missing: {rel}")
    if path.is_symlink():
        fail(f"symlink inputs are forbidden: {rel}")
    if not path.is_file():
        fail(f"input is not a regular file: {rel}")

    mode = stat.S_IMODE(path.stat().st_mode)
    if meta.get("executable") is True and not (mode & stat.S_IXUSR):
        fail(f"required executable bit missing: {rel}")

    digest = sha256(path)

    if rel in EXPECTED_HOOK_SHA256 and digest != EXPECTED_HOOK_SHA256[rel]:
        fail(f"reference hook identity mismatch: {rel}")

    if rel == "packages/hrneo_3.18.3-1_mipsel-3.4.ipk" and digest != EXPECTED_HRNEO_SHA256:
        fail("pinned HRNeo artifact SHA-256 mismatch")

    entry: dict[str, object] = {
        "path": rel,
        "kind": meta["kind"],
        "sensitive": bool(meta["sensitive"]),
        "bytes": path.stat().st_size,
        "sha256": digest,
        "mode": f"{mode:04o}",
    }
    if "artifact_pin" in meta:
        entry["artifact_pin"] = meta["artifact_pin"]
    return entry


def find_unexpected(root: Path) -> list[str]:
    allowed = set(REQUIRED) | set(OPTIONAL) | {MARKER, "manifest.json"}
    unexpected: list[str] = []
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        rel = path.relative_to(root).as_posix()
        if rel not in allowed:
            unexpected.append(rel)
    return sorted(unexpected)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, help="local ignored router reproduction root")
    parser.add_argument("--output", default="manifest.json", help="manifest filename inside --root")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"reproduction root does not exist: {root}")
    if not (root / MARKER).is_file():
        fail(f"reproduction marker missing: {MARKER}")

    output = Path(args.output)
    if output.is_absolute() or ".." in output.parts or len(output.parts) != 1:
        fail("--output must be a simple filename inside the reproduction root")

    unexpected = find_unexpected(root)
    if unexpected:
        fail("unexpected files in reproduction root: " + ", ".join(unexpected))

    entries: list[dict[str, object]] = []
    for rel, meta in REQUIRED.items():
        entries.append(file_entry(root, rel, meta))

    optional_present: list[str] = []
    for rel, meta in OPTIONAL.items():
        if (root / rel).exists():
            entries.append(file_entry(root, rel, meta))
            optional_present.append(rel)

    blockers: list[dict[str, str]] = []
    missing_chur = sorted(set(OPTIONAL) - set(optional_present))
    if missing_chur:
        blockers.append({
            "id": "exact_chur_artifacts_missing",
            "reason": "exact local Chur/AWG artifacts are not all present",
        })

    # Even when optional Chur files are supplied, their reviewed content hashes
    # are not pinned in the repository yet.
    if optional_present:
        blockers.append({
            "id": "exact_chur_artifact_identity_not_pinned",
            "reason": "Chur/AWG artifact content hashes have not been independently pinned/reviewed",
        })

    manifest = {
        "schema": 1,
        "scope": "router",
        "reference_architecture": "mipsel-3.4",
        "files": sorted(entries, key=lambda x: str(x["path"])),
        "blockers": blockers,
        "ready_for_reproduction_apply": len(blockers) == 0,
        "content_printed": False,
    }

    out = root / output
    tmp = root / f".{output.name}.tmp"
    tmp.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(out)

    print(f"HOMEROUTE_REPRO_BUNDLE schema=1 scope=router files={len(entries)}")
    print(f"HOMEROUTE_REPRO_BUNDLE blockers={len(blockers)}")
    print(f"HOMEROUTE_REPRO_BUNDLE ready_for_reproduction_apply={'true' if not blockers else 'false'}")
    print("HOMEROUTE_REPRO_BUNDLE content_printed=false")
    print("[PASS] local router reproduction manifest built")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
