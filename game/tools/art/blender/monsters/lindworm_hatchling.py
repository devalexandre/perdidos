"""Lindworm Filhote / Lindworm do Gelo (lindworm_hatchling) — Fiordes de Gelo (o lindworm do folclore nordico: dragao
serpente sem asas, com duas patinhas). Base: corpo, cabeca e animacoes do "Dragon" do Quaternius Ultimate Monsters
(CC0) SEM as asas, repintado de azul-gelo com espinhos de gelo nossos nas costas."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS
import pack_model as PM


def extra(rig, pk, stage):
    lo, hi = PM.bbox(pk)
    h = hi.z - lo.z
    n = 4 + stage
    for k in range(n):
        b = "Torso" if k < n // 2 else "Body1"
        p = Vector((0, lo.y + (hi.y - lo.y) * (0.35 + 0.5 * k / n), hi.z - h * (0.1 + 0.25 * k / n)))
        PS.add(rig, pk, b, R.cone(f"ice{k}", p, p + Vector((0, 0.06 * h, 0.2 * h)), 0.07 * h, 0.01 * h, seg=5, rings=1),
               f"ice{k}", "ice")


S = PS.PackSpecies(
    "lindworm_hatchling", PS.pack("ultimate-monsters", "Flying", "Dragon.gltf"), heights={1: 0.62, 2: 0.94},
    colormap=[("#905020", "scales", "ice"), ("#583048", "membrane", "cloth_blue"), ("#8890a0", "spikes", "white"),
              ("#181820", "eyes", "eye")],
    hide_bones=[f"Wing{k}.{s}" for k in range(1, 5) for s in "LR"], extras=extra, motion="fly", hover=0.08,
    actions={"idle": "Flying_Idle", "walk": "Fast_Flying", "attack": "Headbutt", "hit": "HitReact", "death": "Death"})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
