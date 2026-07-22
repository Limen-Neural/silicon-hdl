#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0
"""
Fail if Vivado timing_summary.rpt reports WNS or WHS < 0.

Usage:
  python scripts/check_wns.py path/to/timing_summary.rpt

Exit 0 if both WNS and WHS are non-negative, or the report is
missing/unparseable (warn only). Exit 1 if either slack is clearly negative.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def _parse_table_slacks(text: str) -> tuple[float | None, float | None]:
    """Parse WNS/WHS from Design Timing Summary table when present."""
    # Header: WNS(ns) TNS(ns) TNS Failing Endpoints WHS(ns) ...
    m = re.search(
        r"WNS\(ns\)\s+TNS\(ns\).*?WHS\(ns\).*?\n[-\s|]+\n\s*"
        r"([-\d.]+)\s+([-\d.]+)\s+\S+\s+([-\d.]+)",
        text,
        re.DOTALL,
    )
    if m:
        return float(m.group(1)), float(m.group(3))
    m = re.search(
        r"WNS\(ns\)\s+TNS\(ns\).*?\n[-\s]+\n\s*([-\d.]+)",
        text,
        re.DOTALL,
    )
    if m:
        return float(m.group(1)), None
    return None, None


def _parse_prose_slack(text: str, label: str) -> float | None:
    m = re.search(
        rf"Worst (?:Negative|Hold) Slack\s*\({label}\)\s*:\s*([-\d.]+)",
        text,
    )
    if m:
        return float(m.group(1))
    m = re.search(rf"\b{label}\s*[:=]\s*([-\d.]+)\s*ns", text, re.IGNORECASE)
    return float(m.group(1)) if m else None


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_wns.py <timing_summary.rpt>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"check_wns: no report at {path}; skipping timing gate")
        return 0

    text = path.read_text(encoding="utf-8", errors="replace")
    wns, whs = _parse_table_slacks(text)
    if wns is None:
        wns = _parse_prose_slack(text, "WNS")
    if whs is None:
        whs = _parse_prose_slack(text, "WHS")

    if wns is None and whs is None:
        print(f"check_wns: could not parse WNS/WHS from {path}; skipping gate")
        return 0

    failed = False
    if wns is not None:
        print(f"check_wns: WNS = {wns} ns ({path})")
        if wns < 0:
            print(f"check_wns: FAIL setup timing not closed (WNS {wns} < 0)")
            failed = True
    if whs is not None:
        print(f"check_wns: WHS = {whs} ns ({path})")
        if whs < 0:
            print(f"check_wns: FAIL hold timing not closed (WHS {whs} < 0)")
            failed = True

    if failed:
        return 1
    print("check_wns: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
