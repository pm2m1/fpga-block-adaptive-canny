"""Phase 5B frame-local validity on top of the historic, persistent FIFO model."""
from model.canny_fixed.window import Matrix3x3


class Matrix3x3Phase5B(Matrix3x3):
    def __init__(self, depth: int, width: int):
        super().__init__(depth, width)
        self.lines_seen = 0
        self.frame_vsync_d = 0
        self.frame_href_d = 0

    def tick(self, vs: int, hs: int, de: int, pixel: int) -> None:
        old_tap3, old_tap2, old_tap1 = self.column.taps
        if self.hs0:
            if self.de0:
                p = self.p
                top = old_tap1 if self.lines_seen >= 3 else 0
                middle = old_tap2 if self.lines_seen >= 2 else 0
                self.p = [p[1], p[2], top,
                          p[4], p[5], middle,
                          p[7], p[8], old_tap3]
        else:
            self.p = [0] * 9
        self.column.tick(de, pixel)
        self.vs0, self.vs1 = vs, self.vs0
        self.hs0, self.hs1 = hs, self.hs0
        self.de0, self.de1 = de, self.de0
        if vs and not self.frame_vsync_d:
            self.lines_seen = 1 if hs else 0
        elif vs and hs and not self.frame_href_d:
            self.lines_seen = min(3, self.lines_seen + 1)
        self.frame_vsync_d = vs
        self.frame_href_d = hs
