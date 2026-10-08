#!/usr/bin/env python3
"""Andar com 8 desenhos distintos: poses de perna intermediarias (piloto aprovado em 08/10/2026).

As folhas de andar antigas (corpo-base e roupas de titulo) tem 4 desenhos por linha, na ordem A A B C D D B C (A e D =
passada aberta, mais baixa; B = passagem, mais alta; C = passagem a meia altura). Este script mantem as 8 colunas e
troca as repetidas por poses novas de perna. O corpo de cima de cada coluna e o da PROPRIA coluna (cabelo, olhos,
brincos, chapeus e armas, que seguem as colunas, continuam alinhados sem mexer em nenhuma outra folha):

  col 0  A                         contato
  col 1  A + pernas de A           descida: pernas fecham ~metade rumo a passagem, pe de tras sai do chao
  col 2  B                         passagem
  col 3  C + pernas de D           subida: pernas abrem ~metade rumo a D, pe da frente no ar
  col 4  D                         contato
  col 5  D + pernas de D           descida (como col 1, a partir de D)
  col 6  B + pernas de C           passagem do outro passo (pernas de C, esticadas 1 px ate o quadril de B)
  col 7  C + pernas de A           subida rumo a A

Tecnica (deformacao por partes, sem cor nova): a zona das pernas (abaixo do quadril, so o que chega ao chao) e
separada em duas pernas por k-linhas (2 retas) e limpeza por componentes. Cada perna e um "osso" com rampa:
deslocamento (dx, dy) do quadril ate o tornozelo, o pe inteiro rigido. Mapeamento inverso por vizinho mais proximo,
linha a linha (cada linha anda um numero inteiro de pixels: contorno e sombreado inteiros). A perna escura (longe) e
desenhada antes. A mascara recebe o mesmo mapa. Retoque: pixel solto apagado; ajustes por quadro em MANUAL.

Modos por (folha, linha) em MODES:
  legs  (padrao) o descrito acima;
  hem   roupa longa (manto, robe, saia ate o chao) que esconde as pernas: o desenho da propria coluna, com a barra
        (abaixo do quadril) balancando 1 px atrasada (como o L_HEMX do rollout.py), sem separar pernas;
  hold  copia a coluna antiga (4 poses).

Uso:
  walk8_legs.py [--out DIR] [--force] [--debug DIR] <folha_walk.png> ...   (mascara: mesmo nome com _mask_walk)
  Sem --out sobrescreve no lugar. A folha gerada leva o texto PNG walk8=1; folhas ja marcadas (ou que nao seguem o
  padrao A A B C D D B C) sao puladas, a menos que --force.
  Do rollout.py: process_arrays(cor, mascara, sheet_id) depois de gerar o walk de 4 poses (fases body e outfits).
"""
import os, re, sys, json
import numpy as np
from PIL import Image, PngImagePlugin
from scipy.ndimage import label

FR = 96
ROWS = 5
# linhas: 0 S, 1 SE, 2 E, 3 NE, 4 N (SO/O/NO = espelho no cliente)
FRONT_ROWS = (0,)        # vista de frente: pe de tras aparece mais alto
BACK_ROWS = (4,)         # vista de costas: pe da frente aparece mais alto
SIDE_ROWS = (1, 2, 3)    # olhando para a direita da tela: pe de tras = menor x

# plano das colunas: (corpo de cima, pernas de, passagem alvo, fracao rumo a passagem, perna que sobe, dy da subida)
# 'back' / 'front' = pe de tras / da frente da passada da fonte das pernas.
PLAN = {
    1: dict(upper=0, legs=0, toward=2, frac=0.5, lift='back', lift_px=1),
    3: dict(upper=3, legs=4, toward=2, frac=0.5, lift='front', lift_px=2),
    5: dict(upper=4, legs=4, toward=3, frac=0.5, lift='back', lift_px=1),
    6: dict(upper=2, legs=3, toward=None),
    7: dict(upper=3, legs=0, toward=3, frac=0.5, lift='front', lift_px=2),
}
KEEP = (0, 2, 4)   # colunas que ficam como estao (A, B, D)
OLD_TO_SRC = {0: 0, 2: 2, 3: 3, 4: 4}  # desenhos distintos antigos: A=0, B=2, C=3, D=4

