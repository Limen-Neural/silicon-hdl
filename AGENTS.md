<!-- Software Package Data Exchange (SPDX) License-Identifier: Massachusetts Institute of Technology (MIT) OR Apache-2.0 -->
<!-- Last updated: 2026-07-21 -->
# AGENTS.md

Companion agent guidance for `silicon-hdl`. Entry identity and boundaries are in `CLAUDE.md`.

## Build and test

No Vivado license is assumed locally. Prefer Verilator for iteration; reserve Vivado for
synthesis and bitstream generation.

### Verilator (core unit testbenches)

Pattern used by CI in `.github/workflows/sim.yml`:

```bash
verilator --binary --timing -Wno-WIDTHEXPAND -Wno-DECLFILENAME -Wno-TIMESCALEMOD \
  --top-module tb_LifNeuron \
  -Ispikenaut-core-sv/rtl \
  spikenaut-core-sv/rtl/LifNeuron.sv \
  spikenaut-core-sv/tb/tb_LifNeuron.sv
./obj_dir/Vtb_LifNeuron
```

To run another core unit testbench, replace the top module name and both source paths with one
of the pairs below. Prefer removing `obj_dir` first (`rm -rf obj_dir`) so different tops do not
share build artifacts; if you keep a shared `obj_dir`, re-run from a clean directory when
symbols or tops conflict.

| Top module | Design under test (DUT) / testbench sources |
|---|---|
| `tb_LifNeuron` | `spikenaut-core-sv/rtl/LifNeuron.sv` + `spikenaut-core-sv/tb/tb_LifNeuron.sv` |
| `tb_WeightRam` | `spikenaut-core-sv/rtl/WeightRam.sv` + `spikenaut-core-sv/tb/tb_WeightRam.sv` |
| `tb_NeuronParamRam` | `spikenaut-core-sv/rtl/NeuronParamRam.sv` + `spikenaut-core-sv/tb/tb_NeuronParamRam.sv` |
| `tb_StdpController` | `spikenaut-core-sv/rtl/StdpController.sv` + `spikenaut-core-sv/tb/tb_StdpController.sv` |

Testbenches call `$fatal` on failure and are self-checking (look for an `errors` counter and
`$display` summary at the end).

### Vivado (when available)

```bash
vivado -mode batch -source scripts/build_soc.tcl   # synth + implement + write bitstream for Basys 3
vivado -mode batch -source scripts/sim_core.tcl     # all core unit testbenches
```

`build_soc.tcl` hardcodes its register-transfer-level (RTL) source-file lists so library ownership
stays explicit — when adding a new RTL file, add it to the relevant `read_verilog -sv` list.
`sim_core.tcl` hardcodes RTL lists the same way but discovers testbench files under
`spikenaut-core-sv/tb` via glob; new testbenches are picked up automatically, but their top module
still needs to be added to `core_tb_tops` to actually run.

### Deduplication check

Run before committing any RTL change:

```bash
python scripts/dedup_guardian.py            # exits non-zero on strict duplicate violations
python scripts/dedup_guardian.py --radar radar.md --threshold 0.85   # near-dup "Dupe Radar" report
```

## Architecture notes

- **Compile order matters** and is fixed by dependency direction: `lib_bridge` → `lib_core` →
  `lib_soc` / `lib_synapse`.
- `spikenaut-soc-sv/rtl` and `synapse-link-hdl/examples/basys3` should only *instantiate*
  core/bridge modules and should not contain their own copies.
- If a SoC- or demo-only wrapper needs new logic, give it a distinct module name rather than
  cloning a core/bridge implementation.
- The two `Basys3_Top.sv` files (SoC vs. synapse demo) are deliberately separate top-level
  integrations with different module names (`spikenaut_soc_basys3_top` vs
  `synapse_demo_basys3_top`); this is not a duplicate the Guardian should flag as long as the
  module names stay distinct.
- Testbenches drive/sample stimulus on `negedge clk` to stay clear of the designs under test
  (DUTs') `posedge`-triggered `always_ff` blocks — follow the same convention in new testbenches.
- Universal asynchronous receiver/transmitter (UART) default `DATA_WIDTH` is 8 (matches the wire
  protocol); this parameter is intentionally propagated through `UartRx`/`UartTx`/`SiliconBridge`
  even though the protocol is fixed at 8-bit framing.
- Licensing: dual Massachusetts Institute of Technology (MIT) / Apache-2.0. Every source file
  (`.sv`, `.tcl`, `.xdc`, docs) carries a Software Package Data Exchange (SPDX) header
  `SPDX-License-Identifier: MIT OR Apache-2.0` — include it on any new file.

## Issue tracking

This project uses **bd (beads)** for issue tracking — see the beads section in the root guidance
already loaded into your context (run `bd prime` if you need the full command reference). Do not
use TodoWrite or markdown TODO lists in this repo.

`bd` is the source of truth for issue tracking in this repo; Linear and GitHub Issues are used for
cross-team visibility — use Linear for Limen-Neural team issues, and GitHub Issues under
Limen-Neural/silicon-hdl.
