# Phase 8 — single-engine, block-local reduced-bin thresholds

Status: **PASS** for the tested 640×480 stream protocol and 100 MHz core-only A100T synthesis/route. Checkpoint base: `9c49b95`. All Phase 6 and earlier RTL directories remain unchanged. Vivado 2026.1 targeted `xc7a100tcsg324-1`; there is no board-pin XDC or bitstream.

## Architecture and coordinate contract

```
grayscale → frame-isolated Gaussian → Sobel → 16-stage CORDIC
          → global magnitude NMS → two-bank stripe buffer / local histograms
          → block thresholds → strict threshold class → global one-pass local promotion → edge
```

The Gaussian/Sobel/CORDIC/NMS front-end and final local promotion each process the complete raster, not independent tiles. Only threshold statistics are local. NMS and promotion can see across 32×32 threshold boundaries. This is **not** Xu et al.'s independently processed overlapping-block architecture, and no novelty is claimed for Canny, block histograms, or parallel engines. There is one engine. The hardware uses one-pass local weak-edge promotion, **not** recursive Canny hysteresis. The latter remains software reference only.

Every valid NMS output sample (`href && clken`) advances post-NMS raster `(x,y)` from `(0,0)` through `(639,479)`. Its histogram owner is `(x>>5,y>>5)`; the same convention is used for replay. The causal 3×3 window's interior center is geometrically `(x−1,y−1)`, but no image shift is applied. Details and a reproducible probe are in `PHASE8_COORDINATE_SPEC.md` and `scripts/phase8/probe_coordinates.py`.

Geometry is fixed for Phase 8: 640×480, 32×32 blocks, 20×15=300 blocks/frame, 15 stripes/frame, 20,480 samples/stripe, no partial blocks. Two stripe banks hold 20,480×11=225,280 logical bits each; both hold 450,560 bits. They infer 22 RAMB36E1 total (11 per stripe). Four inherited window users infer 8 RAMB18E1 total. Histograms comprise two banks of 20×32×11=7,040 logical bits each, inferred as distributed RAM/LUTRAM, not thousands of FF counters. Each bank has 20 11-bit nonzero totals. A maximum 1,024 entries per bin fits in 11 bits; the directed all-same-bin test confirms no wrap. The scan is pipelined after LUTRAM read to meet timing.

## Histogram and threshold rule

Only **nonzero NMS-suppressed 11-bit magnitudes** are counted. There are 32 uniform bins; `bin=mag[10:6]`, each width 64, with bin 0 covering 0–63 (zero excluded) and bin 31 covering 1984–2047. For a block with `N=nonzero_count`, scan bins 31 down to 0 and select the first `b` where `5*cumulative_high >= N`. Reconstruct `HIGH=max(1,b<<6)` and `LOW=floor(2*HIGH/5)`. If `N=0`, mark the block inactive and classify every sample zero. Classification is strictly `mag>HIGH ? strong : mag>LOW ? weak : zero`. The selected bin approximates the upper 20% tail; the number classified strong need not equal 20% because of 64-value quantization and strict `>`.

The software-only exact-histogram oracle uses 2,048 magnitude counts with the same descending-tail and low-ratio rules. It is a quantization comparator, **not image-quality ground truth**. Per-block data are in `results/phase8/adaptive_quantization.csv` and `results/phase8/patterns_quantization.csv`.

## Buffer schedule and protocol contract

One bank fills while the previous bank is scanned/cleared/replayed. Scan costs 640 bin cycles plus one pipeline-drain cycle, followed by 640 clear cycles; it does not physically clear the stripe BRAM. Raster replay requests 20,480 pixels plus 31 interline gap cycles = 20,511 cycles/stripe. The inherited test source supplies 24 blank clocks per 640-pixel input line, or 21,248 clocks/32-line stripe. The simulation checks reject bank overwrite, premature replay, histogram clear/write collision, stripe read/write collision, invalid indices, incomplete pixel counts and missing block thresholds. **No input backpressure exists**, so an arbitrary continuous source without this cadence is not supported or claimed safe. A future throughput interface must add buffering or backpressure if cadence changes.

The measured adaptive two-frame XSim run recorded 19,200 scan-bin, 30 drain, 19,200 clear, 614,400 replay-request, and 930 interline-gap cycles over 30 stripes. First input-valid to first output-valid was 21,901 cycles. Each output frame occupied 317,983 clock cycles from its first through last output pixel (307,200 active pixels; active density ~0.9661 over that span). Output-frame first-pixel interval was 318,968 cycles for this test stimulus; the first input to last output across two frames was 658,851 cycles. At a *hypothetical* sustained 100 MHz and this exact stimulus cadence, 318,968 cycles/frame corresponds to approximately 313.5 frames/s. This is analytical scaling from measured RTL cycles, **not measured board FPS**. The 21,248-cycle stripe fill figure follows from the source cadence; the scan/replay figures were also instrumented in simulation.

Mode 0 uses frame-atomic 11-bit runtime `threshold_low_i` and `threshold_high_i` (strict comparisons); mode 1 uses block thresholds. `mode_i` and fixed thresholds latch on the Phase 6 input frame-start event. The mixed test changes `mode_i` mid-frame and confirms the current frame remains fixed while the next becomes adaptive.

