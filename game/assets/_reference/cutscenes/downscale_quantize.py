import sys
from PIL import Image
src,dst=sys.argv[1],sys.argv[2]
im=Image.open(src).convert('RGB').resize((960,540),Image.BOX)
im=im.quantize(96,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).convert('RGB')
im.save(dst,optimize=True)
