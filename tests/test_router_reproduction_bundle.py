from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


builder = load_module(
    "build_router_bundle",
    ROOT / "scripts" / "reproduction" / "build_router_bundle.py",
)
verifier = load_module(
    "verify_router_bundle",
    ROOT / "scripts" / "reproduction" / "verify_router_bundle.py",
)


class RouterReproductionBundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / builder.MARKER).write_text("test\n", encoding="utf-8")

        for rel, meta in builder.REQUIRED.items():
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(f"fixture:{rel}\n".encode())
            if meta.get("executable") is True:
                path.chmod(path.stat().st_mode | stat.S_IXUSR)

        self.hook_hashes = {
            rel: hashlib.sha256((self.root / rel).read_bytes()).hexdigest()
            for rel in builder.EXPECTED_HOOK_SHA256
        }
        self.hrneo_hash = hashlib.sha256(
            (self.root / "packages/hrneo_3.18.3-1_mipsel-3.4.ipk").read_bytes()
        ).hexdigest()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def build(self) -> str:
        stdout = io.StringIO()
        with (
            mock.patch.object(builder, "EXPECTED_HOOK_SHA256", self.hook_hashes),
            mock.patch.object(builder, "EXPECTED_HRNEO_SHA256", self.hrneo_hash),
            mock.patch.object(sys, "argv", ["build_router_bundle.py", "--root", str(self.root)]),
            contextlib.redirect_stdout(stdout),
        ):
            rc = builder.main()
        self.assertEqual(rc, 0)
        return stdout.getvalue()

    def verify(self, require_ready: bool = False) -> str:
        argv = ["verify_router_bundle.py", "--root", str(self.root)]
        if require_ready:
            argv.append("--require-ready")
        stdout = io.StringIO()
        with (
            mock.patch.object(sys, "argv", argv),
            contextlib.redirect_stdout(stdout),
        ):
            rc = verifier.main()
        self.assertEqual(rc, 0)
        return stdout.getvalue()

    def test_build_and_verify_blocked_bundle(self) -> None:
        out = self.build()
        self.assertIn("ready_for_reproduction_apply=false", out)

        data = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["scope"], "router")
        self.assertFalse(data["ready_for_reproduction_apply"])
        self.assertEqual(data["blockers"][0]["id"], "exact_chur_artifacts_missing")

        verify_out = self.verify()
        self.assertIn("HOMEROUTE_REPRO_BUNDLE_VERIFY blockers=1", verify_out)
        self.assertIn("[PASS] local router reproduction bundle integrity verified", verify_out)

    def test_require_ready_refuses_blocked_bundle(self) -> None:
        self.build()
        with self.assertRaises(SystemExit) as ctx:
            self.verify(require_ready=True)
        self.assertIn("exact_chur_artifacts_missing", str(ctx.exception))

    def test_file_tamper_is_detected(self) -> None:
        self.build()
        path = self.root / "awg/opkgtun0.conf"
        path.write_text("tampered\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.verify()
        self.assertIn("drift", str(ctx.exception))

    def test_unmanaged_file_is_detected(self) -> None:
        self.build()
        extra = self.root / "private-extra.key"
        extra.write_text("secret fixture\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.verify()
        self.assertIn("unmanaged files", str(ctx.exception))

    def test_builder_refuses_unexpected_file(self) -> None:
        (self.root / "unexpected.txt").write_text("x\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.build()
        self.assertIn("unexpected files", str(ctx.exception))

    def test_manifest_mode_is_private(self) -> None:
        self.build()
        mode = stat.S_IMODE((self.root / "manifest.json").stat().st_mode)
        self.assertEqual(mode, 0o600)


if __name__ == "__main__":
    unittest.main()
