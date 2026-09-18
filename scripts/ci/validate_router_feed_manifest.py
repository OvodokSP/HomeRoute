#!/usr/bin/env python3
"""Validate the HomeRoute router feed manifest safety contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "router-feed-manifest.json"

EXPECTED_CHUR = {
    "aarch64-3.10": "src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/aarch64-3.10",
    "mips-3.4": "src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mips-3.4",
    "mipsel-3.4": "src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mipsel-3.4",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))

    if data.get("schema") != 1:
        fail("router feed manifest schema must be 1")

    policy = data.get("policy", {})
    if policy.get("remote_pipe_to_shell_allowed_for_live_apply") is not False:
        fail("remote pipe-to-shell must remain forbidden for live apply")
    if policy.get("unknown_feed_lines_block_live_apply") is not True:
        fail("unknown feed lines must block live apply")

    chur = data.get("chur_amneziawg", {})
    if chur.get("install_root") != "chur-amneziawg":
        fail("unexpected Chur/AWG install root")
    if chur.get("feeds") != EXPECTED_CHUR:
        fail("Chur feed map drifted from the reviewed architecture map")

    hrneo = data.get("hrneo", {})
    if hrneo.get("install_root") != "hrneo":
        fail("unexpected HRNeo install root")
    if hrneo.get("deterministic_feed_line") is not None:
        fail("HRNeo mutable feed line must not be promoted as deterministic")
    if hrneo.get("status") != "PINNED_RELEASE_ARTIFACTS":
        fail("HRNeo must use pinned release artifacts")
    if hrneo.get("install_strategy") != "PINNED_IPK_ARTIFACT":
        fail("HRNeo install strategy must remain pinned IPK")
    if hrneo.get("release_manifest") != "config/hrneo-release-manifest.json":
        fail("HRNeo release manifest path drifted")
    if hrneo.get("pinned_version") != "3.18.3-1":
        fail("HRNeo pinned version drifted")
    if hrneo.get("live_apply_allowed") is not False:
        fail("HRNeo live apply must remain blocked until live package transaction validation")

    print("[PASS] router feed manifest safety contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
