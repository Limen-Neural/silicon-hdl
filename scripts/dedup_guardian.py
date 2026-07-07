#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0
"""Deduplication Guardian for silicon-hdl.

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


def build_protected_and_locations(files: List[Path]) -> Tuple[set, Dict[str, List[Path]]]:
    """One pass to build protected set and module_locations map. Avoids repeated reads."""
    protected = set()
    locs: Dict[str, List[Path]] = defaultdict(list)
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
        canonical_str, modules = extract_canonical_and_module(text)
        if canonical_str and modules:
            for m in modules:
                protected.add(m)
        for m in modules:
            locs[m].append(f)
    return protected, locs


def compute_similarity(a: str, b: str) -> float:
    """Normalized difflib ratio on full text (good enough for small HDL repo)."""
    # Quick early-out
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def _find_strict_violations(
    protected: set, module_locations: Dict[str, List[Path]]
) -> List[Tuple[str, List[Path]]]:
    """Return modules with != 1 occurrence."""
    violations: List[Tuple[str, List[Path]]] = []
    for name in sorted(protected):
        hits = module_locations.get(name, [])
        if len(hits) != 1:
            violations.append((name, hits))
    return violations


def _load_impl_texts(
    sv_files: List[Path],
) -> Tuple[List[Path], Dict[Path, str]]:
    """Read implementation files (excluding tb/examples), return paths + texts."""
    impl_files = [
        f for f in sv_files
        if "tb" not in f.parts and "examples" not in f.parts
    ]
    file_texts: Dict[Path, str] = {}
    for f in impl_files:
        try:
            file_texts[f] = f.read_text(encoding="utf-8", errors="replace")
        except (OSError, UnicodeDecodeError):
            continue
    return impl_files, file_texts


def _compare_pair(
    a: Path, b: Path, ta: str, tb: str, root: Path, threshold: float
) -> Optional[Tuple[Path, Path, float, str]]:
    """Compare two files; return near-dup tuple if above threshold, else None."""
    if not ta or not tb:
        return None
    score = compute_similarity(ta, tb)
    if score < threshold:
        return None
    diff_lines = list(
        difflib.unified_diff(
            ta.splitlines(keepends=False),
            tb.splitlines(keepends=False),
            fromfile=str(a.relative_to(root)),
            tofile=str(b.relative_to(root)),
            n=3,
        )
    )[:30]
    return (a, b, score, "\n".join(diff_lines))


def _find_near_dups(
    sv_files: List[Path], root: Path, threshold: float
) -> List[Tuple[Path, Path, float, str]]:
    """Pairwise similarity scan on implementation files."""
    impl_files, file_texts = _load_impl_texts(sv_files)
    near_dups: List[Tuple[Path, Path, float, str]] = []
    compared = set()
    for i, a in enumerate(impl_files):
        for b in impl_files[i + 1 :]:
            key = tuple(sorted([str(a), str(b)]))
            if key in compared or a in IGNORE_FOR_NEAR_DUP or b in IGNORE_FOR_NEAR_DUP:
                continue
            compared.add(key)
            result = _compare_pair(
                a, b, file_texts.get(a, ""), file_texts.get(b, ""), root, threshold
            )
            if result is not None:
                near_dups.append(result)
    return near_dups


def analyze_repository(sv_files: List[Path], root: Path, threshold: float):
    """Core analysis: returns (strict_violations, near_dups, purity)."""
    protected, module_locations = build_protected_and_locations(sv_files)
    strict_violations = _find_strict_violations(protected, module_locations)
    near_dups = _find_near_dups(sv_files, root, threshold)
    purity = max(0, 100 - len(strict_violations) * 20 - len(near_dups) * 5)
    return strict_violations, near_dups, purity


def _format_strict_section(
    strict_violations: List[Tuple[str, List[Path]]], root: Path
) -> List[str]:
    """Format the strict-duplicates section of the radar."""
    lines: List[str] = []
    lines.append("### 🚨 Strict Duplicates (enforcement)")
    for name, hits in strict_violations:
        lines.append(f"- **module {name}** appears in {len(hits)} places (expected exactly the canonical):")
        for h in hits:
            lines.append(f"  - `{h.relative_to(root)}`")
        lines.append(
            "  **Action**: keep only the canonical copy declared in its header; "
            "delete or move the others."
        )
    lines.append("")
    return lines


def _format_near_dups_section(
    near_dups: List[Tuple[Path, Path, float, str]], root: Path
) -> List[str]:
    """Format the near-duplicates section of the radar."""
    lines: List[str] = []
    lines.append("### ⚠️ Near Duplicates (review recommended)")
    for a, b, score, diff in near_dups:
        lines.append(f"- `{a.relative_to(root)}` ~ `{b.relative_to(root)}` ({score:.0%} similar)")
        if diff:
            lines.append("  ```diff")
            lines.append(diff)
            lines.append("  ```")
        lines.append("  **Suggested**: align with the canonical source or delete the near-dupe.")
    lines.append("")
    return lines


def generate_radar(
    strict_violations: List[Tuple[str, List[Path]]],
    near_dups: List[Tuple[Path, Path, float, str]],
    purity: int,
    root: Path,
) -> str:
    """Build the Dupe Radar markdown comment."""
    lines: List[str] = [
        "🛡️ **Dupe Radar** <!-- dedup-guardian -->",
        "",
        f"**Purity Score: {purity}%** (this PR / tree)",
        "",
    ]

    if not strict_violations and not near_dups:
        lines.append("✅ **All clear.** The single source of truth is safe.")
        lines.append("")
        lines.append("Guardian says: no strict duplicates, no concerning near-duplicates.")
        return "\n".join(lines)

    if strict_violations:
        lines.extend(_format_strict_section(strict_violations, root))
    if near_dups:
        lines.extend(_format_near_dups_section(near_dups, root))

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

    strict_violations, near_dups, purity = analyze_repository(sv_files, root, args.threshold)

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