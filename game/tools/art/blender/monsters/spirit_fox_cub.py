"""Raposinha Espiritual / Raposa de Tres Caudas (spirit_fox_cub) — Imperio de Jade (raposas espirituais do folclore
chines). Base: esqueleto, corpo e animacoes do "Fox" (Quaternius Ultimate Animated Animals, CC0) reformados em filhote;
cabeca de filhote nossa; pelo branco e chamas espirituais azuis nas pontas das caudas (s1: 2 caudas, s2: 3)."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    tails = PS.tail_ring(pk)
    t0, tip = tails[0][0], tails[-1][1]
    for k in range(1 if stage == 1 else 2):
        side = 1 if k == 0 else -1
        end = t0 + (tip - t0) * 0.9 + Vector((0.5 * r * side, 0.0, 0.4 * r))
        PS.add(rig, pk, "Tail1", R.cone(f"tailx{k}", t0, end, 0.28 * r, 0.2 * r, seg=10, rings=4,
                                        bend=(0.2 * r * side, 0, 0.3 * r)), f"tailx{k}", "fur_white")
        PS.add(rig, pk, "Tail1", R.ellipsoid(f"flamex{k}", end + Vector((0, 0.1 * r, 0.12 * r)), (0.26 * r, 0.26 * r, 0.36 * r)),
               f"flamex{k}", "spirit_flame", noline=True, unlit=True, prio=2)
    PS.add(rig, pk, "Tail8", R.ellipsoid("flame0", tip + Vector((0, 0.08 * r, 0.1 * r)), (0.28 * r, 0.28 * r, 0.38 * r)),
           "flame0", "spirit_flame", noline=True, unlit=True, prio=2)


S = PS.animal_cub("spirit_fox_cub", "Fox.gltf", {1: 0.72, 2: 1.1}, "fur_white",
                  {"Main": ("fur", "fur_white"), "Main_Light": ("fur_light", "fur_white"), "Black": ("paws", "fur_blue"),
                   "Grey": ("tailtip", "fur_blue"), "Eyes": ("eyes_pack", "eye")},
                  head=dict(nose="eye", ear="pointy", ear_in="fur_blue", snout=0.5, brows=lambda st: st >= 2),
                  extra=extra, fat=1.45)
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
