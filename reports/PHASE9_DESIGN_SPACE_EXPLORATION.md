# Phase 9 — single-engine block-adaptive design-space exploration

**Status: PASS for the tested single-engine configurations.** Six parameterizations passed adaptive and fixed-mode RTL simulation and A100T synthesis. The four required corner configurations passed place-and-route at 10.000 ns. The two 16-bin configurations were **not routed**, so their post-route timing is unknown. No board pins, bitstream, multi-engine hardware, or recursive hysteresis were added.

## Architecture and parameterization

The 8-bit grayscale input traverses the same shared, full-frame Gaussian → Sobel → corrected CORDIC → NMS front end as Phase 8. Only the post-NMS threshold statistics are block-local. The classified pixels replay in ordinary raster order into the unchanged global one-pass local weak-edge promotion; NMS and promotion are **not** reset at block boundaries. This is not Xu et al.'s independently processed overlapping-block architecture. The Phase 9 parameterized RTL is in `rtl/phase9/`; the validated front end was not edited.

The 640×480 matrix is 32×32 or 64×64 blocks crossed with 8, 16, or 32 uniform histogram bins. The 32×32 case has 20×15 = 300 full blocks. The 64×64 case has ten columns, seven complete 64-row block rows, and one **32-row partial** block row: 80 blocks in total. The final ten blocks each contain 2,048 real pixels; there is no fake padding in their histogram counts. A full 64×64 block has 4,096 pixels. Counter widths are 11 and 13 bits respectively. See `model/phase9/block_adaptive.py`, `rtl/phase9/histogram_unit_phase9.v`, and `reports/phase9/SCHEDULE_ANALYSIS.md`.

For each nonzero 11-bit post-NMS magnitude *m*, `bin = m >> shift`, where shift is 8, 7, or 6 for 8, 16, or 32 bins. Zero is excluded. Scanning from highest bin downward, the first bin satisfying `5*cumulative >= nonzero_count` is selected. `HIGH = max(1, bin << shift)` and `LOW = floor(2*HIGH/5)`. Classification retains the verified **strict `>`** comparisons. The percentile and reconstruction semantics are identical in all six configurations. The exact 2,048-level software histogram uses the same block geometry and is a **quantization oracle**, not a labeled edge ground truth. See `model/phase9/block_adaptive.py` and `scripts/phase9/software_sweep.py`.

## Common-input software quality comparison

All six configurations used the same Phase 8 post-NMS raster per image from `results/phase8/patterns_nms.mem`: black, white, impulse, horizontal and vertical step, both diagonals, checkerboard, deterministic random, and locally available monkey grayscale. The fixed global 50/100 output, each reduced-bin output, and the same-block-size exact-histogram output were separately calculated. `results/phase9/image_metrics.csv` includes fixed-versus-exact and reduced-versus-exact metrics by image; `results/phase9/block_thresholds.csv` contains every block's LOW/HIGH, candidate count, signed and absolute threshold error. No additional natural image dataset was found/used and none was downloaded.

The table aggregates **ten images** (3,072,000 pixels); mean, median, and p95 include empty blocks. The exact-only edge count was zero in all six comparisons; the reduced lower-bound thresholds produced superset edges under the verified one-pass rule. Thus recall is 1 against this **exact-histogram oracle only**, not against ground-truth edges. F1 and mismatches measure histogram approximation, not objective image quality.

