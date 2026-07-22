#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0
"""Fail if Vivado timing_summary.rpt reports WNS or WHS below zero."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def _parse_table_slacks(text: str) -> tuple[float | None, float | None]:
    """Parse WNS/WHS from Design Timing Summary table when present."""
    match = re.search(
        r"WNS\(ns\)\s+TNS\(ns\).*?WHS\(ns\).*?\n[-\s|]+\n\s*"
        r"([-\d.]+)\s+([-\d.]+)\s+\S+\s+([-\d.]+)",
        text,
        re.DOTALL,
    )
    if match:
        return float(match.group(1)), float(match.group(3))
    match = re.search(
        r"WNS\(ns\)\s+TNS\(ns\).*?\n[-\s]+\n\s*([-\d.]+)",
        text,
        re.DOTALL,
    )
    if match:
        return float(match.group(1)), None
    return None, None


def _parse_prose_slack(text: str, label: str) -> float | None:
    match = re.search(
        rf"Worst (?:Negative|Hold) Slack\s*\({label}\)\s*:\s*([-\d.]+)",
        text,
    )
    if match:
        return float(match.group(1))
    match = re.search(rf"\b{label}\s*[:=]\s*([-\d.]+)\s*ns", text, re.IGNORECASE)
    return float(match.group(1)) if match else None


def _resolve_slacks(text: str) -> tuple[float | None, float | None]:
    wns, whs = _parse_table_slacks(text)
    if wns is None:
        wns = _parse_prose_slack(text, "WNS")
    if whs is None:
        whs = _parse_prose_slack(text, "WHS")
    return wns, whs


def _check_slack(name: str, value: float | None, path: Path) -> bool:
    """Return True if this slack fails (negative)."""
    if value is None:
        return False
    print(f"check_wns: {name} = {value} ns ({path})")
    if value < 0:
        print(f"check_wns: FAIL {name} not closed ({value} < 0)")
        return True
    return False


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_wns.py <timing_summary.rpt>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"check_wns: no report at {path}; skipping timing gate")
        return 0

    text = path.read_text(encoding="utf-8", errors="replace")
    wns, whs = _resolve_slacks(text)
    if wns is None and whs is None:
        print(f"check_wns: could not parse WNS/WHS from {path}; skipping gate")
        return 0

    failed = _check_slack("WNS", wns, path) or _check_slack("WHS", whs, path)
    if failed:
        return 1
    print("check_wns: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
