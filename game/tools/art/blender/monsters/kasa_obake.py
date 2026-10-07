"""Kasa-obake / Kasa-obake Centenario (kasa_obake) — Ilhas do Sol Nascente (o guarda-chuva de papel que ganha vida
no folclore japones: um olho so, lingua comprida, pula numa perna de madeira). Modelo proprio por script (nenhum pack
tem guarda-chuva); mesmas regras de pixel art. Pula (quica) em vez de andar."""
import math
from mathutils import Vector
import mon_rig as R

SCALE = {1: 1.1, 2: 1.55}
FRAME = {1: 96, 2: 144}
STAGES = (1, 2)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
C = Vector((0, 0, 0.66))


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.12, 0.12, 0.12)
    rig = R.Rig("kasa_obake")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(18)
    body = rig.empty("body", C, rig.root)
    ribs = 8
    for k in range(ribs):   # gomos de papel alternando vermelho e creme
        a0, a1 = math.tau * k / ribs, math.tau * (k + 1) / ribs
        nm = f"panel{k}"

        def fn(u, v, a0=a0, a1=a1):
            a = a0 + (a1 - a0) * u
            r = 0.3 * v + 0.02 * math.sin(math.pi * u) * v
            z = 0.62 * (1 - v)
            return C + Vector((r * math.cos(a), r * math.sin(a), z - 0.3))
        rig.add_mesh(R.surface(nm, fn, 6, 6, C + Vector((0, 0, -0.5))), nm, "paper" if k % 2 == 0 else "paper_cream", body)
    rig.add_mesh(R.cone("tip", C + Vector((0, 0, 0.3)), C + Vector((0, 0, 0.44)), 0.04, 0.01, seg=6, rings=1), "tip", "wood", body)
    # olho grande no meio do papel, virado para a frente-cima
    ep = C + Vector((0, -0.19, -0.02))
    eye = rig.empty("eye", ep, body)
    rig.add_mesh(R.ellipsoid("eyew", ep, (0.11, 0.05, 0.13), rot=(-0.45, 0, 0)), "eyew", "white", eye, prio=1.5)
    rig.add_mesh(R.ellipsoid("pupil", ep + Vector((0, -0.035, -0.01)), (0.06, 0.03, 0.08), rot=(-0.45, 0, 0)), "pupil", "eye", eye,
                 noline=True, unlit=True, prio=2.5)
    rig.add_mesh(R.ellipsoid("ehl", ep + Vector((-0.03, -0.06, 0.03)), (0.028, 0.02, 0.028)), "ehl", "white", eye, noline=True,
                 unlit=True, prio=6)
    if stage >= 2:   # sobrancelha zangada do centenario e rasgos
        rig.add_mesh(R.cone("brow", ep + Vector((-0.14, -0.05, 0.14)), ep + Vector((0.14, -0.05, 0.1)), 0.02, 0.02, seg=6, rings=1),
                     "brow", "brow", eye, noline=True, unlit=True, prio=2)
    # lingua comprida
    tg = rig.empty("tongue", C + Vector((0, -0.27, -0.17)), body)
    rig.add_mesh(R.cone("tongue", C + Vector((0, -0.26, -0.16)), C + Vector((0, -0.4, -0.38)), 0.05, 0.045, seg=8, rings=4,
                        bend=(0, -0.04, 0.03)), "tongue", "tongue", tg)
    # cabo = perna de madeira com pezinho
    rig.add_mesh(R.cone("leg", C + Vector((0, 0, -0.25)), Vector((0, 0, 0.06)), 0.035, 0.04, seg=8, rings=2), "leg", "wood", rig.root)
    rig.add_mesh(R.ellipsoid("foot", Vector((0, -0.03, 0.04)), (0.07, 0.1, 0.045)), "foot", "wood", rig.root)
    rig.save_rest()
    return rig


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body = rig.root, rig.n("body")
    tg = rig.n("tongue")
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(root, 1 + 0.06 * s)
        body.rotation_euler.y = 0.06 * math.sin(math.tau * t + 1)
        tg.rotation_euler.x = 0.25 * math.sin(math.tau * t * 2)
        if i == n - 2:
            rig.n("eye").scale.z *= 0.15
    elif anim == "walk":   # pulinhos numa perna so
        ph = (2 * t) % 1.0
        hop = 4 * ph * (1 - ph)
        root.location.z += 0.2 * hop
        R.squash(root, 0.78 + 0.4 * hop if ph > 0.1 else 0.75)
        body.rotation_euler.x = -0.1 + 0.15 * hop
        tg.rotation_euler.x = 0.4 * (1 - hop)
    elif anim == "attack":   # agacha e chicoteia a lingua para frente
        R.squash(root, [0.82, 0.72, 1.15, 1.1, 0.95, 1.0, 1.0, 1.0][i])
        R.tilt(root, [-0.1, -0.2, 0.25, 0.3, 0.2, 0.1, 0.0, 0.0][i], 0.0)
        tg.scale.y = tg.scale.z = [1, 1, 1.4, 1.7, 1.5, 1.2, 1.05, 1][i]
        tg.rotation_euler.x = [0.3, 0.4, -0.3, -0.45, -0.35, -0.15, 0, 0][i]
    elif anim == "hit":
        R.squash(root, [0.72, 1.18, 0.94, 1.02][i])
        body.rotation_euler.y = [0.35, -0.2, 0.1, 0][i]
        if i < 2:
            rig.n("eye").scale.z *= 0.2
    elif anim == "death":   # fecha como guarda-chuva e tomba
        close = [0, 0.2, 0.45, 0.7, 0.85, 0.9, 0.9, 0.9][i]
        body.scale.x = body.scale.y = 1 - 0.7 * close
        body.scale.z = 1 + 0.4 * close
        rig.n("eye").scale.z *= max(0.1, 1 - 1.5 * close)
        fall = [0, 0, 0.12, 0.35, 0.65, 0.82, 0.78, 0.8][i]
        root.rotation_euler.y = fall
        root.location.z += [0, 0.08, 0.1, 0.08, 0.05, 0.02, 0.03, 0.02][i]
