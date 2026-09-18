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
    "render_router_plan",
    ROOT / "scripts" / "reproduction" / "render_router_plan.py",
)


class RouterReproductionPlanTests(unittest.TestCase):
    def render(self, *extra: str) -> str:
        out = io.StringIO()
        argv = ["render_router_plan.py", *extra]
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(out):
            rc = renderer.main()
        self.assertEqual(rc, 0)
        return out.getvalue()

    def test_public_plan_is_read_only_and_blocked(self) -> None:
        out = self.render()
        self.assertIn("HOMEROUTE_REPRO_PLAN schema=1 scope=router mode=plan_only", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN mutates_system=false", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN reproduction_apply_ready=false", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN stable_apply_allowed=false", out)
        self.assertIn("id=exact_chur_artifact_identity", out)
        self.assertIn("id=telegram_ndm_dependency_targets", out)
        self.assertIn("id=reproduction_apply_engine", out)
        self.assertIn("id=router_hook_exact_source_bundle", out)

    def test_exact_hook_bundle_only_satisfies_source_presence(self) -> None:
        contract = json.loads(
            (ROOT / "config" / "router-reference-contract.json").read_text(encoding="utf-8")
        )
        hooks = [
            {
                "path": "hooks" + hook["path"],
                "kind": "hook",
                "bytes": hook["bytes"],
                "sha256": hook["sha256"],
            }
            for hook in contract["hooks"]
        ]

        manifest = {
            "schema": 1,
            "scope": "router",
            "files": hooks,
            "blockers": [],
            "ready_for_reproduction_apply": True,
            "content_printed": False,
        }

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            out = self.render("--bundle-manifest", str(path))

        self.assertNotIn("id=router_hook_exact_source_bundle", out)
        self.assertNotIn("id=exact_hook_source_bundle source=gates", out)

        # Exact source presence does not prove unresolved semantics or packages.
        self.assertIn("id=telegram_ndm_dependency_targets", out)
        self.assertIn("id=exact_chur_artifact_identity", out)
        self.assertIn("id=reproduction_apply_engine", out)
        self.assertIn("HOMEROUTE_REPRO_PLAN reproduction_apply_ready=false", out)

    def test_json_plan_has_stable_ordered_steps(self) -> None:
        out = self.render("--json")
        data = json.loads(out)
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["scope"], "router")
        self.assertEqual(data["mode"], "plan_only")
        self.assertFalse(data["mutates_system"])
        self.assertGreaterEqual(len(data["steps"]), 10)
        orders = [item["order"] for item in data["steps"]]
        self.assertEqual(orders, list(range(1, len(orders) + 1)))
        self.assertEqual(data["steps"][0]["id"], "preflight_platform")
        self.assertEqual(data["steps"][-1]["id"], "record_evidence")


if __name__ == "__main__":
    unittest.main()
