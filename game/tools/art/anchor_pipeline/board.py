import numpy as np
from PIL import Image
import pix
from quant_lab import srgb2lab
from scipy.ndimage import label
PICK={'a1m':0,'a1f':0,'a3':3,'a4':1,'a5':0}
def blobs(im, minarea=2000, merge=True):
    a=np.asarray(im.getchannel('A'))>128; lab,n=label(a); out=[]
    for i in range(1,n+1):
        ys,xs=np.where(lab==i)
        if len(xs)>=minarea: out.append((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
    # agrupa blobs sobrepostos em x (ex.: cabeça separada do corpo)
    out.sort(); merged=[]
    for b in out:
        if merge and merged and b[0] < merged[-1][2]-10:
            m=merged[-1]; merged[-1]=(min(m[0],b[0]),min(m[1],b[1]),max(m[2],b[2]),max(m[3],b[3]))
        else: merged.append(b)
    return merged
def shrink(im, h):
    s=h/im.height; return im.resize((max(1,round(im.width*s)),h), Image.BOX)
# 1) paleta expandida: mestra + clusters das âncoras escolhidas
samples=[]
for g,i in PICK.items():
    im=Image.open(f'{g}_{i}.png').convert('RGB'); im.thumbnail((256,256)); a=np.asarray(im).reshape(-1,3)
    a=a[~((a.min(1)>225)&(np.ptp(a,1)<25))]  # sem o fundo branco
    samples.append(a)
X=np.concatenate(samples).astype(float); L=srgb2lab(X)
from scipy.cluster.vq import kmeans2
np.random.seed(0); C,_=kmeans2(L,40,minit='++',seed=0)
base=np.array(pix.PAL,float); BL=srgb2lab(base); extra=[]
for c in C:
    if np.sqrt(((BL-c)**2).sum(1)).min()>7 and all(np.sqrt(((srgb2lab(np.array(e,float))-c)**2).sum())>7 for e in extra):
        idx=np.argmin(((L-c)**2).sum(1)); extra.append(tuple(int(v) for v in X[idx]))
PALX=[tuple(p) for p in pix.PAL]+extra
print('paleta expandida:',len(PALX),'cores (+%d)'%len(extra))
PL=srgb2lab(np.array(PALX,float))
def quant(im):
    a=np.asarray(im.convert('RGBA')).astype(float); lab=srgb2lab(a[...,:3])
    idx=((lab[...,None,:]-PL)**2).sum(-1).argmin(-1); out=np.array(PALX,float)[idx]
    return Image.fromarray(np.dstack([out,np.where(a[...,3]>140,255,0)]).astype('uint8'),'RGBA')
def clean(sp):
    a=np.asarray(sp).copy(); m=a[...,3]>0
    lab,n=label(m)
    if n>1:
        sizes=np.bincount(lab.ravel()); keep=sizes>=max(12,sizes[1:].max()*0.02); keep[0]=False; a[~keep[lab]]=0
    return Image.fromarray(a,'RGBA')
def frame(sp,fr):
    sp=clean(sp)
    o=Image.new('RGBA',(fr,fr)); o.paste(sp,((fr-sp.width)//2,fr-sp.height),sp); return o
results={}
for g,h,fr in (('a1m',80,96),('a1f',80,96)):
    im=pix.cutout(Image.open(f'{g}_{PICK[g]}.png')); views=[]
    for b in blobs(im): views.append(frame(quant(shrink(im.crop(b),h)),fr))
    results[g]=views; print(g,len(views),'views')
im=pix.cutout(Image.open(f'a3_{PICK["a3"]}.png')); b=im.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
results['a3']=[frame(quant(shrink(im.crop(b),56)),96)]
im=pix.cutout(Image.open(f'a5_{PICK["a5"]}.png')); ic=[]
for b in blobs(im,800,merge=False):
    c=im.crop(b); s=28/max(c.size); c=c.resize((max(1,round(c.width*s)),max(1,round(c.height*s))),Image.BOX)
    o=Image.new('RGBA',(32,32)); q=quant(c); o.paste(q,((32-q.width)//2,(32-q.height)//2),q); ic.append(o)
results['a5']=ic; print('icons',len(ic))
sc=Image.open(f'a4_{PICK["a4"]}.png').convert('RGBA').resize((960,540),Image.BOX); results['a4']=[quant(sc)]
import pickle; pickle.dump(PALX,open('palx.pkl','wb'))
for k,v in results.items():
    for j,im in enumerate(v): im.save(f'proc_{k}_{j}.png')
# prancha
Z=4; bg=(242,230,200,255)
rows=[results['a1m'],results['a1f'],results['a3']+results['a5']]
W=1920+40; y=20; parts=[]
H=sum(max(i.height for i in r)*Z+30 for r in rows)+20+540*2+30
board=Image.new('RGBA',(W,H),bg)
for r in rows:
    x=20; rh=max(i.height for i in r)*Z
    for im in r:
        big=im.resize((im.width*Z,im.height*Z),Image.NEAREST); board.alpha_composite(big,(x,y+rh-big.height)); x+=big.width+30
    y+=rh+30
board.alpha_composite(results['a4'][0].resize((1920,1080),Image.NEAREST),(20,y))
board.save('anchor_board.png'); print('board',board.size)
