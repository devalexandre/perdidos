"""Previa ampliada (3x) dos quadros-chave de uma folha walk: por linha (S..N) os quadros wl, idle, wr.
preview_npc.py <walk.png> <out.png>"""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA'); F = 96; S = 3
o = Image.new('RGBA', (3 * F * S * 5 // 1, F * S), (240, 230, 200, 255))
o = Image.new('RGBA', (15 * F * S // 1, F * S), (240, 230, 200, 255)) if False else Image.new('RGBA', (3 * F * S * 5, F * S), (240, 230, 200, 255))
for r in range(5):
    for j, c in enumerate((0, 3, 4)):
        fr = im.crop((c * F, r * F, c * F + F, r * F + F)).resize((F * S, F * S), Image.NEAREST)
        o.alpha_composite(fr, ((r * 3 + j) * F * S, 0))
o.convert('RGB').save(sys.argv[2])
