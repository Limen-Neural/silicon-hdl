<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# silicon-hdl

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](#license)

Deduplicated, Vivado-ready monorepo for neuromorphic / spiking neural network FPGA
primitives, targeting Digilent Basys 3 (Artix-7).

## About this repo (learning field)

I am **still early on the HDL / SystemVerilog curve** — far from expert. This
repository is my **practice ground**: real RTL, Verilator CI, optional Vivado and
Basys 3 bring-up, and experimental SNN demos (weights via `$readmemh`, multi-neuron
scale later). I rely **heavily on AI coding agents** (and review bots) to design,
debug, and keep the tree consistent (dedup guardian, free CI). Treat PRs and docs as
student-lab work in public, not as production-grade silicon or a finished product.

If you fork or review: expect sharp edges, questions in issues, and iterative
learning. Corrections and teaching-oriented reviews are welcome.

## Repository layout

```
silicon-hdl/
├── spikenaut-core-sv/         # lib_core  – canonical SNN logic
│   ├── rtl/                   #   LifNeuron, WeightRam, NeuronParamRam, StdpController
│   ├── tb/                    #   Unit testbenches
│   └── doc/
├── spikenaut-soc-sv/          # lib_soc  – SoC wrappers only
│   ├── rtl/                   #   spikenaut_soc_basys3_top (Basys3_Top.sv)
│   ├── tb/                    #   Integration testbenches
│   └── ip/                    #   Xilinx IP blocks
├── spikenaut-bridge-sv/       # lib_bridge  – communication primitives
│   ├── rtl/                   #   UartRx, UartTx, SiliconBridge
│   └── tb/
├── synapse-link-hdl/          # lib_synapse  – AER routing + demo
│   ├── src/                   #   SynapseRouter
│   └── examples/
│       └── basys3/            #   synapse_demo_basys3_top (Basys3_Top.sv)
├── constraints/
│   ├── basys3.xdc
│   └── artix7_trainer.xdc
└── scripts/
    ├── build_soc.tcl          # Vivado build: SoC for Basys 3
    └── sim_core.tcl           # Vivado sim: core unit tests
```

## Module ownership (no duplicates)

| Module | Canonical location |
|---|---|
| `LifNeuron` | `spikenaut-core-sv/rtl/LifNeuron.sv` |
| `WeightRam` | `spikenaut-core-sv/rtl/WeightRam.sv` |
| `NeuronParamRam` | `spikenaut-core-sv/rtl/NeuronParamRam.sv` |
| `StdpController` | `spikenaut-core-sv/rtl/StdpController.sv` |
| `UartRx` | `spikenaut-bridge-sv/rtl/UartRx.sv` |
| `UartTx` | `spikenaut-bridge-sv/rtl/UartTx.sv` |
| `SiliconBridge` | `spikenaut-bridge-sv/rtl/SiliconBridge.sv` |
| `SynapseRouter` | `synapse-link-hdl/src/SynapseRouter.sv` |
| `spikenaut_soc_basys3_top` | `spikenaut-soc-sv/rtl/Basys3_Top.sv` |
| `synapse_demo_basys3_top` | `synapse-link-hdl/examples/basys3/Basys3_Top.sv` |

> **Note:** `spikenaut-soc-sv/rtl` does **not** contain copies of core or bridge modules.
> All build scripts source `LifNeuron`, `WeightRam`, `NeuronParamRam`, and `StdpController`
> exclusively from `spikenaut-core-sv/rtl`.

## Vivado build

```tcl
# Synthesize + implement the SoC and generate a bitstream
vivado -mode batch -source scripts/build_soc.tcl

# Run core unit-level simulation
vivado -mode batch -source scripts/sim_core.tcl
```

## Deduplication verification

The manual greps below are enforced automatically by the **Deduplication Guardian**
(`.github/workflows/dedup-guardian.yml` + `scripts/dedup_guardian.py` — see issue #5).

Run locally for the full "Dupe Radar" + Purity Score:

```bash
python scripts/dedup_guardian.py
```

```bash
grep -R "module LifNeuron"       . --include="*.sv"  # expect 1 hit
grep -R "module WeightRam"       . --include="*.sv"  # expect 1 hit
grep -R "module NeuronParamRam"  . --include="*.sv"  # expect 1 hit
grep -R "module StdpController"  . --include="*.sv"  # expect 1 hit
grep -R "module UartRx"          . --include="*.sv"  # expect 1 hit
grep -R "module UartTx"          . --include="*.sv"  # expect 1 hit
grep -R "module SiliconBridge"   . --include="*.sv"  # expect 1 hit
grep -R "module Basys3_Top"      . --include="*.sv"  # expect 0 hits (renamed)
grep -R "module spikenaut_soc_basys3_top"  . --include="*.sv"  # expect 1 hit
grep -R "module synapse_demo_basys3_top"   . --include="*.sv"  # expect 1 hit
```

## License

Licensed under either of

* Apache License, Version 2.0
  ([LICENSE-APACHE-2.0](LICENSE-APACHE-2.0) or <http://www.apache.org/licenses/LICENSE-2.0>)
* MIT license
  ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.
