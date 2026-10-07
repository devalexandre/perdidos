"""Tatu-Pedra (stone_armadillo): 1 modelo, 3 estagios (GDD 10.6).
  s1 Tatu-Pedra (pequeno)  s2 Tatu-Rochedo (grande: mais placas, musgo, pedras)  s3 Tatu-Montanha (chefe:
  picos de pedra, musgo farto, rachaduras brilhando). Fofo, mas emburrado (ancora a3_3.png).
  s4 Tatu-Montanha Atroz (forma atroz = o chefe a noite): placas de obsidiana roxa, picos altos de basalto com colar
  de brasa, magma brilhando entre todas as faixas, olhos de brasa, chifre pesado + par de chifres, presas, rabo com
  ferrao, liquen frio (ciano) e brasas subindo das rachaduras; a bola do ataque tambem tem espinhos.
Ataque: vira bola e rola (squash & stretch). Pose por quadro em pose(); nada de keyframes no .blend."""
import math
from mathutils import Vector, Euler, Quaternion
import mon_rig as R

SCALE = {1: 1.05, 2: 1.66, 3: 2.55, 4: 2.58}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
BANDS = {1: 5, 2: 6, 3: 7, 4: 7}
STAGES = (1, 2, 3, 4)
# forma atroz (s4): troca de material no modelo do s3 (post.MATS, rampas da noite)
NIGHT = {"shell": "obsidian_n", "leg": "obsidian_n", "skin": "skin_n", "nose": "nose_n", "claw": "horn_n",
         "brow": "brow_n", "moss": "moss_n", "rock": "basalt_n", "eye_glow": "eye_ember"}
BODY_C = Vector((0, 0.12, 0.40))
BODY_R = (0.39, 0.43, 0.34)
SHELL_R = (0.425, 0.465, 0.375)
PSI0, PSI1 = 0.30, 2.25
OM0, OM1 = -0.38, math.pi + 0.38
HEAD_TILT = -0.38   # rosto levantado para a camera alta (le melhor de cima)


def _align(normal):
    q = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized())
    return q.to_euler()


