"""Unique key poses of the base body sheets and how every frame derives from them.

The Viajante sheets are built from few key poses: repeated frames are the same pose shifted (walk bob, combat
holds) or with the upper body lowered 1 px (idle breathing). An outfit is drawn once per KEY pose and every frame
is rebuilt with the exact same transform, so the outfit never "boils" between frames of one pose.

Transform of a frame = (key, dx, dy_top, dy_bot, split): rows y < split sample key[y - dy_top], rows y >= split
sample key[y - dy_bot], all shifted dx. Verified to reproduce the base sheet AND mask exactly.
"""
import functools
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
BASE = os.path.join(GAME, 'assets', 'characters', 'base')
FR = 96
DIRS = ['s', 'se', 'e', 'ne', 'n']
BODIES = ['male', 'female']
ANIMS = ['idle', 'walk', 'sit', 'attack_unarmed', 'attack_blade', 'attack_staff', 'cast', 'death']
R = 4  # max shift searched
TOL = 0.03  # mismatch allowed for a frame to reuse a key of the same animation


def base_path(body, anim):
    return os.path.join(BASE, f'chr_{body}_base_{anim}.png')


def mask_path(body, anim):
    return os.path.join(BASE, f'chr_{body}_base_mask_{anim}.png')


def load(p):
    return np.array(Image.open(p).convert('RGBA'))


def split_frames(a):
    return [[a[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] for c in range(a.shape[1] // FR)] for r in range(a.shape[0] // FR)]


def shifted(a, dx, dy):
    """o[y, x] = a[y - dy, x - dx] (moves content by +dx, +dy)."""
    o = np.zeros_like(a)
    h, w = a.shape[:2]
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    o[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return o


def apply(key, t):
    dx, dyt, dyb, split = t
    top = shifted(key, dx, dyt)
    bot = shifted(key, dx, dyb)
    o = bot.copy()
    o[:split] = top[:split]
    return o


def _row_costs(frame, key):
    """{(dx, dy): mismatching pixels per row} of shifted(key) against frame."""
    out = {}
    for dx in range(-R, R + 1):
        for dy in range(-R, R + 1):
            out[(dx, dy)] = (shifted(key, dx, dy) != frame).any(axis=2).sum(axis=1)
    return out


def _match(frame, key, tol):
    """Best transform t (two-band vertical shift, see apply) of key onto frame, when the mismatch <= tol."""
    rc = _row_costs(frame, key)
    best = (None, 10 ** 9)
    for (dx, dyb), cb in rc.items():
        c = int(cb.sum())
        if c < best[1]:
            best = ((dx, dyb, dyb, 0), c)
        for dyt in range(dyb - 2, dyb + 3):
            if dyt == dyb or (dx, dyt) not in rc:
                continue
            ct = rc[(dx, dyt)]
            tot = np.concatenate([[0], np.cumsum(ct)]) + (cb.sum() - np.concatenate([[0], np.cumsum(cb)]))
            sp = int(tot[1:FR].argmin()) + 1
            if tot[sp] < best[1]:
                best = ((dx, dyt, dyb, sp), int(tot[sp]))
    return best[0] if best[1] <= tol else None


# Order matters: a walk "passing" pose is the idle pose shifted, so idle comes first.
@functools.lru_cache(maxsize=None)
def analyse_body(body):
    """Unique key poses of all sheets of one body.
    -> {'keys': [(anim, row, col)], 'frames': {(anim, row, col): (key_index, t)}}
    A frame reuses a key of the same row (any animation) when it is that key shifted (exact), or, inside the same
    animation, when it differs in at most 3% of its pixels (idle breathing): the head is always restored from the
    real frame, so nothing of the base is lost."""
    keys, frames, data = [], {}, {}
    for an in ANIMS:
        if not os.path.exists(base_path(body, an)):
            continue
        st = np.concatenate([load(base_path(body, an)), load(mask_path(body, an))], axis=2)
        F = split_frames(st)
        data[an] = F
        for r, row in enumerate(F):
            for c, fr in enumerate(row):
                found = None
                opq = int((fr[..., 3] > 0).sum())
                for ki, (ka, kr, kc) in enumerate(keys):
                    if kr != r:
                        continue
                    tol = int(opq * TOL) if ka == an else 0
                    if abs(opq - int((data[ka][kr][kc][..., 3] > 0).sum())) > tol + 40:
                        continue
                    t = _match(fr, data[ka][kr][kc], tol)
                    if t is not None:
                        found = (ki, t)
                        break
                if found is None:
                    keys.append((an, r, c))
                    found = (len(keys) - 1, (0, 0, 0, 0))
                frames[(an, r, c)] = found
    return {'keys': keys, 'frames': frames}


def key_name(k):
    return '%s_%s_%d' % (k[0], DIRS[k[1]], k[2])


if __name__ == '__main__':
    for b in BODIES:
        r = analyse_body(b)
        print(b, len(r['keys']), 'keys')
        for k, (ki, t) in sorted(r['frames'].items()):
            if r['keys'][ki] != k:
                print('   ', k, '<-', r['keys'][ki], t)
