"""Taturana Lonomia (lonomia_caterpillar, lagarta-de-fogo) — fauna peconhenta do Brasil. Modelo proprio por script:
cabecona chibi (olhos grandes, sobrancelha brava, bochecha) na frente de 8 aneis marrom-oliva alternados, com
mancha clara no dorso de cada anel, patinhas e falsas-patas embaixo, e os tufos de cerdas urticantes ramificados
("pinheirinhos": tronco + 3 andares de cones verdes, ponta amarela) no dorso e nos lados de cada anel.
Andar: onda que corre da cauda para a cabeca (cada anel sobe, avanca e assenta). Golpe: empina a frente com as
cerdas eriçadas e chicoteia para baixo. Morte: enrola em "C", tomba de lado e as cerdas murcham.
  s1 Taturana Lonomia (quadro 96)   s2 Taturana Espinhosa (144): pinheirinhos maiores
  s3 Lonomia Matriarca das Urtigas (240, chefe — "Mae-Lagarta"): modelo proprio de chefe, gigante e empinada como
     uma naja (a frente do corpo erguida em arco, cabecona no alto com coroa de 3 pinheirinhos), 9 aneis com uma
     floresta de pinheirinhos em brasa (andares de baixo verdes, de cima em brasa, pontas acesas) e um casulo de seda
     em pe na cauda, com costura acesa. Golpe: recua no alto e desaba a frente no chao, cerdas eriçadas e esporos.
  s4 Taturana Lonomia Atroz (240, "Mariposa do Casulo"): outra silhueta — a mariposa Lonomia saindo do casulo
     rachado: torax peludo, cabecona de olhos de brasa, antenas plumosas (pinheirinhos), 2 pares de asas abertas
     (anil e roxo, faixa escura, ocelos de brasa, veias de luz fria) e dois aneis de fogo frio girando em volta do
     casulo. Golpe: ergue as asas e bate para baixo soltando escamas."""
import math
from mathutils import Vector
import mon_rig as R
import venom_common as V

SCALE = {1: 1.26, 2: 1.86, 3: 1.4, 4: 1.45}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"lo_body": "fur_n", "lo_body2": "obsidian_n", "lo_saddle": "pale_n", "lo_spine": "moss_n",
         "lo_tip": "ember_hot", "lo_head": "skin_n", "lo_leg": "obsidian_n", "brow": "brow_n", "glow": "ember",
         "claw": "fang_n"}
NSEG = 7
SEG_Y0, SEG_DY = -0.22, 0.135
HEAD_C = Vector((0, -0.42, 0.3))
HEAD_R = (0.25, 0.22, 0.24)


def seg_r(k):
    return 0.18 - 0.05 * max(0, k - 4) / 2.0


def scolus(rig, nm, base, d, h, piv, stage, tip_mat):
    """Pinheirinho: tronco + 3 andares de cones (largo embaixo, fino em cima) + ponta."""
    g = dict(group=nm)
    top = base + d * h
    rig.add_mesh(R.cone(nm + "t", base, top, 0.022, 0.01, seg=6, rings=1), nm, "lo_spine", piv, **g)
    for j in range(3):
        a = base + d * h * (0.18 + 0.27 * j)
        b = a + d * h * 0.42
        r0 = h * (0.26 - 0.05 * j)
        rig.add_mesh(R.cone(nm + f"p{j}", a, b, r0, 0.004, seg=7, rings=1), nm, "lo_spine", piv, **g)
    rig.add_mesh(R.ellipsoid(nm + "x", top, (0.02,) * 3, seg=8, rings=5), "tip", tip_mat, piv, noline=True,
                 unlit=stage >= 3, prio=2.5)


