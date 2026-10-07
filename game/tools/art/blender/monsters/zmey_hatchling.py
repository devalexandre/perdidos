"""Zmey Filhote / Zmey de Duas Cabecas (zmey_hatchling) — Estepe de Ferro (Zmey Gorynych, o dragao de varias
cabecas do folclore eslavo, filhote). Base: corpo, asinhas e animacoes do "Dragon_Evolved" do Quaternius Ultimate
Monsters (CC0), repintado de verde; cabecas extras nossas no pescoco (s1: 1 pequena, s2: 2)."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS
import pack_model as PM


def extra(rig, pk, stage):
    lo, hi, c = PS.head_box(pk)
    w = hi.x - lo.x
    r = w * 0.34 * (0.8 if stage == 1 else 1.0)
    sides = [1] if stage == 1 else [1, -1]
    for sx in sides:
        p = c + Vector((sx * w * 0.75, w * 0.25, -w * 0.15))
        nm = "L" if sx > 0 else "R"
        PS.add(rig, pk, "Neck", R.cone(f"neck{nm}", PS.bpos(pk, "Neck"), p, 0.3 * r, 0.3 * r, seg=8, rings=3), f"neck{nm}", "snake")
        PS.add(rig, pk, "Neck", R.ellipsoid(f"xh{nm}", p, (r, r * 0.95, r * 0.9)), f"xh{nm}", "snake")
        PS.add(rig, pk, "Neck", R.ellipsoid(f"xsn{nm}", p + Vector((0, -0.8 * r, -0.2 * r)), (0.5 * r, 0.5 * r, 0.38 * r)),
               f"xsn{nm}", "snake")
        for ex in (1, -1):
            e = p + Vector((0.35 * r * ex, -0.75 * r, 0.25 * r))
            PS.add(rig, pk, "Neck", R.ellipsoid(f"xe{nm}{ex}", e, (0.2 * r, 0.1 * r, 0.24 * r)), f"xe{nm}{ex}", "eye",
                   noline=True, unlit=True, prio=2)
            PS.add(rig, pk, "Neck", R.ellipsoid(f"xhl{nm}{ex}", e + Vector((-0.06 * r, -0.1 * r, 0.08 * r)), (0.08 * r,) * 3),
                   f"xhl{nm}{ex}", "white", noline=True, unlit=True, prio=6)


S = PS.PackSpecies(
    "zmey_hatchling", PS.pack("ultimate-monsters", "Flying", "Dragon_Evolved.gltf"), heights={1: 0.9, 2: 1.32},
    colormap=[("#905020", "scales", "snake"), ("#583048", "membrane", "leaf"), ("#8890a0", "horns", "horn"),
              ("#181820", "eyes", "eye")],
    bones={f"Wing{k}.{s}": 0.6 for k in range(1, 5) for s in "LR"}, extras=extra, motion="fly", hover=0.1,
    actions={"idle": "Flying_Idle", "walk": "Fast_Flying", "attack": "Headbutt", "hit": "HitReact", "death": "Death"})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
