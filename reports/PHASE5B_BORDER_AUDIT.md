# Phase 5B pre-edit border/window audit

Checkpoint `138d956` was clean (`git status --short` produced no entries). All Phase 4B RTL and Phase 5 model files remain read-only for this phase.

## Shared window mechanism

Each of the four active 3×3 users instantiates `matrix_generate_3x3`, directly or through the corresponding stage. The window uses one `one_column_ram` with two `fifo_ram` instances; therefore each stage has two vertical line-buffer RAMs. See `rtl/baseline/matrix_generate_3x3.v:51-63`, `rtl/baseline/one_column_ram.v:33-65`.

`fifo_ram` initializes RAM and read/write pointers once, but neither the RAM nor either pointer has a frame reset (`rtl/baseline/fifo_ram.v:19-68`). Its read and write pointers advance on enable and wrap at `DATA_DEPTH`. `one_column_ram` has no reset input (`rtl/baseline/one_column_ram.v:1-18`). Its second FIFO receives delayed first-FIFO output (`:19-65`). Thus full-frame traffic leaves the final two rows in the RAMs, which can be visible at the next frame's first two rows. The horizontal 3-sample registers clear whenever delayed `href` is low (`rtl/baseline/matrix_generate_3x3.v:80-106`), so first/second columns are zero-history horizontally. The two-cycle control shift is at `:65-76`; the matrix samples RAM taps on delayed `href && clken` at `:80-99`. No frame-start validity masking exists.

| Active user | Source and window instance | Width; two RAMs | Frame-start stale exposure | Horizontal/border behavior |
|---|---|---:|---|---|
| Gaussian | `rtl/baseline/vip_gaussian_filter.v:44-69` | 8 bits; 2 × 640 | Top/middle window rows can read prior-frame data at first/second lines. | All three window rows shift horizontally; clear on low delayed href. |
| Sobel | `rtl/phase4b/canny_get_gradient_phase4b.v:19-30` | 8 bits; 2 × 640 | Same, now on Gaussian output stream. | Same. |
| NMS | `rtl/phase4/canny_nonLocalMaxValue_phase4.v:17-24` | 17 bits; 2 × 640 | Same, now on packed gradient stream. | Same. |
| One-pass local promotion | `rtl/baseline/canny_doubleThreshold.v:37-62` | 2 bits; 2 × 640 | Same, now on NMS class stream. | Same. |

The Phase 5 trace measured a next-frame Gaussian sample of 191 on row 0 after a white preceding frame with an almost-black next frame (`reports/phase5_border_observations.txt`). This is direct evidence of the stale vertical history. The effect can propagate downstream through later 3×3 windows. The design emits a valid sample for each active input pixel; borders are not suppressed (`reports/PHASE5_BIT_ACCURATE_GOLDEN_MODEL.md`).

## Correction contract

At every stage's own frame-start `vsync` rising edge, invalidate both vertical histories logically. For the first current-frame line, substitute zero for both older-row taps; for the second line, substitute zero only for the two-lines-back tap; for subsequent lines, use both taps. The protocol permits VSYNC and HREF to rise on the **same** first pixel, so that event must count as line one. Keep RAM contents and pointers unchanged to retain BRAM inference. Horizontal register clearing, pixel/count protocol, arithmetic and all non-border behavior must remain unchanged. A frame-local saturating line-valid counter and tap masks implement this policy in a new `rtl/phase5b` window module. Correct timing of masks relative to the delayed window sample must be verified by RTL/model trace and frame-isolation tests before the result can be accepted.
