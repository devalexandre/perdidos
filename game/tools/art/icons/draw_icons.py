"""Icones de item 32x32 desenhados por codigo (pixel a pixel, so cores da paleta mestra), para drops que nao tem
geracao por IA (gen_icons.py). Mesmo acabamento dos outros icones: tons em rampa com luz de cima-esquerda,
contorno colorido de 1 px (tom escuro da propria cor, gen_icons.outline), fundo transparente.
  .tools/pyvenv/bin/python game/tools/art/icons/draw_icons.py [--preview out.png] [ids...]
Drops da forma atroz (chefe a noite, docs/arte-monstros-blender.md): eternal_ember, pequi_root, ancient_shell_shard.
Loja: return_scroll (Pergaminho de Retorno, 30/09/2026)."""
import argparse, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(HERE, '..'))
import palette as PALM  # noqa: E402

PN = {n: c for c, n in PALM.load_palette()}
S = 32
LIGHT = np.array([-0.6, -0.65, 0.6]); LIGHT = LIGHT / np.linalg.norm(LIGHT)


def P(n):
    return PN[n]


class Canvas:
    def __init__(self):
        self.a = np.zeros((S, S, 4), np.uint8)
        self.yy, self.xx = np.mgrid[0:S, 0:S].astype(float) + 0.5

    def put(self, mask, col):
        self.a[mask, :3] = col; self.a[mask, 3] = 255

    def px(self, pts, col):
        for x, y in pts:
            if 0 <= x < S and 0 <= y < S:
                self.a[y, x, :3] = col; self.a[y, x, 3] = 255

    def ellipse(self, cx, cy, rx, ry, ramp, rot=0.0, th=(-0.05, 0.35, 0.72), clip=None):
        """Elipse sombreada como domo (tom = N.L em 4 faixas da rampa)."""
        c, s = math.cos(rot), math.sin(rot)
        dx, dy = self.xx - cx, self.yy - cy
        u = (dx * c + dy * s) / rx; v = (-dx * s + dy * c) / ry
        d2 = u * u + v * v
        m = d2 <= 1.0
        if clip is not None:
            m &= clip
        nz = np.sqrt(np.clip(1 - d2, 0, 1))
        nx = u * c - v * s; ny = u * s + v * c
        ndl = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        tone = np.digitize(ndl, th)
        for k in range(4):
            self.put(m & (tone == k), ramp[k])
        return m

    def poly(self, pts, ramp, bevel=True, grad=(-0.7, -0.7)):
        """Poligono com tom por gradiente (luz de cima-esquerda) e chanfro escuro embaixo-direita."""
        im = Image.new('L', (S, S), 0); ImageDraw.Draw(im).polygon(pts, fill=255)
        m = np.asarray(im) > 0
        xs = np.array([p[0] for p in pts]); ys = np.array([p[1] for p in pts])
        cx, cy = xs.mean(), ys.mean(); ext = max(np.ptp(xs), np.ptp(ys)) / 2 + 1e-6
        g = ((self.xx - cx) * grad[0] + (self.yy - cy) * grad[1]) / ext
        tone = np.digitize(g, (-0.45, 0.0, 0.45))
        if bevel:
            inner = m.copy()
            inner[:-1, :] &= m[1:, :]; inner[:, :-1] &= m[:, 1:]
            tone = np.where(m & ~inner, np.minimum(tone, 1), tone)
        for k in range(4):
            self.put(m & (tone == k), ramp[k])
        return m

    def line(self, pts, col, w=1):
        im = Image.new('L', (S, S), 0); ImageDraw.Draw(im).line(pts, fill=255, width=w)
        m = np.asarray(im) > 0
        self.put(m, col)
        return m


def finish(cv):
    """Contorno colorido de 1 px (mesma regra do gen_icons.outline) e limpeza de pixels soltos."""
    from scipy.ndimage import binary_erosion, label
    sys.path.insert(0, HERE)
    from gen_icons import nearest
    a = cv.a.copy()
    m = a[..., 3] > 0
    edge = m & ~binary_erosion(m)
    keep = getattr(cv, 'no_outline', np.zeros((S, S), bool))
    dark = nearest(a[..., :3].astype(float) * 0.42 + np.array([6, 4, 8]))
    e = edge & ~keep
    a[e, :3] = dark[e]
    lb, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lb.ravel()); ok = sz >= 1; ok[0] = False; a[~ok[lb]] = 0
    return Image.fromarray(a, 'RGBA')


