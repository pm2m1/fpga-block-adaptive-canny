"""Exact Phase 5 arithmetic, replacing only the four window border policies."""
from model.canny_fixed.pipeline import CannyPipeline as HistoricPipeline
from .window import Matrix3x3Phase5B


class CannyPipeline(HistoricPipeline):
    def __init__(self, width: int = 640):
        super().__init__(width)
        for stage, bit_width in ((self.gaussian, 8), (self.gradient, 8),
                                 (self.nms, 17), (self.local, 2)):
            stage.matrix = Matrix3x3Phase5B(width, bit_width)
