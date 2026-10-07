"""Pecas e poses compartilhadas da fauna peconhenta feita no Blender (docs/arte-monstros-blender.md):
  - olhos chibi (mesmo desenho do Tatu-Pedra: olho escuro grande, iris, 2 brilhos, sobrancelha brava);
  - aranha: cefalotorax (a "cabeca" com o rosto), abdomen com padrao em placas, quelíceras com presas,
    pedipalpos e 8 patas articuladas (coxa + canela, pivo no quadril e no joelho), andar em tetrapode.
Usado por wandering_spider.py (aranha-armadeira) e brown_recluse.py (aranha-marrom).
Modelo proprio por script (sem malha de terceiros): as anatomias de aranha/lagarta nao existem nos packs CC0
(Quaternius) ja extraidos; a rotina de olhos/sobrancelha/bochecha segue a do stone_armadillo.py."""
import math
from mathutils import Vector, Quaternion
import mon_rig as R

Z = Vector((0, 0, 1))


def align(normal):
    return Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_euler()


def on_ell(center, radii, psi, om, lift=1.0):
    """Ponto e normal num elipsoide (psi 0 = traseira +Y .. pi = frente -Y; om pi/2 = topo, om < pi/2 = +X)."""
    d = R.shell_dir(psi, om)
    p = Vector(center) + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * lift
    n = Vector((d.x / radii[0], d.y / radii[1], d.z / radii[2])).normalized()
    return p, n


def chibi_eye(rig, nm, ep, piv, size, yaw, stage, iris="iris", glow=False, night=False):
    """Olho grande (escuro), iris embaixo, brilho grande + pequeno. night: olho de brasa da forma atroz."""
    eye = rig.empty(f"eye{nm}", ep, piv)
    rx, rz = size
    rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (rx, rx * 0.36, rz), rot=(0.35, 0, yaw)), f"eye{nm}", "eye", eye,
                 noline=True, unlit=True, prio=1.8)
    if night:
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0, -0.3 * rx, -0.25 * rz)), (rx * 0.78, rx * 0.25, rz * 0.6),
                                 rot=(0.35, 0, yaw)), f"iris{nm}", "eye_ember", eye, noline=True, unlit=True, prio=1.6)
        rig.add_mesh(R.ellipsoid(f"core{nm}", ep + Vector((0, -0.48 * rx, -0.28 * rz)), (rx * 0.36, rx * 0.2, rz * 0.32),
                                 rot=(0.35, 0, yaw)), f"core{nm}", "ember_core", eye, noline=True, unlit=True, prio=3.5)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.3 * rx, -0.55 * rx, 0.25 * rz)), (rx * 0.25, rx * 0.13, rx * 0.25)),
                     f"hl{nm}", "white", eye, noline=True, unlit=True, prio=7.0)
        return eye
    rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0, -0.3 * rx, -0.3 * rz)), (rx * 0.7, rx * 0.24, rz * 0.48),
                             rot=(0.35, 0, yaw)), f"iris{nm}", "eye_glow" if glow else iris, eye, noline=True, unlit=True,
                 prio=1.5)
    rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.3 * rx, -0.55 * rx, 0.3 * rz)), (rx * 0.38, rx * 0.2, rx * 0.38)),
                 f"hl{nm}", "white", eye, noline=True, unlit=True, prio=7.0)
    rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.32 * rx, -0.55 * rx, -0.35 * rz)), (rx * 0.18, rx * 0.11, rx * 0.18)),
                 f"hl2{nm}", "white", eye, noline=True, unlit=True, prio=3.0)
    return eye


def blink(rig, amt, names=("L", "R")):
    for nm in names:
        e = rig.n(f"eye{nm}")
        e.scale.z *= max(0.12, 1.0 - amt)


def show(rig, name, on):
    o = rig.n(name)
    o.scale = rig.rest[name][2] if on else (0.0001, 0.0001, 0.0001)


# ------------------------------------------------------------------ aranha
CT_C = Vector((0, -0.10, 0.30))      # cefalotorax (cabeca + rosto)
LEG_PHI = (-60.0, -24.0, 12.0, 46.0)  # graus a partir do lado, + para tras


