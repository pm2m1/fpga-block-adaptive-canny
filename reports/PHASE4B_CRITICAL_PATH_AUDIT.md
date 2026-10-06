# Phase 4B pre-edit critical-path audit

This was recorded **before Phase 4B RTL edits**. The working tree started clean at Git `97305fd`; `rtl/baseline`, `rtl/phase3`, and `rtl/phase4` are protected. `scripts/phase4b/run_path_audit.ps1` opened the saved Phase 4 synthesized checkpoint read-only and generated `reports/phase4b_phase4_top10_timing.rpt`. Vivado reported the exact part `xc7a100tcsg324-1` and clock period `10.000 ns` (`reports/phase4b_path_audit.log`). The prior timing summary has WNS `−1.189 ns`, TNS `−11.624 ns`, 17 failing endpoints (`reports/phase4_timing_summary.rpt:139-165,215`).

All ten worst setup paths start at `u_gradient/u_cordic/g_stage[15].x_reg_reg[0]/C`, a rising-edge FF on `clk`, and end at a rising-edge `u_gradient/gra_path_reg[*]/D` FF on the **same** `clk` (`reports/phase4b_phase4_top10_timing.rpt:15-1027`). These are real synchronous setup paths, not input/output-delay artifacts or generated-clock crossings. The only clock is the explicit 10 ns `clk` from `constraints/phase2_core_timing.xdc`; no false/multicycle exception is appropriate. The report's unconstrained I/O entries reflect intentionally absent board-level delays and do not explain this register-to-register failure.

| Rank | Endpoint `gra_path_reg` bit | Slack ns | Data delay ns | Logic ns | Estimated route ns | Levels | Dominant cells/operators |
|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 15 | −1.189 | 11.053 | 6.407 | 4.646 | 22 | 16 CARRY4 plus LUTs: gain multiply → magnitude/clamp → threshold class |
| 2 | 16 | −1.189 | 11.053 | 6.407 | 4.646 | 22 | Same path into strong/weak class |
| 3 | 0 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Gain multiply → output magnitude |
| 4 | 10 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Gain multiply → output magnitude |
| 5 | 11 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Gain multiply → packed direction/class logic |
| 6 | 12 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Same arithmetic fanout |
| 7 | 13 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Same arithmetic fanout |
| 8 | 14 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Same arithmetic fanout |
| 9 | 1 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Gain multiply → output magnitude |
| 10 | 2 | −0.616 | 10.480 | 6.283 | 4.197 | 21 | Gain multiply → output magnitude |

The common source and cell trail show the root cause: `rtl/phase4/cordic_gradient_phase4.v` performs a 26-bit coordinate × Q16 reciprocal-gain constant and arithmetic shift, then clamp/direction output, and `rtl/phase4/canny_get_gradient_phase4.v` immediately compares magnitude to `>50`/`>100` and registers packed class/magnitude. The worst path includes the `scaled__*` carry chains and ends in class bits (`phase4b_phase4_top10_timing.rpt:45-123`). **Individual CORDIC shift/add iterations, Gaussian, Sobel partial sums, NMS, line buffers, and final local hysteresis are not among the ten worst paths.** The first timing optimization should therefore register the post-CORDIC gain computation and/or its result, with matched delay for angle, sign and controls. It must not change Q12/Q16 arithmetic, constants, thresholds, directions, image algorithm, or timing constraints. Any new latency must be verified against the exact Phase 4 numerical model and two-frame output stream.