def _on_shell(psi, om, lift=1.0, radii=SHELL_R, center=BODY_C):
    d = R.shell_dir(psi, om)
    p = center + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * lift
    n = Vector((d.x / radii[0], d.y / radii[1], d.z / radii[2])).normalized()
    return p, n


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.36, 0.62, 0.42)
    rig = R.Rig("stone_armadillo")
    rig.turn.scale = (SCALE[stage],) * 3
    root = rig.root
    body = rig.empty("body", BODY_C, root)
    nb = BANDS[stage]
    # corpo (pele por baixo do casco)
    rig.add_mesh(R.ellipsoid("belly", BODY_C, BODY_R), "belly", "skin", body)
    # casco: faixas (psi) x colunas (om) abauladas; saia de placas menores embaixo dos lados
    edges = [PSI0 + (PSI1 - PSI0) * k / nb for k in range(nb + 1)]
    for k in range(nb):
        cols = 3 if k % 2 == 0 else 2
        if stage >= 2:
            cols += 1
        top = [0.22 + (math.pi - 0.44) * c / cols for c in range(cols + 1)]
        oms = [OM0] + top + [OM1]
        for c in range(len(oms) - 1):
            nm = f"plate_{k}_{c}"
            rig.add_mesh(R.plate(nm, BODY_C, SHELL_R, edges[k], edges[k + 1], oms[c], oms[c + 1],
                                 bulge=0.13, res=7), nm, "shell", body)
    # rabo em aneis (curto e grosso)
    tail = rig.empty("tail", (0, 0.52, 0.28), root)
    tb, tt = Vector((0, 0.50, 0.26)), Vector((0, 0.70, 0.26))
    segs = 3
    for i in range(segs):
        a = tb.lerp(tt, i / segs); b = tb.lerp(tt, (i + 1) / segs + (0.03 if i < segs - 1 else 0))
        r0 = 0.09 - 0.065 * i / segs; r1 = 0.09 - 0.065 * (i + 1) / segs
        a.z += 0.10 * (i / segs) ** 2 - 0.05 * math.sin(math.pi * i / segs)
        b.z += 0.10 * ((i + 1) / segs) ** 2 - 0.05 * math.sin(math.pi * (i + 1) / segs)
        rig.add_mesh(R.cone(f"tail{i}", a, b, r0, max(r1, 0.02), seg=10, rings=2), f"tail{i}", "shell", tail)
    # cabeca grande (chibi), rosto levantado para a camera
    head = rig.empty("head", (0, -0.22, 0.42), root)
    HC, HR = Vector((0, -0.40, 0.52)), (0.30, 0.265, 0.28)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "skin", head, group="head")
    rig.add_mesh(R.plate("headplate", HC, (HR[0] * 1.05, HR[1] * 1.05, HR[2] * 1.05), 0.35, 1.45, 0.55,
                         math.pi - 0.55, bulge=0.14, res=7), "headplate", "shell", head)
    rig.add_mesh(R.ellipsoid("snout", (0, -0.645, 0.43), (0.115, 0.10, 0.085), rot=(0.25, 0, 0)), "snout", "skin",
                 head, group="head")
    rig.add_mesh(R.ellipsoid("nose", (0, -0.735, 0.455), (0.07, 0.04, 0.05)), "nose", "nose", head, group="nose")
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = Vector((0.145 * sx, -0.625, 0.585))
        eye = rig.empty(f"eye{nm}", ep, head)
        yaw = -0.45 * sx
        ez = 0.145 if stage < 4 else 0.125
        rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (0.11, 0.05, ez), rot=(0.25, 0, yaw)), f"eye{nm}", "eye", eye,
                     noline=True, unlit=True, prio=1.8)
        if stage < 4:
            rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.03, -0.045)), (0.078, 0.026, 0.07), rot=(0.25, 0, yaw)),
                         f"iris{nm}", "eye_glow" if stage == 3 else "iris", eye, noline=True, unlit=True, prio=1.5)
            rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.035 + 0.008 * sx, -0.055, 0.042)), (0.04, 0.02, 0.04)),
                         f"hl{nm}", "white", eye, noline=True, unlit=True, prio=7.0)
            rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.035, -0.055, -0.05)), (0.02, 0.012, 0.02)),
                         f"hl2{nm}", "white", eye, noline=True, unlit=True, prio=3.0)
        else:
            # olho de brasa: iris grande vermelha, miolo amarelo que tremula, brilho pequeno
            rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.03, -0.03)), (0.085, 0.026, 0.08), rot=(0.25, 0, yaw)),
                         f"iris{nm}", "eye_ember", eye, noline=True, unlit=True, prio=1.6)
            rig.add_mesh(R.ellipsoid(f"core{nm}", ep + Vector((0.0, -0.05, -0.035)), (0.04, 0.02, 0.045), rot=(0.25, 0, yaw)),
                         f"core{nm}", "ember_core", eye, noline=True, unlit=True, prio=3.5)
            rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.04 + 0.008 * sx, -0.06, 0.03)), (0.026, 0.014, 0.026)),
                         f"hl{nm}", "white", eye, noline=True, unlit=True, prio=7.0)
        # sobrancelha emburrada: ponta de dentro mais baixa
        grump = 0.035 + 0.012 * stage
        if stage < 4:
            rig.add_mesh(R.cone(f"brow{nm}", (0.05 * sx, -0.655, 0.715 - grump), (0.225 * sx, -0.57, 0.745), 0.024, 0.02,
                                seg=8, rings=1), f"brow{nm}", "brow", head, noline=True, unlit=True, prio=2.2)
        else:
            # sobrancelha brava: grossa, ponta de dentro bem baixa, colada no olho
            rig.add_mesh(R.cone(f"brow{nm}", (0.035 * sx, -0.66, 0.625), (0.235 * sx, -0.575, 0.745), 0.036, 0.024,
                                seg=8, rings=1), f"brow{nm}", "brow", head, noline=True, unlit=True, prio=2.6)
        # bochecha rosada
        if stage < 4:
            rig.add_mesh(R.ellipsoid(f"cheek{nm}", (0.20 * sx, -0.58, 0.46), (0.05, 0.02, 0.03), rot=(0, 0, -0.7 * sx)),
                         f"cheek{nm}", "blush", head, noline=True, unlit=True, prio=1.2)
        # orelhas grandes
        ear = rig.empty(f"ear{nm}", (0.17 * sx, -0.32, 0.72), head)
        rig.add_mesh(R.ellipsoid(f"ear{nm}", (0.21 * sx, -0.33, 0.84), (0.09, 0.045, 0.14), rot=(0.1, -0.42 * sx, 0)),
                     f"ear{nm}", "skin", ear, group=f"ear{nm}")
        rig.add_mesh(R.ellipsoid(f"earin{nm}", (0.21 * sx, -0.372, 0.83), (0.055, 0.02, 0.095), rot=(0.1, -0.42 * sx, 0)),
                     f"earin{nm}", "nose", ear, noline=True)
    # boca emburrada (biquinho)
    rig.add_mesh(R.cone("mouth", (-0.04, -0.69, 0.375), (0.04, -0.69, 0.375), 0.013, 0.013, seg=6, rings=1, bend=(0, 0, 0.02)),
                 "mouth", "brow", head, noline=True, unlit=True, prio=1.5)
    if stage == 4:
        # presas saindo da boca (para cima) e chifres: um pesado no focinho + um par curvo acima dos olhos
        for sx in (1, -1):
            b = Vector((0.07 * sx, -0.705, 0.37))
            rig.add_mesh(R.cone(f"tusk{sx}", b, b + Vector((0.025 * sx, -0.03, 0.085)), 0.026, 0.004, seg=6, rings=2,
                                bend=(0.01 * sx, -0.01, 0)), "tusk", "fang_n", head, noline=True, prio=2.5)
            hb = Vector((0.12 * sx, -0.44, 0.78))
            rig.add_mesh(R.cone(f"hornp{sx}", hb, hb + Vector((0.2 * sx, 0.16, 0.3)), 0.06, 0.008, seg=8, rings=5,
                                bend=(0.08 * sx, -0.03, 0.02)), f"hornp{sx}", "horn_n", head)
    head.rotation_euler.x += HEAD_TILT
    # pernas curtas
    for sx, fy, nm in ((1, -0.12, "FL"), (-1, -0.12, "FR"), (1, 0.34, "BL"), (-1, 0.34, "BR")):
        lp = Vector((0.25 * sx, fy, 0.18))
        leg = rig.empty(f"leg{nm}", lp, root)
        foot = Vector((0.25 * sx, fy, 0.08))
        rig.add_mesh(R.ellipsoid(f"leg{nm}", foot, (0.095, 0.105, 0.095)), f"leg{nm}", "leg", leg, group=f"leg{nm}")
        for c in (-1, 0, 1):
            b = foot + Vector((0.04 * c, -0.085, -0.05))
            ln, cr = (0.05, 0.02) if stage < 4 else (0.085, 0.026)
            rig.add_mesh(R.cone(f"claw{nm}{c}", b, b + Vector(((0.01 if stage < 4 else 0.012) * c, -ln, -0.02)), cr,
                                (0.006 if stage < 4 else 0.004), seg=6, rings=1),
                         f"claw{nm}", "claw", leg, noline=True)
    # musgo (mais nos estagios maiores) e pedras / picos / rachaduras
    moss = {1: [(0.9, 1.2), (1.6, 2.1), (1.25, 0.55), (2.0, 1.5), (0.6, 2.4)],
            2: [(0.9, 1.2), (1.6, 2.1), (1.25, 0.55), (2.0, 1.5), (0.6, 2.4), (1.4, 1.6), (0.75, 0.6), (1.9, 0.5),
                (1.15, 2.6), (2.1, 2.5)],
            3: [(0.9, 1.2), (1.6, 2.1), (1.25, 0.55), (2.0, 1.5), (0.6, 2.4), (1.4, 1.6), (0.75, 0.6), (1.9, 0.5),
                (1.15, 2.6), (2.1, 2.5), (0.5, 1.4), (1.7, 1.1)],
            4: [(1.25, 0.55), (0.6, 2.4), (1.9, 0.5), (1.15, 2.6), (2.1, 2.5), (0.75, 0.6)]}[stage]
    for i, (psi, om) in enumerate(moss):
        p, n = _on_shell(psi, om, 1.045)
        rs = 0.065 + 0.012 * ((i * 7) % 3)
        rig.add_mesh(R.ellipsoid(f"moss{i}", p, (rs, rs * 0.85, 0.03), rot=_align(n), seg=12, rings=8),
                     f"moss{i}", "moss", body, group="moss")
    if stage == 4:
        _atroz_back(rig, body, edges, nb)
    elif stage >= 2:
        rocks = [(1.05, 1.9, 0.10), (1.75, 1.35, 0.085), (0.7, 1.0, 0.075)] if stage == 2 else \
                [(1.0, 1.57, 0.2), (1.55, 1.95, 0.15), (1.55, 1.15, 0.14), (0.62, 1.95, 0.12), (0.62, 1.2, 0.12),
                 (2.0, 1.57, 0.11)]
        for i, (psi, om, h) in enumerate(rocks):
            p, n = _on_shell(psi, om, 0.98)
            up = (n + Vector((0, 0, 1.2))).normalized()
            if stage == 2:
                rig.add_mesh(R.ellipsoid(f"rock{i}", p + n * 0.03, (h * 0.9, h * 0.8, h * 0.6), rot=_align(n), seg=7, rings=5),
                             f"rock{i}", "rock", body, group=f"rock{i}")
            else:
                rig.add_mesh(R.cone(f"peak{i}", p, p + up * h * 2.1, h * 0.85, h * 0.12, seg=7, rings=3),
                             f"peak{i}", "rock", body, group=f"peak{i}")
                tip = p + up * h * 1.55
                rig.add_mesh(R.ellipsoid(f"cap{i}", tip, (h * 0.42, h * 0.42, h * 0.16), rot=_align(up), seg=10, rings=6),
                             f"cap{i}", "moss", body, group="moss")
    if stage == 2:
        # cristais de ambar brotando entre as placas
        for i, (psi, om, h) in enumerate([(1.35, 2.2, 0.12), (0.85, 0.9, 0.1), (1.9, 1.9, 0.09)]):
            p, n = _on_shell(psi, om, 0.97)
            up = (n + Vector((0, 0, 0.8))).normalized()
            rig.add_mesh(R.cone(f"cry{i}", p, p + up * h * 1.8, h * 0.45, h * 0.05, seg=5, rings=1), f"cry{i}", "amber",
                         body, group=f"cry{i}")
    if stage == 3:
        # rachaduras brilhando nas juntas das faixas
        for k in range(1, nb):
            for (o0, o1) in ((0.35, 1.25), (1.9, 2.8)):
                if (k + int(o0 * 2)) % 2:
                    continue
                nm = f"crack_{k}_{o0}"
                rig.add_mesh(R.plate(nm, BODY_C, SHELL_R, edges[k] - 0.06, edges[k] + 0.06, o0, o1, bulge=0.0,
                                     res=4, lift=1.02), nm, "glow", body, unlit=True, noline=True, prio=2.5)
        rig.add_mesh(R.ellipsoid("horn", (0, -0.715, 0.53), (0.035, 0.035, 0.075), rot=(-0.5, 0, 0)), "horn", "claw", head)
    elif stage == 4:
        # chifre pesado do focinho, curvo para tras
        rig.add_mesh(R.cone("horn", (0, -0.70, 0.50), (0, -0.74, 0.74), 0.07, 0.01, seg=10, rings=5, bend=(0, 0.05, 0)),
                     "horn", "claw", head)
    elif stage == 2:
        rig.add_mesh(R.ellipsoid("horn", (0, -0.715, 0.525), (0.03, 0.03, 0.055), rot=(-0.5, 0, 0)), "horn", "claw", head)
    # bola (ataque rolando): esfera toda de placas, escondida fora do ataque
    BC = Vector((0, 0.10, 0.37))
    ball = rig.empty("ball", BC, root)
    br = (0.37, 0.37, 0.37)
    bands = nb + 1
    for k in range(bands):
        p0 = 0.02 + (math.pi - 0.04) * k / bands; p1 = 0.02 + (math.pi - 0.04) * (k + 1) / bands
        cols = 4 + (k % 2)
        for c in range(cols):
            o0 = math.tau * c / cols + (0.4 if k % 2 else 0); o1 = math.tau * (c + 1) / cols + (0.4 if k % 2 else 0)
            nm = f"bplate_{k}_{c}"
            rig.add_mesh(R.plate(nm, BC, br, p0, p1, o0, o1, bulge=0.08, res=5), nm, "shell", ball)
    for i, (psi, om) in enumerate([(1.0, 1.4), (2.1, 3.9), (1.6, 5.2)]):
        d = R.shell_dir(psi, om)
        p = BC + d * 0.395
        rig.add_mesh(R.ellipsoid(f"bmoss{i}", p, (0.07, 0.06, 0.03), rot=_align(d), seg=10, rings=6),
                     f"bmoss{i}", "moss", ball, group="moss")
    if stage == 4:
        _atroz_ball(rig, ball, BC, br, bands)
        # rabo com ferrao de basalto
        rig.add_mesh(R.cone("tailspike", Vector((0, 0.66, 0.33)), Vector((0, 0.86, 0.45)), 0.05, 0.006, seg=6, rings=3,
                            bend=(0, 0, 0.03)), "tailspike", "rock", tail)
        _atroz_embers(rig, edges, nb)
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ forma atroz (s4)
def _atroz_back(rig, body, edges, nb):
    """Picos altos de basalto (crista + laterais) com colar de brasa, e magma em todas as juntas das faixas."""
    rig.spikes = []
    ridge = [(0.62, 1.57, 0.16), (0.98, 1.57, 0.21), (1.36, 1.57, 0.23), (1.74, 1.57, 0.19), (2.08, 1.57, 0.14)]
    side = [(0.85, 0.92, 0.12), (1.45, 0.8, 0.14), (0.85, 2.22, 0.12), (1.45, 2.34, 0.14)]
    for i, (psi, om, h) in enumerate(ridge + side):
        p, n = _on_shell(psi, om, 0.99)
        up = (n + Vector((0, 0.35, 1.0))).normalized() if i < len(ridge) else (n * 1.6 + Vector((0, 0.2, 0.6))).normalized()
        sp = rig.empty(f"spk{i}", p, body)
        side_ = up.cross(Vector((0, 1, 0))).normalized()
        rig.add_mesh(R.cone(f"spike{i}", p, p + up * h * 2.5, h * 0.62, h * 0.03, seg=5, rings=3,
                            bend=side_ * h * 0.18 * (1 if i % 2 else -1) + Vector((0, h * 0.2, 0))),
                     f"spike{i}", "rock", sp, group=f"spike{i}")
        if i < len(ridge):
            # lasca menor colada (ponta dupla = basalto quebrado)
            q = p + side_ * h * 0.45 * (1 if i % 2 else -1) + Vector((0, 0.04, 0))
            u2 = (up + side_ * 0.5 * (1 if i % 2 else -1)).normalized()
            rig.add_mesh(R.cone(f"shard{i}", q, q + u2 * h * 1.25, h * 0.36, h * 0.02, seg=5, rings=1),
                         f"shard{i}", "rock", sp, group=f"spike{i}")
        # colar de brasa na base do pico
        rig.add_mesh(R.ellipsoid(f"collar{i}", p + n * 0.012, (h * 0.78, h * 0.78, 0.018), rot=_align(n), seg=10, rings=4),
                     "collar", "ember", sp, unlit=True, noline=True, prio=1.4)
        rig.spikes.append(f"spk{i}")
    # magma nas juntas: todas as faixas, em 3 trechos (com falhas = rachadura, nao anel)
    rig.cracks = []
    segs = [(OM0 + 0.25, 0.9), (1.02, 2.12), (2.24, OM1 - 0.25)]
    for k in range(1, nb):
        for j, (o0, o1) in enumerate(segs):
            if (k + j) % 4 == 3:
                continue
            nm = f"crack_{k}_{j}"
            w = 0.036 if (k + j) % 2 else 0.048
            rig.add_mesh(R.plate(nm, BODY_C, SHELL_R, edges[k] - w, edges[k] + w, o0, o1, bulge=0.0, res=5, lift=1.022),
                         nm, "ember_hot" if (k * 3 + j) % 7 == 0 else "ember", body, unlit=True, noline=True, prio=2.6)
            rig.cracks.append(nm)


