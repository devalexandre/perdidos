"""Monta as folhas de combate do Viajante em TODAS as camadas do paper doll (GDD §17.3/§17.4, contrato
ADENDO 1-2), a partir das poses-chave de keys.py. Sem IA, deterministico.

    python build_combat.py [body ...]            -> assets/ (folhas + mascaras) e pranchas em $COMBAT_WORK/preview/

Animacoes (quadros 96x96, linhas S/SE/L/NE/N, 6 colunas):
  attack_unarmed  soco + chute          attack_blade  facao/espada curta     attack_staff  cajado/varinha (faisca)
  cast            maos a frente         death         desaba de joelhos (fica no ultimo quadro)
Camadas por animacao:
  corpo-base      assets/characters/base/chr_<body>_base_<anim>.png (+ _mask_: R pele, G olhos, B raspado)
  Viajante        assets/characters/chr_traveler_<body>_<anim>.png  (corpo-base + cabelo padrao colorido)
  roupa           assets/characters/outfits/chr_<body>_leather_jerkin_<anim>.png (edicao IA da pose + cabelo)
  cabelo          assets/characters/hair/<style>/<body>_<anim>.png  } quadro do idle da propria camada, deslocado
  brincos         assets/characters/face/<id>/<body>_<anim>.png     } pela ANCORA DA CABECA (raspado verde do
  chapeus         assets/equipment/head/<id>/<body>_<anim>.png      } idle x raspado verde da pose)
  armas           assets/equipment/weapon/{blade,staff}/<body>_attack_{blade,staff}[_back].png (so na propria
                  animacao; pixels magenta da pose -> paleta da arma aprovada; ponta do cajado com cristal e faisca)
Escala da pose = escala do idle aprovado corrigida pela largura da cabeca (raspado verde); posicao = pes no chao
com o centro dos pes onde estao os do idle aprovado.
"""
import json, os, pickle, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label, binary_dilation

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'customization'))
from common import (DIRS, FR, GAME, H_IDLE, TRAVELER_WORK, CUSTOM_WORK, STEP, prep, params, hsv, is_green,
                    shift, save_png, sheet_image, translate)  # noqa: E402
import build as cb  # noqa: E402  (customization/build.py: hair_mask, skin_mask, eye_mask, lum, kmeans1d...)
from edits import STYLES, DEFAULT_STYLE  # noqa: E402
from keys import COMBAT_WORK, BODIES, KEYS, picks, src_flip, wdir  # noqa: E402

N8 = np.ones((3, 3), bool)
SEQ = {
    'attack_unarmed': ['u_wind', 'u_punch', 'u_punch', 'u_kick', 'u_kick', 'u_wind'],
    'attack_blade': ['b_wind', 'b_wind', 'b_slash', 'b_slash', 'b_follow', 'b_follow'],
    'attack_staff': ['s_wind', 's_wind', 's_thrust', 's_thrust', 's_thrust', 's_wind'],
    'cast': ['c_gather', 'c_gather', 'c_release', 'c_release', 'c_release', 'c_gather'],
    'death': ['d_stagger', 'd_stagger', 'd_kneel', 'd_kneel', 'd_slump', 'd_slump'],
}
# Poses-chave recusadas depois de 2+ tentativas (cabeca girada demais para o cabelo/chapeu seguirem a ancora):
# usa outra pose da mesma animacao. (body, dir, key) -> key substituta.
KEY_SUBST = {('male', 'ne', 'd_slump'): 'd_kneel'}
WEAPON_OF = {'attack_blade': 'blade', 'attack_staff': 'staff'}
BACK_ROWS = ['ne', 'n']
# Faisca na ponta do cajado: quadro -> raio (0 = sem).
SPARK = {'attack_staff': [0, 0, 3, 4, 2, 0]}
FACES = ['hoop', 'seed', 'feather']
HEADS = ['straw_hat', 'ipe_flower_crown']
OUTFITS = ['leather_jerkin']
# Paletas das armas (tiradas das camadas aprovadas do idle): escuro -> claro.
STEEL = [(19, 17, 25), (73, 70, 83), (127, 125, 138), (172, 175, 180), (208, 214, 218)]
HANDLE = [(19, 17, 25), (74, 41, 48), (113, 42, 39), (165, 102, 93), (165, 102, 93)]
WOOD = [(17, 10, 14), (75, 25, 24), (153, 66, 38), (185, 95, 50), (214, 137, 73)]
CRYSTAL = [(16, 29, 42), (59, 172, 200), (87, 229, 242)]
SPARK_COL = [(255, 255, 255), (250, 240, 170), (150, 235, 250)]
A = lambda p: os.path.join(GAME, 'assets', p)


