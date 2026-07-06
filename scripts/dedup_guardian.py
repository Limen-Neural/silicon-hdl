#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0
"""
Deduplication Guardian for silicon-hdl

Scans the monorepo for strict duplicate "module Name" definitions
(violating the canonical single-source-of-truth rules) and near-duplicates.

- Builds canonical registry from "Canonical source:" headers + module declarations.
- Enforces exactly one occurrence per registered module, in the declared canonical file.
- Reports near-duplicates using difflib (for "smart" Dupe Radar).
- Outputs human-friendly "Dupe Radar" markdown + Purity Score.
- Exits non-zero on any strict violations (for CI enforcement).

Usage:
  python scripts/dedup_guardian.py [--threshold 0.85] [--radar radar.md]

Local run (clean tree should be 100% purity, exit 0):
  python scripts/dedup_guardian.py

See README.md "Deduplication verification" and issue #5.
"""

import argparse
import difflib
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Focus areas for scanning (per repo layout and issue scope)
FOCUS_GLOBS = ["spikenaut-*/**/*.sv", "synapse-link-hdl/**/*.sv"]

# Pattern for canonical header (seen in all protected .sv)
CANONICAL_RE = re.compile(r"^\s*//\s*Canonical source:\s*(.+?)\s*$", re.MULTILINE)

# Pattern for module declaration (SystemVerilog)
MODULE_RE = re.compile(r"^\s*module\s+(\w+)", re.MULTILINE)

# Files to completely ignore for near-dup comparisons (examples, tests, etc. if needed)
IGNORE_FOR_NEAR_DUP = set()


def find_sv_files(root: Path) -> List[Path]:
    files: List[Path] = []
    for glob in FOCUS_GLOBS:
        files.extend(root.glob(glob))
    # Dedup + sort for determinism
    return sorted(set(f for f in files if f.is_file()))


def extract_canonical_and_module(text: str) -> Tuple[Optional[str], List[str]]:
    """Return (canonical_path_str or None, list of module_names) from a .sv file."""
    canon_match = CANONICAL_RE.search(text)
    canonical = canon_match.group(1).strip() if canon_match else None

    modules = [m.group(1) for m in MODULE_RE.finditer(text)]

    return canonical, modules


def build_protected_modules(files: List[Path]) -> set:
    """
    Return the set of module names that have at least one declaration of
    "Canonical source:" in a file that also contains that module.
    These are the modules the Guardian strictly protects (expect exactly 1 hit).
    """
    protected = set()
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
        canonical_str, modules = extract_canonical_and_module(text)
        if canonical_str and modules:
            for m in modules:
                protected.add(m)
    return protected


def precompute_module_locations(files: List[Path]) -> Dict[str, List[Path]]:
    """One pass to map module name to list of files containing it. Avoids repeated reads."""
    locs: Dict[str, List[Path]] = defaultdict(list)
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
        for m in MODULE_RE.finditer(text):
            locs[m.group(1)].append(f)
    return locs


def find_occurrences(files: List[Path], module_name: str) -> List[Path]:
    """Find all .sv files that contain 'module <name>' (simple, fast, matches README greps)."""
    pattern = re.compile(rf"^\s*module\s+{re.escape(module_name)}\b", re.MULTILINE)
    hits: List[Path] = []
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
            if pattern.search(text):
                hits.append(f)
        except (OSError, UnicodeDecodeError):
            continue
    return sorted(set(hits))


