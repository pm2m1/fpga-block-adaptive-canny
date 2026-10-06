# Phase 6 — frame-atomic runtime global thresholds

**Status: PASS.** The strengthened fixed-mode regression rerun passed (`reports/phase6_fixed_xsim.log`). The protected RTL under `rtl/baseline/`, `rtl/phase3/`, `rtl/phase4/`, `rtl/phase4b/`, `rtl/phase5b/` and the historic Python models were not edited. Work began from clean commit `11ee8df`.

## Interface and contract

`rtl/phase6/canny_edge_detect_phase6_top.v` retains the Phase 5B grayscale stream ports and adds **unsigned 11-bit** `threshold_low_i[10:0]` and `threshold_high_i[10:0]`. The legal frame-start configuration is `0 <= LOW < HIGH <= 2047`. The core does **not** reorder thresholds or clamp values above the usual ~1443 Sobel magnitude. Invalid LOW >= HIGH is a caller error: `tb/phase6/tb_phase6_trace.sv` reports it with `$fatal` at frame start, while `model/phase6/classification.py` rejects invalid configurations. Five invalid Python cases were checked by `model/phase6/boundary_vectors.py`; no complex synthesis-side error handler was added.

`threshold_low_active` and `threshold_high_active` capture the ports **only on rising `per_frame_vsync`**, the same frame-start interpretation as Phase 5B (`rtl/phase6/canny_edge_detect_phase6_top.v:20-35`). This protocol permits VSYNC and first HREF to rise together. The active registers remain unchanged until the next VSYNC rise; external changes during a frame are ignored. The gradient's existing one-cycle registered classification uses these held values (`rtl/phase6/canny_get_gradient_phase6.v`, `rtl/phase6/canny_threshold_classify_phase6.v`). It still packs `{class[1:0], direction[3:0], magnitude[10:0]}`. Semantics are **strict**: `magnitude > HIGH` gives strong class 2; else `magnitude > LOW` gives weak class 1; otherwise class 0. There are no `>=` threshold comparisons.

No threshold shift register was added through Gaussian/Sobel/CORDIC. The measured atomic trace (`results/phase6/atomic_latency.json`) shows the last Frame-0 input sample classified **26 clocks** after input, **247 clocks before** Frame 1 captures its pair. Active registers transition only at Frame-1 start (cycle 319048), not at the external mid-frame port change (cycle 159440). The frame-atomic guarantee here is established for the tested complete 640×480 streaming protocol with its specified inter-frame blanking; a source that starts a new frame before the previous classification pipeline drains is not qualified by this phase.

## Boundary and configuration tests

Standalone combinational classifier unit test: **396 Python-generated RTL vectors across seven legal pairs; 0 mismatches** (`reports/phase6_boundary_xsim.log`). Pairs: 50/100, 0/1, 10/20, 100/200, 500/1000, 1000/1500, 1500/2000. Four direction encodings were exercised for each magnitude. Explicit 50/100 results:

| Magnitude | Expected class | RTL class |
|---:|---|---|
| 0, 49, 50 | zero | zero |
| 51, 99, 100 | weak | weak |
| 101, 1023, 1443, 2047 | strong | strong |

The tests also include each pair's LOW−1, LOW, LOW+1, HIGH−1, HIGH, HIGH+1 where representable. A high threshold above mathematical Sobel range remains legal and naturally produces no strong class for ordinary images.

## RTL-versus-model and Phase 5B regression

`model/phase6/` reuses the Phase 5B window/stream model and the verified Sobel/CORDIC arithmetic; only classification and frame-start configuration are new. The `scripts/phase6/run_trace.ps1` suites compare all valid Gaussian, Sobel Gx/Gy/sign, CORDIC magnitude/direction, threshold packed path, NMS class, and final edge values. Every listed stage has **0 RTL/model mismatches and 0 unknown valid values** in all five suites. The direct fixed-50/100 Phase 5B-versus-Phase 6 test also compares controls and valid stage values side by side.

| Suite | Full frames | Valid pixels per frame | Total pixels per stage | Result |
|---|---:|---:|---:|---|
| Fixed 50/100 (random + monkey) | 2 | 307,200 | 614,400 | Phase 5B output/control equivalence: **0 mismatches**; stage/model: 0 |
| Mid-frame atomic update | 2 | 307,200 | 614,400 | External 50/100→100/200 at Frame-0 row 240; Frame 0 stays 50/100; Frame 1 uses 100/200; classification/model mismatches: **0** |
| Six threshold pairs | 6 | 307,200 | 1,843,200 | 0 stage/final mismatches |
| Same-image trend | 4 | 307,200 | 1,228,800 | 0 stage/final mismatches |
| Black/white predecessor isolation | 4 | 307,200 | 1,228,800 | Target Frame 1: **307,200 pixels compared, 0 mismatches** |