def _build_small(stage):
    R.reset()
    R.CUR["reach"] = (0.6, 0.62, 0.22)
    rig = R.Rig("lonomia_caterpillar")
    rig.turn.scale = (SCALE[stage],) * 3
    root = rig.root
    tip_mat = "glow" if stage >= 3 else "lo_tip"
    hs = {1: 0.24, 2: 0.26, 3: 0.27, 4: 0.28}[stage]
    rig.segs = []
    rig.scoli = []
    for k in range(NSEG):
        r = seg_r(k)
        c = Vector((0, SEG_Y0 + SEG_DY * k, r * 0.95))
        sp = rig.empty(f"seg{k}", c, root)
        rig.segs.append(f"seg{k}")
        mat = "lo_body" if k % 2 == 0 else "lo_body2"
        rig.add_mesh(R.ellipsoid(f"seg{k}", c, (r * 1.02, SEG_DY * 0.78, r)), f"seg{k}", mat, sp)
        # mancha clara no dorso
        for sx in (1, -1):
            p, n = V.on_ell(c, (r * 1.02, SEG_DY * 0.78, r), math.pi / 2, math.pi / 2 - 0.42 * sx, 1.0)
            rig.add_mesh(R.ellipsoid(f"sad{k}{sx}", p, (r * 0.17, SEG_DY * 0.24, 0.02), rot=V.align(n), seg=10,
                                     rings=6), "saddle", "lo_saddle", sp, noline=True)
        # falsas-patas
        if k in (0, 1, 3, 4, 5, 6):
            for sx in (1, -1):
                lp = c + Vector((sx * r * 0.62, 0, -r * 0.8))
                rig.add_mesh(R.ellipsoid(f"pl{k}{sx}", lp, (0.04, 0.035, 0.045) if k > 2 else (0.028, 0.025, 0.04),
                                         seg=8, rings=5), "prolegs", "lo_leg", sp)
        # pinheirinhos: par dorsal + par lateral (s2+: mais um par lateral baixo)
        oms = [0.78] + ([0.05] if k % 2 == 0 else [])
        for j, om in enumerate(oms):
            for sx in (1, -1):
                ang = om if sx > 0 else math.pi - om
                bd = Vector((math.cos(ang), 0, math.sin(ang)))
                base = c + Vector((bd.x * r * 0.9, 0, bd.z * r * 0.9))
                d = (bd + Vector((0, 0.2, 0.9 if j == 0 else 0.45))).normalized()
                h = hs * (1.0 if j == 0 else 0.8 if j == 1 else 0.6) * (0.75 if k >= 6 else 1.0)
                if stage >= 3 and j == 0 and k in (1, 3, 5):
                    h *= 1.35
                nm = f"sc{k}_{j}{'a' if sx > 0 else 'b'}"
                scp = rig.empty("p" + nm, base, sp)
                scolus(rig, nm, base, d, h, scp, stage, tip_mat)
                rig.scoli.append("p" + nm)
    # cabecona
    head = rig.empty("head", HEAD_C + Vector((0, 0.1, -0.1)), root)
    rig.add_mesh(R.ellipsoid("head", HEAD_C, HEAD_R), "head", "lo_head", head, group="head")
    # "capuz" do primeiro anel por cima da cabeca (escuro)
    for sx, nm in ((1, "L"), (-1, "R")):
        ep, _ = V.on_ell(HEAD_C, HEAD_R, 2.42, math.pi / 2 - 0.55 * sx, 0.9)
        V.chibi_eye(rig, nm, ep, head, (0.1, 0.125), -0.55 * sx, stage, glow=stage == 3, night=stage == 4)
        b0, _ = V.on_ell(HEAD_C, HEAD_R, 2.02, math.pi / 2 - 0.2 * sx, 1.02)
        b1, _ = V.on_ell(HEAD_C, HEAD_R, 2.12, math.pi / 2 - 0.95 * sx, 1.02)
        b0.z -= 0.03
        w = 0.02 if stage < 4 else 0.028
        rig.add_mesh(R.cone(f"brow{nm}", b0, b1, w, w * 0.8, seg=8, rings=1), f"brow{nm}", "brow", head,
                     noline=True, unlit=True, prio=2.2)
        if stage <= 2:
            cp, cn = V.on_ell(HEAD_C, HEAD_R, 2.85, math.pi / 2 - 0.95 * sx, 1.0)
            rig.add_mesh(R.ellipsoid(f"cheek{nm}", cp, (0.035, 0.025, 0.01), rot=V.align(cn), seg=10, rings=6),
                         f"cheek{nm}", "blush", head, noline=True, unlit=True, prio=1.2)
        # mandibulas
        mb = HEAD_C + Vector((0.05 * sx, -HEAD_R[1] * 0.92, -0.09))
        rig.add_mesh(R.cone(f"mand{nm}", mb, mb + Vector((-0.03 * sx, -0.035, -0.04)), 0.022, 0.005, seg=6, rings=1),
                     f"mand{nm}", "claw", head, noline=True, prio=1.6)
        # anteninhas
        ab = HEAD_C + Vector((0.1 * sx, -HEAD_R[1] * 0.8, -0.02))
        rig.add_mesh(R.cone(f"ant{nm}", ab, ab + Vector((0.04 * sx, -0.05, 0.05)), 0.014, 0.008, seg=5, rings=1),
                     f"ant{nm}", "lo_leg", head)
    if stage >= 3:
        # coroa de pinheirinhos na cabeca
        for j, om in enumerate((-0.45, 0.0, 0.45)):
            base, n = V.on_ell(HEAD_C, HEAD_R, 1.25, math.pi / 2 + om, 0.95)
            d = (n + Vector((0, 0.3, 1.4))).normalized()
            nm = f"crown{j}"
            scp = rig.empty("p" + nm, base, head)
            scolus(rig, nm, base, d, 0.36 if j == 1 else 0.28, scp, stage, tip_mat)
            rig.scoli.append("p" + nm)
    head.rotation_euler.x += -0.32
    if stage == 4:
        ep = rig.empty("embers", (0, 0, 0), root)
        rig.embers = []
        for j in range(7):
            a = j * math.tau / 7
            p = Vector((0.32 * math.cos(a), 0.15 + 0.5 * math.sin(a), 0.35 + 0.06 * (j % 3)))
            rig.empty(f"emb{j}", p, ep)
            rig.add_mesh(R.ellipsoid(f"emb{j}", p, (0.02, 0.02, 0.028), seg=8, rings=5), "emb" if j % 2 else "embc",
                         "ember_core" if j % 2 else "cold_hot", rig.n(f"emb{j}"), unlit=True, noline=True, prio=4.0)
            rig.embers.append((f"emb{j}", j / 7.0))
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


def _bristle(rig, k):
    for nm in rig.scoli:
        rig.n(nm).scale = (k, k, k)


