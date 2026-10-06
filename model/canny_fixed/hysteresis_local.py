"""Inherited one-pass local weak-edge promotion, not recursive hysteresis."""
from .window import Matrix3x3


class LocalPromotion:
    def __init__(self, width: int = 640):
        self.matrix = Matrix3x3(width, 2)
        self.vs = self.hs = self.de = self.edge = 0

    @property
    def outputs(self) -> tuple[int, int, int, int]:
        return self.vs, self.hs, self.de, self.edge

    def tick(self, vs: int, hs: int, de: int, klass: int) -> None:
        p = self.matrix.p
        old_vs, old_hs, old_de = self.matrix.controls
        self.edge = int(bool(p[4]) and any(value & 2 for value in p))
        self.vs, self.hs, self.de = old_vs, old_hs, old_de
        self.matrix.tick(vs, hs, de, klass)
