from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
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
    "build_vps_bundle",
    ROOT / "scripts" / "reproduction" / "build_vps_bundle.py",
)
verifier = load_module(
    "verify_vps_bundle",
    ROOT / "scripts" / "reproduction" / "verify_vps_bundle.py",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class VPSReproductionBundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / builder.MARKER).write_text("test\n", encoding="utf-8")

        self._make_awg_state()
        self._make_adguard_state()
        self._make_image(
            "awg-image",
            "sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d",
        )
        self._make_image(
            "adguard-image",
            "sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0",
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _write_manifest(self, base: Path, names: list[str], manifest_name: str) -> None:
        lines = [f"{sha256(base / name)}  {name}" for name in names]
        (base / manifest_name).write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _make_awg_state(self) -> None:
        base = self.root / "awg-state"
        (base / "awg").mkdir(parents=True)
        (base / "awg/awg0.conf").write_text("private-fixture\n", encoding="utf-8")
        (base / "start.sh").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        (base / "metadata.txt").write_text(
            "schema=1\n"
            "container=amnezia-awg2\n"
            "state_path=/opt/amnezia/awg\n"
            "startup_path=/opt/amnezia/start.sh\n"
            "captured_utc=fixture\n"
            "scope=awg_state_and_startup\n",
            encoding="utf-8",
        )
        self._write_manifest(
            base,
            ["awg/awg0.conf", "start.sh", "metadata.txt"],
            "MANIFEST.sha256",
        )

    def _make_adguard_state(self) -> None:
        base = self.root / "adguard-state"
        (base / "conf").mkdir(parents=True)
        (base / "work").mkdir(parents=True)
        (base / "conf/AdGuardHome.yaml").write_text("fixture: true\n", encoding="utf-8")
        (base / "work/data.bin").write_bytes(b"fixture\n")
        (base / "metadata.txt").write_text(
            "schema=1\n"
            "container=adguard-home\n"
            "conf_path=/opt/adguardhome/conf\n"
            "work_path=/opt/adguardhome/work\n"
            "captured_utc=fixture\n"
            "scope=adguard_conf_and_work\n",
            encoding="utf-8",
        )
        self._write_manifest(
            base,
            ["conf/AdGuardHome.yaml", "work/data.bin", "metadata.txt"],
            "MANIFEST.sha256",
        )

    def _make_image(self, dirname: str, image_id: str) -> None:
        base = self.root / dirname
        base.mkdir(parents=True)
        (base / "image.tar").write_bytes(f"image fixture {dirname}\n".encode())
        (base / "metadata.txt").write_text(
            "schema=1\n"
            f"container={'amnezia-awg2' if dirname == 'awg-image' else 'adguard-home'}\n"
            f"safe_name={dirname}\n"
            f"image_id={image_id}\n"
            "image_size_bytes=123\n"
            "captured_utc=fixture\n"
            "scope=exact_running_container_image\n",
            encoding="utf-8",
        )
        self._write_manifest(base, ["image.tar"], "IMAGE.sha256")

    def build(self) -> str:
        out = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["build_vps_bundle.py", "--root", str(self.root)]),
            contextlib.redirect_stdout(out),
        ):
            rc = builder.main()
        self.assertEqual(rc, 0)
        return out.getvalue()

    def verify(self) -> str:
        out = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["verify_vps_bundle.py", "--root", str(self.root)]),
            contextlib.redirect_stdout(out),
        ):
            rc = verifier.main()
        self.assertEqual(rc, 0)
        return out.getvalue()

    def test_build_and_verify(self) -> None:
        out = self.build()
        self.assertIn("bundle_integrity_ready=true", out)
        data = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(data["artifact_count"], 4)
        self.assertTrue(data["bundle_integrity_ready"])
        self.assertFalse(data["content_printed"])

        verify_out = self.verify()
        self.assertIn("[PASS] local VPS reproduction bundle integrity re-verified", verify_out)

    def test_state_tamper_is_detected(self) -> None:
        self.build()
        (self.root / "awg-state/awg/awg0.conf").write_text("tampered\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.verify()
        self.assertIn("checksum mismatch", str(ctx.exception))

    def test_image_tamper_is_detected(self) -> None:
        self.build()
        (self.root / "adguard-image/image.tar").write_bytes(b"tampered\n")
        with self.assertRaises(SystemExit) as ctx:
            self.verify()
        self.assertIn("checksum mismatch", str(ctx.exception))

    def test_wrong_image_id_is_rejected(self) -> None:
        metadata = self.root / "awg-image/metadata.txt"
        text = metadata.read_text(encoding="utf-8").replace(
            "sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d",
            "sha256:" + "0" * 64,
        )
        metadata.write_text(text, encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.build()
        self.assertIn("exact image ID drifted", str(ctx.exception))

    def test_unexpected_top_level_object_is_rejected(self) -> None:
        (self.root / "secret.txt").write_text("fixture\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as ctx:
            self.build()
        self.assertIn("unexpected top-level", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
