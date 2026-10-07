"""Prancha dos estagios em ESCALA REAL (quadro idle SE, pes alinhados) com o Viajante ao lado para comparar.
stage_lineup.py out.png [--scale 2] id ..."""
import os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
a = sys.argv[1:]; out = a.pop(0); sc = 2
if a and a[0] == '--scale': sc = int(a[1]); a = a[2:]
trav = Image.open(os.path.join(GAME, 'assets', 'characters', 'base', 'chr_male_base_idle.png')) if os.path.exists(os.path.join(GAME, 'assets', 'characters', 'base', 'chr_male_base_idle.png')) else None
rows = []
for mid in a:
    frames = []
    if trav: frames.append(('Viajante', trav.crop((0, 96, 96, 192))))
    for n in (1, 2, 3):
        p = os.path.join(GAME, 'assets', 'monsters', mid, f'mon_{mid}_s{n}_idle.png')
        if not os.path.exists(p): continue
        im = Image.open(p); F = im.height // 5
        frames.append((f'{mid} s{n}', im.crop((0, F, F, 2 * F))))
    H = max(f.height for _, f in frames) * sc + 16; W = sum(f.width for _, f in frames) * sc + 12 * len(frames)
    r = Image.new('RGBA', (W, H), (240, 230, 200, 255)); d = ImageDraw.Draw(r); x = 0
    for name, f in frames:
        big = f.resize((f.width * sc, f.height * sc), Image.NEAREST); r.alpha_composite(big, (x, H - big.height)); d.text((x + 2, 2), name, fill=(60, 30, 20)); x += big.width + 12
    rows.append(r)
b = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows) + 4 * len(rows)), (255, 255, 255)); y = 0
for r in rows: b.paste(r.convert('RGB'), (0, y)); y += r.height + 4
b.save(out); print(out)