def spider(cfg, stage):
    """cfg: id, scale{st}, mats{body, dark, pale, fang, leg, leg_dark, abd}, ct_r, ab_c, ab_r, leg_len[4], leg_w,
    pattern(rig, stage, ct_c, ct_r, ab_c, ab_r) e extras(rig, stage) opcionais."""
    R.reset()
    R.CUR["reach"] = (0.55, 0.7, 0.75)
    rig = R.Rig(cfg["id"])
    rig.turn.scale = (cfg["scale"][stage],) * 3
    root = rig.root
    M = cfg["mats"]
    ct_r = cfg["ct_r"]
    ab_c, ab_r = Vector(cfg["ab_c"]), cfg["ab_r"]
    # abdomen (pivo no pediculo: balanca/respira atrasado)
    abd = rig.empty("abd", Vector((0, CT_C.y + ct_r[1] * 0.9, 0.3)), root)
    rig.add_mesh(R.ellipsoid("abd", ab_c, ab_r), "abd", M["abd"], abd, group="abd")
    rig.add_mesh(R.ellipsoid("pedicel", Vector((0, CT_C.y + ct_r[1] * 0.95, 0.28)), (0.07, 0.07, 0.06)), "pedicel",
                 M["dark"], abd)
    # fiandeiras
    sp = ab_c + Vector((0, ab_r[1] * 0.97, -ab_r[2] * 0.25))
    rig.add_mesh(R.cone("spinneret", sp, sp + Vector((0, 0.06, -0.02)), 0.045, 0.012, seg=6, rings=1), "spinneret",
                 M["dark"], abd)
    # cefalotorax = cabeca chibi (levantado na frente para o rosto ler de cima)
    head = rig.empty("head", Vector((0, CT_C.y + ct_r[1] * 0.6, 0.26)), root)
    rig.add_mesh(R.ellipsoid("ct", CT_C, ct_r), "ct", M["body"], head, group="ct")
    # olhos: par grande na frente + olhinhos (aranha tem 8/6)
    night = stage == 4
    for sx, nm in ((1, "L"), (-1, "R")):
        p, n = on_ell(CT_C, ct_r, cfg.get("eye_psi", 2.3), math.pi / 2 - cfg.get("eye_om", 0.44) * sx, 0.9)
        chibi_eye(rig, nm, p, head, (cfg.get("eye", 0.085), cfg.get("eye", 0.085) * 1.25), -0.5 * sx, stage,
                  glow=stage == 3, night=night)
        for j, (ps, om, r) in enumerate(cfg.get("small_eyes", ((2.0, 0.2, 0.026), (2.25, 0.95, 0.024)))):
            q, qn = on_ell(CT_C, ct_r, ps, math.pi / 2 - om * sx, 1.0)
            rig.add_mesh(R.ellipsoid(f"se{nm}{j}", q, (r, r, r * 0.7), rot=align(qn), seg=10, rings=6), "seye",
                         "eye_ember" if night else "eye", head, noline=True, unlit=True, prio=2.5)
        # sobrancelha brava (ponta de dentro baixa)
        ep_ = cfg.get("eye_psi", 2.3)
        b0, _ = on_ell(CT_C, ct_r, ep_ - 0.36, math.pi / 2 - 0.14 * sx, 1.03)
        b1, _ = on_ell(CT_C, ct_r, ep_ - 0.28, math.pi / 2 - 0.8 * sx, 1.03)
        b0.z -= 0.02 + 0.008 * min(stage, 3)
        w = 0.02 if not night else 0.03
        rig.add_mesh(R.cone(f"brow{nm}", b0, b1, w, w * 0.8, seg=8, rings=1), f"brow{nm}", "brow", head,
                     noline=True, unlit=True, prio=2.2)
        if stage <= 2:
            c, cn = on_ell(CT_C, ct_r, 2.62, math.pi / 2 - 0.95 * sx, 1.01)
            rig.add_mesh(R.ellipsoid(f"cheek{nm}", c, (0.045, 0.03, 0.012), rot=align(cn), seg=10, rings=6),
                         f"cheek{nm}", "blush", head, noline=True, unlit=True, prio=1.2)
        # quelicera (bochechona) com presa
        cc = Vector((0.065 * sx, CT_C.y - ct_r[1] * 0.92, CT_C.z - ct_r[2] * 0.55))
        chel = rig.empty(f"chel{nm}", cc + Vector((0, 0.03, 0.05)), head)
        rig.add_mesh(R.ellipsoid(f"chel{nm}", cc, (0.06, 0.055, 0.075), rot=(0.3, 0, 0)), f"chel{nm}", M["fang"], chel)
        fb = cc + Vector((0.01 * sx, -0.025, -0.06))
        fl = cfg.get("fang_len", 0.07) * (1.35 if stage == 4 else 1.0)
        rig.add_mesh(R.cone(f"fang{nm}", fb, fb + Vector((-0.03 * sx, -0.015, -fl)), 0.022, 0.004, seg=6, rings=2,
                            bend=(-0.012 * sx, -0.01, 0)), f"fang{nm}", "claw", chel, noline=True, prio=2.0)
        # pedipalpo (bracinho na frente)
        pb = Vector((0.13 * sx, CT_C.y - ct_r[1] * 0.75, CT_C.z - 0.06))
        palp = rig.empty(f"palp{nm}", pb, head)
        pm = pb + Vector((0.05 * sx, -0.09, 0.05))
        pe = pm + Vector((0.01 * sx, -0.06, -0.15))
        rig.add_mesh(R.cone(f"palp{nm}", pb, pm, 0.03, 0.026, seg=6, rings=1), f"palp{nm}", M["leg"], palp,
                     group=f"palp{nm}")
        rig.add_mesh(R.cone(f"palp2{nm}", pm, pe, 0.026, 0.03, seg=6, rings=1), f"palp{nm}", M["leg"], palp,
                     group=f"palp{nm}")
        rig.add_mesh(R.ellipsoid(f"palpk{nm}", pe, (0.034, 0.034, 0.03)), f"palpk{nm}", M["leg_dark"], palp,
                     group=f"palp{nm}")
    head.rotation_euler.x += cfg.get("head_tilt", -0.22)
    # patas: 4 por lado (cfg leg_phi/leg_len), coxa sobe ate o joelho alto e a canela desce ate o chao
    rig.legs = []
    phis = cfg.get("leg_phi", LEG_PHI)
    for sx in (1, -1):
        for k in range(len(phis)):
            add_leg(rig, cfg, stage, sx, k, phis[k], cfg["leg_len"][k], cfg["leg_w"])
    if cfg.get("pattern"):
        cfg["pattern"](rig, stage, abd, head, ab_c, ab_r, ct_r)
    if cfg.get("extras"):
        cfg["extras"](rig, stage, abd, head, ab_c, ab_r, ct_r)
    if stage == 4:
        night_m = cfg.get("night", {})
        for info in rig.part_info[1:]:
            info["mat"] = night_m.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


