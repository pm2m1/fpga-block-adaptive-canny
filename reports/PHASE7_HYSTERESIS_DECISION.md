# Phase 7 — hysteresis semantics and architecture decision

**Status: PASS, analysis/model only. Recommendation: A — retain the verified one-pass local weak-edge promotion in the main hardware, and retain exact recursive 8-connected hysteresis as a separate software quality reference.** No production RTL, threshold, synthesis result, or timing result changed. The protected Phase 6 checkpoint is `b5a3280` (`xc7a100tcsg324-1`, 1670 LUT, 1861 FF, 8 RAMB18, no DSP, post-route WNS +0.792 ns at 10 ns); see `reports/PHASE6_RUNTIME_THRESHOLDS.md`.

## Semantics and verification boundary

`reports/PHASE7_HYSTERESIS_AUDIT.md` cites the RTL. For 2-bit post-NMS class `C(x,y)`, the production Boolean rule on its 3×3 window is

`edge = (center[1] OR center[0]) AND OR_{all 9 cells}(cell[1])`.

The strong center is included. Only original strong classes drive promotion. A promoted weak edge does **not** promote another weak edge: there is one pass and no feedback. The production streaming window is causal and has a line-buffer/control delay; the following spatial experiments use the same **post-NMS class raster** for both rules at class-map coordinates. They do not pretend the production output stream is an unshifted spatial image. The cycle-exact Phase 6 local model was independently replayed against the existing Phase 6 `fixed.trace`: **614,400 valid RTL pixels, zero mismatches**, including output controls (`scripts/phase7/verify_trace_local.py`). The ten directed maps and **all 19,683 possible 3×3 class windows** also match the literal RTL `search`/`high_low` equation (`model/phase7/tests.py`). No new RTL simulation or production-source edit was needed.

`model/phase7/full_hysteresis.py` is independent of OpenCV. It seeds a FIFO with **every** original strong pixel, then breadth-first visits previously unvisited weak 8-neighbors until the queue empties. Strong pixels have depth 0; a retained weak pixel's depth is the shortest number of weak steps from an original strong pixel. Unreachable weak pixels are dropped. `bounded_from_depth` retains depths at most 1, 2, 4, or 8; depth 1 equals the conceptual one-pass rule exactly.

## Directed cases

Complete binary maps and counts are in `results/phase7/directed_tests.csv`. A one-row `S W W W W` gives **11000** after one pass and **11111** after convergence. The two-weak chain differs by one pixel; a five-weak chain by four; diagonal chain by three; branching chain by five; connected loop by ten; two-strong bridge by three. Single strong, isolated weak, adjacent weak, and unconnected weak island behave as expected. All ten tests and the exhaustive window check pass.

## Image-level measurements

Source maps are actual Phase 6 RTL traces already proven bit-exact to the Phase 6 Python model (`results/phase6/fixed.trace`, `multi.trace`, and their comparison JSONs); the five short patterns run that same Python pipeline. Only valid NMS samples (`href && clken`) enter the map. The only relevant local natural grayscale input found was `images/monkey.bmp`; no new data was downloaded. It is decoded with the documented Phase 6 grayscale conversion. Synthetic patterns are 640×16; monkey and random are 640×480. Values below are **connectivity differences on the common post-NMS class map**, not a pixel-registered direct comparison of the two full output video streams.

| Image | Size | LOW/HIGH | Strong | Weak | One-pass edges | Recursive edges | Differing / recursive-only | Max depth |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Monkey | 640×480 | 25/75 | 54,828 | 34,093 | 62,907 | 75,356 | 12,449 | 69 |
| Monkey | 640×480 | 50/100 | 41,276 | 28,693 | 50,512 | 61,233 | 10,721 | 25 |
| Monkey | 640×480 | 100/200 | 8,806 | 32,470 | 13,399 | 25,991 | 12,592 | 76 |
| Random, seed `0x5CA11E` | 640×480 | 50/100 | 117,451 | 4,655 | 121,442 | 121,715 | 273 | 5 |
| Vertical step | 640×16 | 50/100 | 329 | 0 | 329 | 329 | 0 | 0 |
| Horizontal step | 640×16 | 50/100 | 641 | 0 | 641 | 641 | 0 | 0 |
| 45° diagonal step | 640×16 | 50/100 | 348 | 0 | 348 | 348 | 0 | 0 |
| 135° diagonal step | 640×16 | 50/100 | 334 | 0 | 334 | 334 | 0 | 0 |
| Checkerboard | 640×16 | 50/100 | 2,230 | 0 | 2,230 | 2,230 | 0 | 0 |

