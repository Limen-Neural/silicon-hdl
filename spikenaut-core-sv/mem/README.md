<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# FPGA parameter / weight images (Q8.8)

Hex `.mem` files for `$readmemh` into `WeightRam` / `NeuronParamRam`.

**Active profile: `merged_v2`** (Spikenaut-SNN best-of 16-neuron export).

| File | Lines | Source (vault) | Meaning |
|---|---|---|---|
| `merged_v2_thresholds.mem` | 16 | `dataset/merged_v2/parameters.mem` | Neuron thresholds |
| `merged_v2_decay.mem` | 16 | `dataset/merged_v2/parameters_decay.mem` | Leak / decay rates |
| `merged_v2_weights.mem` | 256 | `dataset/merged_v2/parameters_weights.mem` | 16×16 hidden weights |
| `merged_v2_output_weights.mem` | 48 | `dataset/merged_v2/parameters_output_weights.mem` | Output layer (signed Q8.8) |

**Format:** one 16-bit Q8.8 hex word per line  
(`0120` = 288/256 = 1.125; `FFF9` = signed −7/256 ≈ −0.027).  
Leading `// SPDX-...` comment lines are allowed (`$readmemh` skips `//` comments).

**RTL default:** `INIT_FILE = "NONE"` (not `""`) so Vivado synthesis accepts the parameter
(UG901 null-string rule). Pass a real path only when loading.

**Canonical vault path:** `~/Spikenaut-Vault/Spikenaut-SNN/dataset/merged_v2/`  
(also HF `rmems/Spikenaut-SNN`). Re-copy from vault after retrain; do not invent hex by hand.

**Not used here:** `v1_fpga` (8-neuron toy), per-asset `*_v2` clones — use only when a profile switch (E9) is implemented.

Paths passed to `INIT_FILE` are relative to the tool working directory (repo root in CI and recommended Vivado batch).

**Depth:** `$readmemh` loads `min(file lines, 2**ADDR_WIDTH)` words. Match width to the image, e.g. `WeightRam` with `merged_v2_weights.mem` (256 lines) should use `ADDR_WIDTH=8` (not the default 10). Thresholds/decay (16 lines) fit `NeuronParamRam` default `ADDR_WIDTH=8` with room to spare.
