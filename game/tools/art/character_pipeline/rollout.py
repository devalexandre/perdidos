#!/usr/bin/env python3
"""Viajante com mais quadros, para todo o jogo (aprovado em 07/10/2026 a partir da rodada 2 do piloto).

Tecnica: deformacao por partes (skin 2D) dos quadros ATUAIS (fonte: as folhas originais de 4/6 quadros do commit
f328083, extraidas por fetch_rollout_sources.sh para .work/char-frames-pilot/backup_originals), vizinho mais proximo (sem cor nova; mascaras e codigos de rampa intactos), o MESMO plano de
deformacao aplicado a todas as camadas do quadro (corpo-base + mascara, olhos, olho fechado, cabelos, brincos,
chapeus, armas, roupas de titulo + mascara, composto chr_traveler_*). A geometria (cabeca, cintura, tronco, bracos)
sai do corpo-base de cada quadro; roupas usam a do corpo-base (e a camada de cabelo/olhos e a mesma).

  idle 12 (de 4), cast 16 (de 6), golpes 12 (de 6); walk 8 e death 6 mantem a contagem (so movimento secundario).
  walk do corpo-base e das roupas: depois do movimento secundario passa pelo walk8_legs (8 desenhos de perna).

Uso: fetch_rollout_sources.sh   (uma vez: extrai as originais do git)
     rollout.py <saida> [--phase body|equip|outfits|all] [--bodies male,female]
A saida espelha game/assets (characters/..., equipment/...). ROLLOUT_SRC troca a pasta das originais.
Versionado em 08/10/2026 (antes vivia so em .work/char-frames-pilot, fora do git).
"""
import math, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion, distance_transform_edt, label

# andar com 8 desenhos (aprovado em 08/10/2026): depois de gerar o walk de 4 poses do corpo-base e das roupas, o
# walk8_legs.py (versionado em game/tools/art/character_pipeline) troca as colunas repetidas por poses novas de perna.
# Assim o rollout nunca mais grava o andar de 4 poses.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import walk8_legs  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
# folhas originais (commit f328083), extraidas por fetch_rollout_sources.sh
SRC = os.environ.get('ROLLOUT_SRC', os.path.join(ROOT, '.work', 'char-frames-pilot', 'backup_originals'))
FR = 96
ROWS = 5
YY, XX = np.mgrid[0:FR, 0:FR].astype(float)

# rotulos do corpo e do cabelo; Z = ordem de desenho
L_LEGS, L_HEM, L_CHEST, L_ARM_L, L_ARM_R, L_HANDS, L_HEAD, L_HEMX = 0, 1, 2, 3, 4, 5, 6, 7
H_MAIN, H_TOP, H_SIDE = 10, 11, 12
ZB = {L_LEGS: 0, L_HEMX: 1, L_HEM: 1, L_CHEST: 2, L_ARM_L: 3, L_ARM_R: 3, L_HANDS: 4, L_HEAD: 5,
      H_MAIN: 6, H_TOP: 7, H_SIDE: 6}
GLOW = [(252, 250, 245), (250, 229, 140), (230, 180, 58), (217, 85, 58)]   # paleta mestra
SMEAR = (199, 195, 204); SMEAR_EDGE = (252, 250, 245)                       # paleta mestra
NEW_N = {'idle': 12, 'cast': 16, 'attack_unarmed': 12, 'attack_blade': 12, 'attack_staff': 12, 'attack_bow': 12}
SEC = ['walk', 'death']
ANIMS = list(NEW_N) + SEC
DEFAULT_HAIR = {'male': 'spiky', 'female': 'ponytail'}
# Roupas de equipamento que ja tem folhas proprias de 8+ quadros (feitas fora do rollout): nunca regravar.
OWN_FRAMES_OUTFITS = {'apprentice', 'branch_coat', 'leather_jerkin', 'master_armor'}
WEAPON_OF = {'attack_blade': 'blade', 'attack_staff': 'staff', 'attack_bow': 'bow'}


# ------------------------------------------------------------------ utilitarios
_cache = {}


def load(rel):
    if rel not in _cache:
        p = os.path.join(SRC, rel)
        _cache[rel] = np.asarray(Image.open(p).convert('RGBA')).copy() if os.path.exists(p) else None
    return _cache[rel]


def fr(sheet, col, row):
    return sheet[row * FR:(row + 1) * FR, col * FR:(col + 1) * FR].copy()


def ncols(sheet):
    return sheet.shape[1] // FR


def ramp(v, a, b):
    if b == a:
        return (v >= b).astype(float) if isinstance(v, np.ndarray) else float(v >= b)
    return np.clip((v - a) / (b - a), 0.0, 1.0)


def Bp(p):
    return 0.5 - 0.5 * math.cos(2 * math.pi * p)


def Sp(p):
    return math.sin(2 * math.pi * p)


