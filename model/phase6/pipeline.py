"""Phase 5B pipeline, replacing only frame-atomic threshold classification."""
from model.canny_fixed.sobel import SobelGradient
from model.phase5b.pipeline import CannyPipeline as Phase5BPipeline
from model.phase5b.window import Matrix3x3Phase5B
from .classification import classify, validate_thresholds


class SobelGradientPhase6(SobelGradient):
    def __init__(self, width: int):
        super().__init__(width)
        self.matrix = Matrix3x3Phase5B(width, 8)
        self.threshold_low_active = 50
        self.threshold_high_active = 100

    def tick(self, vs: int, hs: int, de: int, pixel: int) -> None:
        old_mag, old_dir, _, _, _ = self.cordic.output
        super().tick(vs, hs, de, pixel)
        self.path = classify(old_mag, old_dir,
                             self.threshold_low_active,
                             self.threshold_high_active)


class CannyPipeline(Phase5BPipeline):
    def __init__(self, width: int = 640):
        super().__init__(width)
        self.gradient = SobelGradientPhase6(width)
        self.threshold_low_active = 50
        self.threshold_high_active = 100
        self.frame_vsync_d = 0

    def tick(self, vs: int, hs: int, de: int, gray: int,
             threshold_low_i: int, threshold_high_i: int) -> None:
        # All stage ticks see pre-edge registers, just as in nonblocking RTL.
        self.gradient.threshold_low_active = self.threshold_low_active
        self.gradient.threshold_high_active = self.threshold_high_active
        super().tick(vs, hs, de, gray)
        if vs and not self.frame_vsync_d:
            validate_thresholds(threshold_low_i, threshold_high_i)
            self.threshold_low_active = threshold_low_i
            self.threshold_high_active = threshold_high_i
        self.frame_vsync_d = vs
