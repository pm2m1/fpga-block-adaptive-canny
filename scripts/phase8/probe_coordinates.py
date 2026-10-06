"""Probe Phase 5B 3x3 center-tag association in output-raster coordinates."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.phase5b.window import Matrix3x3Phase5B

WIDTH = 640
HEIGHT = 8


def main():
    matrix = Matrix3x3Phase5B(WIDTH, 20)
    valid = 0
    probes = {}
    wanted = {(0, 0), (0, 1), (1, 1), (2, 1), (10, 3), (100, 5), (639, 5)}
    def tick(vs, hs, de, value):
        nonlocal valid
        _, old_hs, old_de = matrix.controls
        center = matrix.p[4]
        if old_hs and old_de:
            coordinate = (valid % WIDTH, valid // WIDTH)
            if coordinate in wanted:
                probes[coordinate] = None if center == 0 else (
                    (center - 1) % WIDTH, (center - 1) // WIDTH)
            valid += 1
        matrix.tick(vs, hs, de, value)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            tick(1, 1, 1, y * WIDTH + x + 1)
        for _ in range(24):
            tick(1, 0, 0, 0)
    for _ in range(8):
        tick(0, 0, 0, 0)
    assert valid == WIDTH * HEIGHT
    assert probes[(10, 3)] == (9, 2)
    assert probes[(100, 5)] == (99, 4)
    assert probes[(0, 1)] is None
    assert probes[(1, 1)] == (0, 0)
    for output, center in sorted(probes.items()):
        print(f"output_sample={output} window_center={center}")
    print(f"PHASE8_COORDINATE_PROBE_PASS valid={valid}")


if __name__ == "__main__":
    main()
