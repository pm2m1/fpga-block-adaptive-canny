# Selected results

All figures are from the checked-in reports and CSVs. The exact 2,048-level per-block histogram is the reference for the F1 column; it is **not** labeled ground truth. Ten test images were used in the Phase 9 aggregate. A dash means a configuration was not routed.

| Block | Bins | Mean absolute HIGH error | Mean signed HIGH error | F1 vs exact histogram | Different pixels | LUT | FF | LUTRAM | BRAM18eq | Route WNS (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32×32 | 8 | 17.033 | -17.033 | 0.6524 | 86,723 | 3,095 | 2,880 | 197 | 52 | +0.980 |
| 32×32 | 16 | 9.032 | -9.032 | 0.7192 | 63,549 | 3,361 | 2,959 | 325 | 52 | — |
| 32×32 | 32 | 5.625 | -5.625 | 0.7900 | 43,256 | 3,824 | 3,055 | 645 | 52 | +0.947 |
| 64×64 | 8 | 15.939 | -15.939 | 0.6607 | 82,531 | 2,692 | 2,787 | 221 | 140 | +0.311 |
| 64×64 | 16 | 8.478 | -8.478 | 0.7417 | 55,975 | 2,920 | 2,864 | 329 | 140 | — |
| 64×64 | 32 | 5.625 | -5.625 | 0.8052 | 38,891 | 3,272 | 2,941 | 545 | 140 | +0.248 |

The negative threshold bias comes from reconstructing the selected bin at its lower boundary. The 64×64 designs use three stripe banks and 140 BRAM18-equivalents, versus two banks and 52 equivalents at 32×32. The bottom 32-row partial block row is counted with its real pixels. Sources: `results/phase9/software_summary.json`, `results/phase9/hardware_results.csv`, `reports/PHASE9_DESIGN_SPACE_EXPLORATION.md`.

| Adaptive engines | LUT | FF | LUTRAM | RAMB18 | RAMB36 | BRAM18eq | DSP | Route WNS (ns) | Frame cadence (cycles) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 3,834 | 3,059 | 645 | 8 | 22 | 52 | 0 | +0.960 | 318,968 |
| 2 | 6,058 | 4,252 | 1,285 | 8 | 44 | 96 | 0 | +0.675 | 318,968 |
| 4 | 10,299 | 6,627 | 2,565 | 8 | 88 | 184 | 0 | +0.644 | 318,968 |

All three configurations matched the model and each other for the tested frames. Adaptive-service time was also 298,115 cycles for each. Replicating threshold engines did not increase throughput with the current one-pixel-per-clock shared front end/output. Source: `results/phase10/hardware_results.csv`, `results/phase10/performance_results.csv`.

| Final implementation | LUT | FF | LUTRAM | RAMB18 | RAMB36 | BRAM18eq | DSP | Route WNS / TNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Phase 11 board wrapper, E=1 | 4,063 | 3,299 | 644 | 8 | 118 | 244 / 270 | 0 | +0.436 / 0 ns |

The 244 equivalents include 160 for the input image ROM, 32 for the output frame buffer and 52 for the adaptive core. It should not be compared directly with a pure core. Bitstream generation succeeded and routed DRC had zero findings. Phase 11V routed functional simulation matched 307,200 monkey pixels; SDF timing simulation remains unresolved. Sources: `reports/PHASE11V_NO_BOARD_VALIDATION.md` and `reports/phase11v/bram_cells.txt`.
