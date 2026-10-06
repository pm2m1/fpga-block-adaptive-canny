# Phase 5B — deterministic frame-border correction

**Status: PASS.** This checkpoint changes window history handling only. Phase 4B RTL (`rtl/phase4b/`) and the historic Phase 5 model (`model/canny_fixed/`) were not edited. The workspace began clean at commit `138d956`; `git diff -- rtl/baseline rtl/phase3 rtl/phase4 rtl/phase4b model/canny_fixed` remained empty after the work.

## Old behavior and new policy

The shared `matrix_generate_3x3` window's horizontal samples clear during low HREF, but its two `fifo_ram` arrays/pointers persist across frames (`rtl/baseline/matrix_generate_3x3.v:51-106`, `rtl/baseline/one_column_ram.v:19-65`, `rtl/baseline/fifo_ram.v:19-68`). Old row taps can therefore contain the preceding frame's final rows. All four active 3×3 users—Gaussian, Sobel, NMS and local promotion—are affected. The pre-edit evidence and per-user details are in [PHASE5B_BORDER_AUDIT.md](PHASE5B_BORDER_AUDIT.md).

The new policy substitutes zero for the two older-row taps during the first current-frame line, zero for the two-lines-back tap during the second, and uses both taps from the third line onward. First/second columns still follow the inherited horizontal clear/shift behavior. No output border pixels are suppressed. The RAM arrays are **not** physically cleared or reset; BRAM inference is retained. The new `rtl/phase5b/matrix_generate_3x3_phase5b.v:34-54,109-110` implements a 2-bit saturating current-frame line counter, a VSYNC/HREF edge detector and tap masks. Its VSYNC-rising rule counts HREF on that same clock as line one; this is required by the actual test protocol. The mirror model is `model/phase5b/window.py:6-43`. This validity policy assumes complete 640-pixel lines and normal frame blanking; truncated frames or malformed DE/HREF traffic were not qualified.

The Phase 5 historic persistent-RAM model remains `model/canny_fixed/`; the new frame-isolated model is `model/phase5b/`. All arithmetic, Gaussian coefficients, CORDIC implementation, thresholds 50/100, NMS comparison and one-pass local promotion are reused unchanged from Phase 4B. The new top is `rtl/phase5b/canny_edge_detect_phase5b_top.v`; it retains the same grayscale streaming ports and binary output.

## Verification

`scripts/phase5b/run_all_frame_regressions.ps1` generated deterministic streams, ran XSim and compared every valid sample at Gaussian, Sobel (absolute Gx/Gy and signs), CORDIC magnitude/direction, packed threshold class, NMS class, and final edge. Each valid stage/model comparison had **zero mismatches and zero unknowns**. Counts below are valid samples **per stage**, not VCD transitions.

| Suite | Frames, dimensions | Stage samples | Final mismatches | Unknowns | Additional check |
|---|---:|---:|---:|---:|---|
| `small` | 10 × 640×16 | 102,400 | 0 | 0 | Black, white, impulse, horizontal/vertical steps, both diagonals, ramp, checkerboard, deterministic random |
| `full` | 2 different × 640×480 | 614,400 | 0 | 0 | Random then monkey grayscale; each frame exactly 307,200 valid pixels |
| `isolate_ab` | 4 × 640×480 | 1,228,800 | 0 | 0 | Same target after black vs white: 307,200 Frame-1 pixels compared, **0 differences** |
| `isolate_cd` | 4 × 640×480 | 1,228,800 | 0 | 0 | Same target after checkerboard vs random: 307,200 Frame-1 pixels compared, **0 differences** |
| `leakage` | 2 × 640×480 | 614,400 | 0 | 0 | Final two rows white, then an all-black frame: **0 nonzero valid samples** in that new frame at Gaussian, Sobel Gx, CORDIC magnitude, threshold, NMS and edge |

Total valid samples checked at each stage across the suites: **3,788,800**. Total Frame-1 predecessor-isolation edge pixels compared: **614,400**, with **0 mismatches**. `results/phase5b/*_comparison.json` and `reports/phase5b_*_xsim.log` hold machine-readable outcomes and simulator frame counts. The standalone corrected CORDIC unit regression was rerun after the final window revision: **16,144 vectors, 0 mismatches, 0 unknown outputs** (`reports/phase5b_cordic_xsim.log`). CORDIC arithmetic itself was not modified.

## Historic versus corrected output

`model/phase5b/compare_historic.py` feeds the same two-different-frame stream to the verified historic Phase 5 model and the new model (`results/phase5b/old_vs_new.json`). The initial frame had **0 changed final pixels**. The second had **1,709 changed final pixels**, confined to rows **0–7** (614 columns, x=3–639). At intermediate stages, changes were confined to second-frame rows 0–1 (Gaussian, 1,280 samples), 0–3 (Sobel/CORDIC/class), 0–5 (NMS), then 0–7 (edge). This progression follows the four cascaded 3×3 windows; there were no changes elsewhere in either frame. The changed pixels are the intentional removal of stale preceding-frame border influence, not a new algorithm.

## A100T resources, timing, DRC

Target is `xc7a100tcsg324-1`, core-only 10.000 ns clock from `constraints/phase2_core_timing.xdc`, with no physical pin assignment or bitstream. `scripts/phase5b/create_a100t_project.tcl` creates the project from new Phase 5B sources and unchanged Phase 4B CORDIC, then runs synthesis and route. See `reports/phase5b_synth_impl.log`.

| Metric | Phase 4B | Phase 5B | Delta |
|---|---:|---:|---:|
| Slice LUTs | 1,654 | **1,659** | +5 (+0.30%) |
| Slice FFs | 1,828 | **1,839** | +11 (+0.60%) |
| RAMB18 | 8 | **8** | 0 |
| RAMB36 | 0 | **0** | 0 |
| DSP | 0 | **0** | 0 |
| Synthesis WNS @ 10 ns | +1.701 ns | **+1.701 ns** | 0 |
| Post-route WNS @ 10 ns | +0.810 ns | **+0.883 ns** | +0.073 ns |

Synthesis TNS = **0 ns**; post-route TNS = **0 ns** (`reports/phase5b_timing_synth.rpt:141`, `reports/phase5b_timing_route.rpt:146`). **Core-only 100 MHz post-route timing passes.** Utilization is from `reports/phase5b_utilization.rpt`; post-route utilization, route status and the routed checkpoint are `reports/phase5b_utilization_route.rpt`, `reports/phase5b_route_status.rpt`, and `results/phase5b/canny_a100t_phase5b_routed.dcp`.

Vivado synthesis reported zero synthesis errors/warnings. The existing BRAM asynchronous-control DRC finding **remains**, but fell from 15 post-route `REQP-1840` instances in Phase 4B to 13 here (`reports/phase4b_run2_postroute_drc.rpt:34`, `reports/phase5b_drc.rpt:34`). Synthesis DRC has six in both versions. The routed core still has `NSTD-1`/`UCIO-1` due deliberately absent board pins, and `CFGBVS-1`; these were neither suppressed nor interpreted as board readiness. No physical-hardware, I/O timing, or bitstream claim is made.

**Phase 5B removes dependence of a frame on stale line-buffer contents from the preceding frame. The rest of the Canny algorithm is unchanged.** The last stage remains one-pass local weak-edge promotion, not recursive connected hysteresis. Phase 6 was not started.
