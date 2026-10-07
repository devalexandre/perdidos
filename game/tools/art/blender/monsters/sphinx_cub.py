"""Esfinge Filhote / Esfinge Enigmatica (sphinx_cub) — Areias do Nilo (a esfinge do Egito antigo, como filhote de
leao alado com lenco listrado azul e dourado; sem simbolos religiosos). Base: esqueleto, patas e animacoes do "Fox"
(Quaternius Ultimate Animated Animals, CC0); corpo, cabeca, lenco e asas nossos."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    # lenco listrado (touca por cima e abas caindo dos lados)
    rig.add_mesh(R.plate("scarf", c, (r * 1.08, r * 1.02, r * 1.02), 0.25, 1.9, -0.25, 3.39, bulge=0.04, res=8),
                 "scarf", "cloth_blue", piv)
    for k, psi in enumerate((0.6, 1.1, 1.6)):
        rig.add_mesh(R.plate(f"stripe{k}", c, (r * 1.1, r * 1.04, r * 1.04), psi - 0.08, psi + 0.08, -0.2, 3.34, bulge=0.0, res=6),
                     f"stripe{k}", "gold", piv, noline=True)
    for sx in (1, -1):
        p = c + Vector((0.9 * r * sx, 0.05 * r, -0.55 * r))
        rig.add_mesh(R.ellipsoid(f"flap{sx}", p, (0.18 * r, 0.32 * r, 0.55 * r), rot=(0, 0.2 * sx, 0)), f"flap{sx}", "cloth_blue", piv)
    mid, bc, br = rig.body
    for sx in (1, -1):   # asas dobradas
        p = bc + Vector((0.75 * br[0] * sx, 0.1 * br[1], 0.75 * br[2]))
        PS.add(rig, pk, mid, R.ellipsoid(f"wing{sx}", p, (0.18 * r, 0.75 * r * (1 + 0.25 * (stage > 1)), 0.35 * r),
                                         rot=(0.35, -0.5 * sx, 0.15 * sx)), f"wing{sx}", "fur_cream")
    t0 = PS.bpos(pk, "Tail1")
    end = t0 + Vector((0, 0.8 * r, 0.3 * r))
    PS.add(rig, pk, "Tail1", R.cone("tail", t0, end, 0.1 * r, 0.07 * r, seg=8, rings=4, bend=(0, 0, 0.25 * r)), "tail", "fur_tawny")
    PS.add(rig, pk, "Tail1", R.ellipsoid("tuft", end, (0.14 * r,) * 3), "tuft", "fur_brown")


S = PS.animal_cub("sphinx_cub", "Fox.gltf", {1: 0.75, 2: 1.1}, "fur_tawny",
                  {"Main": ("legs", "fur_tawny"), "Main_Light": ("legs2", "fur_cream"), "Black": ("paws", "fur_tawny"),
                   "Grey": ("tailtip", "fur_tawny"), "Eyes": ("e", "eye")},
                  head=dict(muzzle="fur_cream", nose="nose", ear="none", snout=0.35, brows=lambda st: st >= 2),
                  extra=extra, belly="fur_cream", fat=1.4)
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