# ------------------------------------------------------------------ geometria (do corpo-base)
class Geo:
    def __init__(self, body, anim, row, col):
        base = fr(load(f'characters/base/chr_{body}_base_{anim}.png'), col, row)
        mask = fr(load(f'characters/base/chr_{body}_base_mask_{anim}.png'), col, row)
        eyes_s = load(f'characters/eyes/{body}_{anim}.png')
        self.alpha = base[..., 3] > 0
        hb = (mask[..., 3] == 255) & (mask[..., 2] > 0) & (mask[..., 0] == 0) & (mask[..., 1] == 0)
        ys, xs = np.nonzero(hb)
        if len(ys) < 6:
            ys, xs = np.nonzero(self.alpha)
            ys, xs = ys[ys < ys.min() + 10], xs[ys < ys.min() + 10]
        self.btop = int(ys.min()); self.bx0, self.bx1 = int(xs.min()), int(xs.max())
        self.bcx = float(xs.mean())
        self.chin = self.btop + HEAD_H[body]
        self.waist = self.chin + int(round(0.47 * (95 - self.chin)))
        ly = min(self.waist + 5, 90)
        lx = np.nonzero(self.alpha[ly])[0]
        if len(lx) == 0:
            lx = np.array([self.bx0, self.bx1])
        self.tx0, self.tx1 = int(lx.min()) - 2, int(lx.max()) + 2
        self.cx = (self.tx0 + self.tx1) / 2.0
        self.eyes = None
        if eyes_s is not None:
            e = fr(eyes_s, col, row)[..., 3] > 0
            if e.any():
                ey, ex = np.nonzero(e); self.eyes = (int(ex.min()), int(ey.min()), int(ex.max()), int(ey.max()))
        self.hx0, self.hx1 = self.bx0 - 4, self.bx1 + 4
        self.row = row
        r = self.chin + 12
        xs2 = np.nonzero(self.alpha[min(r, 95)])[0]
        self.front_x = int(xs2.max()) if len(xs2) else int(self.cx)

    def eye_weight(self):
        """1 longe dos olhos, 0 sobre/encostado: a franja perto do olho acompanha a cabeca (rosto nao muda)."""
        if self.eyes is None:
            return np.ones((FR, FR))
        x0, y0, x1, y1 = self.eyes
        dx = np.maximum(np.maximum(x0 - XX, XX - x1), 0); dy = np.maximum(np.maximum(y0 - YY, YY - y1), 0)
        d = np.maximum(dx, dy)
        return np.clip((d - 1) / 3.0, 0, 1)


HEAD_H = {}


def init_head_h(body):
    base = load(f'characters/base/chr_{body}_base_idle.png'); mask = load(f'characters/base/chr_{body}_base_mask_idle.png')
    e = fr(load(f'characters/eyes/{body}_idle.png'), 0, 0)[..., 3] > 0
    m = fr(mask, 0, 0)
    hb = (m[..., 3] == 255) & (m[..., 2] > 0) & (m[..., 0] == 0) & (m[..., 1] == 0)
    HEAD_H[body] = int(np.nonzero(e)[0].max() + 5 - np.nonzero(hb)[0].min())


def body_labels(g, pose):
    lab = np.full((FR, FR), L_CHEST)
    lab[YY >= g.waist] = L_LEGS
    lab[(YY >= g.waist - 8) & (YY < g.waist)] = L_HEM
    head = (YY <= g.chin) & (XX >= g.hx0) & (XX <= g.hx1)
    if pose == 'I':
        lab[(YY >= g.waist - 7) & (YY < g.waist + 14) & ((XX < g.tx0) | (XX > g.tx1))] = L_HANDS
    elif pose == 'A' and g.row == 0:
        lab[(YY >= g.chin + 4) & (YY <= g.waist - 3) & (np.abs(XX - g.cx) <= 9)] = L_HANDS
    elif pose == 'B':
        up = (YY < g.waist - 2) & ~head
        if g.row in (0, 4):
            lab[up & (XX < g.tx0 - 1)] = L_ARM_L
            lab[up & (XX > g.tx1 + 1)] = L_ARM_R
        else:
            lab[up & (XX > g.tx1 + 1)] = L_ARM_R
    lab[head] = L_HEAD
    return lab


def hair_labels(g):
    lab = np.full((FR, FR), H_MAIN)
    lab[YY < g.btop + 7] = H_TOP
    lab[YY >= g.chin - 5] = H_SIDE
    return lab


def body_hem_extra(lab, src_alpha, base_alpha, g):
    """Roupa longa (saia/capa/manto): o que passa da silhueta do corpo-base abaixo da cintura vira barra propria."""
    lab = lab.copy()
    lab[(YY >= g.waist - 4) & src_alpha & ~base_alpha] = L_HEMX
    return lab


# ------------------------------------------------------------------ transformacoes (mapeamento reverso)
def tr(dx=0.0, dy=0.0):
    return lambda X, Y: (X - dx, Y - dy)


def field(dxf, dyf):
    return lambda X, Y: (X - dxf(X, Y), Y - dyf(X, Y))


def rot(piv, phi_deg, scale=1.0, dx=0.0, dy=0.0):
    c, s = math.cos(math.radians(phi_deg)), math.sin(math.radians(phi_deg))

    def f(X, Y):
        x = (X - dx - piv[0]) / scale; y = (Y - dy - piv[1]) / scale
        return piv[0] + c * x + s * y, piv[1] - s * x + c * y
    return f


def rot_fwd(piv, phi_deg, scale, dx, dy, p):
    c, s = math.cos(math.radians(phi_deg)), math.sin(math.radians(phi_deg))
    x, y = p[0] - piv[0], p[1] - piv[1]
    return piv[0] + scale * (c * x - s * y) + dx, piv[1] + scale * (s * x + c * y) + dy


def comp(piv_x, k, dx=0.0, dy=0.0):
    """Braco para frente encurtado em torno do ombro (vista de lado: o in-between do empurrao)."""
    return lambda X, Y: (piv_x + (X - dx - piv_x) / k, Y - dy)