| Block | Bins | Blocks/frame | Mean / median / p95 / max absolute HIGH error | Mean signed HIGH error | Precision | Recall | F1 vs exact | Different pixels |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32×32 | 8 | 300 | 17.033 / 0 / 149 / 254 | −17.033 | 0.4841 | 1.0000 | 0.6524 | 86,723 |
| 32×32 | 16 | 300 | 9.032 / 0 / 66 / 127 | −9.032 | 0.5615 | 1.0000 | 0.7192 | 63,549 |
| 32×32 | 32 | 300 | 5.625 / 0 / 42 / 63 | −5.625 | 0.6529 | 1.0000 | 0.7900 | 43,256 |
| 64×64 | 8 | 80 | 15.939 / 0 / 142 / 252 | −15.939 | 0.4933 | 1.0000 | 0.6607 | 82,531 |
| 64×64 | 16 | 80 | 8.478 / 0 / 61 / 126 | −8.478 | 0.5894 | 1.0000 | 0.7417 | 55,975 |
| 64×64 | 32 | 80 | 5.625 / 0 / 35 / 63 | −5.625 | 0.6739 | 1.0000 | 0.8052 | 38,891 |

Signed reconstruction bias is negative for every configuration because the selected bin's lower boundary does not exceed the corresponding exact magnitude. The 32×32/32-bin ten-image mean error (5.625) is lower than Phase 8's random-plus-monkey 26.42 because this cohort contains many empty/simple synthetic blocks; the RTL rule did not change. Software-only midpoint/upper-bound experiments, including active-block signed and absolute errors, are in `reports/phase9/SOFTWARE_SWEEP.md` and `results/phase9/reconstruction_analysis.csv`. The midpoint reduces signed bias but increases mean absolute error on this cohort. **RTL still uses lower-bound reconstruction.**

### Block-size effect and threshold variation

Comparing 32×32 **exact** output with 64×64 **exact** output isolates spatial adaptation from histogram quantization. The maps differ by 0 pixels on seven images, 40 on the 135° diagonal, 5,564 on random, and 10,958 on monkey (`results/phase9/block_size_effect.csv`). It would be incorrect to call these differences quantization errors or image-quality gains.

The per-image threshold statistics (block count; mean/min/max/std HIGH; mean/min/max LOW; empty fraction; HIGH=0 and top-bin fractions) are in `results/phase9/image_metrics.csv`; block-coordinate maps and candidate counts are in `results/phase9/block_thresholds.csv`. Representative 32-bin results: monkey 32×32 HIGH mean 101.713, min 1, max 256, std 63.602; monkey 64×64 mean 100.163, min 1, max 192, std 60.316. Random 32×32 mean HIGH 251.093 versus 64×64 255.200. Empty blocks are reported rather than silently omitted from aggregate threshold errors. HIGH=0 denotes the inactive empty-block table entry; an active bin-zero block reconstructs HIGH=1.

## Buffering and schedule safety

The tested source stream has 640 active + 24 blank cycles per line. One 32-row stripe is 640×32×11 = 225,280 bits/bank; two ping-pong banks store 450,560 bits and synthesize to 22 RAMB36 total. One 64-row stripe is 640×64×11 = 450,560 bits/bank; **three** banks store 1,351,680 bits and synthesize to 66 RAMB36 total. Histogram counters and per-stripe threshold metadata are in LUTRAM/FF, not additional BRAM, per `reports/phase9/*_memory.rpt` and hierarchical utilization reports. The final 64-row-group bank stores/replays only 32 real rows. The shared front-end and final window consume 8 RAMB18 independent of the stripe bank count.

32-row stripe collection takes 21,248 cycles and replay 20,511; a full 64-row stripe takes 42,496 and replay 41,023. Threshold extraction scans 8/16/32 bins per block plus launch/drain and histogram clear. The detailed bank-reuse analysis is `reports/phase9/SCHEDULE_ANALYSIS.md`. Two banks are safe for 32-row stripes; for 64-row stripes they collide at the next frame's first stripe by 19,857/19,937/20,097 cycles for 8/16/32 bins. Three banks are safe in the analytical three-frame schedule and the tested multi-frame RTL simulation. The design never silently drops input or reuses a bank awaiting replay. RTL collision/overflow assertions did not fire in the tested cases. This is **tested-cadence** safety, not a proof for arbitrary no-blanking inputs.

## RTL/model and regression evidence

