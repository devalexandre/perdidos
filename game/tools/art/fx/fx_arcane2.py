"""Arcano da Terra de Pindorama (30/09/2026): Enxame de Vaga-lumes, Guarda do Cristal e Olho do Boitata.

Pecas-chave: vaga-lume de verdade (asas batendo, lanterna acesa), cacos de cristal que orbitam o aliado,
colunas de cristal que prendem, pontas de cristal brotando em volta, pedra de cristal que chove mana,
poeira de estrela que desfaz e refaz o corpo, olho em fenda da cobra de fogo e o raio que sai dele, a
cobra de fogo rastejando e os olhos em brasa."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Spr, blit, ease_out, layer, lerp, piece, rng
from fxpindorama import (ARCANE_GROUND, CRYSTAL, CRYSTAL_G, CRYSTAL_LINE, D, EMBER_G, EMBER_GROUND, FIREFLY_A,
                     FIREFLY_B, FIREFLY_PAL, MANA_G, SERPENT_EYE_PAL, SERPENT_EYE_TXT, TAU, W_GOLD, W_PALE, W_WHITE,
                     dither_alpha, drop, glow_ramp, spr)

FEET = (64, 124)
FIREFLY_G = glow_ramp(["#1c2a08", "#4a6a10", "#9cc41e", "#e0f050", "#fcffc0", "#ffffff"])


def _crystal(cv, bx, by, h, w, tilt, v_body=0.62, v_face=0.4):
    c, s = math.cos(tilt), math.sin(tilt)

    def P(x, y):
        return (bx + x * c - y * s, by + x * s + y * c)
    cv.poly([P(-w / 2, 0), P(-w / 2, -h * 0.72), P(0, -h), P(w / 2, -h * 0.72), P(w / 2, 0)], v_body)
    cv.poly([P(-w / 2, 0), P(-w / 2, -h * 0.72), P(0, -h), P(0, 0)], v_face)
    cv.stroke([P(w * 0.12, -h * 0.05), P(w * 0.12, -h * 0.8)], [1.6, 1.0], [0.95, 0.95])


# ------------------------------------------------------------------ Enxame de Vaga-lumes
def firefly():
    """Vaga-lume em voo (para +x): asas batendo, lanterna do abdomen acesa com halo e rastro de pontinhos."""
    frames = []
    pal = dict(FIREFLY_PAL, w="#8a96a4", W="#c8d2dc")
    # 30/09 (captura): maior, sprite 3x e lanterna maior para ler na camera.
    a = spr(FIREFLY_A, pal, "#1a1408").scale(3).rot(-90)
    b = spr(FIREFLY_B, pal, "#1a1408").scale(3).rot(-90)
    for f in range(4):
        fr = Frame(96, 56)
        cv = Canvas(96, 56)
        cv.circle(50, 28, 17, 0.3)
        cv.circle(50, 28, 11, 0.6)
        cv.circle(50, 28, 6, 0.95)
        for k in range(5):
            cv.circle(34 - k * 8, 28 + math.sin(f + k) * 3, 3.0 - k * 0.45, 0.55 - k * 0.1)
        cv.glow(2.6, 0.9, 0.18)
        fr.paint_canvas(cv, FIREFLY_G)
        blit(fr, a if f % 2 == 0 else b, 64, 28)
        frames.append(fr)
    piece("arcane_firefly_swarm_bug", frames, pivot=(64, 28), blend="add", plane="billboard", fps=16, loop=True)
    return frames


def firefly_pop():
    """Estouro de um vaga-lume no alvo: flor de luz amarelo-esverdeada que se desfaz em pontinhos."""
    frames = []
    for f in range(6):
        fr = Frame(64)
        cv = Canvas(64)
        v = 1.0 if f < 2 else 1 - (f - 1) * 0.22
        if f < 3:
            cv.circle(32, 32, [10, 14, 8][f], 0.6)
            cv.circle(32, 32, [6, 7, 3][f], 1.0)
        for k in range(6):
            a = k * TAU / 6 + 0.3
            d = 8 + f * 5
            cv.circle(32 + math.cos(a) * d, 32 + math.sin(a) * d, 3.2 * v, 0.7 * v)
        cv.glow(2.0, 0.9, 0.16 * v)
        fr.paint_canvas(cv, FIREFLY_G)
        frames.append(fr)
    piece("arcane_firefly_swarm_pop", frames, pivot=(32, 32), blend="add", plane="billboard", fps=16)
    return frames


# ------------------------------------------------------------------ Guarda do Cristal
def crystal_shard():
    """Caco de cristal voando (para +x) — sai do conjurador para cada aliado do Cristal Repartido."""
    frames = []
    for f in range(4):
        fr = Frame(64, 32)
        cv = Canvas(64, 32)
        cv.stroke([(4, 16), (40, 16)], [0.4, 4.0], [0.2, 0.5])
        cv.glow(1.8, 0.8, 0.12)
        fr.paint_canvas(cv, CRYSTAL_G)
        sv = Canvas(64, 32)
        _crystal(sv, 46, 16, 16, 9, D(90) + f * 0.05)
        layer(fr, sv, CRYSTAL, CRYSTAL_LINE)
        if f % 2 == 0:
            fr.twinkle(54, 13, 2, W_WHITE, "#b0fff2")
        frames.append(fr)
    piece("arcane_shared_crystal_shard", frames, pivot=(50, 16), blend="mix", plane="billboard", fps=14, loop=True)
    return frames


def shared_crystal_orbit():
    """Escudo do Cristal Repartido: tres cacos de cristal girando em volta do aliado (os de tras mais
    escuros), com fio de luz entre eles. Em laco. _back e _front."""
    front, back = [], []
    for f in range(8):
        for part, dst in (("back", back), ("front", front)):
            fr = Frame(128)
            cv = Canvas(128)
            lv = Canvas(128)
            for k in range(3):
                ph = TAU * (f / 8 / 3 + k / 3)
                depth = math.sin(ph)
                if (depth >= 0) != (part == "front"):
                    continue
                x, y = 64 + math.cos(ph) * 40, 72 + depth * 12
                _crystal(cv, x, y + 12, 26 + 4 * depth, 13, math.cos(ph) * 0.3,
                         v_body=0.62 if depth >= 0 else 0.42, v_face=0.4 if depth >= 0 else 0.2)
                lv.ellipse(x, y + 14, 10, 3, 0.4)
            lv.glow(2.0, 0.8, 0.1)
            if part == "back":
                fr.paint_canvas(lv, CRYSTAL_G)
            layer(fr, cv, CRYSTAL, CRYSTAL_LINE)
            if part == "front" and f % 4 == 1:
                fr.twinkle(64 + math.cos(TAU * f / 24) * 40, 60, 2, W_WHITE, "#b0fff2")
            dst.append(fr)
    piece("arcane_shared_crystal_back", back, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    piece("arcane_shared_crystal_front", front, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return back, front


def crystal_prison():
    """Prisao de Cristal: colunas de cristal brotam em volta do alvo (4 quadros) e ficam; brilho correndo.
    _back (colunas de tras, altas) e _front (colunas da frente, mais baixas para o alvo aparecer)."""
    back, front = [], []
    cols_b = [(-30, 70, 16, D(-8)), (-12, 84, 18, 0.0), (10, 80, 17, D(4)), (28, 66, 15, D(10))]
    cols_f = [(-34, 44, 15, D(-14)), (-14, 30, 12, D(-4)), (16, 34, 13, D(6)), (34, 46, 15, D(14))]
    for f in range(8):
        g = min(1.0, ease_out((f + 1) / 4.0)) if f < 4 else 1.0
        shine = (f % 8) / 8
        for cols, dst, v in ((cols_b, back, 0.5), (cols_f, front, 0.62)):
            fr = Frame(128)
            cv = Canvas(128)
            for (dx, h, w, t) in cols:
                _crystal(cv, 64 + dx, 122, h * g, w, t, v_body=v, v_face=v - 0.2)
            layer(fr, cv, CRYSTAL, CRYSTAL_LINE)
            if dst is front:
                x = 64 + lerp(-34, 34, shine)
                fr.twinkle(x, 122 - 36 * g, 2, W_WHITE, "#b0fff2")
            dst.append(fr)
    piece("arcane_crystal_prison_back", back, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    piece("arcane_crystal_prison_front", front, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return back, front


def crystal_spike():
    """Muralha de Cristal: um bloco de pontas de cristal que brota do chao (posto em volta do conjurador)."""
    frames = []
    parts = [(0, 52, 16, 0.0), (-12, 34, 12, D(-20)), (12, 38, 13, D(18)), (-20, 18, 8, D(-40)), (20, 20, 8, D(40))]
    grow = [0.2, 0.6, 1.0, 1.08, 1.0, 1.0, 1.0, 1.0]
    for f in range(8):
        fr = Frame(96)
        cv = Canvas(96)
        g = grow[f]
        for (ox, h, w, t) in parts:
            _crystal(cv, 48 + ox, 92, h * g, w, t)
        layer(fr, cv, CRYSTAL, CRYSTAL_LINE)
        if f in (2, 5):
            fr.twinkle(48, 92 - 50 * g, 3, W_WHITE, "#b0fff2", "#46dcd2")
        frames.append(fr)
    piece("arcane_crystal_wall_spike", frames, pivot=(48, 92), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def crystal_glow_gem():
    """Brilho do Cristal: pedra de cristal flutuando acima do conjurador, girando (faces trocando) e pingando
    gotas de mana azul para baixo."""
    frames = []
    dp = drop("#d2e8ff", "#84b8f6", "#3a78de")
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        bob = math.sin(f / 8 * TAU) * 3
        cx, cy = 64, 40 + bob
        sv = Canvas(128)
        ph = f / 8 * TAU
        w = 22
        top, mid, bot = (cx, cy - 22), cy - 4, (cx, cy + 20)
        l, r = (cx - w * 0.6, mid), (cx + w * 0.6, mid)
        fx = cx + math.cos(ph) * w * 0.35
        sv.poly([top, l, bot, r], 0.5)
        sv.poly([top, (fx, mid), bot, r], 0.7)
        sv.poly([top, l, (fx, mid)], 0.9)
        layer(fr, sv, CRYSTAL, CRYSTAL_LINE)
        for k in range(4):
            u = (f / 8 + k / 4) % 1.0
            blit(fr, dp, cx + (k - 1.5) * 12, cy + 24 + u * 62, alpha=1.0 if u < 0.7 else 0.5)
        fr.twinkle(cx - 5, cy - 12, 2 if f % 2 else 3, W_WHITE, "#b0fff2")
        frames.append(fr)
    piece("arcane_crystal_glow_gem", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


# ------------------------------------------------------------------ Olho do Boitata
def star_step(out: bool):
    """Passo Estelar: o corpo vira poeira de estrela subindo em espiral (saida) ou a poeira desce e junta
    (chegada)."""
    frames = []
    r = rng(2100)
    motes = [(r.uniform(0, TAU), r.uniform(4, 22), r.uniform(10, 110), r.uniform(0, 1)) for _ in range(36)]
    for f in range(10):
        t = f / 9.0 if out else 1 - f / 9.0
        fr = Frame(128)
        cv = Canvas(128)
        col = max(0.0, 1.0 - t * 1.3)
        if col > 0:  # coluna de luz no lugar do corpo
            cv.stroke([(64, 124), (64, 124 - 100 * col)], [26 * col + 2, 8 * col + 1], [0.5, 0.35])
            cv.stroke([(64, 124), (64, 124 - 90 * col)], [8 * col + 1, 2], [0.95, 0.7])
        for (a0, rad, h, p) in motes:
            a = a0 + t * 5
            rr = rad * (1 + t * 1.5)
            y = 124 - h * (0.3 + 0.7 * min(1, col + 0.2)) - t * 40
            if y < 4:
                continue
            cv.circle(64 + math.cos(a) * rr, y, 1.8, 0.8 * (1 - t * 0.6))
        cv.glow(2.4, 0.9, 0.16)
        fr.paint_canvas(cv, CRYSTAL_G)
        for k in range(5):
            a = k * 1.3 + t * 5
            fr.twinkle(64 + math.cos(a) * 28 * (1 + t), 90 - k * 14 - t * 30, 2 if k % 2 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    name = "arcane_star_step_out" if out else "arcane_star_step_in"
    piece(name, frames, pivot=FEET, blend="add", plane="billboard", fps=18)
    return frames


def star_step_out():
    return star_step(True)


def star_step_in():
    return star_step(False)


def fire_gaze_eye():
    """Olhar de Fogo: o olho em fenda do Boitata abre acima do conjurador (fecha no fim), com labaredas."""
    frames = []
    eye = spr(SERPENT_EYE_TXT, SERPENT_EYE_PAL, "#2a0806").scale(2)
    for f in range(10):
        fr = Frame(128)
        cv = Canvas(128)
        open_k = [0.1, 0.4, 0.8, 1, 1, 1, 1, 0.8, 0.4, 0.1][f]
        for k in range(7):  # labaredas em volta do olho
            a = D(-180) + k * D(180) / 6
            ln = 10 + 4 * math.sin(f + k)
            cv.spike(64 + math.cos(a) * 30, 44 + math.sin(a) * 16, a, 0, ln * open_k, 6, 0.6)
        cv.ellipse(64, 44, 34 * open_k + 4, 16 * open_k + 2, 0.3)
        cv.glow(2.4, 0.9, 0.14)
        fr.paint_canvas(cv, EMBER_G)
        e = eye.squash(1.0, max(0.1, open_k))
        blit(fr, e, 64, 44)
        frames.append(fr)
    piece("arcane_fire_gaze_eye", frames, pivot=FEET, blend="mix", plane="billboard", fps=14)
    return frames


def fire_gaze_beam():
    """Raio do olhar (deitado no chao, do conjurador para a frente): faixa de fogo com nucleo branco e
    labaredinhas nas bordas. Desenhado para 12 m de comprimento e 1 m de largura (escalado no jogo)."""
    frames = []
    W, H = 48, 256
    for f in range(8):
        fr = Frame(W, H)
        cv = Canvas(W, H)
        v = 1.0 if f < 5 else 1 - (f - 4) * 0.25
        reach = min(1.0, (f + 1) / 3.0)
        y0 = H - 4
        y1 = y0 - (H - 12) * reach
        wob = [math.sin(i * 0.7 + f * 1.3) * 2 for i in range(12)]
        pts = [(W / 2 + wob[i], lerp(y0, y1, i / 11)) for i in range(12)]
        cv.stroke(pts, [18 * v] * 12, [0.5 * v] * 12)
        cv.stroke(pts, [8 * v] * 12, [0.8 * v] * 12)
        cv.stroke(pts, [3 * v] * 12, [1.0] * 12)
        for i in range(10):
            y = lerp(y0, y1, (i + 0.5) / 10)
            side = 1 if i % 2 else -1
            cv.spike(W / 2 + side * 7, y, D(-90) + side * D(40), 0, 8 + 3 * math.sin(f + i), 4, 0.6 * v)
        cv.glow(2.0, 0.9, 0.14 * v)
        fr.paint_canvas(cv, EMBER_G)
        frames.append(fr)
    piece("arcane_fire_gaze_beam", frames, pivot=(W // 2, H - 4), blend="add", plane="flat", fps=16,
          texel=12.0 / (H - 8))
    return frames


def fire_serpent_head():
    """Serpente de Fogo: a cobra de fogo rastejando (deitada, vista de cima, cabeca triangular para a frente),
    corpo em S com escamas escuras e labaredas nas bordas, dois olhos amarelos. Viaja pela linha."""
    frames = []
    W, H = 64, 128
    for f in range(8):
        fr = Frame(W, H)
        cv = Canvas(W, H)
        ph = f / 8 * TAU
        pts = []
        for i in range(18):
            t = i / 17
            pts.append((W / 2 + math.sin(ph - t * 9) * 11 * min(1, t * 3), 22 + t * 100))
        ws = [lerp(11, 3, (i / 17) ** 1.5) for i in range(18)]
        for i in range(2, 17):  # labaredas nas bordas (primeiro, ficam por baixo)
            x, y = pts[i]
            for sd in (-1, 1):
                if (i + (sd > 0)) % 2:
                    cv.spike(x + sd * ws[i] * 0.45, y, D(90) + sd * D(75), 0, 7 + 3 * math.sin(ph + i), 4, 0.5)
        cv.stroke(pts, ws, [0.62] * 18)
        cv.stroke(pts, [w * 0.35 for w in ws], [0.85] * 18)
        cx = W / 2
        cv.poly([(cx, 4), (cx + 9, 18), (cx + 6, 26), (cx - 6, 26), (cx - 9, 18)], 0.66)
        cv.poly([(cx, 8), (cx + 4, 17), (cx - 4, 17)], 0.8)
        cv.glow(2.0, 0.9, 0.14)
        fr.paint_canvas(cv, EMBER_G)
        for i in range(3, 17, 2):  # escamas escuras nas costas
            x, y = pts[i]
            fr.px(int(x), int(y), "#8c1e12")
            fr.px(int(x) + 1, int(y), "#8c1e12")
        for sd in (-1, 1):
            for dy in (0, 1):
                fr.px(int(cx) + sd * 5, 15 + dy, "#fff4c8")
            fr.px(int(cx) + sd * 5, 17, "#3a0e08")
        frames.append(fr)
    piece("arcane_fire_serpent_head", frames, pivot=(W // 2, 64), blend="add", plane="flat", fps=14, loop=True,
          texel=2.0 / 64.0)
    return frames


def fire_serpent_trail():
    """Rastro da serpente: chao queimando em escamas de brasa (deitado), em laco pelos 5 s."""
    frames = []
    r = rng(2200)
    scales = [(r.uniform(-20, 20), r.uniform(-28, 28), r.uniform(4, 7), r.uniform(0, TAU)) for _ in range(18)]
    for f in range(8):
        fr = Frame(64)
        cv = Canvas(64)
        ph = f / 8 * TAU
        for (x, y, sz, p) in scales:
            pul = 0.5 + 0.5 * math.sin(ph + p)
            cv.poly([(32 + x, 32 + y - sz), (32 + x + sz * 0.8, 32 + y), (32 + x, 32 + y + sz * 0.5),
                     (32 + x - sz * 0.8, 32 + y)], 0.3 + 0.5 * pul)
        for k in range(3):
            cv.spike(32 + (k - 1) * 12, 32 + math.sin(ph + k) * 8, D(-90), 0, 10 + 4 * math.sin(ph * 2 + k), 5, 0.6)
        cv.glow(2.0, 0.9, 0.12)
        fr.paint_canvas(cv, EMBER_GROUND)
        frames.append(fr)
    piece("arcane_fire_serpent_trail", frames, pivot=(32, 32), blend="add", plane="flat", fps=10, loop=True,
          texel=1.4 / 64.0)
    return frames


def ember_eyes():
    """Olhos em Brasa: dois olhos em fenda acesos na altura do rosto, com fios de fogo subindo das pontas.
    Em laco pela duracao."""
    frames = []
    eye = spr("""
