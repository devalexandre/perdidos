"""Conferencia de direcao: recorta a cabeca (topo do recorte) dos quadros wl/idle/wr de SE, E, NE, ja com o
espelhamento de picks.json aplicado. Tudo deve olhar para a DIREITA da tela. heads_board.py out.png npc..."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
out, npcs = sys.argv[1], sys.argv[2:]; S = 150; FR_H = float(os.environ.get("HEAD_FRAC", "0.45"))
b = Image.new('RGB', (9 * S, len(npcs) * (S + 12)), (240, 230, 200)); d = ImageDraw.Draw(b)
for r, npc in enumerate(npcs):
    wd = os.path.join(os.environ['NPC_WORK'], npc); P = json.load(open(os.path.join(wd, 'picks.json')))
    d.text((2, r * (S + 12)), npc + '  (SE wl idle wr | E | NE)', fill=(60, 30, 20))
    for i, dd in enumerate(('se', 'e', 'ne')):
        p = P['dirs'][dd]
        for j, k in enumerate(('wl', 'idle', 'wr')):
            f = p.get(k)
            if not f: continue
            im = Image.open(os.path.join(wd, f.lstrip('!'))).convert('RGB'); a = np.abs(np.asarray(im).astype(int) - 255).sum(2) > 40
            ys, xs = np.nonzero(a); h = ys.max() - ys.min(); top = ys.min()
            cols = np.nonzero(a[top:top + int(h * FR_H)].any(0))[0]
            box = (max(0, cols.min() - 20), top, min(im.width, cols.max() + 20), top + int(h * FR_H))
            c = im.crop(box); c.thumbnail((S, S))
            if p.get('flip') != f.startswith('!'): c = c.transpose(Image.FLIP_LEFT_RIGHT)
            b.paste(c, ((i * 3 + j) * S, r * (S + 12) + 12))
b.save(out); print(out)
