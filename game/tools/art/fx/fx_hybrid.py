"""Brasa no Facao (30/09/2026) — o facao temperado em fogo de vaga-lume do Seu Ze Ferreiro.

Pecas-chave: facao em brasa flutuando ao lado (Lamina Faiscante), corte laranja que deixa brasas no alvo
(Corte em Brasa), rastro de faiscas de esmeril no avanco (Faisca no Aco), bigorna e martelo batendo e o
leque de fagulhas no chao (Fagulhas) e um carvao aceso pulsando no peito (Coracao de Brasa)."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, blit, ease_in, ease_out, layer, lerp, piece, rng
from fxpindorama import (ANVIL_PAL, ANVIL_TXT, D, EMBER_G, EMBER_GROUND, HAMMER_PAL, HAMMER_TXT, STEEL, STEEL_LINE,
                     TAU, W_GOLD, W_PALE, W_WHITE, WOOD, WOOD_LINE, dither_alpha, solid_ramp, spr)
from fx_melee import machete_polys

FEET = (64, 124)
HOT = solid_ramp(["#8c1e12", "#d2421e", "#f4842a", "#fcc84a"])
COAL = solid_ramp(["#1a0e0a", "#3a1a10", "#6a2a14", "#8c3a1a"])


def spark_blade():
    """Lamina Faiscante: facao em brasa (fio laranja-branco) flutuando inclinado ao lado do corpo, soltando
    fagulhas para cima. Em laco (8 s)."""
    frames = []
    r = rng(4000)
    sparks = [(r.uniform(0, 1), r.uniform(-1, 1)) for _ in range(8)]
    for f in range(8):
        fr = Frame(128)
        bob = math.sin(f / 8 * TAU) * 2
        cx, cy, ang = 96, 106 + bob, D(-112)
        blade, handle, edge = machete_polys(cx, cy, ang, 64)
        gv = Canvas(128)  # labaredas lambendo o fio (por tras da lamina)
        for i in range(6):
            u = 0.15 + i * 0.15
            x = cx + math.cos(ang) * 64 * u - math.sin(ang) * 5
            y = cy + math.sin(ang) * 64 * u + math.cos(ang) * 5
            gv.spike(x, y, D(-90) + math.sin(f + i) * 0.3, 0, 10 + 4 * math.sin(f * 1.3 + i), 5, 0.6)
        gv.glow(2.2, 0.9, 0.16)
        fr.paint_canvas(gv, EMBER_G)
        sv = Canvas(128)
        sv.poly(blade, 0.55)
        layer(fr, sv, STEEL, STEEL_LINE)
        cv = Canvas(128)
        cv.stroke(edge, [2.6, 3.0, 1.8], [0.8, 1.0, 0.8])
        layer(fr, cv, HOT, None)
        hv = Canvas(128)
        hv.poly(handle, 0.6)
        layer(fr, hv, WOOD, WOOD_LINE)
        for (p0, sx) in sparks:
            u = (f / 8 + p0) % 1.0
            x = cx + sx * 8 + math.sin(u * 7) * 2
            y = cy - 30 - u * 50
            if u < 0.85:
                fr.twinkle(x, y, 1 if u > 0.4 else 2, "#fff4c8", "#f4842a")
        frames.append(fr)
    piece("hybrid_spark_blade_edge", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


def ember_slash():
    """Corte em Brasa: arco de corte laranja-vermelho com a borda branca, deixando brasas caindo."""
    frames = []
    cx, cy, R = 62, 66, 44
    a0, a1 = D(-150), D(40)
    r = rng(4100)
    embers = [(r.uniform(0, 1), r.uniform(-6, 6)) for _ in range(12)]
    for f in range(9):
        cv = Canvas(128)
        head = ease_out(min(1.0, (f + 1) / 4.0))
        tail = ease_in(min(1.0, max(0.0, (f - 1) / 6.0)))
        v = 1.0 if f < 4 else 1.0 - (f - 3) * 0.16
        n = 30
        if head - tail > 0.01:
            for off, wf, val in ((0.0, 1.0, 0.4), (0.25, 0.55, 0.7), (0.4, 0.25, 1.0)):
                pts, ws, vs = [], [], []
                for i in range(n):
                    u = i / (n - 1)
                    a = lerp(lerp(a0, a1, tail), lerp(a0, a1, head), u)
                    w = 15 * u ** 0.8 * v
                    rr = R + off * w
                    pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
                    ws.append(w * wf)
                    vs.append(val * v * (0.5 + 0.5 * u))
                cv.stroke(pts, ws, vs)
        cv.glow(2.4, 0.9, 0.2 * v)
        fr = Frame(128)
        fr.paint_canvas(cv, EMBER_G)
        if f >= 3:  # brasas caindo do rastro
            for (p0, dx) in embers:
                a = lerp(a0, a1, p0)
                x = cx + math.cos(a) * R + dx
                y = cy + math.sin(a) * R + (f - 3) * 4 + (f - 3) ** 2 * 0.8
                if y < 126:
                    fr.px(int(x), int(y), "#fcc84a" if f < 6 else "#d2421e")
                    fr.px(int(x), int(y) + 1, "#8c1e12")
        frames.append(fr)
    piece("hybrid_ember_cut_slash", frames, pivot=(64, 66), blend="add", plane="billboard", fps=20)
    return frames


def steel_spark_trail():
    """Faisca no Aco: chuveiro de faiscas de esmeril (riscos laranja que caem em arco) no chao do avanco."""
    frames = []
    r = rng(4200)
    for f in range(7):
        fr = Frame(96)
        cv = Canvas(96)
        v = 1.0 if f < 3 else 1 - (f - 2) * 0.2
        rr = rng(4200)
        for k in range(12):
            a = D(-90) + rr.uniform(-1.3, 1.3)
            sp = rr.uniform(26, 52)
            t = (f + 1) / 7
            x0 = 48 + math.cos(a) * sp * t
            y0 = 86 + math.sin(a) * sp * t + 30 * t * t
            x1 = 48 + math.cos(a) * sp * (t - 0.12)
            y1 = 86 + math.sin(a) * sp * (t - 0.12) + 30 * (t - 0.12) ** 2
            cv.stroke([(x1, y1), (x0, y0)], [0.6, 2.6], [0.5 * v, 1.0 * v])
        cv.glow(1.6, 0.9, 0.14 * v)
        fr.paint_canvas(cv, EMBER_G)
        frames.append(fr)
    _ = r
    piece("hybrid_steel_spark_trail", frames, pivot=(48, 88), blend="add", plane="billboard", fps=16)
    return frames


def steel_spark_impact():
    """Impacto da Faisca no Aco: estouro de fagulhas com gotinhas de metal derretido escorrendo."""
    frames = []
    r = rng(4300)
    drops = [(r.uniform(0, TAU), r.uniform(14, 30)) for _ in range(10)]
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 3 else 1 - (f - 2) * 0.17
        if f < 3:
            cv.circle(64, 64, [12, 16, 9][f], 1.0)
            cv.circle(64, 64, [18, 22, 14][f], 0.5)
        for k in range(16):
            a = k * TAU / 16 + (k % 3) * 0.1
            ln = (20 + (k % 4) * 8) * ease_out(min(1, (f + 1) / 3))
            cv.spike(64, 64, a, 6 + f * 3, 6 + f * 3 + ln, 2.4 * v, 0.8 * v)
        cv.glow(2.2, 0.9, 0.18 * v)
        fr.paint_canvas(cv, EMBER_G)
        for (a, sp) in drops:
            d = sp * min(1, f / 3)
            x, y = 64 + math.cos(a) * d, 64 + math.sin(a) * d + max(0, f - 2) ** 2 * 1.4
            fr.px(int(x), int(y), "#fff4c8")
            fr.px(int(x), int(y) + 1, "#f4842a")
            fr.px(int(x), int(y) + 2, "#8c1e12")
        frames.append(fr)
    piece("hybrid_steel_spark_impact", frames, pivot=(64, 64), blend="add", plane="billboard", fps=16)
    return frames


def anvil_strike():
    """Fagulhas: bigorna surge na frente do ferreiro, o martelo desce e bate (TAN), fagulhas pulam."""
    frames = []
    anvil = spr(ANVIL_TXT, ANVIL_PAL, "#120e14").scale(2)
    hammer = spr(HAMMER_TXT, HAMMER_PAL, "#120e14").scale(2)
    angs = [70, 60, 40, 0, -8, -8, 20, 40, 50, 55]
    for f in range(10):
        fr = Frame(128)
        a = 1.0 if f < 8 else 0.5
        blit(fr, anvil, 64, 120, (0.5, 1.0), alpha=a)
        h = hammer.rot(angs[f])
        blit(fr, h, 76 + angs[f] * 0.25, 76 - (angs[f] > 20) * 10, (0.5, 0.5), alpha=a)
        if f in (3, 4, 5):
            cv = Canvas(128)
            for k in range(9):
                an = D(-180) + k * D(180) / 8
                ln = [18, 30, 22][f - 3]
                cv.spike(62, 96, an, 4, ln + (k % 2) * 8, 3.0, 0.9)
            cv.circle(62, 96, [8, 5, 3][f - 3], 1.0)
            cv.glow(2.0, 0.9, 0.2)
            layer(fr, cv, EMBER_G)
        frames.append(fr)
    piece("hybrid_sparks_anvil", frames, pivot=FEET, blend="mix", plane="billboard", fps=14)
    return frames


def sparks_ground():
    """Fagulhas no chao (deitado, raio 3 = 88 px): leque de fagulhas correndo para fora e riscos de brasa
    ficando no chao."""
    frames = []
    c = 96
    r = rng(4400)
    rays = [(k * TAU / 22 + r.uniform(-0.1, 0.1), r.uniform(0.7, 1.0)) for k in range(22)]
    for f in range(9):
        fr = Frame(192)
        cv = Canvas(192)
        v = 1.0 if f < 5 else 1 - (f - 4) * 0.22
        t = ease_out(min(1, (f + 1) / 5))
        for (a, ln) in rays:
            d1 = 88 * ln * t
            d0 = max(10, d1 - 26)
            cv.stroke([(c + math.cos(a) * d0, c + math.sin(a) * d0), (c + math.cos(a) * d1, c + math.sin(a) * d1)],
                      [0.6, 2.8 * v], [0.4 * v, 1.0 * v])
            cv.stroke([(c + math.cos(a) * 10, c + math.sin(a) * 10), (c + math.cos(a) * d0, c + math.sin(a) * d0)],
                      [0.5, 1.0], [0.2 * v, 0.3 * v])
        if f < 3:
            cv.circle(c, c, [14, 18, 10][f], 1.0)
        cv.glow(2.4, 0.9, 0.14 * v)
        fr.paint_canvas(cv, EMBER_GROUND)
        frames.append(fr)
    piece("hybrid_sparks_ground", frames, pivot=(96, 96), blend="add", plane="flat", fps=16, texel=3.0 / 88.0)
    return frames


def ember_heart():
    """Coracao de Brasa: um carvao aceso no peito, rachaduras pulsando laranja e fagulhas subindo — nada de
    simbolo de coracao, e um pedaco de carvao do fogo do ferreiro."""
    frames = []
    r = rng(4500)
    cracks = []
    for k in range(5):
        a = k * TAU / 5 + r.uniform(-0.3, 0.3)
        cracks.append([(64 + math.cos(a) * d + r.uniform(-1, 1), 80 + math.sin(a) * d * 0.8) for d in (1, 5, 9, 12)])
    for f in range(8):
        fr = Frame(128)
        pul = 0.5 + 0.5 * math.sin(f / 8 * TAU)
        cv = Canvas(128)
        cv.poly([(52, 76), (58, 68), (70, 67), (77, 74), (76, 86), (66, 93), (54, 90), (50, 83)], 0.6)
        cv.poly([(56, 72), (66, 70), (60, 76)], 0.85)
        layer(fr, cv, COAL, "#0a0404")
        hv = Canvas(128)
        for pts in cracks:
            hv.stroke(pts, [1.8, 1.4, 1.0, 0.6], [0.6 + 0.4 * pul] * 4)
        layer(fr, hv, HOT, None)
        for k in range(6):  # lingua de fogo curta saindo das bordas do carvao
            a = D(-150) + k * D(24)
            ln = 5 + 4 * pul + (k % 2) * 3
            x, y = 64 + math.cos(a) * 12, 80 + math.sin(a) * 10
            for i in range(int(ln)):
                fr.px(int(x + math.cos(a) * i * 0.4), int(y - i), "#fcc84a" if i < ln * 0.5 else "#d2421e")
        for k in range(4):
            u = (f / 8 + k / 4) % 1.0
            fr.twinkle(64 + (k - 1.5) * 9 + math.sin(u * 6) * 2, 64 - u * 40, 1 if u > 0.5 else 2, "#fff4c8", "#f4842a")
        frames.append(fr)
    piece("hybrid_ember_heart_core", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


ALL = [spark_blade, ember_slash, steel_spark_trail, steel_spark_impact, anvil_strike, sparks_ground, ember_heart]
_ = (STEEL, STEEL_LINE, W_GOLD, W_PALE, W_WHITE, dither_alpha)