## Verification

| Test | Evidence | Result |
| --- | --- | --- |
| NMS/classification commutativity | `model/phase8/prove_commutativity.py`; `reports/phase8_fixed_commute_xsim.log` | 323,958 directed/random windows; two Phase 6 frames, 614,400 NMS and edge pixels, zero mismatches/unknowns |
| Histogram and same-bin stress | `reports/phase8_tb_phase8_histogram_xsim.log` | 10 directed/random cases, 320 bin comparisons, zero overflow/mismatch |
| Threshold generator | `reports/phase8_tb_phase8_threshold_xsim.log` | 109 synthetic histograms, zero mismatches |
| Buffered fixed mode vs Phase 6 | `reports/phase8_buffered_fixed_xsim.log` | 2 frames, 614,400 pixels, 600 blocks, zero class/edge mismatches/unknowns |
| Adaptive random + monkey | `reports/phase8_adaptive_xsim.log` | 2 frames, 614,400 NMS/class/edge samples, 600 block thresholds and all histogram bins, zero mismatches/unknowns |
| Pattern suite | `reports/phase8_patterns_xsim.log` | black, white, impulse, horizontal/vertical, both diagonals, checkerboard, random, monkey: 10 frames, 3,072,000 pixels, 3,000 blocks, zero mismatches/unknowns |
| Predecessor-frame isolation | `reports/phase8_isolate_xsim.log` | black→monkey vs white→monkey, 307,200 target pixels and 300 threshold records equal; 4 total frames, zero oracle mismatches |
| Frame-atomic mode switch | `reports/phase8_mixed_xsim.log` | fixed frame with mid-frame external mode change, then adaptive frame: 614,400 pixels, zero mismatches |
| Prior CORDIC regression | `scripts/phase6/run_cordic_regression.ps1` | 16,144 vectors, zero mismatches; historical tracked log restored after the rerun |

Each full-frame test checks exactly 307,200 input, post-NMS, class, and final valid pixels/frame; 300 block threshold records/frame; zero unknown valid output. Counting is on rising clocks under `href && clken`, not VCD transitions. The local promotion consumes the full raster without block-boundary resets. Smooth/empty blocks have inactive threshold tables and zero classes; final behavior follows the global one-pass window.

For random and monkey (600 blocks), the 32-bin vs exact-histogram HIGH error was mean 26.4167, median 22, max 63; LOW error mean 10.6083, max 26. Final edge maps differed at 13,938 random and 28,154 monkey raster locations. The ten-pattern suite had mean HIGH absolute error 5.6253 across 3,000 blocks (many empty blocks), max 63; edge-map differences by pattern are in `results/phase8/patterns_summary.json`. These differences quantify histogram approximation, not superiority or ground-truth precision/recall.

## A100T resources and timing

| Metric | Phase 6 | Phase 8 | Change |
| --- | ---: | ---: | ---: |
| LUT | 1,670 | 3,748 | +2,078 |
| FF | 1,861 | 3,076 | +1,215 |
| LUTRAM LUT | 5 | 645 | +640 |
| RAMB18E1 | 8 | 8 | 0 |
| RAMB36E1 | 0 | 22 | +22 |
| DSP | 0 | 0 | 0 |
| Synthesis WNS @ 10 ns | +1.701 ns | +1.897 ns | +0.196 ns |
| Post-route WNS @ 10 ns | +0.792 ns | +0.788 ns | −0.004 ns |

Phase 8 synthesis and post-route TNS are 0. The first synthesis candidate failed WNS at −1.672 ns: its critical path combined histogram LUTRAM read, cumulative sum, and the 5× comparison (15 logic levels). A register between LUTRAM read and scan arithmetic added one drain cycle and changed no numerical outputs; final synthesis WNS is +1.897 ns and final post-route WNS is +0.788 ns. Reports: `phase8_utilization.rpt`, `phase8_utilization_hierarchical.rpt`, `phase8_timing_synth.rpt`, `phase8_timing_route.rpt`, `phase8_memory_inference.rpt`, `phase8_route_status.rpt`; checkpoint `results/phase8/canny_a100t_phase8_routed.dcp`. No bitstream was generated.

DRC remains **not board-ready**: NSTD-1 and UCIO-1 for all 40 unconstrained core I/O ports, CFGBVS-1, 20 reported RAMB36 async-control REQP-1839 findings, 13 RAMB18 REQP-1840 findings, and CHECK-3 rule-limit notice. The RAMB18 findings are inherited window-buffer behavior; new RAMB36 address controls add findings. These warnings were not suppressed and should be resolved before any board deployment. Synthesis also retains undriven/unused inherited FIFO status ports and reports trimming simulation-only bank-safety/debug registers and selected-bin records; no new width/latch/multiple-driver/combinational-loop warning was found. Review `reports/phase8_run2_synth_impl.log` and `phase8_drc.rpt` before extending the architecture.

This Phase 8 result is a functional single-engine block-local threshold accelerator under the tested stream cadence. It is not a multi-engine or overlapping-tile architecture, does not implement recursive Canny hysteresis, and establishes neither physical-board operation nor measured FPS/power. Phase 9 has not begun.
