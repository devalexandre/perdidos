#!/usr/bin/env python3
"""Pos-processamento dos NPCs (venv): o mesmo do personagem (characters/chr_post.py, C3, que usa o pos dos monstros
do B3) com as configuracoes desta pasta. NAO instala por padrao (previas em <work>/preview/); --install grava
game/assets/npcs/npc_<id>_<anim>.png (backup antes em <work>/backup/).

  .tools/pyvenv/bin/python game/tools/art/blender/npcs/post_npc.py <id> [<id> ...] [--work .work/n2] [--install]"""
import argparse, os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "characters"))
import chr_post as CP  # noqa: E402
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
CP.NPC_DIR = os.path.join(HERE, "configs")
EXTRA_MATS = json.load(open(os.path.join(HERE, "materials.json")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--work", default=os.path.join(ROOT, ".work", "n2"))
    ap.add_argument("--install", action="store_true")
    a = ap.parse_args()
    for name, fam in EXTRA_MATS.items():      # familias de cor comuns a varios NPCs
        if name.startswith("_"):
            continue
        d = dict(ramp=CP.R(*fam[:4]), line=0, out=CP.hx(fam[4]))
        if len(fam) > 5:
            d["fill"] = tuple(fam[5])
        CP.MATS.setdefault(name, d)
    for i in a.ids:
        CP.process_npc(a.work, i.replace("npc:", ""), install=a.install)
        print("[post]", i, "ok")


if __name__ == "__main__":
    main()