def is_magenta(rgb, op):
    """Arma pedida magenta: nucleo vivo (pecas grandes) + contorno/sombra arroxeada colada nele."""
    h, s, v = hsv(rgb)
    core = op & (h > 280) & (h < 335) & (s > 0.45) & (v > 0.45)
    lab, n = label(core, N8)
    if n:
        sz = np.bincount(lab.ravel()); keep = sz >= 300; keep[0] = False; core = keep[lab]
    if not core.any(): return core
    ring = op & binary_dilation(core, N8, iterations=3) & (((h > 260) & (h < 350) & (s > 0.2)) | (v < 0.25))
    return core | ring


def green_width(a):
    g = is_green(a[..., :3]) & (a[..., 3] > 0)
    lab, n = label(g, N8)
    if not n: return None
    sz = np.bincount(lab.ravel()); sz[0] = 0; xs = np.nonzero(lab == sz.argmax())[1]
    return xs.max() - xs.min() + 1


def feet_cx(fr_a, rows=6):
    op = fr_a[..., 3] > 0; ys = np.nonzero(op.any(1))[0]; b = ys.max()
    return np.nonzero(op[b - rows + 1:b + 1])[1].mean()


def binar(a, thr=128):
    a = a.copy(); a[..., 3] = np.where(a[..., 3] >= thr, 255, 0); a[a[..., 3] == 0] = 0; return a


def blue_group(a):
    c = a[..., :3].astype(np.int32); return (a[..., 3] > 0) & (c[..., 2] > c[..., 0] + 30) & (c[..., 2] >= c[..., 1])


def blue_mean(a):
    return a[blue_group(a)][:, :3].astype(np.float32).mean(0)


