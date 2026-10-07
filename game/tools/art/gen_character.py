#!/usr/bin/env python3
"""Gerador PROVISORIO (GDD 19) das folhas do Viajante (masculino/feminino).

Saidas (assets/characters/):
  chr_traveler_{male,female}_idle.png  -> 4 quadros x 5 linhas (S, SE, L, NE, N), quadro 64x64
  chr_traveler_{male,female}_walk.png  -> 8 quadros x 5 linhas
  chr_shadow.png                       -> sombra oval opaca (renderizador aplica 50%)
Pes no centro inferior (x=32, y=63). Somente cores da paleta mestra; contorno colorido.

O personagem e descrito por "partes" (mascara + material). Depois:
  1) sombreamento por material (luz de cima-esquerda, 3-4 tons),
  2) contorno externo de 1 px com o tom mais escuro da rampa vizinha.
Uso: python3 tools/art/gen_character.py [--preview DIR]
"""
from __future__ import annotations

import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

OUT_DIR = os.path.join(P.GAME_DIR, "assets", "characters")
W = H = 64
DIRS = ["S", "SE", "E", "NE", "N"]

# Materiais: (contorno, sombra, base, luz)
PC = P.ramp("Pele clara")
PE = P.ramp("Pele escura")
MD = P.ramp("Madeira/cabelo")
CEU = P.ramp("Azul ceu")
PED = P.ramp("Pedra/metal")
RED = P.ramp("Vermelho")
ROSA = P.ramp("Rosa")
OURO = P.ramp("Ouro/amarelo")
B1 = P.hexc("16131c")
WHITE = P.hexc("fcfaf5")

MAT = {
    "skin": (PC[1], PC[2], PC[3], PC[3]),
    "hair": (MD[0], MD[1], MD[2], MD[3]),
    "hoodie": (CEU[0], CEU[1], CEU[2], CEU[3]),  # #2f55a8 sombra / #5a90e0 base
    "jeans": (B1, B1, CEU[0], PED[1]),
    "shoe": (PED[1], PED[3], WHITE, WHITE),
    "pack": (PE[0], PE[1], PE[2], PE[3]),
}


class Fig:
    """Figura em construcao: mapa de partes (ordem de desenho = profundidade)."""

    def __init__(self) -> None:
        self.part = [[-1] * W for _ in range(H)]
        self.mats: list[str] = []
        self.flat: dict[tuple[int, int], tuple[int, int, int]] = {}

    def add(self, mat: str, pixels) -> int:
        pid = len(self.mats)
        self.mats.append(mat)
        for x, y in pixels:
            if 0 <= x < W and 0 <= y < H:
                self.part[y][x] = pid
                self.flat.pop((x, y), None)
        return pid

    def dot(self, x: int, y: int, c) -> None:
        if 0 <= x < W and 0 <= y < H and self.part[y][x] >= 0:
            self.flat[(x, y)] = c

    def mask_of(self, pid: int):
        return {(x, y) for y in range(H) for x in range(W) if self.part[y][x] == pid}

    # --- renderizacao ---
    def render(self) -> Image.Image:
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        px = img.load()

        def pid(x: int, y: int) -> int:
            if 0 <= x < W and 0 <= y < H:
                return self.part[y][x]
            return -1

        for y in range(H):
            for x in range(W):
                p = self.part[y][x]
                if p < 0:
                    continue
                o, s, b, l = MAT[self.mats[p]]
                c = b
                right, down = pid(x + 1, y), pid(x, y + 1)
                up, left = pid(x, y - 1), pid(x - 1, y)
                # borda direita/baixo da parte -> sombra (luz vem de cima-esquerda)
                if right != p or down != p or pid(x + 1, y + 1) != p:
                    c = s
                # parte na frente logo acima (mais recente) projeta sombra
                elif up > p and self.mats[up] != self.mats[p]:
                    c = s
                elif up != p and left != p and pid(x - 1, y - 1) != p:
                    c = l
                elif up != p and self.mats[p] in ("hair", "hoodie", "pack") and pid(x - 1, y) == p:
                    c = l
                px[x, y] = (*c, 255)
        for (x, y), c in self.flat.items():
            px[x, y] = (*c, 255)
        # contorno externo colorido
        out = img.copy()
        opx = out.load()
        for y in range(H):
            for x in range(W):
                if self.part[y][x] >= 0:
                    continue
                cands = []
                for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                    q = pid(x + dx, y + dy)
                    if q >= 0:
                        cands.append(MAT[self.mats[q]][0])
                if cands:
                    c = min(cands, key=lambda c: c[0] * 3 + c[1] * 6 + c[2])
                    opx[x, y] = (*c, 255)
        return out


