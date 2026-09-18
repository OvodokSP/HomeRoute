#!/usr/bin/env python3
"""Validate the pinned HRNeo release artifact contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "hrneo-release-manifest.json"

EXPECTED_ARTIFACTS = {
    "aarch64-3.10": {
        "filename": "hrneo_3.18.3-1_aarch64-3.10.ipk",
        "repository_path": "keenetic/aarch64-k3.10/hrneo_3.18.3-1_aarch64-3.10.ipk",
        "size_bytes": 90689,
        "git_blob_sha1": "69e62156adf91868f58a85eaccc21916dc88f1c1",
        "sha256": "e903e8eb0fd9153d1f181b314d9591bdd5b5953ec8dc42bb9f38aff41c4aca21",
    },
    "mipsel-3.4": {
        "filename": "hrneo_3.18.3-1_mipsel-3.4.ipk",
        "repository_path": "keenetic/mipselsf-k3.4/hrneo_3.18.3-1_mipsel-3.4.ipk",
        "size_bytes": 111881,
        "git_blob_sha1": "eb4b7b17c7b987da88270935de74ce59f91c7b99",
        "sha256": "811fe75ee6a566dc0404dfb5943f9a1f6d102459c3b9cbd4d340b5d4f1aeb450",
    },
    "mips-3.4": {
        "filename": "hrneo_3.18.3-1_mips-3.4.ipk",
        "repository_path": "keenetic/mipssf-k3.4/hrneo_3.18.3-1_mips-3.4.ipk",
        "size_bytes": 112060,
        "git_blob_sha1": "3d09aa888c1375a0f2a5aa7872638c8202c44e3a",
        "sha256": "11c881e34d5455662c26ffb3841ba49f712c6e0d2a145a69e61f04fb22abbc62",
    },
}

EXPECTED_FEEDS = {
    "aarch64-3.10": "aarch64-k3.10",
    "mipsel-3.4": "mipselsf-k3.4",
    "mips-3.4": "mipssf-k3.4",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))

    if data.get("schema") != 1 or data.get("component") != "hrneo":
        fail("unexpected HRNeo release manifest identity")
    if data.get("version") != "3.18.3-1":
        fail("HRNeo pinned version drifted")
    if data.get("release_repository") != "Ground-Zerro/release":
        fail("unexpected HRNeo release repository")
    if data.get("release_commit") != "4811c8d13fa4bd6eaed5080fd49788f5aee20883":
        fail("HRNeo release commit drifted")
    if data.get("reviewed_source_commit") != "984ec135dbc3e9fb54e0c8c63a0e2fd829538772":
        fail("reviewed HRNeo source commit drifted")
    if data.get("reviewed_source_version") != "3.18.3-1":
        fail("reviewed HRNeo source version drifted")
    if data.get("package_dependencies") != ["libc", "ipset", "iptables", "ip-full"]:
        fail("HRNeo package dependency contract drifted")
    if data.get("upstream_feed_mapping") != EXPECTED_FEEDS:
        fail("HRNeo upstream architecture map drifted")
    if data.get("artifacts") != EXPECTED_ARTIFACTS:
        fail("HRNeo pinned artifact map drifted")

    integrity = data.get("integrity", {})
    if integrity.get("sha256") != "CAPTURED_AND_MATCHED_PINNED_GIT_OBJECTS_2026-09-18":
        fail("SHA256 capture evidence drifted")
    if integrity.get("gpg") != "NOT_VERIFIED":
        fail("GPG verification must not be claimed before evidence exists")
    if integrity.get("github_release_assets") != "NOT_PRESENT_AT_REVIEW_TIME":
        fail("GitHub release availability boundary drifted")
    if integrity.get("observation_date") != "2026-09-18":
        fail("integrity observation date drifted")
    if integrity.get("release_repository_commit_signature") != "UNSIGNED":
        fail("release repository commit signature evidence drifted")
    if integrity.get("github_releases_api") != "EMPTY_AT_OBSERVATION_TIME":
        fail("GitHub Releases API observation drifted")
    if integrity.get("signing_key_main") != "NOT_FOUND_AT_OBSERVATION_TIME":
        fail("signing key main-branch observation drifted")
    if integrity.get("signing_key_pinned_source_commit") != "NOT_FOUND":
        fail("signing key pinned-commit observation drifted")
    if integrity.get("signing_key_file") != "README_REFERENCES_KEY_BUT_FILE_NOT_AVAILABLE_AT_OBSERVATION_TIME":
        fail("signing key availability boundary drifted")

    provenance = data.get("provenance_boundary", {})
    if provenance.get("package_version_matches_reviewed_source_version") is not True:
        fail("package/source version match must remain recorded")
    if provenance.get("exact_binary_to_source_commit_provenance_proven") is not False:
        fail("binary-to-source provenance must not be overstated")

    policy = data.get("policy", {})
    if policy.get("pipe_remote_script_to_shell") is not False:
        fail("remote pipe-to-shell must remain forbidden")
    if policy.get("mutable_feed_required_for_hrneo_install") is not False:
        fail("pinned HRNeo strategy must not require mutable feed")
    if policy.get("direct_pinned_ipk_strategy") is not True:
        fail("pinned IPK strategy must remain enabled")
    if policy.get("live_install_allowed") is not False:
        fail("HRNeo live install must remain blocked")

    print("[PASS] pinned HRNeo release artifact contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
