# Phase 4 CORDIC/gradient numeric correction

**Functional/numeric verification: PASS. A100T synthesis: PASS. Preliminary 100 MHz synthesis timing: FAIL (WNS −1.189 ns).** No place/route, bitstream, board run, power estimate, adaptive threshold, or block processing was performed. Earlier `rtl/baseline/` and `rtl/phase3/` files remain unchanged. The pre-edit failure analysis is in `reports/PHASE4_CORDIC_NUMERIC_AUDIT.md`.

## Numeric design

For 8-bit standard Sobel, each weighted side is at most `255+2×255+255=1020`, so `|Gx|≤1020`, `|Gy|≤1020`, and ideal magnitude `≤sqrt(2)×1020=1442.497833...`; 11 unsigned output bits are required. `rtl/phase4/canny_get_gradient_phase4.v` retains the baseline left-minus-right and top-minus-bottom Sobel equations, but sends 11-bit absolute values and aligned signs to `rtl/phase4/cordic_gradient_phase4.v`. The latter has **16 vectoring iterations**, **signed 26-bit Q12 x/y coordinates**, **signed 24-bit degree-Q16 angle**, and reciprocal gain **39797/65536** (rounded). The maximum gain-scaled coordinate is below `2376×4096=9,732,096`, versus signed-26 positive limit 33,554,431. A 48-bit signed product carries the gain compensation; the 11-bit output saturates rather than wraps. The 16 nonzero rounded atan-Q16 constants are in `cordic_gradient_phase4.v:34-56` and match `model/cordic_reference.py:22-26`.

The CORDIC has **16 registered stages**: input sampled at edge *n* produces aligned magnitude, angle-derived direction, sign, `vsync`, `href`, and valid after edge *n+15* (16th sampling edge; 15 complete clock periods between edges). Sobel partial sums and absolute/sign values add two stages after the matrix generator; the Phase 4 threshold/class output adds one stage after CORDIC (`canny_get_gradient_phase4.v`). Input-valid bubbles and resets are shifted through the same 16-stage CORDIC pipeline. The packed gradient is exactly `[16:15]` threshold class (`10` strong, `01` weak, `00` below low), `[14:11]` one-hot NMS orientation, `[10:0]` magnitude. Strict fixed comparisons `>100` and `>50` are unchanged; no runtime/adaptive thresholds were introduced. `canny_nonLocalMaxValue_phase4.v` retains the original strict greater-than neighbor comparisons, widened to 11-bit magnitude. The unchanged `canny_doubleThreshold` still performs only one 3×3 strong-neighbor promotion, not full connected hysteresis.

