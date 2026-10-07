"""Base comum do pipeline de personalizacao (GDD §6.1, contrato ADENDO 2).

Fontes: as imagens-chave APROVADAS do Viajante (mesmas escolhas do build_sheets.py / picks.json, incluindo os
idles de frente "idle2" e as fontes do "sit"), na pasta de trabalho do Viajante:
    $TRAVELER_WORK/traveler_<body>/   (picks.json no formato do build_equipment.py: dirs + sit + sit_flip)
Trabalho desta ferramenta (edicoes da IA, remocao de fundo): $CUSTOM_WORK/<body>/<variante>/
As funcoes prep/params/render repetem EXATAMENTE a transformacao do build_sheets.py (alfa binario, recorte,
escala BOX para a altura, posicao pelo centro de massa horizontal), para que todas as camadas fiquem alinhadas
quadro a quadro com as folhas chr_traveler_* e com os itens do build_equipment.py.
"""
import colorsys, json, os
import numpy as np
from PIL import Image
from scipy.ndimage import label

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SCRATCH = '/tmp/claude-1000/-home-devalexandre-projects-devalexandre-game-mmo/aeb39986-09e1-412b-b11b-52cf06cc446f/scratchpad'
TRAVELER_WORK = os.environ.get('TRAVELER_WORK', os.path.join(SCRATCH, 'content', 'npc'))
CUSTOM_WORK = os.environ.get('CUSTOM_WORK', os.path.join(SCRATCH, 'custom', 'work'))
FR = 96; DIRS = ['s', 'se', 'e', 'ne', 'n']; H_IDLE = 84; H_WALK = 83; H_SIT = 62
BODY_KEY = {'male': 'm', 'female': 'f'}
# Codificacao das rampas (igual no shader): tom i (0 = mais escuro/contorno) -> valor i*STEP + STEP/2.
STEP = 40


def src_dir(body): return os.path.join(TRAVELER_WORK, f'traveler_{body}')
def work(body, variant): d = os.path.join(CUSTOM_WORK, body, variant); os.makedirs(d, exist_ok=True); return d


def frames(body):
    """[(anim, dir, tag, src, flip, H)] na ordem das folhas (igual ao build_equipment.frames)."""
    P = json.load(open(os.path.join(src_dir(body), 'picks.json'))); out = []
    for d in DIRS:
        p = P['dirs'][d]; fe = p.get('flip_each', {})
        out.append(('idle', d, 'idle', p['idle'], fe.get('idle', False), H_IDLE))
        for t in ('wl', 'wr'):
            out.append(('walk', d, t, p[t], fe.get(t, False), H_WALK))
    for d in DIRS:
        out.append(('sit', d, 'sit', P['sit'][d], d in P.get('sit_flip', []), H_SIT))
    return out


def prep(path, flip):
    a = np.asarray(Image.open(path).convert('RGBA')).copy()
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    lab, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lab.ravel()); keep = sz >= sz[1:].max() * 0.01; keep[0] = False; a[~keep[lab]] = 0
    if flip: a = a[:, ::-1].copy()
    return a


def params(a, H):
    ys, xs = np.nonzero(a[..., 3] > 0); B = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    bw, bh = B[2] - B[0], B[3] - B[1]; W = max(1, round(bw * H / bh))
    return dict(B=B, W=W, H=H)


def render(a, pr, m=0, cx=None):
    """Transformacao do build_sheets (BOX + posicao pelo centro de massa); m = margem extra (px finais) para
    o que passa do contorno da original (cabelo volumoso). Devolve (quadro 96x96 RGBA, cx)."""
    B, W, H = pr['B'], pr['W'], pr['H']; sx = W / (B[2] - B[0]); sy = H / (B[3] - B[1])
    P = int(m / min(sx, sy)) + 2 if m else 0
    im = Image.fromarray(np.pad(a, ((P, P), (P, P), (0, 0))) if P else a, 'RGBA')
    box = (B[0] + P - m / sx, B[1] + P - m / sy, B[2] + P + m / sx, B[3] + P + m / sy)
    r = im.resize((W + 2 * m, H + 2 * m), Image.BOX, box=box)
    if cx is None:
        cx = int(round(np.nonzero(np.asarray(r)[m:m + H, m:m + W, 3] > 0)[1].mean()))
    ox, oy = FR // 2 - cx - m, FR - H - m
    o = Image.new('RGBA', (FR, FR))
    o.paste(r.crop((max(0, -ox), max(0, -oy), r.width, r.height)), (max(0, ox), max(0, oy)))
    return o, cx


def shift(a, dx, dy):
    """Amostragem deslocada: o[y, x] = a[y + dy, x + dx] (fora = transparente)."""
    o = np.zeros_like(a); h, w = a.shape[:2]
    o[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)] = a[max(0, dy):h - max(0, -dy), max(0, dx):w - max(0, -dx)]
    return o


def hsv(rgb):
    """rgb uint8 (...,3) -> h (graus), s, v em 0..1."""
    f = rgb.astype(np.float32) / 255.0; r, g, b = f[..., 0], f[..., 1], f[..., 2]
    mx = f.max(-1); mn = f.min(-1); d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-6), 0); return h, s, mx


def is_green(rgb, relaxed=False):
    """Cabelo das edicoes da IA: pedimos cabelo VERDE VIVO (nada no Viajante e verde) para recortar por cor."""
    h, s, v = hsv(rgb)
    if relaxed: return (h > 62) & (h < 175) & (s > 0.22) & (v > 0.10)
    return (h > 70) & (h < 165) & (s > 0.35) & (v > 0.14)


