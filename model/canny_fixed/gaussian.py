"""The inherited 12-bit three-row Gaussian arithmetic, floor /16."""
from .window import Matrix3x3


class Gaussian:
    def __init__(self, width: int = 640):
        self.matrix = Matrix3x3(width, 8)
        self.row_sums = (0, 0, 0)
        self.sum_gray = 0
        self.vs1 = self.vs2 = 0
        self.hs1 = self.hs2 = 0
        self.de1 = self.de2 = 0

    @property
    def outputs(self) -> tuple[int, int, int, int]:
        return self.vs2, self.hs2, self.de2, self.sum_gray >> 4

    def tick(self, vs: int, hs: int, de: int, pixel: int) -> None:
        p = self.matrix.p
        old_sums = self.row_sums
        old_vs, old_hs, old_de = self.matrix.controls
        self.matrix.tick(vs, hs, de, pixel)
        self.row_sums = ((p[0] + (p[1] << 1) + p[2]) & 0xfff,
                         ((p[3] << 1) + (p[4] << 2) + (p[5] << 1)) & 0xfff,
                         (p[6] + (p[7] << 1) + p[8]) & 0xfff)
        self.sum_gray = sum(old_sums) & 0xfff
        self.vs1, self.vs2 = old_vs, self.vs1
        self.hs1, self.hs2 = old_hs, self.hs1
        self.de1, self.de2 = old_de, self.de1