# ajustes manuais por (folha, linha, coluna); folha = 'male_base', 'female_title_matinta', ...
#   legs (coluna fonte das pernas), hip (dx, dy), ankle (altura do pe), dfoot_back/dfoot_front (dx, dy extra),
#   knee_back/knee_front (dx no joelho), near (0/1 = perna de perto)
MANUAL = {
    # costas da feminina: a passada A original tem as pernas de pele (sem a legging) e piscava; a subida rumo a A
    # usa as pernas de D (legging), entao so as colunas 0 e 1 ficam com a perna clara, como antes
    ('female_base', 4, 7): {'legs': 4},
}
# modo por (folha, linha): 'legs' (padrao), 'hem' ou 'hold' (ver o topo)
MODES = {}
# lote 2 (08/10/2026): mantos ate o chao (as pernas nao aparecem) -> barra balancando em todas as vistas
for _b in ('male', 'female'):
    for _t in ('boitata', 'crystal', 'ember', 'firefly'):
        for _r in range(ROWS):
            MODES[(f'{_b}_title_{_t}', _r)] = 'hem'
    # avental do root: de frente e de costas a barra cobre as coxas e o enxerto rasgava o avental
    MODES[(f'{_b}_title_root', 0)] = 'hem'
    MODES[(f'{_b}_title_root', 4)] = 'hem'

# quadros revistos na prancha que ficaram feios no enxerto -> reserva (pe levantado na propria coluna)
_LIFT_REVIEW = {
    'female_title_cerrado': [(0, 3), (0, 7)],
    'male_title_jabuti': [(2, 7)],
    'female_title_jaguar': [(3, 3)],
    'female_title_machete': [(2, 3), (3, 3)],
    'female_title_aroeira': [(2, 3), (3, 7)],
    'female_title_matinta': [(2, 7)],
    'male_title_matinta': [(1, 3), (2, 3), (3, 3)],
}
for _sid, _frames in _LIFT_REVIEW.items():
    for _r, _c in _frames:
        MANUAL.setdefault((_sid, _r, _c), {})['mode'] = 'lift'
# balanco da barra no modo hem, por coluna (px na barra; + = para a frente na tela, vistas de lado olham para a direita)
HEM_DX = {1: -1, 3: 1, 5: -1, 6: 1, 7: -1}


def frame(a, r, c):
    return a[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]


def shadow_mask(f):
    """Sombra de chao desenhada: corrida curta (<=3 px) no fundo da coluna, com o topo na faixa do chao."""
    op = f[:, :, 3] > 0
    sh = np.zeros_like(op)
    ybot = np.where(op.any(1))[0].max()
    for x in range(FR):
        ys = np.where(op[:, x])[0]
        if len(ys) == 0:
            continue
        y1 = ys.max()
        y0 = y1
        while y0 - 1 >= 0 and op[y0 - 1, x]:
            y0 -= 1
        if y1 - y0 + 1 <= 3 and y0 >= ybot - 3:
            sh[y0:y1 + 1, x] = True
    # so conta como sombra uma faixa horizontal (>=2 px de largura em algum ponto)
    lab, n = label(sh, structure=np.ones((3, 3)))
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if xs.max() - xs.min() < 2:
            sh[lab == i] = False
    return sh


def leg_zone(f, pivot, shadow):
    """Pixels das pernas abaixo do pivo: componentes (4-conexos) que chegam ao chao. Maos soltas, que nao chegam
    ao pe, e a sombra ficam de fora."""
    op = (f[:, :, 3] > 0) & ~shadow
    z = np.zeros_like(op)
    z[pivot:] = op[pivot:]
    lab, n = label(z)
    if n == 0:
        return z
    ybot = np.where(op.any(1))[0].max()
    keep = np.zeros_like(z)
    for i in range(1, n + 1):
        ys = np.where(lab == i)[0]
        if ys.max() >= ybot - 6 and len(ys) >= 6:
            keep |= lab == i
    # maos que pendem ate o quadril: nas 6 linhas de cima so vale o que fica na largura das coxas logo abaixo
    band = keep[pivot + 6:pivot + 9]
    xs = np.where(band.any(0))[0]
    if len(xs):
        x0, x1 = xs.min() - 1, xs.max() + 1
        keep[pivot:pivot + 6, :max(0, x0)] = False
        keep[pivot:pivot + 6, x1 + 1:] = False
        # o que ficou solto depois do corte (pedaco de mao) sai
        lab2, n2 = label(keep)
        for i in range(1, n2 + 1):
            if np.where(lab2 == i)[0].max() < ybot - 6:
                keep[lab2 == i] = False
    return keep