# ------------------------------------------------------------------ icones
def eternal_ember():
    """Brasa Eterna: carvao de rachaduras acesas com uma chaminha que nunca apaga e luzinhas de vaga-lume."""
    cv = Canvas()
    coal = [P('Base 1'), P('Pedra/metal 1'), P('Roxo 1'), P('Pedra/metal 2')]
    # carvao (dois calombos)
    m1 = cv.ellipse(13.5, 22.5, 9.5, 6.5, coal, rot=-0.15)
    m2 = cv.ellipse(20.5, 23.5, 7.0, 5.5, coal, rot=0.25)
    body = m1 | m2
    # rachaduras de brasa (zigue-zague) so dentro do carvao
    cr = np.zeros((S, S), bool)
    for pts in (((6, 22), (9, 21), (11, 24), (14, 23), (17, 26)), ((15, 19), (17, 22), (21, 21), (24, 24)),
                ((11, 27), (13, 26))):
        im = Image.new('L', (S, S), 0); ImageDraw.Draw(im).line(pts, fill=255, width=1)
        cr |= np.asarray(im) > 0
    cr &= body
    cv.put(cr, P('Vermelho 3'))
    hot = np.zeros((S, S), bool); hot[21, 17] = hot[22, 17] = hot[24, 11] = hot[21, 21] = True
    cv.put(hot & body, P('Ouro/amarelo 3'))
    # chama: tres camadas (vermelha > laranja > miolo claro), ponta torta
    cv.poly([(10, 19), (11, 13), (14, 8), (15, 3), (17, 7), (19, 5), (19.5, 11), (22, 14), (21.5, 19)],
            [P('Vermelho 2'), P('Vermelho 3'), P('Vermelho 3'), P('Vermelho 4')], bevel=False)
    cv.poly([(12.5, 19), (13.5, 14), (15.5, 10), (16.5, 7), (18, 11), (20, 14), (19.5, 19)],
            [P('Vermelho 4'), P('Ouro/amarelo 3'), P('Ouro/amarelo 3'), P('Ouro/amarelo 4')], bevel=False)
    cv.poly([(14.5, 19), (15.5, 15), (17, 12.5), (18.5, 16), (18, 19)],
            [P('Ouro/amarelo 4'), P('Ouro/amarelo 4'), P('Base 2'), P('Base 2')], bevel=False)
    # luzinhas de vaga-lume em volta (verde-amarelo e amarelo), com cruz
    for x, y, c in ((5, 9, P('Verde folha 4')), (26, 8, P('Ouro/amarelo 4')), (27, 16, P('Verde folha 4'))):
        cv.px([(x, y)], P('Base 2'))
        cv.px([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], c)
    cv.px([(8, 14), (24, 3)], P('Ouro/amarelo 3'))
    cv.no_outline = np.zeros((S, S), bool)
    for x, y in ((5, 9), (26, 8), (27, 16), (8, 14), (24, 3)):
        cv.no_outline[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = True
    return finish(cv)


def _taper(cv, pts, w0, w1, ramp):
    """Galho/raiz afunilado: poligono ao longo de uma polilinha (largura w0 -> w1)."""
    pts = [np.array(p, float) for p in pts]
    L, R_ = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        d = d / (np.linalg.norm(d) + 1e-9)
        nrm = np.array([-d[1], d[0]])
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        L.append(tuple(p + nrm * w)); R_.append(tuple(p - nrm * w))
    return cv.poly(L + R_[::-1], ramp)


def pequi_root():
    """Raiz de Pequi: raiz retorcida do cerrado (corte claro em cima, radicelas) com um pequi aberto preso nela
    (casca verde, polpa amarela)."""
    cv = Canvas()
    wood = [P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Madeira/cabelo 3'), P('Madeira/cabelo 4')]
    # radicelas (atras), depois a raiz principal em S
    _taper(cv, [(14, 17), (10, 18), (6, 16), (3, 17)], 3.2, 1.2, wood)
    _taper(cv, [(11, 23), (13, 26), (12, 29)], 3.0, 1.2, wood)
    _taper(cv, [(9, 25), (5, 25), (3, 28)], 2.6, 1.0, wood)
    _taper(cv, [(19, 6), (17, 10), (18, 14), (15, 18), (12, 22), (9, 25), (6, 27)], 7.0, 2.2, wood)
    # no retorcido (calombo) e casca riscada
    cv.ellipse(16.5, 15.5, 3.2, 2.6, wood, rot=0.6)
    cv.px([(17, 9), (16, 12), (14, 19), (11, 22)], P('Madeira/cabelo 1'))
    cv.px([(16, 8), (17, 13), (13, 18), (10, 23)], P('Madeira/cabelo 4'))
    # corte em cima (madeira clara com anel)
    cv.ellipse(19.3, 5.3, 3.6, 2.3, [P('Pergaminho 2'), P('Pergaminho 3'), P('Pergaminho 3'), P('Pergaminho 4')], rot=0.35)
    cv.px([(19, 5), (20, 5)], P('Madeira/cabelo 3'))
    # folhinha brotando
    cv.ellipse(24.5, 9.0, 3.6, 1.8, [P('Verde folha 1'), P('Verde folha 2'), P('Verde folha 3'), P('Verde folha 4')],
               rot=-0.7)
    cv.px([(22, 11)], P('Verde folha 2'))
    # pequi aberto: casca verde por tras, polpa amarela na frente
    cv.ellipse(22.5, 22.0, 7.0, 6.6, [P('Verde folha 1'), P('Verde folha 2'), P('Verde folha 3'), P('Verde folha 4')])
    cv.ellipse(23.2, 23.2, 4.8, 4.4, [P('Ouro/amarelo 2'), P('Ouro/amarelo 3'), P('Ouro/amarelo 3'), P('Ouro/amarelo 4')])
    cv.px([(22, 22), (24, 25), (25, 22), (21, 25)], P('Ouro/amarelo 2'))
    cv.px([(21, 21), (22, 21)], P('Pergaminho 4'))
    return finish(cv)


def ancient_shell_shard():
    """Caco de Casco Antigo: lasca quebrada (bordas angulosas) de casco de tatu, placas em fileiras gastas e
    acinzentadas, com uma rachadura que ainda brilha fraquinho."""
    cv = Canvas()
    shell = [P('Pele escura 2'), P('Pele escura 3'), P('Pergaminho 2'), P('Pergaminho 3')]
    pts = [(3, 11), (9, 5), (14, 7), (20, 2), (28, 7), (29, 15), (25, 19), (27, 25), (19, 29), (14, 25), (9, 26),
           (5, 21)]
    im = Image.new('L', (S, S), 0); ImageDraw.Draw(im).polygon(pts, fill=255)
    m = np.asarray(im) > 0
    cv.put(m, P('Pele escura 1'))      # juntas entre as placas
    dark = [P('Pele escura 1'), P('Pele escura 2'), P('Pele escura 3'), P('Pergaminho 2')]
    for r, y in enumerate((5.5, 12, 18.5, 25)):
        off = 0 if r % 2 else 4.0
        for x in np.arange(off, 34, 8.0):
            cv.ellipse(x + 0.5, y + 0.5, 4.3, 3.3, shell if r < 2 else dark, clip=m)
    # gasto: placas acinzentadas (liquen) e lascas claras na borda quebrada
    for x, y in ((21, 5), (22, 5), (8, 16), (9, 16), (25, 16), (13, 22)):
        if m[y, x]:
            cv.px([(x, y)], P('Pedra/metal 3'))
    for x, y in ((21, 6), (8, 17), (13, 23)):
        if m[y, x]:
            cv.px([(x, y)], P('Pedra/metal 2'))
    # rachadura quase apagada: vermelho escuro com pontos acesos
    crack = [(20, 3), (18, 8), (19, 12), (16, 16), (17, 20), (15, 24), (16, 28)]
    im = Image.new('L', (S, S), 0); ImageDraw.Draw(im).line(crack, fill=255, width=1)
    c = (np.asarray(im) > 0) & m
    cv.put(c, P('Vermelho 2'))
    cv.px([(18, 8), (16, 16), (15, 24)], P('Vermelho 3'))
    cv.px([(16, 16)], P('Ouro/amarelo 3'))
    return finish(cv)


def return_scroll():
    """Pergaminho de Retorno: pergaminho enrolado na diagonal, pontas com a espiral do papel e fita azul amarrada
    no meio (lacos e pontas soltas). Sem simbolo nenhum."""
    cv = Canvas()
    paper = [P('Pergaminho 2'), P('Pergaminho 3'), P('Pergaminho 4'), P('Pergaminho 4')]
    ax, ay, bx, by = 5.0, 26.5, 26.5, 6.0
    dx, dy = bx - ax, by - ay
    ln = math.hypot(dx, dy); ux, uy = dx / ln, dy / ln; nx, ny = -uy, ux
    r = 5.4

    def quad(t0, t1, w):
        p0 = (ax + ux * t0, ay + uy * t0); p1 = (ax + ux * t1, ay + uy * t1)
        return [(p0[0] + nx * w, p0[1] + ny * w), (p1[0] + nx * w, p1[1] + ny * w),
                (p1[0] - nx * w, p1[1] - ny * w), (p0[0] - nx * w, p0[1] - ny * w)]
    # corpo do rolo (cilindro: claro em cima-esquerda, escuro embaixo-direita)
    cv.poly(quad(1.5, ln - 1.5, r), paper, bevel=True, grad=(nx * 0.9, ny * 0.9))
    # pontas: elipses com a espiral do papel
    rot = math.atan2(ny, nx)
    for t in (1.5, ln - 1.5):
        cx, cy = ax + ux * t, ay + uy * t
        cv.ellipse(cx, cy, r, 2.2, [P('Pergaminho 2'), P('Pergaminho 3'), P('Pergaminho 3'), P('Pergaminho 4')], rot=rot)
        cv.ellipse(cx, cy, r * 0.7, 1.6, [P('Pergaminho 2')] * 4, rot=rot)
        cv.ellipse(cx, cy, r * 0.42, 0.9, [P('Pergaminho 1')] * 4, rot=rot)
    # fita azul no meio, com laco e duas pontas caidas
    mid = ln * 0.5
    blue = [P('Azul ceu 1'), P('Azul ceu 2'), P('Azul ceu 3'), P('Azul ceu 4')]
    cv.poly(quad(mid - 1.3, mid + 1.3, r + 0.6), blue, bevel=True, grad=(nx * 0.9, ny * 0.9))
    kx, ky = ax + ux * mid + nx * (r + 0.4), ay + uy * mid + ny * (r + 0.4)
    cv.ellipse(kx - 3.2, ky - 0.6, 2.6, 1.6, blue, rot=0.5)
    cv.ellipse(kx + 2.4, ky - 2.6, 2.6, 1.6, blue, rot=-0.9)
    cv.poly([(kx - 0.6, ky), (kx - 2.8, ky + 5.5), (kx - 1.2, ky + 5.0), (kx + 0.4, ky + 0.6)], blue, bevel=False)
    cv.poly([(kx + 0.2, ky), (kx + 3.6, ky + 4.0), (kx + 4.6, ky + 2.6), (kx + 1.0, ky - 0.4)], blue, bevel=False)
    cv.ellipse(kx, ky, 1.3, 1.3, [P('Azul ceu 2'), P('Azul ceu 3'), P('Azul ceu 3'), P('Azul ceu 4')])
    return finish(cv)


ICONS = {'eternal_ember': eternal_ember, 'pequi_root': pequi_root, 'ancient_shell_shard': ancient_shell_shard,
         'return_scroll': return_scroll}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ids', nargs='*')
    ap.add_argument('--preview', default='')
    ap.add_argument('--no-install', action='store_true')
    a = ap.parse_args()
    ids = a.ids or list(ICONS)
    ims = []
    for k in ids:
        im = ICONS[k]()
        ims.append(im)
        if not a.no_install:
            im.save(os.path.join(GAME, 'assets', 'items', 'icons', f'icon_item_{k}.png'))
    if a.preview:
        ref = [Image.open(os.path.join(GAME, 'assets', 'items', 'icons', f'icon_item_{n}.png')).convert('RGBA')
               for n in ('armadillo_shell', 'firefly_light', 'spinning_leaf')]
        allim = ims + ref
        b = Image.new('RGBA', (len(allim) * 34, 68), (22, 30, 58, 255))
        b.paste((118, 158, 86, 255), (0, 34, b.width, 68))
        for i, im in enumerate(allim):
            b.alpha_composite(im, (i * 34 + 1, 1)); b.alpha_composite(im, (i * 34 + 1, 35))
        b.resize((b.width * 8, b.height * 8), Image.NEAREST).save(a.preview)


if __name__ == '__main__':
    main()
