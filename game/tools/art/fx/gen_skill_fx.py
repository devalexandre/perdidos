#!/usr/bin/env python3
"""Gera as folhas dos efeitos de skill (docs/briefing-sprites-personagem.md §4).

  python3 game/tools/art/fx/gen_skill_fx.py [--preview .work/fx]

Saida: game/assets/fx/skills/<skill>_<peca>.png (quadros em linha, fundo transparente), os .import
(sem compressao, sem mipmaps) e a tabela game/scripts/client/combat/skill_fx_sheets.gd (quadros, pivo,
blend, plano, fps) lida pelo SkillFx. Tudo desenhado aqui, por script — nenhuma imagem de entrada.

Convencoes das pecas:
  - "billboard": em pe, virada para a camera. Projeteis desenhados voando para a DIREITA (+x): o
    SkillFx gira o quadro na direcao do voo na tela.
  - "flat": deitada no chao, vista de cima; "para cima" na imagem = para a frente (direcao do lancamento).
  - pivo = ponto da imagem que fica na posicao do efeito (pes, centro, conjurador...).
  - texel = tamanho no mundo de 1 px (1/48 = mesmo dos personagens).
"""
from __future__ import annotations

import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fxdraw import PIECES, Canvas, Frame, Ramp, ease_in, ease_out, layer, lerp, piece, rng, sheet  # noqa: E402,F401

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(GAME, "assets", "fx", "skills")
TABLE = os.path.join(GAME, "scripts", "client", "combat", "skill_fx_sheets.gd")
TAU = math.tau
D = math.radians

# ------------------------------------------------------------------ rampas (escuro -> branco)
# Brilhos (blend aditivo): a faixa escura soma pouco e vira halo; o topo e branco.
GLOW_TH = [0.05, 0.16, 0.32, 0.5, 0.7, 0.88]
GLOW_A = [90, 170, 255, 255, 255, 255]
BLADE = Ramp(["#3a2408", "#8a5414", "#d88c22", "#f4c252", "#e4ecf4", "#ffffff"], GLOW_TH, GLOW_A)
AMBER = Ramp(["#3a2408", "#7a4a12", "#c8801e", "#f0b640", "#fae58c", "#fffcf0"], GLOW_TH, GLOW_A)
ARCANE = Ramp(["#0a2a36", "#115a66", "#1a9ea4", "#46dcd2", "#b0fff2", "#ffffff"], GLOW_TH, GLOW_A)
GOLD = Ramp(["#4a300c", "#a0701c", "#e6b43a", "#fae58c", "#fffcf0"], [0.1, 0.3, 0.5, 0.7, 0.88],
            [110, 200, 255, 255, 255])
WISP = Ramp(["#18340e", "#3c7418", "#74bc2e", "#bce85a", "#f0ffb0", "#ffffff"], GLOW_TH, GLOW_A)
FROST = Ramp(["#0c2848", "#1c569c", "#3898de", "#84daf6", "#d2f8ff", "#ffffff"], GLOW_TH, GLOW_A)
FIRE = Ramp(["#3a0e08", "#8c1e12", "#d2421e", "#f4842a", "#fcc84a", "#fff4c8"], GLOW_TH, GLOW_A)
# Areas no chao: o veu escuro quase transparente (senao o chao inteiro "suja").
FIRE_GROUND = Ramp(["#3a0e08", "#8c1e12", "#d2421e", "#f4842a", "#fcc84a", "#fff4c8"], GLOW_TH,
                   [36, 150, 255, 255, 255, 255])
FROST_GROUND = Ramp(["#0c2848", "#1c569c", "#3898de", "#84daf6", "#d2f8ff", "#ffffff"], GLOW_TH,
                    [50, 160, 255, 255, 255, 255])
# Pecas solidas (blend normal + contorno de 1 px colorido).
SOLID_TH = [0.1, 0.38, 0.6, 0.82]
DUST = Ramp(["#7a644c", "#a88e6c", "#ccb48e", "#eadcb8"], SOLID_TH)
DUST_LINE = "#4e3e30"
ICE = Ramp(["#2a5c9a", "#4aa0dc", "#9ee4f8", "#f2feff"], SOLID_TH)
ICE_LINE = "#12305a"
STEEL = Ramp(["#5a5462", "#8e8a98", "#c8c4d0", "#f4f2f8"], SOLID_TH)
STEEL_LINE = "#2e2834"
STAR = Ramp(["#c08018", "#eab43c", "#fae58c", "#fffcf0"], SOLID_TH)
STAR_LINE = "#6a4210"

W_WHITE, W_GOLD, W_PALE = "#ffffff", "#fae58c", "#e6b43a"

def arc_pts(cx, cy, r_fn, a0, a1, n=28):
    pts = []
    for i in range(n):
        u = i / (n - 1)
        a = lerp(a0, a1, u)
        r = r_fn(u)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def blade_trail(cv, cx, cy, r_fn, a_tail, a_head, wmax, v=1.0, n=30):
    """Rastro de lamina em arco: fino na cauda, grosso na cabeca; borda externa branca."""
    if abs(a_head - a_tail) < 1e-3:
        return
    us = [i / (n - 1) for i in range(n)]
    for off, wf, val in ((0.0, 1.0, 0.36), (0.2, 0.6, 0.6), (0.34, 0.28, 0.95)):
        pts, ws, vs = [], [], []
        for u in us:
            w = wmax * (u ** 0.9)
            a = lerp(a_tail, a_head, u)
            r = r_fn(u) + off * w
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
            ws.append(w * wf)
            vs.append(val * v * (0.55 + 0.45 * u))
        cv.stroke(pts, ws, vs)


# ================================================================== LAMINA
def firm_strike_slash():
    frames = []
    cx, cy, R = 46, 52, 38
    a0, a1 = D(-160), D(35)
    for f in range(8):
        cv = Canvas(96)
        head = ease_out(min(1.0, (f + 1) / 4.0))
        tail = ease_in(min(1.0, max(0.0, (f - 1) / 6.0)))
        v = 1.0 if f < 4 else 1.0 - (f - 3) * 0.17
        wmax = 13.0 * (1.0 - f / 10.0)
        blade_trail(cv, cx, cy, lambda u: R * (0.9 + 0.14 * u), lerp(a0, a1, tail), lerp(a0, a1, head), wmax, v)
        if 1 <= f <= 5:  # eco interno, mais fraco
            blade_trail(cv, cx + 3, cy + 2, lambda u: (R - 10) * (0.9 + 0.1 * u), lerp(a0, a1, min(1, tail + 0.15)),
                        lerp(a0, a1, head * 0.92), wmax * 0.45, v * 0.5)
        cv.glow(2.2, 0.9, 0.2 * v)
        fr = Frame(96)
        fr.paint_canvas(cv, BLADE)
        ah = lerp(a0, a1, head)
        hx, hy = cx + math.cos(ah) * R * 1.04, cy + math.sin(ah) * R * 1.04
        if f in (1, 2):
            fr.twinkle(hx, hy, 3, W_WHITE, W_GOLD, W_PALE)
        if 3 <= f <= 6:  # faiscas soltas da ponta
            r = rng(10 + f)
            for k in range(3):
                d = (f - 2) * 4 + k * 3
                ang = ah + D(60 + k * 25)
                fr.twinkle(hx + math.cos(ang) * d * 0.6 + r.integers(-1, 2), hy + math.sin(ang) * d * 0.6,
                           1 if f > 4 else 2, W_WHITE if f < 5 else W_GOLD, W_PALE)
        frames.append(fr)
    piece("blade_firm_strike_slash", frames, pivot=(48, 50), blend="add", plane="billboard", fps=22)
    return frames


def burst(cv, cx, cy, n, r0, r1_long, r1_short, width, v, rot=0.0):
    for k in range(n):
        a = rot + k * TAU / n
        r1 = r1_long if k % 2 == 0 else r1_short
        cv.spike(cx, cy, a, r0, r1, width, v)
        cv.spike(cx, cy, a, r0, lerp(r0, r1, 0.7), width * 0.45, min(1.0, v + 0.3))