class Dir:
    """Referencias de uma linha (body, d): escala do idle aprovado, largura da cabeca, pes, raspado do idle."""
    def __init__(self, body, d, idle_base, idle_scalp):
        self.body, self.d = body, d
        src, fl, self.mirror = src_flip(body, d)
        p = picks(body)[d]; ofl = p.get('flip_each', {}).get('idle', False)
        o = prep(os.path.join(TRAVELER_WORK, f'traveler_{body}', 'rb_' + src), ofl)
        pr = params(o, H_IDLE); self.s0 = H_IDLE / (pr['B'][3] - pr['B'][1])
        self.w0 = green_width(prep(os.path.join(wdir(body, d), 'rb__src.png'), False))
        ib = idle_base if not self.mirror else idle_base[:, ::-1]
        self.idle = ib; self.fx0 = feet_cx(ib)
        self.scalp0 = idle_scalp if not self.mirror else idle_scalp[:, ::-1]
        self.blue0 = blue_mean(o)

    def color_fix(self, a):
        """A IA satura o azul (moletom/calca): leva a media do grupo azul da pose para a da imagem aprovada."""
        m = blue_group(a)
        if m.sum() < 100: return a
        d = self.blue0 - a[m][:, :3].astype(np.float32).mean(0)
        a = a.copy(); a[m, :3] = np.clip(a[m, :3].astype(np.float32) + d, 0, 255).astype(np.uint8); return a

    def mirror_fr(self, a):
        return a[:, ::-1].copy() if self.mirror else a

    def render(self, a, s=None, ref=None):
        """a = imagem 1024 (alfa binario). Devolve (quadro 96x96 RGBA, parametros) com a escala s (ou a
        medida pela cabeca) e a posicao (pes). ref = parametros de outra imagem (mesma transformacao)."""
        if ref is None:
            w = green_width(a); r = (self.w0 / w) if w else 1.0
            r = float(np.clip(r, 0.8, 1.15)); s = self.s0 * r
        else:
            s = ref['s']
        W = max(1, round(a.shape[1] * s)); H = max(1, round(a.shape[0] * s))
        im = np.asarray(Image.fromarray(a, 'RGBA').resize((W, H), Image.BOX))
        im = binar(im)
        if ref is None:
            ys, xs = np.nonzero(im[..., 3] > 0); bot = ys.max()
            fx = np.nonzero(im[bot - 5:bot + 1, :, 3] > 0)[1].mean()
            ox = int(round(self.fx0 - fx)); oy = FR - 1 - bot
            ref = dict(s=s, ox=ox, oy=oy)
        out = np.zeros((FR, FR, 4), np.uint8); ox, oy = ref['ox'], ref['oy']
        y0, x0 = max(0, oy), max(0, ox); y1, x1 = min(FR, oy + im.shape[0]), min(FR, ox + im.shape[1])
        if y1 > y0 and x1 > x0: out[y0:y1, x0:x1] = im[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
        return out, ref

    def head_offset(self, scalp):
        """(dx, dy) que leva o raspado do idle para cima do raspado da pose (maior sobreposicao)."""
        A0 = self.scalp0; best = (-1e9, 0, 0)
        if not scalp.any() or not A0.any(): return 0, 0
        cy0, cx0 = [v.mean() for v in np.nonzero(A0)]; cy1, cx1 = [v.mean() for v in np.nonzero(scalp)]
        bx, by = int(round(cx1 - cx0)), int(round(cy1 - cy0))
        for dy in range(by - 6, by + 7):
            for dx in range(bx - 6, bx + 7):
                m = shift(A0[..., None].astype(np.uint8), -dx, -dy)[..., 0] > 0
                sc = (m & scalp).sum() * 2 - m.sum() - scalp.sum()
                if sc > best[0]: best = (sc, dx, dy)
        return best[1], best[2]

    def head_iou(self, scalp, off):
        m = shift(self.scalp0[..., None].astype(np.uint8), -off[0], -off[1])[..., 0] > 0
        u = (m | scalp).sum(); return float((m & scalp).sum() / u) if u else 0.0


def align_alpha(a, e, rng=40, step=4):
    """(dx, dy) que leva a editada e para cima de a (sobreposicao do alfa, busca grossa + fina)."""
    A0 = a[::step, ::step, 3] > 0; E = e[::step, ::step, 3] > 0; best = (-1e9, 0, 0)
    for dy in range(-rng // step, rng // step + 1):
        for dx in range(-rng // step, rng // step + 1):
            m = shift(E[..., None].astype(np.uint8), dx, dy)[..., 0] > 0
            sc = (m & A0).sum() * 2 - m.sum() - A0.sum()
            if sc > best[0]: best = (sc, dx * step, dy * step)
    c = best
    for dy in range(c[2] - step, c[2] + step + 1):
        for dx in range(c[1] - step, c[1] + step + 1):
            m = shift((e[..., 3:] > 0).astype(np.uint8), dx, dy)[..., 0] > 0
            sc = (m & (a[..., 3] > 0)).sum() * 2 - m.sum() - (a[..., 3] > 0).sum()
            if sc > best[0]: best = (sc, dx, dy)
    return best[1], best[2]


def split_weapon(a):
    """imagem 1024 -> (corpo sem a arma, so a arma)."""
    m = is_magenta(a[..., :3], a[..., 3] > 0)
    body = a.copy(); body[m] = 0; wpn = np.zeros_like(a); wpn[m] = a[m]
    return body, wpn, m.any()


# Para onde o personagem olha em cada linha (x, y da imagem): ponta do cajado = extremo mais "a frente".
FACING = {'s': (0.0, 1.0), 'se': (1.0, 0.5), 'e': (1.0, 0.0), 'ne': (1.0, -0.5), 'n': (0.0, -1.0)}


def ends(mask, body_op, facing=None):
    """Extremos do item pelo eixo principal: (ponta, cabo). Cabo = extremo com mais corpo em volta (mao);
    com facing, a ponta e o extremo mais a frente."""
    ys, xs = np.nonzero(mask); P = np.c_[xs, ys].astype(float); c = P.mean(0)
    u, s_, vt = np.linalg.svd(P - c, full_matrices=False); ax = vt[0]; t = (P - c) @ ax
    e1, e2 = P[t.argmin()], P[t.argmax()]
    def around(e):
        x, y = int(e[0]), int(e[1]); return body_op[max(0, y - 3):y + 4, max(0, x - 3):x + 4].sum()
    if facing is not None:
        f = np.array(facing); tip, hilt = (e1, e2) if (e1 - e2) @ f > 0 else (e2, e1)
    else:
        tip, hilt = (e1, e2) if around(e1) < around(e2) else (e2, e1)
    return tip, hilt, t, (P, c, ax)


def recolor_weapon(w, kind, body_op, centers, spark=0, d='s'):
    """quadro magenta 96x96 -> arma com a paleta aprovada (+ cristal e faisca no cajado)."""
    op = w[..., 3] > 0; out = np.zeros_like(w)
    if not op.any(): return out
    t = cb.tones_of(cb.lum(w[..., :3]), centers)
    tip, hilt, proj, (P, c, ax) = ends(op, body_op, FACING[d] if kind == 'staff' else None)
    ys, xs = np.nonzero(op)
    ramp = np.array(STEEL if kind == 'blade' else WOOD)
    out[op, :3] = ramp[t[op]]; out[op, 3] = 255
    if kind == 'blade':
        # cabo: o terco do lado da mao
        d_h = np.hypot(xs - hilt[0], ys - hilt[1]); L = np.hypot(*(tip - hilt)) + 1e-6
        hm = d_h < L * 0.3
        out[ys[hm], xs[hm], :3] = np.array(HANDLE)[t[ys[hm], xs[hm]]]
    else:
        # cristal azul na ponta (losango 3x3 com contorno)
        tx, ty = int(round(tip[0])), int(round(tip[1]))
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if abs(dx) + abs(dy) > 2: continue
                y, x = ty + dy, tx + dx
                if 0 <= y < FR and 0 <= x < FR:
                    col = CRYSTAL[0] if abs(dx) + abs(dy) == 2 else (CRYSTAL[2] if (dx, dy) in ((0, 0), (-1, -1), (0, -1)) else CRYSTAL[1])
                    out[y, x] = (*col, 255)
        if spark:
            v = tip - hilt; v = v / (np.linalg.norm(v) + 1e-6)
            sx, sy = int(round(tip[0] + v[0] * (spark + 2))), int(round(tip[1] + v[1] * (spark + 2)))
            pts = [(0, 0, 0)]
            for r in range(1, spark + 1):
                col = 1 if r < spark else 2
                pts += [(r, 0, col), (-r, 0, col), (0, r, col), (0, -r, col)]
            if spark >= 2: pts += [(1, 1, 2), (-1, -1, 2), (1, -1, 2), (-1, 1, 2)]
            for dx, dy, ci in pts:
                y, x = sy + dy, sx + dx
                if 0 <= y < FR and 0 <= x < FR: out[y, x] = (*SPARK_COL[ci], 255)
    return out


def load_sheet_frame(path, d, col=0):
    im = np.asarray(Image.open(path).convert('RGBA')); r = DIRS.index(d)
    return im[r * FR:(r + 1) * FR, col * FR:(col + 1) * FR].copy()


def palette_of(paths, exclude_masks=()):
    cols = set()
    for i, p in enumerate(paths):
        a = np.asarray(Image.open(p).convert('RGBA')); op = a[..., 3] > 0
        if i < len(exclude_masks) and exclude_masks[i] is not None:
            op &= ~np.asarray(Image.open(exclude_masks[i]))[..., :3].any(-1)
        cols |= {tuple(c) for c in a[op][:, :3]}
    return np.array(sorted(cols), dtype=np.int32)


def quantize_to(a, pal, keep=None):
    """Cada pixel opaco -> cor mais proxima da paleta (keep = pixels que ficam exatos)."""
    op = a[..., 3] > 0
    if keep is not None: op = op & ~keep
    px = a[op][:, :3].astype(np.int32)
    if len(px):
        d = ((px[:, None, :] - pal[None]) ** 2).sum(-1); a = a.copy(); a[op, :3] = pal[d.argmin(1)]
    return a


def ramp_colorize(g, ramp):
    """rampa de cinza (tom i -> i*40+20) -> cores."""
    out = g.copy(); op = g[..., 3] > 0; t = np.clip((g[..., 0].astype(int) - STEP // 2) // STEP, 0, len(ramp) - 1)
    out[op, :3] = np.array(ramp)[t[op]]; return out


def over(dst, src):
    m = src[..., 3] > 0; o = dst.copy(); o[m] = src[m]; return o


def build(body):
    print('==', body)
    meas = json.load(open(os.path.join(CUSTOM_WORK, body, 'measured.json')))
    Bpk, scalp_pk, _ = pickle.load(open(os.path.join(CUSTOM_WORK, body, '_base.pkl'), 'rb'))
    base_idle_path = A(f'characters/base/chr_{body}_base_idle.png')
    pal_base = palette_of([base_idle_path, A(f'characters/base/chr_{body}_base_walk.png')],
                          [A(f'characters/base/chr_{body}_base_mask_idle.png'), A(f'characters/base/chr_{body}_base_mask_walk.png')])
    pal_trav = palette_of([A(f'characters/chr_traveler_{body}_idle.png'), A(f'characters/chr_traveler_{body}_walk.png')])
    pal_jer = palette_of([A(f'characters/outfits/chr_{body}_leather_jerkin_idle.png'), A(f'characters/outfits/chr_{body}_leather_jerkin_walk.png')])
    sk_c = cb.lum(np.array(meas['skin'], np.float32)); styles = [s for s in STYLES[body] if s != 'buzz']
    D = {d: Dir(body, d, load_sheet_frame(base_idle_path, d), scalp_pk[('idle', d, 'idle')]) for d in DIRS}
    # 1) poses-chave -> quadros (corpo, arma magenta, roupa)
    F = {}
    for d in DIRS:
        R = D[d]
        for k in KEYS:
            p = os.path.join(wdir(body, d), 'rb_' + k + '.png')
            if not os.path.exists(p): print('  FALTA', d, k); continue
            a = R.color_fix(prep(p, False)); bod, wpn, has_w = split_weapon(a)
            fb, ref = R.render(bod); fw, _ = R.render(wpn, ref=ref) if has_w else (np.zeros_like(fb), None)
            fb[fw[..., 3] > 0] = 0
            jer = None; jp = os.path.join(wdir(body, d), 'jerkin', 'rb_' + k + '.png')
            if os.path.exists(jp):
                j = R.color_fix(prep(jp, False)); dx, dy = align_alpha(a, j); j = shift(j, dx, dy)
                jb, _, _ = split_weapon(j); jer, _ = R.render(jb, ref=ref); jer[fw[..., 3] > 0] = 0
            scalp = cb.hair_mask(Image.fromarray(fb), 0.5) & (fb[..., 3] > 0)
            top, bot = cb.body_bounds(fb); scalp[top + int((bot - top) * 0.6):] = False
            off = R.head_offset(scalp); iou = R.head_iou(scalp, off)
            F[(d, k)] = dict(body=fb, wpn=fw, jer=jer, scalp=scalp, off=off, s=ref['s'] / R.s0, iou=iou)
            print('  ', d, k, 'escala %.3f' % F[(d, k)]['s'], 'cabeca', off, 'encaixe %.2f' % iou,
                  'arma' if has_w else '', 'roupa' if jer is not None else '', '<< CABECA DIFERENTE' if iou < 0.6 else '')
    # 2) tons do raspado (verde) e da arma
    gv = np.concatenate([cb.lum(f['body'][..., :3])[f['scalp']] for f in F.values()])
    sc_c = cb.kmeans1d(gv, 5)
    wc = {}
    for kind, pre in (('blade', 'b_'), ('staff', 's_')):
        vals = [cb.lum(f['wpn'][..., :3])[f['wpn'][..., 3] > 0] for (d, k), f in F.items() if k.startswith(pre)]
        vals = np.concatenate(vals) if vals else np.array([0, 255.])
        wc[kind] = cb.kmeans1d(vals, 5)
    # 3) camadas por quadro
    out = {}  # layer path -> {anim: [[frames per col] per row]}
    def put(path, anim, r, fr):
        out.setdefault(path, {}).setdefault(anim, [[None] * 6 for _ in DIRS])[r][c] = fr
    hair_def = {d: ramp_colorize(D[d].mirror_fr(load_sheet_frame(A(f'characters/hair/{DEFAULT_STYLE[body]}/{body}_idle.png'), d)), meas['hair']) for d in DIRS}
    layer_idle = {}
    for s in styles: layer_idle[('hair', s)] = f'characters/hair/{s}/{body}'
    for f in FACES: layer_idle[('face', f)] = f'characters/face/{f}/{body}'
    for h in HEADS: layer_idle[('head', h)] = f'equipment/head/{h}/{body}'
    cache = {}
    anchors = {}
    for anim, seq in SEQ.items():
        for r, d in enumerate(DIRS):
            R = D[d]
            for c, k in enumerate(seq):
                k = KEY_SUBST.get((body, d, k), k)
                f = F.get((d, k))
                if f is None: continue
                cache_key = (d, k)
                if cache_key not in cache:
                    fb = f['body'].copy(); op = fb[..., 3] > 0
                    skin = cb.skin_mask(fb); scalp = f['scalp']; skin &= ~scalp
                    em, et = cb.eye_mask(fb, skin, scalp)
                    ts = cb.tones_of(cb.lum(fb[..., :3]), sk_c); tz = cb.tones_of(cb.lum(fb[..., :3]), sc_c)
                    m = np.zeros_like(fb); m[..., 3] = np.where(op, 255, 0)
                    e2 = em & ~skin; z2 = scalp & ~skin & ~em
                    m[..., 0] = np.where(skin, cb.enc(ts), 0); m[..., 1] = np.where(e2, cb.enc(et), 0); m[..., 2] = np.where(z2, cb.enc(tz), 0)
                    m[~op] = 0
                    rec = skin | e2 | z2
                    q = quantize_to(fb, pal_base, keep=rec)
                    q[skin, :3] = np.array(meas['skin'])[ts[skin]]; q[e2, :3] = np.array(meas['eye'])[et[e2]]
                    q[z2, :3] = np.array(meas['hair'])[tz[z2]]
                    dx, dy = f['off']
                    hair = translate(Image.fromarray(hair_def[d]), dx, dy); hair = np.asarray(hair)
                    trav = quantize_to(over(q, hair), pal_trav)  # cores da folha aprovada do Viajante (<= 48)
                    jer = None
                    if f['jer'] is not None:
                        j = f['jer'].copy(); jsc = cb.hair_mask(Image.fromarray(j), 0.5) & (j[..., 3] > 0)
                        jt, jb_ = cb.body_bounds(j); jsc[jt + int((jb_ - jt) * 0.6):] = False
                        jz = cb.tones_of(cb.lum(j[..., :3]), sc_c)
                        j = quantize_to(j, pal_jer, keep=jsc); j[jsc, :3] = np.array(meas['hair'])[jz[jsc]]
                        jdx, jdy = R.head_offset(jsc) if jsc.sum() > 10 else (dx, dy)
                        jer = quantize_to(over(j, np.asarray(translate(Image.fromarray(hair_def[d]), jdx, jdy))), pal_jer)
                    cache[cache_key] = (q, m, trav, jer)
                q, m, trav, jer = cache[cache_key]
                dx, dy = f['off']
                anchors.setdefault(anim, [[None] * 6 for _ in DIRS])[r][c] = {
                    'dx': int(dx), 'dy': int(dy), 'mirror_idle': bool(R.mirror), 'key': k, 'fit': round(f['iou'], 2)}
                put(A(f'characters/base/chr_{body}_base'), anim, r, q)
                put(A(f'characters/base/chr_{body}_base_mask'), anim, r, m)
                put(A(f'characters/chr_traveler_{body}'), anim, r, trav)
                if jer is not None: put(A(f'characters/outfits/chr_{body}_leather_jerkin'), anim, r, jer)
                for (kind, lid), rel in layer_idle.items():
                    src = R.mirror_fr(load_sheet_frame(A(rel + '_idle.png'), d))
                    put(A(rel), anim, r, np.asarray(translate(Image.fromarray(src), dx, dy)))
                if anim in WEAPON_OF:
                    kind = WEAPON_OF[anim]
                    wf = recolor_weapon(f['wpn'], kind, f['body'][..., 3] > 0, wc[kind], SPARK.get(anim, [0] * 6)[c], d)
                    back = d in BACK_ROWS
                    put(A(f'equipment/weapon/{kind}/{body}') + ('#back' if back else '#front'), anim, r, wf)
    # 4) salvar
    for path, anims in out.items():
        for anim, rows in anims.items():
            rows = [[np.ascontiguousarray(fr, dtype=np.uint8) if fr is not None else np.zeros((FR, FR, 4), np.uint8) for fr in row] for row in rows]
            for row in rows:
                for fr in row: assert fr.shape == (FR, FR, 4), (path, anim, fr.shape)
            im = sheet_image([[Image.fromarray(fr) for fr in row] for row in rows])
            if path.endswith('#back') or path.endswith('#front'):
                base, side = path.split('#')
                fn = f'{base}_{anim}' + ('_back' if side == 'back' else '') + '.png'
            elif os.path.basename(path).startswith('chr_'):
                fn = f'{path}_{anim}.png'
            else:
                fn = f'{path}_{anim}.png'
            save_png(im, fn)
    print('  salvo:', sum(len(v) for v in out.values()), 'folhas')
    ap = os.path.join(HERE, 'head_anchors.json')
    allA = json.load(open(ap)) if os.path.exists(ap) else {}
    allA['_doc'] = ("Ancora da cabeca por quadro das folhas de combate: o conteudo da cabeca do quadro idle (coluna 0 "
                    "da mesma linha em chr_<body>_base_idle.png; espelhado horizontalmente no quadro 96x96 quando "
                    "mirror_idle) deslocado (dx, dy) px cai sobre a cabeca deste quadro. [body][anim][linha S,SE,E,NE,N][coluna].")
    allA[body] = anchors
    json.dump(allA, open(ap, 'w'), indent=0)
    pickle.dump({k: {kk: vv for kk, vv in v.items() if kk != 'jer'} for k, v in F.items()}, open(os.path.join(COMBAT_WORK, body, '_frames.pkl'), 'wb'))


if __name__ == '__main__':
    for b in (sys.argv[1:] or BODIES): build(b)