Across these **nine image/threshold cases and 1,280,000 class pixels**, 36,035 pixels differ (2.815%). All differences are recursive-only; one-pass-only count is zero, as graph reachability requires. This is *not* an image-quality superiority claim: it measures connectivity semantics only. Exact per-case `difference_fraction` and `recursive_recovery_fraction` are in `results/phase7/image_metrics.csv`. The one-pass count on the *spatial class map* need not equal the existing production output-bit count because of the causal streaming window alignment documented above.

For monkey 50/100, full recursive recovery has 9,236 weak pixels at depth 1 and 10,721 additional pixels at depth ≥2; 8,736 original weak pixels remain unreachable. Depth histograms for **every case** are stored in `results/phase7/*_depth.json` (including depth 0 strong count). Maximum observed depth is **76** (monkey 100/200).

### Bounded-pass software experiment

Numbers are pixels **still missing relative to full convergence** after 1/2/4/8 synchronous promotion passes:

| Image / LOW-HIGH | 1 | 2 | 4 | 8 |
|---|---:|---:|---:|---:|
| Monkey 25/75 | 12,449 | 8,885 | 5,374 | 2,641 |
| Monkey 50/100 | 10,721 | 6,537 | 2,881 | 703 |
| Monkey 100/200 | 12,592 | 9,435 | 5,544 | 2,168 |
| Random 50/100 | 273 | 38 | 1 | 0 |
| All five high-contrast synthetic patterns | 0 | 0 | 0 | 0 |

An 8-pass approximation is materially closer on monkey but still not exact. Its storage/scheduling cost is not justified by these observations alone. These are software results, **not** implemented FPGA modes. Inspection PNGs for monkey, random, 45° diagonal, and checkerboard include input, NMS classes, one-pass, recursive, and difference maps under `results/phase7/`.

## Exact-hysteresis FPGA architectures

The target has **270 RAMB18 or 135 RAMB36** available (`reports/phase6_utilization.rpt:78-80`). The capacity arithmetic below assumes a nominal **18,432 bits/RAMB18 and 36,864 bits/RAMB36**; a RAMB36 is two RAMB18 equivalents. These are *lower bounds* for storage, not proven realizable memory mappings. Port count, word width/depth organization, read-modify-write hazards, and the eight-neighbor access pattern can raise actual use or cycle count. The Phase 6 core already uses eight RAMB18.

| Item, 640×480 = 307,200 pixels | Bits | Bytes | Ideal RAMB18 | Ideal RAMB36 |
|---|---:|---:|---:|---:|
| 2-bit post-NMS class | 614,400 | 76,800 | 34 | 17 |
| 1-bit retained/visited map | 307,200 | 38,400 | 17 | 9 |
| Second 1-bit propagation map | 307,200 | 38,400 | 17 | 9 |
| 19-bit coordinate queue, pessimistic full-frame capacity | 5,836,800 | 729,600 | 317 | 159 |

Separate class + two propagation banks cost at least **68 RAMB18** (or 35 RAMB36) before overhead. Separate class + visited + full-capacity queue cost at least **368 RAMB18** (or 185 RAMB36), exceeding all A100T BRAM even before the existing pipeline. Queue capacity can be reduced or moved off chip, but then worst-case occupancy, bandwidth and overflow handling need proof. A 19-bit linear address also identifies any of the 307,200 locations.

