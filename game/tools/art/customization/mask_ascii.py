"""Mascara do corpo-base em ASCII (s = pele, e = olhos, h = raspado, x = resto) com coordenadas, para escolher
as ancoras dos brincos (anchors.json):  python mask_ascii.py <male|female>"""
import os, sys, numpy as np
from PIL import Image
from common import GAME
os.chdir(os.path.join(GAME, 'assets', 'characters', 'base'))
body=sys.argv[1]
for anim in ('idle','sit'):
  m=np.asarray(Image.open(f'chr_{body}_base_mask_{anim}.png').convert('RGBA'))
  for r in range(5):
    f=m[r*96:(r+1)*96,0:96]; ys=np.nonzero(f[...,3].any(1))[0]; top=ys.min()
    print(f'== {anim} row{r} top={top}')
    print('    '+''.join(str((x//10)%10) for x in range(28,68)))
    print('    '+''.join(str(x%10) for x in range(28,68)))
    for y in range(top,top+30):
      row=''
      for x in range(28,68):
        p=f[y,x]
        row+= '.' if p[3]==0 else ('s' if p[0]>5 else ('e' if p[1]>5 else ('h' if p[2]>5 else 'x')))
      print(f'{y:3d} '+row)