# ---------- primitivas ----------
def ellipse(cx: float, cy: float, rx: float, ry: float):
    return {(x, y) for y in range(H) for x in range(W)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}


def rect(x0: int, y0: int, x1: int, y1: int):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def poly(points):
    m = Image.new("1", (W, H), 0)
    ImageDraw.Draw(m).polygon(points, fill=1)
    return {(x, y) for y in range(H) for x in range(W) if m.getpixel((x, y))}


def limb(x0: float, y0: int, x1: float, y1: int, w: int):
    """Membro vertical de largura w do centro (x0,y0) ate (x1,y1)."""
    pts = set()
    n = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        t = (y - y0) / n
        cx = x0 + (x1 - x0) * t
        xs = int(math.floor(cx - w / 2.0 + 0.5))
        for x in range(xs, xs + w):
            pts.add((x, y))
    return pts


# ---------- pose ----------
class Pose:
    def __init__(self, bob: int = 0, legs=((0, 0, 0), (0, 0, 0)), arms=(0, 0)) -> None:
        self.bob = bob
        self.legs = legs  # por perna: (dx do pe, dy do pe (negativo = sobe), -)
        self.arms = arms  # balanco da mao (dx no perfil / dy de frente)


def walk_pose(f: int, d: str) -> Pose:
    p = 2 * math.pi * f / 8.0
    legs = []
    for sign in (1, -1):
        pos = sign * math.sin(p)          # +1 = perna a frente
        vel = sign * math.cos(p)          # >0 = perna em balanco
        lift = int(round(1.6 * max(0.0, vel))) if vel > 0.3 else 0
        if d == "E":
            dx = int(round(pos * 4))
            dy = -lift
        elif d in ("SE", "NE"):
            dx = int(round(pos * 2.4))
            away = -pos if d == "SE" else pos
            dy = -int(round(max(0.0, away) * 1.2)) - lift
        else:
            dx = 0
            away = -pos if d == "S" else pos
            dy = -int(round(max(0.0, away) * 1.5)) - lift
        legs.append((dx, dy, 0))
    bob = 1 if abs(math.sin(p)) > 0.7 else 0
    swing = math.sin(p)
    arms = (int(round(-swing * 2.5)), int(round(swing * 2.5)))
    return Pose(bob, tuple(legs), arms)


IDLE_BOB = [0, 0, 1, 1]


