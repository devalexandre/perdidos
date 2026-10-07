"""Monta chr_traveler_{male,female}_{idle,walk}.png (quadros 96x96, linhas S,SE,E,NE,N)."""
import json, sys, numpy as np
from PIL import Image
from scipy.ndimage import label
FR=96; H_IDLE=84; H_WALK=83; DIRS=['s','se','e','ne','n']
P=json.load(open('picks.json')); FLIP=json.load(open('flips.json')) if len(sys.argv)<2 else {}
def load(f, flip):
    im=Image.open('rb_'+f).convert('RGBA'); a=np.asarray(im).copy()
    a[...,3]=np.where(a[...,3]>150,255,0)                       # alfa binário
    lab,n=label(a[...,3]>0)
    if n>1:                                                     # só a maior peça + peças grandes (remove sujeira)
        sz=np.bincount(lab.ravel()); keep=sz>=sz[1:].max()*0.01; keep[0]=False; a[~keep[lab]]=0
    im=Image.fromarray(a,'RGBA'); im=im.crop(im.getbbox())
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im
def fit(im,h):
    return im.resize((max(1,round(im.width*h/im.height)),h),Image.BOX)
def place(sp, dy=0):
    a=np.asarray(sp)[...,3]>0; cx=int(round(np.nonzero(a)[1].mean()))  # centro de massa horizontal
    o=Image.new('RGBA',(FR,FR)); o.alpha_composite(sp,(FR//2-cx, FR-sp.height+dy)); return o
def breathe(fr):  # parte de cima desce 1px (respiração)
    a=np.asarray(fr).copy(); ys=np.nonzero(a[...,3].any(1))[0]; top,bot=ys.min(),ys.max()
    cut=top+int((bot-top)*0.55); up=a[top:cut].copy(); a[top:cut]=0; a[top+1:cut+1]=np.where(up[...,3:]>0,up,a[top+1:cut+1]); return Image.fromarray(a,'RGBA')
def bob(fr, dy):
    o=Image.new('RGBA',(FR,FR)); o.alpha_composite(fr,(0,dy)); return o
for body,key in (('male','m'),('female','f')):
    rows_idle=[];rows_walk=[]
    for d in DIRS:
        fl=FLIP.get(f'{key}_{d}',{})
        idle=place(fit(load(P[key][d]['idle'],fl.get('idle',False)),H_IDLE))
        wl=place(fit(load(P[key][d]['wl'],fl.get('wl',False)),H_WALK))
        wr=place(fit(load(P[key][d]['wr'],fl.get('wr',False)),H_WALK))
        b=breathe(idle); rows_idle.append([idle,idle,b,b])
        rows_walk.append([wl,wl,bob(idle,-1),idle,wr,wr,bob(idle,-1),idle])
    # paleta única por personagem (sem piscar de cor entre quadros)
    allf=[f for r in rows_idle+rows_walk for f in r]
    strip=Image.new('RGB',(FR*len(allf),FR),(0,0,0)); 
    for i,f in enumerate(allf): strip.paste(f.convert('RGB'),(i*FR,0),f)
    pal=strip.quantize(48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    def q(f):
        r=f.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA'); r.putalpha(f.getchannel('A')); return r
    for name,rows in (('idle',rows_idle),('walk',rows_walk)):
        sh=Image.new('RGBA',(FR*len(rows[0]),FR*5))
        for r,row in enumerate(rows):
            for c,f in enumerate(row): sh.alpha_composite(q(f),(c*FR,r*FR))
        sh.save(f'chr_traveler_{body}_{name}.png')
    print(body,'ok')