def _curl(rig, curv, side=1.0):
    """Enrola o corpo no plano do chao (C). curv = rad por metro."""
    if abs(curv) < 1e-4:
        return
    Rc = 1.0 / curv
    yc = SEG_Y0 + SEG_DY * 3.0
    for k in range(NSEG):
        y = SEG_Y0 + SEG_DY * k
        th = (y - yc) / Rc
        o = rig.n(f"seg{k}")
        o.location.x += side * Rc * (1 - math.cos(th))
        o.location.y += (yc + Rc * math.sin(th)) - y
        o.rotation_euler.z = -side * th
    y = HEAD_C.y
    th = (y - yc) / Rc
    h = rig.n("head")
    h.location.x += side * Rc * (1 - math.cos(th))
    h.location.y += (yc + Rc * math.sin(th)) - y
    h.rotation_euler.z = -side * th


def _pose_small(rig, anim, i, n, stage):
    t = i / n
    root, head = rig.root, rig.n("head")
    s = math.sin(math.tau * t)
    if anim == "idle":
        # respira (aneis incham em onda lenta), cabeca balanca, cerdas tremem; pisca
        for k in range(NSEG):
            o = rig.n(f"seg{k}")
            w = math.sin(math.tau * (t - k / NSEG))
            o.scale = (1 + 0.04 * w, 1, 1 + 0.05 * w)
        head.rotation_euler.z = 0.08 * s
        head.location.z += 0.01 * math.sin(math.tau * (t - 0.2))
        _bristle(rig, 1.0 + 0.04 * math.sin(math.tau * 2 * t))
        if i == n - 2:
            V.blink(rig, 1.0)
    elif anim == "walk":
        # onda da cauda para a cabeca: o anel que esta na crista sobe e os vizinhos se juntam
        for k in range(NSEG):
            u = t + k / NSEG * 0.85
            w = max(0.0, math.sin(math.tau * u)) ** 1.5
            o = rig.n(f"seg{k}")
            o.location.z += 0.07 * w
            o.location.y += -0.025 * math.cos(math.tau * u)
            o.scale = (1 - 0.06 * w, 1, 1 + 0.08 * w)
        u0 = t - 0.1
        head.location.z += 0.04 * max(0.0, math.sin(math.tau * u0)) ** 1.5
        head.location.y += -0.025 * math.cos(math.tau * u0)
        head.rotation_euler.z = 0.06 * s
        _bristle(rig, 1.0 + 0.03 * math.sin(math.tau * 2 * t))
    elif anim == "attack":
        # 0 recolhe, 1-2 empina a frente com cerdas eriçadas, 3 segura, 4 chicoteia, 5 impacto, 6-7 volta
        rise = [0.0, 0.6, 1.0, 1.0, -0.15, -0.2, 0.3, 0.05][i]
        br = [1.0, 1.2, 1.35, 1.4, 1.3, 1.45, 1.15, 1.0][i]
        pull = [0.04, 0.03, 0.02, 0.02, -0.04, -0.05, 0.0, 0.0][i]
        for k in range(NSEG):
            o = rig.n(f"seg{k}")
            f = max(0.0, 1 - k / 3.0)
            o.location.z += 0.22 * rise * f * f
            o.location.y += pull * (1 - k / NSEG)
            o.rotation_euler.x = -0.5 * rise * f
        head.location.z += 0.3 * rise + (0.0 if rise >= 0 else 0.03)
        head.location.y += pull + 0.03 * rise
        head.rotation_euler.x += -0.35 * rise + (0.25 if i in (4, 5) else 0.0)
        if i in (4, 5):
            R.squash(root, 0.88 if i == 5 else 0.94)
        if i == 0:
            R.squash(root, 0.92)
        _bristle(rig, br)
    elif anim == "hit":
        R.squash(root, [0.84, 1.1, 0.96, 1.0][i])
        _bristle(rig, [0.8, 1.2, 1.05, 1.0][i])
        if i == 0:
            V.blink(rig, 0.85); head.rotation_euler.x += 0.25
        elif i == 1:
            V.blink(rig, 0.6); head.rotation_euler.x += -0.1
    elif anim == "death":
        # tranco, enrola em C, tomba de lado, cerdas murcham
        R.squash(root, [0.82, 1.08, 1.0, 0.95, 1.02, 1.0, 1.0, 1.0][i])
        V.blink(rig, 0.9 if i == 0 else 1.0)
        _curl(rig, [0.0, 0.6, 1.4, 2.2, 2.6, 2.8, 2.9, 2.9][i])
        roll = [0, 0.1, 0.3, 0.7, 1.1, 1.25, 1.3, 1.3][i]
        root.rotation_euler.y = roll
        root.location.x += -0.12 * math.sin(roll)
        _bristle(rig, [1.1, 1.0, 0.95, 0.9, 0.85, 0.8, 0.78, 0.78][i])
    if stage == 4:
        fade = 1.0 if anim != "death" else max(0.0001, 1 - i / 5)
        for nm, ph in rig.embers:
            u = (t + ph) % 1.0
            o = rig.n(nm)
            o.location = rig.rest[nm][0] + Vector((0.03 * math.sin(math.tau * u + ph * 6), 0, 0.3 * u))
            sc = max(0.0001, (1 - u) ** 0.7 * fade)
            o.scale = (sc, sc, sc)


# ------------------------------------------------------------------ chefe (s3): Mae-Lagarta
Q_N = 7
Q_DY = 0.23
Q_Y0 = -0.4
Q_RISE = (1.05, 0.68, 0.34, 0.1)   # altura extra dos aneis da frente (empinada)


