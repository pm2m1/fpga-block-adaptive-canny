"""Cycle-exact shared front-end model through 11-bit suppressed magnitude."""
from model.canny_fixed.gaussian import Gaussian
from model.canny_fixed.sobel import SobelGradient
from model.canny_fixed.nms import NMS
from model.phase5b.window import Matrix3x3Phase5B


class RawGradient(SobelGradient):
    def __init__(self,width=640):
        super().__init__(width)
        self.matrix=Matrix3x3Phase5B(width,8)

    def tick(self,vs,hs,de,pixel):
        old_mag,old_direction,*_=self.cordic.output
        super().tick(vs,hs,de,pixel)
        self.path=(old_direction<<11)|old_mag


class NmsMagnitude(NMS):
    def __init__(self,width=640):
        super().__init__(width)
        self.matrix=Matrix3x3Phase5B(width,15)

    def tick(self,vs,hs,de,path):
        p=self.matrix.p
        old_vs,old_hs,old_de=self.matrix.controls
        center=p[4]
        direction=(center>>11)&15
        neighbors={1:(3,5),2:(2,6),4:(1,7),8:(0,8)}
        self.klass=0
        if direction in neighbors:
            a,b=neighbors[direction]
            mag=center&2047
            if mag>(p[a]&2047) and mag>(p[b]&2047):
                self.klass=mag
        self.vs,self.hs,self.de=old_vs,old_hs,old_de
        self.matrix.tick(vs,hs,de,path)


class Frontend:
    def __init__(self,width=640):
        self.gaussian=Gaussian(width)
        self.gaussian.matrix=Matrix3x3Phase5B(width,8)
        self.gradient=RawGradient(width)
        self.nms=NmsMagnitude(width)

    def tick(self,vs,hs,de,pixel):
        gauss_old=self.gaussian.outputs
        gradient_old=self.gradient.outputs
        self.nms.tick(*gradient_old)
        self.gradient.tick(*gauss_old)
        self.gaussian.tick(vs,hs,de,pixel)

    @property
    def output(self):
        return self.nms.outputs
