"""Escorpiao das Dunas / Escorpiao Rubro (dune_scorpion) — Areias do Nilo (escorpiao gigante do deserto, fofo
e ameacador). Base: corpo, pincas, patas e animacoes do "Crab" do Quaternius Cute Animated Monsters (CC0),
repintado de areia/ocre (s2: vermelho); cauda curvada com ferrao turquesa nossa, presa ao corpo."""
import math
from mathutils import Vector
import mon_rig as R
import pack_species as PS
import pack_model as PM

ARMOR = {1: "sand", 2: "paper"}


def extra(rig, pk, stage):
    lo, hi = PM.bbox(pk)
    h = hi.z - lo.z
    root_b = pk.armature.data.bones[0].name
    base = Vector((0, hi.y * 0.8, lo.z + h * 0.45))
    pts = []
    for k in range(6):   # cauda em arco por cima das costas
        a = math.pi * 0.08 + k * math.pi * 0.17
        p = base + Vector((0, math.cos(a) * 0.35 * h + 0.1 * h, math.sin(a) * 0.55 * h))
        pts.append(p)
        PS.add(rig, pk, root_b, R.ellipsoid(f"tail{k}", p, (0.14 * h * (1 - k * 0.06),) * 3), f"tail{k}", ARMOR[stage])
    tip = pts[-1] + Vector((0, -0.12 * h, -0.05 * h))
    PS.add(rig, pk, root_b, R.cone("sting", pts[-1], tip + Vector((0, -0.08 * h, -0.12 * h)), 0.09 * h, 0.01 * h, seg=6, rings=2),
           "sting", "turquoise")
    rig.tail_pts = pts


S = PS.PackSpecies(
    "dune_scorpion", PS.pack("cute-animated-monsters", "Crab.gltf"), heights={1: 0.72, 2: 1.08},
    colormap=[("#481818", "armor", "sand"), ("#301010", "armor", "sand"), ("#602020", "armor", "sand"),
              ("#682828", "armor", "sand"), ("#000000", "eyes", "eye"), ("#101010", "eyes", "eye")],
    extras=extra, actions={"attack": "Bite_InPlace", "hit": "HitRecieve", "death": "Death"})
_build = S.build


def build(stage):
    if stage == 2:   # Escorpiao Rubro: armadura vermelha
        S.colormap = [(c, p, ("paper" if r == "sand" else r)) for c, p, r in S.colormap]
    return _build(stage)


STAGES = (1, 2)
FRAME, ANIMS, _ST, pose = S.FRAME, S.ANIMS, S.STAGES, S.pose
