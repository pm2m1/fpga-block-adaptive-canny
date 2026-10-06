"""Exact clocked 3x3 matrix/line-buffer behavior from the inherited RTL.

FIFO memory/pointers initialize once, never reset at a frame boundary. Matrix
horizontal registers clear when delayed href falls. Reads see pre-edge RAM
contents even on simultaneous read/write, matching nonblocking assignments.
"""
from __future__ import annotations


class FifoRam:
    def __init__(self, depth: int, width: int):
        self.mem = [0] * depth
        self.depth = depth
        self.mask = (1 << width) - 1
        self.rd_pointer = 0
        self.wr_pointer = 0
        self.rd_data = 0

    def tick(self, wr_en: int, wr_data: int, rd_en: int) -> None:
        read = self.mem[self.rd_pointer] if rd_en else 0
        if wr_en:
            self.mem[self.wr_pointer] = wr_data & self.mask
            self.wr_pointer = (self.wr_pointer + 1) % self.depth
        if rd_en:
            self.rd_pointer = (self.rd_pointer + 1) % self.depth
        self.rd_data = read


class OneColumnRam:
    def __init__(self, depth: int, width: int):
        self.fifo0 = FifoRam(depth, width)
        self.fifo1 = FifoRam(depth, width)
        self.clken_d1 = self.clken_d2 = 0
        self.shiftin_d1 = self.shiftin_d2 = 0
        self.fifo_rd_data0_d1 = 0

    @property
    def taps(self) -> tuple[int, int, int]:
        return self.shiftin_d1, self.fifo0.rd_data, self.fifo1.rd_data

    def tick(self, clken: int, shiftin: int) -> None:
        old_clken_d1, old_clken_d2 = self.clken_d1, self.clken_d2
        old_shiftin_d1, old_shiftin_d2 = self.shiftin_d1, self.shiftin_d2
        old_fifo0_data = self.fifo0.rd_data
        old_fifo0_d1 = self.fifo_rd_data0_d1
        self.fifo0.tick(old_clken_d2, old_shiftin_d2, clken)
        self.fifo1.tick(old_clken_d2, old_fifo0_d1, clken)
        self.clken_d1, self.clken_d2 = clken, old_clken_d1
        self.shiftin_d1, self.shiftin_d2 = shiftin, old_shiftin_d1
        self.fifo_rd_data0_d1 = old_fifo0_data


class Matrix3x3:
    def __init__(self, depth: int, width: int):
        self.column = OneColumnRam(depth, width)
        self.p = [0] * 9
        self.vs0 = self.vs1 = 0
        self.hs0 = self.hs1 = 0
        self.de0 = self.de1 = 0

    @property
    def controls(self) -> tuple[int, int, int]:
        return self.vs1, self.hs1, self.de1

    def tick(self, vs: int, hs: int, de: int, pixel: int) -> None:
        old_tap3, old_tap2, old_tap1 = self.column.taps
        if self.hs0:
            if self.de0:
                p = self.p
                self.p = [p[1], p[2], old_tap1,
                          p[4], p[5], old_tap2,
                          p[7], p[8], old_tap3]
        else:
            self.p = [0] * 9
        self.column.tick(de, pixel)
        self.vs0, self.vs1 = vs, self.vs0
        self.hs0, self.hs1 = hs, self.hs0
        self.de0, self.de1 = de, self.de0
