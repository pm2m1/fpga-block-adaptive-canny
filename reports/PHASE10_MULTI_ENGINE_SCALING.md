# Phase 10 — resource-scalable adaptive engines

**Result:** 1-, 2-, and 4-engine RTL variants are bit-identical to the verified Phase 9 32×32/32-bin algorithm for the tested frames. All three synthesize and route on `xc7a100tcsg324-1` at the **10.000 ns core-only clock**. Replication changes adaptive-engine activity and resources but provides **no measured adaptive-service or end-to-end cadence speedup** under the one-pixel/clock source and one-pixel/clock raster output protocol. The four-engine variant fits and closes timing, but is not a useful throughput upgrade under this interface.

## Architecture and ownership

`rtl/phase10/canny_block_adaptive_phase10_top.v` instantiates **one** Gaussian/Sobel/CORDIC/NMS front end, `ENGINE_COUNT` copies of `rtl/phase10/block_adaptive_engine_phase10.v`, a static owner/reorder grant, and **one** global Phase 5B local-promotion stage. Each engine derives from the verified Phase 9 stripe threshold engine and owns two 32-row magnitude banks, histogram banks, threshold extraction/table, replay state, and classification. The shared front end accepts one gray pixel and emits at most one post-NMS magnitude per clock. The final raster path also emits at most one classified pixel per clock. Neither is replicated. Detailed pre-RTL audit: `reports/PHASE10_PARALLEL_ARCHITECTURE.md`.

The input scheduler assigns global stripe `s` to engine `s mod ENGINE_COUNT`. It gates the NMS `href/de` so exactly one engine fills on an active sample. Each engine scans its own completed stripe and raises `stripe_ready_o`. The merger grants replay **only** to the owner of `merge_stripe`, the next required raster stripe. A later completed stripe waits until earlier stripes replay. The grant stays with one engine for 20,480 classified pixels and then advances to the next stripe; the shared local-promotion window is never reset at a stripe or engine boundary. This preserves cross-block and cross-engine 3×3 weak-edge promotion. Completion is tracked with per-engine ready/bank state and global modulo-15 input/merge stripe counters; in-order stripes within each engine make a separate associative reorder RAM unnecessary. Frame-start VSYNC resets the *input stripe index*, while completed previous-frame banks remain valid until ordered replay; histogram storage is cleared before reuse, not physically cleared at VSYNC. Assertions reject bank overwrite, histogram clear/read/write collisions, duplicate replay grant, invalid geometry, and replay ahead of a collected stripe.

The algorithm is unchanged: 32×32 blocks, 32 uniform bins of nonzero 11-bit post-NMS magnitudes (`bin=magnitude>>6`), descending 20% high-tail test (`5*cumulative>=N`), `HIGH=max(1,selected_bin<<6)`, `LOW=floor(2*HIGH/5)`, strict `>` classification, then one-pass local weak-edge promotion. No recursive hysteresis, multi-lane front end, or independent full-Canny engine is claimed. `model/phase10/multiengine_scheduler.py` separates the Phase 9 algorithmic oracle from an analytical schedule and tests owner order, bank safety, delayed/out-of-order readiness, wraparound and frame transitions.

## Verification

For the two different 640×480 frames (random and monkey), **each** E=1/2/4 RTL variant produced 614,400 valid output pixels, 600 block threshold pairs, and 614,400 classified pixels matching the Phase 9 Python oracle. Mismatches and unknown valid values were **zero**. A Phase 9 RTL core also ran alongside each DUT; ordinal-by-raster edge comparison gave **zero** Phase 10-versus-Phase 9 mismatches for E=1, 2, and 4. Thus E=1 directly reproduces Phase 9, and 1-versus-2 and 1-versus-4 engine-count invariance holds for all 614,400 pixels and 600 block thresholds tested.

Four-frame predecessor-isolation suites passed for E=1/2/4: 1,228,800 valid pixels and 1,200 block thresholds per variant, including the final stripe and engine-assignment wraparound. In each suite the repeated target frame's 307,200 edge pixels and 300 thresholds matched despite different predecessor frames. An additional **testbench-only** E=2 stress case withheld the first stripe replay grant until the later engine was ready; the merger held its stripe ID at zero, then emitted all 614,400 pixels and 600 thresholds in correct order with zero mismatches/unknowns (`reports/phase10/e2_two_delayed_xsim.log`). It altered first-output latency and the transient two-frame interval, so it is **not** used for steady-state performance numbers. Normal XSim pass logs: `reports/phase10/e{1,2,4}_two_xsim.log` and `e{1,2,4}_isolate_xsim.log`. Model tests: `python -m model.phase10.tests` → PASS. No production RTL from Phase 9 or earlier was modified.

