"""Serpe da Fonte / Serpe Dourada (fountain_serpent) — Reino das Mouras (as serpentes encantadas das fontes do
folclore portugues). Modelo proprio por script: serpentezinha enrolada como mola (quica!), escamas verde-agua com
pintas douradas, crista dourada e gotinhas; s2 dourada."""
import math
from mathutils import Vector
import mon_rig as R

SCALE = {1: 1.15, 2: 1.65}
FRAME = {1: 96, 2: 144}
STAGES = (1, 2)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
SKIN = {1: "water", 2: "gold"}


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.25, 0.25, 0.25)
    rig = R.Rig("fountain_serpent")
    rig.turn.scale = (SCALE[stage],) * 3
    coil = rig.empty("coil", (0, 0, 0), rig.root)
    n = 16
    for k in range(n):   # mola: espiral de esferas que afina para cima
        a = k * 0.72
        z = 0.07 + 0.028 * k
        rr = 0.2 - 0.004 * k
        p = Vector((rr * math.cos(a), rr * math.sin(a) + 0.04, z))
        s = 0.095 - 0.0015 * k
        rig.add_mesh(R.ellipsoid(f"seg{k}", p, (s, s, s * 0.9)), f"seg{k}", SKIN[stage], coil, group="coil")
        if k % 3 == 1:
            q = p + Vector((0, 0, s * 0.85))
            rig.add_mesh(R.ellipsoid(f"dot{k}", q, (0.03, 0.03, 0.012)), f"dot{k}", "gold" if stage == 1 else "cap", coil, noline=True)
    # pescoco e cabeca
    neck = rig.empty("neck", (0, 0.0, 0.5), rig.root)
    hc = Vector((0, -0.08, 0.7))
    rig.add_mesh(R.cone("neckm", Vector((0, 0.05, 0.47)), hc + Vector((0, 0.02, -0.08)), 0.08, 0.07, seg=10, rings=3), "neckm", SKIN[stage], neck, group="coil")
    head = rig.empty("head", hc, neck)
    rig.add_mesh(R.ellipsoid("head", hc, (0.2, 0.2, 0.17)), "head", SKIN[stage], head, group="head")
    rig.add_mesh(R.ellipsoid("snout", hc + Vector((0, -0.13, -0.03)), (0.11, 0.1, 0.08)), "snout", SKIN[stage], head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = hc + Vector((0.09 * sx, -0.16, 0.05))
        rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (0.062, 0.035, 0.075), rot=(0.4, 0, -0.4 * sx)), f"eye{nm}", "eye", head,
                     noline=True, unlit=True, prio=1.8)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.015, -0.025, 0.02)), (0.018,) * 3), f"hl{nm}", "white", head,
                     noline=True, unlit=True, prio=6)
        rig.add_mesh(R.ellipsoid(f"cheek{nm}", hc + Vector((0.11 * sx, -0.14, -0.03)), (0.03, 0.015, 0.02)), f"cheek{nm}", "blush",
                     head, noline=True, unlit=True)
    for k in range(3):   # crista dourada
        p = hc + Vector((0, 0.02 + 0.06 * k, 0.12 - 0.02 * k))
        rig.add_mesh(R.cone(f"crest{k}", p, p + Vector((0, 0.03, 0.09 - 0.02 * k)), 0.035, 0.005, seg=6, rings=1), f"crest{k}", "gold", head)
    tg = rig.empty("tongue", hc + Vector((0, -0.22, -0.06)), head)
    rig.add_mesh(R.cone("tongue", hc + Vector((0, -0.2, -0.06)), hc + Vector((0, -0.3, -0.08)), 0.012, 0.006, seg=5, rings=1),
                 "tongue", "tongue", tg, noline=True)
    drops = rig.empty("drops", (0, 0, 0), rig.root)
    for k in range(3):
        a = k * 2.1
        rig.add_mesh(R.ellipsoid(f"drop{k}", Vector((0.3 * math.cos(a), 0.3 * math.sin(a), 0.4 + 0.08 * k)), (0.025, 0.025, 0.035)),
                     f"drop{k}", "fur_blue", drops, noline=True)
    rig.save_rest()
    return rig


def pose(rig, anim, i, n, stage):
    t = i / n
    root, coil, neck, head = rig.root, rig.n("coil"), rig.n("neck"), rig.n("head")
    drops = rig.n("drops")
    drops.rotation_euler.z = math.tau * t / 3
    if anim == "idle":   # mola respirando
        s = math.sin(math.tau * t)
        coil.scale.z = 1 + 0.08 * s
        neck.location.z += 0.035 * s
        head.rotation_euler.x = 0.08 * math.sin(math.tau * t - 0.8)
        head.rotation_euler.z = 0.12 * math.sin(math.tau * t)
        if i == n - 2:
            for nm in "LR":
                rig.n(f"eye{nm}").scale.z *= 0.15
    elif anim == "walk":   # quica como mola
        ph = (2 * t) % 1.0
        hop = 4 * ph * (1 - ph)
        root.location.z += 0.14 * hop
        coil.scale.z = 0.8 + 0.4 * hop
        neck.location.z += -0.06 + 0.12 * hop
        head.rotation_euler.x = 0.15 - 0.2 * hop
    elif anim == "attack":   # encolhe a mola e da o bote
        cz = [0.85, 0.7, 1.2, 1.25, 1.1, 1.0, 1.0, 1.0][i]
        coil.scale.z = cz
        neck.location.z += [-0.02, -0.08, 0.1, 0.12, 0.08, 0.03, 0.0, 0.0][i]
        neck.location.y += [0.03, 0.06, -0.12, -0.18, -0.12, -0.05, 0.0, 0.0][i]
        head.rotation_euler.x = [0.2, 0.3, -0.35, -0.4, -0.2, 0.0, 0.0, 0.0][i]
        rig.n("tongue").scale = (1, [1, 1, 2, 2.4, 1.6, 1, 1, 1][i], 1)
    elif anim == "hit":
        coil.scale.z = [0.75, 1.15, 0.95, 1.02][i]
        neck.location.z += [-0.08, 0.04, 0.0, 0.0][i]
        head.rotation_euler.y = [0.4, -0.2, 0.08, 0][i]
        if i < 2:
            for nm in "LR":
                rig.n(f"eye{nm}").scale.z *= 0.2
    elif anim == "death":   # desenrola e deita
        u = [0, 0.15, 0.35, 0.6, 0.8, 0.9, 0.95, 1.0][i]
        coil.scale.z = 1 - 0.65 * u
        coil.scale.x = coil.scale.y = 1 + 0.25 * u
        neck.location.z -= 0.36 * u
        neck.location.y -= 0.1 * u
        head.rotation_euler.y = 1.2 * u
        for nm in "LR":
            rig.n(f"eye{nm}").scale.z *= max(0.12, 1 - 1.5 * u)
        drops.scale = (max(0.001, 1 - u),) * 3