def add_leg(rig, cfg, stage, sx, k, phi_deg, L, lw, hip=None, parent=None, knee_h=None):
    """Uma pata articulada (pivo no quadril e no joelho). cfg["leg_hook"](rig, stage, nm, hp, kp, hip, knee, foot,
    d, sx, k, lw) acrescenta pecas proprias (laminas, cerdas)."""
    M = cfg["mats"]
    ct_r = cfg["ct_r"]
    ph = math.radians(phi_deg)
    d = Vector((sx * math.cos(ph), math.sin(ph), 0))
    if hip is None:
        hip = CT_C + Vector((d.x * ct_r[0] * 0.75, d.y * ct_r[1] * 0.75, -0.05))
    knee = hip + d * L * 0.4 + Z * (knee_h if knee_h is not None else cfg.get("knee_h", 0.24))
    foot = hip + d * L
    foot.z = 0.025
    nm = f"leg{'L' if sx > 0 else 'R'}{k}"
    hp = rig.empty(nm, hip, parent or rig.root)
    kp = rig.empty(nm + "k", knee, hp)
    g = dict(group=nm)
    mid = hip.lerp(knee, 0.55)
    rig.add_mesh(R.cone(nm + "a", hip, mid, lw, lw * 0.95, seg=7, rings=1), nm, M["leg"], hp, **g)
    rig.add_mesh(R.cone(nm + "b", mid, knee, lw * 0.95, lw * 0.85, seg=7, rings=1), nm + "d",
                 M["leg_band"], hp, **g)
    rig.add_mesh(R.ellipsoid(nm + "j", knee, (lw * 1.05,) * 3, seg=10, rings=6), nm + "j", M["pale"], kp, **g)
    cuts = (0.0, 0.38, 0.55, 0.84, 1.0)
    mats = (M["leg"], M["leg_band"], M["leg"], M["leg_dark"])
    for j in range(4):
        a, b = knee.lerp(foot, cuts[j]), knee.lerp(foot, cuts[j + 1])
        w0 = lw * (0.85 - 0.4 * cuts[j]); w1 = lw * (0.85 - 0.4 * cuts[j + 1])
        rig.add_mesh(R.cone(nm + f"c{j}", a, b, w0, w1, seg=7, rings=1), nm + ("" if j % 2 == 0 else f"t{j}"),
                     mats[j], kp, **g)
    if cfg.get("hairy") and stage >= 2:
        for j, f in enumerate((0.3, 0.7)):
            hb = knee.lerp(foot, f)
            rig.add_mesh(R.cone(nm + f"h{j}", hb, hb + (d * 0.4 + Z).normalized() * 0.07, lw * 0.45, 0.004,
                                seg=5, rings=1), nm + "h", M["leg_dark"], kp, **g)
    if cfg.get("leg_hook"):
        cfg["leg_hook"](rig, stage, nm, hp, kp, hip, knee, foot, d, sx, k, lw)
    rig.legs.append((nm, nm + "k", sx, k, d))
    return nm


