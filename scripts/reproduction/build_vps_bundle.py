#!/usr/bin/env python3
"""Build a local-only VPS reproduction bundle manifest from verified rescue artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

MARKER = ".homeroute-reproduction-inputs"
ARTIFACTS = {
    "awg_state": "awg-state",
    "adguard_state": "adguard-state",
    "awg_image": "awg-image",
    "adguard_image": "adguard-image",
}
EXPECTED_IMAGE_IDS = {
    "awg_image": "sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d",
    "adguard_image": "sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_rel(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or value in {"", "."}:
        fail(f"unsafe artifact manifest path: {value}")
    return path


def parse_kv(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            fail(f"invalid metadata line in {path.name}")
        key, value = line.split("=", 1)
        data[key] = value
    return data


def verify_sha_manifest(root: Path, manifest_name: str) -> tuple[int, int, str]:
    manifest = root / manifest_name
    if not manifest.is_file():
        fail(f"checksum manifest missing: {root.name}/{manifest_name}")

    count = 0
    total = 0
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            fail(f"invalid checksum line: {root.name}/{manifest_name}")
        expected, rel_raw = parts
        rel = safe_rel(rel_raw.strip().lstrip("*"))
        path = root / rel
        if not path.is_file() or path.is_symlink():
            fail(f"checksum target missing/not regular: {root.name}/{rel.as_posix()}")
        actual = sha256(path)
        if actual != expected:
            fail(f"checksum mismatch: {root.name}/{rel.as_posix()}")
        count += 1
        total += path.stat().st_size

    if count == 0:
        fail(f"empty checksum manifest: {root.name}/{manifest_name}")
    return count, total, sha256(manifest)


def verify_state(kind: str, root: Path) -> dict[str, object]:
    metadata = root / "metadata.txt"
    if not metadata.is_file():
        fail(f"metadata missing: {root.name}")
    meta = parse_kv(metadata)
    if meta.get("schema") != "1":
        fail(f"unsupported state metadata schema: {root.name}")

    count, total, descriptor_sha = verify_sha_manifest(root, "MANIFEST.sha256")

    if kind == "awg_state":
        if meta.get("container") != "amnezia-awg2":
            fail("AWG state container identity drifted")
        if not (root / "awg/awg0.conf").is_file() or not (root / "start.sh").is_file():
            fail("AWG state artifact is incomplete")
    elif kind == "adguard_state":
        if meta.get("container") != "adguard-home":
            fail("AdGuard state container identity drifted")
        if not (root / "conf/AdGuardHome.yaml").is_file():
            fail("AdGuard state artifact is incomplete")
    else:
        fail(f"unknown state artifact: {kind}")

    return {
        "kind": kind,
        "directory": root.name,
        "verified_files": count,
        "verified_bytes": total,
        "descriptor_sha256": descriptor_sha,
        "metadata_sha256": sha256(metadata),
        "content_printed": False,
    }


def verify_image(kind: str, root: Path) -> dict[str, object]:
    metadata = root / "metadata.txt"
    archive = root / "image.tar"
    checksum = root / "IMAGE.sha256"
    for path in (metadata, archive, checksum):
        if not path.is_file() or path.is_symlink():
            fail(f"image rescue artifact missing/not regular: {root.name}/{path.name}")

    meta = parse_kv(metadata)
    if meta.get("schema") != "1":
        fail(f"unsupported image metadata schema: {root.name}")
    if meta.get("image_id") != EXPECTED_IMAGE_IDS[kind]:
        fail(f"exact image ID drifted: {kind}")

    count, total, descriptor_sha = verify_sha_manifest(root, "IMAGE.sha256")
    if count != 1:
        fail(f"image checksum manifest must contain exactly one file: {kind}")

    return {
        "kind": kind,
        "directory": root.name,
        "image_id": meta["image_id"],
        "archive_bytes": archive.stat().st_size,
        "archive_sha256": sha256(archive),
        "descriptor_sha256": descriptor_sha,
        "metadata_sha256": sha256(metadata),
        "content_printed": False,
    }


def build_manifest(root: Path) -> dict[str, object]:
    artifacts: dict[str, object] = {}
    for kind, dirname in ARTIFACTS.items():
        path = root / dirname
        if not path.is_dir():
            fail(f"required VPS artifact directory missing: {dirname}")
        if kind.endswith("_state"):
            artifacts[kind] = verify_state(kind, path)
        else:
            artifacts[kind] = verify_image(kind, path)

    return {
        "schema": 1,
        "scope": "vps",
        "artifacts": artifacts,
        "artifact_count": len(artifacts),
        "bundle_integrity_ready": True,
        "content_printed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output", default="manifest.json")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"VPS reproduction root missing: {root}")
    if not (root / MARKER).is_file():
        fail(f"reproduction marker missing: {MARKER}")

    output = Path(args.output)
    if output.is_absolute() or ".." in output.parts or len(output.parts) != 1:
        fail("--output must be a simple filename inside the reproduction root")

    allowed_top = set(ARTIFACTS.values()) | {MARKER, output.name}
    unexpected = sorted(
        path.name
        for path in root.iterdir()
        if path.name not in allowed_top
    )
    if unexpected:
        fail("unexpected top-level VPS bundle objects: " + ", ".join(unexpected))

    manifest = build_manifest(root)
    out = root / output
    tmp = root / f".{output.name}.tmp"
    tmp.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(out)

    print("HOMEROUTE_VPS_REPRO_BUNDLE schema=1 artifacts=4")
    print("HOMEROUTE_VPS_REPRO_BUNDLE bundle_integrity_ready=true")
    print("HOMEROUTE_VPS_REPRO_BUNDLE content_printed=false")
    print("[PASS] local VPS reproduction bundle verified and manifest built")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