def split_legs(zone, row):
    """Separa a zona em 2 pernas por k-linhas (x = a + b*y), mais limpeza por componente."""
    ys, xs = np.where(zone)
    ylo, yhi = ys.min(), ys.max()
    # chute inicial: metade esquerda / direita pelo x mediano da metade de baixo
    low = ys > (ylo + yhi) / 2
    xm = np.median(xs[low])
    lab = (xs > xm).astype(int)
    for _ in range(20):
        lines = []
        for k in (0, 1):
            m = lab == k
            if m.sum() < 5:
                return None
            w = np.where(ys[m] > ylo + 2, 1.0, 0.2)
            A = np.vstack([np.ones(m.sum()), ys[m]]).T
            coef = np.linalg.lstsq(A * w[:, None], xs[m] * w, rcond=None)[0]
            lines.append(coef)
        d = np.stack([np.abs(xs - (c[0] + c[1] * ys)) for c in lines], 1)
        new = np.argmin(d, 1)
        if (new == lab).all():
            break
        lab = new
    legs = []
    for k in (0, 1):
        m = np.zeros_like(zone)
        m[ys[lab == k], xs[lab == k]] = True
        legs.append(m)
    # ilhas pequenas de uma perna grudadas na outra mudam de lado
    for k in (0, 1):
        l, n = label(legs[k], structure=np.ones((3, 3)))
        if n > 1:
            sizes = [(l == i).sum() for i in range(1, n + 1)]
            big = 1 + int(np.argmax(sizes))
            for i in range(1, n + 1):
                if i != big:
                    legs[1 - k] |= l == i
                    legs[k] &= ~(l == i)
    # pe que passa por baixo da outra perna (vista de frente): linhas abaixo do fim real de uma perna (ultima linha
    # com >=3 px) pertencem a outra
    for k in (0, 1):
        cnt = legs[k].sum(1)
        rows = np.where(cnt >= 3)[0]
        if len(rows) == 0:
            continue
        yend = rows.max()
        other = legs[1 - k]
        if np.where(other.any(1))[0].max() > yend:
            moved = legs[k].copy(); moved[:yend + 1] = False
            legs[1 - k] |= moved; legs[k] &= ~moved
    # ordena: perna 0 = esquerda da tela (menor x no pe)
    def foot_x(m):
        yy, xx = np.where(m)
        return xx[yy >= yy.max() - 4].mean()
    legs.sort(key=foot_x)
    return legs, lines


def crotch_y(legs):
    """Linha mais alta em que as duas pernas estao separadas por fundo (ou nao se tocam)."""
    a, b = legs
    top = None
    for y in range(FR - 1, -1, -1):
        xa = np.where(a[y])[0]; xb = np.where(b[y])[0]
        if len(xa) == 0 or len(xb) == 0:
            if top is not None:
                break
            continue
        if xa.max() + 1 < xb.min():
            top = y
        elif top is not None:
            break
    return top


def leg_info(m):
    ys, xs = np.where(m)
    rows = np.where(m.sum(1) >= 3)[0]
    ybot = rows.max() if len(rows) else ys.max()
    foot = ys >= ybot - 3
    return dict(ybot=int(ybot), fx=float(xs[foot].mean()), top=int(ys.min()))


def feet_x(zone):
    """Centro x de cada pe: 2-medias no x dos pixels das 4 linhas de baixo de cada coluna da zona."""
    ys, xs = np.where(zone)
    ybot = ys.max()
    sel = ys >= ybot - 5
    x = xs[sel].astype(float)
    c = np.array([x.min(), x.max()])
    for _ in range(20):
        lab = np.abs(x[:, None] - c[None]).argmin(1)
        c = np.array([x[lab == k].mean() if (lab == k).any() else c[k] for k in (0, 1)])
    return sorted(c.tolist())


# Acessorio pendurado no quadril (facao/arco verde das roupas de titulo): cores do miolo; o contorno escuro vizinho
# entra junto. Fica com o quadril (nao anda com a perna) e e redesenhado por cima das pernas.
ACCESSORY_CORE = {(76, 152, 116), (120, 192, 156)}


