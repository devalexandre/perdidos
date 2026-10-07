"""Prancha das escolhas (com espelhamento aplicado): picks_board.py <npc> [dirs...] -> $NPC_WORK/<npc>/picks_board.png"""
import json, os, sys
from PIL import Image, ImageDraw
npc = sys.argv[1]; wd = os.path.join(os.environ['NPC_WORK'], npc); P = json.load(open(os.path.join(wd, 'picks.json')))
dirs = sys.argv[2:] or ['s', 'se', 'e', 'ne', 'n']; S = 300
b = Image.new('RGB', (3 * S, len(dirs) * (S + 14)), (240, 230, 200)); d = ImageDraw.Draw(b)
for r, dd in enumerate(dirs):
    p = P['dirs'][dd]
    for c, k in enumerate(('wl', 'idle', 'wr')):
        if not p.get(k): continue
        im = Image.open(os.path.join(wd, p[k])).convert('RGB').resize((S, S), Image.BOX)
        if p.get('flip'): im = im.transpose(Image.FLIP_LEFT_RIGHT)
        b.paste(im, (c * S, r * (S + 14) + 14)); d.text((c * S + 4, r * (S + 14)), f'{dd} {k} {p[k]} flip={p.get("flip")}', fill=(60, 30, 20))
b.save(os.path.join(wd, 'picks_board.png')); print(os.path.join(wd, 'picks_board.png'))
