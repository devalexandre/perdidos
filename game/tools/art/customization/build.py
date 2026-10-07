"""Etapa 2 (sem IA, deterministica): monta as folhas de personalizacao a partir das edicoes (edits.py).

    python build.py <body|all>        -> assets/characters/base|hair/ (+ face/ via earrings.py)

Corpo-base = quadro ORIGINAL aprovado do Viajante, trocando so a regiao do cabelo original (mascara exata
vinda da edicao "recolorir o cabelo de verde") pelos pixels da edicao "raspado" -> roupa, rosto, proporcao e
posicao identicos as folhas chr_traveler_* (itens do ADENDO 1 continuam alinhados).
Mascara (mesma folha): R = pele, G = olhos, B = cabelo raspado; valor = tom da rampa (i*40+20).
Cabelo: pixels verdes (+ contorno escuro colado) da edicao do estilo -> rampa de cinza de 5 tons.
  - estilo padrao (spiky / ponytail): pixels ORIGINAIS do cabelo (quadro a quadro, como hoje no jogo);
  - outros estilos: idle e sit da propria edicao; nos passos o cabelo do idle acompanha a cabeca (deslocamento
    medido no corpo-base) -> sem "piscar" de formato entre quadros do andar.
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, label, binary_fill_holes
from common import (DIRS, FR, STEP, GAME, frames, is_green, hsv, assemble, sheet_image, save_png, CUSTOM_WORK,
                    translate)
from layers import cached
from edits import STYLES, DEFAULT_STYLE, PER_FRAME_WALK

N8 = np.ones((3, 3), bool)
HAIR_TONES = 5


def lum(rgb):
    f = rgb.astype(np.float32); return 0.299 * f[..., 0] + 0.587 * f[..., 1] + 0.114 * f[..., 2]


def body_bounds(a):
    ys = np.nonzero((a[..., 3] > 0).any(1))[0]; return ys.min(), ys.max()


def hair_mask(fr, head_frac=0.5, ref=None):
    """Pixels de cabelo de um quadro editado (verde + contorno escuro colado), so componentes ligados a
    cabeca (parte de cima do corpo) -> ignora verde perdido na roupa."""
    a = np.asarray(fr); op = a[..., 3] > 0
    g = is_green(a[..., :3]) & op
    g |= is_green(a[..., :3], relaxed=True) & op & binary_dilation(g, N8)
    top, bot = body_bounds(np.asarray(ref) if ref is not None else a)
    lab, n = label(g, N8)
    if n:
        lim = top + int((bot - top) * head_frac); keep = np.zeros(n + 1, bool)
        sz = np.bincount(lab.ravel())
        for i in range(1, n + 1):
            ys = np.nonzero(lab == i)[0]
            keep[i] = ys.min() <= lim and sz[i] >= 3
        g = keep[lab]
    # contorno: pixel escuro e colado no verde (1 anel), e buracos pequenos
    dark = op & (lum(a[..., :3]) < 70)
    g |= dark & binary_dilation(g, N8)
    holes = binary_fill_holes(g) & ~g & op; hl, hn = label(holes)
    if hn:
        hs = np.bincount(hl.ravel()); small = hs <= 4; small[0] = False; g |= small[hl]
    return g


def clean(mask, min_size=3):
    lab, n = label(mask, N8)
    if not n: return mask
    sz = np.bincount(lab.ravel()); keep = sz >= min_size; keep[0] = False; return keep[lab]


def main_body(op):
    """So o corpo: a maior peca + pecas grandes (>= 5% dela) + a sombra no chao (pecas no rodape).
    Tira fiapos soltos do cabelo original/da edicao que ficaram flutuando."""
    lab, n = label(op, N8)
    if n <= 1: return op
    sz = np.bincount(lab.ravel()); sz[0] = 0; big = sz.max(); keep = sz >= big * 0.05
    bot = np.nonzero(op.any(1))[0].max()
    for i in range(1, n + 1):
        if not keep[i] and np.nonzero(lab == i)[0].min() >= bot - 6: keep[i] = True
    keep[0] = False
    return keep[lab]


def kmeans1d(vals, k, iters=40):
    v = np.sort(vals.astype(np.float32)); c = np.quantile(v, (np.arange(k) + 0.5) / k)
    for _ in range(iters):
        idx = np.abs(v[:, None] - c[None]).argmin(1)
        c = np.array([v[idx == i].mean() if (idx == i).any() else c[i] for i in range(k)])
    return np.sort(c)


def tones_of(values, centers):
    return np.abs(values[..., None].astype(np.float32) - centers[None]).argmin(-1)


def enc(t): return (t * STEP + STEP // 2).astype(np.uint8)


def head_offset(base_idle, base_walk, rng=8):
    """Deslocamento (dx, dy) da cabeca do idle para o quadro de passo (corpo-base), pela parte de cima."""
    a = np.asarray(base_idle).astype(np.int32); b = np.asarray(base_walk).astype(np.int32)
    top, bot = body_bounds(a); h = int((bot - top) * 0.30)
    ys, ye = top, top + h; A = a[ys:ye]; best = (1e18, 0, 0)
    for dy in range(-rng, rng + 1):
        for dx in range(-rng, rng + 1):
            B = np.zeros_like(A)
            y0, y1 = ys + dy, ye + dy
            if y0 < 0 or y1 > FR: continue
            src = b[y0:y1]; B = np.roll(src, -dx, axis=1)
            if dx > 0: B[:, -dx:] = 0
            elif dx < 0: B[:, :-dx] = 0
            oa, ob = A[..., 3] > 0, B[..., 3] > 0
            d = (oa != ob).sum() * 400 + (np.abs(A[..., :3] - B[..., :3]).sum(-1) * (oa & ob)).sum() / 30
            if d < best[0]: best = (d, dx, dy)
    return best[1], best[2]


# ------------------------------------------------------------------------------------------------

def build_body(body):
    O = cached(body, 'orig'); Z = cached(body, 'buzz'); G = cached(body, DEFAULT_STYLE[body])
    keys = list(O.keys()); base = {}; scalp = {}; orig_hair = {}
    for k in keys:
        o = np.asarray(O[k]).copy(); z = np.asarray(Z[k]) if k in Z else None
        mh = hair_mask(G[k], 0.9, ref=O[k]) if k in G else np.zeros(o.shape[:2], bool)
        mh &= o[..., 3] > 0
        orig_hair[k] = mh
        if z is None:
            print('AVISO sem raspado', k); base[k] = Image.fromarray(o); scalp[k] = np.zeros_like(mh); continue
        ms = hair_mask(Image.fromarray(z), 0.3, ref=O[k])
        top, bot = body_bounds(o); ms[top + int((bot - top) * 0.35):] = False
        R = binary_dilation(mh, N8) | ms
        o[R] = z[R]
        # sobras do cabelo original fora da regiao (pixels soltos) somem
        o[..., 3] = np.where(o[..., 3] > 0, 255, 0)
        o[~main_body(o[..., 3] > 0)] = 0
        base[k] = Image.fromarray(o); scalp[k] = ms & (o[..., 3] > 0)
    return O, base, scalp, orig_hair


def quant_frames(frs, n=48):
    strip = Image.new('RGB', (FR * len(frs), FR))
    for i, f in enumerate(frs): strip.paste(f.convert('RGB'), (i * FR, 0), f)
    pal = strip.quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    def q(f):
        r = f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA'); r.putalpha(f.getchannel('A')); return r
    return q, pal


def hair_frames(body, style, O, base, orig_hair):
    """{key: quadro RGBA com so o cabelo (cores da fonte)}."""
    out = {}
    if style == DEFAULT_STYLE[body]:
        for k in O:
            o = np.asarray(O[k]).copy(); m = orig_hair[k]; m = clean(m, max(6, int(m.sum() * 0.03))); o[~m] = 0; out[k] = Image.fromarray(o)
        return out
    E = cached(body, style)
    for k in O:
        if (k[2] in ('idle', 'sit') or k[1] in PER_FRAME_WALK[body]) and k in E:
            e = np.asarray(E[k]).copy(); m = hair_mask(E[k], 0.5, ref=base[k]); m = clean(m, max(6, int(m.sum() * 0.03))); e[~m] = 0
            out[k] = Image.fromarray(e)
    for k in O:
        if k[2] in ('wl', 'wr') and k not in out:
            ki = ('idle', k[1], 'idle'); dx, dy = head_offset(base[ki], base[k])
            out[k] = translate(out[ki], dx, dy)
    return out


def to_ramp(frs, n=HAIR_TONES):
    """Cabelo -> rampa de cinza (n tons, pelo brilho; tom 0 = contorno). Mesmos centros em todos os quadros."""
    vals = np.concatenate([lum(np.asarray(f)[..., :3])[np.asarray(f)[..., 3] > 0] for f in frs.values()])
    c = kmeans1d(vals, n); out = {}
    for k, f in frs.items():
        a = np.asarray(f); op = a[..., 3] > 0; t = tones_of(lum(a[..., :3]), c)
        g = np.zeros_like(a); v = enc(t); g[..., 0] = v; g[..., 1] = v; g[..., 2] = v; g[..., 3] = np.where(op, 255, 0)
        g[~op] = 0; out[k] = Image.fromarray(g)
    return out, c


def skin_mask(a):
    """Pele do corpo-base: tons quentes claros/medios, so nas pecas (componentes) que tem bastante pele CLARA
    (rosto, pescoco, maos) -> a mochila/luvas (marrom-laranja, sem tom claro) ficam de fora."""
    h, s, v = hsv(a[..., :3]); op = a[..., 3] > 0
    cand = op & (h >= 5) & (h <= 40) & (s >= 0.25) & (s <= 0.78) & (v >= 0.60)
    core = cand & (v >= 0.88) & (s <= 0.6) & (h >= 15)
    lab, n = label(cand, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool))
    if not n: return cand
    tot = np.bincount(lab.ravel(), minlength=n + 1); cc = np.bincount(lab[core], minlength=n + 1)
    keep = (cc >= 1) & (cc >= tot * 0.2); keep[0] = False
    return keep[lab]


def eye_mask(a, skin, scalp):
    """Olhos: dentro do rosto (caixa da pele da cabeca), na faixa dos olhos, pixels que nao sao pele e estao
    entre pele a esquerda e a direita; ficam so os tons de iris (quentes, medios) e a pupila colada neles.
    Devolve (mascara, tom 0..2)."""
    op = a[..., 3] > 0; top, bot = body_bounds(a); head = np.zeros_like(skin); head[:top + int((bot - top) * 0.36)] = True
    face = skin & head
    ys, xs = np.nonzero(face)
    z = np.zeros(skin.shape, bool)
    if len(ys) < 10: return z, np.zeros(skin.shape, int)
    ft, fb = ys.min(), ys.max(); fh = fb - ft
    band = np.zeros_like(z); band[ft + int(fh * 0.28):ft + int(fh * 0.72) + 1] = True
    left = np.maximum.accumulate(face, axis=1); right = np.maximum.accumulate(face[:, ::-1], axis=1)[:, ::-1]
    inside = band & left & right & op & ~skin & ~scalp
    h, s, v = hsv(a[..., :3])
    iris = inside & ((h <= 40) | (h >= 330)) & (s >= 0.2) & (v >= 0.25) & (v <= 0.72)
    pupil = inside & (v < 0.25) & binary_dilation(iris, N8)
    m = iris | pupil
    # orelha != olho: descarta pecas coladas no cabelo raspado ou no fundo (olho fica cercado de pele/contorno)
    lab, n = label(m, N8); bad = binary_dilation(scalp | ~op, N8)
    for i in range(1, n + 1):
        c = lab == i
        if (c & bad).any() or c.sum() < 2: m &= ~c
    t = np.where(v < 0.3, 0, np.where(v < 0.5, 1, 2))
    return m, t


def save_sheets(per, path_of, ref=None):
    for anim, rows in assemble(per, ref=ref).items():
        save_png(sheet_image(rows), path_of(anim)); print('  ', path_of(anim))


def base_palette_report(body, q_base):
    """Lista as cores do corpo-base quantizado (para escolher pele/olhos em masks.json)."""
    cols = {}
    for f in q_base.values():
        a = np.asarray(f); op = a[..., 3] > 0
        for c in map(tuple, a[op][:, :3]): cols[c] = cols.get(c, 0) + 1
    return sorted(cols.items(), key=lambda x: -x[1])


SKIN_TONES = 4


def build(body):
    import pickle
    print('==', body)
    O, base, scalp, orig_hair = build_body(body)
    pickle.dump(({k: np.asarray(v) for k, v in base.items()}, scalp, orig_hair), open(os.path.join(CUSTOM_WORK, body, '_base.pkl'), 'wb'))
    keys = list(O)
    B = {k: np.asarray(base[k]).copy() for k in keys}
    skin = {k: skin_mask(B[k]) for k in keys}
    eyes = {k: eye_mask(B[k], skin[k], scalp[k]) for k in keys}
    for k in keys: skin[k] &= ~scalp[k]
    sk_c = kmeans1d(np.concatenate([lum(B[k][..., :3])[skin[k]] for k in keys]), SKIN_TONES)
    sc_c = kmeans1d(np.concatenate([lum(B[k][..., :3])[scalp[k]] for k in keys]), HAIR_TONES)
    # rampas medidas (= Viajante atual): media RGB de cada tom
    def ramp_of(frs, masks, tone_fn, n):
        acc = np.zeros((n, 3)); cnt = np.zeros(n)
        for k in keys:
            a = np.asarray(frs[k]); m = masks[k]; t = tone_fn(k, a)
            for i in range(n):
                sel = m & (t == i); acc[i] += a[sel][:, :3].sum(0); cnt[i] += sel.sum()
        return [[int(round(x)) for x in acc[i] / max(1, cnt[i])] for i in range(n)]
    skin_ramp = ramp_of(B, skin, lambda k, a: tones_of(lum(a[..., :3]), sk_c), SKIN_TONES)
    eye_ramp = ramp_of(B, {k: eyes[k][0] for k in keys}, lambda k, a: eyes[k][1], 3)
    # cabelo padrao (pixels originais) -> rampa medida
    hdef = hair_frames(body, DEFAULT_STYLE[body], O, base, orig_hair)
    hvals = np.concatenate([lum(np.asarray(f)[..., :3])[np.asarray(f)[..., 3] > 0] for f in hdef.values()])
    h_c = kmeans1d(hvals, HAIR_TONES)
    hair_ramp = ramp_of(hdef, {k: np.asarray(hdef[k])[..., 3] > 0 for k in keys}, lambda k, a: tones_of(lum(a[..., :3]), h_c), HAIR_TONES)
    print('  pele', skin_ramp, '\n  olhos', eye_ramp, '\n  cabelo', hair_ramp)
    # mascara + corpo-base com as cores padrao nos pixels recoloriveis
    masks = {}; per_base = {}
    for k in keys:
        a = B[k]; op = a[..., 3] > 0
        m = np.zeros_like(a); m[..., 3] = np.where(op, 255, 0)
        ts = tones_of(lum(a[..., :3]), sk_c); tz = tones_of(lum(a[..., :3]), sc_c); em, et = eyes[k]
        m[..., 0] = np.where(skin[k], enc(ts), 0); m[..., 1] = np.where(em & ~skin[k], enc(et), 0)
        m[..., 2] = np.where(scalp[k] & ~skin[k] & ~em, enc(tz), 0)
        a = a.copy()
        a[skin[k]] = np.c_[np.array(skin_ramp)[ts[skin[k]]], np.full(skin[k].sum(), 255)]
        e2 = em & ~skin[k]; a[e2] = np.c_[np.array(eye_ramp)[et[e2]], np.full(e2.sum(), 255)]
        z2 = scalp[k] & ~skin[k] & ~em; a[z2] = np.c_[np.array(hair_ramp)[tz[z2]], np.full(z2.sum(), 255)]
        m[~op] = 0
        masks[k] = Image.fromarray(m); per_base[k] = Image.fromarray(a)
    q, _ = quant_frames(list(per_base.values()), 48)
    per_q = {}
    for k in keys:  # quantiza so o que nao e recolorivel (as rampas ficam exatas)
        qa = np.asarray(q(per_base[k])).copy(); a = np.asarray(per_base[k]); rec = np.asarray(masks[k])[..., :3].any(-1)
        qa[rec] = a[rec]; qa[a[..., 3] == 0] = 0; per_q[k] = Image.fromarray(qa)
    bd = os.path.join(GAME, 'assets', 'characters', 'base')
    save_sheets(per_q, lambda an: os.path.join(bd, f'chr_{body}_base_{an}.png'), ref=per_q)
    save_sheets(masks, lambda an: os.path.join(bd, f'chr_{body}_base_mask_{an}.png'), ref=per_q)
    info = {'skin': skin_ramp, 'eye': eye_ramp, 'hair': hair_ramp, 'styles': {}}
    for style in STYLES[body]:
        if style == 'buzz': continue
        hf = hdef if style == DEFAULT_STYLE[body] else hair_frames(body, style, O, base, orig_hair)
        g, c = to_ramp(hf)
        info['styles'][style] = [float(x) for x in c]
        hd = os.path.join(GAME, 'assets', 'characters', 'hair', style)
        save_sheets(g, lambda an: os.path.join(hd, f'{body}_{an}.png'), ref=per_q)
    json.dump(info, open(os.path.join(CUSTOM_WORK, body, 'measured.json'), 'w'), indent=1)


if __name__ == '__main__':
    for b in (['male', 'female'] if len(sys.argv) < 2 or sys.argv[1] == 'all' else [sys.argv[1]]):
        build(b)
