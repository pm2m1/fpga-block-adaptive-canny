# Phase 5: bit-accurate golden model for the Phase 4B grayscale core

**Final result: PASS.** The Python model is independently executable and matches the unchanged Phase 4B RTL for ten deterministic 640×16 frames and two complete 640×480 frames. Every listed stage is compared on each valid rising-clock sample, with no image shift or visual-only judgement. This phase changes no synthesizable RTL; the 100 MHz core timing result remains the Phase 4B checkpoint `a4bbbef`.

## Scope and exact implemented pipeline

Input is one **8-bit grayscale** pixel with vsync/href/clken. RGB/BMP conversion is outside the synthesized core. The model reproduces the following active order, with source-level details and line references in `reports/PHASE5_PIPELINE_SPEC.md`:

1. **Gaussian:** 3×3 `[1 2 1; 2 4 2; 1 2 1]`; unsigned 12-bit row and final sums, unsigned shift right by 4 (floor), 8-bit output (`rtl/baseline/vip_gaussian_filter.v:71-90,118`).
2. **Sobel:** `Gx=(p11+2p21+p31)-(p13+2p23+p33)`; `Gy=(p11+2p12+p13)-(p31+2p32+p33)`. Four 10-bit nonnegative side sums, 11-bit absolute differences and separate nonnegative sign flags (`rtl/phase4b/canny_get_gradient_phase4b.v:29-49`). The sign convention follows the RTL, not an assumed Cartesian image axis.
3. **CORDIC:** reuse `model/cordic_reference.py.fixed`, the already verified 16-iteration signed 26-bit Q12 vectoring recurrence with Q16-degree angle table, exact gain constant 39797, arithmetic right shift by 28, 11-bit saturation, and one-hot direction 1/2/4/8. The Phase 4B RTL has 18-cycle CORDIC/post-gain latency; the model delays corresponding data/sign/control together (`rtl/phase4b/cordic_gradient_phase4b.v:3-170`).
4. **Threshold class:** magnitude `>100` gives strong class 2; else `>50` gives weak class 1; otherwise the **entire** 17-bit packed gradient path is zero. Packing is `{class[1:0], direction[3:0], magnitude[10:0]}` (`rtl/phase4b/canny_get_gradient_phase4b.v:65-79`).
5. **NMS:** center direction selects left/right, upper-right/lower-left, up/down, or upper-left/lower-right. The center must be strictly `>` both selected neighbors; equality suppresses. Output is the center's two-bit threshold class or zero (`rtl/phase4/canny_nonLocalMaxValue_phase4.v:29-39`).
6. **Final edge:** a nonzero center class survives iff the strong bit of **any of the nine** window cells is set, including the center. This is one-pass local weak-edge promotion, **not recursive Canny hysteresis** (`rtl/baseline/canny_doubleThreshold.v:65-96`). Output is one bit.

The Python package is `model/canny_fixed/`; `model/run_canny_model.py` runs a grayscale `.mem` frame without Vivado. No floating-point/OpenCV operation is used for the bit-accurate image path. The separate ideal math inside the inherited CORDIC reference is used only for its analytic approximation metrics.

## Exact window and border behavior

`matrix_generate_3x3` clears its horizontal 3×3 registers when delayed href is low, so the first two columns contain zero/partial left history. Its `one_column_ram` uses two 640-depth RAMs with registered reads and independent circular read/write pointers; the RAMs initialize to zero once but **do not reset per frame** (`rtl/baseline/matrix_generate_3x3.v:44-99`, `rtl/baseline/one_column_ram.v:21-67`, `rtl/baseline/fifo_ram.v:17-65`). There is no right or bottom look-ahead padding. The four window stages are modeled clock-by-clock, including read-before-write RAM behavior, blanking, bubbles, control delays, and cross-frame RAM history.

The measured border probe (`reports/phase5_border_observations.txt`) makes the behavior concrete. In a white frame after black, Gaussian values at (0,0), (1,0), (2,0), (2,1), (2,2) are **15, 47, 63, 191, 255**; (639,2) remains 255. In the following nearly-black impulse frame, (100,0) is **191** and (100,1) is **63** because two white rows persist in line RAM. Thus a per-frame zero-padded software convolution would be wrong. The nth valid sample at each stage corresponds to the nth active input coordinate in this protocol; stage latency is in **clock cycles**, not a post-hoc pixel-coordinate shift. Both small- and full-frame RTL traces prove that association sample by sample.

## Stimulus and comparison method

`model/canny_fixed/images.py` generates grayscale hex `.mem` arrays and a cycle-by-cycle text stream. Ten short 640×16 images exercise arithmetic, borders and cross-frame history. The two full 640×480 frames are fixed-seed random (`0x5CA11E`) and the existing monkey BMP converted **once** to grayscale with a documented 24-bit BMP/BGR top-down decode and `Y=(77R+150G+29B)>>8`. This preprocessing is an asset conversion, not the historical RTL RGB converter.