def accessory_mask(f):
    rgb = f[..., :3].astype(int)
    op = f[..., 3] > 0
    core = np.zeros(op.shape, bool)
    for c in ACCESSORY_CORE:
        core |= op & np.all(rgb == c, -1)
    if not core.any():
        return core
    pad = np.pad(core, 1)
    near = np.zeros_like(core)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near |= pad[1 + dy:1 + dy + FR, 1 + dx:1 + dx + FR]
    lum = rgb @ np.array([3, 6, 1]) / 10
    return core | (near & op & (lum < 60))


def without(f, m):
    g = f.copy()
    g[m] = 0
    return g


def analyze(f, row, pivot):
    f = without(f, accessory_mask(f))
    sh = shadow_mask(f)
    z = leg_zone(f, pivot, sh)
    legs, lines = split_legs(z, row)
    return dict(shadow=sh, pivot=pivot, zone=z, legs=legs, info=[leg_info(m) for m in legs], lines=lines,
                feet=feet_x(z))


def find_pivot(f, row):
    """Quadril de uma pose de passagem: 3 px acima da forquilha."""
    sh = shadow_mask(f)
    op = (f[:, :, 3] > 0) & ~sh
    yb = np.where(op.any(1))[0]
    guess = int(yb.min() + (yb.max() - yb.min()) * 0.66)
    z = leg_zone(f, guess, sh)
    res = split_legs(z, row)
    cy = crotch_y(res[0]) if res else None
    return (cy - 3) if cy is not None else guess


def torso_offset(fref, f, pivot):
    """(dx, dy) que leva o tronco de fref ao de f: melhor encaixe da faixa da cintura (12 linhas acima do pivo de
    fref), so nas colunas do quadril."""
    sh = shadow_mask(fref)
    z = leg_zone(fref, pivot, sh)
    xs = np.where(z[pivot:pivot + 3].any(0))[0]
    x0, x1 = max(0, xs.min() - 1), min(FR - 1, xs.max() + 1)
    best = None
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            err = 0; cnt = 0
            for y in range(pivot - 12, pivot):
                yy = y + dy
                for x in range(x0, x1 + 1):
                    xx = x + dx
                    if not (0 <= yy < FR and 0 <= xx < FR):
                        continue
                    pa = fref[y, x]; pb = f[yy, xx]
                    if pa[3] == 0 and pb[3] == 0:
                        continue
                    cnt += 1
                    if pa[3] != pb[3] or np.abs(pa[:3].astype(int) - pb[:3].astype(int)).sum() > 30:
                        err += 1
            score = err / max(cnt, 1) + 0.01 * (abs(dx) + abs(dy))
            if best is None or score < best[0]:
                best = (score, dx, dy)
    return best[1], best[2], best[0]


def warp_leg(src_mask, pivot, ankle_y, d_piv, d_foot, knee=0.0):
    """Mapa inverso de uma perna: devolve dict destino -> origem. Rampa linear do pivo (d_piv) ao tornozelo
    (d_foot); abaixo do tornozelo o pe e rigido. knee = dx extra no meio (dobra do joelho)."""
    ys, xs = np.where(src_mask)
    rows = sorted(set(ys.tolist()))
    def disp(y):
        t = 0.0 if y <= pivot else min(1.0, (y - pivot) / max(1, ankle_y - pivot))
        dx = d_piv[0] + (d_foot[0] - d_piv[0]) * t + knee * np.sin(np.pi * t) * (1 if y < ankle_y else 0)
        dy = d_piv[1] + (d_foot[1] - d_piv[1]) * t
        return dx, dy
    # destino de cada linha de origem (float), monotono
    fwd = {y: y + disp(y)[1] for y in rows}
    out = {}
    ymin_d = int(np.floor(min(fwd.values()))); ymax_d = int(np.ceil(max(fwd.values())))
    rows_arr = np.array(rows, float); fwd_arr = np.array([fwd[y] for y in rows])
    for yd in range(ymin_d, ymax_d + 1):
        # origem: linha cuja imagem fica mais perto de yd (vizinho mais proximo)
        i = int(np.argmin(np.abs(fwd_arr - yd)))
        # (sem pular linha: se a perna esticou, a linha mais proxima se repete; senao abriria fresta)
        ys_ = rows[i]
        dx = int(round(disp(ys_)[0]))
        for x in np.where(src_mask[ys_])[0]:
            xd = x + dx
            if 0 <= xd < FR and 0 <= yd < FR:
                out[(yd, xd)] = (ys_, x)
    return out