def warp(src, lab, fns, z=ZB):
    out = np.zeros_like(src); zbuf = np.full((FR, FR), -1)
    for L, f in fns.items():
        sx, sy = f(XX, YY)
        sx = np.asarray(sx, float) + 0 * XX; sy = np.asarray(sy, float) + 0 * YY
        bad = np.isnan(sx) | np.isnan(sy)
        sx = np.where(bad, -1, np.floor(np.nan_to_num(sx, nan=-1) + 0.5)).astype(int)
        sy = np.where(bad, -1, np.floor(np.nan_to_num(sy, nan=-1) + 0.5)).astype(int)
        ok = (sx >= 0) & (sx < FR) & (sy >= 0) & (sy < FR)
        sxc = np.clip(sx, 0, FR - 1); syc = np.clip(sy, 0, FR - 1)
        m = ok & (lab[syc, sxc] == L) & (src[syc, sxc, 3] > 0) & (z[L] > zbuf)
        out[m] = src[syc[m], sxc[m]]; zbuf[m] = z[L]
    return out


def fill_holes(outs, ref_alpha, key):
    a = outs[key][..., 3] > 0
    hole = ref_alpha & ~a
    if not hole.any():
        return
    fills = []
    for y, x in zip(*np.nonzero(hole)):
        up = any(a[y - k, x] for k in (1, 2) if y - k >= 0)
        dn = [k for k in (1, 2) if y + k < FR and a[y + k, x]]
        if up and dn:
            fills.append((y, x, y + dn[0], x)); continue
        lt = [k for k in (1, 2, 3) if x - k >= 0 and a[y, x - k]]
        rt = [k for k in (1, 2, 3) if x + k < FR and a[y, x + k]]
        if lt and rt:
            fills.append((y, x, y, x + rt[0] if x < 48 else x - lt[0]))
    for y, x, sy, sx in fills:
        for o in outs.values():
            o[y, x] = o[sy, sx]


def drop_specks(outs, key, max_px=4):
    lab, n = label(outs[key][..., 3] > 0, structure=np.ones((3, 3)))
    if n <= 1:
        return
    sz = np.bincount(lab.ravel()); small = sz <= max_px; small[0] = False
    m = small[lab]
    for o in outs.values():
        o[m] = 0


def outline_fix(outs, key, region, dark):
    base = outs[key]; a = base[..., 3] > 0
    n = np.zeros_like(a)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n |= ~np.roll(np.roll(a, dy, 0), dx, 1)
    fix = region & a & n & (base[..., :3].astype(int).sum(-1) > 180)
    for k, o in outs.items():
        if k == key:
            o[fix, :3] = dark
        elif o is not None and o.shape == base.shape and k.endswith('mask'):
            o[fix] = (0, 0, 0, 255)


def darkest(src):
    px = src[src[..., 3] > 0][:, :3].astype(int)
    return tuple(px[px.sum(-1).argmin()]) if len(px) else (22, 19, 28)


def glow(outs, key, mkey, cx, cy, r, rays=False, under=False):
    if r <= 0:
        return
    base = outs[key]; mask = outs.get(mkey)
    for y in range(cy - r - 2, cy + r + 3):
        for x in range(cx - r - 2, cx + r + 3):
            if not (0 <= x < FR and 0 <= y < FR):
                continue
            if under and base[y, x, 3] > 0:
                continue
            d = abs(x - cx) + abs(y - cy); dd = max(abs(x - cx), abs(y - cy)); e = (d + dd) / 2.0
            if e <= r * 0.35:
                c = GLOW[0]
            elif e <= r * 0.7:
                c = GLOW[1]
            elif e <= r:
                c = GLOW[2]
            elif rays and (x == cx or y == cy) and d <= r + 2:
                c = GLOW[1] if d <= r + 1 else GLOW[2]
            else:
                continue
            base[y, x] = c + (255,)
            if mask is not None:
                mask[y, x] = (0, 0, 0, 128)


def sparkle(outs, key, mkey, x, y):
    base = outs[key]; mask = outs.get(mkey)
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        if 0 <= x + dx < FR and 0 <= y + dy < FR:
            base[y + dy, x + dx] = (GLOW[0] if (dx, dy) == (0, 0) else GLOW[2]) + (255,)
            if mask is not None:
                mask[y + dy, x + dx] = (0, 0, 0, 128)


def smear(outs, key, mkey, ghost, region, min_dist=2, min_px=6):
    base = outs[key]; mask = outs.get(mkey)
    cur = base[..., 3] > 0
    dist = distance_transform_edt(~cur)
    g = ghost & region & ~cur & (dist >= min_dist)
    lab, n = label(g, structure=np.ones((3, 3)))
    if n == 0:
        return
    sz = np.bincount(lab.ravel()); keep = sz >= min_px; keep[0] = False
    g = keep[lab]
    chk = ((XX + YY).astype(int) % 2 == 0); near = dist <= 3
    for m, col in ((g & chk & ~near, SMEAR), (g & near, SMEAR_EDGE)):
        base[m] = col + (255,)
        if mask is not None:
            mask[m] = (0, 0, 0, 128)


# ------------------------------------------------------------------ roteiros (planos por quadro)
def hair_fns(g, head, ex):
    """ex: dict H_* -> (dxf, dyf) relativos a cabeca; peso 0 perto dos olhos."""
    w = g.eye_weight(); hx, hy = head
    out = {}
    for L in (H_MAIN, H_TOP, H_SIDE):
        dxf, dyf = ex.get(L, (lambda X, Y: 0 * X, lambda X, Y: 0 * X))
        out[L] = (lambda dxf, dyf: field(lambda X, Y: hx + w * dxf(X, Y), lambda X, Y: hy + w * dyf(X, Y)))(dxf, dyf)
    return out


