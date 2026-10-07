"""AI edit (big image, white background) -> 96x96 frame registered on the base key frame."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

FR = 96


def cutout(path):
    """RGBA of the AI image: near-white background removed by flood fill from the border; soft shadows too."""
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    mn = a.min(axis=2)
    sat = a.max(axis=2) - mn
    bgish = (mn > 200) & (sat < 30)          # white / light gray
    # the AI ground shadow (gray/tan ellipse at the feet): lighter threshold in the lowest part of the figure
    rows = np.nonzero((~bgish).any(axis=1))[0]
    if len(rows):
        y0 = rows.max() - int((rows.max() - rows.min()) * 0.08)
        low = np.zeros_like(bgish); low[y0:] = True
        bgish |= low & (mn > 135) & (sat < 45)
    lab, n = ndi.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # enclosed background (gap between the legs, under an arm): same color as the border background
    ref = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    near = np.abs(a - ref).sum(axis=2) < 18
    lab2, n2 = ndi.label(near & ~bg)
    if n2:
        sz = np.bincount(lab2.ravel()); sz[0] = 0
        bg |= (sz >= max(40, a.shape[0] * a.shape[1] // 4000))[lab2]
    fg = ~bg
    fg = ndi.binary_opening(fg, iterations=1)
    lab, n = ndi.label(fg)
    if n > 1:
        sz = np.bincount(lab.ravel()); sz[0] = 0
        keep = sz >= sz.max() * 0.02; keep[0] = False
        fg = keep[lab]
    out = np.zeros(a.shape[:2] + (4,), np.uint8)
    out[..., :3] = a
    out[..., 3] = fg * 255
    return out


def _resize_rgba(a, s):
    h, w = a.shape[:2]
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    im = Image.fromarray(a, 'RGBA')
    # premultiplied BOX so the background does not bleed into edge colors
    rgb = np.array(im.convert('RGB').resize((nw, nh), Image.BOX)).astype(float)
    al = np.array(im.getchannel('A').resize((nw, nh), Image.BOX)).astype(float) / 255
    pm = a[..., :3].astype(float) * (a[..., 3:4] / 255)
    pmr = np.stack([np.array(Image.fromarray(pm[..., i].astype(np.float32), 'F').resize((nw, nh), Image.BOX)) for i in range(3)], -1)
    col = np.where(al[..., None] > 1e-3, pmr / np.maximum(al[..., None], 1e-3), rgb)
    o = np.zeros((nh, nw, 4), np.uint8)
    o[..., :3] = np.clip(col, 0, 255)
    o[..., 3] = (al > 0.5) * 255
    return o


def _place(small, ox, oy):
    """Paste small at (ox, oy) in a 96x96 frame."""
    o = np.zeros((FR, FR, 4), np.uint8)
    h, w = small.shape[:2]
    x0, y0 = max(0, ox), max(0, oy)
    x1, y1 = min(FR, ox + w), min(FR, oy + h)
    if x1 > x0 and y1 > y0:
        o[y0:y1, x0:x1] = small[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    return o


def register(ai_rgba, base_key, body_rows_from, s_range=(0.85, 1.18), step=0.015, t=10):
    """Finds scale + offset putting the AI figure over the base frame. The score is the IoU of the silhouettes
    from row body_rows_from down (body without the head, which is restored from the base anyway).
    -> (frame 96x96 RGBA, iou, (s, ox, oy))"""
    ys, xs = np.nonzero(ai_rgba[..., 3] > 0)
    by, bx = np.nonzero(base_key[..., 3] > 0)
    a = ai_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    s0 = (by.max() - by.min() + 1) / a.shape[0]
    B = base_key[..., 3] > 0
    rows = np.arange(FR)[:, None] >= body_rows_from
    Bm = B & rows
    best = (-1, None)
    for f in np.arange(s_range[0], s_range[1] + 1e-9, step):
        s = s0 * f
        al = np.array(Image.fromarray(a[..., 3]).resize((max(1, round(a.shape[1] * s)), max(1, round(a.shape[0] * s))), Image.BOX)) > 127
        h, w = al.shape
        # nominal: bottoms aligned, horizontal centers of mass aligned
        oy0 = by.max() + 1 - h
        ox0 = int(round(bx.mean() - np.nonzero(al)[1].mean()))
        for dy in range(-t, t + 1):
            for dx in range(-t, t + 1):
                ox, oy = ox0 + dx, oy0 + dy
                A = np.zeros((FR, FR), bool)
                x0, y0 = max(0, ox), max(0, oy)
                x1, y1 = min(FR, ox + w), min(FR, oy + h)
                if x1 <= x0 or y1 <= y0:
                    continue
                A[y0:y1, x0:x1] = al[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
                A &= rows
                inter = (A & Bm).sum()
                iou = inter / max(1, (A | Bm).sum())
                if iou > best[0]:
                    best = (iou, (s, ox, oy))
    s, ox, oy = best[1]
    small = _resize_rgba(a, s)
    return _place(small, ox, oy), best[0], best[1]


def stretch_body(ai_rgba, params, chin96, base_chin, base_feet):
    """The AI drew a bigger head (its chin at chin96, under the base chin): drop the AI head and stretch the AI
    body vertically so it goes from just under the base chin to the base feet. Same horizontal scale/position."""
    s, ox, oy = params
    ys, xs = np.nonzero(ai_rgba[..., 3] > 0)
    a = ai_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    top_hi = int(round((chin96 + 1 - oy) / s))
    if top_hi <= 0 or top_hi >= a.shape[0] - 4:
        return None
    body = a[top_hi:]
    h96 = base_feet + 1 - (base_chin + 1)
    if h96 <= 4:
        return None
    w96 = max(1, int(round(body.shape[1] * s)))
    im = Image.fromarray(body, 'RGBA')
    al = np.array(im.getchannel('A').resize((w96, h96), Image.BOX)).astype(float) / 255
    pm = body[..., :3].astype(float) * (body[..., 3:4] / 255)
    pmr = np.stack([np.array(Image.fromarray(pm[..., i].astype(np.float32), 'F').resize((w96, h96), Image.BOX))
                    for i in range(3)], -1)
    col = pmr / np.maximum(al[..., None], 1e-3)
    small = np.zeros((h96, w96, 4), np.uint8)
    small[..., :3] = np.clip(col, 0, 255)
    small[..., 3] = (al > 0.5) * 255
    return _place(small, ox, base_chin + 1)
