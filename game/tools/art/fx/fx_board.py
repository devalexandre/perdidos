#!/usr/bin/env python3
"""Prancha e GIFs dos efeitos de skill a partir das capturas do cliente real.
  python3 game/tools/art/fx/fx_board.py SHOTS_DIR OUT_DIR
SHOTS_DIR tem <skill>_NN.png (tests/client/skill_fx_capture.gd). Saida: OUT_DIR/board.png (tres momentos
de cada skill, recortados em volta do personagem), OUT_DIR/<skill>.gif e OUT_DIR/best/<skill>.png.
30/09/2026: com muitas skills, tambem OUT_DIR/board_NN.png (paginas de 10 linhas, para olhar)."""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

CROP = (440, 140, 960, 500)  # em 1280x720: personagem no centro, bonecos a direita/frente


def main():
    shots, out = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(out, "best"), exist_ok=True)
    groups = {}
    for p in sorted(glob.glob(os.path.join(shots, "*_[0-9][0-9].png"))):
        m = re.match(r"(.+)_(\d\d)\.png$", os.path.basename(p))
        groups.setdefault(m.group(1), []).append(p)
    order = ["blade_firm_strike", "blade_charge", "blade_clearing_sweep", "blade_horizon_cut", "blade_steel_spin",
             "blade_iron_stance", "arcane_spark", "arcane_will_o_wisp", "arcane_creeping_flame", "arcane_frost_burst",
             "arcane_star_fall", "arcane_barrier", "bow_basic_attack"]
    rows = []
    for name in [n for n in order if n in groups] + [n for n in groups if n not in order]:
        full = [Image.open(p).convert("RGB") for p in groups[name]]
        frames = [f.crop(CROP) for f in full]
        base = np.asarray(frames[0], dtype=np.int16)
        scores = [np.abs(np.asarray(f, dtype=np.int16) - base).sum() for f in frames]
        b = int(np.argmax(scores))
        frames[b].save(os.path.join(out, "best", name + ".png"))
        small = [f.resize((f.width * 3 // 4, f.height * 3 // 4), Image.NEAREST) for f in frames]
        small[0].save(os.path.join(out, name + ".gif"), save_all=True, append_images=small[1:], duration=80, loop=0)
        # tres momentos: antes do pico, pico e depois
        idx = sorted({max(1, b - 3), b, min(len(frames) - 1, b + 4)})
        rows.append((name, [frames[k] for k in idx]))
    if not rows:
        print("sem capturas em", shots)
        return
    tw, th = rows[0][1][0].size
    tw, th = tw * 3 // 4, th * 3 // 4
    board = Image.new("RGB", (3 * tw, len(rows) * (th + 20)), (20, 18, 26))
    d = ImageDraw.Draw(board)
    for r, (name, ims) in enumerate(rows):
        y = r * (th + 20)
        d.text((6, y + 4), name, fill=(250, 229, 140))
        for c, im in enumerate(ims):
            board.paste(im.resize((tw, th), Image.LANCZOS), (c * tw, y + 20))
    board.save(os.path.join(out, "board.png"))
    print("prancha:", os.path.join(out, "board.png"), "(%d skills)" % len(rows))
    per = 10
    for p in range(0, len(rows), per):
        page = board.crop((0, p * (th + 20), board.width, min(board.height, (p + per) * (th + 20))))
        page.save(os.path.join(out, "board_%02d.png" % (p // per + 1)))


if __name__ == "__main__":
    main()