def plan_idle(body, row, i, n=12):
    g = Geo(body, 'idle', row, 0)
    p = i / n
    br, br_sh, br_hd, br_hn, br_hr, br_tp = Bp(p), Bp(p - 0.06), Bp(p - 0.1), Bp(p - 0.17), Bp(p - 0.2), Bp(p - 0.28)
    sw_hn, sw_hem, sw_top, sw_side = Sp(p - 0.25), Sp(p - 0.3), Sp(p - 0.33), Sp(p - 0.42)
    head = (0, round(br_hd))
    hands = field(lambda X, Y: np.sign(X - g.cx) * 0.9 * sw_hn * ramp(Y, g.waist - 4, g.waist + 6),
                  lambda X, Y: 1.2 * br_hn + 0 * X)
    body_f = {L_LEGS: tr(), L_HEAD: tr(*head), L_HANDS: hands,
              L_CHEST: field(lambda X, Y: 0 * X, lambda X, Y: (br + 0.35 * br_sh) * (1 - ramp(Y, g.chin + 9, g.waist))),
              L_HEM: field(lambda X, Y: 0 * X, lambda X, Y: 0.6 * br * (1 - ramp(Y, g.waist - 6, g.waist))),
              L_HEMX: field(lambda X, Y: 1.2 * sw_hem * ramp(Y, g.waist, g.waist + 20),
                            lambda X, Y: 0.6 * br + 0 * X)}
    ex = {H_MAIN: (lambda X, Y: 0 * X, lambda X, Y: 1.2 * br_hr * ramp(Y, g.btop, g.btop + 16)),
          H_TOP: (lambda X, Y: 1.6 * sw_top * ramp(-Y, -(g.btop + 10), -g.btop),
                  lambda X, Y: 1.2 * br_hr + 0.9 * br_tp * ramp(-Y, -(g.btop + 8), -g.btop)),
          H_SIDE: (lambda X, Y: 1.4 * sw_side * ramp(Y, g.chin - 5, g.chin + 7) * np.sign(X - g.bcx) * ramp(np.abs(X - g.bcx), 8, 14),
                   lambda X, Y: 1.2 * br_hr + 0.8 * br_tp * ramp(Y, g.chin - 5, g.chin + 7))}
    return dict(src=('idle', 0), pose='I', g=g, body=body_f, head=head, hair=hair_fns(g, head, ex),
                weapon=hands, glow=[], spark=[], shut=None, rot=False, split=0, smear=None)


# cast: (pose, agacha, cabeca, cabelo, pontas, abertura, maos separadas (S), braco (theta, escala))
CAST = [('A', 1, 1, 0, 0, 0, 0, None), ('A', 1, 1, 1, 0, 0, 0, None), ('A', 1, 1, 1, 1, 0, 0, None),
        ('A', 0.5, 1, 1, 1, 0, 0, None), ('A', 0, 0.5, 0.5, 0.5, 0, 1, None), ('A', -0.5, 0, 0, 0, 1, 2, None),
        ('A', -1, 0, -0.5, -0.5, 1, 3, None), ('B', -1, -0.5, -0.5, -1, 1, 0, (62, 0.8)),
        ('B', -1, -1, -1, -1.5, 1.5, 0, (34, 0.9)), ('B', -1, -1, -1, -2, 2, 0, (12, 0.97)),
        ('B', -1, -1, -1.5, -2.5, 2, 0, (-5, 1.0)), ('B', -1, -1, -1, -2, 2, 0, (0, 1.0)),
        ('B', -0.5, -0.5, -0.5, -1, 1, 0, (0, 1.0)), ('B', 0, 0, 0, 0, 1, 0, (28, 0.95)),
        ('B', 0, 0, 0.5, 1, 0, 0, (58, 0.85)), ('I',)]
A_GLOW = {0: 1, 1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 4, 7: 2}
B_GLOW = {7: (2, False), 8: (3, False), 9: (4, True), 10: (4, True), 11: (3, True), 12: (2, False), 13: (1, False)}
SPARK = {10: 6, 11: 9}


def head_shift(body, row, anim_a, col_a):
    """Deslocamento que leva a cabeca do idle (col 0) a cabeca do quadro dado (alinha o cabelo raspado)."""
    def hb(anim, col):
        m = fr(load(f'characters/base/chr_{body}_base_mask_{anim}.png'), col, row)
        return (m[..., 3] == 255) & (m[..., 2] > 0) & (m[..., 0] == 0) & (m[..., 1] == 0)
    a, b = hb('idle', 0), hb(anim_a, col_a)
    best, bs = None, -1
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            s = (np.roll(np.roll(a, dy, 0), dx, 1) & b).sum()
            if s > bs:
                bs, best = s, (dx, dy)
    return best


