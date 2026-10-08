"""Suporte da Terra de Pindorama (30/09/2026) — a raizeira Vo Aninha: Raiz do Cerrado, Seiva do Buriti e o
debuff do Assobio da Matinta.

Pecas-chave: garrafada derramando e o chao de ervas, cuia de cha fumegando, folhas enrolando como emplastro,
copa de pequizeiro com os frutos fazendo sombra, bandeirinhas de mutirao, folha larga descendo, coco verde
de canudinho derramando, seiva ambar escorrendo, raizes grossas segurando o aliado, sopro com leque de folha
de buriti. Matinta: penas pretas em cone de assobio, passarinho agourento rodando na cabeca, rasga-mortalha
mergulhando com o grito no chao, visgo grudento e fumaca amarga rolando."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Spr, blit, ease_in, ease_out, layer, lerp, piece, rng
from fxpindorama import (BIRD_DOWN, BIRD_PAL, BIRD_UP, BITTER, BITTER_LINE, BOTTLE_PAL, BOTTLE_TXT, COCO_PAL, COCO_TXT,
                     CUIA_PAL, CUIA_TXT, D, FEATHER_DARK, FEATHER_WHITE, GOO, GOO_LINE, LEAF, LEAF_G, LEAF_LINE,
                     LEAFLET_PAL, LEAFLET_TXT, MANA_G, MATINTA_G, MATINTA_GROUND, OWL_PAL, OWL_TXT, PEQUI_PAL,
                     PEQUI_TXT, SAP_G, SMOKE, SMOKE_LINE, TAU, W_GOLD, W_WHITE, WATER_G, WOOD, WOOD_LINE,
                     dither_alpha, drop, feather, flag, glow_ramp, leaf, leaf_poly, puff, solid_ramp, spr)

FEET = (64, 124)
HERB_GROUND = glow_ramp(["#10240e", "#2f6b3e", "#5aa048", "#a6d86a", "#e0f8b0", "#ffffff"],
                        [40, 140, 230, 255, 255, 255])
ROOT = solid_ramp(["#3a2418", "#6b4226", "#9c6a3c", "#c9985e"])
SAP_SOLID = solid_ramp(["#7a4a12", "#c8801e", "#f0b640", "#fae58c"])


# ------------------------------------------------------------------ Raiz do Cerrado
def bottle_brew():
    """Garrafada: a garrafa de ervas aparece no alto, inclina e derrama um fio verde que respinga no chao."""
    frames = []
    bt = spr(BOTTLE_TXT, BOTTLE_PAL, "#12261a").scale(2)
    tilt = [0, 0, 20, 60, 110, 120, 120, 120, 110, 90, 60, 30]
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        if 4 <= f <= 9:  # fio de garrafada caindo e respingando
            y0 = 48
            cv.stroke([(76, y0), (74, 70), (72, 110)], [4.0, 3.2, 2.6], [0.62, 0.62, 0.62])
            cv.stroke([(76, y0), (74, 70), (72, 110)], [1.4, 1.2, 1.0], [0.9, 0.9, 0.9])
            for k in range(5):
                a = D(-160) + k * D(35)
                d = 6 + (f % 3) * 3
                cv.circle(72 + math.cos(a) * d * 1.6, 116 + math.sin(a) * d * 0.5, 2.0, 0.7)
            cv.ellipse(72, 118, 16, 4, 0.4)
        cv.glow(1.8, 0.9, 0.14)
        fr.paint_canvas(cv, LEAF_G)
        a = 1.0 if f < 10 else 0.5
        blit(fr, bt.rot(-tilt[f]), 62, 38, alpha=a)
        frames.append(fr)
    piece("support_bottle_brew_bottle", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def bottle_ground():
    """Chao da Garrafada (deitado, raio 4 = 88 px): poca de ervas com folhas boiando, bolhinhas e fiapos de
    vapor verde; em laco pelos 10 s."""
    frames = []
    c = 96
    r = rng(5000)
    leaves = [(r.uniform(0, TAU), 88 * math.sqrt(r.uniform(0.05, 0.9)), r.uniform(0, TAU), r.uniform(8, 13))
              for _ in range(16)]
    for f in range(8):
        fr = Frame(192)
        cv = Canvas(192)
        ph = f / 8 * TAU
        dx, dy = cv.X - c, cv.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        edge = 84 + 4 * np.sin(6 * a + ph * 0.5) + 3 * np.sin(11 * a - ph)
        cv.put((d < edge).astype(np.float32), 0.06)
        cv.put(((np.abs(d - edge) < 2.0) & (np.sin(a * 14 + ph) > -0.4)).astype(np.float32), 0.3)
        for (la, lr, rot, ln) in leaves:  # folhas boiando (giram devagar)
            x, y = c + math.cos(la) * lr, c + math.sin(la) * lr
            cv.poly(leaf_poly(x, y, rot + ph * 0.1, ln, ln * 0.5), 0.55)
        for k in range(10):  # bolhinhas
            u = (f / 8 + k / 10) % 1.0
            bx, by = c + math.cos(k * 2.4) * 60 * (k % 3 + 1) / 3, c + math.sin(k * 2.4) * 60 * (k % 3 + 1) / 3
            cv.circle(bx, by, 1.5 + u * 2.5, 0.8 * (1 - u) + 0.2)
        cv.glow(2.4, 0.8, 0.1)
        fr.paint_canvas(cv, HERB_GROUND)
        frames.append(fr)
    piece("support_bottle_brew_ground", frames, pivot=(96, 96), blend="add", plane="flat", fps=8, loop=True,
          texel=4.0 / 88.0)
    return frames


def herb_tea():
    """Cha de Erva: a cuia de cha de erva aparece sobre o aliado, fumegando (vapor verde em espiral) e
    derrama um gole de luz verde para baixo."""
    frames = []
    cu = spr(CUIA_TXT, CUIA_PAL, "#1e120a").scale(2)
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        for k in range(3):  # vapor em fitas
            pts = [(52 + k * 12 + math.sin(i * 0.8 + f * 0.7 + k) * 4, 26 - i * 3) for i in range(8)]
            cv.stroke(pts, [3.0 - i * 0.3 for i in range(8)], [0.6 - i * 0.05 for i in range(8)])
        if f >= 6:
            u = (f - 6) / 5
            cv.stroke([(64, 44), (64, 44 + u * 70)], [5 * (1 - u) + 1, 2], [0.8, 0.5])
        cv.glow(2.0, 0.9, 0.14)
        fr.paint_canvas(cv, LEAF_G)
        k = [0.3, 0.7, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1][f]
        blit(fr, cu.squash(k, k), 64, 36, alpha=1.0 if f < 10 else 0.5)
        frames.append(fr)
    piece("support_herb_tea_cup", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def poultice():
    """Emplastro: uma faixa de folhas largas se enrola na cintura do aliado (como atadura), aperta e brilha
    verde; depois as folhas se soltam levando fiapos escuros (os efeitos negativos) embora."""
    frames = []
    lf = leaf().squash(0.8, 0.8)
    for f in range(12):
        fr = Frame(128)
        t = f / 11
        wrap = min(1.0, t / 0.45)          # quanto da volta ja foi coberto
        leave = max(0.0, (t - 0.65) / 0.35)  # soltando
        cy = 84
        n = 9
        back_, front_ = [], []
        for k in range(n):
            u = k / n
            if u > wrap:
                continue
            a = u * TAU + D(-90)
            x = 64 + math.cos(a) * 26 * (1 + leave * 1.2)
            y = cy + math.sin(a) * 7 - leave * 40 * (0.5 + 0.5 * math.sin(k))
            sp = lf.rot(-math.degrees(a) + 90 + leave * 120 * (1 if k % 2 else -1))
            (front_ if math.sin(a) > 0 else back_).append((x, y, sp))
        for x, y, sp in back_:
            blit(fr, sp, x, y, alpha=0.75 if leave < 0.5 else 0.5)
        cv = Canvas(128)
        if 0.35 < t < 0.75:  # aperto: brilho verde na faixa
            cv.ellipse(64, cy, 30, 9, 0.35)
            cv.ellipse(64, cy, 22, 5, 0.7)
            cv.glow(2.0, 0.9, 0.14)
            fr.paint_canvas(cv, LEAF_G)
        for x, y, sp in front_:
            blit(fr, sp, x, y, alpha=1.0 if leave < 0.5 else 0.5)
        if leave > 0:  # fiapos escuros subindo e sumindo
            dv = Canvas(128)
            for k in range(5):
                x0 = 44 + k * 10
                pts = [(x0 + math.sin(i + k) * 3, cy - 6 - leave * 34 - i * 5) for i in range(5)]
                dv.stroke(pts, [2.6, 2.2, 1.6, 1.0, 0.5], [0.75 * (1 - leave) + 0.1] * 5)
            layer(fr, dv, MATINTA_G)
        frames.append(fr)
    piece("support_poultice_wrap", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def pequi_shade():
    """Sombra de Pequizeiro: uma copa de pequizeiro (folhas em cacho, pequis amarelos) paira sobre o aliado e
    faz sombra fresca; folhas balancam. Em laco (6 s)."""
    frames = []
    pq = spr(PEQUI_TXT, PEQUI_PAL, "#2e3a0a")
    r = rng(5100)
    tufts = [(r.uniform(-40, 40), r.uniform(-12, 10), r.uniform(0, TAU)) for _ in range(28)]
    for f in range(8):
        fr = Frame(128)
        ph = f / 8 * TAU
        sv = Canvas(128)  # sombra no chao (pontilhada, nao um disco liso)
        sv.ellipse(64, 120, 38, 7, 0.5)
        sv.noise_erode(0.3, seed=5110)
        from fxpindorama import SHADOW
        fr.paint_canvas(sv, SHADOW)
        cv = Canvas(128)
        for (dx, dy, p) in sorted(tufts, key=lambda t: t[1]):
            sway = math.sin(ph + p) * 1.5
            x, y = 64 + dx + sway, 30 + dy + abs(dx) * 0.2
            for k in range(3):
                a = D(-90) + (k - 1) * D(50) + p * 0.2
                cv.poly(leaf_poly(x, y, a, 11, 5.5), 0.45 + 0.15 * k)
        cv.stroke([(64, 50), (64, 36)], [4, 3], [0.3, 0.3])
        layer(fr, cv, LEAF, LEAF_LINE)
        for k, (dx, dy) in enumerate(((-24, 34), (-6, 42), (14, 38), (30, 30), (4, 26))):
            blit(fr, pq, 64 + dx + math.sin(ph + k) * 1.5, dy + (1 if (f + k) % 4 == 0 else 0))
        frames.append(fr)
    piece("support_pequi_shade_tree", frames, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return frames


def mutirao_flags():
    """Mutirao: cordao de bandeirinhas coloridas de festa girando sobre o grupo (o trabalho junto vira festa),
    com fitas balancando. Em pe sobre o conjurador."""
    frames = []
    cols = ["#e8483a", "#fae58c", "#5aa048", "#5a90e0", "#e07aa0", "#f4842a"]
    flags = [flag(c) for c in cols]
    for f in range(8):
        fr = Frame(160, 96)
        ph = f / 8 * TAU / 6
        items = []
        n = 12
        for k in range(n):
            a = k * TAU / n + ph
            x = 80 + math.cos(a) * 64
            y = 40 + math.sin(a) * 14 + math.sin(a * 2 + f) * 1.0
            items.append((math.sin(a), x, y, k))
        pts = sorted(items, key=lambda t: t[3])
        for i in range(n):  # cordao
            _, x0, y0, _ = pts[i]
            _, x1, y1, _ = pts[(i + 1) % n]
            for j in range(9):
                u = j / 8
                fr.px(int(lerp(x0, x1, u)), int(lerp(y0, y1, u) + math.sin(u * math.pi) * 3), "#6b4226")
        for depth, x, y, k in sorted(items):
            blit(fr, flags[k % len(flags)].scale(2), x, y + 1, (0.5, 0.0), alpha=1.0 if depth > -0.3 else 0.75)
        frames.append(fr)
    piece("support_mutirao_flags", frames, pivot=(80, 92), blend="mix", plane="billboard", fps=10, loop=True)
    return frames


# ------------------------------------------------------------------ Seiva do Buriti
def broadleaf_tea():
    """Cha de Folha Larga: uma folha larga desce balancando sobre o aliado, se curva e pinga orvalho verde que
    cura; gotas sobem no fim."""
    frames = []
    lf = leaf().scale(2)
    dp = drop("#e0f8b0", "#8ccc5a", "#3e8a3c")
    for f in range(12):
        fr = Frame(128)
        t = f / 11
        y = lerp(4, 30, ease_out(min(1, t * 1.5)))
        sway = math.sin(t * 7) * 10 * (1 - t)
        blit(fr, lf.rot(sway + 90).squash(1.0, 0.7), 64 + sway * 0.8, y + 18, alpha=1.0 if f < 10 else 0.5)
        if f >= 4:
            for k in range(4):
                u = ((f - 4) / 7 + k / 4) % 1.0
                blit(fr, dp, 48 + k * 10, 44 + u * 70, alpha=1.0 if u < 0.7 else 0.5)
        frames.append(fr)
    piece("support_broadleaf_tea_leaf", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def coconut():
    """Agua de Coco: coco verde de canudinho aparece sobre a Vo, vira e derrama agua fresca que cai em
    respingos."""
    frames = []
    cc = spr(COCO_TXT, COCO_PAL, "#12261a").scale(2)
    tilt = [0, 0, 0, 30, 90, 150, 170, 170, 150, 100, 50, 20]
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        if 5 <= f <= 9:
            cv.stroke([(64, 44), (62, 80), (60, 116)], [9, 7, 6], [0.5, 0.5, 0.5])
            cv.stroke([(64, 44), (62, 80), (60, 116)], [3, 2.4, 2], [0.95, 0.95, 0.95])
        cv.glow(1.8, 0.9, 0.14)
        fr.paint_canvas(cv, WATER_G)
        blit(fr, cc.rot(-tilt[f]), 64, 30, alpha=1.0 if f < 10 else 0.5)
        frames.append(fr)
    piece("support_coconut_water_coco", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def coconut_splash():
    """Respingo de agua de coco no chao (deitado, raio 6 = 132 px): coroa de gotas correndo para fora."""
    frames = []
    c = 144
    r = rng(5200)
    drops_ = [(r.uniform(0, TAU), r.uniform(0.5, 1.0), r.uniform(2.5, 5)) for _ in range(40)]
    for f in range(9):
        fr = Frame(288)
        cv = Canvas(288)
        t = ease_out(min(1, (f + 1) / 6))
        v = 1.0 if f < 6 else 1 - (f - 5) * 0.25
        for (a, sp, sz) in drops_:
            d = 132 * sp * t
            x, y = c + math.cos(a) * d, c + math.sin(a) * d
            cv.circle(x, y, sz * v + 0.5, 0.6 * v)
            cv.stroke([(c + math.cos(a) * d * 0.8, c + math.sin(a) * d * 0.8), (x, y)], [0.4, sz * 0.8],
                      [0.2 * v, 0.5 * v])
        if f < 3:
            cv.circle(c, c, [20, 26, 16][f], 0.8)
        cv.glow(2.4, 0.9, 0.1 * v)
        fr.paint_canvas(cv, WATER_G)
        frames.append(fr)
    piece("support_coconut_water_splash", frames, pivot=(144, 144), blend="add", plane="flat", fps=14,
          texel=6.0 / 132.0)
    return frames


def running_sap():
    """Seiva que Corre: fios de seiva ambar do buriti escorrendo devagar em volta do aliado, com gotas
    douradas. Em laco (12 s)."""
    frames = []
    dp = drop("#fae58c", "#f0b640", "#c8801e")
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        for k in range(6):
            x = 64 + (k - 2.5) * 13
            top = 40 + (k % 3) * 8
            u = (f / 8 + k / 6) % 1.0
            cv.stroke([(x, top), (x + math.sin(k) * 2, top + 20 + u * 40)], [3.0, 2.0], [0.62, 0.62])
            cv.circle(x + math.sin(k) * 2, top + 22 + u * 40, 3.0, 0.8)
        layer(fr, cv, SAP_SOLID, "#3a2408")
        for k in range(3):
            u = (f / 8 + k / 3) % 1.0
            blit(fr, dp, 44 + k * 20, 96 + u * 22, alpha=1.0 if u < 0.6 else 0.5)
        fr.twinkle(64 + math.sin(f) * 20, 50 + (f % 4) * 10, 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("support_running_sap_flow", frames, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return frames


def holding_root():
    """Raiz que Segura: raizes grossas com veios dourados sobem do chao e abracam as pernas do aliado (nao
    deixa cair). _back e _front, em laco (3 s)."""
    back, front = [], []
    for f in range(8):
        glow = 0.5 + 0.5 * math.sin(f / 8 * TAU)
        for part, dst in (("back", back), ("front", front)):
            fr = Frame(128)
            cv = Canvas(128)
            gv = Canvas(128)
            for k in range(4):
                a0 = k * TAU / 4 + 0.4
                segs = []
                for i in range(24):
                    t = i / 23
                    a = a0 + t * 1.1 * TAU
                    rr = lerp(30, 16, t)
                    segs.append((64 + math.cos(a) * rr, 122 + math.sin(a) * rr * 0.3 - t * 64, math.sin(a) > 0, t))
                for i in range(23):
                    x0, y0, fr0, t0 = segs[i]
                    x1, y1, _, _ = segs[i + 1]
                    if fr0 != (part == "front"):
                        continue
                    w = lerp(9, 3, t0)
                    cv.stroke([(x0, y0), (x1, y1)], [w, w], [0.55, 0.55])
                    gv.stroke([(x0, y0), (x1, y1)], [1.2, 1.2], [0.4 + 0.5 * glow] * 2)
            layer(fr, cv, ROOT, WOOD_LINE)
            gv.glow(1.4, 0.9, 0.2)
            layer(fr, gv, SAP_G)
            dst.append(fr)
    piece("support_holding_root_back", back, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    piece("support_holding_root_front", front, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return back, front


BURITI_TXT = """
g.........g.........g
.g........g........g.
..g.......g.......g..
...g......g......g...
.g..g.....g.....g..g.
..g..g....g....g..g..
...g..g...g...g..g...
g...g..g..g..g..g...g
.g...g..g.g.g..g...g.
..gg..g..ggg..g..gg..
....gg.gggggggg.gg...
......ggGGGGGGgg.....
.........GGG.........
..........b..........
..........b..........
..........b..........
"""


def new_breath():
    """Folego Novo: uma folha de buriti (leque) abana ao lado do aliado e o sopro sai em duas rajadas de vento
    azul-esverdeado que passam pelo corpo, levando folhinhas e gotas de mana para cima."""
    frames = []
    fan = spr(BURITI_TXT, {"g": "#5aa048", "G": "#2f6b3e", "b": "#9c6a3c"}, "#12261a").scale(2)
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    dp = drop("#d2e8ff", "#84b8f6", "#3a78de")
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        t = f / 11
        for k in range(2):  # rajadas: faixas curvas que saem do leque e sobem cruzando o corpo
            u0 = min(1.0, max(0.0, t * 1.6 - k * 0.25))
            if u0 <= 0:
                continue
            pts = []
            for i in range(12):
                u = i / 11 * u0
                x = 104 - u * 76
                y = 70 - k * 18 - math.sin(u * math.pi) * 22 - u * 20
                pts.append((x, y))
            fade = 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.3
            cv.stroke(pts, [0.5 + 3.5 * (i / 11) for i in range(12)], [0.75 * fade] * 12)
        cv.glow(1.8, 0.9, 0.12)
        fr.paint_canvas(cv, MANA_G)
        ang = math.sin(t * TAU * 1.5) * 28
        blit(fr, fan.rot(ang), 108, 86, (0.5, 0.9), alpha=1.0 if f < 10 else 0.5)
        for k in range(3):
            u = min(1.0, max(0.0, t * 1.4 - k * 0.15))
            blit(fr, lf.rot(u * 300 + k * 60), 96 - u * 70, 70 - k * 12 - u * 50, alpha=1.0 if u < 0.8 else 0.5)
        if f >= 5:
            for k in range(3):
                u = (f - 5) / 6
                blit(fr, dp, 48 + k * 14, 60 - u * 40 - k * 6, alpha=1.0 if u < 0.7 else 0.5)
        frames.append(fr)
    piece("support_new_breath_wind", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


# ------------------------------------------------------------------ Assobio da Matinta
def ill_whistle_cone():
    """Assobio Agourento (cone 90 graus, 4 cel = 150 px): vento roxo-escuro em fitas onduladas saindo da boca,
    penas pretas voando pelo cone."""
    frames = []
    size = 192
    ox, oy = size // 2, size - 8
    a0, a1 = D(-135), D(-45)
    fe = feather(FEATHER_DARK)
    r = rng(5300)
    feathers = [(r.uniform(a0 + 0.1, a1 - 0.1), r.uniform(0.2, 0.9), r.uniform(0, 360)) for _ in range(12)]
    for f in range(9):
        fr = Frame(size)
        cv = Canvas(size)
        t = ease_out(min(1, (f + 1) / 6))
        v = 1.0 if f < 6 else 1 - (f - 5) * 0.28
        for k in range(5):  # fitas de assobio onduladas
            a = lerp(a0, a1, (k + 0.5) / 5)
            pts = []
            for i in range(14):
                u = i / 13 * t
                d = 150 * u
                wob = math.sin(u * 14 - f * 1.2 + k) * 6 * u
                pts.append((ox + math.cos(a) * d - math.sin(a) * wob, oy + math.sin(a) * d + math.cos(a) * wob))
            cv.stroke(pts, [0.5 + 2.8 * (i / 13) for i in range(14)], [0.7 * v] * 14)
        cv.glow(2.4, 0.9, 0.12 * v)
        fr.paint_canvas(cv, MATINTA_GROUND)
        for (a, d, rot) in feathers:
            dd = 150 * d * t
            if dd > 10:
                blit(fr, fe.rot(rot + f * 30), ox + math.cos(a) * dd, oy + math.sin(a) * dd,
                     alpha=1.0 if f < 7 else 0.5)
        frames.append(fr)
    piece("support_ill_whistle_cone", frames, pivot=(ox, oy), blend="mix", plane="flat", fps=14,
          texel=4.0 / 150.0)
    return frames


def omen_bird():
    """Agouro: passarinho preto de olho vermelho voando em roda sobre a cabeca do alvo, batendo as asas.
    Em laco (10 s)."""
    frames = []
    up = spr(BIRD_UP, BIRD_PAL, "#0a0610").scale(2)
    dn = spr(BIRD_DOWN, BIRD_PAL, "#0a0610").scale(2)
    fe = feather(FEATHER_DARK)
    for f in range(8):
        fr = Frame(96)
        a = f / 8 * TAU
        x = 48 + math.cos(a) * 26
        y = 30 + math.sin(a) * 6
        b = up if f % 2 == 0 else dn
        blit(fr, b if math.cos(a + math.pi / 2) > 0 else b.flip(), x, y)
        u = (f % 4) / 4
        blit(fr, fe.rot(40 + f * 20), 48 + math.cos(a - 1.5) * 20, 44 + u * 30, alpha=1.0 if u < 0.5 else 0.5)
        frames.append(fr)
    piece("support_omen_bird", frames, pivot=(48, 90), blend="mix", plane="billboard", fps=10, loop=True)
    return frames


def owl_cry():
    """Pio da Rasga-Mortalha: a coruja branca mergulha de asas abertas sobre o ponto e grita (em pe)."""
    frames = []
    owl = spr(OWL_TXT, OWL_PAL, "#1a1418").scale(2)
    for f in range(10):
        fr = Frame(128)
        t = f / 9
        y = lerp(40, 88, ease_in(min(1, t * 1.6)))
        k = 1.0 if f % 2 == 0 else 0.9
        a = 1.0 if f < 8 else 0.5
        blit(fr, owl.squash(1.0, k), 64, y, (0.5, 0.5), alpha=a)
        if f >= 5:  # grito: tres tracos saindo do bico
            for sd in (-1, 0, 1):
                for i in range(6):
                    fr.px(int(64 + sd * (10 + i * 2)), int(y + 14 + i * (1 if sd else 1.2) + abs(sd) * 2),
                          "#fffcf0" if i < 4 else "#8a7e6c")
        frames.append(fr)
    piece("support_owl_cry_owl", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def owl_ground():
    """Grito no chao (deitado, raio 3 = 88 px): ondas palidas quebradas saindo do centro e penas brancas
    caindo girando."""
    frames = []
    c = 96
    fw = feather(FEATHER_WHITE)
    r = rng(5400)
    feathers = [(r.uniform(0, TAU), r.uniform(20, 80), r.uniform(0, 360)) for _ in range(12)]
    for f in range(10):
        fr = Frame(192)
        cv = Canvas(192)
        v = 1.0 if f < 6 else 1 - (f - 5) * 0.22
        dx, dy = cv.X - c, cv.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        rr0 = rng(5410)
        for k in range(18):  # riscos do grito correndo para fora (nada de aros)
            an = k * TAU / 18 + rr0.uniform(-0.12, 0.12)
            d1 = 20 + ((f * 9 + k * 7) % 70)
            cv.stroke([(c + math.cos(an) * (d1 - 12), c + math.sin(an) * (d1 - 12)),
                       (c + math.cos(an) * d1, c + math.sin(an) * d1)], [0.5, 2.6], [0.3 * v, 0.8 * v])
        cv.glow(2.0, 0.9, 0.1 * v)
        fr.paint_canvas(cv, MATINTA_GROUND)
        for (fa, fr_, rot) in feathers:
            if f >= 2:
                blit(fr, fw.rot(rot + f * 25), c + math.cos(fa) * fr_, c + math.sin(fa) * fr_,
                     alpha=1.0 if f < 8 else 0.5)
        frames.append(fr)
    piece("support_owl_cry_ground", frames, pivot=(96, 96), blend="mix", plane="flat", fps=12, texel=3.0 / 88.0)
    return frames


def bird_lime_blob():
    """Visgo: bolota de visgo amarelo-esverdeado voando (para +x), deformando e pingando."""
    frames = []
    for f in range(4):
        fr = Frame(64, 32)
        cv = Canvas(64, 32)
        sq = [1.0, 1.15, 1.0, 0.9][f]
        cv.ellipse(42, 16, 10 * sq, 8 / sq, 0.55)
        cv.ellipse(45, 13, 4, 3, 0.9)
        cv.stroke([(32, 16), (18, 17), (10, 19)], [5, 2.5, 0.8], [0.55, 0.55, 0.55])
        layer(fr, cv, GOO, GOO_LINE)
        frames.append(fr)
    piece("support_bird_lime_blob", frames, pivot=(46, 16), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def bird_lime_glue():
    """Visgo grudado: bolota de visgo nos pes do alvo, com fios esticando ate o chao e bolhas. Em laco (3 s)."""
    frames = []
    for f in range(8):
        fr = Frame(96)
        cv = Canvas(96)
        ph = f / 8 * TAU
        cv.ellipse(48, 86, 28, 8, 0.5)
        cv.ellipse(44, 84, 16, 4, 0.8)
        for k in range(5):  # fios de visgo subindo nas pernas
            x = 34 + k * 7
            h = 20 + 8 * math.sin(ph + k)
            cv.stroke([(x, 86), (x + math.sin(k) * 2, 86 - h)], [4.0, 1.4], [0.55, 0.55])
            cv.circle(x + math.sin(k) * 2, 86 - h, 2.4, 0.62)
        for k in range(3):
            u = ((f + k * 3) % 8) / 8
            cv.circle(40 + k * 9, 86 - u * 4, 1.5 + u * 2, 0.85)
        layer(fr, cv, GOO, GOO_LINE)
        frames.append(fr)
    piece("support_bird_lime_glue", frames, pivot=(48, 90), blend="mix", plane="billboard", fps=8, loop=True)
    return frames


def bitter_smoke():
    """Fumaca Amarga: rolo de fumaca verde-acinzentada rolando baixo no chao (espalhado pela area), com
    gotinhas amargas. Em laco (6 s)."""
    frames = []
    for f in range(8):
        fr = Frame(96)
        cv = Canvas(96)
        ph = f / 8 * TAU
        for k in range(4):
            x = 48 + (k - 1.5) * 16 + math.sin(ph + k) * 3
            y = 76 - (k % 2) * 8 + math.cos(ph + k * 1.3) * 2
            puff(cv, x, y, 13 + 2 * math.sin(ph * 2 + k), 0.3, 0.55, 0.8)
        for k in range(2):
            u = (f / 8 + k / 2) % 1.0
            puff(cv, 40 + k * 18, 56 - u * 30, 8 * (1 - u) + 2, 0.3, 0.55, 0.8)
        cv.noise_erode(0.08, seed=5500 + f)
        layer(fr, cv, BITTER, BITTER_LINE)
        for k in range(3):
            x = 30 + k * 18
            fr.px(x, int(84 - ((f + k * 3) % 8) * 3), "#c8d08a")
        frames.append(fr)
    piece("support_bitter_smoke_cloud", frames, pivot=(48, 90), blend="mix", plane="billboard", fps=8, loop=True)
    return frames


ALL = [bottle_brew, bottle_ground, herb_tea, poultice, pequi_shade, mutirao_flags, broadleaf_tea, coconut,
       coconut_splash, running_sap, holding_root, new_breath, ill_whistle_cone, omen_bird, owl_cry, owl_ground,
       bird_lime_blob, bird_lime_glue, bitter_smoke]
_ = (Spr, SMOKE, SMOKE_LINE, WOOD, LEAFLET_PAL, LEAFLET_TXT, MATINTA_G)
