<!-- Software Package Data Exchange (SPDX) License-Identifier: MIT OR Apache-2.0 -->
<!-- Last updated: 2026-07-21 -->
# Architecture notes

- **Compile order matters** and is fixed by dependency direction: `lib_bridge` → `lib_core` →
  `lib_soc` / `lib_synapse`. `spikenaut-soc-sv/rtl` and `synapse-link-hdl/examples/basys3` should
  only *instantiate* core/bridge modules and should not contain their own copies. If a SoC- or
  demo-only wrapper needs new logic, give it a distinct module name rather than cloning a
  core/bridge implementation.
- The two `Basys3_Top.sv` files (SoC vs. synapse demo) are deliberately separate top-level
  integrations with different module names (`spikenaut_soc_basys3_top` vs
  `synapse_demo_basys3_top`); this is not a duplicate the Guardian should flag as long as the
  module names stay distinct.
- Testbenches drive/sample stimulus on `negedge clk` to stay clear of the designs under test
  (DUTs') `posedge`-triggered `always_ff` blocks — follow the same convention in new testbenches.
- Universal asynchronous receiver/transmitter (UART) default `DATA_WIDTH` is 8 (matches the wire
  protocol); this parameter is intentionally propagated through `UartRx`/`UartTx`/`SiliconBridge`
  even though the protocol is fixed at 8-bit framing.
- Licensing: dual MIT/Apache-2.0. Every source file (`.sv`, `.tcl`, `.xdc`, docs) carries a
  Software Package Data Exchange (SPDX) header `SPDX-License-Identifier: MIT OR Apache-2.0` —
  include it on any new file.

## Issue tracking

This project uses **bd (beads)** for issue tracking — see the beads section in the root guidance
already loaded into your context (run `bd prime` if you need the full command reference). Do not
use TodoWrite or markdown TODO lists in this repo.

`bd` is the source of truth for issue tracking in this repo; Linear and GitHub Issues are used for
cross-team visibility — use Linear for Limen-Neural team issues, and GitHub Issues under
Limen-Neural/silicon-hdl.
