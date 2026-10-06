"""Reuse the verified Phase-4 bit-accurate CORDIC model unchanged."""
from collections import deque
from model.cordic_reference import fixed, ITERATIONS, XY_W, XY_FRAC, MAG_W


class CordicPipeline:
    LATENCY = 18

    def __init__(self):
        self.pipe = deque([(0, 1, 0, 0, 0)] * self.LATENCY,
                          maxlen=self.LATENCY)
        self.output = (0, 1, 0, 0, 0)  # magnitude, direction, vs, hs, valid

    def tick(self, abs_gx: int, abs_gy: int, sign_gx: int, sign_gy: int,
             vs: int, hs: int, valid: int) -> None:
        magnitude, direction, _, overflow, clamp = fixed(
            abs_gx, abs_gy, sign_gx, sign_gy)
        if overflow:
            raise AssertionError("Legal Sobel vector overflowed CORDIC")
        self.pipe.appendleft((magnitude, direction, vs, hs, valid))
        self.output = self.pipe[-1]
