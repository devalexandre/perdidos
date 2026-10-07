"""Monta folhas 96x96 (linhas S, SE, E, NE, N) de um personagem a partir das imagens escolhidas.
Generaliza build_sheets.py (Viajante v2). Uso:
  build_npc.py autopick <npc>     escolhe wl/wr de cada direcao (mais parecido com o idle) -> picks.json
  build_npc.py build <npc>        rb_*.png (fundo removido) -> assets/npcs/npc_<npc>_{idle,walk[,sit]}.png
  build_npc.py build <npc> --out <res_base> --height 84 [--palette-from sheet.png] [--only sit]
picks.json (pasta de trabalho $NPC_WORK/<npc>): {"dirs": {"s": {"idle": f, "wl": f, "wr": f, "flip": bool}, ...},
  "sit": {"s": f, ...}, "sit_flip": ["e", ...]}. Um nome com prefixo "!" usa a imagem espelhada so naquele quadro.
"hair_fix": [{"files": [...], "frac": 0.24, "lo": [r,g,b], "hi": [r,g,b]}] recolore cabelo que a edicao escureceu.  flip = espelhar (a linha E deve olhar para a DIREITA da tela).
Escala: cada quadro ajustado a altura do personagem (height); sentado = sit_scale (padrao 0.72) dessa altura."""
import glob, json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
FR = 96; DIRS = ['s', 'se', 'e', 'ne', 'n']
CFG = json.load(open(os.path.join(HERE, 'npc', 'npcs.json')))


def work(npc): return os.path.join(os.environ.get('NPC_WORK', os.path.join(HERE, 'work')), npc)


def _thumb(path):
    im = Image.open(path).convert('RGB'); a = np.asarray(im).astype(int)
    m = (np.abs(a - 255).sum(2) > 40); ys, xs = np.nonzero(m)
    if len(ys) == 0: return None
    c = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).resize((48, 96), Image.BOX)
    return np.asarray(c).astype(float)


def autopick(npc):
    wd = work(npc); pp = os.path.join(wd, 'picks.json'); P = json.load(open(pp))
    for d, p in P['dirs'].items():
        ref = _thumb(os.path.join(wd, p['idle']))
        for tag in ('wl', 'wr'):
            if p.get(tag): continue
            best = None
            for f in sorted(glob.glob(os.path.join(wd, f'w_{d}_{tag}_*.png'))):
                t = _thumb(f); s = np.abs(t - ref).mean() if t is not None else 1e9
                if best is None or s < best[0]: best = (s, os.path.basename(f))
            if best: p[tag] = best[1]; print(npc, d, tag, best[1], round(best[0], 1))
    json.dump(P, open(pp, 'w'), indent=1)


HAIR = {}  # arquivo -> {"frac", "lo", "hi"}: recolore cabelo escuro-azulado (topo da figura) para outra rampa


def hair_fix(a, o):
    al = a[..., 3] > 0; ys = np.nonzero(al.any(1))[0]; top, bot = ys.min(), ys.max()
    lim = top + int((bot - top) * o.get('frac', 0.24)); rgb = a[..., :3].astype(float)
    L = rgb.mean(2); sat = rgb.max(2) - rgb.min(2)
    m = np.zeros(al.shape, bool); m[top:lim] = True
    m &= al & (L < 120) & (sat < 60) & (rgb[..., 2] >= rgb[..., 0] - 5)
    t = np.clip(L / 120.0, 0, 1)[..., None]; lo = np.array(o['lo'], float); hi = np.array(o['hi'], float)
    rgb[m] = (lo + t * (hi - lo))[m]; a[..., :3] = rgb.astype(np.uint8); return a


def load(path, flip):
    im = Image.open(path).convert('RGBA'); a = np.asarray(im).copy()
    if os.path.basename(path) in HAIR: a = hair_fix(a, HAIR[os.path.basename(path)])
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    lab, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lab.ravel()); keep = sz >= sz[1:].max() * 0.004; keep[0] = False; a[~keep[lab]] = 0
    im = Image.fromarray(a, 'RGBA'); im = im.crop(im.getbbox())
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def scale(im, k):
    # k > 0: fator; k < 0: altura alvo em px (ajuste por imagem, como no Viajante v2)
    if k < 0: k = -k / im.height
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)


