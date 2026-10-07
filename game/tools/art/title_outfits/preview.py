"""Previews and consistency metrics of the outfit sheets (same color rule as the shader, in Python).

    python preview.py <outfit|all> [--out DIR]     contact sheets (all animations, 2 bodies), walk GIFs, metrics
    python preview.py board [--out DIR]            board with every installed outfit x 2 bodies x 5 directions

Metric (per animation row, consecutive frames): 'hist' = L1 distance between the color histograms of the
outfit body (head excluded) in the two frames, 0..2. Frames of the same key pose give ~0 (only the pose moves);
a jump between poses shows up when the AI drew the garment differently. Reported: mean and max per animation.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import poses as P  # noqa: E402
from build import OUTFITS, OUT_DIR, WORK  # noqa: E402
import importlib.util as _iu  # noqa: E402
sys.path.append(os.path.join(HERE, '..', 'customization'))
_sp = _iu.spec_from_file_location('custom_compose', os.path.join(HERE, '..', 'customization', 'compose.py'))
C = _iu.module_from_spec(_sp); _sp.loader.exec_module(C)  # customization compose: ramp, tone, eyes_layer

CH = os.path.join(P.GAME, 'assets', 'characters')
FR = P.FR
HAIR = {'male': 'spiky', 'female': 'ponytail'}
BG = (124, 116, 138)
ANIMS = P.ANIMS


def sheet(body, outfit, anim, app=None):
    """Composed sheet (RGBA numpy): outfit body recolored by its mask + eyes + default hair."""
    app = app or {}
    if outfit == 'base':
        bp, mp = P.base_path(body, anim), P.mask_path(body, anim)
    else:
        bp = os.path.join(OUT_DIR, f'chr_{body}_{outfit}_{anim}.png')
        mp = os.path.join(OUT_DIR, f'chr_{body}_{outfit}_mask_{anim}.png')
    b = P.load(bp).copy()
    m = P.load(mp)
    sk, hr, ey = C.ramp('skin', app.get('skin', 0)), C.ramp('hair', app.get('hair_color', 0)), C.ramp('eye', 0)
    for ch, r in ((0, sk), (1, ey), (2, hr)):
        sel = (m[..., ch] > 5) & (b[..., 3] > 0)
        if ch == 1:
            sel &= m[..., 0] <= 5
        if ch == 2:
            sel &= (m[..., 0] <= 5) & (m[..., 1] <= 5)
        b[sel, :3] = r[C.tone(m[..., ch][sel])]
    out = Image.fromarray(b)
    ep = os.path.join(CH, 'eyes', f'{body}_{anim}.png')
    if os.path.exists(ep):
        out.alpha_composite(Image.fromarray(C.eyes_layer(C.load(ep), sk, ey)))
    h = C.load(os.path.join(CH, 'hair', HAIR[body], f'{body}_{anim}.png'))
    if h is not None:
        h = h.copy(); op = h[..., 3] >= 128
        h[op, :3] = hr[C.tone(h[..., 0][op])]; h[..., 3] = np.where(op, 255, 0)
        out.alpha_composite(Image.fromarray(h))
    return np.array(out)


def on_bg(a, z):
    o = Image.new('RGBA', (a.shape[1], a.shape[0]), BG + (255,))
    o.alpha_composite(Image.fromarray(a))
    return o.resize((a.shape[1] * z, a.shape[0] * z), Image.NEAREST)


def contact(outfit, out_dir):
    for body in P.BODIES:
        rows = []
        for an in ANIMS:
            s = sheet(body, outfit, an)
            rows.append(s)
        w = max(r.shape[1] for r in rows)
        big = np.zeros((sum(r.shape[0] for r in rows), w, 4), np.uint8)
        y = 0
        for r in rows:
            big[y:y + r.shape[0], :r.shape[1]] = r; y += r.shape[0]
        on_bg(big, 2).save(os.path.join(out_dir, f'{outfit}_{body}_all.png'))


def gifs(outfit, out_dir, anims=('walk', 'idle', 'attack_blade', 'cast')):
    for body in P.BODIES:
        for an in anims:
            s = sheet(body, outfit, an)
            n = s.shape[1] // FR
            frames = []
            for c in range(n):
                row = np.concatenate([s[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] for r in range(5)], axis=1)
                frames.append(on_bg(row, 3).convert('P', palette=Image.ADAPTIVE))
            dur = 110 if an == 'walk' else 160
            frames[0].save(os.path.join(out_dir, f'{outfit}_{body}_{an}.gif'), save_all=True,
                           append_images=frames[1:], duration=dur, loop=0)


def metrics(outfit):
    res = {}
    for body in P.BODIES:
        for an in ANIMS:
            if outfit == 'base':
                bp, mp = P.base_path(body, an), P.mask_path(body, an)
            else:
                bp = os.path.join(OUT_DIR, f'chr_{body}_{outfit}_{an}.png')
                mp = os.path.join(OUT_DIR, f'chr_{body}_{outfit}_mask_{an}.png')
            if not os.path.exists(bp):
                continue
            s = P.load(bp); m = P.load(mp)
            vals = []
            for r in range(5):
                hists = []
                for c in range(s.shape[1] // FR):
                    f = s[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]
                    mm = m[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]
                    sel = (f[..., 3] > 0) & (mm[..., 3] == 255) & (mm[..., :3].max(axis=2) == 0)
                    px = f[sel][:, :3].astype(np.int64)
                    key = px[:, 0] * 65536 + px[:, 1] * 256 + px[:, 2]
                    u, cnt = np.unique(key, return_counts=True)
                    hists.append(dict(zip(u.tolist(), (cnt / max(1, cnt.sum())).tolist())))
                for i in range(len(hists) - 1):
                    a, b = hists[i], hists[i + 1]
                    vals.append(sum(abs(a.get(k, 0) - b.get(k, 0)) for k in set(a) | set(b)))
            if vals:
                res[f'{body}/{an}'] = (round(float(np.mean(vals)), 3), round(float(np.max(vals)), 3))
    return res


def _title_name(title_id):
    import csv
    for f in sorted(os.listdir(os.path.join(P.GAME, 'localization'))):
        if f.endswith('.csv'):
            for row in csv.reader(open(os.path.join(P.GAME, 'localization', f), encoding='utf-8')):
                if row and row[0] == 'TITLE_%s_NAME' % title_id.upper() and len(row) > 1:
                    return row[1]
    return title_id


def board(out_dir):
    installed = [o for o in OUTFITS if os.path.exists(os.path.join(OUT_DIR, f'chr_female_{o}_mask_idle.png'))]
    cols = ['base'] + installed
    z = 2
    cell = FR * z
    LW = 190
    img = Image.new('RGB', (LW + 10 * cell, len(cols) * cell + 24), BG)
    d = ImageDraw.Draw(img)
    try:
        from PIL import ImageFont
        font = ImageFont.truetype('DejaVuSans.ttf', 15)
    except OSError:
        font = None
    for bi, body in enumerate(P.BODIES):
        d.text((LW + bi * 5 * cell + 8, 6), ('masculino' if body == 'male' else 'feminino') + ': S, SE, L, NE, N',
               fill=(255, 255, 255), font=font)
    for ci, o in enumerate(cols):
        name = 'Viajante (corpo-base)' if o == 'base' else OUTFITS[o].get('name') or _title_name(OUTFITS[o]['title'])
        d.text((8, 24 + ci * cell + cell // 2 - 6), name, fill=(255, 255, 255), font=font)
        for bi, body in enumerate(P.BODIES):
            s_ = sheet(body, o, 'idle')
            for r in range(5):
                img.paste(on_bg(s_[r * FR:(r + 1) * FR, 0:FR], z), (LW + (bi * 5 + r) * cell, 24 + ci * cell))
    img.save(os.path.join(out_dir, 'board.png'))
    # walk strip GIF of every installed outfit (S, SE, E, NE, N)
    frames = []
    for c in range(8):
        row = []
        for o in cols:
            for body in P.BODIES:
                s = sheet(body, o, 'walk')
                row.append(np.concatenate([s[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] for r in range(5)], axis=0))
        frames.append(on_bg(np.concatenate(row, axis=1), 2).convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out_dir, 'board_walk.gif'), save_all=True, append_images=frames[1:], duration=110, loop=0)
    board_bow(out_dir, cols)
    return installed


def with_bow(body, s, anim):
    """Sheet with the bow weapon layer (behind the body on the back rows NE/N, over it on the others)."""
    wp = os.path.join(P.GAME, 'assets', 'equipment', 'weapon', 'bow', f'{body}_{anim}.png')
    if not os.path.exists(wp):
        return s
    fr_, bk = P.load(wp), P.load(wp.replace('.png', '_back.png'))
    out = np.zeros_like(s)
    for r in range(5):
        sl = slice(r * FR, (r + 1) * FR)
        row = Image.new('RGBA', (s.shape[1], FR))
        layers = [bk[sl], s[sl]] if r in (3, 4) else [s[sl], fr_[sl]]
        for L in layers:
            row.alpha_composite(Image.fromarray(np.ascontiguousarray(L)))
        out[sl] = np.array(row)
    return out


def board_bow(out_dir, cols):
    """GIF of the bow attack (attack_bow + bow layer) of every outfit, 2 bodies, rows S, SE, E, NE, N."""
    sheets = {(o, b): with_bow(b, sheet(b, o, 'attack_bow'), 'attack_bow') for o in cols for b in P.BODIES
              if os.path.exists(P.base_path(b, 'attack_bow') if o == 'base'
                                else os.path.join(OUT_DIR, f'chr_{b}_{o}_attack_bow.png'))}
    frames = []
    for c in range(6):
        row = [np.concatenate([s[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] for r in range(5)], axis=0)
               for s in sheets.values()]
        frames.append(on_bg(np.concatenate(row, axis=1), 2).convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out_dir, 'board_bow.gif'), save_all=True, append_images=frames[1:], duration=160,
                   loop=0)


def main():
    a = sys.argv[1:]
    out_dir = os.path.join(WORK, 'preview')
    if '--out' in a:
        out_dir = a[a.index('--out') + 1]; a = a[:a.index('--out')]
    os.makedirs(out_dir, exist_ok=True)
    if a[0] == 'board':
        print('board:', board(out_dir)); return
    outfits = list(OUTFITS) if a[0] == 'all' else a[0].split(',')
    allm = {'base': metrics('base')}
    print('base (reference)', json.dumps(allm['base']))
    for o in outfits:
        if not os.path.exists(os.path.join(OUT_DIR, f'chr_female_{o}_mask_idle.png')):
            continue
        contact(o, out_dir); gifs(o, out_dir)
        allm[o] = metrics(o)
        print(o, json.dumps(allm[o]))
    json.dump(allm, open(os.path.join(out_dir, 'metrics.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
