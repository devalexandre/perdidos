"""Harpia (harpy_eagle) — a HARPIA MITOLOGICA, monstro da fauna nativa (fly_pattern). Direcao do dono (08/10/2026):
mulher-ave PREDADORA (nao fada), da mesma familia da pet harpy_companion (cabelo cinza-azulado, couraca de penas
claras, bracadeiras, pernas de ave cinza, asas ardosia com pontas claras), mas suja, angulosa e hostil. Sem
sensualizacao: tronco coberto por couraca de penas e couro. Modelo proprio por script; olhos/sobrancelha no espirito do
sol_common (legiveis), mas estreitos, de rapina, com pupila em fenda.
  Postura de ataque: corpo inclinado para a frente, ombros erguidos, maos em garra para a frente, asas GRANDES nas
  costas (meio abertas, primarias longas e pontudas como laminas, bordas desfiadas), pernas de ave longas com garras
  abertas embaixo; gola de penas eriçadas; coroa de espinhos de osso; boca aberta com presinhas.
  s1 Harpia Jovem (96): menor, coroa de 3 espinhos.
  s2 Harpia Cacadora (144): adulta, garras maiores, penas-dardo no quadril, cicatriz no rosto, coroa de 5 espinhos.
  s3 Soberana das Alturas (240, chefe): asas enormes, coroa alta de espinhos de osso com penas negras, colar de ossos,
     cauda longa, olhos acesos de ambar, penas soltas girando.
  s4 Harpia-Real Atroz (240, noite): paleta noturna, penas-lamina com fio de luz fria, coroa de laminas, olhos acesos
     de luz fria, garras de osso compridas, fogos-fatuos.
Animacao (fly_pattern): idle = paira com bater de asas forte, cabeca "cacando" aos trancos; walk = voo baixo
inclinada; attack = sobe, grita e mergulha cravando as garras dos pes; hit; death = cai e fica caida.
Materiais proprios em harpy_eagle_mats.json (so cores da paleta mestra)."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

SCALE = {1: 0.84, 2: 1.13, 3: 1.76, 4: 1.62}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"harpy_skin": "skin_n", "harpy_slate": "crow_n", "harpy_black": "crow_n", "harpy_hair": "fur_n",
         "harpy_dirty": "pale_n", "harpy_grey": "fur_slate_n", "harpy_bone": "fang_n", "tunic": "thorn_n",
         "harpy_leg": "fur_slate_n", "harpy_talon": "fang_n", "harpy_brow": "brow_n", "wood": "thorn_n",
         "harpy_bar": "wisp_v2", "harpy_scar": "ember_dim", "harpy_shade": "brow_n"}
LEAN = 6.0
FWD = 0.32          # corpo inclinado para a frente (postura de ataque)
HEAD_TILT = -0.8   # cabeca levantada contra a inclinacao (olha para a frente/camera)


def _dims(stage):
    if stage == 1:
        return dict(hip=0.44, BR=(0.105, 0.085, 0.15), HR=(0.2, 0.155, 0.19), wing=1.5, talon=1.0, hair=1.2, ns=3)
    if stage == 2:
        return dict(hip=0.46, BR=(0.11, 0.09, 0.16), HR=(0.19, 0.15, 0.18), wing=1.7, talon=1.25, hair=1.4, ns=5)
    return dict(hip=0.47, BR=(0.115, 0.09, 0.17), HR=(0.185, 0.145, 0.175), wing=1.8, talon=1.4, hair=1.7, ns=7)


def _blade(name, b, d, ln, wd, side, th=0.012):
    """Pena-lamina: losango achatado e pontudo de b ao longo de d (comprimento ln, largura wd), plano com normal 'side'."""
    d = Vector(d).normalized()
    n = Vector(side).normalized()
    w = d.cross(n)
    if w.length < 1e-4:
        w = d.orthogonal()
    w.normalize()
    n = w.cross(d).normalized()
    b = Vector(b)
    tip = b + d * ln
    mid = b + d * ln * 0.38
    verts = [b, mid + w * wd * 0.5, tip, mid - w * wd * 0.5, mid + n * th, mid - n * th]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)]
    ob = R._obj_from(name, verts, faces, smooth=False)
    R._fix_normals(ob, mid)
    return ob


def _eye(rig, nm, ep, piv, rx, rz, yaw, night, boss):
    """Olho de rapina: estreito, iris ambar (chefe: acesa; noite: luz fria), pupila em fenda, brilho pequeno."""
    sx = 1 if nm == "L" else -1
    e = rig.empty(f"eye{nm}", ep, piv)
    rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (rx, 0.03, rz), rot=(0.25, 0, yaw)), f"eye{nm}", "eye", e, noline=True,
                 unlit=True, prio=1.8)
    iris = "eye_cyan" if night else ("glow_hot" if boss else "eye_glow")
    rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0, -0.012, -0.004)), (rx * 0.82, 0.02, rz * 0.78), rot=(0.25, 0, yaw)),
                 f"iris{nm}", iris, e, noline=True, unlit=True, prio=1.9)
    rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0.002 * sx, -0.026, -0.004)), (rx * 0.18, 0.012, rz * 0.72),
                             rot=(0.25, 0, yaw)), f"slit{nm}", "eye_slit", e, noline=True, unlit=True, prio=4.0)
    rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.012 * sx, -0.03, rz * 0.35)), (rx * 0.2, 0.01, rz * 0.25)),
                 f"hl{nm}", "white", e, noline=True, unlit=True, prio=6.0)
    return e


def _wing(rig, nm, sx, root, wk, parent, stage):
    """Asa grande nas costas: osso da asa para cima/fora/tras, cobertas ardosia, secundarias cinza-sujo penduradas e
    primarias longas e pontudas como laminas (pontas claras-sujas). Pivo na raiz (bater = rotacao em y)."""
    night = stage == 4
    w = rig.empty(f"wing{nm}", root, parent)
    g = f"wing{nm}"
    up = math.radians(38)
    d = Vector((math.cos(up) * sx, 0.22, math.sin(up))).normalized()
    elb = root + d * 0.17 * wk
    d2 = Vector((math.cos(up - 0.45) * sx, 0.12, math.sin(up - 0.45))).normalized()
    wr = elb + d2 * 0.17 * wk
    nrm = Vector((0, -1, 0.9))   # plano da asa de frente para a camera (inclinado para tras)
    rig.add_mesh(R.cone(f"wbone{nm}", root, elb, 0.035 * wk, 0.03 * wk, seg=8, rings=2), f"wbone{nm}", "harpy_slate", w,
                 group=g + "b")
    rig.add_mesh(R.cone(f"wbone2{nm}", elb, wr, 0.03 * wk, 0.022 * wk, seg=8, rings=2), f"wbone2{nm}", "harpy_slate", w,
                 group=g + "b")
    nf = {1: 5, 2: 6}.get(stage, 8)
    for k in range(nf):
        u = (k + 0.5) / nf
        b = root.lerp(elb, min(1.0, u * 2)) if u < 0.5 else elb.lerp(wr, (u - 0.5) * 2)
        ang = math.radians(-100 + 45 * u)
        dd = Vector((math.cos(ang) * sx, 0.18, math.sin(ang))).normalized()
        ln = (0.2 + 0.16 * u) * wk * (1.0 + 0.08 * ((k * 7) % 3 - 1))   # bordas desfiadas (comprimentos irregulares)
        mat = "harpy_grey" if k % 2 == 0 else "harpy_dirty"
        if night:
            mat = "fang_n" if k % 2 else "crow_n"
        rig.add_mesh(_blade(f"sec{nm}{k}", b + Vector((0, 0.02 + 0.003 * k, 0)), dd, ln, 0.15 * wk, nrm), f"sec{nm}{k}", mat, w,
                     group=g + ("s0" if k % 2 == 0 else "s1"))
        if night and k % 2:
            rig.add_mesh(_blade(f"sedge{nm}{k}", b + dd * ln * 0.45 + Vector((0, 0.01, 0)), dd, ln * 0.5, 0.02 * wk, nrm),
                         "wedge", "cold_hot", w, unlit=True, noline=True, prio=2.5)
    for k in range(nf - 1):
        u = (k + 0.9) / nf
        b = root.lerp(elb, min(1.0, u * 2)) if u < 0.5 else elb.lerp(wr, (u - 0.5) * 2)
        ang = math.radians(-95 + 45 * u)
        dd = Vector((math.cos(ang) * sx, 0.15, math.sin(ang))).normalized()
        rig.add_mesh(_blade(f"cov{nm}{k}", b + Vector((0, -0.004, 0)), dd, (0.13 + 0.04 * u) * wk, 0.15 * wk, nrm), f"cov{nm}",
                     "harpy_grey", w, group=g + "c")
    npr = {1: 5, 2: 6}.get(stage, 8)
    for k in range(npr):
        f = k / max(1, npr - 1)
        ang = math.radians(48 - 80 * f)
        dd = Vector((math.cos(ang) * sx, 0.1, math.sin(ang))).normalized()
        ln = (0.42 - 0.1 * abs(f - 0.3)) * wk * (1.15 if night else 1.0) * (1.0 + 0.06 * ((k * 5) % 3 - 1))
        b = wr + Vector((0, 0.03 + 0.003 * k, 0))
        mat = ("harpy_slate" if k % 2 else "harpy_black") if not night else ("crow_n" if k % 2 else "fang_n")
        rig.add_mesh(_blade(f"prim{nm}{k}", b, dd, ln, 0.11 * wk, nrm), f"prim{nm}{k}", mat, w, group=g + ("p0" if k % 2 else "p1"))
        tipm = "harpy_dirty" if not night else "cold_hot"
        rig.add_mesh(_blade(f"ptip{nm}{k}", b + dd * ln * 0.5 + Vector((0, -0.006, 0)), dd, ln * 0.5, 0.1 * wk, nrm),
                     f"ptip{nm}", tipm, w, group=g + "t", unlit=night, noline=night)
    return w


def build(stage):
    if stage not in STAGES:
        raise ValueError("estagios: 1, 2, 3 (chefe), 4 (atroz)")
    R.reset()
    D = _dims(stage)
    BR, HR = D["BR"], D["HR"]
    boss, night = stage >= 3, stage == 4
    R.CUR["reach"] = (0.22, 0.25, 0.2) if not boss else (0.26, 0.3, 0.26)
    rig = R.Rig("harpy_eagle")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    hip = D["hip"]
    body = rig.empty("body", (0, 0.0, hip), root)
    BC = Vector((0, 0.0, hip + 0.15))
    # ---- tronco esguio: couraca de penas claras-sujas sobre couro gasto, gola de penas eriçadas, cinto
    rig.add_mesh(R.ellipsoid("torso", BC, BR), "torso", "tunic", body, group="torso")
    pc = BC + Vector((0, -BR[1] * 0.4, 0.01)); pr = (BR[0] * 0.86, BR[1] * 0.66, BR[2] * 0.86)
    rig.add_mesh(R.ellipsoid("plate", pc, pr), "plate", "harpy_dirty", body, group="plate")
    for k in range(3):
        z = pc.z + 0.06 - 0.05 * k
        for j in (-1, 0, 1):
            x = j * 0.04 + (0.02 if k % 2 else 0.0)
            if abs(x) > pr[0] * 0.75:
                continue
            y = S.ysurf(pc, pr, x, z) - 0.004
            rig.add_mesh(_blade(f"psc{k}{j}", (x, y, z + 0.02), (0, -0.2, -1), 0.05, 0.04, (0, -1, 0.1), th=0.006), "pscale",
                         "harpy_dirty", body, prio=1.1)
    nz = BC.z + BR[2] * 0.85
    for k in range(12):
        a = math.tau * k / 12
        b = Vector((math.cos(a) * BR[0] * 0.75, BC.y + math.sin(a) * BR[1] * 0.75, nz - 0.01))
        dd = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.55)).normalized()
        ln = 0.08 + 0.03 * (k % 2)
        rig.add_mesh(R.cone(f"ruff{k}", b, b + dd * ln, 0.03, 0.003, seg=6, rings=2), f"ruff{k}",
                     "harpy_slate" if k % 2 else "harpy_grey", body, group=f"ruff{k % 2}")
    belt_z = BC.z - BR[2] * 0.62
    rig.add_mesh(S.torus("belt", (0, BC.y, belt_z), BR[0] * 0.95, 0.02, yscale=0.85, nu=22), "belt", "tunic", body,
                 group="belt")
    rig.add_mesh(R.ellipsoid("buckle", (0, BC.y - BR[1] * 0.9 - 0.012, belt_z), (0.026, 0.01, 0.022)), "buckle", "harpy_bone",
                 body, prio=2.0)
    if boss:
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.32
            b = Vector((math.cos(a) * BR[0] * 0.95, BC.y + math.sin(a) * BR[1] * 0.95, nz - 0.03))
            rig.add_mesh(R.cone(f"bone{k}", b, b + Vector((0, -0.02, -0.07 + 0.015 * abs(k - 2))), 0.016, 0.003, seg=6, rings=2,
                                bend=(0, -0.01, 0)), "bonecol", "harpy_bone", body, prio=1.8)
    skirt = rig.empty("skirt", (0, BC.y, belt_z), body)
    ns = 12 if not boss else 16
    for k in range(ns):
        a = math.tau * k / ns
        b = Vector((math.cos(a) * BR[0] * 0.88, BC.y + math.sin(a) * BR[1] * 0.88, belt_z))
        back = max(0.0, math.sin(a))
        ln = (0.12 if stage == 1 else 0.15) * (1.0 + (0.9 if boss else 0.5) * back) * (1.0 + 0.12 * ((k * 3) % 3 - 1))
        dd = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -1)).normalized()
        mat = "harpy_dirty" if k % 2 == 0 else "harpy_grey"
        if night and k % 2:
            mat = "fang_n"
        rig.add_mesh(_blade(f"skirt{k}", b, dd, ln, 0.06, Vector((math.cos(a), math.sin(a), 0))), f"skirt{k}", mat, skirt,
                     group=f"skirt{k % 2}")
    tail = rig.empty("tail", (0, BC.y + BR[1] * 0.7, belt_z), body)
    nt = 3 if stage == 1 else (4 if stage == 2 else 6)
    tl = {1: 0.22, 2: 0.3}.get(stage, 0.5)
    for k in range(nt):
        a = (k - (nt - 1) / 2) * 0.25
        b = Vector((math.sin(a) * 0.04, BC.y + BR[1] * 0.6, belt_z + 0.01))
        dd = Vector((math.sin(a) * 0.5, 0.8, -0.6)).normalized()
        rig.add_mesh(_blade(f"tail{k}", b, dd, tl * (1 - 0.1 * abs(a)), 0.07, (0, 0.6, 0.8)), f"tail{k}",
                     "harpy_slate" if k % 2 == 0 else "harpy_grey", tail, group=f"tail{k % 2}")
    # ---- pernas de ave longas: coxa emplumada barrada, canela cinza, garras grandes abertas
    tk = D["talon"]
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.06 * sx
        hz = belt_z - 0.04
        leg = rig.empty(f"leg{nm}", (hx, BC.y, hz), body)
        g = f"leg{nm}"
        rig.add_mesh(R.ellipsoid(f"thigh{nm}", (hx * 1.1, BC.y - 0.01, hz - 0.06), (0.05, 0.05, 0.085)), f"thigh{nm}",
                     "harpy_dirty", leg, group=g + "t")
        for j in range(2):
            rig.add_mesh(R.ellipsoid(f"thb{nm}{j}", (hx * 1.1, BC.y - 0.055, hz - 0.045 - 0.04 * j), (0.036, 0.01, 0.007)),
                         "thbar", "harpy_bar", leg, noline=True, unlit=True, prio=1.3)
        fb = Vector((hx * 1.35, BC.y - 0.05, 0.06))
        kp = Vector((hx * 1.15, BC.y + 0.02, (hz - 0.12 + 0.06) * 0.5 + 0.04))
        rig.add_mesh(R.cone(f"shin{nm}", (hx * 1.1, BC.y - 0.01, hz - 0.12), kp, 0.024 * tk, 0.021 * tk, seg=8, rings=2),
                     f"shin{nm}", "harpy_leg", leg, group=g)
        rig.add_mesh(R.cone(f"tars{nm}", kp, fb + Vector((0, 0, 0.012)), 0.021 * tk, 0.019 * tk, seg=8, rings=2),
                     f"tars{nm}", "harpy_leg", leg, group=g)
        foot = rig.empty(f"foot{nm}", fb, leg)
        for c in (-1, 0, 1):
            dd = Vector((0.05 * c * tk + 0.012 * sx, -0.07 * tk, -0.012))
            rig.add_mesh(R.cone(f"toe{nm}{c}", fb, fb + dd, 0.018 * tk, 0.014 * tk, seg=6, rings=1), f"toe{nm}{c}",
                         "harpy_leg", foot, group=g)
            tb = fb + dd
            ln = 0.075 * tk * (1.4 if night else 1.0)
            rig.add_mesh(R.cone(f"tal{nm}{c}", tb, tb + Vector((0.01 * c, -ln * 0.5, -ln * 0.85)), 0.015 * tk, 0.0015,
                                seg=6, rings=3, bend=(0, -0.025 * tk, 0.004)), f"tal{nm}{c}", "harpy_talon", foot,
                         group=g + "c", prio=1.3)
        tb = fb + Vector((0, 0.045 * tk, -0.004))
        rig.add_mesh(R.cone(f"toeb{nm}", fb, tb, 0.016 * tk, 0.012 * tk, seg=6, rings=1), f"toeb{nm}", "harpy_leg", foot, group=g)
        rig.add_mesh(R.cone(f"talb{nm}", tb, tb + Vector((0, 0.03 * tk, -0.05 * tk)), 0.013 * tk, 0.0015, seg=6, rings=2),
                     f"talb{nm}", "harpy_talon", foot, group=g + "c")
    if stage == 2:   # penas-dardo no quadril
        q0 = Vector((-0.1, BC.y + 0.06, belt_z + 0.02))
        for k in range(3):
            s0 = q0 + Vector((0.015 * (k - 1), 0.0, 0.0))
            s1 = s0 + Vector((-0.03 + 0.02 * (k - 1), 0.05, 0.16))
            rig.add_mesh(R.cone(f"dart{k}", s0, s1, 0.007, 0.007, seg=5, rings=1), "dart", "wood", body, prio=1.5)
            rig.add_mesh(_blade(f"fletch{k}", s1 - (s1 - s0) * 0.3, (s1 - s0), 0.07, 0.04, (1, 0, 0)), f"fletch{k}",
                         "harpy_dirty", body, prio=1.6)
    # ---- bracos com maos em garra para a frente (nao abertos em T)
    sz = BC.z + BR[2] * 0.62
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((BR[0] * 1.02 * sx, BC.y, sz))
        arm = rig.empty(f"arm{nm}", sp, body)
        el = sp + Vector((0.06 * sx, 0.02, -0.12))
        wr = el + Vector((-0.01 * sx, -0.13, 0.02))
        rig.add_mesh(R.ellipsoid(f"pad{nm}", sp + Vector((0.01 * sx, 0, 0.01)), (0.055, 0.05, 0.045)), f"pad{nm}", "harpy_slate",
                     arm, group=f"arm{nm}p")
        rig.add_mesh(R.cone(f"uarm{nm}", sp, el, 0.026, 0.022, seg=8, rings=2), f"uarm{nm}", "harpy_skin", arm, group=f"arm{nm}")
        rig.add_mesh(R.cone(f"farm{nm}", el, wr, 0.022, 0.02, seg=8, rings=2), f"farm{nm}", "harpy_skin", arm, group=f"arm{nm}")
        rig.add_mesh(R.ellipsoid(f"elb{nm}", el, (0.023, 0.023, 0.023)), f"elb{nm}", "harpy_skin", arm, group=f"arm{nm}")
        rig.add_mesh(R.cone(f"brac{nm}", el + (wr - el) * 0.25, el + (wr - el) * 0.85, 0.03, 0.027, seg=8, rings=2),
                     f"brac{nm}", "tunic" if not boss else "harpy_bone", arm, group=f"arm{nm}b")
        hand = wr + Vector((0, -0.02, -0.005))
        rig.add_mesh(R.ellipsoid(f"hand{nm}", hand, (0.03, 0.028, 0.026)), f"hand{nm}", "harpy_skin", arm, group=f"arm{nm}")
        for c in (-1, 0, 1):
            b = hand + Vector((0.016 * c, -0.02, -0.004))
            rig.add_mesh(R.cone(f"nail{nm}{c}", b, b + Vector((0.01 * c, -0.035, -0.03)), 0.009, 0.0015, seg=5, rings=2,
                                bend=(0, -0.008, 0.004)), f"nail{nm}", "harpy_talon", arm, group=f"arm{nm}c", prio=1.6)
    # ---- asas grandes nas costas
    wk = D["wing"]
    for sx, nm in ((1, "L"), (-1, "R")):
        _wing(rig, nm, sx, Vector((0.05 * sx, BC.y + BR[1] * 0.7, BC.z + BR[2] * 0.55)), wk, body, stage)
    # ---- cabeca: menos bebe, olhos estreitos de rapina, sobrancelha baixa, boca de grito, cabelo de penas, coroa
    neck_z = nz + 0.02
    rig.add_mesh(R.cone("neck", (0, BC.y, nz - 0.03), (0, BC.y - 0.01, neck_z + 0.04), 0.035, 0.033, seg=10, rings=1),
                 "neck", "harpy_skin", body, group="neck")
    HC = Vector((0, BC.y - 0.03, neck_z + HR[2] * 0.95))
    head = rig.empty("head", (0, BC.y - 0.01, neck_z), body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "harpy_skin", head, group="head")
    rig.add_mesh(R.ellipsoid("jawl", HC + Vector((0, -HR[1] * 0.35, -HR[2] * 0.45)), (HR[0] * 0.62, HR[1] * 0.6, HR[2] * 0.55)),
                 "jawl", "harpy_skin", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.075 * sx, HC.z - 0.005
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.008, ez))
        rz = 0.05 if stage == 1 else 0.046
        _eye(rig, nm, ep, head, rz * 1.55, rz, -0.4 * sx, night, boss)
        S.brow(rig, nm, ep + Vector((0, -0.005, -0.012)), head, 0.75, 0.11, mat="harpy_brow" if not night else "brow_wn",
               thick=1.25, width=1.1, lift=-0.03, prio=3.2)
        rig.add_mesh(R.ellipsoid(f"shade{nm}", ep + Vector((0, 0.004, rz * 0.9)), (rz * 1.8, 0.02, rz * 0.55), rot=(0.25, 0, -0.4 * sx)),
                     f"shade{nm}", "harpy_shade", head, noline=True, unlit=True, prio=1.4)
    if stage >= 2:
        cp = Vector((0.11, S.ysurf(HC, HR, 0.11, HC.z - 0.07) - 0.004, HC.z - 0.07))
        rig.add_mesh(R.cone("scar", cp + Vector((-0.012, 0, 0.03)), cp + Vector((0.014, -0.004, -0.03)), 0.005, 0.004, seg=5,
                            rings=1), "scar", "harpy_scar", head, noline=True, unlit=True, prio=2.6)
    MOUTH = HC + Vector((0, -HR[1] * 0.92, -0.105))
    jaw = rig.empty("jaw", MOUTH, head)
    rig.add_mesh(R.ellipsoid("mouth", MOUTH, (0.032, 0.016, 0.016)), "mouth", "mouth_in", jaw, noline=True, unlit=True, prio=2.6)
    for sx in (1, -1):
        rig.add_mesh(R.cone(f"fang{sx}", MOUTH + Vector((0.017 * sx, -0.014, 0.012)), MOUTH + Vector((0.016 * sx, -0.018, -0.012)),
                            0.007, 0.001, seg=5, rings=1), "fang", "harpy_bone" if not night else "fang_n", jaw, noline=True,
                     prio=3.4)
    # nariz pequeno (perfil legivel de lado)
    np_ = Vector((0, S.ysurf(HC, HR, 0, HC.z - 0.055) + 0.004, HC.z - 0.055))
    rig.add_mesh(R.cone("nose", np_ + Vector((0, 0.012, 0.012)), np_ + Vector((0, -0.022, -0.008)), 0.016, 0.004, seg=6, rings=2),
                 "nose", "harpy_skin", head, group="nose")
    hairp = rig.empty("hair", HC, head)

    def edge(ph):
        fr = S.front_off(ph) < 0.95
        return S.bob(ph, 0.95, 1.45, open_=0.85, ramp=0.6) + S.zigzag(ph + 0.1, 18, 0.1 if fr else 0.18)
    # capa de cabelo so no alto (nada de cupula): o resto sao mechas
    rig.add_mesh(S.cap("hair", HC, HR, 0.0, edge, lift=1.03, nv=7), "hair", "harpy_hair", hairp, group="hair")
    mane = rig.empty("mane", HC + Vector((0, 0.1, -0.03)), head)
    hl = D["hair"]
    # 1a fileira: mechas do alto da cabeca penteadas para tras (cobrem a nuca com fios, nao com bola)
    for j in range(7):
        a = -1.2 + 2.4 * j / 6
        top = HC + Vector((math.sin(a) * HR[0] * 0.75, math.cos(a) * HR[1] * 0.35, HR[2] * 0.8))
        dd = Vector((math.sin(a) * 0.45, 0.85, -0.45)).normalized()
        rig.add_mesh(_blade(f"lockt{j}", top, dd, 0.24, 0.1, (math.sin(a) * 0.5, 0.4, 1), th=0.02), f"lockt{j}",
                     "harpy_hair" if j % 2 == 0 else "harpy_grey", mane, group=f"lockt{j % 2}")
    # 2a fileira: mechas LONGAS da nuca para tras e para baixo (esvoacam)
    for j in range(7):
        a = -1.3 + 2.6 * j / 6
        top = HC + Vector((math.sin(a) * HR[0] * 0.85, math.cos(a) * HR[1] * 0.75 + 0.02, -0.01))
        ln = 0.36 * hl * (1.0 - 0.15 * abs(a)) * (1.0 + 0.12 * ((j * 3) % 3 - 1))
        dd = Vector((math.sin(a) * 0.5, 0.8, -0.5)).normalized()
        mat = "harpy_hair" if j % 2 == 0 else "harpy_slate"
        if night and j % 2:
            mat = "fang_n"
        rig.add_mesh(_blade(f"lock{j}", top, dd, ln, 0.12, (math.sin(a), 0.3, 0.6), th=0.02), f"lock{j}", mat, mane,
                     group=f"lock{j % 2}")
    for sx, nm in ((1, "L"), (-1, "R")):
        a = HC + Vector((0.16 * sx, -0.07, 0.0))
        rig.add_mesh(_blade(f"side{nm}", a, (0.15 * sx, -0.1, -1), 0.17 + 0.03 * (stage > 1), 0.07, (sx, -0.3, 0), th=0.015),
                     f"side{nm}", "harpy_hair", hairp, group="side")
        # "orelhas" de pena na lateral, para tras e para cima
        for q, (dz, ln) in enumerate(((0.04, 0.15), (-0.01, 0.12))):
            eb = HC + Vector((HR[0] * 0.92 * sx, 0.02, dz))
            rig.add_mesh(_blade(f"ear{nm}{q}", eb, (0.5 * sx, 0.7, 0.5 - 0.3 * q), ln, 0.05, (sx, -0.2, 0.2), th=0.012),
                         f"ear{nm}", "harpy_slate" if q == 0 else "harpy_grey", hairp, group=f"ear{nm}{q}")
    crown = rig.empty("crown", HC + Vector((0, 0.0, HR[2] * 0.7)), head)
    cz = HC.z + HR[2] * 0.6
    rig.add_mesh(S.torus("tiara", (0, HC.y, cz), HR[0] * 0.86, 0.016, rot=(-0.3, 0, 0), squash=1.2, yscale=0.92, nu=24),
                 "tiara", "tunic" if not boss else "harpy_bone", crown, group="crown")
    nsp = D["ns"]
    for k in range(nsp):
        a = (k - (nsp - 1) / 2) * (0.5 if nsp <= 3 else (0.36 if nsp == 5 else 0.3))
        b = Vector((math.sin(a) * HR[0] * 0.82, HC.y - math.cos(a) * HR[1] * 0.75, cz - math.cos(a) * 0.04 + 0.02))
        h = {1: 0.07, 2: 0.1}.get(stage, 0.2) * (1.0 - 0.3 * abs(k - (nsp - 1) / 2) / max(1, (nsp - 1) / 2))
        tip = b + Vector((math.sin(a) * 0.05, 0.05, h))
        rig.add_mesh(R.cone(f"spike{k}", b, tip, 0.022 if not boss else 0.03, 0.002, seg=6, rings=3, bend=(0, 0.01, 0.0)),
                     f"spike{k}", "harpy_bone" if not night else "fang_n", crown, group="crown")
        rig.add_mesh(R.cone(f"stip{k}", b + (tip - b) * 0.65, tip, 0.01, 0.001, seg=5, rings=1), "spiket",
                     "harpy_black" if not night else "cold_hot", crown, noline=True, unlit=night, prio=2.0)
        if boss and k % 2:
            fb = b + Vector((0, 0.03, 0))
            rig.add_mesh(_blade(f"cfeat{k}", fb, (math.sin(a) * 0.4, 0.4, 1), h * 1.2, 0.05, (0, -1, 0.3)), f"cfeat{k}",
                         "harpy_black" if not night else "crow_n", crown, group="crownf")
    head.rotation_euler.x += HEAD_TILT
    body.rotation_euler.x += FWD
    # ---- particulas: penas soltas caindo (sempre), penas no dano/morte; chefe: penas girando; atroz: fogos-fatuos
    S.add_motes(rig, "fall", [(0.45 * math.cos(k * 2.1), 0.3 * math.sin(k * 2.1), 0.9 + 0.12 * k) for k in range(3 if not boss else 5)],
                ["harpy_grey", "harpy_dirty"] if not night else ["crow_n", "pale_n"], size=0.026, parent=root)
    S.add_motes(rig, "feather", [(0.0, 0.0, 0.5)] * 6, ["harpy_slate", "harpy_dirty"] if not night else ["crow_n", "pale_n"],
                size=0.03, parent=root)
    S.hide_motes(rig, "feather")
    if boss:
        spots = [(0.62 * math.cos(math.tau * k / 6), 0.45 * math.sin(math.tau * k / 6), 0.55 + 0.25 * (k % 3)) for k in range(6)]
        S.add_motes(rig, "leaf", spots, ["harpy_dirty", "harpy_black"] if not night else ["wisp_v", "wisp_c"], size=0.028,
                    parent=root)
    if night:
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _flap(rig, up, back=0.0):
    """up > 0 = asas para cima; back > 0 = dobra para tras."""
    for nm, sg in (("L", 1), ("R", -1)):
        w = rig.n(f"wing{nm}")
        w.rotation_euler.y += -up * sg
        w.rotation_euler.z += back * sg


def _arms(rig, fwd, out=0.0):
    """fwd > 0 = garras para a frente/cima; out > 0 = abre para os lados."""
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += -fwd
        a.rotation_euler.y += -out * sg


def _hair(rig, a):
    rig.n("mane").rotation_euler.x += a


def _legs(rig, swing, grip=0.0):
    for nm in ("L", "R"):
        rig.n(f"leg{nm}").rotation_euler.x += swing
        rig.n(f"foot{nm}").rotation_euler.x += grip


def _jaw(rig, o):
    rig.n("jaw").scale.z *= 1.0 + 2.2 * o
    rig.n("jaw").scale.x *= 1.0 + 0.3 * o


def _fall(rig, t):
    """Penas soltas caindo devagar, balancando (loop)."""
    for j, (node, ph) in enumerate(rig.motes.get("fall", [])):
        u = (t + ph) % 1.0
        o = rig.n(node)
        base = rig.rest[node][0]
        o.location = base + Vector((0.06 * math.sin(math.tau * (u * 1.5 + ph)), 0.0, -0.7 * u))
        s = max(0.0001, min(1.0, 4 * u) * (1.0 - u) ** 0.3)
        o.scale = (s, s, s)


def _feathers(rig, u, origin, spread=1.0):
    vel = [(0.5 * math.cos(k * 1.9) * spread, 0.4 * math.sin(k * 1.9) * spread, 0.6 + 0.15 * (k % 3)) for k in range(6)]
    S.splash(rig, "feather", u, origin, vel, g=0.9, shrink=0.55, floor=0.15)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, head = rig.root, rig.n("head")
    boss = stage >= 3
    hz = _dims(stage)["hip"] + 0.45
    _fall(rig, t)
    if boss:
        S.motes(rig, "leaf", t, rise=0.08, orbit=1.0)
    if anim == "idle":
        c = math.cos(math.tau * t)
        _flap(rig, 0.6 * c - 0.05, 0.08 * (1 - c))
        root.location.z += 0.045 * -math.sin(math.tau * t + 0.6)
        R.squash(root, 1.0 + 0.03 * math.sin(math.tau * t))
        _legs(rig, 0.12 * math.sin(math.tau * (t - 0.2)), 0.15 + 0.1 * math.sin(math.tau * t))
        _arms(rig, 0.15 + 0.1 * math.sin(math.tau * (t - 0.15)), 0.05)
        _hair(rig, 0.15 * math.sin(math.tau * (t - 0.25)))
        rig.n("skirt").rotation_euler.x += 0.06 * math.sin(math.tau * (t - 0.3))
        head.rotation_euler.z = [0.0, 0.0, 0.22, 0.22, 0.05, -0.18, -0.18, 0.0][i]
        head.rotation_euler.y = [0.0, 0.0, 0.12, 0.12, 0.0, -0.1, -0.1, 0.0][i]
        _jaw(rig, [0.1, 0.1, 0.2, 0.2, 0.1, 0.25, 0.25, 0.1][i])
        if i == n - 2:
            S.blink(rig, 0.8)
    elif anim == "walk":
        c = math.cos(math.tau * t)
        R.tilt(root, 0.16, 0.0)
        head.rotation_euler.x += -0.14
        _flap(rig, 0.65 * c - 0.05, 0.15 - 0.1 * c)
        root.location.z += 0.04 * -math.sin(math.tau * t + 0.6)
        _legs(rig, 0.45 + 0.08 * math.sin(math.tau * t), 0.3)
        _arms(rig, 0.3, 0.1)
        rig.n("skirt").rotation_euler.x += 0.2
        rig.n("tail").rotation_euler.x += -0.1 + 0.08 * math.sin(math.tau * (t - 0.3))
        _hair(rig, 0.35 + 0.1 * math.sin(math.tau * (t - 0.25)))
        _jaw(rig, 0.15)
    elif anim == "attack":
        _attack_dive(rig, i, stage)
    elif anim == "hit":
        R.squash(root, [0.82, 1.1, 0.95, 1.02][i])
        if i == 0:
            R.tilt(root, -0.18, 0.12); S.blink(rig, 0.85); _jaw(rig, 1.0)
            _flap(rig, 0.9, -0.1); _arms(rig, -0.3, 0.4)
            head.rotation_euler.x += 0.25
        elif i == 1:
            R.tilt(root, 0.05, -0.1); S.blink(rig, 0.5); _jaw(rig, 0.6); _flap(rig, 0.4); _arms(rig, 0.1, 0.2)
        _hair(rig, [-0.35, 0.3, 0.05, 0.0][i])
        _legs(rig, [-0.3, 0.2, 0.0, 0.0][i])
        _feathers(rig, [0.15, 0.4, 0.65, 0.9][i], Vector((0, -0.05, hz)))
    elif anim == "death":
        _death(rig, i, stage)


def _attack_dive(rig, i, stage):
    """Sobe batendo as asas e GRITA (boca aberta), mergulha inclinada cravando as garras dos pes; maos em garra abertas."""
    root, head = rig.root, rig.n("head")
    root.location.z += [0.07, 0.12, 0.06, -0.02, -0.03, 0.0, 0.02, 0.0][i] * (1.4 if stage >= 3 else 1.0)
    R.tilt(root, [-0.15, -0.22, 0.25, 0.45, 0.4, 0.22, 0.06, 0.0][i], 0.0)
    _flap(rig, [1.0, 1.15, 0.2, -0.4, -0.45, 0.1, 0.4, 0.1][i], [0.0, 0.05, 0.45, 0.6, 0.55, 0.25, 0.1, 0.05][i])
    _legs(rig, [0.35, 0.5, -0.45, -1.05, -1.0, -0.5, -0.1, 0.0][i], [0.4, 0.5, -0.35, -0.45, 0.55, 0.3, 0.1, 0.0][i])
    _arms(rig, [0.2, 0.5, 0.7, 0.4, 0.3, 0.2, 0.1, 0.0][i], [0.5, 0.7, 0.3, 0.1, 0.1, 0.1, 0.05, 0.0][i])
    _jaw(rig, [0.4, 1.0, 1.0, 0.8, 0.5, 0.3, 0.15, 0.1][i])
    _hair(rig, [-0.1, -0.25, 0.35, 0.5, 0.45, 0.25, 0.1, 0.0][i])
    head.rotation_euler.x += [0.15, 0.22, -0.12, -0.22, -0.2, -0.1, 0.0, 0.0][i]
    rig.n("skirt").rotation_euler.x += [-0.1, -0.15, 0.2, 0.3, 0.25, 0.1, 0.0, 0.0][i]


def _death(rig, i, stage):
    """Perde o voo, tomba de lado no chao e fica caida com uma asa aberta e olhos fechados."""
    root = rig.root
    hz = _dims(stage)["hip"] + 0.45
    R.squash(root, [0.84, 1.08, 1.0, 0.95, 0.9, 1.02, 0.98, 1.0][i])
    roll = [0.0, 0.15, 0.4, 0.85, 1.2, 1.3, 1.28, 1.28][i]
    root.rotation_euler.y += roll
    # cai NO LUGAR: gira em torno do meio do corpo (zc) e desce ate o chao -> centrada no quadro em todas as direcoes
    zc = _dims(stage)["hip"] + 0.1
    u = roll / 1.28
    root.location.x += -zc * math.sin(roll) + 0.05 * u + [0, 0, -0.01, -0.03, -0.015, 0, 0, 0][i]
    root.location.z += (zc + (0.14 - zc) * u) - zc * math.cos(roll)
    _flap(rig, [0.6, 0.5, 0.2, -0.5, -0.7, -0.75, -0.8, -0.8][i], [0.0, 0.2, 0.5, 1.0, 1.0, 1.05, 1.1, 1.1][i])
    _legs(rig, [-0.3, -0.5, -0.2, 0.4, 0.8, 0.9, 0.9, 0.9][i], [0.0, 0.2, 0.4, 0.6, 0.7, 0.7, 0.7, 0.7][i])
    _arms(rig, [0.4, 0.2, -0.1, -0.2, -0.3, -0.3, -0.3, -0.3][i], [0.6, 0.4, 0.3, 0.2, 0.2, 0.2, 0.2, 0.2][i])
    S.blink(rig, 0.85 if i == 0 else (0.5 if i < 3 else 1.0))
    _jaw(rig, [1.0, 0.7, 0.6, 0.4, 0.3, 0.2, 0.2, 0.2][i])
    _hair(rig, [-0.3, 0.1, 0.3, 0.4, 0.4, 0.4, 0.4, 0.4][i])
    _feathers(rig, [0.1, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 0][i], Vector((0, -0.05, hz)), spread=0.8)