def q_r(k):
    return 0.34 - 0.1 * max(0, k - 4) / 2.0


def pine(rig, nm, base, d, h, piv, tiers=4, ember_from=2, tip="glow"):
    """Pinheirinho grande: tronco + andares (os de cima em brasa) + ponta acesa."""
    g = dict(group=nm)
    top = base + d * h
    rig.add_mesh(R.cone(nm + "t", base, top, 0.03, 0.012, seg=6, rings=1), nm, "lo_spine", piv, **g)
    for j in range(tiers):
        a = base + d * h * (0.12 + 0.2 * j)
        b = a + d * h * 0.36
        r0 = h * (0.27 - 0.045 * j)
        m = "lo_ember" if j >= ember_from else "lo_spine"
        rig.add_mesh(R.cone(nm + f"p{j}", a, b, r0, 0.004, seg=8, rings=1), nm + ("e" if j >= ember_from else ""), m,
                     piv, **g)
    rig.add_mesh(R.ellipsoid(nm + "x", top, (0.03,) * 3, seg=8, rings=5), "tip", tip, piv, noline=True, unlit=True,
                 prio=2.5)


def build_queen():
    R.reset()
    R.CUR["reach"] = (0.75, 0.9, 0.35)
    rig = R.Rig("lonomia_caterpillar")
    rig.turn.scale = (SCALE[3],) * 3
    root = rig.root
    rig.segs, rig.scoli, rig.qrise = [], [], []
    for k in range(Q_N):
        r = q_r(k)
        rise = Q_RISE[k] if k < len(Q_RISE) else 0.0
        c = Vector((0, Q_Y0 + Q_DY * k + 0.12 * rise, r * 0.95 + rise))
        sp = rig.empty(f"seg{k}", c, root)
        rig.segs.append(f"seg{k}"); rig.qrise.append(rise)
        rig.add_mesh(R.ellipsoid(f"seg{k}", c, (r * 1.02, Q_DY * 0.8, r), rot=(-1.1 * rise, 0, 0)), f"seg{k}",
                     "lo_body" if k % 2 == 0 else "lo_body2", sp)
        for sx in (1, -1):
            p, n = V.on_ell(c, (r * 1.02, Q_DY * 0.8, r), math.pi / 2, math.pi / 2 - 0.42 * sx, 1.0)
            rig.add_mesh(R.ellipsoid(f"sad{k}{sx}", p, (r * 0.16, Q_DY * 0.24, 0.02), rot=V.align(n), seg=10, rings=6),
                         "saddle", "lo_saddle", sp, noline=True)
            if rise < 0.2:
                lp = c + Vector((sx * r * 0.62, 0, -r * 0.8))
                rig.add_mesh(R.ellipsoid(f"pl{k}{sx}", lp, (0.05, 0.045, 0.055), seg=8, rings=5), "prolegs", "lo_leg", sp)
        oms = [0.8] + ([0.1] if k % 2 == 0 else [])
        for j, om in enumerate(oms):
            for sx in (1, -1):
                ang = om if sx > 0 else math.pi - om
                bd = Vector((math.cos(ang), 0, math.sin(ang)))
                base = c + Vector((bd.x * r * 0.9, 0, bd.z * r * 0.9))
                d = (bd + Vector((0, 0.25, 1.0 if j == 0 else 0.5))).normalized()
                h = (0.5 if j == 0 else 0.34) * (0.8 if k >= 6 else 1.0) * (1.15 if k in (2, 4) else 1.0)
                nm = f"pq{k}_{j}{'a' if sx > 0 else 'b'}"
                scp = rig.empty("p" + nm, base, sp)
                pine(rig, nm, base, d, h, scp, tiers=4 if j == 0 else 3, ember_from=2 if j == 0 else 1)
                rig.scoli.append("p" + nm)
    # cabecona no alto da naja
    HC = Vector((0, Q_Y0 - 0.1, 0.34 + Q_RISE[0] + 0.38))
    HRq = (0.44, 0.37, 0.41)
    head = rig.empty("head", HC + Vector((0, 0.12, -0.12)), root)
    rig.add_mesh(R.ellipsoid("head", HC, HRq), "head", "lo_head", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ep, _ = V.on_ell(HC, HRq, 2.42, math.pi / 2 - 0.55 * sx, 0.9)
        V.chibi_eye(rig, nm, ep, head, (0.16, 0.2), -0.55 * sx, 3, glow=True)
        b0, _ = V.on_ell(HC, HRq, 2.02, math.pi / 2 - 0.2 * sx, 1.02)
        b1, _ = V.on_ell(HC, HRq, 2.14, math.pi / 2 - 0.95 * sx, 1.02)
        b0.z -= 0.05
        rig.add_mesh(R.cone(f"brow{nm}", b0, b1, 0.03, 0.024, seg=8, rings=1), f"brow{nm}", "brow", head, noline=True,
                     unlit=True, prio=2.2)
        mb = HC + Vector((0.07 * sx, -HRq[1] * 0.92, -0.12))
        rig.add_mesh(R.cone(f"mand{nm}", mb, mb + Vector((-0.05 * sx, -0.06, -0.07)), 0.034, 0.006, seg=6, rings=2,
                            bend=(-0.01 * sx, 0, 0)), f"mand{nm}", "claw", head, noline=True, prio=1.6)
    for j, om in enumerate((-0.5, 0.0, 0.5)):
        base, n = V.on_ell(HC, HRq, 1.35, math.pi / 2 + om, 0.95)
        d = (n + Vector((0, 0.35, 1.5))).normalized()
        nm = f"crown{j}"
        scp = rig.empty("p" + nm, base, head)
        pine(rig, nm, base, d, 0.62 if j == 1 else 0.46, scp, tiers=4, ember_from=1)
        rig.scoli.append("p" + nm)
    head.rotation_euler.x += -0.3
    # casulo de seda em pe na cauda, com costura acesa e fios
    tail = Vector((0, Q_Y0 + Q_DY * (Q_N - 1), q_r(Q_N - 1)))
    cc = tail + Vector((0, 0.3, 0.5))
    coc = rig.empty("cocoon", tail + Vector((0, 0.12, 0.0)), root)
    rig.add_mesh(R.ellipsoid("cocoon", cc, (0.28, 0.26, 0.55), seg=18, rings=14), "cocoon", "lo_silk", coc)
    for j in range(5):
        z = cc.z - 0.4 + 0.2 * j
        rr = 0.28 * math.sqrt(max(0.05, 1 - ((z - cc.z) / 0.55) ** 2))

        def fn(u, v, z=z, rr=rr):
            a = math.tau * u
            return Vector((rr * 1.04 * math.cos(a), cc.y + rr * 0.94 * math.sin(a), z + 0.04 * v + 0.05 * math.sin(a)))
        rig.add_mesh(R.surface(f"wrap{j}", fn, 20, 1, cc, closed_u=True), "wrap", "lo_silk_line", coc, noline=True)
    rig.add_mesh(R.cone("seam", cc + Vector((0, -0.25, -0.42)), cc + Vector((0, -0.25, 0.42)), 0.03, 0.03, seg=6, rings=6,
                        bend=(0, -0.05, 0)), "seam", "lo_seam", coc, unlit=True, noline=True, prio=2.0)
    for j, x in enumerate((-0.12, 0.0, 0.12)):
        rig.add_mesh(R.cone(f"thr{j}", tail + Vector((x, 0, 0.1)), cc + Vector((x * 0.6, -0.1, -0.25)), 0.008, 0.008,
                            seg=4, rings=1), "thread", "lo_silk_line", coc, noline=True)
    V.add_motes(rig, [(0.55 * math.cos(a), 0.2 + 0.7 * math.sin(a), 0.5 + 0.15 * (j % 3))
                      for j, a in enumerate([k * math.tau / 8 for k in range(8)])], ["ember_hot", "ember", "ember_core"],
                0.03)
    rig.save_rest()
    return rig


def pose_queen(rig, anim, i, n):
    t = i / n
    root, head = rig.root, rig.n("head")
    s = math.sin(math.tau * t)

    def lower(f, fwd=0.0):
        # f > 0: a frente desce (desaba); f < 0: sobe/recua
        for k, nm in enumerate(rig.segs):
            o = rig.n(nm)
            o.location.z -= rig.qrise[k] * f
            o.location.y -= fwd * max(0.0, 1 - k / 4)
        head.location.z -= (Q_RISE[0] + 0.25) * f
        head.location.y -= fwd * 1.2

    if anim == "idle":
        for k, nm in enumerate(rig.segs):
            o = rig.n(nm)
            w = math.sin(math.tau * (t - k / Q_N))
            o.scale = (1 + 0.03 * w, 1, 1 + 0.04 * w)
            if rig.qrise[k] > 0:
                o.location.x += 0.03 * rig.qrise[k] * math.sin(math.tau * t)
        head.location.x += 0.03 * math.sin(math.tau * t)
        head.rotation_euler.z = 0.1 * s
        _bristle(rig, 1.0 + 0.05 * math.sin(math.tau * 2 * t))
        rig.n("cocoon").rotation_euler.x = 0.04 * s
        if i == n - 2:
            V.blink(rig, 1.0)
        V.motes(rig, t, rise=0.7)
    elif anim == "walk":
        for k, nm in enumerate(rig.segs):
            if rig.qrise[k] > 0.1:
                continue
            u = t + k / Q_N * 0.85
            w = max(0.0, math.sin(math.tau * u)) ** 1.5
            o = rig.n(nm)
            o.location.z += 0.08 * w
            o.location.y += -0.03 * math.cos(math.tau * u)
            o.scale = (1 - 0.05 * w, 1, 1 + 0.07 * w)
        head.location.z += 0.03 * math.sin(math.tau * 2 * t)
        head.rotation_euler.z = 0.06 * s
        for k in range(3):
            rig.n(rig.segs[k]).location.z += 0.02 * math.sin(math.tau * 2 * t + k)
        rig.n("cocoon").rotation_euler.x = 0.06 * math.sin(math.tau * 2 * t)
        _bristle(rig, 1.0 + 0.03 * math.sin(math.tau * 2 * t))
        V.motes(rig, t, rise=0.6)
    elif anim == "attack":
        f = [-0.15, -0.3, -0.35, 0.55, 0.85, 0.7, 0.3, 0.05][i]
        fwd = [0.0, -0.05, -0.08, 0.12, 0.2, 0.15, 0.05, 0.0][i]
        lower(f, fwd)
        head.rotation_euler.x += [0.0, -0.2, -0.3, 0.25, 0.4, 0.3, 0.1, 0.0][i]
        _bristle(rig, [1.05, 1.2, 1.3, 1.35, 1.45, 1.3, 1.1, 1.0][i])
        if i in (4, 5):
            R.squash(root, 0.92)
        V.motes(rig, 0.12 * i, rise=0.8, spread=[1, 1, 1, 2, 4, 3.5, 2, 1][i])
    elif anim == "hit":
        R.squash(root, [0.88, 1.06, 0.97, 1.0][i])
        lower([-0.1, 0.1, 0.0, 0.0][i])
        _bristle(rig, [0.85, 1.15, 1.05, 1.0][i])
        if i == 0:
            V.blink(rig, 0.85)
        elif i == 1:
            V.blink(rig, 0.6)
        V.motes(rig, 0.1 * i, rise=0.6, spread=2.0)
    elif anim == "death":
        f = [0.0, -0.1, 0.4, 0.8, 1.0, 1.0, 1.0, 1.0][i]
        lower(f, [0, 0, 0.05, 0.1, 0.12, 0.12, 0.12, 0.12][i])
        head.rotation_euler.x += [0, -0.1, 0.3, 0.6, 0.75, 0.7, 0.7, 0.7][i]
        head.rotation_euler.y = [0, 0, 0.1, 0.3, 0.5, 0.55, 0.55, 0.55][i]
        V.blink(rig, 0.9 if i == 0 else 1.0)
        R.squash(root, [0.85, 1.05, 1.0, 0.92, 1.03, 0.98, 1.0, 1.0][i])
        _bristle(rig, [1.1, 1.0, 0.95, 0.85, 0.8, 0.78, 0.76, 0.76][i])
        rig.n("cocoon").rotation_euler.x = [0, 0, 0.1, 0.3, 0.45, 0.5, 0.5, 0.5][i]
        V.motes(rig, 0.1 * i, rise=0.5, fade=max(0.0001, 1 - i / 5))


# ------------------------------------------------------------------ atroz (s4): Mariposa do Casulo
def wing(rig, nm, sx, root_l, root_t, tip, trail_tip, piv, mat, spot=True, line=True):
    root_l, root_t, tip, trail_tip = Vector(root_l), Vector(root_t), Vector(tip), Vector(trail_tip)

    def fn(u, v):
        L = root_l.lerp(tip, u) + Vector((0, -0.06, 0.08)) * math.sin(math.pi * u)
        T = root_t.lerp(trail_tip, u) + Vector((0, 0.1, -0.04)) * math.sin(math.pi * u)
        p = L.lerp(T, v)
        # borda de fora arredondada
        p += (tip - root_l).normalized() * 0.08 * math.sin(math.pi * v) * u ** 2
        return p
    c = root_l.lerp(trail_tip, 0.5) + Vector((0, 0, -0.3))
    rig.add_mesh(R.surface(nm, fn, 10, 6, c), nm, mat, piv, group=nm)
    off = Vector((0, -0.012, 0.012))
    if line:
        pts = [fn(0.15 + 0.85 * j / 6, 0.25 + 0.5 * j / 6) + off for j in range(7)]
        for j in range(6):
            rig.add_mesh(R.cone(f"{nm}l{j}", pts[j], pts[j + 1], 0.016, 0.016, seg=4, rings=1), nm + "line",
                         "lo_wing_line", piv, noline=True, prio=1.6)
    for j, v in enumerate((0.15, 0.5, 0.85)):
        pts = [fn(0.05 + 0.9 * q / 4, v) + off for q in range(5)]
        for q in range(4):
            rig.add_mesh(R.cone(f"{nm}v{j}{q}", pts[q], pts[q + 1], 0.009, 0.009, seg=4, rings=1), "vein", "cold",
                         piv, noline=True, unlit=True, prio=1.5)
    if spot:
        p = fn(0.62, 0.5) + off * 1.5
        rig.add_mesh(R.ellipsoid(f"{nm}s", p, (0.085, 0.03, 0.07), seg=12, rings=8), "ocelo", "ember", piv,
                     noline=True, unlit=True, prio=2.2)
        rig.add_mesh(R.ellipsoid(f"{nm}s2", p + off, (0.04, 0.02, 0.034), seg=10, rings=6), "ocelo2", "ember_core",
                     piv, noline=True, unlit=True, prio=3.0)


def build_moth():
    R.reset()
    R.CUR["reach"] = (0.5, 0.6, 0.5)
    rig = R.Rig("lonomia_caterpillar")
    rig.turn.scale = (SCALE[4],) * 3
    root = rig.root
    # casulo rachado deitado
    CC = Vector((0, 0.2, 0.3))
    coc = rig.empty("cocoon", CC, root)
    rig.add_mesh(R.ellipsoid("cocoon", CC, (0.4, 0.55, 0.3), seg=20, rings=14), "cocoon", "lo_cocoon_n", coc)
    for j in range(4):
        y = CC.y - 0.35 + 0.22 * j
        rr = 0.42 * math.sqrt(max(0.05, 1 - ((y - CC.y) / 0.55) ** 2))
        def fn(u, v, y=y, rr=rr):
            a = math.pi * u
            return Vector((rr * math.cos(a), y + 0.03 * v, CC.z + rr * 0.74 * math.sin(a) + 0.005))
        rig.add_mesh(R.surface(f"wrap{j}", fn, 14, 1, CC), "wrap", "lo_cocoon_line", coc, noline=True)
    op = CC + Vector((0, -0.18, 0.26))
    rig.add_mesh(R.ellipsoid("opening", op, (0.24, 0.2, 0.05), seg=14, rings=8), "opening", "cold", coc, unlit=True,
                 noline=True, prio=1.4)
    for j in range(9):
        a = math.tau * j / 9
        p = op + Vector((0.25 * math.cos(a), 0.21 * math.sin(a), 0.0))
        rig.add_mesh(R.cone(f"shard{j}", p, p + Vector((0.07 * math.cos(a), 0.06 * math.sin(a), 0.14 + 0.06 * (j % 2))),
                            0.06, 0.005, seg=5, rings=1), "shard", "lo_cocoon_n", coc)
    # corpo da mariposa saindo do casulo
    body = rig.empty("body", op, root)
    for j, (dz, r) in enumerate(((0.05, 0.17), (0.22, 0.2), (0.4, 0.22))):
        rig.add_mesh(R.ellipsoid(f"mabd{j}", op + Vector((0, 0.02 * j, dz)), (r, r * 0.9, 0.11), seg=14, rings=10),
                     f"mabd{j}", "lo_moth_fur" if j % 2 == 0 else "lo_moth_fur2", body)
    TC = op + Vector((0, -0.04, 0.68))
    rig.add_mesh(R.ellipsoid("thorax", TC, (0.27, 0.24, 0.24), seg=18, rings=12), "thorax", "lo_moth_fur", body)
    for j in range(10):
        a = math.tau * j / 10
        p = TC + Vector((0.24 * math.cos(a), -0.08 + 0.18 * math.sin(a), 0.14))
        rig.add_mesh(R.ellipsoid(f"collar{j}", p, (0.09, 0.08, 0.07), seg=10, rings=6), "collar", "lo_moth_fur2", body,
                     group="collar")
    HC = TC + Vector((0, -0.24, 0.24))
    HRm = (0.25, 0.22, 0.23)
    head = rig.empty("head", HC + Vector((0, 0.1, -0.1)), body)
    rig.add_mesh(R.ellipsoid("head", HC, HRm), "head", "lo_moth_head", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ep, _ = V.on_ell(HC, HRm, 2.42, math.pi / 2 - 0.55 * sx, 0.9)
        V.chibi_eye(rig, nm, ep, head, (0.1, 0.125), -0.55 * sx, 4, night=True)
        b0, _ = V.on_ell(HC, HRm, 2.02, math.pi / 2 - 0.2 * sx, 1.02)
        b1, _ = V.on_ell(HC, HRm, 2.14, math.pi / 2 - 0.95 * sx, 1.02)
        b0.z -= 0.05
        rig.add_mesh(R.cone(f"brow{nm}", b0, b1, 0.03, 0.024, seg=8, rings=1), f"brow{nm}", "brow_n", head,
                     noline=True, unlit=True, prio=2.2)
        mb = HC + Vector((0.06 * sx, -HRm[1] * 0.92, -0.1))
        rig.add_mesh(R.cone(f"mand{nm}", mb, mb + Vector((-0.04 * sx, -0.05, -0.07)), 0.03, 0.005, seg=6, rings=2),
                     f"mand{nm}", "fang_n", head, noline=True, prio=1.6)
        # antena plumosa (pinheirinho)
        ab = HC + Vector((0.1 * sx, -0.05, HRm[2] * 0.85))
        ant = rig.empty(f"ant{nm}", ab, head)
        at = ab + Vector((0.32 * sx, -0.08, 0.5))
        rig.add_mesh(R.cone(f"ant{nm}", ab, at, 0.022, 0.01, seg=6, rings=4, bend=(0.04 * sx, -0.04, 0)), f"ant{nm}",
                     "lo_moth_fur2", ant, group=f"ant{nm}")
        for q in range(6):
            p = ab.lerp(at, 0.2 + 0.13 * q)
            ln = 0.13 - 0.015 * q
            for side in (1, -1):
                dd = Vector((side * 0.55 * sx, -0.3 + 0.3 * side, 0.35)).normalized()
                rig.add_mesh(R.cone(f"ant{nm}{q}{side}", p, p + dd * ln, 0.012, 0.003, seg=4, rings=1), f"antb{nm}",
                             "lo_moth_fur2", ant, group=f"ant{nm}")
    head.rotation_euler.x += -0.3
    # asas
    rig.wings = []
    for sx in (1, -1):
        r0 = TC + Vector((0.16 * sx, -0.05, 0.08))
        fw = rig.empty(f"fw{sx}", r0, body)
        wing(rig, f"fwing{sx}", sx, r0, r0 + Vector((0, 0.24, -0.08)), r0 + Vector((0.95 * sx, 0.02, 0.78)),
             r0 + Vector((0.95 * sx, 0.45, 0.25)), fw, "lo_wing")
        r1 = TC + Vector((0.13 * sx, 0.12, -0.04))
        hw = rig.empty(f"hw{sx}", r1, body)
        wing(rig, f"hwing{sx}", sx, r1, r1 + Vector((0, 0.18, -0.08)), r1 + Vector((0.7 * sx, 0.35, 0.3)),
             r1 + Vector((0.45 * sx, 0.6, 0.0)), hw, "lo_wing2", spot=True, line=False)
        rig.wings.append((f"fw{sx}", f"hw{sx}", sx))
    # dois aneis de fogo frio em volta do casulo
    rig.rings = []
    for j, (rad, z) in enumerate(((0.62, 0.12), (0.5, 0.42))):
        rp = rig.empty(f"fring{j}", CC + Vector((0, 0, z - CC.z)), root)

        def fn(u, v, rad=rad, z=z):
            a, b = math.tau * u, math.tau * v
            r = rad + 0.03 * math.cos(b)
            return Vector((r * math.cos(a), CC.y + r * 1.15 * math.sin(a), z + 0.03 * math.sin(b)))
        rig.add_mesh(R.surface(f"fring{j}", fn, 32, 6, Vector((0, CC.y, z))), f"fring{j}", "cold", rp, unlit=True,
                     noline=True, prio=1.5)
        for q in range(8):
            a = math.tau * (q + 0.5 * j) / 8
            p = Vector((rad * math.cos(a), CC.y + rad * 1.15 * math.sin(a), z))
            rig.add_mesh(R.cone(f"flame{j}{q}", p, p + Vector((0, 0, 0.16 + 0.05 * (q % 2))), 0.05, 0.004, seg=6,
                                rings=2, bend=(0.02, 0, 0)), "flame", "cold_hot" if q % 2 else "wisp_c", rp,
                         unlit=True, noline=True, prio=1.8)
        rig.rings.append(f"fring{j}")
    V.add_motes(rig, [(0.8 * math.cos(a), 0.2 + 0.7 * math.sin(a), 0.5 + 0.2 * (j % 3))
                      for j, a in enumerate([k * math.tau / 9 for k in range(9)])], ["wisp_c", "ember_hot", "wisp_v"],
                0.03)
    rig.save_rest()
    return rig


def _flap(rig, f, f2=None):
    for fw, hw, sx in rig.wings:
        rig.n(fw).rotation_euler.y = -sx * f
        rig.n(hw).rotation_euler.y = -sx * (f2 if f2 is not None else f * 0.8)


def pose_moth(rig, anim, i, n):
    t = i / n
    root, head, body = rig.root, rig.n("head"), rig.n("body")
    s = math.sin(math.tau * t)
    for j, nm in enumerate(rig.rings):
        rig.n(nm).rotation_euler.z = (1 if j == 0 else -1) * math.tau * t / 8
    for sx, nm in ((1, "L"), (-1, "R")):
        rig.n(f"ant{nm}").rotation_euler.y = -sx * 0.08 * math.sin(math.tau * t + sx)
    if anim == "idle":
        _flap(rig, 0.25 * s)
        body.location.z += 0.03 * math.sin(math.tau * t - 0.5)
        head.rotation_euler.z = 0.06 * s
        if i == n - 2:
            V.blink(rig, 1.0)
        V.motes(rig, t, rise=0.7)
    elif anim == "walk":
        _flap(rig, 0.45 * math.sin(math.tau * 2 * t))
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.06 * b
        R.squash(rig.n("cocoon"), 1.0 + 0.06 * (b - 0.5), anchored=False)
        body.location.z += 0.04 * b
        V.motes(rig, t, rise=0.6)
    elif anim == "attack":
        f = [0.3, 0.75, 0.95, -0.45, -0.6, -0.3, 0.1, 0.2][i]
        _flap(rig, f)
        R.tilt(body, [0.0, -0.15, -0.2, 0.2, 0.3, 0.15, 0.0, 0.0][i], 0.0)
        body.location.z += [0.0, 0.06, 0.1, -0.02, -0.04, 0.0, 0.0, 0.0][i]
        R.squash(root, [1.0, 1.04, 1.06, 0.92, 0.88, 0.96, 1.0, 1.0][i])
        V.motes(rig, 0.12 * i, rise=0.6, spread=[1, 1, 1, 3, 4.5, 4, 2, 1][i])
    elif anim == "hit":
        R.squash(root, [0.88, 1.06, 0.97, 1.0][i])
        _flap(rig, [0.5, -0.2, 0.1, 0.0][i])
        if i == 0:
            V.blink(rig, 0.85)
        elif i == 1:
            V.blink(rig, 0.6)
        V.motes(rig, 0.1 * i, rise=0.6, spread=2.0)
    elif anim == "death":
        _flap(rig, [0.4, 0.2, -0.2, -0.5, -0.7, -0.75, -0.8, -0.8][i])
        body.location.z -= [0, 0, 0.08, 0.2, 0.3, 0.34, 0.35, 0.35][i]
        R.tilt(body, [0, 0, 0.15, 0.3, 0.4, 0.4, 0.4, 0.4][i], 0.0)
        V.blink(rig, 0.9 if i == 0 else 1.0)
        R.squash(root, [0.86, 1.05, 1.0, 0.94, 1.02, 1.0, 1.0, 1.0][i])
        k = max(0.0001, 1 - i / 5)
        for nm in rig.rings:
            rig.n(nm).scale = (1, 1, 1) if i < 2 else (k, k, k)
        V.motes(rig, 0.1 * i, rise=0.5, fade=k)


def build(stage):
    if stage == 3:
        return build_queen()
    if stage == 4:
        return build_moth()
    return _build_small(stage)


def pose(rig, anim, i, n, stage):
    if stage == 3:
        return pose_queen(rig, anim, i, n)
    if stage == 4:
        return pose_moth(rig, anim, i, n)
    return _pose_small(rig, anim, i, n, stage)
