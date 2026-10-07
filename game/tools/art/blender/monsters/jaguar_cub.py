"""Jaguarzinho da Selva / Jaguar da Selva (jaguar_cub) — Selvas de Obsidiana (a onca, bicho da mata no folclore
mesoamericano). Base: esqueleto, patas e animacoes do "ShibaInu" (Quaternius Ultimate Animated Animals, CC0);
corpo gordinho e cabeca de filhote nossos (orelhas redondas, careta brincalhona); pelo dourado com rosetas; rabo longo."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    PS.spots(rig, pk, "Head", c, (r * 0.98, r * 0.9, r * 0.88), 6, "spot", 0.1 * r, seed=4, prefix="hs")
    mid, bc, br = rig.body
    PS.spots(rig, pk, mid, bc, br, 9 + 4 * (stage > 1), "spot", 0.13 * r, seed=11, prefix="bs")
    t0 = PS.bpos(pk, "Tail1")
    end = t0 + Vector((0, 0.9 * r, 0.5 * r))
    PS.add(rig, pk, "Tail1", R.cone("tail", t0, end, 0.16 * r, 0.1 * r, seg=10, rings=5, bend=(0, 0.1 * r, 0.3 * r)), "tail", "fur_gold")
    PS.add(rig, pk, "Tail1", R.ellipsoid("tailtip", end, (0.13 * r,) * 3), "tailtip", "fur_dark")


S = PS.animal_cub("jaguar_cub", "ShibaInu.gltf", {1: 0.9, 2: 1.36}, "fur_gold",
                  {"Main": ("legs", "fur_gold"), "Main_Light": ("legs2", "fur_cream"), "Black": ("paws", "fur_dark"),
                   "Eyes_Black": ("e1", "eye"), "Eyes_Pupil": ("e2", "eye"), "Eyes_White": ("e3", "white")},
                  head=dict(muzzle="fur_cream", nose="nose", ear="round", ear_in="fur_dark", snout=0.4,
                            brows=lambda st: True),
                  extra=extra, belly="fur_cream")
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
