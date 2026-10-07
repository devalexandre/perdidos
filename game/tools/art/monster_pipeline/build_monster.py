"""Monta as folhas de um monstro (GDD 17.3: idle 4, walk 6, attack 6, hit 2, death 6; linhas S, SE, L, NE, N)
a partir das poses escolhidas (picks.json de monster_pipeline.py, imagens com fundo removido rb_*.png):
  - idle/walk: pose parada de cada direcao + respiracao/balanco/pulo feitos por deslocamento de pixels;
  - attack: parada -> antecipacao (recua) -> pose de ataque (edicao Bria) avancando na direcao -> volta;
  - hit: clarao + recuo; death: tomba, achata e se desfaz em pixels (ultimo quadro fica).
Uso: build_monster.py <id> <n> [--frame 96] [--height 57] [--hover 0] [--style walk|hop|fly|spin]
  --height = tamanho aparente alvo (max(altura, 0,75 x largura)), GDD 10.2.1: pequeno 57, medio 82, grande 123, chefe 205
Saida: assets/monsters/<id>/mon_<id>_s<n>_<anim>.png (paleta propria de ate 40 cores por estagio)."""
import json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
DIRS = ['s', 'se', 'e', 'ne', 'n']
FWD = {'s': (0, 1), 'se': (1, 1), 'e': (1, 0), 'ne': (1, -1), 'n': (0, -1)}
# tamanhos aparentes do GDD 10.2.1 (Viajante = 82 px): pequeno 57, medio 82, grande 123, chefe 205
DEF = {64: 50, 96: 57, 144: 123, 240: 205}


def work(mid, n):
    return os.path.join(os.environ.get('MON_WORK', os.path.join(HERE, 'work')), f'{mid}_s{n}')


def load(path, flip, keep_frac=0.01):
    im = Image.open(path).convert('RGBA'); a = np.asarray(im).copy()
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    lab, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lab.ravel()); keep = sz >= sz[1:].max() * keep_frac; keep[0] = False; a[~keep[lab]] = 0
    im = Image.fromarray(a, 'RGBA'); im = im.crop(im.getbbox())
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def fit(im, maxw, maxh, size=None):
    """size (GDD 10.2.1): tamanho aparente alvo em px = max(altura, 0,75 x largura), para bichos largos e altos
    ficarem com o mesmo "peso" visual; limitado pelo quadro (maxw, maxh)."""
    k = min(maxw / im.width, maxh / im.height)
    if size: k = min(k, size / max(im.height, 0.75 * im.width))
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)


def recolor_top(im, rgb, frac=0.45):
    """Tira tons dourados da metade de cima (ex.: faixa de pano do chapeu do jiangshi nao pode lembrar um amuleto
    religioso, GDD 4.0 regra 3): vira o tom do manto, mantendo a luz."""
    a = np.asarray(im).copy(); h = a.shape[0]; top = np.zeros(a.shape[:2], bool); top[:int(h * frac)] = True
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    gold = top & (a[..., 3] > 0) & (r > 150) & (g > 90) & (b < 110) & (r - b > 70)
    L = (r + g + b) / 3.0 / 255.0
    for i in range(3):
        a[..., i] = np.where(gold, np.clip(rgb[i] * (0.6 + L * 0.8), 0, 255), a[..., i])
    return Image.fromarray(a, 'RGBA')


def binarize(im):
    a = np.asarray(im).copy(); a[..., 3] = np.where(a[..., 3] > 110, 255, 0); return Image.fromarray(a, 'RGBA')


