"""Fila de conferencia: coluna = personagem, linha = direcao (S..N), quadro 0 da folha idle, ampliado.
lineup.py out.png [--scale 3] [--col 0] idle1.png idle2.png ..."""
import os, sys
from PIL import Image, ImageDraw
a = sys.argv[1:]; out = a.pop(0); sc = 3; col = 0
while a and a[0].startswith('--'):
    if a[0] == '--scale': sc = int(a[1])
    if a[0] == '--col': col = int(a[1])
    a = a[2:]
F = 96; W = F * sc
b = Image.new('RGBA', (W * len(a), W * 5 + 16), (240, 230, 200, 255)); d = ImageDraw.Draw(b)
for i, p in enumerate(a):
    im = Image.open(p).convert('RGBA')
    d.text((i * W + 4, 2), os.path.basename(p).replace('_idle.png', '').replace('.png', ''), fill=(60, 30, 20))
    for r in range(5):
        c = min(col, im.width // F - 1)
        fr = im.crop((c * F, r * F, c * F + F, r * F + F)).resize((W, W), Image.NEAREST)
        b.alpha_composite(fr, (i * W, 16 + r * W))
b.convert('RGB').save(out); print(out, b.size)
