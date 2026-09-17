#!/usr/bin/env python3
"""Select or complete one machine-readable HomeRoute Roadmap item."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROADMAP = Path("ROADMAP.md")
OPEN_ITEM = re.compile(r"^- \[ \] (HL-\d{3}) — (.+)$")


def next_item(text: str) -> tuple[str, str] | None:
    for line in text.splitlines():
        match = OPEN_ITEM.match(line)
        if match:
            return match.group(1), match.group(2).strip()
    return None


def complete(text: str, task_id: str) -> str:
    pattern = re.compile(rf"^- \[ \] ({re.escape(task_id)}) — (.+)$", re.MULTILINE)
    updated, count = pattern.subn(r"- [x] \1 — \2", text, count=1)
    if count != 1:
        raise SystemExit(f"open Roadmap item not found: {task_id}")
    return updated


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("next")
    done = sub.add_parser("complete")
    done.add_argument("task_id")
    args = parser.parse_args()

    text = ROADMAP.read_text(encoding="utf-8")
    if args.command == "next":
        item = next_item(text)
        if item is None:
            print("found=false")
            return
        task_id, title = item
        print("found=true")
        print(f"task_id={task_id}")
        print(f"title={title}")
        return

    ROADMAP.write_text(complete(text, args.task_id), encoding="utf-8")


if __name__ == "__main__":
    main()
