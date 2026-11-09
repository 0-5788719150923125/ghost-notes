"""Color for the painting lab (TEST_PLAN.md): the show's own encoding, OKLab for judging, and paints mixed as pigments.

THE SHOW'S ENCODING: the skin shader holds paint as sRGB and prop.gdshader decodes it with a plain `pow 2.2`, never the sRGB
curve - so the lab decodes the same way, or a color matched here would come out another shade there.

OKLAB, x100: a difference of 1 is about the least an eye sees side by side; 10 is plainly another color (the engine's `NEED`).

PIGMENTS DARKEN AS THEY MIX: a mix is the weighted geometric mean of the two paints' linear light, never their average - teal and
red a muddy brown, never a lilac (PaintLayers._mixes, the same rule).
"""
import numpy as np

GAMMA = 2.2


def dec(c):
    """sRGB (0-1) to linear light, as prop.gdshader decodes it."""
    return np.power(np.clip(c, 0.0, 1.0), GAMMA)


def enc(c):
    """Linear light to sRGB (0-1)."""
    return np.power(np.clip(c, 0.0, 1.0), 1.0 / GAMMA)


def hex_rgb(h):
    """'#rrggbb' to sRGB floats."""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]])
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]])


def oklab(lin):
    """Linear RGB (..., 3) to OKLab x100 (..., 3)."""
    lms = np.cbrt(np.maximum(lin @ _M1.T, 0.0))
    return (lms @ _M2.T) * 100.0


def mix(a, b, t):
    """Paints a and b (sRGB) mixed, t of b: the weighted geometric mean of their linear light."""
    la = np.maximum(dec(a), 1e-4)
    lb = np.maximum(dec(b), 1e-4)
    return enc(np.power(la, 1.0 - t) * np.power(lb, t))


def delta(lab_a, lab_b):
    """OKLab difference, x100."""
    return np.sqrt(np.sum((lab_a - lab_b) ** 2, axis=-1))