def _atroz_ball(rig, ball, BC, br, bands):
    """Bola do ataque: magma entre as faixas e espinhos de basalto (sobem no impacto)."""
    for k in range(1, bands):
        pk = 0.02 + (math.pi - 0.04) * k / bands
        nm = f"bcrack{k}"
        rig.add_mesh(R.plate(nm, BC, br, pk - 0.05, pk + 0.05, 0.0, math.tau, bulge=0.0, res=12, lift=1.02), "bcrack",
                     "ember", ball, unlit=True, noline=True, prio=2.2)
    rig.bspikes = []
    pts = [(0.5, 0.3), (0.5, 2.4), (0.5, 4.5), (1.1, 1.3), (1.1, 3.4), (1.1, 5.5), (1.6, 0.3), (1.6, 2.4), (1.6, 4.5),
           (2.1, 1.3), (2.1, 3.4), (2.1, 5.5), (2.65, 0.3), (2.65, 2.4), (2.65, 4.5)]
    for i, (psi, om) in enumerate(pts):
        d = R.shell_dir(psi, om)
        p = BC + d * 0.35
        sp = rig.empty(f"bspk{i}", p, ball)
        rig.add_mesh(R.cone(f"bspike{i}", p, p + d * 0.2, 0.065, 0.006, seg=5, rings=2), f"bspike{i}", "rock", sp,
                     group="bspike")
        rig.bspikes.append(f"bspk{i}")


