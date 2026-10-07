#!/usr/bin/env python3
"""Tratamento em pixel art do minimapa (GDD 9.4): reduz o render ortografico (render_minimap.gd) por BOX para
SIZE px, quantiza para a PALETA MESTRA (Lab, sem dithering), realca bordas de agua/construcoes com contorno
escuro de 1 px e grava assets/minimap/minimap_<map_id>.png. A imagem cobre exatamente o minimap_world_rect.
Uso: minimap_pixel.py <raw.png> <map_id> [--size 512]"""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(HERE, 'icons')); sys.path.insert(0, os.path.join(HERE, 'anchor_pipeline')); sys.path.insert(0, os.path.join(HERE, 'character_pipeline'))
os.environ.setdefault('BK', 'x')
from gen_icons import nearest  # noqa: E402
raw, map_id = sys.argv[1], sys.argv[2]
size = int(sys.argv[sys.argv.index('--size') + 1]) if '--size' in sys.argv else 512
im = Image.open(raw).convert('RGB')
s = min(im.size); im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2))
im = im.resize((size, size), Image.BOX)
a = np.asarray(im).astype(float)
# leve aumento de contraste/saturacao para leitura em tamanho pequeno
m = a.mean(-1, keepdims=True); a = np.clip(m + (a - m) * 1.15, 0, 255); a = np.clip((a - 128) * 1.05 + 128, 0, 255)
q = nearest(a).astype(np.uint8)
# contorno: onde a luminancia muda muito entre vizinhos, escurece o lado mais escuro (1 px)
L = q.mean(-1)
edge = np.zeros(L.shape, bool)
for dy, dx in ((0, 1), (1, 0)):
    d = np.abs(L - np.roll(L, (-dy, -dx), (0, 1)))
    edge |= (d > 60) & (L < np.roll(L, (-dy, -dx), (0, 1)))
dark = nearest(q.astype(float) * 0.55).astype(np.uint8)
q[edge] = dark[edge]
os.makedirs(os.path.join(GAME, 'assets', 'minimap'), exist_ok=True)
out = os.path.join(GAME, 'assets', 'minimap', f'minimap_{map_id}.png')
Image.fromarray(q, 'RGB').save(out); print(out)