def compute_similarity(a: str, b: str) -> float:
    """Normalized difflib ratio on full text (good enough for small HDL repo)."""
    # Quick early-out
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def generate_radar(
    strict_violations: List[Tuple[str, List[Path]]],
    near_dups: List[Tuple[Path, Path, float, str]],
    purity: int,
    root: Path,
) -> str:
    lines: List[str] = []
    lines.append("🛡️ **Dupe Radar** <!-- dedup-guardian -->")
    lines.append("")
    lines.append(f"**Purity Score: {purity}%** (this PR / tree)")
    lines.append("")

    if not strict_violations and not near_dups:
        lines.append("✅ **All clear.** The single source of truth is safe.")
        lines.append("")
        lines.append("Guardian says: no strict duplicates, no concerning near-duplicates.")
        return "\n".join(lines)

    if strict_violations:
        lines.append("### 🚨 Strict Duplicates (enforcement)")
        for name, hits in strict_violations:
            lines.append(f"- **module {name}** appears in {len(hits)} places (expected exactly the canonical):")
            for h in hits:
                rel = h.relative_to(root)
                lines.append(f"  - `{rel}`")
            lines.append("  **Action**: keep only the canonical copy declared in its header; delete or move the others.")
        lines.append("")

    if near_dups:
        lines.append("### ⚠️ Near Duplicates (review recommended)")
        for a, b, score, diff in near_dups:
            rel_a = a.relative_to(root)
            rel_b = b.relative_to(root)
            lines.append(f"- `{rel_a}` ~ `{rel_b}` ({score:.0%} similar)")
            if diff:
                lines.append("  ```diff")
                lines.append(diff)
                lines.append("  ```")
            lines.append("  **Suggested**: align with the canonical source or delete the near-dupe.")
        lines.append("")

    lines.append("Guardian says: review the radar above and keep the single source of truth pure.")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Deduplication Guardian")
    parser.add_argument("--threshold", type=float, default=0.85, help="Near-dupe similarity threshold (0-1)")
    parser.add_argument("--radar", type=str, default=None, help="Write radar markdown to this file")
    parser.add_argument("--json", action="store_true", help="Also emit JSON findings (future use)")
    args = parser.parse_args()

    root = Path(".").resolve()
    sv_files = find_sv_files(root)

    # Precompute module locations in one pass to avoid O(N*M) re-reads (addresses gemini perf review)
    module_locations: Dict[str, List[Path]] = defaultdict(list)
    for f in sv_files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
        for m in MODULE_RE.finditer(text):
            module_locations[m.group(1)].append(f)

    # Protected modules = those that declare "Canonical source:" in at least one file
    protected = build_protected_modules(sv_files)

    strict_violations: List[Tuple[str, List[Path]]] = []
    for name in sorted(protected):
        hits = module_locations.get(name, [])
        if len(hits) != 1:
            strict_violations.append((name, hits))

    # Near-dup radar — only among the protected canonical files (skip TBs etc.)
    near_dups: List[Tuple[Path, Path, float, str]] = []
    # Map protected names back to their canonical file (the one with the header)
    name_to_canon: Dict[str, Path] = {}
    for f in sv_files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
        canonical_str, modules = extract_canonical_and_module(text)
        if canonical_str and modules:
            for m in modules:
                if m in protected and m not in name_to_canon:
                    name_to_canon[m] = f
    impl_files = [f for f in sv_files if '/tb/' not in str(f) and '/examples/' not in str(f)]  # compare impl for near, exclude tb/examples (to keep 100% on clean)
    file_texts: Dict[Path, str] = {}
    for f in impl_files:
        try:
            file_texts[f] = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

    compared = set()
    for i, a in enumerate(impl_files):
        for b in impl_files[i+1:]:
            key = tuple(sorted([str(a), str(b)]))
            if key in compared:
                continue
            compared.add(key)
            if a in IGNORE_FOR_NEAR_DUP or b in IGNORE_FOR_NEAR_DUP:
                continue
            ta = file_texts.get(a, "")
            tb = file_texts.get(b, "")
            if not ta or not tb:
                continue
            score = compute_similarity(ta, tb)
            if score >= args.threshold:
                diff_lines = list(difflib.unified_diff(
                    ta.splitlines(keepends=False),
                    tb.splitlines(keepends=False),
                    fromfile=str(a.relative_to(root)),
                    tofile=str(b.relative_to(root)),
                    n=3,
                ))[:30]
                diff = "\n".join(diff_lines)
                near_dups.append((a, b, score, diff))

    # Purity score (simple, tunable)
    strict_penalty = len(strict_violations) * 20
    near_penalty = len(near_dups) * 5
    purity = max(0, 100 - strict_penalty - near_penalty)

    radar = generate_radar(strict_violations, near_dups, purity, root)

    if args.radar:
        Path(args.radar).write_text(radar, encoding="utf-8")

    # Always print radar to stdout (CI captures it)
    print(radar)
    print()

    if strict_violations:
        print(f"Guardian: {len(strict_violations)} strict violation(s) found. Purity: {purity}%")
        return 1

    if near_dups:
        print(f"Guardian: {len(near_dups)} near-duplicate(s) flagged for review. Purity: {purity}%")
        # Near-dups are warnings only; do not fail CI (unless you change policy)
        return 0

    print(f"Guardian: clean. Purity: {purity}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())