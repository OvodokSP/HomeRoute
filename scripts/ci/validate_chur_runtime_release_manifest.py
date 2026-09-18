#!/usr/bin/env python3
"""Validate the pinned Chur AmneziaWG runtime release contract."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "config" / "chur-runtime-release-manifest.json"

EXPECTED = {
    "aarch64-3.10": {
        "feed_path": "chur-keenetic/1_0_0/aarch64-3.10",
        "packages_file": {"size_bytes": 2944, "git_blob_sha1": "12244f92d0283a42a097ad1df5611798b47ec001"},
        "artifacts": {
            "chur-amneziawg-go": {
                "filename": "chur-amneziawg-go_f4f4c99-1_aarch64-3.10.ipk",
                "size_bytes": 1330809,
                "sha256": "f722998eb4f9ea9b680e49924df5cddf981aa1cb01b8494de1fdf031765804ad",
                "git_blob_sha1": "803a91071b45299acc2cac7ebfa44d0f155605ad",
            },
            "chur-amneziawg-tools": {
                "filename": "chur-amneziawg-tools_1.0.20260223-2_aarch64-3.10.ipk",
                "size_bytes": 55913,
                "sha256": "48e1486fd025d1bd35e61a97eedbf7dafc067056f850f9a0d009916d9e4a2454",
                "git_blob_sha1": "371f9c4caf1883007c457900356a66d6d0b7b7f5",
            },
            "chur-amneziawg": {
                "filename": "chur-amneziawg_1.0.0-1_aarch64-3.10.ipk",
                "size_bytes": 841,
                "sha256": "2f7ab5e17f0ce51bb2e51078c9a73a81c6115be1da108ade27c37ed6179546d9",
                "git_blob_sha1": "d702839dd195230277c732ca51dab81a965deaf2",
            },
        },
    },
    "mips-3.4": {
        "feed_path": "chur-keenetic/1_0_0/mips-3.4",
        "packages_file": {"size_bytes": 2912, "git_blob_sha1": "1e47427b41236fcf2bc86c9f3b054463b16a3061"},
        "artifacts": {
            "chur-amneziawg-go": {
                "filename": "chur-amneziawg-go_f4f4c99-1_mips-3.4.ipk",
                "size_bytes": 1369317,
                "sha256": "1ffefc4d740458abaa765f04962dbfe9728c3611ea7196209d6d788e02367cd6",
                "git_blob_sha1": "d9a2392c73f3484f111dc1f1f44651b3579abd46",
            },
            "chur-amneziawg-tools": {
                "filename": "chur-amneziawg-tools_1.0.20260223-2_mips-3.4.ipk",
                "size_bytes": 43657,
                "sha256": "e10330f00234da5e9054862e1a2ea0fabf6a697c1750f220aad7ae197f04f80a",
                "git_blob_sha1": "c40f44f4ce94e272ed2b05e0c76c63b08193d3a1",
            },
            "chur-amneziawg": {
                "filename": "chur-amneziawg_1.0.0-1_mips-3.4.ipk",
                "size_bytes": 840,
                "sha256": "32ecd04f828da12e3d44018a85df0837df62337fb03e19b3e92b7254db48e998",
                "git_blob_sha1": "4bfa8f1e96cf5962c6bf080fd5058bab35746deb",
            },
        },
    },
    "mipsel-3.4": {
        "feed_path": "chur-keenetic/1_0_0/mipsel-3.4",
        "packages_file": {"size_bytes": 2928, "git_blob_sha1": "84f4226c994473d76327424f495a448963f8dbc5"},
        "artifacts": {
            "chur-amneziawg-go": {
                "filename": "chur-amneziawg-go_f4f4c99-1_mipsel-3.4.ipk",
                "size_bytes": 1347467,
                "sha256": "29fa09b90b30fa9bddc65836dd3c1f3ab9883811d9b5c69aff7fa959148f6457",
                "git_blob_sha1": "ea409731c65366d0570d4cfb3461c79773a7a62d",
            },
            "chur-amneziawg-tools": {
                "filename": "chur-amneziawg-tools_1.0.20260223-2_mipsel-3.4.ipk",
                "size_bytes": 43738,
                "sha256": "6ab652ea6cf742ac67dbd5892750a24353b0d5fcfe4fb1b12724e35cd2cb1d7b",
                "git_blob_sha1": "be6837e3a6896fd333dd7ef95c064ede3239292e",
            },
            "chur-amneziawg": {
                "filename": "chur-amneziawg_1.0.0-1_mipsel-3.4.ipk",
                "size_bytes": 838,
                "sha256": "3836b376d686427b587c450d2e4e8103bf05315801c33320ee76498ecd3661a9",
                "git_blob_sha1": "138b0f48f84c915a5ef001e6c3cf0b9e32e971da",
            },
        },
    },
}

def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")

def main() -> int:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or data.get("component") != "chur-amneziawg-runtime":
        fail("unexpected Chur runtime manifest identity")
    if data.get("release_version") != "1.0.0":
        fail("Chur release version drifted")
    if data.get("source_commit") != "a445e93b305d439ae1d797a54cee67aff8e36ae2":
        fail("Chur source commit drifted")
    if data.get("pages_commit") != "b8493603eb08a631f4d93e4597f221830d2a8ba5":
        fail("Chur Pages release commit drifted")
    if data.get("versioned_feed_root") != "chur-keenetic/1_0_0":
        fail("Chur versioned feed root drifted")
    if data.get("architectures") != EXPECTED:
        fail("Chur runtime artifact map drifted")

    pins = data.get("upstream_pins", {})
    if pins.get("amneziawg_go", {}).get("commit") != "f4f4c999267437c3eb909e8d0e5278fb4596d9a7":
        fail("AmneziaWG Go upstream pin drifted")
    tools = pins.get("amneziawg_tools", {})
    if tools.get("commit") != "5d6179a6d0842e98dfb349c28cf1bd8e4b9d1079":
        fail("AmneziaWG tools upstream pin drifted")
    if tools.get("source_tar_sha256") != "e79a3c7f2def315d052a3648b49058a268c4b63cdb5e082b696d2a4a0a2367f0":
        fail("AmneziaWG tools source tar SHA256 drifted")

    policy = data.get("policy", {})
    required_true = (
        "versioned_feed_allowed_for_metadata",
        "pinned_raw_artifacts_preferred_for_live_install",
        "require_sha256_before_install",
        "require_git_blob_identity_before_install",
    )
    for key in required_true:
        if policy.get(key) is not True:
            fail(f"Chur safety policy must remain true: {key}")
    if policy.get("mutable_latest_feed_allowed") is not False:
        fail("mutable latest Chur feed must remain forbidden")
    if policy.get("install_web_manager_by_default") is not False:
        fail("Chur web manager must not become a core default")
    if policy.get("live_install_allowed") is not False:
        fail("Chur live install must remain blocked until package transaction validation")

    print("[PASS] pinned Chur AmneziaWG runtime release contract")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
