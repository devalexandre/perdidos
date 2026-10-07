"""Grifinho / Grifo Jovem (griffin_chick) — Costa das Colunas (o grifo do mito grego, filhote: cabeca de aguia
fofinha de penas creme e douradas, corpinho de leaozinho, asinhas). Base: esqueleto, patas e animacoes do
"ShibaInu" (Quaternius Ultimate Animated Animals, CC0); corpo, cabeca com bico, asas e rabo nossos."""
import math
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    for k in range(3):   # topete de penas
        p = c + Vector(((k - 1) * 0.22 * r, 0.1 * r, 0.9 * r))
        rig.add_mesh(R.cone(f"crest{k}", p, p + Vector(((k - 1) * 0.1 * r, 0.25 * r, 0.35 * r)), 0.12 * r, 0.02 * r, seg=6, rings=2),
                     f"crest{k}", "fur_gold", piv)
    mid, bc, br = rig.body
    for sx in (1, -1):   # asinhas
        p = bc + Vector((0.85 * br[0] * sx, -0.2 * br[1], 0.6 * br[2]))
        PS.add(rig, pk, mid, R.ellipsoid(f"wing{sx}", p, (0.15 * r, 0.55 * r * (1 + 0.3 * (stage > 1)), 0.32 * r),
                                         rot=(0.5, -0.6 * sx, 0.3 * sx)), f"wing{sx}", "fur_gold")
    t0 = PS.bpos(pk, "Tail1")
    end = t0 + Vector((0, 0.7 * r, 0.35 * r))
    PS.add(rig, pk, "Tail1", R.cone("tail", t0, end, 0.09 * r, 0.06 * r, seg=8, rings=4, bend=(0, 0, 0.25 * r)), "tail", "fur_tawny")
    PS.add(rig, pk, "Tail1", R.ellipsoid("tuft", end, (0.14 * r,) * 3), "tuft", "fur_brown")


S = PS.animal_cub("griffin_chick", "ShibaInu.gltf", {1: 0.92, 2: 1.38}, "fur_tawny",
                  {"Main": ("legs", "fur_tawny"), "Main_Light": ("legs2", "fur_tawny"), "Black": ("paws", "beak"),
                   "Eyes_Black": ("e1", "eye"), "Eyes_Pupil": ("e2", "eye"), "Eyes_White": ("e3", "white")},
                  head=dict(skin="fur_cream", beak="beak", ear="none", snout=0.0, brows=lambda st: st >= 2),
                  extra=extra, belly="fur_cream", fat=1.2)
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