def _atroz_embers(rig, edges, nb):
    """Brasas soltas que sobem das rachaduras (loop em idle/walk)."""
    ep = rig.empty("embers", (0, 0, 0), rig.root)
    rig.embers = []
    spots = [(2, 0.7), (3, 1.9), (4, 1.2), (5, 2.5), (2, 2.3), (4, 0.4), (3, 1.4), (5, 0.9), (1, 1.6), (6, 2.0)]
    for i, (k, om) in enumerate(spots):
        p, n = _on_shell(edges[min(k, nb - 1)], om, 1.03)
        e = rig.empty(f"emb{i}", p, ep)
        r = 0.022 if i % 3 else 0.03
        rig.add_mesh(R.ellipsoid(f"emb{i}", p, (r, r, r * 1.3), seg=8, rings=5), "emb_hot" if i % 3 == 0 else "emb",
                     "ember_core" if i % 3 == 0 else "ember_hot", e, unlit=True, noline=True, prio=4.0)
        rig.embers.append((f"emb{i}", (i * 0.37) % 1.0, 0.35 + 0.1 * (i % 3), 0.05 * math.sin(i * 2.1)))


def _embers(rig, t, rise=1.0, spread=1.0, fade=1.0):
    """t em ciclos (loop): cada brasa sobe da rachadura, deriva e encolhe."""
    for nm, ph, h, dx in rig.embers:
        u = (t + ph) % 1.0
        o = rig.n(nm)
        base = rig.rest[nm][0]
        o.location = base + Vector((dx * spread + 0.03 * math.sin(math.tau * u * 1.5 + ph * 7), 0.02 * spread,
                                    h * u * rise))
        s = max(0.0001, (1.0 - u) ** 0.7 * fade)
        o.scale = (s, s, s)


