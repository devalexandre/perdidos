"""Jiangshi Saltitante / Jiangshi Anciao (hopping_jiangshi) — Imperio de Jade (o jiangshi dos contos populares
chineses, em versao comica: pula duro com os bracos esticados; sem papel escrito nem simbolos religiosos).
Base: esqueleto, corpo e animacoes do "Yeti" (Big) do Quaternius Ultimate Monsters (CC0) repintado (tunica verde-agua,
pele verde-palida), bracos esticados para a frente; chapeu redondo e faixa lisa de pano nossos."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage):
    lo, hi, c = PS.head_box(pk)
    w = hi.x - lo.x
    top = Vector((c.x, c.y + 0.25 * w, hi.z + 0.02 * w))
    PS.add(rig, pk, "Head", R.ellipsoid("brim", top, (0.5 * w, 0.46 * w, 0.05 * w), rot=(-0.55, 0, 0)), "brim", "hat")
    PS.add(rig, pk, "Head", R.cone("crown", top, top + Vector((0, 0.12 * w, 0.22 * w)), 0.32 * w, 0.29 * w, seg=14, rings=1),
           "crown", "hat")
    if stage >= 2:
        PS.add(rig, pk, "Head", R.ellipsoid("bead", top + Vector((0, 0.14 * w, 0.26 * w)), (0.07 * w,) * 3), "bead", "gold")
    # faixa lisa de pano pendurada na aba (sem escrita)
    PS.add(rig, pk, "Head", R.ellipsoid("strip", Vector((c.x + 0.25 * w, lo.y + 0.1 * w, c.z)), (0.09 * w, 0.02 * w, 0.26 * w)),
           "strip", "paper_cream")
    # mangas largas
    for sx, b in ((1, "LowerArm.L"), (-1, "LowerArm.R")):
        a, t = PS.bpos(pk, b), PS.bpos(pk, b, True)
        PS.add(rig, pk, b, R.cone(f"sleeve{sx}", a, a + (t - a) * 0.9, 0.12 * w, 0.2 * w, seg=10, rings=2), f"sleeve{sx}", "robe")


S = PS.PackSpecies(
    "hopping_jiangshi", PS.pack("ultimate-monsters", "Big", "Yeti.gltf"), heights={1: 0.98, 2: 1.4},
    colormap=[("#a0a0a0", "robe", "robe"), ("#407888", "skin", "pale_skin"), ("#8890a0", "teeth", "white"),
              ("#181820", "eyes", "eye")],
    rot_bones={"UpperArm.L": (0, 0, -1.2), "UpperArm.R": (0, 0, 1.2)},
    extras=extra, motion="hop", hop_height=0.16,
    actions={"walk": "Idle", "attack": "Punch", "hit": "HitReact", "death": ("Death", 0.0, 0.5)})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