def leg_rot(rig, idx, swing=0.0, lift=0.0, curl=0.0, add=True):
    """swing > 0 = para a frente; lift > 0 = sobe; curl > 0 = dobra a canela para dentro."""
    nm, kn, sx, k, d = rig.legs[idx]
    perp = Vector((-d.y, d.x, 0))
    q = Quaternion(Z, -sx * swing) @ Quaternion(perp, -lift)
    rig.n(nm).rotation_euler = q.to_euler()
    if curl:
        rig.n(kn).rotation_euler = Quaternion(perp, curl).to_euler()


def walk_legs(rig, t, amp=0.32, lift=0.3, raise_front=0.0):
    for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
        grp = (k + (0 if sx > 0 else 1)) % 2
        ph = t + 0.5 * grp
        a = math.sin(math.tau * ph)
        up = max(0.0, math.cos(math.tau * ph))
        lf = lift * up + (raise_front if k == 0 else 0.0)
        leg_rot(rig, idx, swing=amp * a, lift=lf, curl=-0.25 * up)


def spider_pose(rig, anim, i, n, stage, style):
    """style: 'rear' (armadeira: patas da frente erguidas) ou 'pounce' (aranha-marrom: bote rente ao chao)."""
    t = i / n
    root, head, abd = rig.root, rig.n("head"), rig.n("abd")
    back_y = 0.35
    rear = style == "rear"
    s = math.sin(math.tau * t)

    def palps(a):
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"palp{nm}").rotation_euler.x = a * sg

    def chel(open_):
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"chel{nm}").rotation_euler.y = 0.45 * open_ * sg
            rig.n(f"chel{nm}").rotation_euler.x = -0.35 * open_

    if anim == "idle":
        R.squash(abd, 1.0 + 0.06 * s, anchored=False)
        abd.rotation_euler.x = 0.04 * math.sin(math.tau * (t - 0.15))
        root.location.z += 0.008 * (1 + s)
        palps(0.25 * math.sin(math.tau * 2 * t))
        if rear:
            # marca da armadeira: patas da frente erguidas, balancando (ameaca)
            R.tilt(root, -0.10, back_y)
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k == 0:
                    leg_rot(rig, idx, swing=0.1 + 0.08 * math.sin(math.tau * t + (0 if sx > 0 else 1.2)),
                            lift=0.62 + 0.1 * math.sin(math.tau * t + (0 if sx > 0 else 1.2)), curl=-0.2)
                elif k == 1:
                    leg_rot(rig, idx, lift=0.12 + 0.04 * s)
        else:
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k == 0:
                    leg_rot(rig, idx, swing=0.06 * math.sin(math.tau * t + (0 if sx > 0 else 2)),
                            lift=0.08 * max(0, math.sin(math.tau * t + (0 if sx > 0 else 2))))
        if i == n - 2:
            blink(rig, 1.0)
    elif anim == "walk":
        b = abs(math.sin(math.tau * t * 2))
        root.location.z += 0.03 * b
        root.rotation_euler.y = 0.04 * s
        R.squash(abd, 1.0 + 0.05 * math.sin(math.tau * 2 * t + 1), anchored=False)
        abd.rotation_euler.z = 0.06 * math.sin(math.tau * t + 0.8)
        if rear:
            R.tilt(root, -0.06, back_y)
        walk_legs(rig, t, raise_front=0.28 if rear else 0.0)
        palps(0.3 * s)
    elif anim == "attack":
        if rear:
            # 0 agacha, 1-2 empina (patas da frente la em cima, presas abertas), 3 segura, 4 bote, 5 impacto, 6-7 volta
            tl = [0.06, -0.28, -0.40, -0.40, 0.14, 0.10, -0.06, -0.08][i]
            fl = [0.1, 1.05, 1.3, 1.22, -0.05, 0.0, 0.5, 0.55][i]
            fs = [0.0, -0.25, -0.35, -0.3, 0.45, 0.4, 0.05, 0.08][i]
            sq = [0.88, 1.06, 1.1, 1.08, 0.9, 0.86, 1.02, 1.0][i]
            R.tilt(root, tl, back_y)
            R.squash(root, sq)
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k == 0:
                    leg_rot(rig, idx, swing=fs + (0.06 * sx if i == 3 else 0), lift=fl, curl=-0.3 if 1 <= i <= 3 else 0.1)
                elif k == 1:
                    leg_rot(rig, idx, swing=fs * 0.5, lift=fl * 0.55)
                elif k == 3:
                    leg_rot(rig, idx, swing=-0.1 if 1 <= i <= 3 else 0.0)
            chel([0.0, 0.6, 1.0, 1.0, 0.2, 0.0, 0.2, 0.0][i])
            palps([0.0, 0.5, 0.7, 0.6, -0.3, -0.2, 0.1, 0.0][i])
            if i == 3:
                root.location.x += 0.015
        else:
            # 0-1 agacha, 2 salta (estica), 3 morde ao cair, 4 crava, 5 solta, 6-7 volta
            hop = [0.0, 0.0, 0.14, 0.04, 0.0, 0.0, 0.0, 0.0][i]
            tl = [0.08, 0.12, -0.22, 0.14, 0.18, 0.08, 0.0, 0.0][i]
            sq = [0.9, 0.82, 1.15, 0.92, 0.86, 0.95, 1.02, 1.0][i]
            fl = [0.0, 0.1, 0.7, 0.2, -0.05, 0.0, 0.1, 0.0][i]
            root.location.z += hop
            R.tilt(root, tl, back_y)
            R.squash(root, sq)
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k <= 1:
                    leg_rot(rig, idx, swing=[0, 0, 0.35, 0.4, 0.3, 0.1, 0, 0][i] * (1 if k == 0 else 0.5),
                            lift=fl * (1 if k == 0 else 0.5))
                elif i in (2, 3):
                    leg_rot(rig, idx, swing=-0.25, lift=0.15 if i == 2 else 0.0)
            chel([0.0, 0.3, 1.0, 1.0, 0.1, 0.4, 0.0, 0.0][i])
            palps([0.2, 0.4, 0.6, -0.3, -0.3, 0.0, 0.1, 0.0][i])
    elif anim == "hit":
        sq = [0.84, 1.1, 0.96, 1.0][i]
        R.squash(root, sq)
        if i == 0:
            R.tilt(root, -0.12, back_y); blink(rig, 0.85)
            for idx in range(8):
                leg_rot(rig, idx, lift=0.25, curl=0.35)
        elif i == 1:
            R.tilt(root, 0.06, -0.3); blink(rig, 0.6)
            for idx in range(8):
                leg_rot(rig, idx, lift=-0.05, curl=-0.1)
        if rear and i >= 2:
            R.tilt(root, -0.06, back_y)
    elif anim == "death":
        # tranco, pulinho, vira de barriga para cima, quica, patas se encolhem (aranha morta), fica
        spin = [0, 0.4, 1.7, math.pi, math.pi, math.pi, math.pi, math.pi][i]
        hop = [0, 0.12, 0.16, 0.0, 0.04, 0.0, 0.0, 0.0][i]
        sq = [0.82, 1.12, 1.04, 0.86, 1.04, 0.98, 1.0, 1.0][i]
        R.squash(root, sq)
        blink(rig, 0.9 if i == 0 else 1.0)
        cz = 0.28
        root.rotation_euler.y = spin
        root.location.x += -cz * math.sin(spin)
        root.location.z += cz * (1 - math.cos(spin)) * 0.75 + hop
        curl = [0.0, 0.3, 0.5, 0.6, 0.9, 1.15, 1.25, 1.3][i]
        lift = [0.0, 0.2, 0.3, 0.2, 0.0, -0.15, -0.25, -0.3][i]
        for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
            tw = 0.12 * math.sin(i * 2.3 + idx) if 4 <= i <= 6 else 0.0
            leg_rot(rig, idx, swing=tw, lift=lift, curl=curl)
        chel(0.5 if i >= 3 else 0.0)
        if i >= 3:
            root.location.z -= 0.1


