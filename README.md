# silicon-hdl

Deduplicated, Vivado-ready monorepo for neuromorphic / spiking neural network FPGA primitives.

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