"""Phase 8 block-local threshold reference on post-NMS output-raster slots.

The global Gaussian/Sobel/CORDIC/NMS front-end is outside this module. Every
input sample is an 11-bit NMS-suppressed magnitude in full raster order.
"""
from dataclasses import dataclass
from model.phase7.full_hysteresis import one_pass

FRAME_WIDTH = 640
FRAME_HEIGHT = 480
BLOCK_W = BLOCK_H = 32
HIST_BINS = 32
BIN_SHIFT = 6
PIXELS_PER_BLOCK = 1024


@dataclass(frozen=True)
class BlockResult:
    bx: int
    by: int
    nonzero_count: int
    histogram: tuple[int, ...]
    selected_bin: int
    high: int
    low: int
    active: bool


def select_thresholds(histogram, nonzero_count):
    """Select first high-to-low bin satisfying 5*cumulative >= N."""
    if len(histogram) != HIST_BINS:
        raise ValueError("expected 32 bins")
    if any(not 0 <= count <= PIXELS_PER_BLOCK for count in histogram):
        raise ValueError("histogram counter outside 11-bit legal range")
    if not 0 <= nonzero_count <= PIXELS_PER_BLOCK or sum(histogram) != nonzero_count:
        raise ValueError("histogram total mismatch")
    if nonzero_count == 0:
        return 0, 0, 0, False
    cumulative = 0
    for bin_index in range(31, -1, -1):
        cumulative += histogram[bin_index]
        if 5 * cumulative >= nonzero_count:
            high = max(1, bin_index << BIN_SHIFT)
            return bin_index, high, (2 * high) // 5, True
    raise AssertionError("nonzero histogram has no selected bin")


def exact_thresholds(histogram, nonzero_count):
    """Software-only 2048-value oracle with the same high-tail rule."""
    if len(histogram) != 2048 or sum(histogram) != nonzero_count:
        raise ValueError("invalid exact histogram")
    if nonzero_count == 0:
        return 0, 0, False
    cumulative = 0
    for value in range(2047, 0, -1):
        cumulative += histogram[value]
        if 5 * cumulative >= nonzero_count:
            high = max(1, value)
            return high, (2 * high) // 5, True
    raise AssertionError("nonzero exact histogram has no selected value")


def _classify(magnitude, low, high, active):
    if not active:
        return 0
    return 2 if magnitude > high else 1 if magnitude > low else 0


def process_frame(magnitudes, width=FRAME_WIDTH, height=FRAME_HEIGHT,
                  exact=False):
    """Return (block table, post-NMS class raster, conceptual one-pass edge)."""
    if (width, height) != (FRAME_WIDTH, FRAME_HEIGHT):
        raise ValueError("Phase 8 geometry is fixed at 640x480")
    if len(magnitudes) != width * height:
        raise ValueError("incorrect magnitude raster length")
    if any(not 0 <= magnitude <= 2047 for magnitude in magnitudes):
        raise ValueError("magnitudes must be unsigned 11-bit")
    classes = bytearray(len(magnitudes))
    blocks = []
    for by in range(15):
        for bx in range(20):
            histogram = [0] * (2048 if exact else HIST_BINS)
            positions = []
            for y in range(by * BLOCK_H, (by + 1) * BLOCK_H):
                base = y * width + bx * BLOCK_W
                for x in range(BLOCK_W):
                    pos = base + x
                    positions.append(pos)
                    magnitude = magnitudes[pos]
                    if magnitude:
                        histogram[magnitude if exact else magnitude >> BIN_SHIFT] += 1
            nonzero_count = sum(histogram)
            assert nonzero_count <= PIXELS_PER_BLOCK
            if exact:
                high, low, active = exact_thresholds(histogram, nonzero_count)
                selected_bin = high >> BIN_SHIFT if active else 0
            else:
                selected_bin, high, low, active = select_thresholds(histogram, nonzero_count)
            for pos in positions:
                classes[pos] = _classify(magnitudes[pos], low, high, active)
            blocks.append(BlockResult(bx, by, nonzero_count,
                                      tuple(histogram),selected_bin,high,low,active))
    assert len(blocks) == 300
    # No reset at 32x32 boundaries: local neighborhood crosses blocks.
    return blocks, classes, one_pass(classes, width)
