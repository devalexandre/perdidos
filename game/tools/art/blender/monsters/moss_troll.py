"""Trollzinho de Musgo / Troll de Musgo (moss_troll) — Fiordes de Gelo (troll de pedra do folclore nordico, pequeno e
emburrado, coberto de musgo com cogumelos nos ombros). Base: corpo, bracos compridos e animacoes do "Yeti" (Big) do
Quaternius Ultimate Monsters (CC0), repintado de pedra cinza; nariz, musgo e cogumelos nossos."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS
import pack_model as PM


def extra(rig, pk, stage):
    lo, hi, c = PS.head_box(pk)
    w = hi.x - lo.x
    PS.add(rig, pk, "Head", R.ellipsoid("nose", Vector((c.x, lo.y + 0.02 * w, c.z - 0.05 * w)), (0.16 * w, 0.14 * w, 0.14 * w)),
           "nose", "rock")
    for sx, b in ((1, "Shoulder.L"), (-1, "Shoulder.R")):
        p = PS.bpos(pk, b, True) + Vector((0, 0, 0.12 * w))
        PS.add(rig, pk, b, R.ellipsoid(f"moss{sx}", p, (0.3 * w, 0.25 * w, 0.08 * w)), f"moss{sx}", "moss")
        for k in range(1 + stage):
            q = p + Vector((0.08 * w * k * sx, 0.05 * w * k, 0.06 * w))
            PS.add(rig, pk, b, R.cone(f"stem{sx}{k}", q, q + Vector((0, 0, 0.12 * w)), 0.03 * w, 0.03 * w, seg=6, rings=1),
                   f"stem{sx}{k}", "paper_cream", noline=True)
            PS.add(rig, pk, b, R.ellipsoid(f"cap{sx}{k}", q + Vector((0, 0, 0.13 * w)), (0.09 * w, 0.09 * w, 0.05 * w)),
                   f"cap{sx}{k}", "paper")
    PS.add(rig, pk, "Head", R.ellipsoid("headmoss", Vector((c.x, c.y + 0.1 * w, hi.z)), (0.35 * w, 0.3 * w, 0.08 * w)),
           "headmoss", "moss")


S = PS.PackSpecies(
    "moss_troll", PS.pack("ultimate-monsters", "Big", "Yeti.gltf"), heights={1: 1.0, 2: 1.45},
    colormap=[("#a0a0a0", "stone", "rock"), ("#407888", "mossy", "moss"), ("#8890a0", "teeth", "claw"),
              ("#181820", "eyes", "eye")],
    extras=extra, actions={"attack": "Punch", "hit": "HitReact", "death": ("Death", 0.0, 0.5)})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
