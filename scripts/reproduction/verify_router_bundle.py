#!/usr/bin/env python3
"""Verify a local HomeRoute router reproduction bundle against its manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MARKER = ".homeroute-reproduction-inputs"
MANIFEST = "manifest.json"


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"reproduction root missing: {root}")
    if not (root / MARKER).is_file():
        fail(f"reproduction marker missing: {MARKER}")

    manifest_path = root / MANIFEST
    if not manifest_path.is_file():
        fail(f"manifest missing: {MANIFEST}")

    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or data.get("scope") != "router":
        fail("router reproduction manifest schema/scope mismatch")
    if data.get("content_printed") is not False:
        fail("manifest content-print boundary drifted")

    files = data.get("files")
    if not isinstance(files, list) or not files:
        fail("manifest files list is empty")

    seen: set[str] = set()
    for entry in files:
        if not isinstance(entry, dict):
            fail("invalid manifest file entry")
        rel = entry.get("path")
        if not isinstance(rel, str) or not rel or rel.startswith("/") or ".." in Path(rel).parts:
            fail(f"unsafe manifest path: {rel!r}")
        if rel in seen:
            fail(f"duplicate manifest path: {rel}")
        seen.add(rel)

        path = root / rel
        if not path.is_file() or path.is_symlink():
            fail(f"bundle file missing/not regular: {rel}")
        actual_size = path.stat().st_size
        if actual_size != entry.get("bytes"):
            fail(f"bundle file size drift: {rel}")
        actual_sha = sha256(path)
        if actual_sha != entry.get("sha256"):
            fail(f"bundle file SHA-256 drift: {rel}")

    blockers = data.get("blockers")
    if not isinstance(blockers, list):
        fail("manifest blockers must be a list")
    ready = data.get("ready_for_reproduction_apply")
    if ready is not (len(blockers) == 0):
        fail("manifest ready flag is inconsistent with blockers")

    # Refuse unmanaged material in the bundle tree. This prevents a stale
    # manifest from silently ignoring newly dropped secret/package files.
    allowed = seen | {MARKER, MANIFEST}
    unexpected: list[str] = []
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        rel = path.relative_to(root).as_posix()
        if rel not in allowed:
            unexpected.append(rel)
    if unexpected:
        fail("unmanaged files in reproduction bundle: " + ", ".join(sorted(unexpected)))

    if args.require_ready and blockers:
        ids = [str(item.get("id", "unknown")) for item in blockers if isinstance(item, dict)]
        fail("reproduction bundle is blocked: " + ", ".join(ids))

    print(f"HOMEROUTE_REPRO_BUNDLE_VERIFY schema=1 scope=router files={len(files)}")
    print(f"HOMEROUTE_REPRO_BUNDLE_VERIFY blockers={len(blockers)}")
    print(f"HOMEROUTE_REPRO_BUNDLE_VERIFY ready_for_reproduction_apply={'true' if not blockers else 'false'}")
    print("HOMEROUTE_REPRO_BUNDLE_VERIFY content_printed=false")
    print("[PASS] local router reproduction bundle integrity verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
