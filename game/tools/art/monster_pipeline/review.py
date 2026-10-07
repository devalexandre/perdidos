"""Prancha de revisao: por especie/estagio, idle (col 0) e ataque (col 2) nas 5 direcoes, ampliados.
review.py out.png id:n id:n ..."""
import os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
out, items = sys.argv[1], sys.argv[2:]; S = 2
rows = []
for it in items:
    mid, n = it.split(':'); b = os.path.join(GAME, 'assets', 'monsters', mid, f'mon_{mid}_s{n}_')
    idle = Image.open(b + 'idle.png'); atk = Image.open(b + 'attack.png'); F = idle.height // 5
    r = Image.new('RGBA', (F * 10 * S + 20, F * S + 12), (240, 230, 200, 255)); d = ImageDraw.Draw(r); d.text((2, 0), it, fill=(0, 0, 0))
    for k in range(5):
        r.alpha_composite(idle.crop((0, k * F, F, k * F + F)).resize((F * S, F * S), Image.NEAREST), (k * F * S, 12))
        r.alpha_composite(atk.crop((2 * F, k * F, 3 * F, k * F + F)).resize((F * S, F * S), Image.NEAREST), ((5 + k) * F * S + 20, 12))
    rows.append(r)
W = max(r.width for r in rows); H = sum(r.height for r in rows)
b = Image.new('RGB', (W, H), (255, 255, 255)); y = 0
for r in rows: b.paste(r.convert('RGB'), (0, y)); y += r.height
b.save(out); print(out)
