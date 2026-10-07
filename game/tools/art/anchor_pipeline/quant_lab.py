import sys, numpy as np
from PIL import Image
import pix
def srgb2lab(a):
    a=a/255.0; a=np.where(a>0.04045,((a+0.055)/1.055)**2.4,a/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=a@M.T/np.array([0.9505,1.0,1.089]); f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
PAL=np.array(pix.PAL,float); PL=srgb2lab(PAL)
def quant(im):
    a=np.asarray(im.convert('RGBA')).astype(float); lab=srgb2lab(a[...,:3])
    d=((lab[...,None,:]-PL)**2).sum(-1); idx=d.argmin(-1); out=PAL[idx]
    al=np.where(a[...,3]>140,255,0)
    return Image.fromarray(np.dstack([out,al]).astype('uint8'),'RGBA')
def sprite(src,ch,fr):
    im=pix.cutout(Image.open(src)); bb=im.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox(); im=im.crop(bb)
    s=ch/im.height; im=im.resize((round(im.width*s),ch),Image.BOX); q=quant(im)
    o=Image.new('RGBA',(fr,fr)); o.paste(q,((fr-q.width)//2,fr-q.height),q); return o
if __name__=='__main__':
    res=[]
    for f in sys.argv[1:]:
        for ch,fr in ((51,64),(80,96)): res.append(sprite(f,ch,fr))
    res[-1].save('best_96.png')
    W=sum(r.width*5+30 for r in res); sh=Image.new('RGBA',(W,480),(201,176,138,255)); x=0
    for r in res:
        b=r.resize((r.width*5,r.height*5),Image.NEAREST); sh.alpha_composite(b,(x,480-b.height)); x+=b.width+30
    sh.save('cmp_lab.png')
