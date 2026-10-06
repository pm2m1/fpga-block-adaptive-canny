"""Clock-by-clock composition of the verified Phase 4B top.

Every tick samples *old* upstream outputs, matching nonblocking RTL edges.
Post-tick properties correspond to simulator values at posedge + 1 ns.
"""
from .gaussian import Gaussian
from .sobel import SobelGradient
from .nms import NMS
from .hysteresis_local import LocalPromotion


class CannyPipeline:
    def __init__(self, width: int = 640):
        self.gaussian = Gaussian(width)
        self.gradient = SobelGradient(width)
        self.nms = NMS(width)
        self.local = LocalPromotion(width)

    def tick(self, vs: int, hs: int, de: int, gray: int) -> None:
        gauss_old = self.gaussian.outputs
        grad_old = self.gradient.outputs
        nms_old = self.nms.outputs
        self.local.tick(*nms_old)
        self.nms.tick(*grad_old)
        self.gradient.tick(*gauss_old)
        self.gaussian.tick(vs, hs, de, gray)

    def sampled(self) -> dict[str, tuple[int, ...]]:
        return {
            "gaussian": self.gaussian.outputs,
            "sobel": self.gradient.sobel_debug,
            "cordic": self.gradient.cordic_debug,
            "threshold": self.gradient.outputs,
            "nms": self.nms.outputs,
            "edge": self.local.outputs,
        }
