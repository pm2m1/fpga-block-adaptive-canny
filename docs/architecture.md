# Architecture

The final board top is `rtl/phase11/canny_nexys_a7_phase11_top.v`. It feeds an 8-bit grayscale raster to `rtl/phase11/core/canny_block_adaptive_phase10_top.v` and stores a 1-bit edge frame for simulated USB-UART readback. RGB conversion is outside the synthesized core.

```text
grayscale raster
  -> Gaussian 3x3 -> Sobel -> 16-stage fixed-point CORDIC -> NMS magnitude
  -> stripe buffer + block histogram -> HIGH/LOW thresholds -> raster replay
  -> one-pass local weak-edge promotion -> binary edge raster
```

The Gaussian/Sobel/CORDIC/NMS front end and final promotion window are shared across the frame. Only threshold statistics are local to 32×32 blocks. Each block's histogram counts **nonzero** 11-bit post-NMS magnitudes in 32 uniform bins (`bin = magnitude >> 6`). Scanning from the high end selects the first bin with `5 × cumulative_count >= nonzero_count`. The block uses `HIGH = max(1, selected_bin << 6)` and `LOW = floor(2 × HIGH / 5)`, then classifies with strict `>` comparisons. Empty blocks are inactive. See `rtl/phase11/core/` and `model/phase9/block_adaptive.py` for executable definitions.

The threshold is known only after collecting a block, so two 32-row stripe banks retain post-NMS magnitudes while histograms are finalized and the previous stripe is replayed. Replayed pixels return to raster order before the **single global** 3×3 promotion window. Neither NMS nor promotion is reset at block boundaries, so they can see neighbors across those boundaries. This is not a set of independent full-Canny tiles.

Phase 10 implemented `ENGINE_COUNT=1,2,4` with static stripe ownership (`stripe_index % ENGINE_COUNT`) and an ordered merge. All three gave identical tested edge maps and the same 318,968-cycle output-frame-start interval. More engines cost BRAM/LUT without increasing cadence under the shared one-pixel-per-clock input/output interface. The final board configuration therefore uses one adaptive engine, 32×32 blocks and 32 bins. The board wrapper adds one 640×480×8 image ROM, a packed 38,400-byte output frame buffer and a UART transmitter; its area is not the algorithm-only area.

For timing, buffering and engine-state detail, see `reports/PHASE8_BLOCK_ADAPTIVE_SINGLE_ENGINE.md`, `reports/PHASE9_DESIGN_SPACE_EXPLORATION.md`, `reports/PHASE10_MULTI_ENGINE_SCALING.md`, and `reports/PHASE11_FINAL_FPGA_VALIDATION.md`.
