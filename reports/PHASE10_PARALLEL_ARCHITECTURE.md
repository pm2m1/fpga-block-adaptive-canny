# Phase 10 parallel architecture audit — before RTL replication

Starting point: clean Git checkpoint `d38ddfb`; source examined: `rtl/phase9/canny_block_adaptive_phase9_top.v`, `rtl/phase9/stripe_threshold_engine_phase9.v`, `rtl/phase9/histogram_unit_phase9.v`, `rtl/phase9/adaptive_threshold_step_phase9.v`, and `scripts/phase9/schedule_analysis.py`. The verified geometry is 640×480, 32×32, 32 bins, 15 stripes/frame, 20 blocks/stripe. No Phase 8/9 file will be edited.

## Resource ownership

| Resource | Ownership in intended architecture | Evidence / reason |
| --- | --- | --- |
| Gaussian and its line buffers | shared, one copy | `canny_block_adaptive_phase9_top.v`, `u_gaussian`; one incoming gray stream |
| Sobel/window, corrected 16-stage CORDIC | shared, one copy | `u_gradient`; one Gaussian output stream |
| NMS/window | shared, one copy | `u_nms`; at most one post-NMS magnitude per clock |
| Stripe magnitude buffer | per engine | `stripe_threshold_engine_phase9.v`, `g_bank[*].stripe`; independently owned completed stripes |
| Histogram storage and nonzero counters | per engine | `g_bank[*].u_hist`; block-local state is consumed after stripe collection |
| Threshold scan, cumulative accumulator, threshold tables | per engine | `scan_state`, `u_step`, `block_low/high/active`; scans of different completed stripes can overlap |
| Stripe replay address and classification | per engine, but **one global replay grant at a time** | independently ready stripe can wait; global output remains one pixel/clock |
| Ownership/completion order, replay arbitration | shared scheduler/merger | assigns stripe `s` to `s % ENGINE_COUNT`; only next required `s` may replay |
| Final 3×3 local promotion/window | shared, one copy | `u_local_3x3`; must see a single raster-order class stream across engine boundaries |
| Input frame counter and fixed/adaptive mode latch | shared | one frame-atomic configuration and one source |

No front-end duplication is justified: the front end and final promotion each transport approximately one pixel per clock. The multi-engine parallel work is independent **histogram collection in local memory while another engine scans or replays**, and independent scans of completed stripes. Only one engine is written by the front end in any cycle. A replicated engine that remains idle is not counted as useful parallelism; per-engine fill/scan/replay/idle counters must establish actual overlap.

## Scheduling and bank derivation

The preferred static schedule is global stripe `s` → engine `s mod E`, with 32 consecutive 640-pixel rows per stripe. Each engine must retain the **global** frame/stripe tag, not infer it from its local stripe count. The merger's `next_to_emit` counter advances only after a complete 20,480-pixel stripe has replayed. The engine owning a later stripe may finish its histogram early, but cannot output before earlier stripes. It must hold magnitude storage and thresholds until a replay grant. Releasing a bank before both histogram clear and replay completion is illegal. The one shared promotion module sees normal line boundaries and no reset at stripe/engine boundaries.

Under the tested 640-active + 24-blank cycles/line cadence, a stripe arrives every 21,248 clocks. Its 640-bin threshold scan plus launch/drain and 640-address clear completes in about 1,282 clocks after fill, while replay requires 20,511 clocks. Phase 9 needed two banks for one engine: the next stripe begins filling 21,248 clocks after the prior fill starts, before its replay finishes. With two engines and alternating stripes, the same engine is revisited after 42,496 clocks. If replay is granted promptly, a single bank per engine is *analytically almost sufficient* (about 95 cycles of margin using the Phase 9 idealized schedule), but minor grant/control gaps or different source cadence could destroy that margin. Therefore the correctness-first implementation should initially retain **two banks per engine** and measure whether reducing to one is safe; Phase 9 BRAM estimates 52/96/184 RAMB18 equivalents reflect this conservative replication. For four engines the revisit interval is 84,992 clocks and bank pressure is lower, but output grant order remains a possible source of backpressure.

The scheduler must assert against selecting two engines for one input stripe, missing or duplicated stripe IDs, overwriting an unreplayed bank, and granting replay of an incomplete stripe. A frame transition is identified by the verified VSYNC convention, not by arbitrary reset of BRAM contents. Engine metadata and counters are logically invalidated at frame start. The final stripe is stripe 14, followed by stripe 0 of the next frame; replay may still be active across that input boundary, so frame ID is necessary to distinguish ownership. No input backpressure exists on the current shared front-end interface. If bank reuse cannot be proven for the tested stream, the design must stop rather than drop pixels.

## Expected performance ceiling and measurement contract

The source presents 307,200 active pixels/frame through a one-pixel/clock interface; 307,200 clocks is a hard active-data floor before blanking and pipeline costs. Phase 9 output-frame-start cadence was 318,968 clocks. Replicating the adaptive subsystem cannot multiply that input bandwidth or the one-pixel/clock raster output bandwidth. End-to-end speedup may therefore remain close to 1 even if threshold scans overlap. Report separately (1) adaptive service interval, with an identical definition for E=1/2/4, and (2) output-frame-start cadence. Count active fill, histogram scan/clear, replay, and idle cycles by engine; calculate measured speedup and efficiency without assuming 2× or 4×.

**Design gate:** this report is the required architecture audit. Only after this resource/schedule distinction is established may new Phase 10 RTL be written. No Phase 10 algorithmic change is permitted: 32×32 blocks, 32 uniform bins from nonzero post-NMS magnitude, 20% high-tail rule, lower-bin-boundary HIGH, LOW=floor(2×HIGH/5), strict `>`, and one global one-pass local promotion remain unchanged.
