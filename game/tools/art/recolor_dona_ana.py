#!/usr/bin/env python3
"""Dona Ana (06/10/2026): folhas derivadas da Vó Aninha (assets/npcs/npc_elder_aninha_*), recoloridas
para não ser a mesma senhora: saia verde -> vinho e lenço laranja -> azul anil (o creme da estampa fica).

Reaproveitar antes de criar: mesma arte (Bria.ai, licença comercial; ver assets/_reference/npcs/REGISTRO.md),
só a cor muda. Determinístico. Rode a partir de game/:

    ../.tools/pyvenv/bin/python3 tools/art/recolor_dona_ana.py

Regras por quadro (96x96):
- saia: maior região verde ligada (as folhas do cesto são regiões separadas e ficam verdes);
- lenço: tons laranja/vermelho fortes na parte de cima da figura, fora do retângulo do rosto (a pele e o
  blush do rosto ficam como estão).
"""
from __future__ import annotations

import colorsys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[2]
SRC = GAME / "assets/npcs/npc_elder_aninha_{anim}.png"
DST = GAME / "assets/npcs/npc_dona_ana_{anim}.png"
ANIMS = ("idle", "walk")
FRAME = 96
SKIRT_HUE = 345 / 360.0  # vinho
SCARF_HUE = 215 / 360.0  # azul anil
# Parte de cima da figura onde fica o lenço (fração da altura do quadro ocupada).
HEAD_FRACTION = 0.36
# Tons de pele da Vó Aninha (rosto), para achar o rosto e não pintá-lo.
SKIN = {(200, 130, 69), (204, 139, 91), (203, 151, 97), (220, 180, 133), (180, 110, 54)}


def components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    h, w = mask.shape
    seen = np.zeros(mask.shape, bool)
    out: list[list[tuple[int, int]]] = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            seen[y, x] = True
            q = deque([(y, x)])
            pts: list[tuple[int, int]] = []
            while q:
                cy, cx = q.popleft()
                pts.append((cy, cx))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            out.append(pts)
    return out


def recolor_frame(f: np.ndarray) -> np.ndarray:
    a = f[:, :, 3] > 128
    ys = np.nonzero(a)[0]
    if len(ys) == 0:
        return f
    hsv = np.zeros(f.shape[:2] + (3,))
    for y, x in zip(*np.nonzero(a)):
        hsv[y, x] = colorsys.rgb_to_hsv(*(f[y, x, :3] / 255.0))
    H, S, V = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    top, height = ys.min(), ys.max() - ys.min()
    out = f.copy()

    def paint(y: int, x: int, hue: float, sat_mul: float = 1.0, val_mul: float = 1.0) -> None:
        r, g, b = colorsys.hsv_to_rgb(hue, min(1.0, S[y, x] * sat_mul), min(1.0, V[y, x] * val_mul))
        out[y, x, :3] = [int(r * 255), int(g * 255), int(b * 255)]

    green = a & (H > 0.15) & (H < 0.30) & (S > 0.2)
    regions = sorted(components(green), key=len, reverse=True)
    if regions:
        for y, x in regions[0]:
            paint(y, x, SKIRT_HUE, 1.25, 1.05)

    head = a.copy()
    head[int(top + height * HEAD_FRACTION):, :] = False
    skin = np.zeros(a.shape, bool)
    for y, x in zip(*np.nonzero(head)):
        skin[y, x] = tuple(int(v) for v in f[y, x, :3]) in SKIN
    faces = sorted(components(skin), key=len, reverse=True)
    fy0 = fy1 = fx0 = fx1 = -1
    if faces and len(faces[0]) > 20:
        fy0, fy1 = min(p[0] for p in faces[0]), max(p[0] for p in faces[0])
        fx0, fx1 = min(p[1] for p in faces[0]), max(p[1] for p in faces[0])
    for y, x in zip(*np.nonzero(head)):
        if fy0 <= y <= fy1 + 1 and fx0 - 2 <= x <= fx1 + 2:
            continue
        if H[y, x] <= 23 / 360.0 and S[y, x] > 0.35 and V[y, x] > 0.53:
            paint(y, x, SCARF_HUE)
    return out


## Limite do validate_art: no máximo MAX_COLORS cores opacas por folha (o recolor cria tons novos).
MAX_COLORS = 48


def limit_colors(im: np.ndarray, n: int = MAX_COLORS) -> np.ndarray:
    opaque = im[..., 3] > 0
    if len({tuple(c) for c in im[opaque][:, :3]}) <= n:
        return im
    rgb = im[..., :3].copy()
    rgb[~opaque] = im[opaque][0, :3]  # transparentes não gastam cor da paleta
    q = Image.fromarray(rgb).quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = im.copy()
    out[..., :3] = np.array(q.convert("RGB"))
    return out


def main() -> None:
    for anim in ANIMS:
        im = np.array(Image.open(str(SRC).format(anim=anim)).convert("RGBA"))
        for fy in range(0, im.shape[0], FRAME):
            for fx in range(0, im.shape[1], FRAME):
                im[fy:fy + FRAME, fx:fx + FRAME] = recolor_frame(im[fy:fy + FRAME, fx:fx + FRAME])
        dst = Path(str(DST).format(anim=anim))
        Image.fromarray(limit_colors(im)).save(dst)
        print(f"{dst.relative_to(GAME)} {im.shape[1]}x{im.shape[0]}")


if __name__ == "__main__":
    main()
