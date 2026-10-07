"""A Fera da Mata: homem amaldiçoado de silhueta lupina, criado do zero para a Terra do Sabia."""
import math
from mathutils import Vector
import mon_rig as R

SCALE = {1: 0.88, 2: 1.12, 3: 1.65, 4: 1.72}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
ORIGIN_FRAC = 0.76


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.24, 0.28, 0.30)
    rig = R.Rig("werewolf")
    footprint_scale = {1: 0.60, 2: 0.72, 3: 0.75, 4: 0.72}[stage]
    height_scale = 0.78 if stage == 1 else 1.0
    rig.turn.scale = (SCALE[stage] * footprint_scale, SCALE[stage] * footprint_scale,
                      SCALE[stage] * height_scale)
    root = rig.root

    torso = rig.empty("torso", (0, 0, 0.92), root)
    rig.add_mesh(R.ellipsoid("chest", (0, 0.02, 1.18), (0.39, 0.30, 0.53)),
                 "fur", "fur", torso, group="torso")
    rig.add_mesh(R.ellipsoid("belly", (0, -0.13, 0.88), (0.31, 0.25, 0.37)),
                 "belly", "fur_light", torso, group="torso")
    rig.add_mesh(R.ellipsoid("back_mane", (0, 0.20, 1.40), (0.44, 0.31, 0.40)),
                 "mane", "fur_dark", torso, group="mane")

    head = rig.empty("head", (0, -0.19, 1.63), root)
    rig.add_mesh(R.ellipsoid("skull", (0, -0.28, 1.66), (0.31, 0.29, 0.31)),
                 "fur", "fur", head, group="head")
    rig.add_mesh(R.ellipsoid("muzzle", (0, -0.53, 1.56), (0.18, 0.25, 0.16)),
                 "muzzle", "fur_light", head, group="muzzle")
    rig.add_mesh(R.ellipsoid("nose", (0, -0.75, 1.59), (0.09, 0.07, 0.06)),
                 "nose", "nose", head, noline=True, prio=1.5)
    rig.add_mesh(R.cone("jaw", (0, -0.38, 1.46), (0, -0.67, 1.43), 0.14, 0.04, seg=8, rings=2),
                 "mouth", "fur_dark", head)

    for side, suffix in ((-1, "L"), (1, "R")):
        eye_pos = Vector((side * 0.17, -0.505, 1.73))
        rig.add_mesh(R.ellipsoid("eye" + suffix, eye_pos, (0.072, 0.035, 0.055)),
                     "eye", "gold", head, noline=True, unlit=True, prio=2.2)
        rig.add_mesh(R.ellipsoid("pupil" + suffix, eye_pos + Vector((0, -0.029, 0)), (0.02, 0.015, 0.042)),
                     "pupil", "eye_slit", head, noline=True, unlit=True, prio=3.0)
        ear_base = Vector((side * 0.22, -0.18, 1.83))
        ear_tip = Vector((side * 0.29, -0.12, 2.16 if stage < 3 else 2.32))
        rig.add_mesh(R.cone("ear" + suffix, ear_base, ear_tip, 0.10, 0.008, seg=8, rings=3),
                     "fur_dark", "fur_dark", head, group="ears")
        shoulder = Vector((side * 0.35, -0.03, 1.42))
        arm = rig.empty("arm" + suffix, shoulder, root)
        rig.add_mesh(R.ellipsoid("upper_arm" + suffix, shoulder + Vector((side * 0.06, 0, -0.21)),
                                 (0.15, 0.17, 0.31), rot=(0, 0, side * 0.22)),
                     "fur", "fur", arm, group="arms")
        hand = shoulder + Vector((side * 0.10, -0.02, -0.48))
        rig.add_mesh(R.ellipsoid("hand" + suffix, hand, (0.14, 0.13, 0.14)),
                     "fur_dark", "fur_dark", arm, group="hands")
        for claw_index in range(3):
            claw_x = hand.x + (claw_index - 1) * 0.075
            claw_start = Vector((claw_x, hand.y - 0.06, hand.z - 0.06))
            claw_end = claw_start + Vector((0, -0.12, -0.16))
            rig.add_mesh(R.cone("claw_%s_%d" % (suffix, claw_index), claw_start, claw_end,
                                0.035, 0.004, seg=6, rings=2), "claw", "claw", arm, noline=True)

        hip = Vector((side * 0.20, 0.04, 0.55))
        leg = rig.empty("leg" + suffix, hip, root)
        rig.add_mesh(R.ellipsoid("thigh" + suffix, hip + Vector((0, 0, -0.17)), (0.18, 0.19, 0.30)),
                     "fur", "fur", leg, group="legs")
        shin = hip + Vector((0, -0.03, -0.38))
        rig.add_mesh(R.ellipsoid("shin" + suffix, shin, (0.13, 0.14, 0.23)),
                     "fur_dark", "fur_dark", leg, group="legs")
        foot = shin + Vector((0, -0.10, -0.18))
        rig.add_mesh(R.ellipsoid("foot" + suffix, foot, (0.13, 0.21, 0.09)),
                     "fur", "fur", leg, group="feet")
        for claw_index in range(3):
            claw_start = foot + Vector(((claw_index - 1) * 0.07, -0.13, -0.015))
            rig.add_mesh(R.cone("toe_%s_%d" % (suffix, claw_index), claw_start,
                                claw_start + Vector((0, -0.12, -0.025)), 0.025, 0.003, seg=6, rings=1),
                         "claw", "claw", leg, noline=True)

    tail = rig.empty("tail", (0, 0.28, 1.05), torso)
    rig.add_mesh(R.cone("tail_base", (0, 0.28, 1.02), (0, 0.62, 0.91), 0.11, 0.08, seg=8, rings=3,
                        bend=(0, 0.02, -0.03)), "fur_dark", "fur_dark", tail)
    rig.add_mesh(R.ellipsoid("tail_tip", (0, 0.65, 0.90), (0.11, 0.15, 0.12)),
                 "fur", "fur", tail)

    # Jagged cheek and shoulder tufts give the silhouette a distinct mane without hiding the human torso.
    for i in range(5 + stage):
        side = -1 if i % 2 == 0 else 1
        y = -0.30 + (i % 3) * 0.12
        z = 1.50 - (i // 3) * 0.13
        start = Vector((side * (0.28 + (i % 2) * 0.04), y, z))
        end = start + Vector((side * 0.13, -0.04, -0.10 - 0.02 * (i % 3)))
        rig.add_mesh(R.cone("mane_tuft_%d" % i, start, end, 0.10, 0.004, seg=7, rings=2),
                     "fur_light" if i % 2 else "fur_dark", "fur_light" if i % 2 else "fur_dark",
                     torso, group="mane")

    if stage >= 3:
        for side in (-1, 1):
            rig.add_mesh(R.cone("boss_fang_%d" % side,
                                (side * 0.13, -0.64, 1.50), (side * 0.15, -0.69, 1.38),
                                0.035, 0.002, seg=6, rings=2), "claw", "claw", head, noline=True)
        for i in range(3):
            pos = Vector(((i - 1) * 0.18, 0.0, 1.66 + (i % 2) * 0.08))
            rig.add_mesh(R.cone("mane_spike_%d" % i, pos, pos + Vector(((i - 1) * 0.07, 0.18, 0.26)),
                                0.09, 0.006, seg=7, rings=2), "fur_dark", "fur_dark", torso, group="mane")

    if stage == 4:
        # Full-moon form: colder coat, pale scar and violet-blue fire in the eyes.
        for mesh in rig.meshes:
            if mesh.name.startswith(("chest", "skull", "upper_arm", "thigh", "foot", "tail_tip")):
                rig.set_part(mesh, "fur_n", "fur_n")
        for side in (-1, 1):
            rig.set_part(rig.n("eye" + ("L" if side < 0 else "R")), "eye_cyan", "eye_cyan", unlit=True)
        scar = Vector((0.05, -0.585, 1.82))
        rig.add_mesh(R.cone("moon_scar", scar, scar + Vector((0.13, -0.01, -0.18)), 0.025, 0.012, seg=6, rings=1),
                     "glow", "glow", head, noline=True, unlit=True, prio=1.8)

    rig.save_rest()
    return rig


def pose(rig, anim, i, n, stage):
    t = i / n
    root = rig.root
    torso = rig.n("torso")
    head = rig.n("head")
    if anim == "idle":
        breath = math.sin(math.tau * t)
        R.squash(root, 1.0 + 0.025 * breath)
        torso.rotation_euler.x = 0.025 * math.sin(math.tau * t + 0.4)
        head.rotation_euler.x = 0.035 * math.sin(math.tau * t + 1.2)
        rig.n("tail").rotation_euler.x = 0.12 * math.sin(math.tau * t)
    elif anim == "walk":
        stride = math.sin(math.tau * t)
        for suffix, sign in (("L", 1), ("R", -1)):
            rig.n("leg" + suffix).rotation_euler.x = sign * stride * 0.42
            rig.n("arm" + suffix).rotation_euler.x = -sign * stride * 0.34
        root.location.z += 0.025 * abs(math.sin(math.tau * 2 * t))
        torso.rotation_euler.x = -0.06
        rig.n("tail").rotation_euler.x = 0.10 * stride
    elif anim == "attack":
        wind = [0.0, -0.12, -0.28, 0.12, 0.30, 0.18, 0.05, 0.0][i]
        root.rotation_euler.x = wind
        for suffix, sign in (("L", 1), ("R", -1)):
            rig.n("arm" + suffix).rotation_euler.x = [-0.1, -0.25, -0.4, 0.35, 0.48, 0.25, 0.08, 0][i]
            rig.n("arm" + suffix).rotation_euler.y = sign * [0, 0.1, 0.22, 0.08, 0, 0, 0, 0][i]
        head.rotation_euler.x = [0, 0.1, 0.18, -0.08, -0.12, -0.06, 0, 0][i]
    elif anim == "hit":
        R.squash(root, [0.90, 1.06, 0.98, 1.0][i])
        root.rotation_euler.x = [0.08, -0.04, 0.03, 0.0][i]
        head.rotation_euler.y = [0.20, -0.12, 0.05, 0.0][i]
    elif anim == "death":
        root.rotation_euler.x = [0, -0.08, -0.22, -0.50, -0.82, -1.02, -1.08, -1.08][i]
        root.location.z += [0, 0, 0, 0, -0.03, -0.08, -0.08, -0.08][i]
        for suffix in ("L", "R"):
            rig.n("arm" + suffix).rotation_euler.x = [0, -0.1, -0.2, 0.18, 0.45, 0.52, 0.52, 0.52][i]
            rig.n("leg" + suffix).rotation_euler.x = [0, 0.05, 0.08, -0.1, -0.16, -0.16, -0.16, -0.16][i]