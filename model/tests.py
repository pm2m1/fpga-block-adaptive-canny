r"""Fast unit tests for Phase 5 hardware-equivalent integer stages.

Run: C:\Program Files\Python312\python.exe -m model.tests
"""
from __future__ import annotations
from pathlib import Path

from model.canny_fixed.fixed import signed, unsigned, saturate_unsigned
from model.canny_fixed.gaussian import Gaussian
from model.canny_fixed.sobel import SobelGradient
from model.canny_fixed.nms import NMS
from model.canny_fixed.hysteresis_local import LocalPromotion
from model.canny_fixed.pipeline import CannyPipeline
from model.cordic_reference import fixed, sweep


def pack(mag: int, direction: int, klass: int) -> int:
    return (klass << 15) | (direction << 11) | mag


def run() -> None:
    assert unsigned(-1, 11) == 2047
    assert signed(0x3ff, 10) == -1
    assert saturate_unsigned(3000, 11) == 2047

    gaussian = Gaussian()
    gaussian.matrix.p = list(range(1, 10))
    gaussian.tick(0, 0, 0, 0)
    assert gaussian.row_sums == (8, 40, 32)
    gaussian.tick(0, 0, 0, 0)
    assert gaussian.outputs[3] == 5  # floor(80/16)

    sobel = SobelGradient()
    sobel.matrix.p = [0, 0, 255, 0, 0, 255, 0, 0, 255]
    sobel.tick(0, 0, 0, 0)
    assert sobel.sums == (0, 1020, 255, 255)
    sobel.tick(0, 0, 0, 0)
    assert (sobel.abs_gx, sobel.abs_gy, sobel.sign_gx, sobel.sign_gy) == (1020, 0, 0, 1)

    for gx, gy, sx, sy, direction in (
        (0, 0, 1, 1, 1), (1020, 0, 1, 1, 1),
        (0, 1020, 1, 1, 4), (1020, 1020, 1, 1, 8),
        (1020, 1020, 1, 0, 2)):
        assert fixed(gx, gy, sx, sy)[1] == direction

    gradient = SobelGradient()
    for mag, expected_class in ((0, 0), (50, 0), (51, 1),
                                (100, 1), (101, 2), (1442, 2)):
        gradient.cordic.output = (mag, 1, 1, 1, 1)
        gradient.tick(0, 0, 0, 0)
        assert (gradient.path >> 15) == expected_class

    nms = NMS()
    nms.matrix.p = [0] * 9
    nms.matrix.p[4] = pack(100, 1, 2)
    nms.matrix.p[3] = pack(99, 1, 1)
    nms.matrix.p[5] = pack(99, 1, 1)
    nms.tick(0, 0, 0, 0)
    assert nms.klass == 2
    nms.matrix.p = [0] * 9
    nms.matrix.p[4] = pack(100, 1, 2)
    nms.matrix.p[3] = pack(100, 1, 1)  # equal magnitude suppresses
    nms.tick(0, 0, 0, 0)
    assert nms.klass == 0
    for direction, neighbors in ((2, (2, 6)), (4, (1, 7)), (8, (0, 8))):
        nms.matrix.p = [0] * 9
        nms.matrix.p[4] = pack(100, direction, 1)
        for index in neighbors:
            nms.matrix.p[index] = pack(99, 1, 1)
        nms.tick(0, 0, 0, 0)
        assert nms.klass == 1

    local = LocalPromotion()
    local.matrix.p = [0, 0, 0, 0, 1, 2, 0, 0, 0]
    local.tick(0, 0, 0, 0)
    assert local.edge == 1
    local.matrix.p = [0, 0, 0, 0, 1, 1, 0, 0, 0]
    local.tick(0, 0, 0, 0)
    assert local.edge == 0  # weak-to-weak is not recursive linking
    local.matrix.p = [0, 0, 0, 0, 2, 0, 0, 0, 0]
    local.tick(0, 0, 0, 0)
    assert local.edge == 1

    pipeline = CannyPipeline()
    for _ in range(100):
        pipeline.tick(0, 0, 0, 0)
    assert pipeline.sampled()["edge"][3] == 0

    root = Path(__file__).resolve().parents[1]
    report = root / "reports/phase5_cordic_software_metrics.txt"
    sweep(report)
    previous = (root / "reports/phase4_cordic_software_metrics.txt").read_text(
        encoding="utf-8")
    assert report.read_text(encoding="utf-8") == previous, (
        "Phase 5 CORDIC sweep changed from verified Phase 4 metrics")
    print("PHASE5_UNIT_TESTS PASS")


if __name__ == "__main__":
    run()