`scripts/phase9/run_matrix.ps1` ran two full adaptive frames and two full fixed frames for **every** configuration. Each run counted 614,400 valid pixels, 0 model mismatches, and 0 unknown valid outputs. Adaptive runs checked 600 blocks/2 frames for 32×32 and 160 blocks/2 frames for 64×64, including every threshold pair; fixed runs used 50/100 and the Phase 6-compatible fixed oracle. Total adaptive comparison was 3,686,400 valid pixels; fixed was another 3,686,400. `scripts/phase9/run_hist_units.ps1` passed all six directed histogram tests, including 1,024 or 4,096 consecutive same-bin pixels, clear, and the 2,048-pixel partial row, with zero overflow/mismatch. `scripts/phase9/run_phase8_equiv.ps1` compared 32×32/32-bin directly with verified Phase 8 RTL for 614,400 pixels: **zero mismatches/unknowns**. This direct check protects against parameterization drift; Phase 8 fixed mode had already been compared with Phase 6 at checkpoint `ee473cf`.

Predecessor-frame isolation passed for 32×32/8, 32×32/32, and 64×64/32. Each four-frame RTL run produced 1,228,800 known valid pixels; for the repeated target frame, **307,200 edge pixels and every block threshold matched** despite different predecessor frames. All output frames had exactly 307,200 pixels. The isolated final-row 64×64 blocks used their real 2,048-pixel count. Model tests and the schedule analyzer also passed. Evidence: `reports/phase9/*_xsim.log`, `reports/phase9/phase8_equiv_xsim.log`, `model/phase9/tests.py`. The unchanged corrected CORDIC is the same verified shared front end; no new CORDIC arithmetic was added.

## Resource and timing measurements

Vivado 2026.1 targeted **xc7a100tcsg324-1** with a 10.000 ns core-only clock. `results/phase9/hardware_results.csv` is parsed from actual utilization/timing reports; **dash means not routed**, not a timing pass. BRAM18eq = RAMB18 + 2×RAMB36. The device reports 270 RAMB18 equivalents. Phase 8's 32×32/32-bin checkpoint was 3,748 LUT, 3,076 FF, 645 LUTRAM, 8 RAMB18, 22 RAMB36, 0 DSP, route WNS +0.788 ns. The parameterized Phase 9 version of that point uses +76 LUT, −21 FF, unchanged BRAM/DSP, and route WNS +0.947 ns.

| Block | Bins | LUT | FF | LUTRAM | RAMB18 | RAMB36 | BRAM18eq (% device) | DSP | Synth WNS/TNS ns | Route WNS/TNS ns | Cadence cycles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32×32 | 8 | 3,095 | 2,880 | 197 | 8 | 22 | 52 (19.26%) | 0 | +1.897 / 0 | +0.980 / 0 | 318,968 |
| 32×32 | 16 | 3,361 | 2,959 | 325 | 8 | 22 | 52 (19.26%) | 0 | +1.897 / 0 | — | 318,968 |
| 32×32 | 32 | 3,824 | 3,055 | 645 | 8 | 22 | 52 (19.26%) | 0 | +1.897 / 0 | +0.947 / 0 | 318,968 |
| 64×64 | 8 | 2,692 | 2,787 | 221 | 8 | 66 | 140 (51.85%) | 0 | +1.052 / 0 | +0.311 / 0 | 318,968 |
| 64×64 | 16 | 2,920 | 2,864 | 329 | 8 | 66 | 140 (51.85%) | 0 | +1.067 / 0 | — | 318,968 |
| 64×64 | 32 | 3,272 | 2,941 | 545 | 8 | 66 | 140 (51.85%) | 0 | +1.064 / 0 | +0.248 / 0 | 318,968 |

