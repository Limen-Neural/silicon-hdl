# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`silicon-hdl` is a deduplicated, Vivado-ready SystemVerilog monorepo for neuromorphic / spiking neural
network (SNN) FPGA primitives, targeting Basys 3 (Artix-7, `xc7a35tcpg236-1`). It's organized as four
independent libraries with a strict single-source-of-truth rule: no module is ever defined in more than
one place.

| Library | Path | Contents |
|---|---|---|
| `lib_core` | `spikenaut-core-sv/rtl` | `LifNeuron`, `WeightRam`, `NeuronParamRam`, `StdpController` — canonical SNN logic |
| `lib_bridge` | `spikenaut-bridge-sv/rtl` | `UartRx`, `UartTx`, `SiliconBridge` — host communication |
| `lib_soc` | `spikenaut-soc-sv/rtl` | `Basys3_Top.sv` (top: `spikenaut_soc_basys3_top`) — SoC wrapper only, no copies of core/bridge modules |
| `lib_synapse` | `synapse-link-hdl/src` | `SynapseRouter` — AER routing, plus `examples/basys3/Basys3_Top.sv` (top: `synapse_demo_basys3_top`) |

Each `.sv` file in the four libraries starts with a header comment declaring its canonical source, e.g.:

```systemverilog
// SPDX-License-Identifier: MIT OR Apache-2.0
// LifNeuron.sv
// Canonical source: spikenaut-core-sv/rtl
```

The **Deduplication Guardian** (`scripts/dedup_guardian.py`, enforced in CI via
`.github/workflows/dedup-guardian.yml`) parses these headers and fails any PR that introduces a second
`module Name` definition for a registered module, or a near-duplicate implementation file. Never copy an
RTL module between directories — instead have the new location instantiate/import the canonical one, or
if genuinely new logic is needed, give it a new module name.

## Build & test

No Vivado license is assumed to be available locally; use Verilator for fast iteration and reserve Vivado
scripts for final synthesis/bitstream generation.

**Run a single core testbench with Verilator** (the pattern CI uses in `.github/workflows/sim.yml`):

```bash
verilator --binary --timing -Wno-WIDTHEXPAND -Wno-DECLFILENAME -Wno-TIMESCALEMOD \
  --top-module tb_LifNeuron \
  -Ispikenaut-core-sv/rtl \
  spikenaut-core-sv/rtl/LifNeuron.sv \
  spikenaut-core-sv/tb/tb_LifNeuron.sv
./obj_dir/Vtb_LifNeuron
```

Swap `tb_LifNeuron` / `LifNeuron.sv` for `tb_WeightRam`/`WeightRam.sv`, `tb_NeuronParamRam`/`NeuronParamRam.sv`,
or `tb_StdpController`/`StdpController.sv` as needed. Run `rm -rf obj_dir` between testbenches (different
top modules in the same `obj_dir` will conflict). Testbenches call `$fatal` on failure and are self-checking
(look for an `errors` counter and `$display` summary at the end).

**Vivado (when available):**

```bash
vivado -mode batch -source scripts/build_soc.tcl   # synth + implement + write bitstream for Basys 3
vivado -mode batch -source scripts/sim_core.tcl     # runs all core unit testbenches (tb_LifNeuron, tb_WeightRam, tb_NeuronParamRam, tb_StdpController)
```

Both scripts hardcode their source-file lists (no globbing beyond constraints) so that library ownership
stays explicit — when adding a new RTL or testbench file, add it to the relevant `read_verilog -sv` list.

**Deduplication check** — run before committing any RTL change:

```bash
python scripts/dedup_guardian.py            # exits non-zero on strict duplicate violations
python scripts/dedup_guardian.py --radar radar.md --threshold 0.85   # also writes near-dup "Dupe Radar" report
```

## Architecture notes

- **Compile order matters** and is fixed by dependency direction: `lib_bridge` → `lib_core` → `lib_soc` /
  `lib_synapse`. `spikenaut-soc-sv/rtl` and `synapse-link-hdl/examples/basys3` only ever *instantiate*
  core/bridge modules — they must never contain their own copies.
- The two `Basys3_Top.sv` files (SoC vs. synapse demo) are deliberately separate top-level integrations
  with different module names (`spikenaut_soc_basys3_top` vs `synapse_demo_basys3_top`); this is not a
  duplicate the Guardian should flag as long as the module names stay distinct.
- Testbenches drive/sample stimulus on `negedge clk` to stay clear of the DUTs' `posedge`-triggered
  `always_ff` blocks — follow the same convention in new testbenches.
- UART default `DATA_WIDTH` is 8 (matches the wire protocol); this parameter is intentionally propagated
  through `UartRx`/`UartTx`/`SiliconBridge` even though the protocol is fixed at 8-bit framing (see
  `docs/pr-response-checklist.md` for the review history behind this).
- Licensing: dual MIT/Apache-2.0. Every source file (`.sv`, `.tcl`, `.xdc`, docs) carries an
  `SPDX-License-Identifier: MIT OR Apache-2.0` header — include it on any new file.

## Issue tracking

This project uses **bd (beads)** for issue tracking — see the beads section in the root guidance already
loaded into your context (run `bd prime` if you need the full command reference). Do not use TodoWrite or
markdown TODO lists in this repo.

Linear/GitHub issue tracking preferred under Limen-Neural teams for Linear.    GitHub issue will be under Limen-Neural/silicon-hdl.