def align_color(orig, ed, pr, frac=0.62, rng=48):
    """(dx, dy) que leva a editada para cima da original, pela CONCORDANCIA DE COR na parte de cima do corpo
    (cabeca + tronco; conta pixels parecidos, ignora o cabelo verde) -> o rosto/cabeca ficam alinhados, que e o
    que importa para cabelo, brincos e chapeus. Busca grossa em 1/4 da resolucao e refinamento em 1 px."""
    B = pr['B']; y1 = B[1] + int((B[3] - B[1]) * frac)
    def score(o, e, dx, dy, k):
        ys0, xs0 = (B[1] // k), (B[0] // k); ys1, xs1 = y1 // k, B[2] // k
        O = o[ys0:ys1, xs0:xs1]
        ey0, ex0 = ys0 + dy, xs0 + dx
        if ey0 < 0 or ex0 < 0 or ey0 + O.shape[0] > e.shape[0] or ex0 + O.shape[1] > e.shape[1]: return -1
        E = e[ey0:ey0 + O.shape[0], ex0:ex0 + O.shape[1]]
        ok = (O[..., 3] > 0) & (E[..., 3] > 0) & ~is_green(E[..., :3])
        d = np.abs(O[..., :3].astype(int) - E[..., :3].astype(int)).sum(-1)
        return int((ok & (d < 60)).sum())
    k = 4; o4 = orig[::k, ::k]; e4 = ed[::k, ::k]; best = (-2, 0, 0)
    for dy in range(-rng // k, rng // k + 1):
        for dx in range(-rng // k, rng // k + 1):
            s = score(o4, e4, dx, dy, k)
            if s > best[0]: best = (s, dx * k, dy * k)
    c = best
    for dy in range(c[2] - 4, c[2] + 5):
        for dx in range(c[1] - 4, c[1] + 5):
            s = score(orig, ed, dx, dy, 1)
            if s > best[0]: best = (s, dx, dy)
    return best[1], best[2]


def binarize(im, thr=128):
    a = np.asarray(im).copy(); a[..., 3] = np.where(a[..., 3] >= thr, 255, 0); a[a[..., 3] == 0] = 0
    return Image.fromarray(a, 'RGBA')


def breathe(fr, ref=None):
    """Respiracao do build_sheets: parte de cima (55% do corpo) desce 1 px. ref = quadro do corpo (limites)."""
    a = np.asarray(fr).copy(); rb = np.asarray(ref if ref is not None else fr)[..., 3] > 0
    ys = np.nonzero(rb.any(1))[0]
    if not len(ys): return fr
    top, bot = ys.min(), ys.max(); cut = top + int((bot - top) * 0.55)
    own = np.nonzero(a[..., 3].any(1))[0]; lo = min(top, own.min()) if len(own) else top
    up = a[lo:cut].copy(); a[lo:cut] = 0; a[lo + 1:cut + 1] = np.where(up[..., 3:] > 0, up, a[lo + 1:cut + 1])
    return Image.fromarray(a, 'RGBA')


def bob(fr, dy):
    o = Image.new('RGBA', (FR, FR)); o.alpha_composite(fr, (0, dy)); return o


def translate(fr, dx, dy):
    """Move o conteudo do quadro (dx, dy) pixels."""
    a = np.asarray(fr); return Image.fromarray(shift(a, -dx, -dy), 'RGBA')


def assemble(per, anims=('idle', 'walk', 'sit'), ref=None):
    """per[(anim, dir, tag)] -> quadro. Mesma montagem do build_sheets:
    idle = [i, i, b, b] (b = respiracao); walk = [wl, wl, bob(i,-1), i, wr, wr, bob(i,-1), i]; sit = [s]."""
    ref = ref or per; sheets = {a: [] for a in anims}
    for d in DIRS:
        i = per[('idle', d, 'idle')]; b = breathe(i, ref[('idle', d, 'idle')])
        if 'idle' in sheets: sheets['idle'].append([i, i, b, b])
        if 'walk' in sheets:
            wl = per[('walk', d, 'wl')]; wr = per[('walk', d, 'wr')]
            sheets['walk'].append([wl, wl, bob(i, -1), i, wr, wr, bob(i, -1), i])
        if 'sit' in sheets: sheets['sit'].append([per[('sit', d, 'sit')]])
    return sheets


def sheet_image(rows):
    sh = Image.new('RGBA', (FR * len(rows[0]), FR * 5))
    for r, row in enumerate(rows):
        for c, f in enumerate(row): sh.alpha_composite(f, (c * FR, r * FR))
    return sh


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def save_png(im, path):
    """Salva a PNG e um .import SEM compressao/mipmaps/fix_alpha_border (as mascaras e rampas precisam dos
    valores exatos dos pixels). Mantem o .import existente (uid) se ja houver."""
    import hashlib
    os.makedirs(os.path.dirname(path), exist_ok=True); im.save(path)
    imp = path + '.import'
    if not os.path.exists(imp):
        res = 'res://' + os.path.relpath(path, GAME).replace(os.sep, '/')
        md5 = hashlib.md5(res.encode()).hexdigest()
        open(imp, 'w').write(IMPORT_TMPL.format(name=os.path.basename(path), md5=md5, res=res))
