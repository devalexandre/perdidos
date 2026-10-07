"""Cabaninha Andante / Cabana de Pes de Galinha (walking_hut) — Estepe de Ferro (a isba de pes de galinha do conto
eslavo, em miniatura travessa). Modelo proprio por script: cabana de toras com telhado de palha, janela redonda
que brilha como um olho e duas pernas de galinha; fumacinha na chamine."""
import math
from mathutils import Vector
import mon_rig as R

SCALE = {1: 1.0, 2: 1.45}
FRAME = {1: 96, 2: 144}
STAGES = (1, 2)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
HC = Vector((0, 0, 0.72))


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.3, 0.3, 0.35)
    rig = R.Rig("walking_hut")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(20)
    hut = rig.empty("hut", HC, rig.root)
    for k in range(4):   # toras empilhadas
        z = HC.z - 0.16 + 0.1 * k
        rig.add_mesh(R.cone(f"logf{k}", Vector((-0.3, -0.22, z)), Vector((0.3, -0.22, z)), 0.055, 0.055, seg=10, rings=1),
                     f"logf{k}", "wood_log", hut, group="walls")
        rig.add_mesh(R.cone(f"logb{k}", Vector((-0.3, 0.22, z)), Vector((0.3, 0.22, z)), 0.055, 0.055, seg=10, rings=1),
                     f"logb{k}", "wood_log", hut, group="walls")
        for sx in (1, -1):
            rig.add_mesh(R.cone(f"logs{k}{sx}", Vector((0.27 * sx, -0.26, z + 0.05)), Vector((0.27 * sx, 0.26, z + 0.05)), 0.055,
                                0.055, seg=10, rings=1), f"logs{k}{sx}", "wood_log", hut, group="walls")
    rig.add_mesh(R.ellipsoid("fill", HC, (0.27, 0.21, 0.2)), "fill", "wood_log", hut, group="walls")
    # telhado de palha redondo (cone) com beiral
    rig.add_mesh(R.cone("roof", HC + Vector((0, 0.03, 0.22)), HC + Vector((0, 0.08, 0.5)), 0.36, 0.03, seg=16, rings=4,
                        bend=(0, 0, 0.04)), "roof", "thatch", hut)
    rig.add_mesh(R.cone("chim", HC + Vector((0.16, 0.14, 0.32)), HC + Vector((0.16, 0.14, 0.58)), 0.05, 0.05, seg=8, rings=1),
                 "chim", "rock", hut)
    smoke = rig.empty("smoke", HC + Vector((0.16, 0.14, 0.62)), hut)
    for k in range(2):
        rig.add_mesh(R.ellipsoid(f"smk{k}", HC + Vector((0.16 + 0.03 * k, 0.14, 0.66 + 0.09 * k)), (0.05 + 0.02 * k,) * 3),
                     f"smk{k}", "smoke", smoke, noline=True)
    # janela redonda = olho; porta
    ep = HC + Vector((0.1, -0.29, 0.06))
    win = rig.empty("win", ep, hut)
    rig.add_mesh(R.ellipsoid("winframe", ep, (0.12, 0.03, 0.12), rot=(0.1, 0, 0)), "winframe", "wood", win)
    rig.add_mesh(R.ellipsoid("winglow", ep + Vector((0, -0.02, 0)), (0.09, 0.02, 0.09), rot=(0.1, 0, 0)), "winglow", "window",
                 win, noline=True, unlit=True, prio=2)
    rig.add_mesh(R.ellipsoid("pupil", ep + Vector((0.01, -0.035, -0.005)), (0.04, 0.015, 0.055)), "pupil", "eye", win,
                 noline=True, unlit=True, prio=3)
    if stage >= 2:
        rig.add_mesh(R.cone("lid", ep + Vector((-0.1, -0.04, 0.1)), ep + Vector((0.1, -0.04, 0.07)), 0.018, 0.018, seg=6, rings=1),
                     "lid", "brow", win, noline=True, unlit=True, prio=2)
    rig.add_mesh(R.ellipsoid("door", HC + Vector((-0.12, -0.27, -0.06)), (0.08, 0.02, 0.13)), "door", "wood", hut, noline=True)
    # pernas de galinha
    for sx, nm in ((1, "L"), (-1, "R")):
        leg = rig.empty(f"leg{nm}", Vector((0.14 * sx, 0, HC.z - 0.2)), rig.root)
        top, knee, ank = Vector((0.14 * sx, 0, HC.z - 0.2)), Vector((0.17 * sx, 0.1, 0.26)), Vector((0.15 * sx, -0.02, 0.05))
        rig.add_mesh(R.ellipsoid(f"thigh{nm}", (top + knee) / 2, (0.08, 0.08, 0.16)), f"thigh{nm}", "chicken_leg", leg)
        rig.add_mesh(R.cone(f"shin{nm}", knee, ank, 0.035, 0.03, seg=8, rings=2), f"shin{nm}", "chicken_leg", leg)
        for k, a in enumerate((-0.5, 0, 0.5)):
            rig.add_mesh(R.cone(f"toe{nm}{k}", ank, ank + Vector((0.09 * math.sin(a), -0.1 * math.cos(a), -0.045)), 0.02, 0.008, seg=6,
                                rings=1), f"toe{nm}{k}", "chicken_leg", leg)
    rig.save_rest()
    return rig