NMS codes are `0001` horizontal (left/right), `0010` `/` (top-right/bottom-left), `0100` vertical (top/bottom), `1000` `\` (top-left/bottom-right). Because this RTL's Sobel signs both point toward left/top, equal nonzero signs correspond to `\` in image coordinates, opposite signs to `/`. The fixed model uses 22.5° and 67.5° first-quadrant boundaries with sign parity for the diagonal class; angle and sign travel through matching pipeline stages.

## Verification

| Test | Result | Evidence |
|---|---|---|
| Exhaustive first-quadrant software sweep | **PASS**, 1,042,441 pairs `(Gx,Gy)∈[0,1020]²` | `reports/phase4_cordic_software_metrics.txt`; `model/cordic_reference.py` |
| RTL CORDIC/model unit test | **PASS**, 16,137 valid output vectors, 0 mismatches, 0 unknown outputs | `reports/phase4_cordic_xsim.log:15` |
| Phase 4 frame smoke | **PASS**, two 640×480 output frames, each 307,200 valid pixels, 0 unknowns | `reports/phase4_frame_xsim.log:15-16` |
| Phase 3 unchanged regression | **PASS**, two frames, 614,400 matching pixels, 0 mismatches | `reports/phase4_phase3_regression_xsim.log:15-16` |

The software fixed-point model exactly matches the intended RTL recurrence, widths, arithmetic shifts, gain scaling, saturation and direction mapping. Its independent ideal reference uses `math.hypot` and `atan2`, not the CORDIC recurrence. Exhaustive metrics: output magnitude **0..1442**, maximum absolute error **1.000000**, mean absolute error **0.480821950**, RMS error **0.562529810**, internal overflow **0**, output clamp **0**, wraparound **0**, and monotonicity decreases with increasing Gx or Gy **0**. Ideal-direction disagreements: **4 of 1,042,441** first-quadrant pairs, all within **0.000103869°** of a 22.5°/67.5° boundary; there were no disagreements outside that narrow boundary region in the sweep. The RTL unit test covers all four sign combinations through directed axes/diagonals/asymmetric and boundary-adjacent inputs, fixed-seed random vectors, back-to-back valid cycles, valid bubbles, idle reset, and post-reset vectors. Of 16,144 generated valid rows, seven were deliberately flushed by the mid-test reset, leaving 16,137 compared outputs. The unit test checks aligned valid, vsync, href, magnitude and one-hot direction for every compared vector.

The frame test uses the existing `monkey.bmp` source, one RGB→Y conversion **only in the testbench**, one Gaussian in the synthesis core, and the corrected numeric path. It counts pixels only on rising clock edges with `output_href && output_clken`. Frame 0: 307,200 valid / 0 unknown / **50,724 edge** pixels. Frame 1: 307,200 valid / 0 unknown / **51,611 edge** pixels. Both contain edge and non-edge pixels; `results/phase4/outcom_phase4.bmp` was generated. Pixel identity with Phase 3 is not expected because this phase intentionally changes magnitude and direction math. The Phase 3 regression reused its original PRJ/testbench/run Tcl unchanged but wrote separate Phase 4-named logs, preserving the earlier reports.

## A100T synthesis and timing

Vivado 2026.1 synthesized `canny_edge_detect_phase4_top` for exactly `xc7a100tcsg324-1` with the same 10.000 ns core-only clock constraint; `reports/phase4_synth.log` verifies part, top, and run completion. No RGB converter was added to the synthesis source set. The 17-bit NMS line buffer still maps to two RAMB18s, so BRAM count is unchanged. `reports/phase4_utilization_hierarchical.rpt` shows the Gaussian, corrected gradient/CORDIC, widened NMS and unchanged local-threshold stage reachable.

| Synthesized result | Phase 3 | Phase 4 | Delta |
|---|---:|---:|---:|
| LUT | 760 | **1,724** | +964 |
| FF | 985 | **1,772** | +787 |
| RAMB18 | 8 | **8** | 0 |
| RAMB36 | 0 | **0** | 0 |
| DSP | 1 | **0** | −1 |
| WNS at 10 ns | +2.738 ns | **−1.189 ns** | −3.927 ns |

Sources: `reports/phase3_utilization.rpt:34,39,79,91`; `reports/phase4_utilization.rpt:34,39,79,91`; timing summaries at lines 141/215. Phase 4 synthesis has **17 failing setup endpoints**, TNS **−11.624 ns** (`reports/phase4_timing_summary.rpt:139-165,215`). The worst path is from the final CORDIC x register through combinational gain compensation and threshold logic into `gra_path_reg[15]` (`phase4_timing_summary.rpt:223-280`). Thus the 100 MHz target is **not met even at preliminary synthesis timing**. This does not invalidate the numeric/simulation or synthesis pass, but Phase 4 must **not** be claimed to run at 100 MHz. A future in-scope timing optimization would pipeline gain compensation and reverify all latency/control checks; none was attempted here because the requested phase gate requires synthesis, not final timing closure. No routed Fmax is claimed.

## Warning classification

- **Eliminated CORDIC warnings:** the Phase 3 `sqrt_out` 16-vs-22-bit port mismatch, sixteen unsized `pipline_level` elaboration warnings, 19 synthesis parameter-to-localparam warnings, and one old CORDIC equal-priority set/reset warning. Phase 4 standalone and frame XELAB logs have no warnings; no suppression rules were used.
- **Remaining pre-existing synthesis warnings:** twelve FIFO status-port messages (six undriven `wr_full`/`rd_empty`, six unconnected/unloaded) from unchanged `rtl/baseline/fifo_ram.v:10,14` and its parameterized variants. They do not participate in the line-buffer datapath but should be cleaned in a later phase.
- **One new explained synthesis warning:** Vivado removes the final CORDIC `y` register (`g_stage[15].y_reg_reg`) because the output consumes final `x` and angle but not final `y` (`reports/phase4_synth_runme.log:106`). This is expected dead-result trimming, not an undriven control, latch, loop, or multiple driver. Total synthesis warnings: **13**, 0 errors (`phase4_synth_runme.log:416`).
- **DRC:** 9 findings: two expected missing board-I/O critical warnings (`NSTD-1`, `UCIO-1`), one configuration-voltage warning, and six existing/additional RAMB18 asynchronous-control checks (`reports/phase4_drc.rpt:27-35`). No severity was suppressed. The project is not bitstream-ready.

Files and commands are under `scripts/phase4/`; run the software sweep with `C:\Program Files\Python312\python.exe model/cordic_reference.py --sweep --vectors`, the unit test with `scripts/phase4/run_cordic_unit.ps1`, frame test with `scripts/phase4/run_frame_smoke.ps1`, Phase 3 regression with `scripts/phase4/run_phase3_regression.ps1`, and synthesis with `scripts/phase4/run_a100t_synth.ps1`. Full Phase 4 logs and utilization/timing/DRC reports are in `reports/`. The synthesis checkpoint is `results/phase4/canny_a100t_cordic_fixed_synth.dcp`; the generated Vivado project/cache is ignored by Git and reproducible from Tcl.

**Conclusion:** Phase 4 corrects and verifies the CORDIC gradient numeric path and preserves prior checkpoint behavior. It establishes A100T synthesis feasibility but **not** 100 MHz timing closure, board operation, real-time throughput, power, full hysteresis, or algorithm-wide golden-model equivalence. Stop here pending user approval for any further phase or timing work.
