import sys
from PIL import Image, ImageDraw
def palette(path):
    cols=[]
    for l in open(path):
        p=l.split()
        if len(p)>=3 and all(x.isdigit() for x in p[:3]): cols.append(tuple(map(int,p[:3])))
    return cols
PAL=palette('/home/devalexandre/projects/devalexandre/game-mmo/game/assets/_reference/style_anchor/paleta-mestra.gpl')
def cutout(im, tol=40):
    im=im.convert('RGBA'); w,h=im.size
    # flood fill do fundo claro a partir das bordas
    bg=Image.new('L',(w,h),0); px=im.load(); m=bg.load(); stack=[(x,y) for x in range(w) for y in (0,h-1)]+[(x,y) for y in range(h) for x in (0,w-1)]
    while stack:
        x,y=stack.pop()
        if m[x,y]: continue
        r,g,b,a=px[x,y]
        if min(r,g,b) < 255-tol or max(r,g,b)-min(r,g,b)>25: continue
        m[x,y]=255
        for nx,ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0<=nx<w and 0<=ny<h and not m[nx,ny]: stack.append((nx,ny))
    im.putalpha(Image.eval(bg,lambda v:255-v)); return im
def to_sprite(src, char_h, frame):
    im=cutout(Image.open(src)); bb=im.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox(); im=im.crop(bb)
    s=char_h/im.height; im=im.resize((max(1,round(im.width*s)),char_h), Image.BOX)
    pal=Image.new('P',(1,1)); flat=[c for rgb in PAL for c in rgb]; pal.putpalette(flat+[0]*(768-len(flat)))
    rgb=im.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGB')
    a=im.getchannel('A').point(lambda v:255 if v>140 else 0)
    rgb.putalpha(a)
    out=Image.new('RGBA',(frame,frame)); out.paste(rgb,((frame-rgb.width)//2, frame-1-rgb.height+1), rgb); return out
if __name__=='__main__':
    src=sys.argv[1]; res=[]
    for ch,fr in ((51,64),(80,96)):
        sp=to_sprite(src,ch,fr); sp.save(f'{src[:-4]}_{fr}.png'); res.append(sp)
    bgc=(201,176,138,255); W=sum(r.width*6 for r in res)+40; H=96*6
    sheet=Image.new('RGBA',(W,H),bgc); x=0
    for r in res:
        big=r.resize((r.width*6,r.height*6),Image.NEAREST); sheet.alpha_composite(big,(x,H-big.height)); x+=big.width+40
    sheet.save(f'{src[:-4]}_cmp.png')
