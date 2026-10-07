"""The base head (pixels + mask) that every outfit frame keeps untouched, and the base skin colors."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, '..', 'customization'))
from cloth_zone import zone_frame  # noqa: E402  (customization/cloth_zone.py: head zone of the mask)

FR = 96
STEP = 40
N8 = np.ones((3, 3), bool)


def head_pixels(base, mask):
    """Head of the base frame (face, neck skin, eyes, shaved hair and their outline), without the Viajante
    clothes that fall inside the head zone (hood collar, T-shirt, straps): the outfit replaces those.
    head core = connected pieces of mask channels (R/G/B) inside the head zone that hold hair (B) or eyes (G);
    it ends at the neck (chin line = lowest row of the core). Unmarked pixels of the zone (alpha 128: outlines,
    mouth, ears) count only above that line and touching the core."""
    op = base[..., 3] > 0
    zone = zone_frame(mask)
    chan = op & zone & (mask[..., :3].max(axis=2) > 5)
    lab, n = ndi.label(chan, N8)
    if n == 0:
        return np.zeros(op.shape, bool)
    hairy = np.unique(lab[(mask[..., 1] > 5) | (mask[..., 2] > 5)])
    core = np.isin(lab, hairy[hairy > 0])
    if not core.any():
        return np.zeros(op.shape, bool)
    chin = np.nonzero(core.any(axis=1))[0].max()
    lit = op & zone & (mask[..., 3] == 128) & ~chan
    lit[chin + 1:] = False
    # outlines/mouth/ears: unmarked pixels reachable from the core without leaving the zone above the chin
    grow = core.copy()
    for _ in range(3):
        grow |= ndi.binary_dilation(grow, N8) & lit
    return grow


def head_box(hp):
    ys, xs = np.nonzero(hp)
    if len(ys) == 0:
        return None
    return ys.min(), ys.max(), xs.min(), xs.max()


def skin_table(base, mask):
    """{rgb: R value} of the base skin colors (literal colors under mask R)."""
    sel = (base[..., 3] > 0) & (mask[..., 0] > 5)
    t = {}
    for c, r in zip(map(tuple, base[sel][:, :3]), mask[sel][:, 0]):
        t[c] = int(r)
    return t
