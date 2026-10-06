"""Strict greater-than NMS on the center's one-hot direction."""
from .window import Matrix3x3


class NMS:
    def __init__(self, width: int = 640):
        self.matrix = Matrix3x3(width, 17)
        self.vs = self.hs = self.de = self.klass = 0

    @property
    def outputs(self) -> tuple[int, int, int, int]:
        return self.vs, self.hs, self.de, self.klass

    def tick(self, vs: int, hs: int, de: int, path: int) -> None:
        p = self.matrix.p
        old_vs, old_hs, old_de = self.matrix.controls
        center = p[4]
        direction = (center >> 11) & 15
        neighbor_indices = {1: (3, 5), 2: (2, 6),
                            4: (1, 7), 8: (0, 8)}
        if direction in neighbor_indices:
            a, b = neighbor_indices[direction]
            mag = center & 0x7ff
            self.klass = (center >> 15) & 3 if (
                mag > (p[a] & 0x7ff) and mag > (p[b] & 0x7ff)) else 0
        else:
            self.klass = 0
        self.vs, self.hs, self.de = old_vs, old_hs, old_de
        self.matrix.tick(vs, hs, de, path)
