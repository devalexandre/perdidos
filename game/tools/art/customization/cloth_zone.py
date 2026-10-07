"""Marca a zona da cabeça no canal alfa das máscaras do corpo-base (roupa por nacionalidade, GDD §4.0).

A troca de cor da roupa (shader char_palette_swap*, CharacterLayers.recolor_cloth) só vale para pixels
da máscara com alfa 255. Esta ferramenta põe alfa 128 nos pixels sem marca (roupa) que ficam na cabeça,
para o recolor não pegar rosto nem mechas de cabelo pintadas no corpo-base. O tecido azul (gola do capuz)
dentro da zona continua com 255.

Zona da cabeça por quadro 96x96: caixa dos pixels de olhos (G) e cabelo raspado (B) da máscara,
alargada MARGIN_X para os lados, do topo do quadro até MARGIN_BOTTOM abaixo da caixa. Quadro sem G nem B fica sem zona.

Reexecutável (parte das máscaras atuais, zera marcas anteriores). Rodar depois de qualquer etapa que
regenere as máscaras:  python3 tools/art/customization/cloth_zone.py
"""
import glob
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
BASE = os.path.join(GAME, 'assets', 'characters', 'base')
FR = 96
MARGIN_X = 14
MARGIN_BOTTOM = 10
HEAD_ALPHA = 128
MARK = 5


def zone_frame(m: np.ndarray) -> np.ndarray:
    """m: quadro RGBA da máscara. Retorna um booleano (FR, FR) da zona da cabeça."""
    head = (m[:, :, 1] > MARK) | (m[:, :, 2] > MARK)
    zone = np.zeros(m.shape[:2], dtype=bool)
    ys, xs = np.nonzero(head)
    if len(ys) == 0:
        return zone
    y1 = min(FR, ys.max() + 1 + MARGIN_BOTTOM)
    x0 = max(0, xs.min() - MARGIN_X)
    x1 = min(FR, xs.max() + 1 + MARGIN_X)
    zone[:y1, x0:x1] = True  # tudo acima (cabelo alto) até a base da caixa
    return zone


def blue_cloth(sheet: np.ndarray) -> np.ndarray:
    """Pixels do tecido azul (mesma faixa de matiz do recolor): a gola do capuz na zona continua recolorível."""
    rgb = sheet[:, :, :3].astype(float) / 255.0
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    d = mx - mn
    l = (mx + mn) / 2
    s = np.where((l > 0) & (l < 1), d / np.maximum(1e-6, 1 - np.abs(2 * l - 1)), 0)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    h = np.zeros_like(l)
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6, h)
    h = np.where(mx == g, (b - r) / dd + 2, h)
    h = np.where(mx == b, (r - g) / dd + 4, h)
    h = h / 6
    return (d > 1e-5) & (s >= 0.2) & (h >= 0.45) & (h < 0.70)


def process(path: str) -> int:
    m = np.array(Image.open(path).convert('RGBA'))
    sheet = np.array(Image.open(path.replace('_base_mask_', '_base_')).convert('RGBA'))
    opaque = m[:, :, 3] > 0
    m[opaque, 3] = 255
    unmarked = opaque & (m[:, :, :3].max(axis=2) <= MARK) & ~blue_cloth(sheet)
    h, w = m.shape[:2]
    count = 0
    for fy in range(0, h, FR):
        for fx in range(0, w, FR):
            fr = m[fy:fy + FR, fx:fx + FR]
            z = zone_frame(fr) & unmarked[fy:fy + FR, fx:fx + FR]
            fr[z, 3] = HEAD_ALPHA
            count += int(z.sum())
    Image.fromarray(m, 'RGBA').save(path)
    return count


def main() -> None:
    for p in sorted(glob.glob(os.path.join(BASE, 'chr_*_base_mask_*.png'))):
        print('%-44s cabeça: %5d px' % (os.path.basename(p), process(p)))


if __name__ == '__main__':
    main()
