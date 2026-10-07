"""Conferencia do GDD 10.2.1: todos os estagios na MESMA escala de mundo (48 px/un.) ao lado do Viajante, pes
alinhados; o estagio que reusa a folha do anterior e ampliado por MonsterStage.visual_scale (como no jogo).
Le os dados de tools/art/content/training_src.json. size_lineup.py out.png [--scale 2]"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
out = sys.argv[1]; sc = int(sys.argv[sys.argv.index('--scale') + 1]) if '--scale' in sys.argv else 2
src = json.load(open(os.path.join(GAME, 'tools', 'art', 'content', 'training_src.json')))
trav = Image.open(os.path.join(GAME, 'assets', 'characters', 'base', 'chr_male_base_idle.png')).crop((0, 96, 96, 192))


def crop(im):
    return im.crop(im.getbbox())


cells = []
for m in src['monsters']:
    base = None
    for i, st in enumerate(m['stages'], 1):
        if 'frame' in st: base = os.path.join(GAME, 'assets', 'monsters', m['id'], f"mon_{m['id']}_s{i}_idle.png")
        im = Image.open(base); F = im.height // 5; fr = crop(im.crop((0, F, F, 2 * F)))
        k = st.get('scale', 1.0)
        if k != 1.0: fr = fr.resize((round(fr.width * k), round(fr.height * k)), Image.NEAREST)
        cells.append((f"{m['id']} s{i}", fr, m['id']))
rows, cur, curw = [], [], 0
MAXW = 1500
for c in cells:
    if curw + c[1].width + 10 > MAXW and cur: rows.append(cur); cur, curw = [], 0
    cur.append(c); curw += c[1].width + 10
rows.append(cur)
tv = crop(trav)
imgs = []
for r in rows:
    H = max([f.height for _, f, _ in r] + [tv.height]) + 16; W = tv.width + 20 + sum(f.width + 10 for _, f, _ in r)
    b = Image.new('RGBA', (W, H), (240, 230, 200, 255)); d = ImageDraw.Draw(b)
    b.alpha_composite(tv, (0, H - tv.height)); x = tv.width + 20
    d.line([(0, H - 83), (W, H - 83)], fill=(200, 120, 120)); d.line([(0, H - 58), (W, H - 58)], fill=(150, 150, 220))
    for name, f, _ in r:
        b.alpha_composite(f, (x, H - f.height)); d.text((x, 1), name.replace('_', ' ')[:18], fill=(60, 30, 20)); x += f.width + 10
    imgs.append(b.resize((b.width * sc, b.height * sc), Image.NEAREST))
out_im = Image.new('RGB', (max(i.width for i in imgs), sum(i.height for i in imgs)), (255, 255, 255)); y = 0
for i in imgs: out_im.paste(i.convert('RGB'), (0, y)); y += i.height
out_im.save(out); print(out, out_im.size)
