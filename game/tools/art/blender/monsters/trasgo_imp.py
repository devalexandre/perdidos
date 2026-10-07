"""Trasguinho / Trasgo Resmungao (trasgo_imp) — Reino das Mouras (o trasgo do folclore portugues: diabinho caseiro
travesso de barrete vermelho). Base: corpo, orelhonas e animacoes do "Monkroose" (Big) do Quaternius Ultimate
Monsters (CC0), repintado (pele verde-oliva, tunica marrom remendada); barrete vermelho caido nosso."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage):
    lo, hi, c = PS.head_box(pk)
    w = hi.x - lo.x
    b0 = Vector((c.x, c.y + 0.22 * w, hi.z - 0.02 * w))
    PS.add(rig, pk, "Head", R.ellipsoid("capband", b0, (0.3 * w, 0.26 * w, 0.08 * w), rot=(-0.5, 0, 0)), "capband", "cap_band")
    PS.add(rig, pk, "Head", R.cone("cap", b0 + Vector((0, 0.02 * w, 0.03 * w)), b0 + Vector((0.08 * w, 0.45 * w, 0.2 * w)),
                                   0.26 * w, 0.04 * w, seg=12, rings=6, bend=(0.04 * w, 0.05 * w, 0.14 * w)), "cap", "cap")
    PS.add(rig, pk, "Head", R.ellipsoid("pom", b0 + Vector((0.09 * w, 0.5 * w, 0.14 * w)), (0.08 * w,) * 3), "pom", "white")
    if stage >= 2:   # remendo
        t = PS.bpos(pk, "Torso")
        PS.add(rig, pk, "Torso", R.ellipsoid("patch", t + Vector((0.15 * w, -0.35 * w, 0)), (0.12 * w, 0.03 * w, 0.12 * w)),
               "patch", "paper_cream", noline=True)


S = PS.PackSpecies(
    "trasgo_imp", PS.pack("ultimate-monsters", "Big", "Monkroose.gltf"), heights={1: 1.0, 2: 1.45},
    colormap=[("#78a850", "skin", "goblin"), ("#986028", "tunic", "tunic"), ("#605840", "horns", "horn"),
              ("#8890a0", "teeth", "white"), ("#181820", "eyes", "eye")],
    extras=extra, motion="hop", hop_height=0.1,
    actions={"attack": "Punch", "hit": "HitReact", "death": ("Death", 0.0, 0.5)})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
