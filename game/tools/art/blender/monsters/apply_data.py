#!/usr/bin/env python3
"""Aponta os estagios dos MonsterDef (.tres) para as folhas do Blender: estagio n -> mon_<id>_s<n>, visual_scale 1.0
(mesma densidade de pixel do Viajante; o tamanho ja vem no quadro) e baked_life = true (a vida vem desenhada).
  python3 game/tools/art/blender/monsters/apply_data.py <id> [<id> ...]"""
import os, re, sys
GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
for mid in sys.argv[1:]:
    p = os.path.join(GAME, "data", "monsters", f"{mid}.tres")
    s = open(p).read()
    blocks = re.split(r"(?=\n\[sub_resource|\n\[resource\])", s)
    out = []
    for b in blocks:
        m = re.search(r'name_key = "MON_[A-Z_]+_S(\d)_NAME"', b)
        if m:
            st = m.group(1)
            if os.path.exists(os.path.join(GAME, "assets", "monsters", mid, f"mon_{mid}_s{st}_idle.png")):
                b = re.sub(r'(sprite_base = "res://assets/monsters/[^"]+_s)\d(")', rf"\g<1>{st}\2", b)
                b = re.sub(r"\nvisual_scale = [0-9.]+", "", b)
                if "baked_life" not in b:
                    b = re.sub(r'(sprite_base = "[^"]+"\n)', r"\1baked_life = true\n", b)
        out.append(b)
    open(p, "w").write("".join(out))
    print("ok", mid)
