"""Exact two-stage Sobel arithmetic and packed class register."""
from .window import Matrix3x3
from .cordic import CordicPipeline


class SobelGradient:
    def __init__(self, width: int = 640):
        self.matrix = Matrix3x3(width, 8)
        self.cordic = CordicPipeline()
        self.sums = (0, 0, 0, 0)  # left, right, top, bottom
        self.abs_gx = self.abs_gy = 0
        self.sign_gx = self.sign_gy = 1
        self.vs0 = self.vs1 = self.hs0 = self.hs1 = 0
        self.de0 = self.de1 = 0
        self.vs = self.hs = self.de = self.path = 0

    @property
    def outputs(self) -> tuple[int, int, int, int]:
        return self.vs, self.hs, self.de, self.path

    @property
    def sobel_debug(self) -> tuple[int, int, int, int, int]:
        return self.abs_gx, self.abs_gy, self.sign_gx, self.sign_gy, self.de1 & self.hs1

    @property
    def cordic_debug(self) -> tuple[int, int, int]:
        mag, direction, _, hs, de = self.cordic.output
        return mag, direction, hs & de

    def tick(self, vs: int, hs: int, de: int, pixel: int) -> None:
        p = self.matrix.p
        left, right, top, bottom = self.sums
        matrix_vs, matrix_hs, matrix_de = self.matrix.controls
        old_mag, old_dir, old_vs, old_hs, old_de = self.cordic.output
        self.matrix.tick(vs, hs, de, pixel)
        self.cordic.tick(self.abs_gx, self.abs_gy, self.sign_gx, self.sign_gy,
                         self.vs1, self.hs1, self.de1)
        self.sums = ((p[0] + 2 * p[3] + p[6]) & 0x3ff,
                     (p[2] + 2 * p[5] + p[8]) & 0x3ff,
                     (p[0] + 2 * p[1] + p[2]) & 0x3ff,
                     (p[6] + 2 * p[7] + p[8]) & 0x3ff)
        self.abs_gx, self.abs_gy = abs(left - right), abs(top - bottom)
        self.sign_gx, self.sign_gy = int(left >= right), int(top >= bottom)
        self.vs0, self.vs1 = matrix_vs, self.vs0
        self.hs0, self.hs1 = matrix_hs, self.hs0
        self.de0, self.de1 = matrix_de, self.de0
        if old_mag > 100:
            self.path = (2 << 15) | (old_dir << 11) | old_mag
        elif old_mag > 50:
            self.path = (1 << 15) | (old_dir << 11) | old_mag
        else:
            self.path = 0
        self.vs, self.hs, self.de = old_vs, old_hs, old_de