def place(sp, dy=0):
    a = np.asarray(sp)[..., 3] > 0
    # centro pelos pes: media horizontal das 25% linhas de baixo (props altos nao deslocam o corpo)
    ys = np.nonzero(a.any(1))[0]; low = a[ys.max() - max(1, (ys.max() - ys.min()) // 4):ys.max() + 1]
    cx = int(round(np.nonzero(low)[1].mean()))
    o = Image.new('RGBA', (FR, FR)); o.alpha_composite(sp, (FR // 2 - cx, FR - sp.height - 1 + dy)); return o


def breathe(fr):
    a = np.asarray(fr).copy(); ys = np.nonzero(a[..., 3].any(1))[0]; top, bot = ys.min(), ys.max()
    cut = top + int((bot - top) * 0.55); up = a[top:cut].copy(); a[top:cut] = 0
    a[top + 1:cut + 1] = np.where(up[..., 3:] > 0, up, a[top + 1:cut + 1]); return Image.fromarray(a, 'RGBA')


def bob(fr, dy):
    o = Image.new('RGBA', (FR, FR)); o.alpha_composite(fr, (0, dy)); return o


def quantizer(frames, palette_from=None, n=48, head_colors=0):
    """Paleta unica (n cores) da folha. head_colors > 0 (picks.json "head_colors"): reserva essa quantidade de cores
    para a cabeca (terco de cima de cada quadro) -> pele e cabelo nao herdam o tom da roupa (ex.: pescador, cuja pele
    e cabelo grisalho saiam esverdeados pela camisa verde)."""
    if head_colors and not palette_from:
        def strip_of(fs):
            st = Image.new('RGB', (FR * len(fs), FR), (0, 0, 0))
            for i, f in enumerate(fs): st.paste(f.convert('RGB'), (i * FR, 0), f)
            return st
        def cols(st, k):
            p = st.quantize(k, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[:3 * k]
            return [tuple(p[i:i + 3]) for i in range(0, len(p), 3)]
        px = []
        for f in frames:  # so os pixels opacos do terco de cima (cabeca)
            a = np.asarray(f); ys = np.nonzero(a[..., 3].any(1))[0]
            if not len(ys): continue
            h = a[:ys.min() + int((ys.max() - ys.min()) * 0.3)]; px.append(h[h[..., 3] > 0][:, :3])
        px = np.concatenate(px).astype(np.uint8)
        hp = cols(Image.fromarray(px[None, :, :], 'RGB'), head_colors)
        bp = cols(strip_of(frames), n - head_colors)
        allc = list(dict.fromkeys(bp + hp))[:n]
        pal = Image.new('P', (1, 1)); flat = [v for c in allc for v in c]; pal.putpalette(flat + [0] * (768 - len(flat)))
    elif palette_from:
        ref = Image.open(palette_from).convert('RGBA'); cols = {tuple(c[:3]) for c in np.asarray(ref).reshape(-1, 4) if c[3] > 0}
        pal = Image.new('P', (1, 1)); flat = [v for c in sorted(cols) for v in c]; pal.putpalette(flat + [0] * (768 - len(flat)))
    else:
        strip = Image.new('RGB', (FR * len(frames), FR), (0, 0, 0))
        for i, f in enumerate(frames): strip.paste(f.convert('RGB'), (i * FR, 0), f)
        pal = strip.quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    def q(f):
        r = f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA'); r.putalpha(f.getchannel('A')); return r
    return q


def build(npc, out=None, height=None, palette_from=None, only=None):
    wd = work(npc); P = json.load(open(os.path.join(wd, 'picks.json')))
    H = height or CFG[npc]['height']; out = out or os.path.join(GAME, 'assets', 'npcs', f'npc_{npc}')
    rb = lambda f: os.path.join(wd, 'rb_' + f.lstrip('!'))
    HAIR.clear()
    for hf in P.get('hair_fix', []):
        for f in hf['files']: HAIR['rb_' + f] = hf
    fx = lambda f, fl: fl != f.startswith('!')  # prefixo "!" = espelhar so este quadro
    ref_dir = P['dirs'].get('s') or next(iter(P['dirs'].values()))
    ref_img = P.get('scale_ref') or ref_dir['idle']
    k = -H  # cada quadro ajustado para a altura H (as edicoes mudam a escala da figura)
    sheets = {}
    if 'dirs' in P and only in (None, 'idle', 'walk'):
        ri, rw = [], []
        for d in DIRS:
            p = P['dirs'][d]; fl = p.get('flip', False)
            idle = place(scale(load(rb(p['idle']), fx(p['idle'], fl)), k))
            b = breathe(idle); ri.append([idle, idle, b, b])
            if p.get('wl') and p.get('wr'):
                wl = place(scale(load(rb(p['wl']), fx(p['wl'], fl)), k)); wr = place(scale(load(rb(p['wr']), fx(p['wr'], fl)), k))
                rw.append([wl, wl, bob(idle, -1), idle, wr, wr, bob(idle, -1), idle])
        sheets['idle'] = ri
        if len(rw) == 5: sheets['walk'] = rw
    if 'sit' in P and only in (None, 'sit'):
        sf = set(P.get('sit_flip', []))
        sheets['sit'] = [[place(scale(load(rb(P['sit'][d]), d in sf), -round(H * P.get('sit_scale', 0.72))))] for d in DIRS]
    allf = [f for rows in sheets.values() for r in rows for f in r]
    q = quantizer(allf, palette_from, head_colors=P.get('head_colors', 0))
    for name, rows in sheets.items():
        sh = Image.new('RGBA', (FR * len(rows[0]), FR * 5))
        for r, row in enumerate(rows):
            for c, f in enumerate(row): sh.alpha_composite(q(f), (c * FR, r * FR))
        sh.save(f'{out}_{name}.png'); print('saved', f'{out}_{name}.png')


if __name__ == '__main__':
    cmd, npc, *rest = sys.argv[1:]
    opts = {rest[i].lstrip('-'): rest[i + 1] for i in range(0, len(rest), 2)}
    if cmd == 'autopick': autopick(npc)
    else: build(npc, opts.get('out'), int(opts['height']) if 'height' in opts else None, opts.get('palette-from'), opts.get('only'))
