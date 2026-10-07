"""Compositor de referencia (Python, mesma regra do shader) + pranchas de conferencia.

    python compose.py contact <out.png>     todos os estilos x 3 cores, peles, olhos, brincos; frente e lado
    python compose.py walk <out.png>        tiras do andar (alinhamento das camadas quadro a quadro)
    python compose.py compare <out.png>     padrao (base+cabelo) vs chr_traveler_* atual
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from common import GAME, FR, STEP

HERE = os.path.dirname(os.path.abspath(__file__))
PAL = json.load(open(os.path.join(HERE, 'palettes.json')))
CH = os.path.join(GAME, 'assets', 'characters')
STYLES = {'male': ['spiky', 'neat', 'ponytail', 'curly', 'buzz'], 'female': ['ponytail', 'bob', 'waves', 'braid', 'buzz']}
EARRINGS = ['hoop', 'seed', 'feather']


def ramp(group, i):
    r = PAL[group][i][1]; return np.array([r[min(j, len(r) - 1)] for j in range(6)], np.uint8)


def tone(v): return np.clip(v.astype(int) // STEP, 0, 5)


def load(p):
    return np.asarray(Image.open(p).convert('RGBA')) if os.path.exists(p) else None


def eyes_layer(e, sk, ey):
    """Camada de olhos (eyes.py) colorida pela mesma regra do shader (MODE_EYES)."""
    e = e.copy(); op = e[..., 3] >= 128
    r0 = (e[..., 1] == 0) & (e[..., 2] == 0) & (e[..., 0] > 0)
    g0 = (e[..., 0] == 0) & (e[..., 2] == 0) & (e[..., 1] > 0)
    e[op & r0, :3] = sk[tone(e[..., 0][op & r0])]
    e[op & g0, :3] = ey[tone(e[..., 1][op & g0])]
    e[..., 3] = np.where(op, 255, 0)
    return e


def compose(body, anim, app):
    """Folha inteira composta (numpy RGBA) para a aparencia."""
    b = load(os.path.join(CH, 'base', f'chr_{body}_base_{anim}.png')).copy()
    m = load(os.path.join(CH, 'base', f'chr_{body}_base_mask_{anim}.png'))
    sk, hr, ey = ramp('skin', app.get('skin', 0)), ramp('hair', app.get('hair_color', 0)), ramp('eye', app.get('eye_color', 0))
    for ch, r in ((0, sk), (1, ey), (2, hr)):
        sel = (m[..., ch] > 5) & (b[..., 3] > 0)
        if ch == 1: sel &= m[..., 0] <= 5
        if ch == 2: sel &= (m[..., 0] <= 5) & (m[..., 1] <= 5)
        b[sel, :3] = r[tone(m[..., ch][sel])]
    out = Image.fromarray(b)
    if app.get('eyes', True):
        ep = os.path.join(CH, 'eyes', f'{body}_{anim}.png')
        if app.get('blink') and os.path.exists(os.path.join(CH, 'eyes', f'{body}_{anim}_blink.png')):
            ep = os.path.join(CH, 'eyes', f'{body}_{anim}_blink.png')
        if os.path.exists(ep):
            out.alpha_composite(Image.fromarray(eyes_layer(load(ep), sk, ey)))
    st = app.get('hair_style', 'buzz')
    if st != 'buzz':
        h = load(os.path.join(CH, 'hair', st, f'{body}_{anim}.png'))
        if h is not None:
            h = h.copy(); op = h[..., 3] >= 128; h[op, :3] = hr[tone(h[..., 0][op])]; h[..., 3] = np.where(op, 255, 0)
            out.alpha_composite(Image.fromarray(h))
    e = app.get('earrings', '')
    if e:
        ep = os.path.join(CH, 'face', e, f'{body}_{anim}.png')
        if os.path.exists(ep): out.alpha_composite(Image.open(ep).convert('RGBA'))
    return out


def frame(sheet, row, col=0, mirror=False):
    f = sheet.crop((col * FR, row * FR, col * FR + FR, row * FR + FR))
    return f.transpose(Image.FLIP_LEFT_RIGHT) if mirror else f


def on_bg(f, bg=(124, 116, 138), z=3):
    o = Image.new('RGBA', f.size, bg + (255,)); o.alpha_composite(f); return o.resize((f.width * z, f.height * z), Image.NEAREST)


def contact(out):
    cells = []  # (label, frame)
    for body in ('male', 'female'):
        for st in STYLES[body]:
            for hc in (0, 4, 7):
                app = dict(hair_style=st, hair_color=hc)
                sh = compose(body, 'idle', app)
                cells.append((f'{body[0]} {st} c{hc}', [frame(sh, 0), frame(sh, 1), frame(sh, 2), frame(sh, 4)]))
        for sk in range(6):
            sh = compose(body, 'idle', dict(hair_style=STYLES[body][0], skin=sk, hair_color=[0, 2, 1, 3, 1, 1][sk]))
            cells.append((f'{body[0]} pele {sk}', [frame(sh, 0), frame(sh, 1), frame(sh, 2), frame(sh, 4)]))
        for ey in range(6):
            sh = compose(body, 'idle', dict(hair_style=STYLES[body][1], eye_color=ey))
            cells.append((f'{body[0]} olho {ey}', [frame(sh, 0), frame(sh, 1)]))
        for e in EARRINGS:
            sh = compose(body, 'idle', dict(hair_style=STYLES[body][1], earrings=e))
            cells.append((f'{body[0]} {e}', [frame(sh, 0), frame(sh, 1), frame(sh, 2), frame(sh, 3), frame(sh, 4)]))
    Z = 3; cw = FR * Z; per_row = 16
    flat = [(lab if i == 0 else '', f) for lab, fs in cells for i, f in enumerate(fs)]
    rows = (len(flat) + per_row - 1) // per_row
    img = Image.new('RGBA', (per_row * cw, rows * (cw + 14)), (60, 52, 70, 255)); d = ImageDraw.Draw(img)
    for i, (lab, f) in enumerate(flat):
        x, y = (i % per_row) * cw, (i // per_row) * (cw + 14)
        img.alpha_composite(on_bg(f, z=Z), (x, y + 14)); d.text((x + 3, y + 1), lab, fill=(250, 229, 140))
    img.save(out); print(out, img.size)


def walk(out):
    rows = []
    for body in ('male', 'female'):
        for st in STYLES[body][:4]:
            sh = compose(body, 'walk', dict(hair_style=st, hair_color=3, earrings='hoop'))
            for r in range(5): rows.append([frame(sh, r, c) for c in range(8)])
    Z = 2; img = Image.new('RGBA', (8 * FR * Z, len(rows) * FR * Z))
    for r, row in enumerate(rows):
        for c, f in enumerate(row): img.paste(on_bg(f, z=Z), (c * FR * Z, r * FR * Z))
    img.save(out); print(out, img.size)


def compare(out):
    rows = []
    for body in ('male', 'female'):
        for anim in ('idle', 'walk', 'sit'):
            cur = Image.open(os.path.join(CH, f'chr_traveler_{body}_{anim}.png')).convert('RGBA')
            new = compose(body, anim, dict(hair_style=STYLES[body][0]))
            rows.append(cur); rows.append(new)
    W = max(r.width for r in rows); H = sum(r.height for r in rows)
    img = Image.new('RGBA', (W, H), (124, 116, 138, 255)); y = 0
    for r in rows: img.alpha_composite(r, (0, y)); y += r.height
    img = img.resize((W * 2, H * 2), Image.NEAREST); img.save(out); print(out, img.size)


def eyes(out):
    """Toda cor de olho x corpos x S/SE/L (idle), a 1x e a 4x, + piscar + todas as animacoes (S) a 2x."""
    from PIL import ImageDraw
    Z = 4; bg = (124, 116, 138)
    rows = []
    for body in ('male', 'female'):
        for ey in range(len(PAL['eye'])):
            sh = compose(body, 'idle', dict(hair_style=STYLES[body][0], eye_color=ey, skin=[0, 1, 2, 3, 4, 5][ey]))
            rows.append((f'{body[0]} olho {ey} pele {ey}', [frame(sh, r) for r in (0, 1, 2)]))
        sh = compose(body, 'idle', dict(hair_style=STYLES[body][1], eye_color=4, blink=True))
        rows.append((f'{body[0]} piscando', [frame(sh, r) for r in (0, 1, 2)]))
    crop = (24, 8, 72, 48)
    cw1, cw4 = FR, (crop[2] - crop[0]) * Z
    W = 3 * cw1 + 3 * (cw4 + 4) + 150; RH = max(FR, (crop[3] - crop[1]) * Z) + 6
    img = Image.new('RGBA', (W, len(rows) * RH), (60, 52, 70, 255)); d = ImageDraw.Draw(img)
    for i, (lab, fs) in enumerate(rows):
        y = i * RH; d.text((4, y + 4), lab, fill=(250, 229, 140))
        for j, f in enumerate(fs):
            o = Image.new('RGBA', f.size, bg + (255,)); o.alpha_composite(f)
            img.paste(o, (150 + j * cw1, y))
            img.paste(o.crop(crop).resize((cw4, (crop[3] - crop[1]) * Z), Image.NEAREST), (150 + 3 * cw1 + j * (cw4 + 4), y))
    img.save(out); print(out, img.size)


def anims(out):
    """Todas as animacoes com a camada de olhos (olho azul), linhas S/SE/L, a 2x."""
    Z = 2; bg = (124, 116, 138); rows = []
    for body in ('male', 'female'):
        for anim in ('idle', 'walk', 'sit', 'attack_unarmed', 'attack_blade', 'attack_staff', 'cast', 'death'):
            p = os.path.join(CH, 'base', f'chr_{body}_base_{anim}.png')
            if not os.path.exists(p): continue
            sh = compose(body, anim, dict(hair_style=STYLES[body][0], eye_color=4))
            for r in (0, 1, 2):
                rows.append([frame(sh, r, c) for c in range(sh.width // FR)])
    W = max(len(r) for r in rows) * FR * Z
    img = Image.new('RGBA', (W, len(rows) * FR * Z), (60, 52, 70, 255))
    for i, row in enumerate(rows):
        for c, f in enumerate(row): img.paste(on_bg(f, bg, Z), (c * FR * Z, i * FR * Z))
    img.save(out); print(out, img.size)


if __name__ == '__main__':
    {'contact': contact, 'walk': walk, 'compare': compare, 'eyes': eyes, 'anims': anims}[sys.argv[1]](sys.argv[2])