def row_analysis(a, r):
    """Pivo e deslocamento do tronco de cada coluna, tendo B (col 2) como referencia."""
    fB = frame(a, r, 2)
    pB = find_pivot(fB, r)
    off, an = {}, {}
    for c in range(8):
        dx, dy, fit = (0, 0, 0.0) if c == 2 else torso_offset(fB, frame(a, r, c), pB)
        off[c] = (dx, dy)
        an[c] = analyze(frame(a, r, c), r, pB + dy)
        an[c]['fit'] = fit   # fracao de pixels da cintura que nao bateram (0 = encaixe perfeito)
    return off, an


def hem_frame(a, m, r, c, pivot):
    """Modo hem: a propria coluna, com a parte abaixo do quadril deslocada em rampa (0 no quadril, HEM_DX na barra).
    Na frente e nas costas o mesmo deslocamento le como o quadril balancando."""
    f = frame(a, r, c).copy(); fm = frame(m, r, c).copy()
    if c not in HEM_DX:
        return f, fm
    op = f[..., 3] > 0
    ys = np.where(op.any(1))[0]
    ybot = ys.max()
    dxb = HEM_DX[c]
    of = f.copy(); om = fm.copy()
    for y in range(pivot, ybot + 1):
        t = (y - pivot) / max(1, ybot - pivot)
        dx = int(round(dxb * t))
        if dx == 0:
            continue
        of[y] = 0; om[y] = 0
        if dx > 0:
            of[y, dx:] = f[y, :-dx]; om[y, dx:] = fm[y, :-dx]
        else:
            of[y, :dx] = f[y, -dx:]; om[y, :dx] = fm[y, -dx:]
    return of, om


# reserva por quadro (modo lift): a propria coluna com um pe levantado (lado e px por coluna)
LIFT = {1: ('L', 1), 3: ('R', 2), 5: ('R', 1), 6: ('R', 1), 7: ('L', 2)}


def lift_frame(a, m, r, c, an):
    """Reserva segura: o desenho da propria coluna com o pe de um lado (metade da zona das pernas) levantado; a
    canela encurta o mesmo tanto. Usada quando o enxerto de pernas falha nas checagens."""
    f = frame(a, r, c).copy(); fm = frame(m, r, c).copy()
    z = an[c]['zone']
    ys, xs = np.where(z)
    ybot = ys.max(); y0 = ybot - 9
    xm = int(np.median(xs[ys >= y0]))
    side, k = LIFT[c]
    cols = np.zeros(FR, bool)
    if side == 'L':
        cols[:xm] = True
    else:
        cols[xm:] = True
    sel = np.zeros_like(z)
    sel[y0:ybot + 1] = z[y0:ybot + 1] & cols[None, :]
    of = f.copy(); om = fm.copy()
    of[sel] = 0; om[sel] = 0
    yy, xx = np.where(sel)
    of[yy - k, xx] = f[yy, xx]; om[yy - k, xx] = fm[yy, xx]
    return of, om


def tween(a, m, r, c, off, an, sheet_id):
    """Quadro novo com enxerto de pernas; cai no lift_frame se falhar nas checagens."""
    man = MANUAL.get((sheet_id, r, c), {})
    if man.get('mode') == 'lift':
        fo, fmo = lift_frame(a, m, r, c, an)
        return fo, fmo, dict(reserva='manual')
    fo, fmo, rep = tween_legs(a, m, r, c, off, an, sheet_id)
    if rep.get('reserva'):
        fo, fmo = lift_frame(a, m, r, c, an)
    return fo, fmo, rep


