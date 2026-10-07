"""Pranchas de conferencia das animacoes de combate (mesma regra do shader, via customization/compose.py).

    python preview.py [out_dir]     -> <out>/strip_<body>_<anim>.png (8 direcoes x 6 quadros, varias aparencias)
                                        <out>/<body>_<anim>.gif     (todas as aparencias, 8 direcoes, 70/90/120 ms)
                                        <out>/layers_<body>_<anim>.png (cada camada sobre o corpo esmaecido)
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'customization'))
from common import FR, GAME  # noqa: E402
from compose import compose  # noqa: E402
from build_combat import SEQ, WEAPON_OF, HEADS, FACES  # noqa: E402
from keys import COMBAT_WORK  # noqa: E402

CH = os.path.join(GAME, 'assets', 'characters'); EQ = os.path.join(GAME, 'assets', 'equipment')
MS = {'attack_unarmed': 70, 'attack_blade': 70, 'attack_staff': 70, 'cast': 90, 'death': 120}
ROWS = [(0, False), (1, False), (2, False), (3, False), (4, False), (3, True), (2, True), (1, True)]
BG = (124, 116, 138, 255)


def ld(p): return Image.open(p).convert('RGBA') if os.path.exists(p) else None


def looks(body, anim):
    """[(rotulo, corpo, [camadas frente], [camadas atras])] -> folhas inteiras."""
    wpn = WEAPON_OF.get(anim)
    wf = ld(os.path.join(EQ, 'weapon', wpn, f'{body}_{anim}.png')) if wpn else None
    wb = ld(os.path.join(EQ, 'weapon', wpn, f'{body}_{anim}_back.png')) if wpn else None
    trav = ld(os.path.join(CH, f'chr_traveler_{body}_{anim}.png'))
    style2 = {'male': 'curly', 'female': 'braid'}[body]; style3 = {'male': 'neat', 'female': 'bob'}[body]
    c1 = compose(body, anim, {'skin': 3, 'hair_style': style2, 'hair_color': 4, 'eye_color': 4, 'earrings': 'hoop'})
    c2 = compose(body, anim, {'skin': 1, 'hair_style': style3, 'hair_color': 7, 'eye_color': 2, 'earrings': 'feather'})
    jer = ld(os.path.join(CH, 'outfits', f'chr_{body}_leather_jerkin_{anim}.png'))
    hat = ld(os.path.join(EQ, 'head', 'straw_hat', f'{body}_{anim}.png'))
    crown = ld(os.path.join(EQ, 'head', 'ipe_flower_crown', f'{body}_{anim}.png'))
    out = [('viajante', trav, [], [wb]), ('custom1', c1, [crown], [wb]), ('custom2', c2, [hat], [wb])]
    if jer is not None: out.append(('jerkin+chapeu', jer, [hat], [wb]))
    return [(n, b, [x for x in f if x is not None] + ([wf] if wf is not None else []), [x for x in bk if x is not None]) for n, b, f, bk in out]


def frame_of(sheet, row, col, mirror):
    f = sheet.crop((col * FR, row * FR, col * FR + FR, row * FR + FR))
    return f.transpose(Image.FLIP_LEFT_RIGHT) if mirror else f


def comp(look, row, col, mirror):
    n, b, front, back = look; o = Image.new('RGBA', (FR, FR), BG)
    back_row = row in (3, 4)
    for s in back:
        if back_row: o.alpha_composite(frame_of(s, row, col, mirror))
    o.alpha_composite(frame_of(b, row, col, mirror))
    for s in front:
        o.alpha_composite(frame_of(s, row, col, mirror))
    return o


def strip(body, anim, out):
    L = looks(body, anim); z = 2; n = len(SEQ[anim])
    W = len(L) * (n * FR + 8); im = Image.new('RGBA', (W, 8 * FR), (60, 56, 70, 255))
    for li, lk in enumerate(L):
        for r, (row, mir) in enumerate(ROWS):
            for c in range(n): im.alpha_composite(comp(lk, row, c, mir), (li * (n * FR + 8) + c * FR, r * FR))
    im.resize((im.width * z, im.height * z), Image.NEAREST).save(os.path.join(out, f'strip_{body}_{anim}.png'))
    frames = []
    for c in range(n):
        f = Image.new('RGBA', (8 * FR, len(L) * FR), BG)
        for li, lk in enumerate(L):
            for r, (row, mir) in enumerate(ROWS): f.alpha_composite(comp(lk, row, c, mir), (r * FR, li * FR))
        frames.append(f.resize((f.width * z, f.height * z), Image.NEAREST).convert('RGB'))
    hold = [400] if anim != 'death' else [900]
    frames.append(frames[0] if anim != 'death' else frames[-1])
    frames[0].save(os.path.join(out, f'{body}_{anim}.gif'), save_all=True, append_images=frames[1:],
                   duration=[MS[anim]] * n + hold, loop=0)


def layers(body, anim, out):
    """Cada camada (cor viva) sobre o corpo-base esmaecido: confere o encaixe quadro a quadro."""
    base = ld(os.path.join(CH, 'base', f'chr_{body}_base_{anim}.png'))
    paths = [('hair/' + s, os.path.join(CH, 'hair', s, f'{body}_{anim}.png')) for s in sorted(os.listdir(os.path.join(CH, 'hair')))]
    paths += [('face/' + f, os.path.join(CH, 'face', f, f'{body}_{anim}.png')) for f in FACES]
    paths += [('head/' + h, os.path.join(EQ, 'head', h, f'{body}_{anim}.png')) for h in HEADS]
    if anim in WEAPON_OF:
        w = WEAPON_OF[anim]
        paths += [(w, os.path.join(EQ, 'weapon', w, f'{body}_{anim}.png')), (w + '_back', os.path.join(EQ, 'weapon', w, f'{body}_{anim}_back.png'))]
    paths = [(n, ld(p)) for n, p in paths if os.path.exists(p)]
    dim = np.asarray(base).copy(); dim[..., 3] = (dim[..., 3] * 0.45).astype(np.uint8); dim = Image.fromarray(dim)
    W = base.width; im = Image.new('RGBA', (W, len(paths) * base.height), (235, 235, 240, 255))
    for i, (n, sh) in enumerate(paths):
        im.alpha_composite(dim, (0, i * base.height)); im.alpha_composite(sh, (0, i * base.height))
    im.save(os.path.join(out, f'layers_{body}_{anim}.png'))


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(COMBAT_WORK, 'preview'); os.makedirs(out, exist_ok=True)
    for body in ('male', 'female'):
        for anim in SEQ:
            if not os.path.exists(os.path.join(CH, 'base', f'chr_{body}_base_{anim}.png')): continue
            strip(body, anim, out); layers(body, anim, out)
    print('ok', out)
