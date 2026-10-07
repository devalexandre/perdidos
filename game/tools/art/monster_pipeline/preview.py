"""Prancha de conferencia de um estagio: todas as animacoes (linhas S..N), ampliadas.
preview.py <id> <n> <out.png> [--scale 3]"""
import os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
mid, n, out = sys.argv[1:4]; sc = int(sys.argv[5]) if len(sys.argv) > 5 else 3
base = os.path.join(GAME, 'assets', 'monsters', mid, f'mon_{mid}_s{n}_')
sheets = [(a, Image.open(base + a + '.png')) for a in ('idle', 'walk', 'attack', 'hit', 'death')]
FR = sheets[0][1].height // 5; W = sum(s.width for _, s in sheets) * sc + 8 * sc * len(sheets); H = FR * 5 * sc + 14
b = Image.new('RGBA', (W, H), (240, 230, 200, 255)); d = ImageDraw.Draw(b); x = 0
for a, s in sheets:
    d.text((x + 2, 1), f'{mid} s{n} {a}', fill=(60, 30, 20))
    b.alpha_composite(s.resize((s.width * sc, s.height * sc), Image.NEAREST), (x, 14)); x += s.width * sc + 8 * sc
b.convert('RGB').save(out); print(out)