def tween_legs(a, m, r, c, off, an, sheet_id):
    p = PLAN[c]
    man = MANUAL.get((sheet_id, r, c), {})
    U, K = c, man.get('legs', p['legs'])   # corpo de cima: o da propria coluna (= p['upper'] nas folhas de 4 poses)
    fu, fk = frame(a, r, U), frame(a, r, K)
    mu, mk = frame(m, r, U), frame(m, r, K)
    au, ak = an[U], an[K]
    # quadril de K levado ao de U
    dx0 = off[U][0] - off[K][0]; dy0 = off[U][1] - off[K][1]
    if 'hip' in man:
        dx0, dy0 = man['hip']
    if U != K and (abs(dy0) > 3 or abs(dx0) > 4):
        return None, None, dict(reserva=f'quadril {dx0},{dy0}')
    pivot_u = au['pivot']
    pivot_k = pivot_u - dy0
    acc_u = accessory_mask(fu); acc_k = accessory_mask(fk)
    zk = leg_zone(without(fk, acc_k), pivot_k, ak['shadow'])
    legs_k, _ = split_legs(zk, r)
    if acc_k.any():
        # o que o acessorio tampava dentro da perna vira o pixel de perna mais proximo na linha (senao o buraco
        # andaria com a perna)
        fk = fk.copy(); mk = mk.copy()
        for l in legs_k:
            for y in np.where(l.any(1))[0]:
                xs = np.where(l[y])[0]
                for x in range(xs.min(), xs.max() + 1):
                    if acc_k[y, x] and not l[y, x]:
                        j = xs[np.argmin(np.abs(xs - x))]
                        fk[y, x] = fk[y, j]; mk[y, x] = mk[y, j]; l[y, x] = True
    info_k = [leg_info(l) for l in legs_k]
    back = 0
    d_feet = [(float(dx0), 0.0), (float(dx0), 0.0)]
    if p['toward'] is not None:
        at = an[p['toward']]
        fr = p['frac']
        if r in SIDE_ROWS:
            # passada lateral: os pes se aproximam (fr da diferenca de abertura), o centro acompanha a passagem
            fk_x = ak['feet']; ft_x = at['feet']
            sep_k = fk_x[1] - fk_x[0]; sep_t = ft_x[1] - ft_x[0]
            close = fr * (sep_k - sep_t) / 2.0
            d_feet = [(close, 0.0), (-close, 0.0)]
            back = 0
        else:
            # frente/costas: o pe mais alto desce rumo a linha do chao da passagem
            yb = [i['ybot'] for i in info_k]
            hi = int(np.argmin(yb))
            d_feet = [(0.0, 0.0), (0.0, 0.0)]
            # pelo menos 1 px, para o quadro novo nao repetir a passada
            d_feet[hi] = (0.0, max(1.0, round(fr * (max(yb) - yb[hi]))) if max(yb) > yb[hi] else 0.0)
            if max(yb) == min(yb):
                # pes na mesma altura: o de tras e o de menos pixels no pe (mais longe da camera)
                cnt = [int(l[max(yb) - 9:].sum()) for l in legs_k]
                back = int(np.argmin(cnt))
            elif r in FRONT_ROWS:
                back = hi
            else:
                back = 1 - hi
        li = back if p['lift'] == 'back' else 1 - back
        # frente/costas: o pe de tras que sai do chao ja sobe na tela por estar atras; so o da frente ganha o
        # levantar extra (no lado, o calcanhar de tras sai do chao)
        lift = p['lift_px'] if (r not in FRONT_ROWS or p['lift'] == 'front') else 0
        if lift == 0 and all(d == (0.0, 0.0) for d in d_feet):
            lift = 1   # frente sem diferenca de altura: o calcanhar de tras sobe 1 px para o quadro nao repetir
        d_feet[li] = (d_feet[li][0], d_feet[li][1] - lift)
        for i, side in ((back, 'back'), (1 - back, 'front')):
            ex = man.get('dfoot_' + side)
            if ex:
                d_feet[i] = (d_feet[i][0] + ex[0], d_feet[i][1] + ex[1])
        # deslocamentos relativos a K; somar o quadril so no x (o y do pe fica no chao de K)
        d_feet = [(d[0] + dx0, d[1]) for d in d_feet]
    lum = []
    for l in legs_k:
        px = fk[l][:, :3].astype(float)
        lum.append((px @ np.array([0.3, 0.59, 0.11])).mean())
    order = list(np.argsort(lum))  # escura (longe) primeiro
    if 'near' in man:
        order = [1 - man['near'], man['near']]
    fz = leg_zone(without(fu, acc_u), pivot_u, au['shadow'])
    fo = fu.copy(); fmo = mu.copy()
    fo[fz] = 0; fmo[fz] = 0
    fo[au['shadow']] = 0; fmo[au['shadow']] = 0
    fo[ak['shadow']] = fk[ak['shadow']]; fmo[ak['shadow']] = mk[ak['shadow']]
    for i in order:
        side = 'back' if i == back else 'front'
        ankle = info_k[i]['ybot'] - man.get('ankle', 12 if r in SIDE_ROWS else 9)
        knee = man.get('knee_' + side, 0.0) if p['toward'] is not None else 0.0
        mp = warp_leg(legs_k[i], pivot_k, ankle, (dx0, dy0), d_feet[i], knee)
        for (yd, xd), (ys_, xs_) in mp.items():
            fo[yd, xd] = fk[ys_, xs_]; fmo[yd, xd] = mk[ys_, xs_]
    fo[acc_u] = fu[acc_u]; fmo[acc_u] = mu[acc_u]   # acessorio do quadril por cima das pernas
    # fresta na emenda (barra da roupa x topo das pernas enxertadas): volta o pixel da propria coluna
    for y in range(max(1, pivot_u - 1), min(FR - 2, pivot_u + 5)):
        gap = (fo[y, :, 3] == 0) & (fu[y, :, 3] > 0) & (fo[y - 1, :, 3] > 0) & \
              ((fo[y + 1, :, 3] > 0) | (fo[y + 2, :, 3] > 0))
        fo[y, gap] = fu[y, gap]; fmo[y, gap] = mu[y, gap]
    for (y, x), v in man.get('px', {}).items() if isinstance(man.get('px'), dict) else []:
        fo[y, x] = v
    op = fo[:, :, 3] > 0
    pad = np.pad(op, 1)
    nb = sum(np.roll(np.roll(pad, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
             if (dy, dx) != (0, 0))[1:-1, 1:-1]
    lone = op & (nb == 0)
    fo[lone] = 0; fmo[lone] = 0
    # pedacos soltos perto do chao (sola/sombra que ficou para tras quando o pe andou): ate 15 px, fora do corpo e
    # que nao existiam no desenho da propria coluna
    lab, n = label(fo[..., 3] > 0, structure=np.ones((3, 3)))
    if n > 1:
        sizes = np.bincount(lab.ravel())
        main = int(np.argmax(sizes[1:])) + 1
        yb = np.where(fo[..., 3].any(1))[0].max()
        for i in range(1, n + 1):
            if i == main or sizes[i] > 15:
                continue
            msk = lab == i
            if np.where(msk)[0].min() < yb - 8:
                continue
            if (fu[msk][:, 3] > 0).all() and (fu[msk] == fo[msk]).all():
                continue
            fo[msk] = 0; fmo[msk] = 0
    # checagens: nada abaixo do chao; a parte de baixo nao perde nem ganha muito (roupa rasgada no enxerto)
    ground = max(np.where(fu[..., 3].any(1))[0].max(), np.where(fk[..., 3].any(1))[0].max())
    if fo[ground + 1:, :, 3].any():
        return fo, fmo, dict(reserva='abaixo do chao')
    n_new = int((fo[pivot_u:, :, 3] > 0).sum())
    n_u = int((fu[pivot_u:, :, 3] > 0).sum()); n_k = int((fk[pivot_k:, :, 3] > 0).sum())
    if not (0.8 * min(n_u, n_k) <= n_new <= 1.2 * max(n_u, n_k)):
        return fo, fmo, dict(reserva=f'parte de baixo {n_u}/{n_k}->{n_new}')
    rep = dict(pivot_u=int(pivot_u), pivot_k=int(pivot_k), hip=(int(dx0), int(dy0)),
               feet=[(round(d[0], 2), round(d[1], 2)) for d in d_feet], lone=int(lone.sum()))
    return fo, fmo, rep


def is_four_pose(a):
    """Folha de 4 poses (A A B C D D B C): coluna 1 = 0, 5 = 4, 6 = 2 e 7 = 3 na maioria das linhas."""
    ok = 0
    for r in range(ROWS):
        if all((frame(a, r, x) == frame(a, r, y)).all() for x, y in ((1, 0), (5, 4), (6, 2), (7, 3))):
            ok += 1
    return ok >= 3


def build(a, m, sheet_id, debug=None):
    out = np.zeros_like(a); outm = np.zeros_like(m)
    report = {}
    for r in range(ROWS):
        mode = MODES.get((sheet_id, r), 'legs')
        off = an = None
        if mode == 'legs':
            try:
                off, an = row_analysis(a, r)
            except Exception as e:  # pernas nao separaveis (roupa ate o chao): cai no modo hem
                report[f'{r}:aviso'] = f'analise falhou ({type(e).__name__}); modo hem'
                mode = 'hem'
        report[f'{r}:modo'] = mode
        for c in range(8):
            sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
            if c in KEEP or mode == 'hold':
                out[sl] = frame(a, r, c); outm[sl] = frame(m, r, c)
                continue
            if mode == 'hem':
                # quadril aproximado: 62% da altura do boneco (a forquilha nao aparece debaixo do manto)
                yb = np.where(frame(a, r, 2)[..., 3].any(1))[0]
                pv = int(yb.min() + 0.62 * (yb.max() - yb.min()))
                out[sl], outm[sl] = hem_frame(a, m, r, c, pv)
                continue
            fo, fmo, rep = tween(a, m, r, c, off, an, sheet_id)
            out[sl] = fo; outm[sl] = fmo
            report[f'{r},{c}'] = rep
        if debug is not None and an is not None:
            dbg = np.zeros((FR, FR * 4, 4), np.uint8)
            for j, c in enumerate((0, 2, 3, 4)):
                f = frame(a, r, c)
                g = f.copy()
                g[..., 3] = np.where(f[..., 3] > 0, 90, 0)
                for k, col in enumerate(((255, 60, 60), (60, 220, 60))):
                    g[an[c]['legs'][k]] = (*col, 255)
                g[an[c]['shadow']] = (255, 0, 255, 255)
                g[an[c]['pivot'], :, :] = (0, 0, 255, 255)
                dbg[:, j * FR:(j + 1) * FR] = g
            Image.fromarray(dbg).resize((FR * 4 * 5, FR * 5), Image.NEAREST).save(
                os.path.join(debug, f'seg_{sheet_id}_r{r}.png'))
    return out, outm, report


def process_arrays(a, m, sheet_id, debug=None):
    """API para o rollout.py: (cor, mascara ou None) de 4 poses -> (cor, mascara) com 8 desenhos."""
    mm = m if m is not None else np.zeros_like(a)
    o, om, rep = build(a, mm, sheet_id, debug)
    return o, (om if m is not None else None), rep


def sheet_id_from_path(path):
    """chr_male_base_walk.png -> male_base; chr_female_title_x_walk.png -> female_title_x."""
    n = os.path.basename(path)
    mt = re.match(r'chr_(.+)_walk\.png$', n)
    return mt.group(1) if mt else n


def mask_path_for(path):
    return re.sub(r'_walk\.png$', '_mask_walk.png', path)


def save_tagged(arr, path):
    info = PngImagePlugin.PngInfo()
    info.add_text('walk8', '1')
    Image.fromarray(arr).save(path, pnginfo=info)


def main():
    args = sys.argv[1:]
    out_dir = None; force = False; debug = None; files = []
    i = 0
    while i < len(args):
        if args[i] == '--out':
            out_dir = args[i + 1]; i += 2; continue
        if args[i] == '--debug':
            debug = args[i + 1]; i += 2; continue
        if args[i] == '--force':
            force = True; i += 1; continue
        files.append(args[i]); i += 1
    if debug:
        os.makedirs(debug, exist_ok=True)
    rep = {}
    for f in files:
        sid = sheet_id_from_path(f)
        im = Image.open(f)
        a = np.array(im.convert('RGBA'))
        if not force and (im.text.get('walk8') == '1' if hasattr(im, 'text') else False):
            print(f'pulada (ja tem 8 desenhos): {f}'); continue
        if not force and not is_four_pose(a):
            print(f'pulada (nao segue A A B C D D B C): {f}'); continue
        mp = mask_path_for(f)
        m = np.array(Image.open(mp).convert('RGBA')) if os.path.exists(mp) and mp != f else None
        o, om, r = process_arrays(a, m, sid, debug)
        dst = os.path.join(out_dir, os.path.basename(f)) if out_dir else f
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        save_tagged(o, dst)
        if om is not None:
            save_tagged(om, os.path.join(out_dir, os.path.basename(mp)) if out_dir else mp)
        rep[sid] = r
        res = [f'{k}:{v["reserva"]}' for k, v in r.items() if isinstance(v, dict) and v.get('reserva')]
        print(f'ok {sid}: ' + ' '.join(f'{k}={v}' for k, v in r.items() if k.endswith(':modo') and v != 'legs' or k.endswith(':aviso'))
              + (' reservas: ' + '; '.join(res) if res else ''))
    if debug:
        json.dump(rep, open(os.path.join(debug, 'report.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
