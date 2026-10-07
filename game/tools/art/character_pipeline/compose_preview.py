"""Previa do paper doll: compose_preview.py out.png body anim [camadas...]; camada = caminho base sem _<anim>.png
(ex.: assets/equipment/head/straw_hat/male). Ordem: *_back atras do corpo; o resto na frente. Roupa: --outfit <base>."""
import os, sys
from PIL import Image
a = sys.argv[1:]; out, body, anim = a[:3]; rest = a[3:]
G = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
outfit = f'{G}/assets/characters/chr_traveler_{body}'
if '--outfit' in rest: i = rest.index('--outfit'); outfit = os.path.join(G, rest[i + 1]); rest = rest[:i] + rest[i + 2:]
bodyim = Image.open(f'{outfit}_{anim}.png').convert('RGBA')
canvas = Image.new('RGBA', bodyim.size, (240, 230, 200, 255))
for l in rest:
    p = os.path.join(G, f'{l}_{anim}_back.png')
    if os.path.exists(p): canvas.alpha_composite(Image.open(p).convert('RGBA'))
canvas.alpha_composite(bodyim)
for l in rest:
    canvas.alpha_composite(Image.open(os.path.join(G, f'{l}_{anim}.png')).convert('RGBA'))
canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST).save(out); print(out)
