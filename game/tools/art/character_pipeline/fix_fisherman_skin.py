"""Pescador (npc_fisherman): pele e cabelo grisalho saiam esverdeados (Agente E, item 9). Causa: a paleta unica de
48 cores da folha (build_npc.quantizer) juntou o cinza do cabelo e as sombras da pele com o verde-oliva da camisa.
Correcao na folha pronta (Agente F, 28/09; as fontes da IA nao existem mais): so na cabeca (30% de cima do corpo
de cada quadro), cada tom oliva vira o tom quente (bege/castanho) da PROPRIA paleta de luminancia mais proxima ->
nao cria cor nova (continua <= 48). Se a folha for refeita pelo build_npc.py, use "head_colors": 12 no picks.json
(reserva cores para a cabeca) em vez deste script.

    python fix_fisherman_skin.py <entrada.png> <saida.png> 0.30
"""
import sys, numpy as np, colorsys
from PIL import Image
FR=96; src, dst = sys.argv[1], sys.argv[2]
def hsv(c): return colorsys.rgb_to_hsv(*[x/255 for x in c])
im=np.asarray(Image.open(src).convert('RGBA')).copy()
cols={tuple(int(v) for v in c[:3]) for c in im.reshape(-1,4) if c[3]>0}
olive=[c for c in cols if 44<=hsv(c)[0]*360<=62 and 0.2<=hsv(c)[1]<=0.42]
warm=[c for c in cols if 28<=hsv(c)[0]*360<=42 and 0.25<=hsv(c)[1]<=0.5]
L=lambda c: 0.299*c[0]+0.587*c[1]+0.114*c[2]
M={o: min(warm, key=lambda w: abs(L(w)-L(o))) for o in olive}
n=0
for r in range(im.shape[0]//FR):
    for c in range(im.shape[1]//FR):
        f=im[r*FR:(r+1)*FR,c*FR:(c+1)*FR]; op=f[...,3]>0
        if not op.any(): continue
        ys=np.nonzero(op.any(1))[0]; lim=ys.min()+int((ys.max()-ys.min())*float(sys.argv[3]))
        for y in range(ys.min(), lim):
            for x in np.nonzero(op[y])[0]:
                k=tuple(int(v) for v in f[y,x,:3])
                if k in M: f[y,x,:3]=M[k]; n+=1
Image.fromarray(im).save(dst); print(dst, n, 'px;', len(M), 'tons', M)