def _legs(rig, ph, amp=0.5, lift=0.06):
    for nm, off in (("L", 0.0), ("R", 0.5)):
        leg = rig.n(f"leg{nm}")
        a = math.sin(math.tau * (ph + off))
        leg.rotation_euler.x = -amp * a
        leg.location.z += lift * max(0.0, math.cos(math.tau * (ph + off)))


def pose(rig, anim, i, n, stage):
    t = i / n
    root, hut, smoke = rig.root, rig.n("hut"), rig.n("smoke")
    smoke.location.z += 0.04 * t
    smoke.scale = (1 + 0.3 * t,) * 3
    if anim == "idle":
        s = math.sin(math.tau * t)
        hut.location.z += 0.02 * s
        R.squash(hut, 1 + 0.04 * s, anchored=False)
        hut.rotation_euler.y = 0.04 * math.sin(math.tau * t)
        if i == n - 2:
            rig.n("win").scale.z *= 0.2
    elif anim == "walk":   # passos de galinha: a casa sacode e quica
        _legs(rig, t)
        b = abs(math.sin(math.tau * t))
        hut.location.z += 0.05 * b
        hut.rotation_euler.y = 0.08 * math.sin(math.tau * t)
        R.squash(hut, 1 + 0.06 * (b - 0.5), anchored=False)
    elif anim == "attack":   # chute com a perna direita
        k = [0, -0.4, -0.7, 1.1, 1.3, 0.8, 0.3, 0][i]
        rig.n("legR").rotation_euler.x = -k
        rig.n("legR").location.z += max(0.0, k) * 0.08
        hut.rotation_euler.x = [0, 0.1, 0.15, -0.15, -0.2, -0.1, 0, 0][i]
        R.squash(hut, [0.9, 0.85, 0.85, 1.1, 1.08, 1.0, 1.0, 1.0][i], anchored=False)
    elif anim == "hit":
        R.squash(hut, [0.8, 1.12, 0.95, 1.02][i], anchored=False)
        hut.rotation_euler.y = [0.25, -0.15, 0.06, 0][i]
        if i < 2:
            rig.n("win").scale.z *= 0.2
    elif anim == "death":   # pernas dobram, a casa senta e a janela apaga
        sit = [0, 0.2, 0.45, 0.7, 0.9, 1.0, 1.0, 1.0][i]
        for nm in ("L", "R"):
            rig.n(f"leg{nm}").rotation_euler.x = -1.2 * sit
        hut.location.z -= 0.32 * sit
        hut.rotation_euler.y = [0, 0.1, 0.2, 0.25, 0.2, 0.18, 0.2, 0.2][i]
        R.squash(hut, [0.85, 1.05, 0.95, 0.85, 0.95, 0.92, 0.93, 0.92][i], anchored=False)
        if i >= 4:
            rig.n("win").scale.z *= 0.15