| Architecture | Exactness / state | Throughput/control | Interaction with future tiles/engines |
|---|---|---|---|
| **A. Full-frame iterative scan** | Exact only after no-change convergence; class plus retained/current-next maps; frame held until done. | At an *ideal* one processed pixel/clock, 307,200 cycles = **3.072 ms/pass**, at most **325.5/pass_count frames/s** at 100 MHz, excluding input/output and neighbor-memory penalties. Observed depth 76 implies at least 76 propagation layers for a synchronous depth-1/pass method: ≥233.472 ms, ideal ≤4.28 fps. A contrived chain can require O(frame pixels) passes. Change flag and termination scan are needed. | Global passes serialize all tiles; multiple Canny engines do not eliminate the global connectivity dependency. |
| **B. Queue flood-fill** | Exact; class/visited plus worklist; enqueue all original strong pixels, then each reachable weak once. | Variable O(S+W_reached) pops plus up to 8 neighbor reads/popped pixel. If eight checks are scheduled per retained pixel at one check/clock, monkey 50/100 needs ~8×61,233 = **489,864 neighbor cycles (4.899 ms)**, *before* queue/visited load, writes, hazards and output. The all-pixel eight-check case is 2,457,600 neighbor cycles (24.576 ms, ≤40.7 fps ideal). Multiport/banking or caching is required for more than one neighbor/clock. | A global queue conflicts with independent tile engines; the naive full-capacity on-chip queue cannot fit A100T. |
| **C. Streaming connected components** | Potentially exact with component labels, equivalence merges, deferred output and strong-connected flag; cannot finally decide an early weak component before a later strong connection. | Single raster pass for provisional labels, but equivalence resolution/output pass and sufficient state storage; label count worst case may be large. Complex proof/control, not a simple 1-pixel/clock add-on. | Tile boundaries require equivalence merging across engines, global ownership and deterministic output commit. |
| **D. Tile-local exact flood-fill** | Exact *inside* each tile only. A 32×32 tile needs 2,048 class bits + 1,024 visited bits, or 64×64 needs 8,192 + 4,096, before queue/halo. | Local queue/scans are variable-latency. Exact **frame-wide** hysteresis additionally requires boundary frontier exchange and repeated inter-tile propagation until convergence; a halo alone cannot bound arbitrary chains. | Independent tile completion/output is unsafe: a weak component can connect to a strong component several tiles away. Cross-tile iteration or a final global merge is necessary. |

Queue figures are analytical scheduling examples, not measured throughput or guaranteed lower bounds. The representative queue estimate counts each popped retained pixel's eight possible neighbor checks; border skips reduce actual checks but random BRAM access and update bookkeeping add cycles. A queue need not actually reach full-frame occupancy on these images; the full-frame capacity is the safe worst-case provision. Exact iterative scan may need additional line-window buffering or multi-bank reads to realize the optimistic one-pixel/clock assumption.

## Decision and academic language

**Select Option A.** The natural-image result shows a real semantic difference, so this is an acknowledged algorithm limitation, not an assertion that one pass is equivalent to full Canny. Yet exact global connectivity would consume extra full-frame state and impose variable-latency/global coordination that directly conflicts with the planned reduced-bin local thresholds and 1/2/4-engine scaling study. The intended contribution is the controlled Artix-7 area/throughput/quality tradeoff of the block-adaptive thresholding architecture, not an exact connectivity engine. A future bounded or exact hysteresis study can be a separate extension, ideally with an explicit cross-tile protocol and resource budget.

Use the sentence: **“The current FPGA architecture uses one-pass local weak-edge promotion, not recursive Canny hysteresis. Full recursive 8-connected hysteresis is maintained as a software reference for quality evaluation.”** Do not claim textbook Canny hysteresis, measured quality superiority, measured FPS for hypothetical engines, physical board operation, or a new synthesis result from Phase 7.

Reproduce from the workspace root: `python -m model.phase7.tests`; `python scripts/phase7/verify_trace_local.py`; `python scripts/phase7/run_analysis.py`. The last command writes CSV, JSON depth histograms and inspection PNGs under `results/phase7/` and fails on an invalid class/count/invariant. Historic `results/phase6` traces are local prerequisite artifacts; regenerate them with `scripts/phase6/run_trace.ps1 -Suite fixed` and `-Suite multi` if absent, without modifying production RTL.
