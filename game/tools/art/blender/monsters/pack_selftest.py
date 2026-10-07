"""Teste do adaptador de packs (pack_model.py) com um modelo gerado (.work/b3/packs/_selftest/make_test_glb.py).
Modelo para as proximas especies feitas a partir de packs CC0: troca PATH/MATMAP/ACTIONS e reforma."""
import os, math
import mon_rig as R
import pack_model as PM

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
PATH = os.path.join(ROOT, ".work", "b3", "packs", "_selftest", "test_creature.glb")
FRAME = {1: 96, 2: 144, 3: 240}
SCALE = {1: 0.7, 2: 1.1, 3: 1.8}
MATMAP = {"Body": "moss", "Face": "skin"}
ACTIONS = {"idle": "Idle", "walk": "Walk", "attack": "Walk", "hit": "Idle", "death": "Idle"}
ANIMS = [("idle", 8), ("walk", 8)]


def build(stage):
    R.reset()
    rig = R.Rig("pack_selftest")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.pack = PM.import_model(rig, PATH, MATMAP, parent=rig.root, yaw_deg=0.0)
    PM.bone_scale(rig.pack, "Head", 1.35)   # reforma: cabeca maior (chibi)
    rig.save_rest()
    return rig


def pose(rig, anim, i, n, stage):
    PM.play(rig.pack, ACTIONS[anim], i, n, loop=anim in ("idle", "walk"))
    R.squash(rig.root, 1.0 + 0.05 * math.sin(math.tau * i / n))
