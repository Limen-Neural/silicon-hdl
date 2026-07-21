<!-- Software Package Data Exchange (SPDX) License-Identifier: MIT OR Apache-2.0 -->
<!-- Last updated: 2026-07-21 -->
# Build and test

No Vivado license is assumed locally. Prefer Verilator for iteration; reserve Vivado for
synthesis and bitstream generation.

## Verilator (core unit testbenches)

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

## Vivado (when available)

```bash
vivado -mode batch -source scripts/build_soc.tcl   # synth + implement + write bitstream for Basys 3
vivado -mode batch -source scripts/sim_core.tcl     # all core unit testbenches
```

`build_soc.tcl` hardcodes its register-transfer-level (RTL) source-file lists so library ownership
stays explicit — when adding a new RTL file, add it to the relevant `read_verilog -sv` list.
`sim_core.tcl` hardcodes RTL lists the same way but discovers testbench files under
`spikenaut-core-sv/tb` via glob; new testbenches are picked up automatically, but their top module
still needs to be added to `core_tb_tops` to actually run.

## Deduplication check

Run before committing any RTL change:

```bash
python scripts/dedup_guardian.py            # exits non-zero on strict duplicate violations
python scripts/dedup_guardian.py --radar radar.md --threshold 0.85   # near-dup "Dupe Radar" report
```
