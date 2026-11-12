"""The canvas of the painting lab (TEST_PLAN.md): paint over a bare surface, as the show's skin holds it.

As the show holds it (skin_paint.gdshader into prop.gdshader): paint is kept as sRGB times its coverage (`pre`) and its coverage
(`alp`); a mark of color c and coverage a lays `pre = c a + pre (1 - a)`, `alp = a + alp (1 - a)`; what shows is the bare surface
by what is left uncovered and the paint's own color, decoded, by its coverage. The lab keeps the show's rule, so a mark list painted
here can be played there as it was judged here.

When each point was last painted (`laid_t`, the painting's clock in seconds): wet paint blends with what touches it, dry paint is
gone over (marks.wet_blend).
"""
import numpy as np

from color import dec, oklab

PX = 4.0          # pixels a millimeter: the show's own (PaintLayers.FOOT_PX)


class Canvas:
    def __init__(self, h, w, bare, face):
        self.h, self.w = h, w
        self.pre = np.zeros((h, w, 3))
        self.alp = np.zeros((h, w))
        self.bare_lin = dec(np.asarray(bare, dtype=float))
        self.face = face.astype(bool)
        self.laid_t = np.full((h, w), -1e9)

    def copy(self):
        c = Canvas.__new__(Canvas)
        c.h, c.w, c.bare_lin, c.face = self.h, self.w, self.bare_lin, self.face
        c.pre, c.alp, c.laid_t = self.pre.copy(), self.alp.copy(), self.laid_t.copy()
        return c

    @staticmethod
    def shown_of(pre, alp, bare_lin):
        """What shows (linear RGB) for paint `pre`, `alp` over the bare surface."""
        a = alp[..., None]
        col = np.where(a > 1e-5, pre / np.maximum(a, 1e-5), 0.0)
        return bare_lin * (1.0 - a) + dec(col) * a

    def shown(self, sl=np.s_[:, :]):
        return Canvas.shown_of(self.pre[sl], self.alp[sl], self.bare_lin)

    def lab(self, sl=np.s_[:, :]):
        return oklab(self.shown(sl))

    @staticmethod
    def over(pre, alp, a, c):
        """Coverage `a` (h, w) of color `c` (sRGB, (3,) or (h, w, 3)) laid over `pre`, `alp`: the new pair."""
        a3 = a[..., None]
        return c * a3 + pre * (1.0 - a3), a + alp * (1.0 - a)

    def lay(self, sl, pre, alp, t):
        """The canvas over `sl` made `pre`, `alp`, painted at moment `t` wherever it changed."""
        changed = np.abs(alp - self.alp[sl]) > 1e-3
        self.pre[sl] = pre
        self.alp[sl] = alp
        lt = self.laid_t[sl]
        lt[changed] = t
        self.laid_t[sl] = lt

    def picture(self):
        """The canvas as an sRGB uint8 image, the bare surface where nothing is."""
        from color import enc
        return (np.clip(enc(self.shown()), 0, 1) * 255 + 0.5).astype(np.uint8)
