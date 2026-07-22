#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0
"""Fail if Vivado timing_summary.rpt reports WNS < 0.

Usage:
  python scripts/check_wns.py path/to/timing_summary.rpt
Exit 0 if WNS is non-negative or the report is missing/unparseable (warn only).
Exit 1 if WNS is clearly negative.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_wns.py <timing_summary.rpt>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"check_wns: no report at {path}; skipping WNS gate")
        return 0
    text = path.read_text(encoding="utf-8", errors="replace")
    # Vivado timing_summary.rpt has a Design Timing Summary table with WNS column.
    m = re.search(
        r"WNS\(ns\)\s+TNS\(ns\).*?\n[-\s]+\n\s*([-\d.]+)",
        text,
        re.DOTALL,
    )
    if not m:
        # Alternate: "Worst Negative Slack (WNS):  0.123 ns"
        m = re.search(r"Worst Negative Slack\s*\(WNS\)\s*:\s*([-\d.]+)", text)
    if not m:
        print(f"check_wns: could not parse WNS from {path}; skipping gate")
        return 0
    wns = float(m.group(1))
    print(f"check_wns: WNS = {wns} ns ({path})")
    if wns < 0:
        print(f"check_wns: FAIL timing not closed (WNS {wns} < 0)")
        return 1
    print("check_wns: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
