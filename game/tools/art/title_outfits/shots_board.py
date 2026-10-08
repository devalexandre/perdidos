"""Board of the real-client captures (capture_titles.sh): the player at the spawn point, cropped and zoomed.

    python shots_board.py <captures dir> <out.png>
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(src, 'pindorama_*_male.png')))
CW, CH, Z = 220, 260, 2
try:
    font = ImageFont.truetype('DejaVuSans.ttf', 16)
except OSError:
    font = None
img = Image.new('RGB', (len(files) * CW * Z, 2 * CH * Z + 30), (30, 30, 36))
d = ImageDraw.Draw(img)
for i, f in enumerate(files):
    t = os.path.basename(f)[:-len('_male.png')]
    d.text((i * CW * Z + 8, 6), t, fill=(255, 255, 255), font=font)
    for j, body in enumerate(('male', 'female')):
        p = os.path.join(src, f'{t}_{body}.png')
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert('RGB')
        cx, cy = im.width // 2, im.height // 2 - 20
        c = im.crop((cx - CW // 2, cy - CH // 2, cx + CW // 2, cy + CH // 2)).resize((CW * Z, CH * Z), Image.NEAREST)
        img.paste(c, (i * CW * Z, 30 + j * CH * Z))
img.save(out)
print(out, img.size)
