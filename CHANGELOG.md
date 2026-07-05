<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# Changelog

All notable changes to silicon-hdl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Dual MIT / Apache-2.0 licensing for maximum adoption in research and commercial hardware (addresses #6).
  - `LICENSE-MIT` and `LICENSE-APACHE-2.0` added at repository root.
  - SPDX-License-Identifier headers (`MIT OR Apache-2.0`) added to all `.sv`, `.tcl`, `.xdc`, and documentation sources.
  - README updated with license badge and standard dual-license section.
  - CHANGELOG introduced.

- Verilator CI for core RTL unit testbenches on GitHub-hosted runners (addresses #9).
  - `.github/workflows/sim.yml` created; runs `tb_LifNeuron`, `tb_WeightRam`, and `tb_NeuronParamRam` via Verilator on every `push` and `pull_request`.
  - Uses explicit steps for the three testbenches; `rm -rf obj_dir` isolation + exact flags from issue notes (validated locally and matches PR #11 `$fatal` hardening).
  - Free CI (no Vivado license). Out-of-scope items tracked in #12 and #13.

### Changed

- No behavioral or interface changes to RTL or modules.

See also the org master tracker: <https://github.com/Limen-Neural/neuromod/issues/19>
