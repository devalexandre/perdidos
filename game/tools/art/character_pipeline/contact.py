"""Prancha de conferencia: contact.py out.png [--scale 2] sheet1.png sheet2.png ...  (cada folha lado a lado
com o nome). Fundo pergaminho, como as pranchas de ancoras."""
import os, sys
from PIL import Image, ImageDraw
args = sys.argv[1:]; out = args.pop(0); sc = 2
if args and args[0] == '--scale': sc = int(args[1]); args = args[2:]
ims = [Image.open(a).convert('RGBA') for a in args]
W = max(i.width for i in ims) * sc; H = sum(i.height * sc + 14 for i in ims)
b = Image.new('RGBA', (W, H), (240, 230, 200, 255)); d = ImageDraw.Draw(b); y = 0
for a, im in zip(args, ims):
    d.text((4, y + 1), os.path.basename(a), fill=(60, 30, 20)); y += 14
    b.alpha_composite(im.resize((im.width * sc, im.height * sc), Image.NEAREST), (0, y)); y += im.height * sc
b.convert('RGB').save(out); print(out, b.size)