class Frame:
    def __init__(self, FR, hover):
        self.FR, self.hover = FR, hover

    def place(self, sp, dx=0, dy=0):
        FR = self.FR
        a = np.asarray(sp)[..., 3] > 0
        ys = np.nonzero(a.any(1))[0]; low = a[ys.max() - max(1, (ys.max() - ys.min()) // 4):ys.max() + 1]
        cx = int(round(np.nonzero(low)[1].mean())) if low.any() else sp.width // 2
        o = Image.new('RGBA', (FR, FR))
        o.alpha_composite(sp, (FR // 2 - cx + dx, FR - sp.height - 2 - self.hover + dy)) if True else None
        return o


def shift(fr, dx, dy):
    o = Image.new('RGBA', fr.size); o.alpha_composite(fr, (dx, dy)); return o


def squash(fr, sx, sy):
    """Escala em torno do pe (centro de baixo do conteudo)."""
    bb = fr.getbbox()
    if not bb: return fr
    c = fr.crop(bb); w, h = max(1, round(c.width * sx)), max(1, round(c.height * sy))
    c = binarize(c.resize((w, h), Image.NEAREST))
    o = Image.new('RGBA', fr.size); cx = (bb[0] + bb[2]) // 2
    o.alpha_composite(c, (cx - w // 2, bb[3] - h)); return o


def rotate(fr, deg):
    bb = fr.getbbox()
    if not bb: return fr
    pivot = ((bb[0] + bb[2]) / 2, bb[3])
    return binarize(fr.rotate(deg, resample=Image.NEAREST, center=pivot))


def tint(fr, col, t):
    a = np.asarray(fr).astype(float).copy(); m = a[..., 3] > 0
    a[..., :3][m] = a[..., :3][m] * (1 - t) + np.array(col) * t
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


def dissolve(fr, frac, seed):
    """Desfaz em pixels de cima para baixo (relativo ao proprio conteudo), com ruido; frac = parte que some."""
    a = np.asarray(fr).copy(); rnd = np.random.RandomState(seed)
    bb = fr.getbbox()
    if not bb: return fr
    h = a.shape[0]; ys = np.clip((np.arange(h)[:, None] - bb[1]) / max(1, bb[3] - bb[1]), 0, 1)
    kill = (rnd.rand(*a.shape[:2]) * 0.5 + (1 - ys) * 0.5) < frac
    a[kill] = 0; return Image.fromarray(a, 'RGBA')


def build(mid, n, FR, H, hover, style):
    wd = work(mid, n); P = json.load(open(os.path.join(wd, 'picks.json')))
    flips = set(P.get('flip', [])); aflips = set(P.get('atk_flip', []))
    F = Frame(FR, hover)
    maxw = FR - 2 - 4 * max(1, FR // 32)  # margem para o avanco do ataque
    maxh = FR - 4 - hover
    rows = {k: [] for k in ('idle', 'walk', 'attack', 'hit', 'death')}
    kf = P.get('keep_frac', 0.01)
    for d in DIRS:
        fdx, fdy = FWD[d]
        base_img = load(os.path.join(wd, 'rb_' + P['dirs'][d].lstrip('!')), d in flips, kf)
        if P.get('recolor_top'): base_img = recolor_top(base_img, P['recolor_top'])
        b = F.place(binarize(fit(base_img, maxw, maxh, H)))
        if d in P.get('atk', {}):
            ai = load(os.path.join(wd, 'rb_' + P['atk'][d].lstrip('!')), d in aflips, kf)
            if P.get('recolor_top'): ai = recolor_top(ai, P['recolor_top'])
            A = F.place(binarize(fit(ai, maxw, maxh, H * 1.05)))
        else:
            A = squash(shift(b, fdx, fdy), 1.06, 0.94)
        s = max(1, FR // 32)  # passo de deslocamento proporcional ao quadro
        if style == 'fly':
            rows['idle'].append([b, shift(b, 0, -s), shift(b, 0, -2 * s), shift(b, 0, -s)])
            rows['walk'].append([shift(b, 0, -s * k) for k in (0, 1, 2, 2, 1, 0)])
        elif style == 'spin':
            rows['idle'].append([b, rotate(b, 3), b, rotate(b, -3)])
            rows['walk'].append([rotate(shift(b, 0, -s * k), r) for k, r in ((0, 5), (1, 2), (1, -2), (0, -5), (1, -2), (1, 2))])
        elif style == 'hop':
            rows['idle'].append([b, b, squash(b, 1.04, 0.96), squash(b, 1.04, 0.96)])
            rows['walk'].append([squash(b, 1.08, 0.9), shift(b, 0, -2 * s), shift(b, 0, -4 * s), shift(b, 0, -3 * s), shift(b, 0, -s), squash(b, 1.08, 0.9)])
        else:
            rows['idle'].append([b, b, squash(b, 1.0, 0.97), squash(b, 1.0, 0.97)])
            rows['walk'].append([b, shift(rotate(b, 3), 0, -s), shift(b, 0, -s), b, shift(rotate(b, -3), 0, -s), shift(b, 0, -s)])
        rows['attack'].append([b, squash(shift(b, -fdx * 2 * s, -fdy * s), 1.05, 0.93), A, shift(A, fdx * 3 * s, fdy * 2 * s),
                               shift(A, fdx * s, fdy * s), b])
        rows['hit'].append([tint(shift(b, -fdx * 2 * s, -fdy * 2 * s), (250, 229, 200), 0.3), shift(b, -fdx * s, -fdy * s)])
        fall = b if style != 'fly' else shift(b, 0, hover)
        rows['death'].append([tint(b, (250, 229, 200), 0.2), rotate(shift(b, 0, hover // 3), -18), squash(rotate(fall, -25), 1.1, 0.75),
                              dissolve(squash(fall, 1.2, 0.55), 0.25, 1), dissolve(squash(fall, 1.25, 0.45), 0.5, 2),
                              dissolve(squash(fall, 1.3, 0.35), 0.72, 3)])
    allf = [f for r in rows.values() for row in r for f in row]
    strip = Image.new('RGB', (FR * len(allf), FR), (0, 0, 0))
    for i, f in enumerate(allf): strip.paste(f.convert('RGB'), (i * FR, 0), f)
    pal = strip.quantize(40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    def q(f):
        r = f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA'); r.putalpha(f.getchannel('A')); return r
    od = os.path.join(GAME, 'assets', 'monsters', mid); os.makedirs(od, exist_ok=True)
    for name, rr in rows.items():
        sh = Image.new('RGBA', (FR * len(rr[0]), FR * 5))
        for r, row in enumerate(rr):
            for c, f in enumerate(row): sh.alpha_composite(q(f), (c * FR, r * FR))
        out = os.path.join(od, f'mon_{mid}_s{n}_{name}.png'); sh.save(out)
    print('ok', mid, n, FR)


if __name__ == '__main__':
    mid, n, *rest = sys.argv[1:]
    o = {rest[i].lstrip('-'): rest[i + 1] for i in range(0, len(rest), 2)}
    FR = int(o.get('frame', 96))
    build(mid, int(n), FR, int(o.get('height', DEF[FR])), int(o.get('hover', 0)), o.get('style', 'walk'))
