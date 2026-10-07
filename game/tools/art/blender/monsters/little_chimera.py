"""Quimerinha / Quimera Jovem (little_chimera) — Costa das Colunas (a quimera do mito grego, em versao filhote:
leaozinho com uma cabecinha de cabra nas costas e rabo de cobra). Base: esqueleto, patas e animacoes do "ShibaInu"
(Quaternius Ultimate Animated Animals, CC0); corpo, cabecas, juba e rabo nossos."""
import math
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    for k in range(10):   # juba em volta da cara
        a = math.tau * k / 10
        p = c + Vector((math.cos(a) * 0.95 * r, 0.15 * r, math.sin(a) * 0.9 * r))
        rig.add_mesh(R.ellipsoid(f"mane{k}", p, (0.3 * r, 0.24 * r, 0.3 * r)), f"mane{k}", "fur_brown", piv, group="mane")
    mid, bc, br = rig.body
    # cabecinha de cabra nas costas
    gp = bc + Vector((0, 0.1 * br[1], br[2] * 1.05))
    PS.add(rig, pk, mid, R.ellipsoid("goat", gp, (0.34 * r, 0.3 * r, 0.32 * r)), "goat", "fur_white")
    PS.add(rig, pk, mid, R.ellipsoid("goatsn", gp + Vector((0, -0.3 * r, -0.08 * r)), (0.16 * r, 0.16 * r, 0.14 * r)), "goatsn", "fur_white")
    for sx in (1, -1):
        PS.add(rig, pk, mid, R.cone(f"ghorn{sx}", gp + Vector((0.15 * r * sx, 0, 0.22 * r)), gp + Vector((0.25 * r * sx, 0.25 * r, 0.45 * r)),
                                    0.07 * r, 0.02 * r, seg=6, rings=3, bend=(0, 0.08 * r, 0)), f"ghorn{sx}", "horn")
        PS.add(rig, pk, mid, R.ellipsoid(f"geye{sx}", gp + Vector((0.14 * r * sx, -0.26 * r, 0.06 * r)), (0.07 * r, 0.04 * r, 0.08 * r)),
               f"geye{sx}", "eye", noline=True, unlit=True, prio=2.5)
    # rabo de cobra com cabecinha
    t0 = PS.bpos(pk, "Tail1")
    end = t0 + Vector((0.2 * r, 0.95 * r, 0.55 * r))
    PS.add(rig, pk, "Tail1", R.cone("snake", t0, end, 0.13 * r, 0.1 * r, seg=10, rings=6, bend=(0.25 * r, 0.1 * r, 0.2 * r)), "snake", "snake")
    PS.add(rig, pk, "Tail1", R.ellipsoid("snakehead", end + Vector((0, 0.05 * r, 0.08 * r)), (0.15 * r, 0.2 * r, 0.12 * r)),
           "snakehead", "snake")
    for sx in (1, -1):
        PS.add(rig, pk, "Tail1", R.ellipsoid(f"seye{sx}", end + Vector((0.08 * r * sx, -0.05 * r, 0.16 * r)), (0.045 * r,) * 3),
               f"seye{sx}", "eye", noline=True, unlit=True, prio=2.5)


S = PS.animal_cub("little_chimera", "ShibaInu.gltf", {1: 0.92, 2: 1.38}, "fur_tawny",
                  {"Main": ("legs", "fur_tawny"), "Main_Light": ("legs2", "fur_cream"), "Black": ("paws", "fur_brown"),
                   "Eyes_Black": ("e1", "eye"), "Eyes_Pupil": ("e2", "eye"), "Eyes_White": ("e3", "white")},
                  head=dict(muzzle="fur_cream", nose="nose", ear="round", ear_in="fur_brown", snout=0.38,
                            brows=lambda st: st >= 2),
                  extra=extra, belly="fur_cream", fat=1.15)
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