.oooo..
oyYYyo.
oyykyyo
.oykyo.
..ooo..
""", {"o": "#8c1e12", "y": "#f4842a", "Y": "#fff4c8", "k": "#1a0806"}, "#2a0806")
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        for sd in (-1, 1):
            x0, y0 = 64 + sd * 7, 34
            # rastro de brilho saindo para os lados (olhos acesos), nao para cima
            pts = [(x0 + sd * (4 + i * 4), y0 + 1 + i * 0.5 + math.sin(f / 8 * TAU + i) * 1.0) for i in range(7)]
            cv.stroke(pts, [3.0, 2.6, 2.2, 1.8, 1.2, 0.8, 0.4], [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3])
        for k in range(4):  # brasinhas subindo
            u = (f / 8 + k / 4) % 1.0
            cv.circle(64 + (k - 1.5) * 8 + math.sin(u * 6) * 2, 30 - u * 22, 1.4, 0.8 * (1 - u) + 0.2)
        cv.glow(2.2, 0.9, 0.16)
        fr.paint_canvas(cv, EMBER_G)
        for sd in (-1, 1):
            blit(fr, eye if sd < 0 else eye.flip(), 64 + sd * 7, 36)
        frames.append(fr)
    piece("arcane_ember_eyes_glow", frames, pivot=FEET, blend="add", plane="billboard", fps=10, loop=True)
    return frames


ALL = [firefly, firefly_pop, crystal_shard, shared_crystal_orbit, crystal_prison, crystal_spike, crystal_glow_gem,
       star_step_out, star_step_in, fire_gaze_eye, fire_gaze_beam, fire_serpent_head, fire_serpent_trail,
       ember_eyes]
_ = (np, Spr, ARCANE_GROUND, dither_alpha, W_PALE)
