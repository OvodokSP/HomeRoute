#!/usr/bin/env python3
"""Dependency-free deterministic checks for the HomeRoute repository."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(os.environ.get("HOMEROUTE_ROOT", Path(__file__).resolve().parents[2])).resolve()
REQUIRED = {
    "AGENTS.md",
    "CURRENT_STATE.md",
    "README.md",
    "ROADMAP.md",
    "SECURITY.md",
    "docs/architecture.md",
    "docs/decision-log.md",
    "docs/reference-state-v0.1.md",
}
PROTECTED = {
    ".gitignore",
    "AGENTS.md",
    "CURRENT_STATE.md",
    "SECURITY.md",
    "docs/architecture.md",
    "docs/decision-log.md",
    "scripts/agent/roadmap.py",
    "scripts/ci/validate_repo.py",
}
PROTECTED_PREFIXES = (".github/workflows/", "agent/prompts/")
SECRET_PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----"),
    "OpenAI key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"),
    "GitHub token": re.compile(r"\b(?:ghp|github_pat)_[A-Za-z0-9_]{20,}\b"),
    "Slack token": re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    "WireGuard/AWG key": re.compile(
        r"(?im)^[ \t]*(?:PrivateKey|PublicKey|PresharedKey)[ \t]*=[ \t]*[A-Za-z0-9+/]{43}=[ \t]*$"
    ),
    "literal credential assignment": re.compile(
        r"(?im)^[ \t]*[\"']?[A-Z0-9_]*(?:PASSWORD|TOKEN|SECRET|PSK|PRIVATE_KEY)[\"']?"
        r"[ \t]*[:=][ \t]*"
        r"[\"']?(?!CHANGE_ME|REDACTED|PLACEHOLDER|EXAMPLE|\$\{\{|[\"']?[ \t]*$)"
        r"[^\"'\s#][^\"'\r\n]{7,}"
    ),
    "private infrastructure endpoint": re.compile(
        r"(?im)^[ \t]*[\"']?(?:VPS_HOST|SSH_HOST|NAS_HOST|ROUTER_HOST)[\"']?"
        r"[ \t]*[:=][ \t]*"
        r"[\"']?(?!CHANGE_ME|REDACTED|PLACEHOLDER|EXAMPLE|[\"']?[ \t]*$)"
        r"[^\"'\s#]+"
    ),
    "credential in URL": re.compile(r"https?://[^\s/:@]+:(?!\$\{)[^\s/@]+@[^\s/]+"),
}
LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
FORBIDDEN_WORKFLOW = re.compile(
    r"(^|[\s|;&])(?:ssh|scp|sftp|rsync|ansible-playbook|kubectl)\s", re.MULTILINE
)


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        text=True,
        check=True,
        capture_output=True,
    )
    return [ROOT / line for line in result.stdout.splitlines() if line]


def check_required(errors: list[str]) -> None:
    for relative in sorted(REQUIRED):
        if not (ROOT / relative).is_file():
            errors.append(f"missing required file: {relative}")


def check_secrets(files: list[Path], errors: list[str]) -> None:
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        relative = path.relative_to(ROOT)
        for name, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                errors.append(f"possible {name} in {relative}")


def check_markdown_links(files: list[Path], errors: list[str]) -> None:
    for path in files:
        if path.suffix.lower() != ".md":
            continue
        text = path.read_text(encoding="utf-8")
        for raw_target in LINK.findall(text):
            target = raw_target.strip().split(maxsplit=1)[0].strip("<>\"")
            if not target or target.startswith("#") or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue
            relative_target = unquote(target.split("#", 1)[0])
            if relative_target and not (path.parent / relative_target).resolve().exists():
                errors.append(f"broken local link in {path.relative_to(ROOT)}: {target}")


def check_shell(files: list[Path], errors: list[str]) -> None:
    for path in files:
        if path.suffix != ".sh":
            continue
        result = subprocess.run(["sh", "-n", str(path)], cwd=ROOT, text=True, capture_output=True)
        if result.returncode:
            errors.append(f"shell syntax error in {path.relative_to(ROOT)}: {result.stderr.strip()}")


def check_workflows(errors: list[str]) -> None:
    workflow_dir = ROOT / ".github" / "workflows"
    if not workflow_dir.exists():
        return
    for path in workflow_dir.glob("*.yml"):
        text = path.read_text(encoding="utf-8")
        if "pull_request_target:" in text:
            errors.append(f"unsafe pull_request_target trigger in {path.relative_to(ROOT)}")
        if FORBIDDEN_WORKFLOW.search(text):
            errors.append(f"live infrastructure command in {path.relative_to(ROOT)}")


def check_state_contract(errors: list[str]) -> None:
    state = (ROOT / "CURRENT_STATE.md").read_text(encoding="utf-8")
    for value in ("opkgtun0", "0x3001", "301", "AmneziaWG 2.x", "0xffffaab", "4098"):
        if value not in state:
            errors.append(f"CURRENT_STATE.md lost required contract value: {value}")
    roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
    if not re.search(r"^- \[[ x]\] HL-\d{3} — .+$", roadmap, re.MULTILINE):
        errors.append("ROADMAP.md has no machine-readable HL-NNN item")


def changed_files(base: str) -> set[str]:
    subprocess.run(["git", "fetch", "--no-tags", "origin", base], cwd=ROOT, check=False, capture_output=True)
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        cwd=ROOT,
        text=True,
        check=True,
        capture_output=True,
    )
    unstaged = subprocess.run(
        ["git", "diff", "--name-only"], cwd=ROOT, text=True, check=True, capture_output=True
    )
    staged = subprocess.run(
        ["git", "diff", "--cached", "--name-only"],
        cwd=ROOT,
        text=True,
        check=True,
        capture_output=True,
    )
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard"],
        cwd=ROOT,
        text=True,
        check=True,
        capture_output=True,
    )
    return (
        set(result.stdout.splitlines())
        | set(unstaged.stdout.splitlines())
        | set(staged.stdout.splitlines())
        | set(untracked.stdout.splitlines())
    )


def check_protected(base: str, errors: list[str]) -> None:
    for relative in sorted(changed_files(base)):
        if relative in PROTECTED or relative.startswith(PROTECTED_PREFIXES):
            errors.append(f"ordinary autopilot task changed protected policy: {relative}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--protect-policy", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    files = tracked_files()
    check_required(errors)
    check_secrets(files, errors)
    check_markdown_links(files, errors)
    check_shell(files, errors)
    check_workflows(errors)
    check_state_contract(errors)
    if args.protect_policy:
        check_protected(args.base, errors)
    diff_check = subprocess.run(["git", "diff", "--check"], cwd=ROOT, text=True, capture_output=True)
    if diff_check.returncode:
        errors.append(diff_check.stdout.strip() or "git diff --check failed")
    cached_diff_check = subprocess.run(
        ["git", "diff", "--cached", "--check"], cwd=ROOT, text=True, capture_output=True
    )
    if cached_diff_check.returncode:
        errors.append(cached_diff_check.stdout.strip() or "git diff --cached --check failed")

    if errors:
        for error in errors:
            print(f"[FAIL] {error}")
        return 1
    print("[PASS] repository validation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
