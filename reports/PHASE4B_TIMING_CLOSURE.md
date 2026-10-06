# Phase 4B: 100 MHz core timing closure

**Status: PASS (core-only, post-route).** Vivado 2026.1, part `xc7a100tcsg324-1`, top `canny_edge_detect_phase4b_top`, clock `clk` constrained to 10.000 ns by `constraints/phase2_core_timing.xdc`. This is not a pin-constrained board build and no bitstream was generated.

## Original failing path and cause

The pre-edit audit is in `reports/PHASE4B_CRITICAL_PATH_AUDIT.md` and its ten-path Vivado evidence is `reports/phase4b_phase4_top10_timing.rpt`. The worst Phase 4 path starts at `u_gradient/u_cordic/g_stage[15].x_reg_reg[0]/C` and ends at `u_gradient/gra_path_reg[15]/D` (also bit 16), both rising-edge registers on `clk`. It has **-1.189 ns slack**, **11.053 ns data delay** (6.407 ns logic, 4.646 ns estimated routing), 22 logic levels, and 16 CARRY4 cells. The old TNS was -11.624 ns. This is a real synchronous setup path, not an unconstrained I/O or generated-clock path; no false/multicycle exception was added.

The dominant combinational chain was the final CORDIC x coordinate through constant reciprocal-gain multiplication, arithmetic shift/clamp, then threshold-class comparison before the packed gradient register. The CORDIC iteration itself was not the critical path.

## Timing-only change and latency

`rtl/phase4b/cordic_gradient_phase4b.v` retains the Phase 4 16 vectoring iterations, signed 26-bit Q12 coordinates, 48-bit multiplication by the exact `39797` Q16 reciprocal-gain constant, 11-bit saturation, Q16-degree angle comparisons, and four-bin direction mapping. It adds:

1. A register for the exact 48-bit product, angle, zero/quadrant flags and valid/vsync/href.
2. A register for the unchanged shifted/clamped magnitude, direction and matching controls.

The CORDIC block latency is **18 registered stages**, versus **16** in Phase 4; the complete Canny output stream is delayed by exactly **2 clocks**. The corresponding valid/vsync/href and sign/zero paths are delayed together. `rtl/phase4b/canny_get_gradient_phase4b.v` and `rtl/phase4b/canny_edge_detect_phase4b_top.v` only connect the Phase 4B numeric block into a new top; Gaussian, NMS, 50/100 thresholds, and local 3x3 linking are unchanged.

The final CORDIC y coordinate has no consumer after the last iteration. The Phase 4B generate loop omits that last y register instead of relying on synthesis to trim it. This eliminates the Phase 4 `Synth 8-6014` unused-final-y warning; the final synthesis log has no such warning.

## Equivalence gates

| Check | Final Phase 4B result | Evidence |
|---|---:|---|
| Phase 4 bit-accurate model vs Phase 4B RTL | 16,144 valid vectors, 0 mismatches, 0 unknowns | `reports/phase4b_cordic_xsim.log` |
| Phase 4 vs Phase 4B complete frames | 2 frames, 614,400 valid pixels, 0 mismatches, 0 unknowns | `reports/phase4b_frame_xsim.log` |
| Per-frame active pixels | 307,200 each | `reports/phase4b_frame_xsim.log` |
| Observed extra latency | 2 clocks, controls and pixel values aligned | `tb/phase4b/tb_phase4b_equivalence.sv` |

The deterministic Phase 4 vector values were reused unchanged. The Phase 4B vector-preparation script inserts only 20 **invalid** drain cycles before the existing reset so that the longer pipeline can retire all directed vectors; it does not alter any valid input or expected value. The self-checking RTL unit test and two-frame comparator were both rerun after the final-y cleanup. The output BMP is `results/phase4b/outcom_phase4b.bmp`.

## Area and timing

Synthesis utilization is compared like-for-like. Post-route LUTs are reported separately because implementation optimizes packing.

| Metric | Phase 4 | Final Phase 4B | Change |
|---|---:|---:|---:|
| Synthesis LUT | 1,724 | 1,654 | -70 (-4.06%) |
| Synthesis FF | 1,772 | 1,828 | +56 (+3.16%) |
| RAMB18 | 8 | 8 | 0 |
| RAMB36 | 0 | 0 | 0 |
| DSP | 0 | 0 | 0 |
| Synthesis WNS at 10 ns | -1.189 ns | +1.701 ns | +2.890 ns |
| Synthesis TNS | -11.624 ns | 0.000 ns | +11.624 ns |
| Post-route WNS at 10 ns | Not measured | **+0.810 ns** | — |
| Post-route TNS | Not measured | **0.000 ns** | — |

Final placed/routed utilization: 1,631 LUT, 1,828 FF, 8 RAMB18, 0 DSP (`reports/phase4b_run2_postroute_utilization.rpt`). All 2,585 routable nets are fully routed, with 0 routing errors (`reports/phase4b_run2_route_status.rpt`). The routed checkpoint is `results/phase4b/canny_a100t_phase4b_run2_routed.dcp`; the final synthesis checkpoint is `results/phase4b/canny_a100t_phase4b_run2_synth.dcp`. Final timing/utilization reports are `reports/phase4b_run2_timing_summary.rpt`, `reports/phase4b_run2_postroute_timing_summary.rpt`, and `reports/phase4b_run2_utilization.rpt`.

The earlier first timing revision is preserved independently in `reports/phase4b_*.rpt` and `results/phase4b/canny_a100t_phase4b_routed.dcp`; it passed route at +0.600 ns before the final-y cleanup. The final run is the `run2` set above. The first attempt at project creation stopped before synthesis because the script pointed to an incorrect Phase 4B top path; this was corrected in the new project script without editing any protected RTL.

## Warnings and limitations

Final synthesis has **12 warnings**, all the pre-existing `fifo_ram` `wr_full`/`rd_empty` undriven or unused-port warnings across three width variants (`reports/phase4b_run2_synth_impl.log:156-167`). There are no new RTL width, latch, multiple-driver, or final-y warnings. The eight line-buffer RAMs infer as RAMB18.

Post-route DRC retains `NSTD-1` and `UCIO-1` critical warnings because this deliberately has **no board I/O standard or package-pin assignments**; bitstream generation would be inappropriate. `CFGBVS-1` is likewise board-configuration-related. Fifteen `REQP-1840` BRAM asynchronous-control warnings remain from inherited line-buffer logic (`reports/phase4b_run2_postroute_drc.rpt`). None was suppressed or modified in Phase 4B. Input/output delays are not modeled, so this result establishes **100 MHz timing closure for the constrained core synchronous paths only**, not a complete board interface.

No threshold, NMS, Gaussian, CORDIC numerical, local hysteresis, block/tile, or adaptive-processing behavior was changed. No physical hardware was tested.

**Phase 4B changes pipeline timing/implementation only. Numerical and algorithmic behavior remains bit-identical to the verified Phase 4 reference.**

## Reproduction

From the protected workspace in PowerShell:

```powershell
& './scripts/phase4b/run_cordic_unit.ps1'
& './scripts/phase4b/run_frame_equivalence.ps1'
& './scripts/phase4b/run_a100t_synth_impl_run2.ps1'
```

The synthesis/implementation script intentionally refuses to overwrite an existing generated Vivado project. For a fresh rerun, use a new project/output name in a copy of the Tcl script; do not delete the verified run.