# ------------------------------------------------------------------ chefes e atrozes (quadro 240)
def add_motes(rig, spots, mats, size=0.03, parent=None):
    """Particulas em loop (brasas, fogos-fatuos, esporos): spots = [(x, y, z)], mats alternados."""
    ep = rig.empty("motes", (0, 0, 0), parent or rig.root)
    rig.motes = []
    for j, p in enumerate(spots):
        p = Vector(p)
        rig.empty(f"mote{j}", p, ep)
        m = mats[j % len(mats)]
        rig.add_mesh(R.ellipsoid(f"mote{j}", p, (size, size, size * 1.35), seg=8, rings=5), f"mote_{m}", m,
                     rig.n(f"mote{j}"), unlit=True, noline=True, prio=4.0)
        rig.motes.append((f"mote{j}", (j * 0.37) % 1.0))


def motes(rig, t, rise=0.5, spread=1.0, fade=1.0, drift=0.05):
    for nm, ph in getattr(rig, "motes", []):
        u = (t + ph) % 1.0
        o = rig.n(nm)
        o.location = rig.rest[nm][0] + Vector((drift * spread * math.sin(math.tau * u + ph * 7),
                                               0.02 * spread, rise * u))
        s = max(0.0001, (1 - u) ** 0.7 * fade)
        o.scale = (s, s, s)