Every routed corner point meets 100 MHz core timing; the two unrouted 16-bin points have synthesis timing only. The narrowest routed margin is +0.248 ns at 64×64/32. Its worst setup path is `u_stripe/fill_x_reg[1]_rep__1/C` → `u_stripe/g_bank[1].stripe_reg_1_7/ADDRARDADDR[1]`: 9.114 ns data delay, 0 logic levels, 8.658 ns (94.997%) estimated routed-net delay. This is stripe-address distribution/routing, **not** a CORDIC arithmetic path (`reports/phase9/b64_h32_timing_route.rpt`, “Max Delay Paths”). No clock exception was added.

Simulation measured **318,968 output-frame-start cycles** for all six tested variants, or 1.038307 effective cycles/pixel. At a hypothetical continuously supplied 100 MHz clock this corresponds to **313.511 frame-starts/s**, an *analytical core cadence estimate*, not measured board FPS. First-input-to-first-output latency varies from 21,421 cycles (32×32/8) to 42,829 cycles (64×64/32), as reported in the per-configuration XSim logs. No power or physical-board performance is claimed.

### DRC and memory caveats

The routed 64×64/32 DRC reports UCIO-1, NSTD-1 and CFGBVS-1 because this is a core-only build without board pin/electrical constraints; CHECK-3 indicates a report-rule limit. The pre-existing RAMB async-control findings remain: REQP-1839 for RAMB36 (20 displayed) and REQP-1840 for RAMB18 (14 displayed). They were **not** waived or suppressed. Existing inherited FIFO full/empty warnings may remain; Phase 9 debug-only safety/state registers can be trimmed in synthesis. No new unexplained latch, multi-driver, combinational-loop, or width warning was identified in the reviewed reports. This design is not board-ready and no bitstream was generated. See `reports/phase9/b64_h32_drc_route.rpt` and the per-configuration Vivado logs.

## BRAM replication estimate and Pareto decision

For a future architecture *sharing* the eight front-end/final-window RAMB18 and replicating only the stripe buffers, 32-row variants require **52/96/184 RAMB18eq** for hypothetical 1/2/4 engines (19.26/35.56/68.15% of the part). The correct three-bank 64-row design requires **140/272/536 RAMB18eq** (51.85/100.74/198.52%). A two-engine 64-row replication already exceeds the device's 270 RAMB18eq before extra scheduler/merger queues. These are architecture estimates, **not implemented multi-engine results**; see `reports/phase9/BRAM_SCALING.md`.

Using strict multiobjective dominance (maximize exact-histogram F1 while not increasing LUT, FF, LUTRAM, BRAM, DSP or cadence), all six configurations are formally nondominated (`results/phase9/pareto.csv`): increasing bin count improves F1 but costs logic/LUTRAM; moving to 64 rows can reduce LUT but sharply increases BRAM. The 16-bin variants' routed timing is unknown and is not counted as closed. A practical Phase 10 replication filter eliminates all 64-row options with this bank schedule. Among 32-row choices, 32 bins improves aggregate F1 from 0.7192 at 16 bins to **0.7900** for +463 LUT and +320 LUTRAM, with the same 52 BRAM18eq and measured cadence; route margin is +0.947 ns. Thus the recommended **Phase 10 base configuration is 32×32/32 bins**, with 32×32/16 as an area/quality comparison point if later replication pressure demands it. This recommendation is based on measured quality/resource/timing/cadence plus BRAM feasibility, not bin count alone.

**Scope statement:** Phase 9 evaluates block size and reduced-bin histogram precision for a **single-engine** adaptive Canny architecture. Multi-engine hardware has not been implemented. Hardware retains one-pass local weak-edge promotion, **not** recursive Canny hysteresis. Full recursive hysteresis remains a separate software reference; it is not mixed into the histogram-quantization metrics here.

Reproduction commands are in `scripts/phase9/README.md`. Concise primary machine-readable results are `results/phase9/software_sweep.csv`, `image_metrics.csv`, `block_thresholds.csv`, `hardware_results.csv`, and `pareto.csv`. Generated Vivado project caches, large stimulus vectors, and checkpoints are intentionally not source-controlled.