def firm_strike_impact():
    frames = []
    c = 48
    for f in range(7):
        cv = Canvas(96)
        rot = D(22.5)
        if f == 0:
            cv.circle(c, c, 9.8, 1.0)
            cv.circle(c, c, 14.6, 0.45)
        elif f == 1:
            burst(cv, c, c, 8, 3.7, 34.2, 20.7, 6, 0.7, rot)
            cv.circle(c, c, 9.8, 1.0)
            cv.ring(c, c, 13.4, 2.5, 0.55)
        elif f == 2:
            burst(cv, c, c, 8, 7.3, 41.5, 26.8, 5, 0.62, rot)
            cv.circle(c, c, 6.1, 0.95)
            cv.ring(c, c, 20.7, 2.5, 0.45)
        elif f == 3:
            burst(cv, c, c, 8, 13.4, 43.9, 29.3, 3.6, 0.5, rot)
            cv.ring(c, c, 26.8, 2.0, 0.34)
        elif f == 4:
            burst(cv, c, c, 8, 23.2, 45.1, 32.9, 2.6, 0.36, rot)
            cv.ring(c, c, 31.7, 1.6, 0.22)
        elif f == 5:
            burst(cv, c, c, 8, 32.9, 46.4, 37.8, 2.0, 0.24, rot)
        cv.glow(2.5, 0.9, 0.18 if f < 4 else 0.08)
        fr = Frame(96)
        fr.paint_canvas(cv, BLADE)
        if f >= 3:
            for k in range(6):
                a = rot + D(45) * k + D(12)
                d = 27 + (f - 3) * 6
                fr.twinkle(c + math.cos(a) * d, c + math.sin(a) * d, 2 if f < 5 else 1,
                           W_WHITE if f < 5 else W_GOLD, W_GOLD if f < 5 else W_PALE)
        frames.append(fr)
    piece("blade_firm_strike_impact", frames, pivot=(48, 48), blend="add", plane="billboard", fps=18)
    return frames


def charge_dust():
    frames = []
    blobs = [(-14, 0, 9), (-4, -4, 12), (8, -1, 10), (17, 2, 7), (2, 3, 8)]
    for f in range(8):
        cv = Canvas(96)
        s = 0.55 + 0.6 * ease_out(f / 5.0)
        rise = -f * 2.2
        spread = 1.0 + f * 0.1
        for (bx, by, br) in blobs:
            x, y, r = 48 + bx * spread, 78 + by + rise, br * s
            cv.circle(x, y, r, 0.3)
            cv.circle(x - r * 0.12, y - r * 0.15, r * 0.84, 0.5)
            cv.circle(x - r * 0.3, y - r * 0.34, r * 0.46, 0.72)
        cv.noise_erode(max(0.0, (f - 3) * 0.2), seed=40 + f, scale=3.5)
        fr = Frame(96)
        fr.paint_canvas(cv, DUST)
        if f <= 4:  # pedrinhas
            for k, (dx, dy) in enumerate(((-1, -1.3), (1.2, -1.1), (-1.6, -0.5), (1.7, -0.6))):
                t = f + 1
                x = 48 + dx * t * 5
                y = 76 + dy * t * 5 + 0.6 * t * t
                for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    fr.px(int(x) + ox, int(y) + oy, "#a88e6c" if (ox + oy) else "#eadcb8")
        fr.outline(DUST_LINE)
        frames.append(fr)
    piece("blade_charge_dust", frames, pivot=(48, 88), blend="mix", plane="billboard", fps=16)
    return frames