def spiderling(rig, nm, p, parent, mat_body, mat_leg, night=False):
    """Filhote no dorso da mae: bolinha com olhos grandes e 6 perninhas."""
    piv = rig.empty(nm, p, parent)
    p = Vector(p)
    rig.add_mesh(R.ellipsoid(nm + "b", p + Vector((0, 0.04, 0.0)), (0.075, 0.08, 0.06), seg=12, rings=8), "sl_abd",
                 mat_body, piv)
    rig.add_mesh(R.ellipsoid(nm + "h", p + Vector((0, -0.05, 0.02)), (0.062, 0.055, 0.055), seg=12, rings=8), "sl_head",
                 mat_body, piv)
    for sx in (1, -1):
        e = p + Vector((0.026 * sx, -0.1, 0.04))
        rig.add_mesh(R.ellipsoid(nm + f"e{sx}", e, (0.022, 0.012, 0.027), seg=8, rings=6), "sl_eye",
                     "eye_ember" if night else "eye", piv, noline=True, unlit=True, prio=3.0)
        if not night:
            rig.add_mesh(R.ellipsoid(nm + f"w{sx}", e + Vector((-0.007, -0.012, 0.01)), (0.009, 0.006, 0.009), seg=6,
                                     rings=4), "sl_hl", "white", piv, noline=True, unlit=True, prio=6.0)
        for k, a in enumerate((-0.7, 0.0, 0.7)):
            d = Vector((sx * math.cos(a), math.sin(a), 0))
            b = p + d * 0.05
            rig.add_mesh(R.cone(nm + f"l{sx}{k}", b, b + d * 0.09 + Vector((0, 0, -0.05)), 0.013, 0.006, seg=5,
                                rings=1, bend=(0, 0, 0.03)), "sl_leg", mat_leg, piv)
    return nm


def web_cape(rig, nm, ab_c, ab_r, sx, parent, mat, line_mat, z_bot=0.14, out=1.28):
    """Manto de teia pendurado do lado do abdomen ate perto do chao (borda de baixo recortada)."""
    ab_c = Vector(ab_c)

    def top(u):
        psi = 2.3 - 1.9 * u
        p, _ = on_ell(ab_c, ab_r, psi, math.pi / 2 - sx * 0.95, 1.0)
        return p

    def fn(u, v):
        a = top(u)
        zb = z_bot + 0.08 * abs(math.sin(3 * math.pi * u))
        b = Vector((sx * ab_r[0] * out, a.y + 0.05, zb))
        p = a.lerp(b, v)
        p.x += sx * 0.07 * math.sin(math.pi * v)
        return p
    rig.add_mesh(R.surface(nm, fn, 10, 6, ab_c), nm, mat, parent, group=nm)
    for j in range(4):
        u = 0.1 + 0.8 * j / 3
        rig.add_mesh(R.cone(nm + f"t{j}", fn(u, 0.0) + Vector((sx * 0.012, 0, 0)), fn(u, 0.97) + Vector((sx * 0.012, 0, 0)),
                            0.008, 0.008, seg=4, rings=4, bend=(sx * 0.07, 0, 0)), nm + "t", line_mat, parent,
                     noline=True, prio=1.5)
    for j, v in enumerate((0.35, 0.7)):
        pts = [fn(u / 6, v) + Vector((sx * 0.013, 0, 0)) for u in range(7)]
        for k in range(6):
            rig.add_mesh(R.cone(nm + f"r{j}{k}", pts[k], pts[k + 1], 0.007, 0.007, seg=4, rings=1), nm + "t", line_mat,
                         parent, noline=True, prio=1.5)


