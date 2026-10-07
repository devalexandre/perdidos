#!/usr/bin/env python3
"""Prancha de conferencia: todas as especies (estagios) lado a lado com o Viajante, na escala do jogo (1 px = 1 texel),
pes alinhados, fundo de grama. Direcao SE (quadro 0 do idle). Saida: .work/b3/preview/lineup_<estagio>.png (x2).
  .tools/pyvenv/bin/python game/tools/art/blender/monsters/lineup.py [estagio ...]"""
import glob, os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(os.path.dirname(GAME), ".work", "b3", "preview")
ROW = 1  # SE


def frame(path, row=ROW, col=0):
    im = Image.open(path).convert("RGBA")
    F = im.height // 5
    return im.crop((col * F, row * F, (col + 1) * F, (row + 1) * F))


for st in (sys.argv[1:] or ["1", "2"]):
    ims = [("Viajante", frame(os.path.join(GAME, "assets", "characters", "chr_traveler_male_idle.png")))]
    for p in sorted(glob.glob(os.path.join(GAME, "assets", "monsters", "*", f"*_s{st}_idle.png"))):
        ims.append((os.path.basename(os.path.dirname(p)), frame(p)))
    H = max(i.height for _, i in ims) + 14
    W = sum(i.width for _, i in ims) + 4 * len(ims)
    board = Image.new("RGBA", (W, H), (118, 158, 86, 255))
    d = ImageDraw.Draw(board)
    x = 0
    for name, i in ims:
        board.alpha_composite(i, (x, H - 14 - i.height))
        d.text((x + 1, H - 12), name[:14], fill=(20, 30, 20, 255))
        x += i.width + 4
    board = board.resize((W * 2, H * 2), Image.NEAREST)
    os.makedirs(OUT, exist_ok=True)
    board.save(os.path.join(OUT, f"lineup_s{st}.png"))
    print("ok", os.path.join(OUT, f"lineup_s{st}.png"))
