"""Parameterized post-NMS block thresholds; no changes to the Canny front end.

Coordinates are Phase 8 post-NMS raster slots. The final short 64-row stripe
contains 32 real rows; it is never padded into the histogram denominator.
"""
from dataclasses import dataclass
from math import ceil, log2

from model.phase7.full_hysteresis import one_pass

WIDTH = 640
HEIGHT = 480
MAG_BITS = 11
MAG_LEVELS = 1 << MAG_BITS


@dataclass(frozen=True)
class Block:
    bx: int
    by: int
    pixels: int
    nonzero: int
    bin_index: int
    high: int
    low: int
    active: bool
    histogram: tuple[int, ...]


def geometry(block_size):
    if block_size not in (32, 64):
        raise ValueError("Phase 9 block size must be 32 or 64")
    if WIDTH % block_size:
        raise ValueError("partial columns are unsupported")
    return WIDTH // block_size, ceil(HEIGHT / block_size)


def select(histogram, bins):
    """High-tail crossing at 5*cumulative >= N, then lower-bin boundary."""
    if bins not in (8, 16, 32, MAG_LEVELS) or len(histogram) != bins:
        raise ValueError("unsupported histogram shape")
    count = sum(histogram)
    if count == 0:
        return 0, 0, 0, False
    shift = MAG_BITS - (bins.bit_length() - 1)
    cumulative = 0
    for b in range(bins - 1, -1, -1):
        cumulative += histogram[b]
        if 5 * cumulative >= count:
            high = max(1, b << shift)
            return b, high, (2 * high) // 5, True
    raise AssertionError("nonempty histogram did not cross target")


def process_frame(magnitudes, block_size, bins, *, edges=True):
    if len(magnitudes) != WIDTH * HEIGHT:
        raise ValueError("640x480 NMS magnitude raster required")
    if bins not in (8, 16, 32, MAG_LEVELS):
        raise ValueError("bins must be 8, 16, 32, or 2048 oracle")
    shift = MAG_BITS - (bins.bit_length() - 1)
    nx, ny = geometry(block_size)
    classes = bytearray(len(magnitudes))
    blocks = []
    for by in range(ny):
        y0 = by * block_size
        y1 = min(y0 + block_size, HEIGHT)
        for bx in range(nx):
            x0 = bx * block_size
            hist = [0] * bins
            for y in range(y0, y1):
                for x in range(x0, x0 + block_size):
                    mag = magnitudes[y * WIDTH + x]
                    if not 0 <= mag < MAG_LEVELS:
                        raise ValueError("magnitude outside 11 bits")
                    if mag:
                        hist[mag >> shift] += 1
            nonzero = sum(hist)
            pixels = block_size * (y1 - y0)
            if nonzero > pixels or max(hist) > pixels:
                raise AssertionError("histogram counter overflow")
            b, high, low, active = select(hist, bins)
            for y in range(y0, y1):
                for x in range(x0, x0 + block_size):
                    pos = y * WIDTH + x
                    mag = magnitudes[pos]
                    classes[pos] = (2 if mag > high else 1 if mag > low else 0) if active else 0
            blocks.append(Block(bx, by, pixels, nonzero, b, high, low,
                                active, tuple(hist)))
    assert len(blocks) == nx * ny
    return blocks, classes, one_pass(classes, WIDTH) if edges else None


def fixed_frame(magnitudes, low=50, high=100):
    if not 0 <= low < high <= 2047:
        raise ValueError("invalid fixed pair")
    classes = bytearray(2 if mag > high else 1 if mag > low else 0
                        for mag in magnitudes)
    return classes, one_pass(classes, WIDTH)


def counter_width(block_size):
    return (block_size * block_size + 1 - 1).bit_length()