## Engine utilization and useful overlap

Counters were sampled over the first-input-to-last-output interval of **658,852 cycles** for the normal two-frame suite. Fill, scan and replay counters can overlap, so their sum is not active time; `busy` counts cycles with any such activity. In a two-frame 15-stripe/frame workload, modulo assignment gives E=2 a 16/14 stripe split and E=4 an 8/8/8/6 split.

| E | Engine | Fill | Histogram scan/clear | Replay | Busy | Idle | Utilization |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | 614,400 | 38,430 | 614,400 | 657,984 | 868 | 99.87% |
| 2 | 0 | 327,680 | 20,496 | 327,680 | 645,524 | 13,328 | 97.98% |
| 2 | 1 | 286,720 | 17,934 | 286,720 | 582,428 | 76,424 | 88.40% |
| 4 | 0–2, each | 163,840 | 10,248 | 163,840 | 332,816 | 326,036 | 50.51% |
| 4 | 3 | 122,880 | 7,686 | 122,880 | 249,612 | 409,240 | 37.89% |

Multiple engines perform independent collection/scanning while another replays, so the copies are not all idle. Nevertheless the shared serial input and ordered serial replay limit system service. The uneven engine-3 utilization is a consequence of 15 not being divisible by four, not dropped work. Exact counters are in `results/phase10/engine_utilization.csv`.

## Adaptive and end-to-end performance

**Adaptive service interval definition:** first completed post-NMS stripe of a frame to the threshold-ready pulse for that frame's fifteenth/final stripe, inclusive. This is held identical for E=1/2/4; both frames in each normal test measured **298,115 cycles**. It intentionally includes the arrival of subsequent stripes from the shared source and therefore characterizes this integrated adaptive subsystem, *not* an unconstrained compute-only engine. The schedule-only Python model gives the same ownership/order conclusion and is not substituted for RTL cycle measurement.

**System cadence definition:** first valid output pixel of one frame to first valid output pixel of the next. All normal runs measured **318,968 cycles**. The hard active-data floor for one pixel/clock is 307,200 cycles; this design is 11,768 cycles (3.83%) above that floor under the tested blanking/protocol. Analytical `100,000,000 / 318,968 = 313.511` is a **100 MHz core cadence estimate**, not measured board FPS.

| Engines | Adaptive cycles | Adaptive speedup | Adaptive efficiency | Frame cadence cycles | System speedup | System efficiency |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 298,115 | 1.000 | 1.000 | 318,968 | 1.000 | 1.000 |
| 2 | 298,115 | 1.000 | 0.500 | 318,968 | 1.000 | 0.500 |
| 4 | 298,115 | 1.000 | 0.250 | 318,968 | 1.000 | 0.250 |

The first-input-to-first-output latency was 21,901 cycles and last-output latency 658,851 cycles for all normal variants. **Incremental adaptive or system speedup per additional LUT or BRAM18eq is zero** in this measured regime; there is no meaningful throughput-per-added-resource improvement to report. A synthetic multi-lane benchmark was not needed to answer the production-interface question and was not conflated with full-Canny throughput. `results/phase10/performance_results.csv` holds the exact numbers.

## Resource scaling and BRAM comparison

Vivado 2026.1 synthesis reports supply LUT, FF, LUTRAM and primitive counts. Device capacity used here is 63,400 LUT, 126,800 FF, 19,000 LUT-as-memory sites, and 270 RAMB18 equivalents from Vivado's utilization tables. `BRAM18eq = RAMB18 + 2×RAMB36`. The shared line buffers remain 8 RAMB18; each copied two-bank stripe engine adds 22 RAMB36 (44 RAMB18eq). Histogram memory maps to LUTRAM. Each engine has its own histogram, scan/threshold and stripe storage, not a copied Gaussian/CORDIC/NMS path.

| Engines | LUT (% part) | FF (% part) | LUTRAM (% available) | RAMB18 | RAMB36 | BRAM18eq (% part) | DSP |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 3,834 (6.05%) | 3,059 (2.41%) | 645 (3.39%) | 8 | 22 | 52 (19.26%) | 0 |
| 2 | 6,058 (9.56%) | 4,252 (3.35%) | 1,285 (6.76%) | 8 | 44 | 96 (35.56%) | 0 |
| 4 | 10,299 (16.24%) | 6,627 (5.23%) | 2,565 (13.50%) | 8 | 88 | 184 (68.15%) | 0 |

