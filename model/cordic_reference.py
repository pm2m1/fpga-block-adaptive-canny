r"""Phase-4 fixed-point vectoring CORDIC and independent ideal reference.

Run with an explicit installed Python interpreter, e.g.
  C:\Program Files\Python312\python.exe model/cordic_reference.py --sweep --vectors
No OpenCV, floating point, or division is used in the intended RTL model.
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

ITERATIONS = 16
XY_W = 26
XY_FRAC = 12
ANGLE_FRAC = 16
MAG_W = 11
GAIN_INV_Q16 = 39797  # round(2^16 / product(sqrt(1+2^(-2*i)), i=0..15))
ATAN_Q16 = (2949120, 1740967, 919879, 466945, 234379, 117304, 58666,
            29335, 14668, 7334, 3667, 1833, 917, 458, 229, 115)
DEG_22_5_Q16 = 1474560
DEG_67_5_Q16 = 4423680


def fixed(gx: int, gy: int, sx: int = 1, sy: int = 1) -> tuple[int, int, int, bool, bool]:
    """Return (11-bit magnitude, one-hot NMS direction, angle_q16, overflow, clamp).

    sx/sy are Sobel signs (1 nonnegative, 0 negative), not pixel coordinates.
    This exactly follows the intended signed, arithmetic-shift RTL recurrence.
    """
    assert 0 <= gx <= 1020 and 0 <= gy <= 1020
    x, y, angle = gx << XY_FRAC, gy << XY_FRAC, 0
    overflow = False
    for i, atan in enumerate(ATAN_Q16):
        if y >= 0:
            nx, ny, na = x + (y >> i), y - (x >> i), angle + atan
        else:
            nx, ny, na = x - (y >> i), y + (x >> i), angle - atan
        x, y, angle = nx, ny, na
        overflow |= not (-(1 << (XY_W - 1)) <= x < (1 << (XY_W - 1)))
        overflow |= not (-(1 << (XY_W - 1)) <= y < (1 << (XY_W - 1)))
    raw = (x * GAIN_INV_Q16) >> (XY_FRAC + 16)
    clamp = raw > (1 << MAG_W) - 1
    magnitude = max(0, min(raw, (1 << MAG_W) - 1))
    if gx == 0 and gy == 0 or angle < DEG_22_5_Q16:
        direction = 1  # compare left and right
    elif angle >= DEG_67_5_Q16:
        direction = 4  # compare top and bottom
    else:
        direction = 8 if sx == sy else 2  # image y points downward
    return magnitude, direction, angle, overflow, clamp


def ideal(gx: int, gy: int, sx: int = 1, sy: int = 1) -> tuple[float, int, float]:
    """Independent high-precision hypot/atan2 reference and four-bin direction."""
    magnitude = math.hypot(gx, gy)
    angle = math.degrees(math.atan2(gy, gx)) if (gx or gy) else 0.0
    if angle < 22.5:
        direction = 1
    elif angle >= 67.5:
        direction = 4
    else:
        direction = 8 if sx == sy else 2
    return magnitude, direction, angle


def sweep(report: Path) -> None:
    n = 1021 * 1021
    min_mag, max_mag = 2047, 0
    max_error, sum_error, sum_sq = 0.0, 0.0, 0.0
    overflows = clamps = wraps = direction_mismatches = 0
    max_boundary_distance = 0.0
    mono_decreases_x = mono_decreases_y = 0
    prev_y = [None] * 1021
    for gx in range(1021):
        prev_x = None
        for gy in range(1021):
            mag, direction, _, overflow, clamp = fixed(gx, gy)
            im, idir, ia = ideal(gx, gy)
            err = abs(mag - im)
            min_mag, max_mag = min(min_mag, mag), max(max_mag, mag)
            max_error = max(max_error, err)
            sum_error += err
            sum_sq += err * err
            overflows += overflow
            clamps += clamp
            wraps += int(not 0 <= mag <= 2047)
            if direction != idir:
                direction_mismatches += 1
                max_boundary_distance = max(max_boundary_distance,
                                            min(abs(ia - 22.5), abs(ia - 67.5)))
            if prev_x is not None and mag < prev_x:
                mono_decreases_y += 1
            if prev_y[gy] is not None and mag < prev_y[gy]:
                mono_decreases_x += 1
            prev_x, prev_y[gy] = mag, mag
    lines = [
        f"vectors_tested={n}", f"minimum_magnitude={min_mag}",
        f"maximum_magnitude={max_mag}",
        f"maximum_absolute_error={max_error:.9f}",
        f"mean_absolute_error={sum_error / n:.9f}",
        f"rms_error={math.sqrt(sum_sq / n):.9f}",
        f"internal_overflow_count={overflows}", f"output_clamp_count={clamps}",
        f"wraparound_count={wraps}",
        f"ideal_direction_disagreement_count={direction_mismatches}",
        f"maximum_boundary_distance_degrees={max_boundary_distance:.9f}",
        f"monotonicity_decreases_with_increasing_gx={mono_decreases_x}",
        f"monotonicity_decreases_with_increasing_gy={mono_decreases_y}",
    ]
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    assert overflows == 0 and wraps == 0 and clamps == 0


def vectors(path: Path, random_count: int = 20000) -> None:
    """rst_n gx gy sx sy valid expected_mag expected_dir, one row/cycle."""
    rng = random.Random(0xC0D1C4)
    directed = [(0,0),(1,0),(0,1),(1020,0),(0,1020),(1,1),
                (100,100),(1020,1020),(1020,1),(1,1020),
                (1000,500),(500,1000)]
    for x in (100, 500, 1000):
        for boundary in (22.5, 67.5):
            y = round(x * math.tan(math.radians(boundary)))
            for offset in (-2, -1, 0, 1, 2):
                if 0 <= y + offset <= 1020:
                    directed.append((x, y + offset))
    rows = [(0,0,0,1,1,0,0,1)] * 3
    for sx in (0,1):
        for sy in (0,1):
            for gx,gy in directed:
                mag,direction,*_ = fixed(gx,gy,sx,sy)
                rows.append((1,gx,gy,sx,sy,1,mag,direction))
                rows.append((1,0,0,1,1,0,0,1))  # valid bubble
    rows += [(0,0,0,1,1,0,0,1)] * 2  # reset while idle
    for _ in range(random_count):
        gx,gy = rng.randrange(1021),rng.randrange(1021)
        sx,sy = rng.randrange(2),rng.randrange(2)
        valid = 0 if rng.randrange(5)==0 else 1
        mag,direction,*_ = fixed(gx,gy,sx,sy)
        rows.append((1,gx,gy,sx,sy,valid,mag,direction))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(" ".join(map(str,row))+"\n" for row in rows),encoding="ascii")
    print(f"vector_file={path} cycles={len(rows)} valid_vectors={sum(r[5] for r in rows)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sweep", action="store_true")
    parser.add_argument("--vectors", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.sweep:
        sweep(root / "reports/phase4_cordic_software_metrics.txt")
    if args.vectors:
        vectors(root / "results/phase4/cordic_vectors.txt")
