# Phase 9 common-NMS software design-space sweep

The input for every result is the **same** verified Phase 8 post-NMS 11-bit magnitude raster from `results/phase8/patterns_nms.mem`. Images are black, white, impulse, horizontal and vertical steps, both diagonals, checkerboard, deterministic random, and the only locally available natural grayscale image, monkey. No dataset was downloaded. Scripts: `scripts/phase9/software_sweep.py` and `model/phase9/block_adaptive.py`. All outputs use the same one-pass local promotion rule. The exact 2048-level histogram is a **quantization oracle**, not ground-truth edge accuracy.

64×64 geometry has ten columns and eight block rows: seven full 64-row block rows and a final 32-row block row, yielding 80 blocks/frame. Histograms and counters for those final ten blocks use 64×32=2,048 real pixels. The remaining configurations use 300 full 32×32 blocks/frame. Zero magnitudes are excluded. Histogram bins are uniform with shifts 8/7/6 for 8/16/32 bins; reconstruction remains the selected bin's lower boundary (minimum 1) and LOW=floor(2×HIGH/5).

The ten-image aggregate, including empty blocks, is:

| Block | Bins | Blocks/frame | Mean / p95 / max absolute HIGH error | Mean signed HIGH error | F1 vs same-block exact | Pixel mismatches (10 frames) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 32×32 | 8 | 300 | 17.033 / 149 / 254 | −17.033 | 0.6524 | 86,723 |
| 32×32 | 16 | 300 | 9.032 / 66 / 127 | −9.032 | 0.7192 | 63,549 |
| 32×32 | 32 | 300 | 5.625 / 42 / 63 | −5.625 | 0.7900 | 43,256 |
| 64×64 | 8 | 80 | 15.939 / 142 / 252 | −15.939 | 0.6607 | 82,531 |
| 64×64 | 16 | 80 | 8.478 / 61 / 126 | −8.478 | 0.7417 | 55,975 |
| 64×64 | 32 | 80 | 5.625 / 35 / 63 | −5.625 | 0.8052 | 38,891 |

All signed errors are nonpositive for the lower-bound rule: its HIGH is at or below the exact value in the same selected bin. The smaller ten-image mean than Phase 8's random+monkey 26.42 for 32×32/32 bins reflects many empty or simple synthetic blocks, not a changed algorithm. Per-image precision, recall, F1, empty-block fraction, and HIGH/LOW maps are in `results/phase9/image_metrics.csv` and `block_thresholds.csv`; per-block signed/absolute errors are also in the latter. Precision/recall/F1 here mean agreement with the **same-block-size exact histogram** only.

Across this cohort the exact-only edge count is zero in all six comparisons, so recall relative to the exact-histogram oracle is 1.0000. Lower-bound reconstruction makes both approximate thresholds no greater than their exact thresholds; under strict classification and the same monotone one-pass promotion rule, the approximate edge set is a superset of the exact edge set. Thus the nonzero mismatches above are approximation-only pixels. Aggregate precision is 0.4841, 0.5615, 0.6529 for 32-row 8/16/32 bins and 0.4933, 0.5894, 0.6739 for 64-row 8/16/32 bins. This does **not** mean recall against labeled ground-truth edges is one; the reference here is only the exact-histogram implementation.

Optional software-only reconstruction analysis excludes empty blocks. Mean signed / mean absolute HIGH errors for lower, midpoint and upper reconstruction respectively were:

| Block/bins | Lower | Midpoint | Upper |
| --- | ---: | ---: | ---: |
| 32/8 | −48.67 / 48.67 | +79.03 / 100.56 | +206.03 / 206.03 |
| 32/16 | −25.81 / 25.81 | +38.07 / 48.24 | +101.07 / 101.07 |
| 32/32 | −16.07 / 16.07 | +15.88 / 22.74 | +46.88 / 46.88 |
| 64/8 | −40.35 / 40.35 | +87.39 / 102.40 | +214.39 / 214.39 |
| 64/16 | −21.46 / 21.46 | +42.43 / 48.48 | +105.43 / 105.43 |
| 64/32 | −14.24 / 14.24 | +17.72 / 23.00 | +48.72 / 48.72 |

Midpoint is less biased but has **larger absolute error** on this image cohort, because the selected percentile often lies near a bin's lower edge. This is analysis only; Phase 9 RTL retains Phase 8 lower-bound reconstruction.

Block-size effect is separate from histogram quantization. Comparing **32×32 exact** against **64×64 exact** changes 0 pixels on seven of ten images, 40 on diagonal135, 5,564 on random, and 10,958 on monkey (`results/phase9/block_size_effect.csv`). These are spatial-adaptation differences, not histogram approximation errors, and neither map is labeled ground truth. All edge-map numbers in this report use the cycle-faithful Phase 5B/8 local-promotion software window, not a textbook spatial-padding shortcut.