# ---------- personagem ----------
def build(body: str, d: str, pose: Pose) -> Image.Image:
    fem = body == "female"
    f = Fig()
    b = pose.bob
    hip = 46 + b
    head_cy = 21.2 + b
    head = ellipse(32, head_cy, 9.7, 8.6)
    hoodie_top = 29 + b

    # ----- pernas -----
    def legs(hips_x: list[float], toe: int) -> None:
        order = [0, 1]
        # no perfil a perna de tras (dx menor) e desenhada primeiro
        if d == "E":
            order.sort(key=lambda i: pose.legs[i][0])
        for i in order:
            dx, dy, _ = pose.legs[i]
            hx = hips_x[i]
            fx = hx + dx
            fy = 62 + dy
            f.add("jeans", limb(hx, hip, fx, fy - 3, 4))
            fxi = int(math.floor(fx + 0.5))
            if d == "E":
                shoe = rect(fxi - 2, fy - 2, fxi + 2, fy) | rect(fxi + 3, fy - 1, fxi + 3, fy)
                f.add("shoe", shoe)
                f.dot(fxi - 1, fy - 1, RED[2])
                f.dot(fxi, fy - 1, RED[2])
            else:
                x0 = fxi - 2 + (1 if toe > 0 and i == 1 else 0)
                shoe = rect(x0 - (1 if i == 0 else 0), fy - 2, x0 + 3 + (1 if i == 1 else 0), fy)
                f.add("shoe", shoe)
                if d in ("N", "NE"):
                    f.dot(x0 + 1, fy, RED[2])
                    f.dot(x0 + 2, fy, RED[2])
                else:
                    sx = x0 - 1 if i == 0 else x0 + 4
                    f.dot(sx, fy - 1, RED[2])

    # ----- cabelo helpers -----
    def male_spikes(pts):
        f.add("hair", pts)

    if d == "S":
        if fem:  # ponta do rabo de cavalo aparecendo
            f.add("hair", poly([(40, 22 + b), (43, 25 + b), (43, 31 + b), (41, 33 + b), (40, 28 + b)]))
        f.add("pack", rect(24, 31 + b, 25, 39 + b) | rect(39, 31 + b, 40, 39 + b))
        legs([29.5, 34.5], 0)
        f.add("hoodie", poly([(26, hoodie_top), (38, hoodie_top), (39, 31 + b), (38, 45 + b),
                              (26, 45 + b), (25, 31 + b)]))
        for i, (ax, sgn) in enumerate(((24, -1), (40, 1))):
            hy = 42 + b + (pose.arms[i] if False else 0)
            dy = 1 if pose.arms[i] > 1 else (-1 if pose.arms[i] < -1 else 0)
            f.add("hoodie", limb(ax, 30 + b, ax + sgn * 0.5, 41 + b + dy, 3))
            f.add("skin", rect(ax - 1 + (1 if sgn > 0 else 0), 42 + b + dy, ax + (1 if sgn > 0 else 0), 43 + b + dy))
        # bolso canguru + cordoes + alcas
        for x in range(29, 36):
            f.dot(x, 38 + b, CEU[1])
        f.dot(28, 39 + b, CEU[1]); f.dot(36, 39 + b, CEU[1])
        for y in range(39, 42):
            f.dot(28, y + b, CEU[1]); f.dot(36, y + b, CEU[1])
        for x in range(26, 39):
            f.dot(x, 44 + b, CEU[1])
        for y in range(30, 36):
            f.dot(27, y + b, PE[1]); f.dot(37, y + b, PE[1])
        f.dot(31, 31 + b, WHITE); f.dot(31, 32 + b, WHITE)
        f.dot(33, 31 + b, WHITE); f.dot(33, 32 + b, WHITE)
        # cabeca
        f.add("hair", head)
        face = ellipse(32, head_cy + 2.2, 7.6, 6.6) & head
        if fem:
            bang = lambda x: 17 + b + (0 if x > 34 else (1 if x > 30 else 2)) if 25 <= x <= 39 else 99
        else:
            pat = [2, 1, 2, 3, 1, 2, 3, 2, 1, 2, 3, 1, 2, 1, 2]
            bang = lambda x: 16 + b + pat[x - 25] if 25 <= x <= 39 else 99
        face = {(x, y) for (x, y) in face if y >= bang(x)}
        if fem:  # mechas laterais longas emoldurando o rosto
            face = {(x, y) for (x, y) in face if 26 <= x <= 38}
        else:
            face = {(x, y) for (x, y) in face if not ((x <= 25 or x >= 39) and y < head_cy + 2)}
        f.add("skin", face)
        if fem:
            f.add("hair", rect(23, 20 + b, 25, 29 + b) | rect(39, 20 + b, 41, 29 + b))
        else:
            male_spikes({(26, 12 + b), (27, 12 + b), (29, 11 + b), (30, 11 + b), (30, 12 + b),
                         (34, 11 + b), (35, 12 + b), (37, 12 + b), (38, 13 + b)})
        eyes(f, [(27, 22 + b), (36, 22 + b)], fem)
        f.dot(32, 27 + b, PC[0])
        f.dot(26, 26 + b, ROSA[2]); f.dot(38, 26 + b, ROSA[2])
        if fem:
            f.dot(39, 17 + b, RED[2]); f.dot(40, 18 + b, RED[2])

    elif d == "SE":
        if fem:
            f.add("hair", poly([(23, 18 + b), (20, 22 + b), (20, 30 + b), (22, 33 + b), (24, 28 + b)]))
        f.add("pack", rect(23, 31 + b, 26, 40 + b))
        legs([29.5, 34.5], 1)
        f.add("hoodie", poly([(26, hoodie_top), (38, hoodie_top), (39, 31 + b), (38, 45 + b),
                              (27, 45 + b), (26, 31 + b)]))
        for i, (ax, sgn) in enumerate(((25, -1), (40, 1))):
            dy = 1 if pose.arms[i] > 1 else (-1 if pose.arms[i] < -1 else 0)
            f.add("hoodie", limb(ax, 30 + b, ax + sgn * 0.5 + (1 if i == 1 else 0) * (dy), 41 + b + dy, 3))
            hx = ax + (1 if sgn > 0 else 0) + (dy if i == 1 else 0)
            f.add("skin", rect(hx - 1, 42 + b + dy, hx, 43 + b + dy))
        for x in range(30, 37):
            f.dot(x, 38 + b, CEU[1])
        for y in range(39, 42):
            f.dot(29, y + b, CEU[1]); f.dot(37, y + b, CEU[1])
        for x in range(27, 39):
            f.dot(x, 44 + b, CEU[1])
        for y in range(30, 36):
            f.dot(28, y + b, PE[1]); f.dot(37, y + b, PE[1])
        f.dot(33, 31 + b, WHITE); f.dot(33, 32 + b, WHITE)
        f.dot(35, 31 + b, WHITE); f.dot(35, 32 + b, WHITE)
        f.add("hair", head)
        face = ellipse(34, head_cy + 2.2, 7.0, 6.6) & head
        if fem:
            bang = lambda x: 17 + b + (0 if x > 36 else (1 if x > 32 else 2)) if 27 <= x <= 41 else 99
        else:
            pat = [1, 2, 3, 1, 2, 3, 2, 1, 2, 3, 2, 1, 2, 1, 2]
            bang = lambda x: 16 + b + pat[x - 27] if 27 <= x <= 41 else 99
        face = {(x, y) for (x, y) in face if y >= bang(x) and x >= 28}
        f.add("skin", face)
        f.add("skin", rect(27, 22 + b, 27, 24 + b))  # orelha
        f.dot(27, 23 + b, PC[1])
        if fem:
            f.add("hair", rect(25, 20 + b, 26, 28 + b))
        else:
            male_spikes({(25, 13 + b), (27, 12 + b), (28, 11 + b), (31, 11 + b), (32, 12 + b),
                         (35, 11 + b), (36, 12 + b), (38, 13 + b), (23, 17 + b), (23, 18 + b)})
        eyes(f, [(30, 22 + b), (37, 22 + b)], fem, far=0)
        f.dot(35, 27 + b, PC[0])
        f.dot(38, 26 + b, ROSA[2]); f.dot(29, 26 + b, ROSA[2])
        if fem:
            f.dot(24, 18 + b, RED[2]); f.dot(24, 19 + b, RED[2])

    elif d == "E":
        # braco de tras (espreita no balanco)
        if pose.arms[1] > 1:
            f.add("hoodie", limb(34, 31 + b, 34 + pose.arms[1], 41 + b, 3))
            f.add("skin", rect(33 + pose.arms[1], 42 + b, 35 + pose.arms[1], 43 + b))
        legs([32.0, 32.0], 0)
        f.add("pack", poly([(24, 31 + b), (28, 30 + b), (28, 43 + b), (24, 42 + b), (23, 38 + b)]))
        f.add("hoodie", poly([(28, hoodie_top), (36, hoodie_top), (37, 32 + b), (37, 45 + b),
                              (28, 45 + b), (27, 31 + b)]))
        for x in range(28, 37):
            f.dot(x, 44 + b, CEU[1])
        for y in range(31, 38):
            f.dot(28, y + b, PE[1])
        f.dot(25, 35 + b, OURO[2])
        # capuz nas costas
        f.add("hoodie", poly([(26, 26 + b), (30, 27 + b), (30, 32 + b), (27, 32 + b), (25, 29 + b)]))
        ax = pose.arms[0]
        f.add("hoodie", limb(31.5, 30 + b, 31.5 + ax, 41 + b, 4))
        f.add("skin", rect(31 + ax, 42 + b, 33 + ax, 43 + b))
        if fem:
            f.add("hair", poly([(25, 16 + b), (21, 18 + b), (19, 24 + b), (20, 31 + b), (22, 33 + b), (24, 27 + b)]))
        f.add("hair", head)
        face = ellipse(35, head_cy + 2.0, 6.4, 6.6) & head
        if fem:
            bang = lambda x: 17 + b + (0 if x > 38 else 1) if x >= 33 else 99
        else:
            pat = [2, 3, 1, 2, 3, 1, 2, 2, 1, 1]
            bang = lambda x: 16 + b + pat[x - 32] if 32 <= x <= 41 else 99
        face = {(x, y) for (x, y) in face if y >= bang(x) and x >= 32}
        f.add("skin", face | {(41, 24 + b)})
        f.add("skin", rect(31, 21 + b, 32, 24 + b))  # orelha
        f.dot(31, 22 + b, PC[1]); f.dot(31, 23 + b, PC[1])
        if not fem:
            male_spikes({(24, 15 + b), (23, 17 + b), (22, 18 + b), (23, 20 + b), (27, 12 + b),
                         (30, 11 + b), (31, 11 + b), (34, 11 + b), (36, 12 + b), (24, 25 + b), (25, 27 + b)})
        else:
            f.dot(24, 17 + b, RED[2]); f.dot(24, 18 + b, RED[2])
        eyes(f, [(37, 22 + b)], fem, far=None)
        f.dot(39, 27 + b, PC[0])
        f.dot(36, 26 + b, ROSA[2])

    elif d == "NE":
        legs([29.5, 34.5], 1)
        f.add("hoodie", poly([(26, hoodie_top), (38, hoodie_top), (39, 31 + b), (38, 45 + b),
                              (26, 45 + b), (25, 31 + b)]))
        for i, (ax, sgn) in enumerate(((24, -1), (40, 1))):
            dy = 1 if pose.arms[i] > 1 else (-1 if pose.arms[i] < -1 else 0)
            f.add("hoodie", limb(ax, 30 + b, ax + sgn * 0.5, 41 + b - dy, 3))
            f.add("skin", rect(ax - 1 + (1 if sgn > 0 else 0), 42 + b - dy, ax + (1 if sgn > 0 else 0), 43 + b - dy))
        for x in range(26, 39):
            f.dot(x, 44 + b, CEU[1])
        f.add("hoodie", poly([(27, 28 + b), (35, 28 + b), (34, 31 + b), (28, 31 + b)]))
        f.add("pack", rect(26, 31 + b, 35, 43 + b) - {(26, 31 + b), (35, 31 + b)})
        for x in range(27, 35):
            f.dot(x, 34 + b, PE[1])
        for x in range(28, 34):
            f.dot(x, 39 + b, PE[1])
        f.dot(30, 35 + b, OURO[2]); f.dot(31, 35 + b, OURO[2])
        for y in range(31, 38):
            f.dot(36, y + b, PE[1])
        f.add("hair", head)
        f.add("skin", ellipse(39.8, head_cy + 2.8, 2.4, 4.6) & head - rect(0, 0, 63, int(head_cy - 1)))
        if not fem:
            male_spikes({(26, 12 + b), (29, 11 + b), (30, 11 + b), (34, 11 + b), (37, 12 + b),
                         (27, 29 + b), (30, 30 + b), (33, 29 + b), (36, 29 + b)})
        else:
            f.add("hair", poly([(30, 20 + b), (34, 20 + b), (35, 26 + b), (34, 33 + b), (32, 35 + b), (30, 33 + b), (29, 26 + b)]))
            f.dot(31, 20 + b, RED[2]); f.dot(32, 20 + b, RED[2]); f.dot(33, 20 + b, RED[2])

    else:  # N
        legs([29.5, 34.5], 0)
        f.add("hoodie", poly([(26, hoodie_top), (38, hoodie_top), (39, 31 + b), (38, 45 + b),
                              (26, 45 + b), (25, 31 + b)]))
        for i, (ax, sgn) in enumerate(((24, -1), (40, 1))):
            dy = 1 if pose.arms[i] > 1 else (-1 if pose.arms[i] < -1 else 0)
            f.add("hoodie", limb(ax, 30 + b, ax + sgn * 0.5, 41 + b - dy, 3))
            f.add("skin", rect(ax - 1 + (1 if sgn > 0 else 0), 42 + b - dy, ax + (1 if sgn > 0 else 0), 43 + b - dy))
        for x in range(26, 39):
            f.dot(x, 44 + b, CEU[1])
        f.add("hoodie", poly([(28, 28 + b), (36, 28 + b), (35, 31 + b), (29, 31 + b)]))
        f.add("pack", rect(27, 31 + b, 37, 43 + b) - {(27, 31 + b), (37, 31 + b)})
        for x in range(28, 37):
            f.dot(x, 34 + b, PE[1])
        for x in range(29, 36):
            f.dot(x, 39 + b, PE[1])
        f.dot(32, 35 + b, OURO[2])
        f.add("hair", head)
        f.add("skin", rect(23, 21 + b, 23, 24 + b) | rect(41, 21 + b, 41, 24 + b))  # orelhas
        if not fem:
            male_spikes({(26, 12 + b), (29, 11 + b), (30, 11 + b), (34, 11 + b), (35, 12 + b), (38, 13 + b),
                         (27, 29 + b), (29, 30 + b), (32, 30 + b), (35, 30 + b), (37, 29 + b)})
        else:
            f.add("hair", poly([(30, 20 + b), (34, 20 + b), (35, 26 + b), (34, 33 + b), (32, 35 + b), (30, 33 + b), (29, 26 + b)]))
            f.dot(31, 20 + b, RED[2]); f.dot(32, 20 + b, RED[2]); f.dot(33, 20 + b, RED[2])
    return f.render()


