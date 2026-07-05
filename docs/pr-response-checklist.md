<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# PR response checklist for `gh-14` / `5u3.x` bot threads

Use this checklist when replying to the PR review.  It maps each known bot/review
thread that is still anchored in the source to the exact fix location, current
status, and the available verification evidence.

| Bot / source | Comment id | Issue summary | Fix location | Status | Verification |
|---|---:|---|---|---|---|
| Greptile (`gh-14`, `5u3.1`) | `3035928747` | `uart_rx` is asynchronous to `clk`; sampling it directly in `UartRx` risks metastability. | `spikenaut-bridge-sv/rtl/UartRx.sv`: `rx_sync_0` / `rx_sync_1` two-flop synchronizer and all receive state-machine sampling switched to `rx_sync_1`. | Code fix complete. | Local anchor check: grep for gh-14, 5u3. and comment IDs finds the synchronizer note (see verification section). Vivado not available in container. |
| Review thread (`gh-14`, `5u3.2`) | Unknown | Width mismatches around SoC neuron parameter, weight, STDP, and bridge paths. | `spikenaut-soc-sv/rtl/Basys3_Top.sv`: `u_neuron` threshold/leak connections and `u_stdp` `DATA_WIDTH` paths; `synapse-link-hdl/examples/basys3/Basys3_Top.sv`: synapse variant width review note. | Code fix / review complete. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |
| Copilot (`gh-14`, `5u3.4`) | `3035925438` | Synapse demo echoed received bytes with `tx_send` driven from `rx_valid` without respecting `tx_busy`, risking lost bytes during an in-flight transmit. | `synapse-link-hdl/examples/basys3/Basys3_Top.sv`: `tx_hold` / `hold_pending` one-entry transmit hold buffer. | Code fix complete. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |
| Review thread (`gh-14`, `5u3.5`) | Unknown | Basys 3 reset polarity was ambiguous/inverted; XDC also had a stray SystemVerilog remnant. | `spikenaut-soc-sv/rtl/Basys3_Top.sv`: `rst = ~rst_n`; `synapse-link-hdl/examples/basys3/Basys3_Top.sv`: matching reset inversion; `constraints/basys3.xdc`: stray SV code removed. | Code fix complete. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |
| Review thread (`gh-14`, `5u3.6`) | Unknown | RAM outputs needed deterministic reset behavior / documentation of parameter RAM semantics. | `spikenaut-core-sv/rtl/WeightRam.sv`: reset-aware `dout`; `spikenaut-core-sv/rtl/NeuronParamRam.sv`: header clarified that one parameter is stored per address. | Code fix complete for `WeightRam`; documentation-only clarification for `NeuronParamRam`. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |
| Review thread (`gh-14`, `5u3.7`) | Comments `5447`, `8803`, `5441` | UART/bridge `DATA_WIDTH` and unused router `DATA_WIDTH` parameters caused confusing or unused parameterization. | `spikenaut-bridge-sv/rtl/SiliconBridge.sv`, `spikenaut-bridge-sv/rtl/UartRx.sv`, and `spikenaut-bridge-sv/rtl/UartTx.sv`: UART byte-width parameter notes/defaults; `synapse-link-hdl/src/SynapseRouter.sv`: unused `DATA_WIDTH` removed; `spikenaut-core-sv/rtl/NeuronParamRam.sv`: header aligned with implementation. | Code fix complete, with documentation notes where the protocol intentionally remains 8-bit UART. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |
| Greptile (`gh-14` PR#1, `5u3.8`) | `4186983425` | Vivado scripts relied on implicit/dependent source discovery and simulation only covered one top. | `scripts/build_soc.tcl`: explicit bridge/core/SoC source list and canonical ownership notes; `scripts/sim_core.tcl`: enumerates all core testbench tops and re-elaborates each run. | Code fix complete. | Local anchor check: grep for gh-14/5u3. and IDs finds the notes (see verification). Vivado not available. |

## Local verification captured while preparing this checklist

```text
$ grep -r "gh-14\|5u3\.\|3035928747\|4186983425" . --include="*.sv" --include="*.md" | head -5
# Found anchors in UartRx, SiliconBridge, UartTx, NeuronParamRam, WeightRam,
# SynapseRouter, both Basys3_Top variants, constraints/basys3.xdc,
# scripts/build_soc.tcl, and scripts/sim_core.tcl.

$ command -v vivado || true
# No output: Vivado is not installed in this container, so local Vivado synth/sim
# output cannot be captured here. Use CI or a Vivado host for:
#   vivado -mode batch -source scripts/build_soc.tcl
#   vivado -mode batch -source scripts/sim_core.tcl
```