Across these suites, **5,529,600 valid samples per stage** were compared with the Phase 6 model. The fixed-mode side-by-side test compared **614,400 final pixels** to Phase 5B with zero mismatches and unknowns (`reports/phase6_fixed_xsim.log`, `results/phase6/fixed_comparison.json`). The Phase 5B frame-border correction remains intact. The unchanged CORDIC unit regression passed **16,144 vectors, 0 mismatches, 0 unknown outputs** (`reports/phase6_cordic_xsim.log`).

## Multi-frame threshold measurements

All six frames use the same monkey grayscale image; each has 307,200 valid outputs and zero RTL/model mismatches (`results/phase6/multi_comparison.json`). Counts refer to the pre-NMS strong/weak threshold class and final post-local-promotion edge output.

| LOW/HIGH | Strong-class pixels | Weak-class pixels | Final edge pixels |
|---:|---:|---:|---:|
| 10/20 | 248,934 | 37,111 | 95,486 |
| 25/75 | 106,839 | 123,124 | 62,809 |
| 50/100 | 71,703 | 84,642 | 50,439 |
| 100/200 | 11,975 | 59,728 | 13,379 |
| 300/600 | 0 | 2,545 | 0 |
| 700/1200 | 0 | 0 | 0 |

The separate same-image trend pairs yielded:

| LOW/HIGH | Strong | Weak | Final edge |
|---:|---:|---:|---:|
| 20/40 | 182,542 | 66,392 | 82,084 |
| 50/100 | 71,703 | 84,642 | 50,439 |
| 100/200 | 11,975 | 59,728 | 13,379 |
| 200/400 | 1,044 | 10,931 | 750 |

For these particular pairs/image, final edge count falls as thresholds rise. This is an observation, **not** a general monotonicity assertion about NMS plus local promotion.

## A100T synthesis and route

`scripts/phase6/create_a100t_project.tcl` generated a clean Vivado 2026.1 project for `xc7a100tcsg324-1` with synthesis top `canny_edge_detect_phase6_top`. Only the existing core-only `create_clock -period 10.000` constraint was used. No package pins, board wrapper, or bitstream were added.

| Metric | Phase 5B | Phase 6 | Delta |
|---|---:|---:|---:|
| Slice LUTs | 1,659 | **1,670** | +11 |
| Slice FFs | 1,839 | **1,861** | +22 |
| RAMB18 | 8 | **8** | 0 |
| RAMB36 | 0 | **0** | 0 |
| DSP | 0 | **0** | 0 |
| Synthesis WNS @ 10 ns | +1.701 ns | **+1.701 ns** | 0 |
| Post-route WNS @ 10 ns | +0.883 ns | **+0.792 ns** | −0.091 ns |

Synthesis TNS **0 ns**; post-route TNS **0 ns** (`reports/phase6_timing_synth.rpt:141`, `reports/phase6_timing_route.rpt:146`). **Core-only 100 MHz post-route timing passes.** Reports: `reports/phase6_utilization.rpt`, `reports/phase6_timing_synth.rpt`, `reports/phase6_timing_route.rpt`, `reports/phase6_drc.rpt`; routed checkpoint: `results/phase6/canny_a100t_phase6_routed.dcp`.

The baseline `fifo_ram` warnings about undriven/unloaded `wr_full`/`rd_empty` remain (12 synthesis warnings); no new threshold width/latch/driver warning was found (`reports/phase6_synth_impl.log`). Post-route DRC is **unchanged** from Phase 5B: 13 `REQP-1840` BRAM asynchronous-control warnings, plus one each `NSTD-1`, `UCIO-1`, and `CFGBVS-1` (`reports/phase5b_drc.rpt:27-34`, `reports/phase6_drc.rpt:27-34`). They were not suppressed. Core timing closure is not board I/O timing or physical-board validation.

**Phase 6 adds frame-atomic runtime configuration of global Canny thresholds. It does not implement adaptive/local thresholds.** Gaussian, Sobel, CORDIC, NMS and one-pass local weak-edge promotion are unchanged. Phase 7 was not started.