def plan_cast(body, row, i):
    spec = CAST[i]
    if spec[0] == 'I':
        p = plan_idle(body, row, 0); p['src_override'] = True; return p
    pose, cr, hd, hr, tp, flare, split, arm = spec
    col = 0 if pose == 'A' else 2
    g = Geo(body, 'cast', row, col)
    head = (0, round(hd))
    body_f = {L_LEGS: tr(), L_HEAD: tr(*head),
              L_CHEST: field(lambda X, Y: 0 * X, lambda X, Y: cr * (1 - ramp(Y, g.chin + 12, g.waist + 4))),
              L_HEM: field(lambda X, Y: flare * np.sign(X - g.cx) * ramp(np.abs(X - g.cx), 3, 12) * ramp(Y, g.waist - 8, g.waist),
                           lambda X, Y: cr * 0.5 + 0 * X),
              L_HEMX: field(lambda X, Y: flare * 1.5 * np.sign(X - g.cx) * ramp(Y, g.waist, g.waist + 20),
                            lambda X, Y: cr * 0.5 + 0 * X)}
    glows, sparks = [], []
    under = row in (3, 4)
    if pose == 'A':
        def hands(X, Y, s=split, c=cr):
            sx = X + np.where(X < g.cx, s, -s)
            sx = np.where(np.abs(X - g.cx) < s, np.nan, sx)
            return sx, Y - c
        body_f[L_HANDS] = hands if row == 0 else tr(0, cr)
        if i in A_GLOW:
            r = A_GLOW[i]
            if row == 0:
                glows.append((int(round(g.cx)), g.chin + 13 - (1 if i >= 5 else 0), r, i >= 5, False))
            elif row in (1, 2):
                glows.append((g.front_x - 2, g.chin + 12, r, i >= 5, False))
            else:
                glows.append((g.front_x - 1 if row == 3 else int(round(g.cx)), g.chin + 12, r + 1, i >= 5, True))
    else:
        th, sc = arm
        if row in (0, 4):
            pl, pr = (g.tx0 + 2, g.chin + 6), (g.tx1 - 2, g.chin + 6)
            body_f[L_ARM_L] = rot(pl, -th, sc, 0, cr); body_f[L_ARM_R] = rot(pr, th, sc, 0, cr)
            arms = [(L_ARM_L, pl, -th), (L_ARM_R, pr, th)]
        else:
            k = 1.0 - 0.5 * max(0.0, th) / 62.0
            pr = (g.tx1 - 2, g.chin + 6)
            body_f[L_ARM_R] = comp(pr[0], k, 0, cr + 2 * max(0.0, th) / 62.0)
            arms = [(L_ARM_R, pr, None, k, cr + 2 * max(0.0, th) / 62.0)]
        if i in B_GLOW:
            r, rays = B_GLOW[i]
            lab = body_labels(g, 'B')
            for a in arms:
                L, piv = a[0], a[1]
                ys, xs = np.nonzero((lab == L) & g.alpha)
                if len(ys) < 5:
                    continue
                d = (xs - piv[0]) ** 2 + (ys - piv[1]) ** 2
                idx = np.argsort(d)[-10:]
                tip = (xs[idx].mean(), ys[idx].mean())
                if a[2] is not None:
                    tx, ty = rot_fwd(piv, a[2], sc, 0, cr, tip)
                else:
                    tx, ty = piv[0] + (tip[0] - piv[0]) * a[3], tip[1] + a[4]
                glows.append((int(round(tx)), int(round(ty)), r, rays, False))
        if i in SPARK:
            off = SPARK[i]
            for (x, y, *_r) in [gg for gg in glows]:
                sparks += [(x - off // 2, y - off), (x + off // 2, y - off - 2)]
    ex = {H_MAIN: (lambda X, Y: 0 * X, lambda X, Y: hr * 0.7 + 0 * X),
          H_TOP: (lambda X, Y: 0 * X, lambda X, Y: hr * 0.7 + tp * ramp(-Y, -(g.btop + 12), -g.btop)),
          H_SIDE: (lambda X, Y: 0 * X, lambda X, Y: hr * 0.7 + tp * 0.6 * ramp(Y, g.chin - 5, g.chin + 7))}
    shut = None
    if pose == 'A' and i <= 4 and row in (0, 1, 2):
        dx, dy = head_shift(body, row, 'cast', 0)
        shut = (dx, dy + head[1])
    weapon = field(lambda X, Y: 0 * X, lambda X, Y: cr * (1 - float(ramp(np.array(58.0), g.chin + 12, g.waist + 4))) + 0 * X)
    return dict(src=('cast', col), pose=pose, g=g, body=body_f, head=head, hair=hair_fns(g, head, ex), weapon=weapon,
                glow=glows, spark=sparks, shut=shut, rot=arm is not None, split=split if (pose == 'A' and row == 0) else 0,
                smear=None, cr=cr)


# golpes: (coluna antiga, agacha(+)/sobe(-), inclinacao em "unidades do golpe" (- = prepara, + = vai), rastro de)
ATTACKS = {
    'attack_unarmed': [(0, 0, 0, None), (0, 1, -1, None), (0, 1, -2, None), (1, 0, 0, 0), (1, 0, 1, None),
                       (1, 0, 1, None), (1, 0, 0, None), (3, 0, 0, 1), (3, -1, 0, None), (3, 0, 0, None),
                       (0, 1, 0, 3), (0, 0, 0, None)],
    'attack_blade': [(0, 0, 0, None), (0, -1, -1, None), (0, -1, -2, None), (2, 0, 0, 0), (2, 1, 1, None),
                     (2, 1, 1, None), (4, 1, 0, 2), (4, 0, 0, None), (4, 0, 0, None), (4, 0, 0, None),
                     (4, 1, 0, None), (4, 0, 0, None)],
    'attack_staff': [(0, 0, 0, None), (0, 1, -1, None), (0, 1, -2, None), (2, 0, 0, 0), (2, 0, 1, None),
                     (2, 0, 1, None), (2, 0, 0, None), (2, 0, 0, None), (2, 1, 0, None), (0, 0, 0, 2),
                     (0, 0, 0, None), (0, 0, 0, None)],
    'attack_bow': [(0, 0, 0, None), (0, 0, -1, None), (1, 0, 0, 0), (1, 0, -1, None), (3, 0, 0, None),
                   (3, 0, -1, None), (3, 0, -1, None), (3, 0, 0, None), (3, 0, 0, None), (3, 0, 0, None),
                   (0, 0, 0, 3), (0, 0, 0, None)],
}
STRIKE = {'attack_unarmed': (0, 1), 'attack_blade': (0, 2), 'attack_staff': (0, 2), 'attack_bow': (0, 1)}


def strike_dir(body, anim, row):
    a0, a1 = STRIKE[anim]
    s = load(f'characters/base/chr_{body}_base_{anim}.png')
    f0, f1 = fr(s, a0, row)[..., 3] > 0, fr(s, a1, row)[..., 3] > 0
    g = Geo(body, anim, row, a1)
    up = YY < g.waist
    new, old = f1 & ~f0 & up, f0 & ~f1 & up
    if new.sum() < 8:
        return 0
    d = XX[new].mean() - (XX[old].mean() if old.sum() >= 8 else g.cx)
    return 0 if abs(d) < 3 else (1 if d > 0 else -1)


def spring_offsets(anchors, cyclic):
    """Cabelo como mola: atraso contra o movimento da ancora da cabeca (px por quadro)."""
    n = len(anchors); off = np.zeros(2); out = [None] * n
    for k in range(2 if cyclic else 1):
        for i in range(n):
            prev = anchors[i - 1] if (i > 0 or cyclic) else anchors[0]
            vel = np.array(anchors[i]) - np.array(prev)
            off = np.clip(0.55 * off - 0.45 * vel, -2, 2)
            out[i] = off.copy()
    return out


def spring_hair_ex(o):
    hdx, hdy = o
    return {H_MAIN: (lambda X, Y: 0.5 * hdx + 0 * X, lambda X, Y: 0.5 * hdy + 0 * X),
            H_TOP: (lambda X, Y: 1.2 * hdx + 0 * X, lambda X, Y: 1.0 * hdy + 0 * X),
            H_SIDE: (lambda X, Y: 0.9 * hdx + 0 * X, lambda X, Y: 0.6 * hdy + 0 * X)}


def plans_attack(body, anim, row):
    d = strike_dir(body, anim, row)
    rec = ATTACKS[anim]
    geos = [Geo(body, anim, row, c) for c, *_ in rec]
    anchors = [(g.bcx + L * d, g.btop + cr) for g, (c, cr, L, sm) in zip(geos, rec)]
    offs = spring_offsets(anchors, False)
    out = []
    for g, (col, cr, L, sm), o in zip(geos, rec, offs):
        lean = L * d
        head = (round(lean), round(cr))
        body_f = {L_LEGS: tr(), L_HEAD: tr(*head),
                  L_CHEST: field(lambda X, Y, l=lean, w=g.waist: l * (1 - ramp(Y, w - 8, w)),
                                 lambda X, Y, c=cr, w=g.waist: c * (1 - ramp(Y, w - 14, w))),
                  L_HEM: field(lambda X, Y, l=lean, w=g.waist: l * (1 - ramp(Y, w - 8, w)) - 0.6 * o[0] * ramp(Y, w - 6, w),
                               lambda X, Y, c=cr, w=g.waist: c * (1 - ramp(Y, w - 14, w))),
                  L_HEMX: field(lambda X, Y, w=g.waist: -1.2 * o[0] * ramp(Y, w, w + 20), lambda X, Y: 0 * X)}
        wl = lean * (1 - float(ramp(np.array(58.0), g.waist - 8, g.waist)))
        wc = cr * (1 - float(ramp(np.array(58.0), g.waist - 14, g.waist)))
        out.append(dict(src=(anim, col), pose='X', g=g, body=body_f, head=head,
                        hair=hair_fns(g, head, spring_hair_ex(o)), weapon=tr(round(wl), round(wc)),
                        glow=[], spark=[], shut=None, rot=False, split=0, smear=sm))
    return out


def plans_secondary(body, anim, row):
    s = load(f'characters/base/chr_{body}_base_{anim}.png'); n = ncols(s)
    geos = [Geo(body, anim, row, c) for c in range(n)]
    offs = spring_offsets([(g.bcx, g.btop) for g in geos], anim == 'walk')
    out = []
    for c, (g, o) in enumerate(zip(geos, offs)):
        body_f = {L_LEGS: tr(), L_HEAD: tr(), L_CHEST: tr(), L_HANDS: tr(), L_ARM_L: tr(), L_ARM_R: tr(),
                  L_HEM: field(lambda X, Y, w=g.waist: -0.6 * o[0] * ramp(Y, w - 6, w), lambda X, Y, w=g.waist: -0.5 * o[1] * ramp(Y, w - 6, w)),
                  L_HEMX: field(lambda X, Y, w=g.waist: -1.2 * o[0] * ramp(Y, w, w + 20), lambda X, Y, w=g.waist: -0.6 * o[1] * ramp(Y, w, w + 20))}
        out.append(dict(src=(anim, c), pose='X', g=g, body=body_f, head=(0, 0),
                        hair=hair_fns(g, (0, 0), spring_hair_ex(o)), weapon=tr(), glow=[], spark=[], shut=None,
                        rot=False, split=0, smear=None))
    return out


_plans = {}


def plans(body, anim, row):
    k = (body, anim, row)
    if k not in _plans:
        _plans[k] = _plans_raw(body, anim, row)
    return _plans[k]


def _plans_raw(body, anim, row):
    if anim == 'idle':
        return [plan_idle(body, row, i) for i in range(NEW_N['idle'])]
    if anim == 'cast':
        return [plan_cast(body, row, i) for i in range(NEW_N['cast'])]
    if anim in ATTACKS:
        return plans_attack(body, anim, row)
    return plans_secondary(body, anim, row)


# ------------------------------------------------------------------ aplicacao em camadas
def layer_sets(body, phase):
    """Lista de conjuntos de camadas: (tipo, {chave: caminho relativo com {anim}}, nome)."""
    sets = []
    if phase in ('body', 'all'):
        sets.append(('body', {'base': f'characters/base/chr_{body}_base_{{anim}}.png',
                              'mask': f'characters/base/chr_{body}_base_mask_{{anim}}.png'}, 'base'))
        sets.append(('composite', {'base': f'characters/chr_traveler_{body}_{{anim}}.png'}, 'traveler'))
        sets.append(('head', {'x': f'characters/eyes/{body}_{{anim}}.png'}, 'eyes'))
        sets.append(('head', {'x': f'characters/eyes/{body}_idle_blink.png'}, 'blink'))
        for h in sorted(os.listdir(os.path.join(SRC, 'characters', 'hair'))):
            sets.append(('hair', {'x': f'characters/hair/{h}/{body}_{{anim}}.png'}, f'hair_{h}'))
        for f in sorted(os.listdir(os.path.join(SRC, 'characters', 'face'))):
            sets.append(('head', {'x': f'characters/face/{f}/{body}_{{anim}}.png'}, f'face_{f}'))
    if phase in ('equip', 'all'):
        for h in sorted(os.listdir(os.path.join(SRC, 'equipment', 'head'))):
            sets.append(('head', {'x': f'equipment/head/{h}/{body}_{{anim}}.png'}, f'hat_{h}'))
        for w in sorted(os.listdir(os.path.join(SRC, 'equipment', 'weapon'))):
            for suf in ('', '_back'):
                sets.append(('weapon', {'x': f'equipment/weapon/{w}/{body}_{{anim}}{suf}.png'}, f'w_{w}{suf}'))
    if phase in ('outfits', 'all'):
        names = sorted({f[len(f'chr_{body}_'):-len('_mask_idle.png')] for f in os.listdir(os.path.join(SRC, 'characters', 'outfits'))
                        if f.startswith(f'chr_{body}_') and f.endswith('_mask_idle.png')})
        for o in names:
            if o in OWN_FRAMES_OUTFITS:
                continue
            sets.append(('outfit', {'base': f'characters/outfits/chr_{body}_{o}_{{anim}}.png',
                                    'mask': f'characters/outfits/chr_{body}_{o}_mask_{{anim}}.png'}, f'outfit_{o}'))
    return sets


def apply_frame(kind, srcs, p, body, row, anim, base_alpha_src):
    """srcs: chave -> quadro origem (96x96x4) ou None. Devolve chave -> quadro novo."""
    g = p['g']
    outs = {}
    if kind in ('body', 'outfit', 'composite'):
        lab = body_labels(g, p['pose'])
        main = srcs['base']
        if kind == 'outfit':
            lab = body_hem_extra(lab, main[..., 3] > 0, base_alpha_src, g)
        fns = dict(p['body']); z = ZB
        if kind == 'composite':
            hairsrc = srcs.get('_hair')
            if hairsrc is not None:
                hl = hair_labels(g); hm = hairsrc[..., 3] > 0
                lab = np.where(hm, hl, lab)
                fns.update(p['hair'])
            em = srcs.get('_eyes')
            if em is not None:
                lab = np.where(em[..., 3] > 0, L_HEAD, lab)
        for k in ('base', 'mask'):
            if srcs.get(k) is not None:
                outs[k] = warp(srcs[k], lab, fns, z)
        fill_holes(outs, main[..., 3] > 0, 'base')
        drop_specks(outs, 'base', 8)
        if p.get('split') and srcs.get('_b') is not None:
            bsrc = srcs['_b']; s = p['split']; crr = int(round(p.get('cr', 0)))
            gap = (np.abs(XX - g.cx) < s + 0.5) & (YY >= g.chin + 2) & (YY <= g.waist - 2)
            for k in outs:
                sh = np.roll(bsrc[k], crr, 0)
                m = gap & (outs['base'][..., 3] == 0) & (sh[..., 3] > 0)
                outs[k][m] = sh[m]
        if p['rot']:
            region = np.zeros((FR, FR), bool)
            region[:, :max(0, g.tx0)] = True; region[:, min(FR, g.tx1 + 1):] = True; region[g.waist:] = False
            outline_fix(outs, 'base', region, darkest(main))
        if p['smear'] is not None and srcs.get('_ghost') is not None:
            gsrc = srcs['_ghost'][..., 3] > 0; cur = main[..., 3] > 0
            gg = Geo(body, anim, row, p['smear'])
            top = max(g.chin, gg.chin) + 2
            if anim == 'attack_unarmed' and p['src'][1] == 3:
                region = (YY >= g.waist) & (YY < 88)
            else:
                region = (YY > top) & (YY < g.waist)
            smear(outs, 'base', 'mask', gsrc & ~cur, region)
        for (x, y, r, rays, under) in p['glow']:
            glow(outs, 'base', 'mask', x, y, r, rays, under)
        for (x, y) in p['spark']:
            sparkle(outs, 'base', 'mask', x, y)
    elif kind == 'hair':
        outs['x'] = warp(srcs['x'], hair_labels(g), p['hair'])
        fill_holes(outs, srcs['x'][..., 3] > 0, 'x')
    elif kind == 'head':
        outs['x'] = warp(srcs['x'], np.full((FR, FR), L_HEAD), {L_HEAD: tr(*p['head'])})
    elif kind == 'weapon':
        outs['x'] = warp(srcs['x'], np.full((FR, FR), L_HANDS), {L_HANDS: p['weapon']})
        if p['smear'] is not None and srcs.get('_ghost') is not None and srcs.get('_body') is not None:
            wg = srcs['_ghost'][..., 3] > 0
            smear(outs, 'x', None, wg & ~(srcs['x'][..., 3] > 0), srcs['_body'][..., 3] == 0)
    return outs


PRIORITY = [GLOW[0], GLOW[1], GLOW[2], SMEAR, GLOW[3]]


def cap_colors(out, orig, limit=48):
    """Folhas validadas (composto, roupas: <= 48 cores): as cores novas (brilho, rastro) que nao cabem viram a cor
    mais proxima da propria folha."""
    oc = {tuple(int(v) for v in c) for c in orig[orig[..., 3] > 0][:, :3]}
    op = out[..., 3] > 0
    nc = {tuple(int(v) for v in c) for c in out[op][:, :3]} - oc
    if len(oc) + len(nc) <= max(limit, len(oc)):
        return
    room = max(0, limit - len(oc))
    keep = [c for c in PRIORITY if c in nc][:room]
    pal = np.array(sorted(oc) + keep, int)
    for c in nc:
        if c in keep:
            continue
        m = op & np.all(out[..., :3] == c, -1)
        j = int(((pal - np.array(c)) ** 2).sum(-1).argmin())
        out[m, :3] = pal[j]


def run_set(kind, paths, name, body, out_root, log):
    written = 0
    for anim in ANIMS:
        rel = {k: v.format(anim=anim) for k, v in paths.items()}
        if name == 'blink':
            if anim != 'idle':
                continue
            rel = {'x': f'characters/eyes/{body}_idle_blink.png'}
        sheets = {k: load(r) for k, r in rel.items()}
        if any(s is None for s in sheets.values()):
            continue
        n = NEW_N.get(anim, ncols(next(iter(sheets.values()))))
        cols_out = {k: np.zeros((FR * ROWS, FR * n, 4), np.uint8) for k in sheets}
        for row in range(ROWS):
            pl = plans(body, anim, row)
            for i, p in enumerate(pl):
                src_anim, col = p['src']
                if p.get('src_override'):
                    src_anim, col = 'idle', 0
                srel = {k: v.format(anim=src_anim) if '{anim}' in paths.get(k, '') else rel[k] for k, v in paths.items()}
                if name == 'blink':
                    srel = {'x': rel['x']}
                srcs = {}
                ok = True
                for k, r in srel.items():
                    s = load(r)
                    if s is None:
                        ok = False; break
                    srcs[k] = fr(s, min(col, ncols(s) - 1), row)
                if not ok:
                    continue
                base_src = fr(load(f'characters/base/chr_{body}_base_{src_anim}.png'), col, row)
                if kind == 'composite':
                    hs = load(f'characters/hair/{DEFAULT_HAIR[body]}/{body}_{src_anim}.png')
                    es = load(f'characters/eyes/{body}_{src_anim}.png')
                    srcs['_hair'] = fr(hs, col, row) if hs is not None else None
                    srcs['_eyes'] = fr(es, col, row) if es is not None else None
                if kind in ('body', 'outfit', 'composite') and p.get('split'):
                    srcs['_b'] = {k: fr(load(srel[k]), 2, row) for k in ('base', 'mask') if k in srel}
                if p['smear'] is not None:
                    gk = 'base' if 'base' in srel else 'x'
                    srcs['_ghost'] = fr(load(srel[gk]), p['smear'], row)
                if kind == 'weapon':
                    srcs['_body'] = None
                outs = apply_frame(kind, srcs, p, body, row, anim, base_src[..., 3] > 0)
                if kind == 'weapon' and p['smear'] is not None:
                    # rastro da arma so onde o corpo novo nao cobre: usa o corpo-base deste quadro
                    bp = apply_frame('body', {'base': base_src, 'mask': fr(load(f'characters/base/chr_{body}_base_mask_{src_anim}.png'), col, row)},
                                     dict(p, glow=[], spark=[], smear=None), body, row, anim, base_src[..., 3] > 0)
                    srcs['_body'] = bp['base']
                    outs = apply_frame(kind, srcs, p, body, row, anim, base_src[..., 3] > 0)
                if name == 'eyes' and p.get('shut') is not None:
                    bl = load(f'characters/eyes/{body}_idle_blink.png')
                    dx, dy = p['shut']
                    outs['x'] = np.roll(np.roll(fr(bl, 0, row), dy, 0), dx, 1)
                for k in sheets:
                    cols_out[k][row * FR:(row + 1) * FR, i * FR:(i + 1) * FR] = outs[k]
        if anim == 'walk' and kind in ('body', 'outfit') and 'base' in cols_out:
            sid = walk8_legs.sheet_id_from_path(rel['base'])
            o8, m8, _ = walk8_legs.process_arrays(cols_out['base'], cols_out.get('mask'), sid)
            cols_out['base'] = o8
            if m8 is not None:
                cols_out['mask'] = m8
        for k, r in rel.items():
            if kind in ('composite', 'outfit') and k == 'base':
                cap_colors(cols_out[k], sheets[k])
            dst = os.path.join(out_root, r); os.makedirs(os.path.dirname(dst), exist_ok=True)
            Image.fromarray(cols_out[k]).save(dst); written += 1
    log.append(f'{name}: {written} folhas')
    return written


def main():
    out_root = sys.argv[1]
    phase = 'all'; bodies = ['male', 'female']; only = None
    for a in sys.argv[2:]:
        if a.startswith('--phase='):
            phase = a.split('=', 1)[1]
        elif a.startswith('--bodies='):
            bodies = a.split('=', 1)[1].split(',')
        elif a.startswith('--only='):
            only = a.split('=', 1)[1].split(',')
    log = []
    for body in bodies:
        init_head_h(body)
        for kind, paths, name in layer_sets(body, phase):
            if only and name not in only:
                continue
            run_set(kind, paths, name, body, out_root, log)
            print(body, log[-1], flush=True)


if __name__ == '__main__':
    main()
