"""Tanuki Trapaceiro / Tanuki Barrigudo (trickster_tanuki) — Ilhas do Sol Nascente (tanuki do folclore japones,
o trapaceiro com a folha na cabeca). Base: esqueleto/corpo/animacoes do "ShibaInu" (Quaternius Ultimate Animated
Animals, CC0) reformado barrigudo; cabeca nossa com mascara escura, orelhas redondas e folha; rabo listrado."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    for sx, nm in ((1, "L"), (-1, "R")):   # mascara em volta dos olhos
        p = c + Vector((0.36 * r * sx, -0.74 * r, 0.14 * r))
        rig.add_mesh(R.ellipsoid(f"mask{nm}", p, (0.34 * r, 0.12 * r, 0.3 * r), rot=(0.3, 0, -0.38 * sx)), f"mask{nm}",
                     "fur_dark", piv, noline=True)
    # folha na cabeca (a do disfarce)
    lp = c + Vector((0.05 * r, 0.05 * r, 0.95 * r))
    rig.add_mesh(R.ellipsoid("leaf", lp, (0.42 * r, 0.22 * r, 0.05 * r), rot=(0.3, -0.35, 0.4)), "leaf", "leaf", piv)
    rig.add_mesh(R.cone("stem", lp + Vector((-0.35 * r, 0, -0.05 * r)), lp + Vector((-0.55 * r, 0, -0.15 * r)), 0.03 * r,
                        0.02 * r, seg=5, rings=1), "stem", "wood", piv, noline=True)
    for k, (a, b) in enumerate(PS.tail_ring(pk)):
        PS.add(rig, pk, f"Tail{k + 1}", R.ellipsoid(f"tring{k}", (a + b) / 2, (0.24 * r, 0.2 * r, 0.24 * r)),
               f"tring{k}", "fur_dark" if k % 2 else "fur_brown", noline=True)


S = PS.animal_cub("trickster_tanuki", "ShibaInu.gltf", {1: 0.9, 2: 1.36}, "fur_brown", 
                  matmap={"Main": ("fur", "fur_brown"), "Main_Light": ("belly0", "fur_cream"), "Black": ("paws", "fur_dark"),
                          "Eyes_Black": ("e1", "eye"), "Eyes_Pupil": ("e2", "eye"), "Eyes_White": ("e3", "white")},
                  head=dict(muzzle="fur_cream", nose="eye", ear="round", ear_in="fur_dark", snout=0.42,
                            brows=lambda st: st >= 2),
                  extra=extra, fat=1.3, belly="fur_cream")
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