`tb/phase5/tb_phase5_trace.sv` feeds the exact text stream to the **actual** `canny_edge_detect_phase4b_top` and observes existing internal wires hierarchically; no synthesis RTL was instrumented. It samples after each rising edge, writes stage/control values, and enforces exact per-frame output pixel counts. `model/run_phase5_regression.py` feeds the same stream to the clocked Python model and compares controls plus stage data at the same cycle. On a mismatch it fails nonzero with stage, frame, x/y, clock cycle, RTL/model values, and recent input. Unknown RTL values during a valid sample also fail. Generated traces/arrays are under `results/phase5/`; PASS does not depend on PNG appearance or VCD transition counts.

| Test image | Dimensions | Stages checked | Valid samples per stage | Mismatches | Unknown valid values |
|---|---:|---|---:|---:|---:|
| Black | 640×16 | All six | 10,240 | 0 | 0 |
| White | 640×16 | All six | 10,240 | 0 | 0 |
| Single impulse | 640×16 | All six | 10,240 | 0 | 0 |
| Vertical step | 640×16 | All six | 10,240 | 0 | 0 |
| Horizontal step | 640×16 | All six | 10,240 | 0 | 0 |
| 45° diagonal step | 640×16 | All six | 10,240 | 0 | 0 |
| 135° diagonal step | 640×16 | All six | 10,240 | 0 | 0 |
| Grayscale ramp | 640×16 | All six | 10,240 | 0 | 0 |
| Checkerboard | 640×16 | All six | 10,240 | 0 | 0 |
| Fixed-seed random | 640×16 | All six | 10,240 | 0 | 0 |
| Fixed-seed random, full | 640×480 | All six | 307,200 | 0 | 0 |
| Monkey grayscale, full | 640×480 | All six | 307,200 | 0 | 0 |

“All six” means Gaussian, Sobel **both magnitudes and sign flags**, CORDIC **magnitude and direction**, packed threshold classification, NMS class, and final edge. Across all 12 frames, **716,800 valid samples per stage** match. Full-frame results alone are **2 frames × 307,200 = 614,400 pixels**, zero final-output mismatches and zero unknown output pixels. The six full-frame stage counts and zeros are in `results/phase5/full_comparison.json`; the short-frame counts are in `results/phase5/small_comparison.json`. RTL runs are in `reports/phase5_small_xsim.log` and `reports/phase5_full_xsim.log`.

| Intermediate check | Mismatches |
|---|---:|
| Gaussian | 0 |
| Sobel Gx/Gy/sign | 0 |
| CORDIC magnitude | 0 |
| Direction bin | 0 |
| Threshold class/packed path | 0 |
| NMS class | 0 |
| Local-promotion/final edge | 0 |

The independent Python unit suite also passed Gaussian/Sobel/threshold/NMS/local-rule directed tests and repeated all **1,042,441** first-quadrant CORDIC pairs; its metrics file is byte-identical to the verified Phase 4 report (0 overflow/wrap, maximum ideal-magnitude error 1, mean 0.480821950). `model/run_canny_model.py` independently generated the 307,200-pixel first random-frame edge PNG; its SHA256 was identical to the regression reference: `FA15017E966D3E3483B5ECC21A0CF22D20FF411AF63ADEFACD4EEEA9A49D2374`.

Earlier Phase 4B regressions were rerun **without changing their tracked logs or RTL**: CORDIC 16,144 vectors/0 mismatches (`reports/phase5_prev_cordic_xsim.log`), and two-frame Phase 4/4B equivalence 614,400 pixels/0 mismatches/0 unknowns (`reports/phase5_prev_frame_xsim.log`).

Inspection-only grayscale PNGs for selected images, including `*_input.png`, `*_gaussian.png`, `*_magnitude.png`, `*_direction.png`, `*_nms.png`, and `*_edge.png`, are generated under `results/phase5/`. They do not determine PASS/FAIL.

## Reproduction and limitations

From the workspace root in PowerShell:

```powershell
& 'C:\Program Files\Python312\python.exe' -m model.tests
& './scripts/phase5/run_trace.ps1' -Suite small
& './scripts/phase5/run_trace.ps1' -Suite full
& './scripts/phase5/run_previous_cordic.ps1'
& './scripts/phase5/run_previous_frame.ps1'
& 'C:\Program Files\Python312\python.exe' model/run_canny_model.py --input results/phase5/random_full.mem --output results/phase5/random_full_standalone_edge.png
```

No new synthesis/place-and-route was run because no synthesizable source changed. The Phase 4B clock closure is a **core-only** 100 MHz result, not a board deployment or image-quality comparison.

**Phase 5 establishes a bit-accurate software golden model for the current Phase 4B RTL. It does not claim equivalence to a floating-point or textbook Canny implementation, nor does it establish image-quality superiority.**
