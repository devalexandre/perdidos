"""Teste visual: eqtest.py <body> <out.png> <visual> <src> <flip 0/1> <H> [...]  -> base | editada | camada | composto"""
import sys, build_equipment as BE
from PIL import Image
body, out, *a = sys.argv[1:]; items = [a[i:i + 4] for i in range(0, len(a), 4)]
o = Image.new('RGBA', (96 * 4, 96 * len(items)), (240, 230, 200, 255))
for i, (v, src, fl, H) in enumerate(items):
    base, ef = BE.edited_frame(body, v, src, fl == '1', int(H))
    ov = BE.extract(base, ef, BE.VISUALS[v]['region']) if BE.VISUALS[v]['kind'] == 'layer' else ef
    comp = base.copy(); comp.alpha_composite(ov)
    for j, im in enumerate((base, ef, ov, comp if BE.VISUALS[v]['kind'] == 'layer' else ef)): o.alpha_composite(im, (j * 96, i * 96))
o.resize((o.width * 3, o.height * 3), Image.NEAREST).save(out); print(out)