def charge_impact():
    frames = []
    c = 48
    for f in range(8):
        cv = Canvas(96)
        v = 1.0 if f < 3 else max(0.0, 1.0 - (f - 2) * 0.2)
        grow = ease_out(min(1.0, (f + 1) / 3.0))
        if f == 0:
            cv.circle(c, c, 10, 1.0)
            cv.circle(c, c, 15, 0.5)
        else:
            # X de dois cortes cruzados
            for ang in (D(-40), D(40)):
                L = 40 * grow
                w = 9 * v
                p0 = (c - math.cos(ang) * L, c - math.sin(ang) * L)
                p1 = (c + math.cos(ang) * L, c + math.sin(ang) * L)
                mid = (c, c)
                cv.stroke([p0, mid, p1], [0.5, w, 0.5], [0.45 * v, 0.6 * v, 0.45 * v])
                cv.stroke([p0, mid, p1], [0.3, w * 0.4, 0.3], [0.8 * v, 1.0 * v, 0.8 * v])
            # onda de choque achatada
            cv.ring(c, c + 4, 12 + f * 6, 3.0 * v + 0.5, 0.55 * v, ry_scale=0.45)
            burst(cv, c, c, 10, 8 + f * 3, 30 + f * 2, 20 + f * 2, 3.5 * v + 0.5, 0.5 * v, D(9))
            if f <= 2:
                cv.circle(c, c, 7 - f, 1.0)
        cv.glow(2.8, 0.9, 0.2 * v)
        fr = Frame(96)
        fr.paint_canvas(cv, BLADE)
        if 2 <= f <= 6:
            for k in range(8):
                a = D(45) * k + D(20)
                d = 20 + f * 5
                fr.twinkle(c + math.cos(a) * d, c + math.sin(a) * d * 0.8, 2 if f < 5 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_charge_impact", frames, pivot=(48, 48), blend="add", plane="billboard", fps=18)
    return frames


def charge_stun():
    frames = []
    cx, cy, rx, ry = 48, 48, 21, 7
    for f in range(8):
        fr = Frame(96)
        items = []
        for k in range(3):
            ph = TAU * (f / 8.0 + k / 3.0)
            depth = math.sin(ph)
            items.append((depth, ph))
        items.sort()
        for depth, ph in items:  # de tras para a frente
            cv = Canvas(96)
            x, y = cx + math.cos(ph) * rx, cy + math.sin(ph) * ry
            r = 5.5 + 1.6 * depth
            rot = -math.pi / 2 + ph * 0.5
            cv.star(x, y, r, r * 0.46, 5, rot, 0.45 if depth < 0 else 0.55)
            cv.star(x - 0.6, y - 0.8, r * 0.55, r * 0.26, 5, rot, 0.75 if depth < 0 else 0.85)
            sub = Frame(96)
            sub.paint_canvas(cv, STAR, clean=False)
            sub.outline(STAR_LINE)
            m = sub.rgba[..., 3] > 0
            fr.rgba[m] = sub.rgba[m]
            if depth > 0.3:
                fr.px(int(x - 1), int(y - 2), W_WHITE)
        frames.append(fr)
    piece("blade_charge_stun", frames, pivot=(48, 48), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def sector_field(cv, ox, oy, r0, r1, a0, a1, fn):
    """Setor (angulos em radianos, y para baixo). fn(u_ang, u_rad) -> intensidade."""
    dx, dy = cv.X - ox, cv.Y - oy
    r = np.sqrt(dx * dx + dy * dy)
    a = np.arctan2(dy, dx)
    lo, hi = min(a0, a1), max(a0, a1)
    m = (r >= r0) & (r <= r1) & (a >= lo) & (a <= hi)
    ua = np.clip((a - a0) / (a1 - a0 if a1 != a0 else 1), 0, 1)
    ur = np.clip((r - r0) / max(r1 - r0, 1e-3), 0, 1)
    val = fn(ua, ur)
    np.maximum(cv.f, np.where(m, val, 0).astype(np.float32), out=cv.f)


def clearing_sweep():
    frames = []
    ox, oy, R = 96, 162, 124
    a0, a1 = D(-135), D(-45)
    for f in range(8):
        cv = Canvas(192)
        lead = lerp(a0, a1, ease_out(min(1.0, (f + 1) / 4.5)))
        trail = lerp(a0, a1, ease_in(min(1.0, max(0.0, (f - 1.5) / 5.5))))
        v = 1.0 if f < 5 else 1.0 - (f - 4) * 0.25
        if lead - trail > 1e-3:
            # veu tenue (so a faixa escura do aditivo) + riscos de velocidade concentricos
            sector_field(cv, ox, oy, 30, R - 6, trail, lead, lambda ua, ur: (0.03 + 0.1 * ua ** 2) * v + 0 * ur)
            for k, rr in enumerate((46, 62, 78, 94, 108)):
                span = (lead - trail) * (0.35 + 0.12 * k)
                blade_trail(cv, ox, oy, lambda u, rr=rr: rr, lead - span, lead - D(4), 3.2 * v, 0.55 * v, n=24)
            blade_trail(cv, ox, oy, lambda u: R - 8 + 4 * u, trail, lead, 18 * v, v, n=44)
        if f <= 4:  # fio da lamina na frente
            c, s_ = math.cos(lead), math.sin(lead)
            pts = [(ox + c * r, oy + s_ * r) for r in (26, 60, 96, R)]
            cv.stroke(pts, [1.0, 4.0, 6.0, 3.0], [0.5, 0.8, 1.0, 1.0])
        cv.glow(3.0, 0.9, 0.16 * v)
        cv.noise_erode(max(0.0, (f - 5) * 0.3), seed=70 + f, scale=4)
        fr = Frame(192)
        fr.paint_canvas(cv, BLADE)
        if f >= 3:
            r = rng(80 + f)
            for k in range(9):
                a = lerp(trail, lead, (k + 0.5) / 9)
                d = R + (f - 3) * 4 + r.integers(-3, 4)
                fr.twinkle(ox + math.cos(a) * d, oy + math.sin(a) * d, 2 if f < 6 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_clearing_sweep_arc", frames, pivot=(96, 162), blend="add", plane="flat", fps=20,
          texel=3.0 / 124.0)
    return frames


def horizon_wave():
    frames = []
    for f in range(6):
        cv = Canvas(96)
        dx, dy = cv.X - 48, cv.Y - 104
        d_out = np.sqrt(dx * dx + dy * dy)
        dx2, dy2 = cv.X - 48, cv.Y - 117
        d_in = np.sqrt(dx2 * dx2 + dy2 * dy2)
        m = (d_out <= 64) & (d_in >= 63) & (np.abs(dx) < 45)
        t = np.clip((64 - d_out) / 13.0, 0, 1)
        side = np.clip(1 - np.abs(dx) / 47.0, 0, 1) ** 0.5
        val = np.where(t < 0.3, 1.0, np.where(t < 0.6, 0.62, 0.36)) * side
        np.maximum(cv.f, np.where(m, val, 0).astype(np.float32), out=cv.f)
        for k, (back, val) in enumerate(((10, 0.4), (19, 0.22))):  # ecos da meia-lua (rastro)
            d_e = np.sqrt((cv.X - 48) ** 2 + (cv.Y - 104 - back) ** 2)
            jit = 0.6 * math.sin(f * 2.1 + k)
            me = (np.abs(d_e - 62 + jit) < 1.6 - 0.4 * k) & (np.abs(cv.X - 48) < 40 - 8 * k)
            np.maximum(cv.f, np.where(me, val * side, 0).astype(np.float32), out=cv.f)
        cv.glow(2.0, 0.9, 0.18)
        fr = Frame(96)
        fr.paint_canvas(cv, BLADE)
        for k in (-1, 1):
            x = 48 + k * (26 + (f % 3) * 5)
            y = 104 - math.sqrt(max(0, 64 ** 2 - (x - 48) ** 2)) - 1
            fr.twinkle(x, y, 2, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_horizon_cut_wave", frames, pivot=(48, 52), blend="add", plane="flat", fps=18, loop=True,
          texel=2.6 / 90.0)
    return frames


def steel_spin():
    frames = []
    c = 96
    for f in range(8):
        cv = Canvas(192)
        head = D(-90) + D(58) * f
        R = 44 + 42 * ease_out((f + 1) / 5.0)
        v = 1.0 if f < 5 else 1.0 - (f - 4) * 0.24
        span = D(150) if f > 0 else D(70)
        for k in range(3):
            h = head + k * TAU / 3
            blade_trail(cv, c, c, lambda u: R * (0.8 + 0.2 * u), h - span, h, 13 * v, v, n=36)
        if f >= 4:
            cv.ring(c, c, 86 + (f - 4) * 1.5, 3.0 * v, 0.5 * v)
        cv.glow(3.0, 0.9, 0.18 * v)
        cv.noise_erode(max(0.0, (f - 5) * 0.3), seed=90 + f, scale=4)
        fr = Frame(192)
        fr.paint_canvas(cv, BLADE)
        for k in range(3):
            h = head + k * TAU / 3
            fr.twinkle(c + math.cos(h) * R * 1.02, c + math.sin(h) * R * 1.02, 3 if f < 5 else 1, W_WHITE, W_GOLD, W_PALE)
        frames.append(fr)
    piece("blade_steel_spin_whirl", frames, pivot=(96, 96), blend="add", plane="flat", fps=18, texel=3.0 / 88.0)
    return frames


def plate_poly(x, y, s, tilt):
    """Placa de aco em forma de escudo (heater), s = altura."""
    w = s * 0.72
    pts = [(-w / 2, -s / 2), (w / 2, -s / 2), (w / 2, s * 0.05), (0, s / 2), (-w / 2, s * 0.05)]
    c, si = math.cos(tilt), math.sin(tilt)
    return [(x + px * c - py * si, y + px * si + py * c) for px, py in pts]


def iron_stance():
    # 30/09/2026: placas maiores e mais afastadas do corpo (quadro 128, placa 34 px).
    front, back, glow = [], [], []
    cx, cy, rx, ry = 64, 76, 50, 14
    for f in range(8):
        fr_f, fr_b = Frame(128), Frame(128)
        items = []
        for k in range(5):
            ph = TAU * (f / 8.0 / 5.0 + k / 5.0)  # 1/5 de volta por laco: repete sem salto
            items.append((math.sin(ph), ph))
        items.sort()
        for depth, ph in items:
            x = cx + math.cos(ph) * rx
            y = cy + math.sin(ph) * ry + math.sin(ph * 2 + f * TAU / 8) * 1.6
            s = 34 + 5 * depth
            tilt = math.cos(ph) * 0.35
            cv = Canvas(128)
            cv.poly(plate_poly(x, y, s, tilt), 0.42)
            cv.poly(plate_poly(x - s * 0.1, y - s * 0.08, s * 0.62, tilt), 0.66)
            cv.stroke([(x - 0.5, y - s * 0.4), (x, y + s * 0.34)], [2.0, 0.8], [0.95, 0.7])
            sub = Frame(128)
            sub.paint_canvas(cv, STEEL, clean=False)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):  # rebite ambar 2x2
                sub.px(int(round(x)) + dx, int(round(y - s * 0.12)) + dy, "#f0b640" if dx + dy else "#fae58c")
            sub.outline(STEEL_LINE)
            dst = fr_f if depth >= 0 else fr_b
            m = sub.rgba[..., 3] > 0
            dst.rgba[m] = sub.rgba[m]
        front.append(fr_f)
        back.append(fr_b)
        # brilho ambar: anel nos pes + fios de luz subindo
        cv = Canvas(128)
        pulse = 0.5 + 0.12 * math.sin(f * TAU / 8)
        cv.ring(64, 118, 32, 3.0, pulse, ry_scale=0.28)
        cv.ring(64, 118, 24, 1.6, pulse * 0.6, ry_scale=0.28)
        for k in range(8):
            ph = (f / 8.0 + k / 8.0) % 1.0
            x = 64 + math.cos(k * 2.3) * 32
            y = 120 - ph * 92
            ln = 13 + 7 * math.sin(k)
            a = (1 - ph) * 0.7
            cv.stroke([(x, y - ln), (x, y)], [3.0, 0.4], [a, a * 0.25])
        cv.glow(2.8, 0.8, 0.14)
        g = Frame(128)
        g.paint_canvas(cv, AMBER)
        glow.append(g)
    piece("blade_iron_stance_front", front, pivot=(64, 124), blend="mix", plane="billboard", fps=10, loop=True)
    piece("blade_iron_stance_back", back, pivot=(64, 124), blend="mix", plane="billboard", fps=10, loop=True)
    piece("blade_iron_stance_glow", glow, pivot=(64, 124), blend="add", plane="billboard", fps=10, loop=True)
    return front, back, glow


# ================================================================== ARCANO
def spark_projectile():
    # 30/09/2026: maior (o dono achou pequena no jogo) — quadro 128, forma 1,45x.
    frames = []
    K = 1.45
    hx, hy = 86, 64
    for f in range(6):
        cv = Canvas(128)
        wob = [math.sin(f * 1.7 + i) * 1.2 * K for i in range(6)]
        pts = [(hx - i * 8 * K, hy + wob[i] * (i / 5)) for i in range(6)]
        cv.stroke(pts, [w * K for w in (10, 8, 6, 4, 2, 0.4)], [0.5, 0.42, 0.34, 0.24, 0.14, 0.08])
        cv.stroke(pts[:3], [w * K for w in (4.5, 3, 1)], [0.8, 0.62, 0.4])
        cv.circle(hx, hy, 11 * K, 0.5)
        cv.circle(hx, hy, 6.5 * K, 0.82)
        cv.circle(hx, hy, 3.2 * K, 1.0)
        rot = f * D(15)
        for k in range(4):
            a = rot + k * TAU / 4
            cv.spike(hx, hy, a, 2, (20 if k % 2 == 0 else 13) * K, 3.0 * K, 0.9)
        for k in range(4):
            a = rot + D(45) + k * TAU / 4
            cv.spike(hx, hy, a, 2, 8 * K, 2.0 * K, 0.7)
        cv.glow(2.6, 0.9, 0.2)
        fr = Frame(128)
        fr.paint_canvas(cv, ARCANE)
        for k in range(3):
            t = ((f / 6.0) + k / 3.0) % 1.0
            fr.twinkle(hx - 14 - t * 48, hy + math.sin(k * 2.1 + f) * 7, 1 if t > 0.5 else 3, W_WHITE, W_GOLD, W_PALE)
        frames.append(fr)
    piece("arcane_spark_projectile", frames, pivot=(86, 64), blend="add", plane="billboard", fps=16, loop=True)
    return frames


def zigzag(cx, cy, ang, r0, r1, amp, seed):
    r = rng(seed)
    n = 5
    pts = []
    c, s = math.cos(ang), math.sin(ang)
    for i in range(n):
        t = i / (n - 1)
        d = lerp(r0, r1, t)
        o = 0 if i in (0, n - 1) else r.uniform(-amp, amp)
        pts.append((cx + c * d - s * o, cy + s * d + c * o))
    return pts


def spark_impact():
    frames = []
    K = 1.35
    c = 64
    for f in range(7):
        cv = Canvas(128)
        v = 1.0 if f < 3 else max(0.0, 1.0 - (f - 2) * 0.24)
        if f == 0:
            cv.circle(c, c, 9 * K, 1.0)
            cv.circle(c, c, 14 * K, 0.5)
        else:
            # clarao em quatro raios longos + quatro curtos que afina e some
            Ll = [0, 40, 44, 34, 20, 0, 0][f] * K
            Ls = [0, 18, 20, 14, 8, 0, 0][f] * K
            w = [0, 7, 5, 3.4, 2.2, 0, 0][f] * K
            for k in range(4):
                a = k * TAU / 4 + D(12)
                if Ll:
                    cv.spike(c, c, a, 0, Ll, w, 0.62 * v)
                    cv.spike(c, c, a, 0, Ll * 0.75, w * 0.4, 1.0)
                if Ls:
                    cv.spike(c, c, a + TAU / 8, 0, Ls, w * 0.8, 0.55 * v)
            if f <= 3:
                cv.circle(c, c, [0, 9, 7, 4][f] * K, 1.0)
                cv.circle(c, c, [0, 13, 11, 8][f] * K, 0.6)
            if 1 <= f <= 3:  # tres faiscas-raio em zigue-zague, curtas
                for k in range(3):
                    a = k * TAU / 3 + D(35)
                    pts = zigzag(c, c, a, (8 + f * 5) * K, (20 + f * 6) * K, 3.0 * K, 300 + k)
                    cv.stroke(pts, [2.2 * K] * 5, [0.8 * v] * 5)
            cv.ring(c, c, (8 + f * 5) * K, 2.0 * v * K, 0.45 * v)
        cv.glow(2.8, 0.9, 0.2 * v)
        fr = Frame(128)
        fr.paint_canvas(cv, ARCANE)
        if f >= 2:
            for k in range(8):
                a = k * TAU / 8 + D(22.5)
                d = (10 + f * 5.5) * K
                if f <= 4:
                    fr.twinkle(c + math.cos(a) * d, c + math.sin(a) * d, 3 if k % 2 else 2, W_WHITE, W_GOLD, W_PALE)
                else:
                    fr.px(int(c + math.cos(a) * d), int(c + math.sin(a) * d + (f - 4) * 2), W_GOLD)
        frames.append(fr)
    piece("arcane_spark_impact", frames, pivot=(64, 64), blend="add", plane="billboard", fps=18)
    return frames


def wisp_projectile():
    # 30/09/2026: maior — quadro 128, forma 1,4x.
    frames = []
    K = 1.4
    hx, hy = 88, 64
    for f in range(8):
        cv = Canvas(128)
        ph = f * TAU / 8
        for k, (amp, ln, w0, val) in enumerate(((6, 54, 19, 0.42), (5, 42, 13, 0.55), (3, 28, 8, 0.75))):
            pts, ws, vs = [], [], []
            n = 14
            for i in range(n):
                t = i / (n - 1)
                x = hx - t * ln * K
                y = hy + math.sin(ph + t * 5.5 + k) * amp * K * t
                pts.append((x, y))
                ws.append(w0 * K * (1 - t) ** 0.8 + 0.3)
                vs.append(val * (1 - 0.5 * t))
            cv.stroke(pts, ws, vs)
        cv.circle(hx, hy, 11.5 * K, 0.5)
        cv.circle(hx + 0.5, hy - 0.5, 7.5 * K, 0.78)
        cv.circle(hx + 1, hy - 1, 4.0 * K, 1.0)
        cv.glow(2.8, 0.9, 0.2)
        fr = Frame(128)
        fr.paint_canvas(cv, WISP)
        # dois "olhos" escuros de fogo-fatuo (assombracao do cerrado)
        for ex in (-4, 4):
            fr.px(hx + 2 + ex // 2, hy - 2 + (1 if ex > 0 else 0), "#3c7418")
            fr.px(hx + 2 + ex // 2, hy - 1 + (1 if ex > 0 else 0), "#3c7418")
        for k in range(5):
            t = ((f / 8.0) + k / 5.0) % 1.0
            x = hx - 18 - t * 50
            y = hy + math.sin(k * 1.9 + t * 6) * 12
            fr.twinkle(x, y, 2 if t < 0.4 else 1, "#f0ffb0", "#74bc2e")
        frames.append(fr)
    piece("arcane_will_o_wisp_projectile", frames, pivot=(88, 64), blend="add", plane="billboard", fps=14,
          loop=True)
    return frames


def flame_tongue_stroke(cv, bx, by, ang, length, w0, ph, v, sway=4.0, n=12):
    pts, ws, vs = [], [], []
    c, s = math.cos(ang), math.sin(ang)
    for i in range(n):
        t = i / (n - 1)
        o = math.sin(ph + t * 4.0) * sway * t
        d = t * length
        pts.append((bx + c * d - s * o, by + s * d + c * o))
        ws.append(w0 * (1 - t) ** 0.75 + 0.2)
        vs.append(v)
    cv.stroke(pts, ws, vs)


def wisp_impact():
    frames = []
    K = 1.3
    c, cy = 64, 84
    tongues = [(-12, 20, 9, 0.0), (0, 34, 13, 1.3), (11, 26, 10, 2.6), (-20, 12, 6, 3.4), (19, 14, 6, 4.4)]
    for f in range(7):
        cv = Canvas(128)
        v = 1.0 if f < 3 else max(0.0, 1.0 - (f - 2) * 0.22)
        g = ease_out(min(1.0, (f + 1) / 3.0))
        ph = f * 1.1
        # bola de fogo-fatuo que estoura
        cv.circle(c, cy - 4 * K, [10, 12, 10, 7, 4, 0, 0][f] * K, 0.5 * v)
        cv.circle(c, cy - 4 * K, [7, 8, 6, 4, 0, 0, 0][f] * K, 1.0)
        if f >= 1:
            cv.ring(c, cy + 6 * K, (10 + f * 5) * K, 3.2 * v * K, 0.5 * v, ry_scale=0.32)
            for (ox, h, w, p) in tongues:  # linguas subindo, com balanco
                hh = h * K * g * (1.15 if f == 2 else 1.0) * (1 - max(0, f - 3) * 0.18)
                bx = c + ox * K * (0.6 + 0.12 * f)
                flame_tongue_stroke(cv, bx, cy + 4 * K, D(-90) + ox * 0.012, hh, w * K * v, ph + p, 0.45 * v, sway=5)
                flame_tongue_stroke(cv, bx, cy + 4 * K, D(-90) + ox * 0.012, hh * 0.6, w * 0.55 * K * v, ph + p,
                                    0.75 * v, sway=4)
        cv.glow(2.8, 0.9, 0.2 * v)
        cv.noise_erode(max(0.0, (f - 4) * 0.25), seed=400 + f, scale=3)
        fr = Frame(128)
        fr.paint_canvas(cv, WISP)
        if f >= 2:
            r = rng(410)
            for k in range(9):
                x = c + r.uniform(-32, 32)
                y = cy - 14 - (f - 1) * r.uniform(5, 9)
                fr.twinkle(x, y, 2 if f < 4 else 1, "#f0ffb0", "#74bc2e")
        frames.append(fr)
    piece("arcane_will_o_wisp_impact", frames, pivot=(64, 80), blend="add", plane="billboard", fps=16)
    return frames


def creeping_ground():
    frames = []
    c = 96
    r = rng(500)
    embers = [(r.uniform(0, TAU), 80 * math.sqrt(r.uniform(0.02, 1)), r.uniform(1.6, 3.6), r.uniform(0, TAU))
              for _ in range(46)]
    cracks = []
    for k in range(9):  # rachaduras incandescentes (fixas), com um galho cada
        a = k * TAU / 9 + r.uniform(-0.2, 0.2)
        pts, rr = [], 10.0
        while rr < 74:
            a += r.uniform(-0.25, 0.25)
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
            rr += r.uniform(8, 13)
        cracks.append((pts, 1.8))
        j = len(pts) // 2
        b = a + r.choice([-0.8, 0.8])
        cracks.append(([pts[j], (pts[j][0] + math.cos(b) * 14, pts[j][1] + math.sin(b) * 14)], 1.3))
    for f in range(8):
        cv = Canvas(192)
        ph = f * TAU / 8
        cv.circle(c, c, 84, 0.03)
        dx, dy = cv.X - c, cv.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        rim = 84 + 3.5 * np.sin(7 * a + ph) + 2 * np.sin(13 * a - 2 * ph)
        cv.put((np.abs(d - rim) < 3.2).astype(np.float32), 0.5)
        cv.put((np.abs(d - rim) < 1.2).astype(np.float32), 0.7)
        for (pts, w) in cracks:
            glow_v = 0.3 + 0.12 * math.sin(ph + pts[0][0])
            cv.stroke(pts, [w] * len(pts), [glow_v] * len(pts))
        for (ea, er, es, eph) in embers:
            puls = 0.5 + 0.5 * math.sin(ph + eph)
            cv.circle(c + math.cos(ea) * er, c + math.sin(ea) * er, es * (0.7 + 0.4 * puls), 0.3 + 0.5 * puls)
        # linguinhas para fora na borda
        for k in range(18):
            ang = k * TAU / 18 + 0.3 * math.sin(ph + k)
            ln = 7 + 4 * math.sin(ph * 2 + k * 1.3)
            cv.spike(c, c, ang, 82, 82 + ln, 5, 0.55)
        cv.glow(3.0, 0.9, 0.1)
        fr = Frame(192)
        fr.paint_canvas(cv, FIRE)
        frames.append(fr)
    piece("arcane_creeping_flame_ground", frames, pivot=(96, 96), blend="add", plane="flat", fps=10, loop=True,
          texel=3.0 / 86.0)
    return frames


def flame_tongue():
    frames = []
    bx, by = 48, 88
    tongues = [(0, 54, 15, 0.0), (-9, 36, 11, 1.7), (9, 40, 11, 3.1), (-15, 22, 7, 4.2), (15, 24, 7, 5.3)]
    for f in range(8):
        cv = Canvas(96)
        ph = f * TAU / 8
        cv.ellipse(bx, by, 17, 5, 0.42)
        for (ox, h, w, p) in tongues:
            hh = h * (0.9 + 0.12 * math.sin(ph * 2 + p))
            flame_tongue_stroke(cv, bx + ox, by, D(-90), hh, w, ph + p, 0.45, sway=5)
            flame_tongue_stroke(cv, bx + ox, by, D(-90), hh * 0.7, w * 0.6, ph + p, 0.66, sway=4)
        flame_tongue_stroke(cv, bx, by, D(-90), 26, 10, ph, 0.9, sway=2)
        flame_tongue_stroke(cv, bx, by + 1, D(-90), 12, 7, ph, 1.0, sway=1)
        # pedaco de chama solto
        t = (f / 8.0)
        cv.ellipse(bx + 4 * math.sin(ph), by - 56 - t * 14, 3.5 * (1 - t), 5 * (1 - t), 0.5)
        cv.glow(2.4, 0.9, 0.18)
        fr = Frame(96)
        fr.paint_canvas(cv, FIRE)
        for k in range(3):
            tt = ((f / 8.0) + k / 3.0) % 1.0
            fr.twinkle(bx + math.sin(k * 2.2 + tt * 5) * 16, by - 20 - tt * 50, 1, "#fff4c8", "#f4842a")
        frames.append(fr)
    piece("arcane_creeping_flame_tongue", frames, pivot=(48, 90), blend="add", plane="billboard", fps=12, loop=True)
    return frames


def frost_cone():
    frames = []
    ox, oy, R = 96, 184, 178
    a0, a1 = D(-120), D(-60)
    r = rng(600)
    shards = [(r.uniform(a0 + 0.04, a1 - 0.04), r.uniform(28, R - 12), r.uniform(9, 19), r.uniform(-0.4, 0.4))
              for _ in range(34)]
    for f in range(8):
        cv = Canvas(192)
        Rf = 20 + (R - 20) * ease_out((f + 1) / 5.5)
        v = 1.0 if f < 5 else 1.0 - (f - 4) * 0.26
        sector_field(cv, ox, oy, 6, Rf, a0, a1, lambda ua, ur: (0.06 + 0.08 * ur) * v + 0 * ua)
        if f < 6:
            sector_field(cv, ox, oy, max(6, Rf - 12), Rf, a0, a1, lambda ua, ur: (0.2 + 0.36 * ur) * v)
            sector_field(cv, ox, oy, max(6, Rf - 4), Rf, a0, a1, lambda ua, ur: 0.85 * v + 0 * ur)
        for (sa, sr, sl, tw) in shards:
            if sr + 4 < Rf:
                cv.spike(ox + math.cos(sa) * sr, oy + math.sin(sa) * sr, sa + tw, -sl * 0.4, sl * 0.6, 6, 0.55 * v)
                cv.spike(ox + math.cos(sa) * sr, oy + math.sin(sa) * sr, sa + tw, -sl * 0.3, sl * 0.45, 2, 0.95 * v)
        cv.glow(3.0, 0.9, 0.1 * v)
        cv.noise_erode(max(0.0, (f - 5) * 0.3), seed=620 + f, scale=4)
        fr = Frame(192)
        fr.paint_canvas(cv, FROST_GROUND)
        rr = rng(630 + f)
        for k in range(8):
            a = rr.uniform(a0, a1)
            d = rr.uniform(20, Rf)
            fr.twinkle(ox + math.cos(a) * d, oy + math.sin(a) * d, 2 if f < 6 else 1, W_WHITE, "#84daf6")
        frames.append(fr)
    piece("arcane_frost_burst_cone", frames, pivot=(96, 184), blend="add", plane="flat", fps=16,
          texel=6.0 / 178.0)
    return frames


def prism(cv, bx, by, h, w, tilt):
    c, s = math.cos(tilt), math.sin(tilt)

    def P(x, y):
        return (bx + x * c - y * s, by + x * s + y * c)
    body = [P(-w / 2, 0), P(-w / 2, -h * 0.72), P(0, -h), P(w / 2, -h * 0.72), P(w / 2, 0)]
    left = [P(-w / 2, 0), P(-w / 2, -h * 0.72), P(0, -h), P(0, 0)]
    cv.poly(body, 0.62)
    cv.poly(left, 0.4)
    cv.stroke([P(w * 0.08, -h * 0.05), P(w * 0.08, -h * 0.8)], [1.6, 1.0], [0.9, 0.9])
    cv.stroke([P(w * 0.3, -h * 0.2), P(w * 0.3, -h * 0.62)], [1.0, 0.8], [0.72, 0.72])


def frost_crystal():
    frames = []
    bx, by = 48, 90
    parts = [(0, 46, 15, 0.0), (-13, 30, 11, D(-24)), (13, 34, 12, D(20)), (-6, 18, 8, D(-48)), (8, 16, 7, D(52))]
    grow = [0.35, 0.78, 1.0, 1.0, 1.0, 0.8, 0, 0]
    r = rng(720)
    shards = [(r.uniform(-1, 1), r.uniform(-1.6, -0.5), r.uniform(3, 5.5), r.uniform(0, TAU)) for _ in range(12)]
    for f in range(8):
        cv = Canvas(96)
        g = grow[f]
        if g > 0:
            for k, (ox, h, w, tilt) in enumerate(parts):
                prism(cv, bx + ox, by, h * g, w * (0.7 + 0.3 * g), tilt)
            cv.ellipse(bx, by, 19 * g, 4, 0.82)
        if f >= 5:  # estilhacos voando e caindo
            t = f - 4
            for (vx, vy, sz, rot) in shards:
                x = bx + vx * 16 * t
                y = by - 26 + vy * 10 * t + 4.5 * t * t
                s2 = sz * (1.0 if t < 3 else 0.7)
                c_, s_ = math.cos(rot + t), math.sin(rot + t)
                pts = [(x + c_ * s2, y + s_ * s2), (x - s_ * s2 * 0.5, y + c_ * s2 * 0.5),
                       (x - c_ * s2, y - s_ * s2), (x + s_ * s2 * 0.5, y - c_ * s2 * 0.5)]
                cv.poly(pts, 0.7)
        fr = Frame(96)
        fr.paint_canvas(cv, ICE)
        if f == 5:  # rachaduras
            for (x0, y0, x1, y1) in ((46, 60, 51, 72), (51, 72, 47, 82), (38, 70, 42, 80), (58, 66, 55, 78)):
                n = 8
                for i in range(n + 1):
                    fr.px(int(round(lerp(x0, x1, i / n))), int(round(lerp(y0, y1, i / n))), ICE_LINE)
        fr.outline(ICE_LINE)
        if f in (2, 3):
            fr.twinkle(bx, by - 46 * g, 2, W_WHITE, "#d2f8ff")
        if f == 4:
            fr.twinkle(bx + 13, by - 32, 2, W_WHITE, "#d2f8ff")
        frames.append(fr)
    piece("arcane_frost_burst_crystal", frames, pivot=(48, 90), blend="mix", plane="billboard", fps=14)
    return frames


def snowflake(fr, x, y, s, core, arm):
    x, y = int(round(x)), int(round(y))
    fr.px(x, y, core)
    for k in range(1, s + 1):
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            fr.px(x + dx, y + dy, arm)
    if s >= 2:
        for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1), (2, 2), (-2, -2), (2, -2), (-2, 2)):
            fr.px(x + dx, y + dy, arm)


def frost_chill():
    frames = []
    for f in range(8):
        cv = Canvas(96)
        ph = f * TAU / 8
        cv.ellipse(48, 86, 22, 6, 0.14)
        cv.ring(48, 86, 22, 2.2, 0.58, ry_scale=0.27)
        for k in range(8):  # geada no chao: pontas de cristal
            a = k * TAU / 8 + 0.2
            x, y = 48 + math.cos(a) * 22, 86 + math.sin(a) * 6
            cv.spike(x, y, D(-90) + math.cos(a) * 0.5, 0, 7 + 2 * math.sin(ph + k), 3, 0.7)
        cv.glow(2.0, 0.9, 0.14)
        fr = Frame(96)
        fr.paint_canvas(cv, FROST)
        for k in range(6):
            t = ((f / 8.0) + k / 6.0) % 1.0
            x = 48 + math.cos(k * 2.4) * 20 + math.sin(t * 6 + k) * 3
            y = 84 - t * 46
            snowflake(fr, x, y, 2 if t < 0.6 else 1, W_WHITE, "#84daf6")
        frames.append(fr)
    piece("arcane_frost_burst_chill", frames, pivot=(48, 90), blend="add", plane="billboard", fps=10, loop=True)
    return frames


def star_fall_star():
    frames = []
    hx, hy = 64, 48
    for f in range(6):
        cv = Canvas(96)
        for oy, ln, w, v in ((0, 52, 16, 0.44), (-6, 34, 7, 0.3), (6, 34, 7, 0.3), (0, 30, 7, 0.72)):
            pts = [(hx - 6 - t * ln, hy + oy * t) for t in (0, 0.25, 0.5, 0.75, 1.0)]
            cv.stroke(pts, [w, w * 0.75, w * 0.5, w * 0.25, 0.3], [v, v * 0.85, v * 0.7, v * 0.5, v * 0.3])
        cv.glow(2.4, 0.9, 0.2)
        fr = Frame(96)
        fr.paint_canvas(cv, ARCANE)
        sv = Canvas(96)
        rot = -math.pi / 2 + f * D(12)
        sv.star(hx, hy, 15, 6.5, 5, rot, 0.55)
        sv.star(hx, hy, 9, 4, 5, rot, 0.8)
        sv.circle(hx, hy, 2.6, 1.0)
        fr.paint(sv.down(), GOLD)
        for k in range(3):
            t = ((f / 6.0) + k / 3.0) % 1.0
            fr.twinkle(hx - 18 - t * 34, hy + math.sin(k * 2 + f) * 6, 2 if t < 0.5 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("arcane_star_fall_star", frames, pivot=(64, 48), blend="add", plane="billboard", fps=14, loop=True)
    return frames


STONE_SHADOW = Ramp(["#1c1830", "#2a2448", "#3a3464"], [0.08, 0.4, 0.75], [70, 110, 140])
CRACK_GLOW = Ramp(["#0a2a36", "#115a66", "#1a9ea4", "#46dcd2", "#b0fff2", "#ffffff"], GLOW_TH,
                  [0, 150, 255, 255, 255, 255])


def ground_cracks(seed, c, r_max, n=9, r_min=8.0):
    """Rachaduras radiais (listas de pontos) com um galho cada — chao que racha."""
    r = rng(seed)
    out = []
    for k in range(n):
        a = k * TAU / n + r.uniform(-0.25, 0.25)
        pts, rr = [], r_min
        while rr < r_max:
            a += r.uniform(-0.28, 0.28)
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
            rr += r.uniform(7, 12)
        out.append(pts)
        if len(pts) > 3:
            j = len(pts) // 2
            b = a + r.choice([-0.7, 0.7])
            out.append([pts[j], (pts[j][0] + math.cos(b) * 13, pts[j][1] + math.sin(b) * 13)])
    return out


def star_fall_warning():
    """Aviso no chao antes da queda (30/09/2026, troca a estrela dentro do circulo): a SOMBRA da pedra-estrela
    que cai, com o chao rachando e brilhando por baixo e pedrinhas pulando. Em laco; o SkillFx faz crescer."""
    frames = []
    c = 96
    cracks = ground_cracks(830, c, 84, n=11, r_min=14)
    r = rng(840)
    pebbles = [(r.uniform(0, TAU), r.uniform(20, 80), r.uniform(0, 1)) for _ in range(14)]
    for f in range(8):
        ph = f / 8.0
        fr = Frame(192)
        sh = Canvas(192)
        # sombra de borda pontilhada (nada de aro liso): tres faixas e um ruido fixo na borda
        dx, dy = sh.X - c, sh.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        edge = 86 + 3 * np.sin(9 * a) + 2 * np.sin(5 * a + 1.3)
        sh.put(((d < edge) * np.clip((edge - d) / 60.0 + 0.1, 0, 1)).astype(np.float32), 1.0)
        fr.paint_canvas(sh, STONE_SHADOW, clean=False)
        cv = Canvas(192)
        glow_v = 0.36 + 0.2 * (0.5 + 0.5 * math.sin(ph * TAU))
        for pts in cracks:
            cv.stroke(pts, [2.2] * len(pts), [glow_v] * len(pts))
            cv.stroke(pts[:2], [3.0, 2.0], [glow_v + 0.25] * 2)
        cv.circle(c, c, 9, glow_v + 0.2)
        cv.glow(2.4, 0.8, 0.12)
        layer(fr, cv, CRACK_GLOW)
        for (pa, pr, p0) in pebbles:  # pedrinhas pulando (tremor)
            t = (ph + p0) % 1.0
            hop = math.sin(t * math.pi) * 5 if t < 0.5 else 0
            x, y = c + math.cos(pa) * pr, c + math.sin(pa) * pr - hop
            for ox, oy, col in ((0, 0, "#c8c4d0"), (1, 0, "#8e8a98"), (0, 1, "#5a5462"), (1, 1, "#5a5462")):
                fr.px(int(x) + ox, int(y) + oy, col)
        frames.append(fr)
    piece("arcane_star_fall_warning", frames, pivot=(96, 96), blend="mix", plane="flat", fps=10, loop=True,
          texel=4.0 / 90.0)
    return frames


def star_fall_impact():
    """Impacto deitado (30/09/2026): cratera de chao estourado, rachaduras em brasa turquesa, onda de poeira
    e cacos de luz dourada espalhados — sem estrela desenhada no chao."""
    frames = []
    c = 96
    cracks = ground_cracks(850, c, 88, n=12, r_min=18)
    r = rng(860)
    shards = [(r.uniform(0, TAU), r.uniform(24, 84), r.uniform(0, TAU), r.uniform(3.5, 6.5)) for _ in range(22)]
    for f in range(9):
        cv = Canvas(192)
        v = 1.0 if f < 3 else max(0.0, 1.0 - (f - 2) * 0.16)
        R = 30 + 58 * ease_out(f / 4.0)
        if f == 0:
            cv.circle(c, c, 30, 0.55)
            cv.circle(c, c, 18, 1.0)
        else:
            # frente de choque de borda quebrada (poeira levantada), nao um aro liso
            dx, dy = cv.X - c, cv.Y - c
            d = np.sqrt(dx * dx + dy * dy)
            a = np.arctan2(dy, dx)
            front = R + 4 * np.sin(11 * a + f) + 3 * np.sin(7 * a - 2 * f)
            cv.put(((np.abs(d - front) < 5 * v + 1)).astype(np.float32), 0.45 * v)
            cv.put(((np.abs(d - front) < 1.6 * v + 0.5)).astype(np.float32), 0.85 * v)
            grow = ease_out(min(1.0, f / 3.0))
            for pts in cracks:
                n = max(2, int(len(pts) * grow))
                cv.stroke(pts[:n], [3.0 * v + 0.8] * n, [0.62 * v + 0.1] * n)
            if f <= 3:
                cv.circle(c, c, 22 - f * 4, 1.0)
                cv.circle(c, c, 30 - f * 3, 0.6)
        cv.glow(4.0, 0.9, 0.16 * v)
        cv.noise_erode(max(0.0, (f - 5) * 0.22), seed=870 + f, scale=4)
        fr = Frame(192)
        fr.paint_canvas(cv, ARCANE)
        gv = Canvas(192)
        for (sa, sr, rot, sz) in shards:  # cacos da pedra-estrela, dourados, espalhados pelo chao
            if f == 0 or sr > R + 8:
                continue
            x, y = c + math.cos(sa) * sr, c + math.sin(sa) * sr
            k = sz * (1.0 if f < 6 else 0.7)
            cs, sn = math.cos(rot), math.sin(rot)
            gv.poly([(x + cs * k, y + sn * k), (x - sn * k * 0.45, y + cs * k * 0.45),
                     (x - cs * k * 0.7, y - sn * k * 0.7), (x + sn * k * 0.45, y - cs * k * 0.45)], 0.75 * v + 0.15)
        layer(fr, gv, GOLD, STAR_LINE if f < 7 else None)
        if f >= 2:
            rr = rng(820)
            for k in range(14):
                a = rr.uniform(0, TAU)
                d = rr.uniform(20, 70) + f * 3
                fr.twinkle(c + math.cos(a) * d, c + math.sin(a) * d, 2 if f < 6 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("arcane_star_fall_impact", frames, pivot=(96, 96), blend="add", plane="flat", fps=16, texel=4.0 / 90.0)
    return frames


def star_fall_burst():
    frames = []
    bx, by = 48, 90
    for f in range(8):
        cv = Canvas(96)
        v = 1.0 if f < 2 else max(0.0, 1.0 - (f - 1) * 0.16)
        w = [10, 22, 18, 14, 10, 7, 4, 2][f]
        top = [40, 2, 0, 0, 4, 10, 20, 34][f]
        cv.stroke([(bx, by), (bx, top)], [w, w * 0.6], [0.5 * v, 0.4 * v])
        cv.stroke([(bx, by), (bx, top + 6)], [w * 0.4, w * 0.2], [1.0 * v, 0.9 * v])
        cv.ellipse(bx, by, 10 + f * 3.5, 3 + f * 0.9, 0.55 * v)
        cv.glow(3.0, 0.9, 0.2 * v)
        fr = Frame(96)
        fr.paint_canvas(cv, ARCANE)
        rr = rng(900)
        for k in range(9):
            x = bx + rr.uniform(-22, 22)
            y = by - 10 - f * rr.uniform(5, 10)
            if f >= 1:
                fr.twinkle(x, y, 2 if f < 5 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("arcane_star_fall_burst", frames, pivot=(48, 90), blend="add", plane="billboard", fps=16)
    return frames


# Runas de Pindorama (30/09/2026): semente, broto e ziguezague de rio — nenhuma em forma de cruz ou estrela.
RUNES = [
    [".#.", "#.#", "#.#", ".#."],
    ["#.#", ".#.", ".#.", "##."],
    ["##.", ".#.", ".##", "..#"],
]


def rune(fr, x, y, k, core, edge):
    g = RUNES[k % len(RUNES)]
    x0, y0 = int(round(x)) - 1, int(round(y)) - 2
    for j, row in enumerate(g):
        for i, ch in enumerate(row):
            if ch == "#":
                fr.px(x0 + i, y0 + j, core if j in (1, 2) else edge)


def hex_lines(cv, cx, cy, R, cell, fn):
    """Grade hexagonal recortada no circulo; fn(dist_norm) -> intensidade da linha."""
    s = cell
    h = s * math.sqrt(3)
    for row in range(-8, 9):
        for col in range(-8, 9):
            hx = cx + col * s * 1.5
            hy = cy + row * h + (h / 2 if col % 2 else 0)
            pts = [(hx + math.cos(a) * s, hy + math.sin(a) * s) for a in [k * math.pi / 3 for k in range(7)]]
            for i in range(6):
                (x0, y0), (x1, y1) = pts[i], pts[i + 1]
                mx, my = (x0 + x1) / 2, (y0 + y1) / 2
                d = math.hypot(mx - cx, my - cy) / R
                if d < 0.93:
                    cv.stroke([(x0, y0), (x1, y1)], [1.1, 1.1], [fn(d, mx, my)] * 2)


def barrier():
    frames = []
    cx, cy, R = 48, 52, 38
    for f in range(8):
        cv = Canvas(96)
        cv.circle(cx, cy, R, 0.07)
        band = (f / 8.0) * 2.4 - 1.2  # faixa de brilho que atravessa na diagonal

        def fn(d, mx, my):
            u = ((mx - cx) + (my - cy)) / (2 * R)
            shine = max(0.0, 1 - abs(u - band) * 4)
            return 0.2 + 0.3 * d * d + 0.4 * shine
        hex_lines(cv, cx, cy, R, 6.5, fn)
        cv.ring(cx, cy, R, 3.2, 0.62)
        cv.ring(cx, cy, R - 1, 1.2, 0.8)
        cv.ring(cx, cy, R - 5, 2.4, 0.95, a0=D(-165), a1=D(-110))  # reflexo em cima-esquerda
        cv.circle(cx - 17, cy - 19, 2.4, 1.0)
        cv.glow(2.4, 0.9, 0.16)
        fr = Frame(96)
        fr.paint_canvas(cv, ARCANE)
        for k in range(6):
            a = k * TAU / 6 + f * D(15)
            rune(fr, cx + math.cos(a) * (R + 0.5), cy + math.sin(a) * (R + 0.5), k, "#fffcf0", "#e6b43a")
        frames.append(fr)
    piece("arcane_barrier_shield", frames, pivot=(48, 90), blend="add", plane="billboard", fps=10, loop=True)
    return frames


def cast_circle():
    """Circulo de conjuracao: aros, runas douradas e a flor de ipe de 5 petalas girando (motivo de Pindorama)."""
    frames = []
    c = 48
    for f in range(8):
        cv = Canvas(96)
        cv.ring(c, c, 44, 2.2, 0.7)
        cv.ring(c, c, 38, 1.4, 0.55)
        cv.ring(c, c, 13, 1.4, 0.6)
        rot = f * D(9)  # 72 graus / 8 quadros: laco sem salto
        for k in range(5):
            a = rot + k * TAU / 5 - math.pi / 2
            # petala: dois arcos (lente) do centro ate r=33
            pts = []
            for i in range(13):
                t = i / 12
                rr = 13 + t * 21
                off = math.sin(t * math.pi) * 0.34
                pts.append((c + math.cos(a + off) * rr, c + math.sin(a + off) * rr))
            for i in range(12, -1, -1):
                t = i / 12
                rr = 13 + t * 21
                off = -math.sin(t * math.pi) * 0.34
                pts.append((c + math.cos(a + off) * rr, c + math.sin(a + off) * rr))
            cv.stroke(pts, [1.7] * len(pts), [0.72] * len(pts))
            cv.spike(c, c, a, 16, 30, 2.6, 0.42)
        cv.circle(c, c, 4, 0.9)
        cv.circle(c, c, 7, 0.4)
        cv.glow(2.0, 0.9, 0.14)
        fr = Frame(96)
        fr.paint_canvas(cv, ARCANE)
        for k in range(12):
            a = -f * D(3.75) + k * TAU / 12
            rune(fr, c + math.cos(a) * 41, c + math.sin(a) * 41, k, "#fffcf0", "#e6b43a")
        frames.append(fr)
    piece("arcane_cast_circle", frames, pivot=(48, 48), blend="add", plane="flat", fps=12, loop=True,
          texel=2.4 / 96.0)
    return frames


ALL = [firm_strike_slash, firm_strike_impact, charge_dust, charge_impact, charge_stun, clearing_sweep,
       horizon_wave, steel_spin, iron_stance, spark_projectile, spark_impact, wisp_projectile, wisp_impact,
       creeping_ground, flame_tongue, frost_cone, frost_crystal, frost_chill, star_fall_star, star_fall_warning,
       star_fall_impact, star_fall_burst, barrier, cast_circle]

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
detect_3d/compress_to=0
process/fix_alpha_border=false
"""


def _entry(name, p):
    return (f"\t&\"{name}\": {{\"frames\": {len(p['frames'])}, \"size\": Vector2i({p['w']}, {p['h']}), "
            f"\"pivot\": Vector2({p['pivot'][0]}, {p['pivot'][1]}), \"blend\": &\"{p['blend']}\", "
            f"\"plane\": &\"{p['plane']}\", \"fps\": {float(p['fps'])}, "
            f"\"loop\": {'true' if p['loop'] else 'false'}, \"texel\": {p['texel']:.6f}}},")


def write_table(merge: bool = False):
    """Tabela lida pelo jogo. merge=True (--only): mantem as linhas das pecas que nao foram refeitas."""
    entries: dict[str, str] = {}
    if merge and os.path.exists(TABLE):
        for ln in open(TABLE, encoding="utf-8").read().splitlines():
            if ln.startswith("\t&\""):
                entries[ln.split("\"")[1]] = ln
    for name, p in PIECES.items():
        if "w" in p:
            entries[name] = _entry(name, p)
    lines = ["# GERADO por game/tools/art/fx/gen_skill_fx.py — nao editar a mao.",
             "class_name SkillFxSheets", "extends RefCounted",
             "## Folhas dos efeitos de skill: quadros, pivo (px), blend, plano, fps, laco e texel (m por px).", "",
             "const DIR: String = \"res://assets/fx/skills/\"", "", "const SHEETS: Dictionary = {"]
    lines += list(entries.values())
    lines += ["}", ""]
    open(TABLE, "w", encoding="utf-8").write("\n".join(lines))


def preview(out_dir, results):
    os.makedirs(out_dir, exist_ok=True)
    bgs = [(24, 22, 30), (104, 150, 70), (222, 206, 170)]  # noite, grama e terra clara do Campo  # noite e grama (verifica leitura no aditivo e no normal)
    rows = []
    for name, frames in results:
        p = PIECES[name]
        w, h = p["w"], p["h"]
        scale = 2 if w <= 96 else 1
        row = Image.new("RGB", (len(frames) * w * scale, h * scale * len(bgs)), (0, 0, 0))
        for bi, bg in enumerate(bgs):
            for i, fr in enumerate(frames):
                base = np.zeros((h, w, 3), dtype=np.float32) + np.array(bg, dtype=np.float32)
                src = fr.rgba.astype(np.float32)
                a = src[..., 3:4] / 255.0
                comp = base * (1 - a) + src[..., :3] * a
                if p["blend"] == "add":  # como no jogo: forma normal + a mesma folha somada (SkillFxSprite.GLOW_GAIN)
                    comp = np.clip(comp + src[..., :3] * a * 0.55, 0, 255)
                im = Image.fromarray(comp.astype(np.uint8), "RGB").resize((w * scale, h * scale), Image.NEAREST)
                row.paste(im, (i * w * scale, bi * h * scale))
        row.save(os.path.join(out_dir, f"sheet_{name}.png"))
        rows.append((name, row))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=os.path.join(GAME, "..", ".work", "fx", "sheets"))
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    # Arvores da Terra de Pindorama (30/09/2026): um modulo por escola, todos registrando em fxdraw.PIECES.
    import fx_status  # noqa: E402
    import fx_melee  # noqa: E402
    import fx_arcane2  # noqa: E402
    import fx_bow  # noqa: E402
    import fx_hybrid  # noqa: E402
    import fx_support  # noqa: E402
    import fx_tank  # noqa: E402
    import fx_portal  # noqa: E402
    todo = ALL + fx_status.ALL + fx_melee.ALL + fx_arcane2.ALL + fx_bow.ALL + fx_hybrid.ALL + fx_support.ALL \
        + fx_tank.ALL + fx_portal.ALL
    only = [o for o in a.only.split(",") if o]
    results = []
    for fn in todo:
        if only and not any(o in fn.__name__ for o in only):
            continue
        before = set(PIECES)
        out = fn()
        new = [k for k in PIECES if k not in before]
        groups = out if isinstance(out, tuple) else (out,)
        for name, frames in zip(new, groups):
            PIECES[name]["w"], PIECES[name]["h"] = frames[0].w, frames[0].h
            path = os.path.join(OUT, name + ".png")
            if os.path.exists(os.path.join(OUT, name + ".json")):
                print(f"{name}: mantida (folha importada de GIF, {name}.json)")
                continue
            sheet(frames).save(path)
            if not os.path.exists(path + ".import"):
                open(path + ".import", "w").write(IMPORT)
            results.append((name, frames))
            print(f"{name}: {len(frames)} quadros {frames[0].w}x{frames[0].h}")
    write_table(merge=bool(only))
    preview(a.preview, results)


if __name__ == "__main__":
    main()