Relative to E=1, E=2 adds 2,224 LUT, 1,193 FF, 640 LUTRAM and 44 BRAM18eq; E=4 adds 6,465 LUT, 3,568 FF, 1,920 LUTRAM and 132 BRAM18eq. LUT ratios are 1.580/2.686 and BRAM ratios 1.846/3.538 for E=2/4; the shared front end prevents exactly linear *total* BRAM scaling. The measured BRAM18eq values **exactly match** Phase 9's conservative 52/96/184 estimate. E=1 differs from Phase 9's parameterized checkpoint by only +10 LUT and +4 FF; its 52 BRAM18eq and 645 LUTRAM are unchanged. `results/phase10/hardware_results.csv` contains all deltas and percentages.

## Timing, critical paths and implementation status

All three designs completed place-and-route on `xc7a100tcsg324-1`; all have nonnegative post-route WNS and TNS 0 at 10.000 ns. No clock weakening, false path, multicycle exception, board pin assignment or bitstream was used.

| Engines | Synth WNS/TNS | Route WNS/TNS | Routed worst-path module | Data delay: logic / route | Logic levels |
| ---: | ---: | ---: | --- | ---: | ---: |
| 1 | +1.897 / 0 ns | +0.960 / 0 ns | shared CORDIC gain-scale path | 9.038 ns: 4.774 / 4.264 | 17 |
| 2 | +1.843 / 0 ns | +0.675 / 0 ns | shared CORDIC gain-scale path | 9.190 ns: 4.734 / 4.456 | 16 |
| 4 | +1.897 / 0 ns | +0.644 / 0 ns | engine 3 threshold scan → block-active CE | 8.973 ns: 3.925 / 5.048 | 10 |

The four-engine worst setup path starts at `g_engine[3].u_engine/scan_first_pipe_reg/C` and ends at `g_engine[3].u_engine/block_active_reg[1][3]/CE` (`reports/phase10/e4_timing_route.rpt`, “Max Delay Paths”). It is a threshold-selection control path with 56.26% routed delay, **not** the input scheduler or final merger. E=1/2 are limited by the inherited CORDIC gain-scaling path. All routed nets were complete with no routing errors (`reports/phase10/e4_route_status.rpt`). Four engines thus **fit and meet this preliminary 100 MHz core timing constraint**, but consume 68.15% of BRAM capacity and deliver no measured cadence gain.

Core-only DRC still reports NSTD-1/UCIO-1 missing board pin/electrical constraints, CFGBVS-1, and existing RAMB async-control REQP-1839/1840 findings; CHECK-3 limits displayed checks. These were not suppressed (`reports/phase10/e4_drc_route.rpt`). The inherited `fifo_ram.v` undriven unused full/empty ports generate Synth 8-3848/7129 warnings. Synth 8-6014 removes Phase 10 debug-only bank-safety, selected-bin, and counter state that does not feed the production output; it does not indicate a missing datapath. There is no board-readiness or physical FPS/power claim. No Vivado power estimate was attempted because comparable switching activity was not prepared; power is deferred rather than guessed.

## Scaling interpretation and decision

**Classification: B — useful independent adaptive work overlaps, but the single-stream input and raster-order output limit both adaptive service and end-to-end scaling in the measured configuration.** The engines are real replicated histogram/buffer/threshold hardware, not full independent Canny pipelines. The service-time and cadence speedups are exactly 1.000 for E=2/4, with 0.500/0.250 parallel efficiency. E=4 is physically area/timing-feasible on this A100T core-only design but **not performance-practical** for the current single-lane interface: it costs +6,465 LUT and +132 BRAM18eq over E=1 with no measured throughput benefit. A future wider/banked source or an explicitly different throughput objective would require a new phase and new measurements; neither is assumed here.

**Research-claim boundary:** “resource-scalable replicated block-adaptive threshold engines sharing a common streaming Canny front end” accurately describes this hardware. Do not claim four pixels/clock, 4× full-Canny speedup, measured board FPS, physical power, recursive hardware hysteresis, or Xu-style independent full-Canny tile engines. **Engine count changes scheduling and hardware replication but does not change the block-adaptive Canny algorithm. The reported 100 MHz FPS/cadence values are analytical core estimates, not measured board frame rates.**

Reproduction: `scripts/phase10/README.md`. Primary machine-readable evidence: `results/phase10/hardware_results.csv`, `performance_results.csv`, and `engine_utilization.csv`. Original/verified RTL trees remained untouched; generated Vivado projects and routed checkpoints reside in ignored Phase 10 paths, while reports and source are checkpointed in Git.
