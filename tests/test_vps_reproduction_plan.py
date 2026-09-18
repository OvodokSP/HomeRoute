from __future__ import annotations

import contextlib
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


renderer = load_module(
    "render_vps_plan",
    ROOT / "scripts" / "reproduction" / "render_vps_plan.py",
)


class VPSReproductionPlanTests(unittest.TestCase):
    def render(self, *extra: str) -> str:
        out = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["render_vps_plan.py", *extra]),
            contextlib.redirect_stdout(out),
        ):
            rc = renderer.main()
        self.assertEqual(rc, 0)
        return out.getvalue()

    def test_public_plan_is_read_only_and_blocked(self) -> None:
        out = self.render()
        self.assertIn("HOMEROUTE_REPRO_PLAN schema=1 scope=vps mode=plan_only", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN mutates_system=false", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN reproduction_apply_ready=false", out)
        self.assertIn("id=exact_clean_install_image_bundle", out)
        self.assertIn("id=dns_helper_semantics", out)
        self.assertIn("id=deterministic_container_renderer", out)
        self.assertIn("id=reproduction_apply_engine", out)

    def test_verified_local_bundle_satisfies_only_bundle_gate(self) -> None:
        manifest = {
            "schema": 1,
            "scope": "vps",
            "artifact_count": 4,
            "bundle_integrity_ready": True,
            "content_printed": False,
            "artifacts": {
                "awg_state": {},
                "adguard_state": {},
                "awg_image": {},
                "adguard_image": {},
            },
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            out = self.render("--bundle-manifest", str(path))

        self.assertNotIn("id=exact_clean_install_image_bundle", out)
        self.assertIn("id=dns_helper_semantics", out)
        self.assertIn("id=deterministic_container_renderer", out)
        self.assertIn("id=reproduction_apply_engine", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN reproduction_apply_ready=false", out)

    def test_json_plan_step_order(self) -> None:
        data = json.loads(self.render("--json"))
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["scope"], "vps")
        self.assertEqual(data["steps"][0]["id"], "preflight_platform")
        self.assertEqual(data["steps"][-1]["id"], "record_evidence")
        self.assertFalse(data["mutates_system"])
        self.assertFalse(data["stable_apply_allowed"])


if __name__ == "__main__":
    unittest.main()