def _spikes(rig, k, names=None):
    for nm in (names if names is not None else getattr(rig, "spikes", [])):
        rig.n(nm).scale = (k, k, k)


def _cracks(rig, mat):
    """Todas as rachaduras numa cor so (clarao do golpe / apagando na morte); None = volta ao normal."""
    for nm in getattr(rig, "cracks", []):
        o = rig.n(nm)
        if mat is None:
            rig.set_part(o, nm)
        else:
            rig.set_part(o, "crack_" + mat, mat, unlit=True, noline=True, prio=2.6)


def _atroz_pose(rig, anim, i, n):
    """Movimento extra da forma atroz por cima da pose do s3."""
    t = i / n
    _cracks(rig, None)
    # miolo do olho tremula (amarelo <-> branco-quente)
    for nm in ("L", "R"):
        c = rig.n(f"core{nm}.001") if f"core{nm}.001" in rig.nodes else rig.n(f"core{nm}")
        rig.set_part(c, f"core{nm}" if i % 3 else f"coreb{nm}", "ember_core" if i % 3 else "ember_hot",
                     noline=True, unlit=True, prio=3.5)
    if anim == "idle":
        _embers(rig, t)
        # rosnado: tremida curta da cabeca e picos pulsando junto com a respiracao
        rig.n("head").location.x += 0.008 * math.sin(math.tau * 4 * t)
        _spikes(rig, 1.0 + 0.04 * math.sin(math.tau * t))
        if i == 3:
            _cracks(rig, "ember_hot")
    elif anim == "walk":
        _embers(rig, t, rise=0.8, spread=1.5)
    elif anim == "attack":
        # picos eriçam na preparacao; na bola os espinhos crescem no impacto e soltam brasas
        if i < 2:
            _spikes(rig, [1.08, 1.16][i]); _cracks(rig, "ember" if i == 0 else "ember_hot")
        elif i < 6:
            _spikes(rig, [0.6, 0.95, 1.35, 1.1][i - 2], rig.bspikes)
        else:
            _spikes(rig, [1.1, 1.0][i - 6])
        _embers(rig, [0.1, 0.2, 0.3, 0.4, 0.55, 0.7, 0.85, 0.95][i], rise=1.0, spread=[1, 1, 1.5, 2, 3.5, 3.0, 2, 1.2][i])
    elif anim == "hit":
        _embers(rig, 0.15 * i, spread=[2.5, 2.0, 1.5, 1.2][i])
        if i == 0:
            _cracks(rig, "ember_core")
    elif anim == "death":
        _embers(rig, 0.1 * i, spread=1.5, fade=max(0.0001, 1 - i / 5))
        if i >= 5:
            _cracks(rig, "ember_dim" if i == 5 else "obsidian_n")
        if i >= 2:
            _spikes(rig, [0.7, 0.72, 0.72, 0.7, 0.7, 0.7][i - 2])  # picos murcham ao cair



