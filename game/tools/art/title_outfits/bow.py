"""Bow (item simple_bow, visual_id "bow", attack style "bow"): the attack_bow animation of every paper-doll layer and
the bow weapon layer.

    python bow.py sheets      attack_bow of every layer that has attack_unarmed + cast (base + mask, Viajante, eyes,
                              hair, face, hats, every outfit + mask), by recomposing frames of those two sheets
    python bow.py weapon      assets/equipment/weapon/bow/<body>_{idle,walk,sit,attack_bow}[_back].png
    python bow.py icon        assets/items/icons/icon_item_simple_bow.png (32x32, master palette)
    python bow.py all         sheets + weapon

attack_bow (6 frames, rows S, SE, E, NE, N):
  every row: guard, jab (bow arm out), jab, jab, jab, guard     <- attack_unarmed columns 0, 1, 1, 2, 2, 5
  (S and N: the jab goes to the left of the screen, so the bow is aimed to that side, like the RO archer)
  bow      ready, drawn (string + arrow), drawn, released, released, ready
The frames are copies of existing frames, so every layer (hair, eyes, hats, outfits) stays aligned for free and every
outfit has the animation. The body does not pull the string with the rear hand (no new pose): the string goes to the
chin. A real draw pose needs new key poses of the base body (pending, see README).

The bow itself comes from an AI image (bow_source.png, Bria text-to-image, "a simple longbow of bamboo cane"): the
thin string is removed, the limb is mirrored/rotated at full resolution, reduced (premultiplied BOX), put on the
master palette and outlined. The string and the arrow are 1 px lines drawn per frame (they depend on the hands).
Hands: idle/walk/sit use the grip of the blade layer (the handle pixels); attack_bow uses the front fist
(right-most pixels of the arm band in SE/E/NE, left-most in S/N) and the string goes to the chin.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'icons'))
import poses as P  # noqa: E402
from head import head_pixels, head_box  # noqa: E402

GAME = P.GAME
A = os.path.join(GAME, 'assets')
FR = 96
ANIM = 'attack_bow'
SRC_UN, SRC_CAST = 'attack_unarmed', 'cast'
SIDE_MAP = [(SRC_UN, 0), (SRC_UN, 1), (SRC_UN, 1), (SRC_UN, 2), (SRC_UN, 2), (SRC_UN, 5)]
FRAME_MAP = [SIDE_MAP] * 5
STATE = ['ready', 'drawn', 'drawn', 'released', 'released', 'ready']
BOW_LEN = 34          # tip to tip, px (the Viajante is ~80 px tall)
BOW_LEN_ATTACK = 36
SOURCE = os.path.join(HERE, 'bow_source.png')


# --- palette / drawing helpers ---------------------------------------------------------------------------------

def _gi():
    sys.argv, keep = ['x'], sys.argv
    import gen_icons as g
    sys.argv = keep
    return g


G = _gi()


def pal(rgb):
    return G.nearest(np.array([rgb], float))[0].astype(np.uint8)


STRING = pal((236, 226, 204))
SHAFT = pal((170, 116, 66))
HEAD = pal((196, 204, 214))
FLETCH = pal((196, 58, 48))


def line(o, p0, p1, col, only_empty=False):
    (x0, y0), (x1, y1) = p0, p1
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = int(round(x0 + (x1 - x0) * i / n)); y = int(round(y0 + (y1 - y0) * i / n))
        if 0 <= x < o.shape[1] and 0 <= y < o.shape[0] and not (only_empty and o[y, x, 3]):
            o[y, x, :3] = col; o[y, x, 3] = 255


def dot(o, x, y, col):
    if 0 <= x < o.shape[1] and 0 <= y < o.shape[0]:
        o[y, x, :3] = col; o[y, x, 3] = 255


# --- the bow sprite ----------------------------------------------------------------------------------------------

_HI = None


def _hires():
    """Bow limb without the string (RGBA, full resolution) + tips/grip (x, y) in that image. Arc bulges LEFT."""
    global _HI
    if _HI is None:
        a = np.asarray(Image.open(SOURCE).convert('RGB')).astype(int)
        m = np.abs(a - 255).sum(2) > 60
        limb = ndi.binary_opening(m, np.ones((15, 15), bool))   # the string is ~13 px wide, the limb wider
        lab, n = ndi.label(limb)
        limb = lab == (np.argmax(np.bincount(lab.ravel())[1:]) + 1)
        limb = m & ndi.binary_dilation(limb, np.ones((7, 7), bool))  # outline details back, not the string
        # the AI drew the riser going on straight past the lower limb (a stick under the grip): cut it
        limb[830:, :545] = False
        ys, xs = np.nonzero(limb)
        top = (int(xs[ys == ys.min()].mean()), int(ys.min()))
        bot = (int(xs[ys == ys.max()].mean()), int(ys.max()))
        mid = (ys.min() + ys.max()) // 2
        band = limb[mid - 20:mid + 20]
        gx = int(np.nonzero(band.any(axis=0))[0].mean())
        rgba = np.zeros(a.shape[:2] + (4,), np.uint8)
        rgba[..., :3] = a; rgba[..., 3] = np.where(limb, 255, 0)
        _HI = (rgba, top, bot, (gx, mid))
    return _HI


_CACHE = {}


def bow_sprite(length, angle, mirror):
    """-> (RGBA array, tip_a, tip_b, grip) at game size, points (x, y) inside the array. angle: degrees clockwise;
    mirror: arc bulges RIGHT (before the rotation)."""
    key = (length, angle, mirror)
    if key in _CACHE:
        return _CACHE[key]
    rgba, top, bot, grip = _hires()
    h, w = rgba.shape[:2]
    pts = np.array([top, bot, grip], float)
    im = Image.fromarray(rgba, 'RGBA')
    if mirror:
        im = im.transpose(Image.FLIP_LEFT_RIGHT); pts[:, 0] = w - 1 - pts[:, 0]
    # rotate about the image center, clockwise
    im = im.rotate(-angle, resample=Image.BICUBIC, expand=True)
    t = np.radians(angle); c, s = np.cos(t), np.sin(t)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    W2, H2 = im.size
    rel = pts - [cx, cy]
    pts = np.stack([rel[:, 0] * c - rel[:, 1] * s, rel[:, 0] * s + rel[:, 1] * c], 1) + [(W2 - 1) / 2, (H2 - 1) / 2]
    k = length / np.hypot(*(pts[0] - pts[1]))
    # premultiplied BOX reduction
    a = np.asarray(im).astype(float)
    a[..., :3] *= a[..., 3:] / 255
    small = []
    for ch in range(4):
        small.append(np.asarray(Image.fromarray(a[..., ch].astype(np.float32), 'F').resize(
            (max(1, round(W2 * k)), max(1, round(H2 * k))), Image.BOX)))
    sm = np.stack(small, -1)
    al = sm[..., 3] > 110
    rgb = np.where(sm[..., 3:] > 0, sm[..., :3] * 255 / np.maximum(sm[..., 3:], 1), 0)
    out = np.zeros(sm.shape[:2] + (4,), np.uint8)
    q = G.nearest(rgb)
    out[al, :3] = q[al]; out[al, 3] = 255
    # 1 px colored outline OUTSIDE the limb (the limb is only ~2 px wide at this size); canvas grown by 1 px
    pad = np.zeros((out.shape[0] + 2, out.shape[1] + 2, 4), np.uint8)
    pad[1:-1, 1:-1] = out
    alp = np.zeros(pad.shape[:2], bool); alp[1:-1, 1:-1] = al
    ring_p = ndi.binary_dilation(alp, np.ones((3, 3), bool)) & ~alp
    near = ndi.distance_transform_edt(~alp, return_indices=True)[1]
    dark = G.nearest(pad[near[0], near[1], :3].astype(float) * 0.42 + np.array([6, 4, 8]))
    pad[ring_p, :3] = dark[ring_p]; pad[ring_p, 3] = 255
    pts = pts * k + 1
    res = (pad, tuple(np.round(pts[0]).astype(int)), tuple(np.round(pts[1]).astype(int)),
           tuple(np.round(pts[2]).astype(int)))
    _CACHE[key] = res
    return res


def put_bow(o, hand, length, angle, mirror, state='ready', anchor=None, arrow_dir=None):
    """Draws the bow with its grip on hand (x, y) into the 96x96 frame o; string straight (ready/released) or pulled
    to anchor with an arrow (drawn)."""
    spr, ta, tb, gp = bow_sprite(length, angle, mirror)
    ox, oy = hand[0] - gp[0], hand[1] - gp[1]
    h, w = spr.shape[:2]
    for y in range(h):
        for x in range(w):
            if spr[y, x, 3]:
                X, Y = x + ox, y + oy
                if 0 <= X < FR and 0 <= Y < FR:
                    o[Y, X] = spr[y, x]
    A_ = (ta[0] + ox, ta[1] + oy); B_ = (tb[0] + ox, tb[1] + oy)
    if state == 'drawn' and anchor is not None:
        line(o, A_, anchor, STRING, only_empty=True)
        line(o, B_, anchor, STRING, only_empty=True)
        if arrow_dir is None:
            # arrow along anchor -> hand, 4 px past the grip
            d = np.array(hand, float) - anchor
            n = np.hypot(*d) or 1
            tip = tuple(np.round(np.array(hand) + d / n * 4).astype(int))
            line(o, anchor, tip, SHAFT)
            dot(o, *tip, HEAD)
            back = tuple(np.round(np.array(hand) + d / n * 3).astype(int))
            dot(o, *back, HEAD)
            dot(o, int(anchor[0]), int(anchor[1]) - 1, FLETCH)
            dot(o, int(anchor[0]), int(anchor[1]) + 1, FLETCH)
        else:  # toward the viewer: only the arrow head on the grip
            dot(o, hand[0], hand[1] - 1, HEAD); dot(o, hand[0] + 1, hand[1] - 1, HEAD)
    else:
        line(o, A_, B_, STRING, only_empty=True)


# --- hands ------------------------------------------------------------------------------------------------------

def blade_grips(body, anim):
    """{(row, col): (x, y)} of the hand of the blade layer (centroid of the handle, warm pixels)."""
    out = {}
    base = os.path.join(A, 'equipment', 'weapon', 'blade')
    fr_ = P.load(os.path.join(base, f'{body}_{anim}.png'))
    bk = os.path.join(base, f'{body}_{anim}_back.png')
    bk = P.load(bk) if os.path.exists(bk) else fr_
    for r in range(fr_.shape[0] // FR):
        for c in range(fr_.shape[1] // FR):
            src = bk if r in (3, 4) else fr_
            f = src[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]
            rgb = f[..., :3].astype(float) / 255
            mx, mn = rgb.max(2), rgb.min(2)
            warm = (f[..., 3] > 0) & (mx == rgb[..., 0]) & (rgb[..., 0] > rgb[..., 1]) & (mx - mn > 0.12)
            sel = warm if warm.sum() >= 2 else f[..., 3] > 0
            ys, xs = np.nonzero(sel)
            out[(r, c)] = (int(round(xs.mean())), int(round(ys.mean()))) if len(ys) else (48, 60)
    return out


def front_fist(frame, right=True):
    """Fist that holds the bow: mean of the outermost opaque pixels of the arm band (right-most in SE/E/NE, whose
    jab goes right; left-most in S/N)."""
    op = frame[..., 3] > 0
    band = op[38:64]
    xs = np.nonzero(band.any(axis=0))[0]
    if right:
        xm = xs.max()
        ys = np.nonzero(band[:, xm - 2:xm + 1].any(axis=1))[0] + 38
        return int(xm - 2), int(round(ys.mean()))
    xm = xs.min()
    ys = np.nonzero(band[:, xm:xm + 3].any(axis=1))[0] + 38
    return int(xm + 2), int(round(ys.mean()))


def chin_anchor(b, m, row):
    hb = head_box(head_pixels(b, m))
    if hb is None:
        return None
    y0, y1, x0, x1 = hb
    if row == 3:
        return (x1 - 1, y1 + 3)
    if row in (0, 4):
        return (x0 + 4, y1 + 1)
    return (x1 - 3, y1 + 1)


# --- attack_bow sheets of every layer -----------------------------------------------------------------------------

def sheet_pairs():
    """[(unarmed sheet, cast sheet, output sheet)] for every layer that has both."""
    pairs = []
    pats = [
        ('characters/base/chr_{b}_base_{a}.png', ['male', 'female']),
        ('characters/base/chr_{b}_base_mask_{a}.png', ['male', 'female']),
        ('characters/chr_traveler_{b}_{a}.png', ['male', 'female']),
        ('characters/eyes/{b}_{a}.png', ['male', 'female']),
    ]
    for d in sorted(glob.glob(os.path.join(A, 'characters', 'hair', '*'))) + \
            sorted(glob.glob(os.path.join(A, 'characters', 'face', '*'))) + \
            sorted(glob.glob(os.path.join(A, 'equipment', 'head', '*'))):
        rel = os.path.relpath(d, A)
        pats.append((rel + '/{b}_{a}.png', ['male', 'female']))
    for f in sorted(glob.glob(os.path.join(A, 'characters', 'outfits', f'chr_*_{SRC_UN}.png'))):
        n = os.path.basename(f)[4:-len(f'_{SRC_UN}.png')]      # <body>_<outfit>[_mask]
        body, rest = n.split('_', 1)
        pats.append((f'characters/outfits/chr_{{b}}_{rest}_{{a}}.png', [body]))
    for pat, bodies in pats:
        for b in bodies:
            u = os.path.join(A, pat.format(b=b, a=SRC_UN)); c = os.path.join(A, pat.format(b=b, a=SRC_CAST))
            if os.path.exists(u) and os.path.exists(c):
                pairs.append((u, c, os.path.join(A, pat.format(b=b, a=ANIM))))
    return pairs


def write_import_like(png, sibling):
    """Import file with the [params] of the sibling sheet (same compression/alpha settings)."""
    params = ''
    if os.path.exists(sibling + '.import'):
        txt = open(sibling + '.import', encoding='utf-8').read()
        params = txt[txt.index('[params]'):] if '[params]' in txt else ''
    if not params:
        params = ('[params]\n\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=false\n'
                  'detect_3d/compress_to=0\n')
    imp = png + '.import'
    if os.path.exists(imp):
        old = open(imp, encoding='utf-8').read()
        head = old[:old.index('[params]')] if '[params]' in old else old
        open(imp, 'w', encoding='utf-8').write(head + params)
    else:
        open(imp, 'w', encoding='utf-8').write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + params)


def compose(u_path, c_path, out_path):
    src = {SRC_UN: P.load(u_path), SRC_CAST: P.load(c_path)}
    o = np.zeros((FR * 5, FR * 6, 4), np.uint8)
    for r in range(5):
        for col, (an, sc) in enumerate(FRAME_MAP[r]):
            o[r * FR:(r + 1) * FR, col * FR:(col + 1) * FR] = src[an][r * FR:(r + 1) * FR, sc * FR:(sc + 1) * FR]
    Image.fromarray(o, 'RGBA').save(out_path)
    write_import_like(out_path, u_path)


def cmd_sheets():
    pairs = sheet_pairs()
    for u, c, o in pairs:
        compose(u, c, o)
    print(len(pairs), 'attack_bow sheets')


# --- bow weapon layer ---------------------------------------------------------------------------------------------

def arc_out(row, x):
    """mirror flag: the arc bulges away from the body (S/N) or forward (SE/E/NE face right)."""
    if row in (1, 2, 3):
        return True
    return x >= 48


def cmd_weapon():
    out_dir = os.path.join(A, 'equipment', 'weapon', 'bow')
    os.makedirs(out_dir, exist_ok=True)
    for body in P.BODIES:
        for anim in ('idle', 'walk', 'sit'):
            grips = blade_grips(body, anim)
            ref = P.load(os.path.join(A, 'equipment', 'weapon', 'blade', f'{body}_{anim}.png'))
            o = np.zeros_like(ref)
            for (r, c), hand in grips.items():
                f = np.zeros((FR, FR, 4), np.uint8)
                mir = arc_out(r, hand[0])
                if anim == 'sit':
                    put_bow(f, hand, BOW_LEN - 4, 90 if mir else -90, False)
                else:
                    put_bow(f, hand, BOW_LEN, 8 if mir else -8, mir)
                o[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] = f
            for suf in ('', '_back'):
                p = os.path.join(out_dir, f'{body}_{anim}{suf}.png')
                Image.fromarray(o, 'RGBA').save(p)
                write_import_like(p, os.path.join(A, 'equipment', 'weapon', 'blade', f'{body}_{anim}{suf}.png'))
        # attack_bow
        base = P.load(os.path.join(A, 'characters', 'base', f'chr_{body}_base_{ANIM}.png'))
        mask = P.load(os.path.join(A, 'characters', 'base', f'chr_{body}_base_mask_{ANIM}.png'))
        o = np.zeros((FR * 5, FR * 6, 4), np.uint8)
        for r in range(5):
            for c in range(6):
                sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
                b, m = base[sl], mask[sl]
                f = np.zeros((FR, FR, 4), np.uint8)
                st = STATE[c]
                right = r in (1, 2, 3)
                hand = front_fist(b, right)
                if FRAME_MAP[r][c][1] in (0, 5):     # guard: bow upright, leaning forward (off the face)
                    put_bow(f, hand, BOW_LEN_ATTACK, 20 if right else -20, right)
                else:
                    anc = chin_anchor(b, m, r) if st == 'drawn' else None
                    put_bow(f, hand, BOW_LEN_ATTACK, 0, right, st, anc)
                o[sl] = f
        for suf in ('', '_back'):
            p = os.path.join(out_dir, f'{body}_{ANIM}{suf}.png')
            Image.fromarray(o, 'RGBA').save(p)
            write_import_like(p, os.path.join(A, 'equipment', 'weapon', 'blade', f'{body}_attack_blade{suf}.png'))
    print('bow layer ok')


# --- item icon ----------------------------------------------------------------------------------------------------

def cmd_icon():
    """32x32 icon from the same AI bow: stretched sideways (thicker limb at icon size), reduced by gen_icons.process
    (master palette + outline) and a 1 px string redrawn between the tips (the AI string vanishes when reduced)."""
    src = Image.open(SOURCE).convert('RGB')
    a = np.asarray(src).astype(int)
    m = np.abs(a - 255).sum(2) > 60
    ys, xs = np.nonzero(m)
    c = src.crop((xs.min() - 20, ys.min() - 20, xs.max() + 20, ys.max() + 20))
    c = c.resize((int(c.width * 1.9), c.height), Image.LANCZOS)
    tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'bow_icon_src.png')
    c.save(tmp)
    o = np.asarray(G.process(tmp, 30)).copy()
    op = o[..., 3] > 0
    yy, xx = np.nonzero(op)
    top, bot = yy.min(), yy.max()
    tx = xx[yy <= top + 2].max(); bx = xx[yy >= bot - 2].max()
    dark = pal((80, 64, 70))
    xs_ = np.round(np.linspace(tx, bx, bot - top + 1)).astype(int)
    for i, y in enumerate(range(top, bot + 1)):
        x = xs_[i]
        if o[y, x, 3] == 0 or top + 2 < y < bot - 2:
            o[y, x, :3] = STRING; o[y, x, 3] = 255
        if x + 1 < o.shape[1] and o[y, x + 1, 3] == 0:
            o[y, x + 1, :3] = dark; o[y, x + 1, 3] = 255
    G.place_icon(Image.fromarray(o, 'RGBA')).save(os.path.join(A, 'items', 'icons', 'icon_item_simple_bow.png'))
    print('icon ok')


if __name__ == '__main__':
    c = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if c in ('sheets', 'all'):
        cmd_sheets()
    if c in ('weapon', 'all'):
        cmd_weapon()
    if c == 'icon':
        cmd_icon()