def eyes(f: Fig, positions, fem: bool, far=None) -> None:
    """Olhos grandes estilo anime 2x4: contorno escuro em cima, brilho branco, iris."""
    for i, (x, y) in enumerate(positions):
        narrow = far is not None and i == far
        xs = [x] if narrow else [x, x + 1]
        for xx in xs:
            f.dot(xx, y, MD[0])
            f.dot(xx, y + 1, MD[1])
            f.dot(xx, y + 2, MD[1])
            f.dot(xx, y + 3, MD[0])
        f.dot(xs[0], y + 1, WHITE)
        if fem:
            f.dot(xs[-1] + 1 if i == len(positions) - 1 else xs[0] - 1, y, MD[0])


def sheet(body: str, anim: str) -> Image.Image:
    n = 4 if anim == "idle" else 8
    img = Image.new("RGBA", (W * n, H * len(DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for c in range(n):
            pose = Pose(bob=IDLE_BOB[c]) if anim == "idle" else walk_pose(c, d)
            img.paste(build(body, d, pose), (c * W, r * H))
    return img


def shadow() -> Image.Image:
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((2, 3, 29, 12), fill=(*PED[0], 255))
    return img


def preview(sheets: dict[str, Image.Image], out_path: str) -> None:
    sc = 4
    bg = P.hexc("c9b08a")
    items = list(sheets.items())
    wmax = max(im.width for _, im in items) * sc
    htot = sum(im.height * sc + 12 for _, im in items)
    pv = Image.new("RGBA", (wmax + 8, htot + 8), (*bg, 255))
    sh = shadow()
    y = 4
    for _, im in items:
        base = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for r in range(im.height // H):
            for c in range(im.width // W):
                s = sh.copy()
                s.putalpha(s.getchannel("A").point(lambda a: a // 2))
                base.alpha_composite(s, (c * W + 16, r * H + 56))
        base.alpha_composite(im)
        pv.alpha_composite(base.resize((im.width * sc, im.height * sc), Image.NEAREST), (4, y))
        y += im.height * sc + 12
    pv.save(out_path)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    made: dict[str, Image.Image] = {}
    for body in ("male", "female"):
        for anim in ("idle", "walk"):
            im = sheet(body, anim)
            name = f"chr_traveler_{body}_{anim}.png"
            im.save(os.path.join(OUT_DIR, name))
            made[name] = im
    shadow().save(os.path.join(OUT_DIR, "chr_shadow.png"))
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        preview(made, os.path.join(d, "chr_preview.png"))
    print("ok:", ", ".join(made))


if __name__ == "__main__":
    main()
