# SPDX-License-Identifier: MIT OR Apache-2.0
"""Unit tests for scripts/dedup_guardian.py (Phase A4 / issue #21)."""

from __future__ import annotations

from pathlib import Path

import dedup_guardian as dg


def test_compute_similarity_identical() -> None:
    assert dg.compute_similarity("abc", "abc") == 1.0


def test_compute_similarity_different() -> None:
    score = dg.compute_similarity("module Foo;", "module Bar;")
    assert 0.0 <= score < 1.0


def test_extract_canonical_and_module() -> None:
    text = """// SPDX-License-Identifier: MIT OR Apache-2.0
// LifNeuron.sv
// Canonical source: spikenaut-core-sv/rtl

module LifNeuron (
  input wire clk
);
endmodule
"""
    canon, modules = dg.extract_canonical_and_module(text)
    assert canon == "spikenaut-core-sv/rtl"
    assert modules == ["LifNeuron"]


def test_extract_no_canonical() -> None:
    text = "module Orphan;\nendmodule\n"
    canon, modules = dg.extract_canonical_and_module(text)
    assert canon is None
    assert modules == ["Orphan"]


def test_generate_radar_all_clear(tmp_path: Path) -> None:
    radar = dg.generate_radar([], [], purity=100, root=tmp_path)
    assert "All clear" in radar
    assert "100%" in radar


def test_generate_radar_strict_violation(tmp_path: Path) -> None:
    a = tmp_path / "a.sv"
    b = tmp_path / "b.sv"
    a.write_text("module Dup;\nendmodule\n", encoding="utf-8")
    b.write_text("module Dup;\nendmodule\n", encoding="utf-8")
    radar = dg.generate_radar(
        [("Dup", [a, b])],
        [],
        purity=80,
        root=tmp_path,
    )
    assert "Strict Duplicates" in radar
    assert "Dup" in radar


def test_analyze_repository_on_real_tree() -> None:
    """Smoke: run against the monorepo checkout (canonical tree should be clean)."""
    root = Path(__file__).resolve().parents[1]
    sv_files = dg.find_sv_files(root)
    assert sv_files, "expected SystemVerilog files under monorepo roots"
    strict, _near, purity = dg.analyze_repository(sv_files, root, threshold=0.85)
    assert strict == [], f"strict violations on clean tree: {strict}"
    assert purity >= 80