def boss_spider_pose(rig, anim, i, n, stage, P):
    """Pose dos chefes/atrozes de aranha. P: tilt (empinado), raise (lift das patas k=0,1 paradas), abd (abdomen
    erguido), hover (altura flutuando), attack ('slam' | 'lunge' | 'bow' | 'swoop')."""
    t = i / n
    root, head, abd = rig.root, rig.n("head"), rig.n("abd")
    back_y = 0.4
    s = math.sin(math.tau * t)
    r0, r1 = P.get("raise", (0.0, 0.0))
    hover = P.get("hover", 0.0)

    def palps(a):
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"palp{nm}").rotation_euler.x = a * sg

    def chel(o):
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"chel{nm}").rotation_euler.y = 0.45 * o * sg
            rig.n(f"chel{nm}").rotation_euler.x = -0.35 * o

    def raised(extra0=0.0, extra1=0.0, sway=1.0, swing0=0.15):
        for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
            ph = t + (0 if sx > 0 else 0.35)
            if k == 0 and r0:
                leg_rot(rig, idx, swing=swing0 + 0.1 * sway * math.sin(math.tau * ph),
                        lift=r0 + extra0 + 0.1 * sway * math.sin(math.tau * ph), curl=-0.25)
            elif k == 1 and r1:
                leg_rot(rig, idx, swing=0.05, lift=r1 + extra1 + 0.06 * sway * math.sin(math.tau * ph + 1), curl=-0.15)

    abd.rotation_euler.x = P.get("abd", 0.0)
    if hover:
        root.location.z += hover + 0.04 * math.sin(math.tau * t)
        for idx in range(len(rig.legs)):
            leg_rot(rig, idx, lift=-0.15 + 0.08 * math.sin(math.tau * t + idx), curl=0.35)
    if anim == "idle":
        R.squash(abd, 1.0 + 0.05 * s, anchored=False)
        abd.rotation_euler.x += 0.04 * math.sin(math.tau * (t - 0.15))
        R.tilt(root, P.get("tilt", 0.0) + 0.02 * s, back_y)
        if not hover:
            raised()
        palps(0.25 * math.sin(math.tau * 2 * t))
        chel(0.25 + 0.25 * max(0, math.sin(math.tau * t)))
        if i == n - 2:
            blink(rig, 1.0)
    elif anim == "walk":
        b = abs(math.sin(math.tau * t * 2))
        root.location.z += 0.03 * b
        root.rotation_euler.y = 0.035 * s
        R.tilt(root, P.get("tilt", 0.0) * 0.8, back_y)
        if hover:
            root.location.y += 0.0
            for idx in range(len(rig.legs)):
                leg_rot(rig, idx, swing=0.15 * math.sin(math.tau * t + idx * 0.7), lift=-0.1, curl=0.4)
        else:
            walk_legs(rig, t, amp=0.28, lift=0.28)
            raised(-0.15, -0.1, 0.6)
        R.squash(abd, 1.0 + 0.05 * math.sin(math.tau * 2 * t + 1), anchored=False)
        palps(0.3 * s)
    elif anim == "attack":
        kind = P.get("attack", "slam")
        if kind == "slam":
            # empina mais (patas-lamina la em cima), segura, desce as laminas no chao, volta
            tl = [0.04, -0.12, -0.2, -0.2, 0.14, 0.12, 0.0, 0.0][i]
            e0 = [0.0, 0.35, 0.5, 0.45, -1.2, -1.15, -0.4, 0.0][i]
            R.tilt(root, P.get("tilt", 0.0) + tl, back_y)
            R.squash(root, [0.9, 1.05, 1.08, 1.06, 0.9, 0.86, 1.0, 1.0][i])
            raised(e0, e0 * 0.6, 0.0, swing0=[0.15, 0.0, -0.1, -0.1, 0.3, 0.3, 0.2, 0.15][i])
            chel([0.2, 0.7, 1.0, 1.0, 0.3, 0.1, 0.2, 0.2][i])
        elif kind == "lunge":
            tl = [0.08, 0.12, -0.25, 0.16, 0.2, 0.1, 0.02, 0.0][i]
            R.tilt(root, P.get("tilt", 0.0) + tl, back_y)
            root.location.z += [0, 0, 0.18, 0.05, 0, 0, 0, 0][i]
            R.squash(root, [0.88, 0.8, 1.15, 0.9, 0.85, 0.95, 1.02, 1.0][i])
            raised([0.0, 0.2, 0.6, -0.6, -0.7, -0.4, 0.0, 0.0][i], 0.0, 0.0,
                   swing0=[0.15, 0.1, 0.25, 0.3, 0.3, 0.2, 0.15, 0.15][i])
            chel([0.2, 0.5, 1.0, 1.0, 0.2, 0.5, 0.2, 0.2][i])
            abd.rotation_euler.x += [0.0, 0.1, 0.2, -0.1, -0.15, 0.0, 0.0, 0.0][i]
        elif kind == "bow":
            # toca o violino: a pata-arco serra para la e para ca, o corpo vibra, e no fim da o bote
            tl = [0.0, -0.06, -0.08, -0.06, 0.1, 0.14, 0.04, 0.0][i]
            R.tilt(root, P.get("tilt", 0.0) + tl, back_y)
            R.squash(root, [0.95, 1.03, 0.97, 1.04, 0.9, 0.86, 0.98, 1.0][i])
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k == 0:
                    saw = [0.1, -0.35, 0.3, -0.35, 0.3, 0.1, 0.0, 0.1][i] if sx < 0 else 0.1
                    leg_rot(rig, idx, swing=saw, lift=r0 + (0.1 if i < 4 else -0.3), curl=-0.2)
            chel([0.2, 0.3, 0.3, 0.4, 1.0, 0.8, 0.2, 0.2][i])
        elif kind == "swoop":
            root.location.z += [0.05, 0.15, 0.25, -0.1, -0.15, -0.05, 0.05, 0.0][i]
            R.tilt(root, [0.0, -0.2, -0.3, 0.3, 0.35, 0.15, 0.0, 0.0][i], back_y)
            R.squash(root, [1.0, 1.08, 1.12, 0.88, 0.85, 0.95, 1.0, 1.0][i])
            for idx, (nm, kn, sx, k, d) in enumerate(rig.legs):
                if k <= 1:
                    leg_rot(rig, idx, swing=[0, -0.2, -0.3, 0.5, 0.5, 0.2, 0, 0][i],
                            lift=[0, 0.6, 0.9, -0.4, -0.5, -0.2, 0, 0][i], curl=0.2)
            chel([0.2, 0.6, 1.0, 1.0, 0.2, 0.4, 0.2, 0.2][i])
        if P.get("attack_extra"):
            P["attack_extra"](rig, i)
    elif anim == "hit":
        R.squash(root, [0.86, 1.08, 0.96, 1.0][i])
        R.tilt(root, P.get("tilt", 0.0) + [-0.1, 0.05, 0.0, 0.0][i], back_y)
        if not hover:
            raised([0.3, -0.2, 0.0, 0.0][i], [0.2, -0.1, 0.0, 0.0][i], 0.0)
        if i == 0:
            blink(rig, 0.85)
        elif i == 1:
            blink(rig, 0.6)
    elif anim == "death":
        spin = [0, 0.3, 1.5, math.pi, math.pi, math.pi, math.pi, math.pi][i]
        hop = [0, 0.1, 0.14, 0.0, 0.03, 0.0, 0.0, 0.0][i]
        R.squash(root, [0.84, 1.1, 1.03, 0.88, 1.03, 0.98, 1.0, 1.0][i])
        blink(rig, 0.9 if i == 0 else 1.0)
        if hover:
            root.location.z -= hover * min(1.0, i / 3)
        cz = 0.34
        root.rotation_euler.y = spin
        root.location.x += -cz * math.sin(spin)
        root.location.z += cz * (1 - math.cos(spin)) * 0.75 + hop - (0.12 if i >= 3 else 0)
        curl = [0.0, 0.3, 0.5, 0.6, 0.9, 1.15, 1.25, 1.3][i]
        lift = [0.0, 0.2, 0.3, 0.2, 0.0, -0.15, -0.25, -0.3][i]
        for idx in range(len(rig.legs)):
            tw = 0.12 * math.sin(i * 2.3 + idx) if 4 <= i <= 6 else 0.0
            leg_rot(rig, idx, swing=tw, lift=lift, curl=curl)
        abd.rotation_euler.x = P.get("abd", 0.0) * max(0.0, 1 - i / 3)
        chel(0.5 if i >= 3 else 0.0)
    fade = 1.0 if anim != "death" else max(0.0001, 1 - i / 5)
    motes(rig, t if anim in ("idle", "walk") else 0.12 * i, rise=0.6, spread=2.0 if anim == "attack" else 1.0,
          fade=fade)
