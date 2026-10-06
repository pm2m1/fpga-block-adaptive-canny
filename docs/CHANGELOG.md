# Change log

## Phase 0 — archived streaming import

- `../final project.rar` → `baseline_original/archive/`: copied 11 Verilog modules, four testbenches, input BMP, original `.xpr` and README. No algorithmic change.
- `baseline_original/archive/1.RTL/source/*.v` → `rtl/baseline/*.v`: exact byte copies. Choosing archived `canny_get_grandient.v` restores the comment lost in the extracted tree; no other RTL edit.
- Archived testbenches → `tb/baseline/`: byte copies initially. `tb/baseline/canny_tb.sv` then had only two BMP paths changed for a reproducible workspace-relative Phase 1 run. No algorithmic change.
- `scripts/import_baseline.py`, `scripts/run_baseline_sim.ps1`, and `scripts/run_baseline_sim.tcl` are new workspace-only tooling.

Further phases have not started. A phase is recorded here only when work actually occurs.

## Phase 1 tool discovery (no RTL change)

- Expanded `scripts/run_baseline_sim.ps1` to search C:/D: Xilinx and AMD Vivado version directories and accept `.bat` or `.exe` tools. This changes discovery only, not Canny behavior.
- Added `reports/PHASE1_TOOL_DISCOVERY.md`; full-drive checks found no usable Vivado/XSim binaries. Phase 1 remains FAIL because compile/elaboration/simulation were not run.

## Later verified checkpoints (supersede the historical Phase 1 note above)

- Phase 1, commit `65ef3ef`: Vivado 2026.1 compile/elaboration and two-frame simulation passed. Only the copied testbench gained a valid-pixel monitor; `rtl/baseline` remained unchanged.
- Phase 2, commit `de7c63c`: new Tcl-generated A100T project synthesized the unchanged baseline core. No original RTL edit.
- Phase 3, commit `ab1596c`: new `rtl/phase3/canny_edge_detect_gaussian_top.v` placed the archived `image_gaussian_filter` before the unchanged baseline Canny core. Two-frame equivalence against the old external-Gaussian simulation path passed. No Gaussian arithmetic edit.

## Phase 4 — numeric gradient/CORDIC correction

- `rtl/baseline/canny_get_grandient.v`, `cordic_sqrt.v`, `cordic_pipline.v`, and `canny_nonLocalMaxValue.v` were studied but **not edited**. Their local reference paths are listed in `reports/PHASE4_CORDIC_NUMERIC_AUDIT.md`.
- New `rtl/phase4/cordic_gradient_phase4.v` replaces the old narrow/misaligned vectoring path: 16 consistent stages, signed Q12 coordinates in 26 bits, Q16-degree angle, gain correction, 11-bit saturating magnitude, aligned sign and control, and explicit four-bin direction. This changes gradient numeric behavior intentionally.
- New `rtl/phase4/canny_get_gradient_phase4.v` preserves the baseline Sobel equations and fixed strict `>50` / `>100` threshold comparisons, but uses the corrected CORDIC output and a 17-bit packed gradient path. New `rtl/phase4/canny_nonLocalMaxValue_phase4.v` preserves the baseline strict-neighbor NMS rule while widening magnitude comparisons from 10 to 11 bits.
- New `rtl/phase4/canny_edge_detect_phase4_top.v` reuses the archived Gaussian and archived local one-pass threshold/hysteresis stage. Public grayscale stream ports remain unchanged; no RGB converter is in the synthesis top.
- New software model, directed/random unit test, frame smoke test, Phase 3 regression runner, synthesis Tcl and reports are under `model/`, `tb/phase4/`, `scripts/phase4/`, `results/phase4/`, and `reports/`. No baseline or Phase 3 RTL was changed.

## Phase 8 — shared-front-end block-local adaptive thresholds