# ------------------------------------------------------------------ animacao
def _show(rig, name, on):
    o = rig.n(name)
    o.scale = rig.rest[name][2] if on else (0.0001, 0.0001, 0.0001)


def _blink(rig, amt):
    for nm in ("L", "R"):
        e = rig.n(f"eye{nm}")
        e.scale.z *= max(0.12, 1.0 - amt)


def _legs(rig, phase, amp, lift):
    """Trote: pares diagonais alternados. phase em ciclos."""
    for nm, off in (("FL", 0.0), ("BR", 0.0), ("FR", 0.5), ("BL", 0.5)):
        leg = rig.n(f"leg{nm}")
        a = math.sin(math.tau * (phase + off))
        leg.rotation_euler.x = -amp * a
        leg.location.z += lift * max(0.0, math.sin(math.tau * (phase + off) + math.pi / 2))


def _ball_mode(rig, on):
    for nm in ("body", "head", "tail", "legFL", "legFR", "legBL", "legBR"):
        _show(rig, nm, not on)
    _show(rig, "ball", on)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, head, tail, body = rig.root, rig.n("head"), rig.n("tail"), rig.n("body")
    _ball_mode(rig, False)
    if stage == 4:
        _atroz_pose(rig, anim, i, n)
    if anim == "idle":
        # respiracao com quique leve: estica/achata, cabeca atrasada, orelha e rabo mexendo; pisca no fim
        s = math.sin(math.tau * t)
        R.squash(root, 1.0 + 0.045 * s)
        head.location.z += 0.012 * math.sin(math.tau * (t - 0.12))
        head.rotation_euler.x += 0.05 * math.sin(math.tau * (t - 0.1))
        tail.rotation_euler.z = 0.25 * math.sin(math.tau * t)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"ear{nm}").rotation_euler.y = 0.12 * sg * max(0.0, math.sin(math.tau * (t * 2 - 0.2)))
        if i == n - 2:
            _blink(rig, 1.0)
    elif anim == "walk":
        # trote com quique duplo por ciclo (achata no apoio, estica no ar) e ginga lateral
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.05 * b
        R.squash(root, 1.0 + 0.06 * (b - 0.5))
        root.rotation_euler.y = 0.05 * math.sin(math.tau * t)
        root.rotation_euler.x = 0.04 * math.sin(math.tau * 2 * t)
        _legs(rig, t, 0.55, 0.05)
        head.rotation_euler.x += 0.06 * math.sin(math.tau * 2 * t + 1.0)
        head.rotation_euler.z = 0.05 * math.sin(math.tau * t)
        tail.rotation_euler.z = 0.35 * math.sin(math.tau * t + 1.2)
    elif anim == "attack":
        # 0-1 preparacao (agacha, recua), 2 enrola (bola esticada), 3-4 rola e bate (achata), 5 quica,
        # 6 desenrola, 7 volta
        ball = rig.n("ball")
        if i == 0:
            R.squash(root, 0.86); R.tilt(root, -0.12, 0.34)
            head.rotation_euler.x += 0.25; tail.rotation_euler.x = 0.3
        elif i == 1:
            R.squash(root, 0.78); R.tilt(root, -0.12, 0.34); tail.rotation_euler.x = 0.55
            head.location.y += 0.1; head.location.z -= 0.06; head.scale = (0.8, 0.8, 0.8)
            for nm in ("FL", "FR", "BL", "BR"):
                rig.n(f"leg{nm}").location.z += 0.04
            _blink(rig, 0.7)
        else:
            _ball_mode(rig, True)
            roll = {2: 0.0, 3: -1.4, 4: -2.9, 5: -4.3, 6: -5.6, 7: -6.28}[i]
            ball.rotation_euler.x = roll
            if i == 2:
                ball.location.z += 0.06; R.squash(root, 1.22)
            elif i == 3:
                ball.location.z += 0.1; R.squash(root, 1.12)
                root.scale.y *= 1.06
            elif i == 4:
                R.squash(root, 0.78)
            elif i == 5:
                ball.location.z += 0.14; R.squash(root, 1.15)
            elif i == 6:
                _ball_mode(rig, False)
                R.squash(root, 1.14); root.location.z += 0.04
                head.rotation_euler.x += -0.15
                for nm in ("FL", "FR", "BL", "BR"):
                    rig.n(f"leg{nm}").scale = (0.8, 0.8, 0.7)
            elif i == 7:
                _ball_mode(rig, False)
                R.squash(root, 0.93)
    elif anim == "hit":
        # tranco: achata e recua com olhos apertados, estica de volta, assenta
        if i == 0:
            R.squash(root, 0.86); R.tilt(root, -0.1, 0.34)
            head.rotation_euler.x += 0.2; _blink(rig, 0.85)
            for nm, sg in (("L", 1), ("R", -1)):
                rig.n(f"ear{nm}").rotation_euler.y = 0.5 * sg
        elif i == 1:
            R.squash(root, 1.12); R.tilt(root, 0.08, -0.2)
            _blink(rig, 0.6); tail.rotation_euler.x = -0.3
        elif i == 2:
            R.squash(root, 0.95); 
        else:
            R.squash(root, 1.02)
    elif anim == "death":
        # tranco, pulo esticado, vira de costas no ar, cai de barriga para cima, quica, patinhas, fica
        spin = [0, 0.45, 1.7, math.pi, math.pi, math.pi, math.pi, math.pi][i]
        hop = [0, 0.14, 0.2, 0.0, 0.05, 0.0, 0.0, 0.0][i]
        sq = [0.78, 1.18, 1.05, 0.8, 1.06, 0.97, 1.0, 0.96][i]
        if stage == 4:
            sq = 1.0 + (sq - 1.0) * 0.6  # corpo mais comprido (chifre + ferrao): achata menos para caber no quadro
        R.squash(root, sq)
        _blink(rig, 0.9 if i == 0 else 1.0)
        cz = BODY_C.z
        root.rotation_euler.y = spin
        root.location.x += -cz * math.sin(spin)
        root.location.z += cz * (1 - math.cos(spin)) * (0.93 if i >= 3 else 1.0) + hop
        if 4 <= i <= 6:
            _legs(rig, 0.3 * i, 0.5, 0.0)
            tail.rotation_euler.z = [0.5, -0.5, 0.25][i - 4]
        if i >= 3:
            head.rotation_euler.x += 0.45
            tail.rotation_euler.x = -0.7
            root.location.z += 0.12 + {3: 0.16, 4: 0.3}.get(stage, 0.0)
            for nm, sg in (("L", 1), ("R", -1)):
                rig.n(f"ear{nm}").rotation_euler.y = 0.6 * sg
