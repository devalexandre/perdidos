"""Portal dos mapas (30/09/2026, pedido do dono: "como no Ragnarok", mas com arte 100% nossa).

Duas folhas, feitas aqui por script, quadro a quadro:
  - portal_ground: redemoinho de luz DEITADO no chao, com seis bracos finos em espiral girando devagar, aneis finos
    que correm para o centro, borda de luz quebrada em tracos e pontinhos brilhando. Laco de 12 quadros =
    1/6 de volta (seis bracos iguais), sem salto.
  - portal_column: brilho suave em coluna, bem transparente (nao cobre ninguem), com fagulhas e pontinhos
    subindo.
Azul-claro e branco. Sem estrela, hexagrama, pentagrama ou cruz: so espirais, aneis e pontos."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Ramp, piece, rng

TAU = math.tau
# azul-claro -> branco; as faixas escuras quase transparentes (o chao aparece por baixo, de dia e de noite)
PORTAL = Ramp(["#0c2a4a", "#1c5a9a", "#3a96dc", "#7cccf4", "#d2f2ff", "#ffffff"],
              [0.05, 0.16, 0.32, 0.5, 0.7, 0.88], [26, 110, 220, 255, 255, 255])
COLUMN = Ramp(["#1c5a9a", "#3a96dc", "#7cccf4", "#d2f2ff", "#ffffff"],
              [0.06, 0.2, 0.42, 0.66, 0.86], [18, 60, 150, 230, 255])
N_FRAMES = 12
R_DESIGN_PX = 84      # raio desenhado (px)
R_WORLD_M = 1.3       # raio no mundo (m): ~2,6 celulas de diametro


def portal_ground():
    frames = []
    size = 192
    c = size / 2
    r = rng(7000)
    dots = [(r.uniform(0, TAU), r.uniform(10, 80), r.uniform(0, 1)) for _ in range(30)]
    for f in range(N_FRAMES):
        ph = f / N_FRAMES
        rot = ph * TAU / 6          # 1/6 de volta por laco (seis bracos iguais)
        cv = Canvas(size)
        dx, dy = cv.X - c, cv.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        # veu muito leve dentro (so a faixa escura, quase transparente)
        cv.put((d < R_DESIGN_PX).astype(np.float32) * np.clip(1 - d / R_DESIGN_PX, 0, 1) ** 0.5, 0.1)
        # seis bracos em espiral: claros perto do centro, afinando para fora
        for k in range(6):  # seis bracos finos: redemoinho, nao simbolo de tres pernas
            base = rot + k * TAU / 6
            pts, ws, vs = [], [], []
            for i in range(40):
                t = i / 39
                rr = 6 + t * (R_DESIGN_PX - 8)
                ang = base + t * 3.2
                pts.append((c + math.cos(ang) * rr, c + math.sin(ang) * rr))
                ws.append(0.8 + 3.2 * math.sin(t * math.pi) ** 0.8)
                vs.append(0.95 - 0.45 * t)
            cv.stroke(pts, ws, [v * 0.55 for v in vs])
            cv.stroke(pts, [w * 0.4 for w in ws], vs)
        # aneis finos correndo para o centro (tres em fase)
        for k in range(3):
            u = (ph + k / 3) % 1.0
            rr = R_DESIGN_PX * (1 - u) * 0.92 + 6
            broken = (np.sin(a * 7 + k * 2 + rot * 3) > -0.5)
            cv.put(((np.abs(d - rr) < 1.3) & broken).astype(np.float32), 0.55 * (0.4 + 0.6 * u))
        # borda de luz em tracos (nao um aro liso), girando ao contrario
        seg = (np.sin(a * 12 - rot * 4) > -0.2)
        cv.put(((np.abs(d - (R_DESIGN_PX - 2)) < 2.0) & seg).astype(np.float32), 0.62)
        cv.put(((np.abs(d - (R_DESIGN_PX - 7)) < 0.9)).astype(np.float32), 0.32)
        # miolo
        cv.circle(c, c, 9, 0.8)
        cv.circle(c, c, 4.5, 1.0)
        cv.glow(3.0, 0.9, 0.14)
        fr = Frame(size)
        fr.paint_canvas(cv, PORTAL)
        for (da, dr, dp) in dots:  # pontinhos girando junto, piscando
            aa = da + rot * 1.5
            x, y = c + math.cos(aa) * dr, c + math.sin(aa) * dr
            if (ph + dp) % 1.0 < 0.5:
                fr.twinkle(x, y, 1 if (ph + dp) % 1.0 < 0.25 else 2, "#ffffff", "#9fdcff")
        frames.append(fr)
    piece("portal_ground", frames, pivot=(96, 96), blend="add", plane="flat", fps=8, loop=True,
          texel=R_WORLD_M / R_DESIGN_PX)
    return frames


def portal_column():
    frames = []
    w, h = 96, 192
    r = rng(7100)
    motes = [(r.uniform(-30, 30), r.uniform(0, 1), r.uniform(0.6, 1.4), int(r.integers(0, 3))) for _ in range(22)]
    for f in range(N_FRAMES):
        ph = f / N_FRAMES
        cv = Canvas(w, h)
        # coluna: faixas verticais bem fracas, mais fortes embaixo, sumindo no alto
        for k in range(5):
            x = w / 2 + (k - 2) * 9 + math.sin(ph * TAU + k) * 1.5
            top = 30 + (k % 2) * 20
            cv.stroke([(x, h - 6), (x, top)], [5.0 - abs(k - 2), 0.6], [0.26 - 0.03 * abs(k - 2), 0.05])
        cv.glow(3.0, 0.9, 0.08)
        fr = Frame(w, h)
        fr.paint_canvas(cv, COLUMN)
        for (dx, p0, sp, kind) in motes:  # fagulhas subindo
            u = (ph * sp + p0) % 1.0
            x = w / 2 + dx * (1 - 0.4 * u) + math.sin(u * 9 + dx) * 2
            y = h - 8 - u * (h - 30)
            if u > 0.9:
                continue
            if kind == 0:
                fr.twinkle(x, y, 2 if u < 0.5 else 1, "#ffffff", "#9fdcff")
            else:
                fr.px(int(x), int(y), "#d2f2ff" if kind == 1 else "#7cccf4")
                fr.px(int(x), int(y) + 1, "#3a96dc")
        frames.append(fr)
    piece("portal_column", frames, pivot=(48, 188), blend="add", plane="billboard", fps=10, loop=True)
    return frames


ALL = [portal_ground, portal_column]