- Prior Phase 6 source and all earlier RTL directories are untouched. New `rtl/phase8/canny_gradient_raw_phase8.v` emits 11-bit magnitude and direction before classification; `canny_nms_magnitude_phase8.v` performs the same strict neighbor suppression and emits surviving magnitude. Fixed 50/100 results equal Phase 6 across 614,400 pixels.
- New `histogram_unit_phase8.v` counts nonzero suppressed magnitudes in 32 uniform bins with 11-bit counters; `adaptive_threshold_step_phase8.v` implements the descending 20% high-tail test and 40% low ratio.
- New `stripe_threshold_engine_phase8.v` uses two 32-row stripe buffers, two histogram banks, threshold tables, and raster replay. A registered histogram read separates LUTRAM access from cumulative/threshold arithmetic; this is timing-only and preserves model results. New `canny_block_adaptive_phase8_top.v` chooses frame-atomic fixed or adaptive mode, reusing the prior global Gaussian/Sobel/CORDIC path and global one-pass local promotion.
- Python oracles, directed and full-frame tests, reproducible batch scripts, and A100T reports are in Phase 8 folders. No board pins or bitstream were added.

## Phase 9 — single-engine block-size/bin-count sweep

- New `rtl/phase9/histogram_unit_phase9.v`, `adaptive_threshold_step_phase9.v`, `stripe_threshold_engine_phase9.v`, and `canny_block_adaptive_phase9_top.v` parameterize 32/64 block geometry and 8/16/32 uniform bins. The shared Phase 8 front end and earlier one-pass promotion are unchanged.
- The 64-row variant adds a third stripe bank because two banks collide when the 32-row final stripe is followed by the next frame. It counts only real final-row pixels and replays exactly 307,200 pixels/frame.
- New Python exact-histogram and quality sweep, RTL oracles, direct Phase 8 comparison, histogram stress tests, simulation matrix, analytical schedule check, and reproducible Tcl-based A100T synthesis/route runners are under Phase 9 folders. No board pins, bitstream, recursive hysteresis, or multiple processing engines were added.

## Phase 10 — shared-front-end replicated adaptive engines

- New `rtl/phase10/block_adaptive_engine_phase10.v` is a derivative of the Phase 9 stripe engine with explicit ready/grant control, per-engine two-bank storage, and simulation-observable activity counters. New `canny_block_adaptive_phase10_top.v` retains one shared Gaussian/Sobel/CORDIC/NMS front end and one shared global local-promotion stage, statically assigns stripes modulo 1/2/4 engines, and merges classified stripes in raster order.
- Python schedule/invariance checks, direct Phase 9 side-by-side RTL tests, six normal/isolation simulations, a directed out-of-order-ready test, and Tcl-driven A100T synthesis/routes for all three counts were added. All variants are algorithmically bit-identical on tested frames and route at 100 MHz. The measured adaptive service interval and output-frame cadence do **not** speed up with engine replication. No protected RTL, board pins, bitstream, or recursive hysteresis was changed/added.

## Phase 11 — Nexys A7-100T board-validation build

- Copied the verified Phase 10 E=1 core into `rtl/phase11/core/` and changed 19 asynchronous-reset sensitivity lists to synchronous reset for BRAM-control safety. No original/verified source was edited; the two-frame model regression still matches 614,400 pixels and 600 block thresholds exactly.
- Added the Phase 11 board wrapper: one preinitialized monkey grayscale BRAM, procedural patterns, the verified core, packed output BRAM, cycle counters, LEDs, and USB-UART packetization. Host decoder checks exact byte/pixel count, CRC, and bitwise golden equality. This is validation infrastructure, not a Canny algorithm change.
- Added Digilent-derived Nexys A7-100T pin constraints and configuration-bank settings. Monkey, black, vertical step, and checkerboard wrapper simulations match Python golden outputs exactly; accelerated UART simulation checks a complete 38,426-byte packet.
- Vivado 2026.1 routed the final `rev3` wrapper with +0.436 ns WNS, TNS 0, and zero DRC findings, then generated `results/phase11/canny_nexys_a7.bit`. No JTAG board was detected; physical programming, UART capture, and physical power measurement remain pending. Post-route vectorless power is a low-confidence estimate only.
