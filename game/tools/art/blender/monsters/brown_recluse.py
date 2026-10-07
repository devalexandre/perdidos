"""Aranha-Marrom (brown_recluse, Loxosceles) — fauna peconhenta do Brasil. Modelo proprio por script
(venom_common.spider): menor e mais rente ao chao que a armadeira, toda marrom-canela, com o "violino" escuro no
dorso do cefalotorax (o braco aponta para o abdomen), abdomen liso marrom-escuro e patas finas e compridas sem
listras. Golpe: bote rente ao chao (agacha, salta e morde).
  s1 Aranha-Marrom (quadro 96)   s2 Aranha-Marrom Tecedeira (144): fios de seda saindo das fiandeiras e teia
     nas costas   s3 Tecedeira da Necrose (240, chefe — "Rainha do Violino"): modelo proprio de chefe, alta e pernalta; o violino
     do dorso virou um violino de verdade erguido nas costas (tampo de madeira, espelho de ebano, cordas, voluta e
     efes acesos em roxo); a pata da frente segura o arco. Necrose viva: pustulas roxas acesas no abdomen e nas
     juntas, teia grande nas costas, nevoa roxa. Golpe: toca (o arco serra), ondas de som roxas, e da o bote.
  s4 Aranha-Marrom Atroz (240, "Fantasma"): outra silhueta — flutua envolta num lencol de teia fantasma (lilas
     palido) que termina em tiras rasgadas e fiapos de luz fria; so a cabeca e as patas longas e finas saem do
     lencol; violino e olhos acesos em ciano; fogos-fatuos. Golpe: mergulho no ar."""
import math
from mathutils import Vector
import mon_rig as R
import venom_common as V

Z = V.Z

SCALE = {1: 0.88, 2: 1.26, 3: 1.57, 4: 1.52}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"br_body": "fur_wine_n", "br_abd": "chitin_n", "br_leg": "fur_wine_n", "br_dark": "obsidian_n",
         "br_pale": "pale_n", "br_silk": "pale_n", "claw": "fang_n", "brow": "brow_n", "br_violin_g": "wisp_v",
         "br_sore": "wisp_c"}


def pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    vm = "br_violin_g" if stage >= 3 else "br_violin"
    fl = dict(noline=True, group="violin", unlit=stage >= 3, prio=1.6)
    # corpo do violino junto dos olhos, braco para tras (para o abdomen)
    rig.add_mesh(R.plate("violin", V.CT_C, ct_r, 1.66, 2.06, 0.86, math.pi - 0.86, bulge=0.0, res=6, lift=1.025),
                 "violin", vm, head, **fl)
    rig.add_mesh(R.plate("violin2", V.CT_C, ct_r, 1.5, 1.72, 1.02, math.pi - 1.02, bulge=0.0, res=5, lift=1.025),
                 "violin", vm, head, **fl)
    rig.add_mesh(R.plate("vneck", V.CT_C, ct_r, 0.5, 1.55, math.pi / 2 - 0.17, math.pi / 2 + 0.17, bulge=0.0, res=5,
                         lift=1.025), "violin", vm, head, **fl)
    rig.add_mesh(R.plate("vscroll", V.CT_C, ct_r, 0.38, 0.62, math.pi / 2 - 0.22, math.pi / 2 + 0.22, bulge=0.0,
                         res=4, lift=1.025), "violin", vm, head, **fl)


def extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    if stage >= 2:
        # teia nas costas
        top, n = V.on_ell(ab_c, ab_r, 1.2, math.pi / 2, 1.0)
        for j in range(6):
            a = j * math.tau / 6
            q, _ = V.on_ell(ab_c, ab_r, 1.2 + 0.55 * math.cos(a), math.pi / 2 + 0.6 * math.sin(a), 1.035)
            rig.add_mesh(R.cone(f"web{j}", top + n * 0.03, q, 0.01, 0.01, seg=4, rings=2), "web", "br_silk", abd,
                         noline=True)
        for ring in (0.25, 0.45):
            for j in range(6):
                a0 = j * math.tau / 6; a1 = (j + 1) * math.tau / 6
                p0, _ = V.on_ell(ab_c, ab_r, 1.2 + 0.55 * ring / 0.45 * math.cos(a0), math.pi / 2 + 0.6 * ring / 0.45 * math.sin(a0), 1.04)
                p1, _ = V.on_ell(ab_c, ab_r, 1.2 + 0.55 * ring / 0.45 * math.cos(a1), math.pi / 2 + 0.6 * ring / 0.45 * math.sin(a1), 1.04)
                rig.add_mesh(R.cone(f"webr{ring}{j}", p0, p1, 0.009, 0.009, seg=4, rings=1), "web", "br_silk", abd,
                             noline=True)
    if stage >= 3:
        for j, (ps, om, r) in enumerate(((0.55, 1.0, 0.05), (0.75, 2.2, 0.04), (1.75, 2.35, 0.045), (1.85, 0.8, 0.035))):
            p, n = V.on_ell(ab_c, ab_r, ps, om, 1.01)
            rig.add_mesh(R.ellipsoid(f"sore{j}", p, (r, r, 0.015), rot=V.align(n), seg=10, rings=6), "sore",
                         "br_sore", abd, noline=True, unlit=True, prio=1.5)
        # crista de espinhos finos atras dos olhos
        for j, om in enumerate((-0.4, 0.0, 0.4)):
            p, n = V.on_ell(V.CT_C, ct_r, 1.3, math.pi / 2 + om, 0.97)
            up = (n + Vector((0, 0.5, 1.0))).normalized()
            rig.add_mesh(R.cone(f"crest{j}", p, p + up * (0.13 - 0.03 * abs(om) / 0.4), 0.028, 0.004, seg=6, rings=2),
                         f"crest{j}", "br_dark", head, group="crest")
    if stage == 4:
        for j, (ps, h) in enumerate(((0.6, 0.14), (1.0, 0.17), (1.4, 0.15))):
            for sx in (1, -1):
                p, n = V.on_ell(ab_c, ab_r, ps, math.pi / 2 - 0.6 * sx, 0.98)
                up = (n + Vector((0, 0.5, 0.6))).normalized()
                rig.add_mesh(R.cone(f"blade{j}{sx}", p, p + up * h, 0.045, 0.004, seg=5, rings=2),
                             f"blade{j}{sx}", "br_dark", abd, group=f"blade{j}{sx}")
        for nm in ("L", "R"):
            tip = Vector(rig.n(f"fang{nm}").data.vertices[-1].co)
            rig.add_mesh(R.ellipsoid(f"drop{nm}", tip + Vector((0, 0, -0.03)), (0.018, 0.018, 0.028), seg=8, rings=6),
                         "drop", "cold_hot", rig.n(f"chel{nm}"), unlit=True, noline=True, prio=4.0)
        ep = rig.empty("embers", (0, 0, 0), rig.root)
        rig.embers = []
        for j in range(6):
            a = j * math.tau / 6 + 0.4
            p = Vector((0.5 * math.cos(a), 0.15 + 0.45 * math.sin(a), 0.2 + 0.07 * (j % 3)))
            rig.empty(f"emb{j}", p, ep)
            rig.add_mesh(R.ellipsoid(f"emb{j}", p, (0.022, 0.022, 0.03), seg=8, rings=5), "emb" if j % 2 else "embc",
                         "wisp_v" if j % 2 else "wisp_c", rig.n(f"emb{j}"), unlit=True, noline=True, prio=4.0)
            rig.embers.append((f"emb{j}", j / 6.0))


CFG = dict(id="brown_recluse", scale=SCALE,
           mats=dict(body="br_body", abd="br_abd", dark="br_dark", pale="br_pale", fang="br_body", leg="br_leg",
                     leg_band="br_leg", leg_dark="br_dark"),
           ct_r=(0.28, 0.28, 0.21), ab_c=(0, 0.42, 0.3), ab_r=(0.25, 0.31, 0.21),
           leg_len=(0.7, 0.62, 0.55, 0.68), leg_w=0.036, knee_h=0.27, hairy=False, eye=0.115, fang_len=0.06,
           head_tilt=-0.4, small_eyes=((2.02, 0.16, 0.024), (2.2, 0.9, 0.022)),
           pattern=pattern, extras=extras, night=NIGHT)


# ------------------------------------------------------------------ chefe (s3): Rainha do Violino
def queen_leg(rig, stage, nm, hp, kp, hip, knee, foot, d, sx, k, lw):
    # pustula de necrose no joelho
    rig.add_mesh(R.ellipsoid(nm + "pu", knee + Vector((0, 0, lw * 0.6)), (lw * 1.15, lw * 1.15, lw * 0.9), seg=8,
                             rings=6), "pustule", "br_sore_hot", kp, noline=True, unlit=True, prio=1.6)
    if k == 0 and sx < 0:
        # arco do violino na pata da frente
        a = knee.lerp(foot, 0.55) + Vector((0, 0, 0.03))
        b = a + (d * 0.25 + Vector((0, 0.15, 0.85))).normalized() * 0.95
        rig.add_mesh(R.cone("bow", a, b, 0.018, 0.012, seg=6, rings=4, bend=(0, -0.03, 0)), "bow", "br_wood", kp,
                     group="bow")
        rig.add_mesh(R.cone("bowhair", a + Vector((0, -0.04, 0.02)), b + Vector((0, -0.04, -0.04)), 0.008, 0.008,
                            seg=4, rings=1), "bowhair", "br_string", kp, noline=True, group="bow")
        rig.add_mesh(R.ellipsoid("frog", a, (0.03, 0.03, 0.04), seg=8, rings=6), "frog", "br_dark", kp, group="bow")


def violin(rig, head, ct_r, stage):
    C = V.CT_C
    B = Vector((0, C.y + 0.14, C.z + ct_r[2] * 0.7))
    vp = rig.empty("violin", B, head)
    W = "br_wood"
    for nm, dz, rad in (("vlow", 0.22, (0.21, 0.065, 0.17)), ("vwaist", 0.37, (0.13, 0.055, 0.08)),
                        ("vup", 0.5, (0.165, 0.06, 0.13))):
        rig.add_mesh(R.ellipsoid(nm, B + Vector((0, 0, dz)), rad, seg=20, rings=12), "vbody", W, vp, group="violin")
    rig.add_mesh(R.cone("vneck", B + Vector((0, 0.0, 0.6)), B + Vector((0, 0.0, 0.86)), 0.035, 0.03, seg=8, rings=1),
                 "vneck", W, vp, group="violin")
    rig.add_mesh(R.ellipsoid("vscroll", B + Vector((0, -0.005, 0.9)), (0.045, 0.045, 0.055), seg=10, rings=8), "vscroll",
                 W, vp, group="violin")
    for sx in (1, -1):
        rig.add_mesh(R.cone(f"vpeg{sx}", B + Vector((0, 0, 0.8)), B + Vector((0.08 * sx, 0.0, 0.81)), 0.014, 0.02,
                            seg=6, rings=1), "vpeg", "br_dark", vp)
        rig.add_mesh(R.cone(f"vf{sx}", B + Vector((0.085 * sx, -0.062, 0.14)), B + Vector((0.07 * sx, -0.062, 0.3)),
                            0.016, 0.012, seg=6, rings=2, bend=(0.015 * sx, 0, 0)), "vfhole",
                     "cold_hot" if stage == 4 else "br_violin_g", vp, unlit=True, noline=True, prio=2.0)
    rig.add_mesh(R.cone("vboard", B + Vector((0, -0.066, 0.3)), B + Vector((0, -0.05, 0.8)), 0.032, 0.026, seg=8,
                        rings=1), "vboard", "br_dark", vp)
    rig.add_mesh(R.cone("vtail", B + Vector((0, -0.07, 0.07)), B + Vector((0, -0.07, 0.17)), 0.04, 0.022, seg=8,
                        rings=1), "vboard", "br_dark", vp)
    rig.add_mesh(R.ellipsoid("vbridge", B + Vector((0, -0.075, 0.2)), (0.06, 0.014, 0.022), seg=8, rings=6),
                 "vbridge", "br_pale", vp, noline=True)
    for j, x in enumerate((-0.03, -0.01, 0.01, 0.03)):
        rig.add_mesh(R.cone(f"vstr{j}", B + Vector((x, -0.08, 0.17)), B + Vector((x * 0.6, -0.07, 0.78)), 0.005, 0.005,
                            seg=4, rings=1), "vstring", "br_string", vp, noline=True, prio=1.8)
    vp.rotation_euler.x += -0.12
    return vp


def sound_rings(rig, head, ct_r):
    C = V.CT_C
    rig.rings = []
    for j in range(2):
        c = Vector((0, C.y - 0.35 - 0.1 * j, C.z + 0.4))
        piv = rig.empty(f"ring{j}", c, head)

        def fn(u, v, c=c, rr=0.22 + 0.06 * j):
            a, b = math.tau * u, math.tau * v
            r = rr + 0.025 * math.cos(b)
            return c + Vector((r * math.cos(a), 0.025 * math.sin(b), r * math.sin(a)))
        rig.add_mesh(R.surface(f"ring{j}", fn, 24, 6, c), "ring", "br_violin_g", piv, unlit=True, noline=True, prio=3.0)
        rig.rings.append(f"ring{j}")


def queen_pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    pattern(rig, 3, abd, head, ab_c, ab_r, ct_r)


def queen_extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    violin(rig, head, ct_r, 3)
    sound_rings(rig, head, ct_r)
    # necrose viva: pustulas acesas e escuras
    for j, (ps, om, r) in enumerate(((0.45, 1.0, 0.07), (0.7, 2.1, 0.06), (1.2, 0.75, 0.055), (1.55, 2.35, 0.065),
                                     (1.85, 1.2, 0.05), (1.1, 1.9, 0.045), (0.3, 1.6, 0.05))):
        p, n = V.on_ell(ab_c, ab_r, ps, om, 1.0)
        rig.add_mesh(R.ellipsoid(f"sore{j}", p, (r * 1.25, r * 1.25, 0.02), rot=V.align(n), seg=10, rings=6), "sorering",
                     "br_sore", abd, noline=True, unlit=True, prio=1.4)
        rig.add_mesh(R.ellipsoid(f"pus{j}", p + n * 0.015, (r * 0.75, r * 0.75, r * 0.55), rot=V.align(n), seg=10,
                                 rings=6), "pus", "br_sore_hot", abd, noline=True, unlit=True, prio=1.8)
    # teia grande nas costas
    top, n = V.on_ell(ab_c, ab_r, 1.15, math.pi / 2, 1.0)
    for j in range(8):
        a = j * math.tau / 8
        q, _ = V.on_ell(ab_c, ab_r, 1.15 + 0.85 * math.cos(a), math.pi / 2 + 0.95 * math.sin(a), 1.035)
        rig.add_mesh(R.cone(f"web{j}", top + n * 0.03, q, 0.011, 0.011, seg=4, rings=3), "web", "br_silk", abd,
                     noline=True)
    for ring in (0.3, 0.6, 0.9):
        for j in range(8):
            a0, a1 = j * math.tau / 8, (j + 1) * math.tau / 8
            p0, _ = V.on_ell(ab_c, ab_r, 1.15 + 0.85 * ring * math.cos(a0), math.pi / 2 + 0.95 * ring * math.sin(a0), 1.04)
            p1, _ = V.on_ell(ab_c, ab_r, 1.15 + 0.85 * ring * math.cos(a1), math.pi / 2 + 0.95 * ring * math.sin(a1), 1.04)
            rig.add_mesh(R.cone(f"webr{ring}{j}", p0, p1, 0.01, 0.01, seg=4, rings=1), "web", "br_silk", abd,
                         noline=True)
    V.add_motes(rig, [(0.55 * math.cos(a), 0.3 + 0.55 * math.sin(a), 0.25 + 0.1 * (j % 3))
                      for j, a in enumerate([k * math.tau / 7 for k in range(7)])], ["br_sore", "br_sore_hot"], 0.03)


# ------------------------------------------------------------------ atroz (s4): Aranha-Marrom Fantasma
def ghost_extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    ab_c = Vector(ab_c)
    # o violino continua no dorso, aceso em ciano
    for nm in ("violin", "violin2", "vneck", "vscroll"):
        pass
    # lencol fantasma: sai do topo do abdomen e cai em volta dele, borda rasgada; tiras soltas atras
    top = ab_c + Vector((0, -0.05, ab_r[2] * 0.85))

    def fn(u, v):
        a = math.tau * u
        r = 0.12 + 0.36 * v + 0.12 * math.sin(math.pi * v)
        rag = 0.16 * abs(math.sin(6 * math.pi * u)) * v ** 2
        z = top.z - (top.z - 0.02) * v + rag
        yb = 0.12 * v
        return Vector((r * math.cos(a), top.y + yb + r * 1.15 * math.sin(a), z))
    rig.add_mesh(R.surface("shroud", fn, 28, 8, ab_c, closed_u=True), "shroud", "br_ghost", abd, group="shroud")
    rig.add_mesh(R.ellipsoid("shroudtop", top, (0.14, 0.16, 0.06), seg=12, rings=8), "shroud", "br_ghost", abd,
                 group="shroud")
    # fios de teia desenhados no lencol (raios + 2 voltas)
    for j in range(10):
        u = j / 10
        pts = [fn(u, v / 6) * 1.0 for v in range(7)]
        for k in range(6):
            c = (pts[k] - Vector((0, top.y, 0)))
            off = Vector((c.x, c.y, 0)).normalized() * 0.012 if c.length > 1e-4 else Vector()
            rig.add_mesh(R.cone(f"sw{j}{k}", pts[k] + off, pts[k + 1] + off, 0.008, 0.008, seg=4, rings=1), "sweb",
                         "br_ghost_line", abd, noline=True, prio=1.5)
    for v in (0.35, 0.7):
        pts = [fn(u / 20, v) for u in range(21)]
        for k in range(20):
            c = pts[k] - Vector((0, top.y, 0))
            off = Vector((c.x, c.y, 0)).normalized() * 0.012
            rig.add_mesh(R.cone(f"swr{v}{k}", pts[k] + off, pts[k + 1] + off, 0.008, 0.008, seg=4, rings=1), "sweb",
                         "br_ghost_line", abd, noline=True, prio=1.5)
    rig.tendrils = []
    for j, (x, h) in enumerate(((-0.3, 0.55), (0.0, 0.75), (0.3, 0.55), (-0.16, 0.62), (0.16, 0.62), (-0.4, 0.4),
                                (0.4, 0.4))):
        b = Vector((x, ab_c.y + 0.42 - 0.25 * abs(x), 0.06))
        tp = rig.empty(f"tend{j}", b, abd)
        rig.add_mesh(R.cone(f"tend{j}", b, b + Vector((x * 0.6, h * 0.8, h * 0.45)), 0.07, 0.006, seg=7, rings=6,
                            bend=(0.05 * (1 if j % 2 else -1), 0.0, -0.12)), f"tend{j}", "br_ghost2", tp, group="shroud")
        rig.tendrils.append(f"tend{j}")
    # violino fantasma (so o desenho aceso no cefalotorax) + olhos/efes em ciano
    V.add_motes(rig, [(0.65 * math.cos(a), 0.2 + 0.65 * math.sin(a), 0.35 + 0.15 * (j % 3))
                      for j, a in enumerate([k * math.tau / 8 for k in range(8)])], ["wisp_c", "wisp_v", "wisp_c2"], 0.032)


def ghost_pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    pattern(rig, 3, abd, head, ab_c, ab_r, ct_r)


def ring_extra(rig, i):
    for j, nm in enumerate(rig.rings):
        o = rig.n(nm)
        k = i - 2 - j
        if 0 <= k <= 3:
            sc = 0.6 + 0.35 * k
            o.scale = (sc, sc, sc)
            o.location.y -= 0.08 * k
        else:
            o.scale = (0.0001,) * 3
    if 1 <= i <= 4:
        rig.n("violin").rotation_euler.y = 0.04 * (1 if i % 2 else -1)


MATS_BOSS = dict(body="br_body", abd="br_abd", dark="br_dark", pale="br_pale", fang="br_body", leg="br_leg",
                 leg_band="br_leg", leg_dark="br_dark")
CFG3 = dict(id="brown_recluse", scale=SCALE, mats=MATS_BOSS,
            ct_r=(0.3, 0.3, 0.23), ab_c=(0, 0.5, 0.36), ab_r=(0.3, 0.38, 0.27),
            leg_len=(0.98, 0.86, 0.74, 0.92), leg_w=0.044, knee_h=0.42, hairy=False, eye=0.12, fang_len=0.08,
            head_tilt=-0.4, small_eyes=((2.02, 0.16, 0.026), (2.2, 0.9, 0.024)),
            leg_hook=queen_leg, pattern=queen_pattern, extras=queen_extras)
GHOST = {"br_body": "br_ghost", "br_abd": "br_ghost", "br_leg": "br_ghost_leg", "br_dark": "br_ghost_dark",
         "br_pale": "pale_n", "claw": "fang_n", "brow": "brow_n", "br_violin_g": "cold_hot", "eye_ember": "eye_cyan",
         "ember_core": "cold_hot"}
CFG4 = dict(id="brown_recluse", scale=SCALE, mats=MATS_BOSS,
            ct_r=(0.3, 0.3, 0.23), ab_c=(0, 0.48, 0.36), ab_r=(0.29, 0.36, 0.26),
            leg_len=(1.0, 0.9, 0.78, 0.92), leg_w=0.036, knee_h=0.46, hairy=False, eye=0.125, fang_len=0.1,
            head_tilt=-0.4, small_eyes=((2.02, 0.16, 0.026), (2.2, 0.9, 0.024)),
            pattern=ghost_pattern, extras=ghost_extras, night=GHOST)
POSE3 = {"tilt": -0.1, "raise": (0.95, 0.0), "attack": "bow", "attack_extra": ring_extra}
POSE4 = {"hover": 0.3, "attack": "swoop"}


def build(stage):
    if stage == 3:
        return V.spider(CFG3, 3)
    if stage == 4:
        return V.spider(CFG4, 4)
    return V.spider(CFG, stage)


def pose(rig, anim, i, n, stage):
    if stage >= 3:
        if stage == 3:
            ring_extra(rig, -9)
        V.boss_spider_pose(rig, anim, i, n, stage, POSE3 if stage == 3 else POSE4)
        if stage == 4:
            t = i / n
            for j, nm in enumerate(rig.tendrils):
                rig.n(nm).rotation_euler.x = 0.25 * math.sin(math.tau * (t + j * 0.2))
                rig.n(nm).rotation_euler.z = 0.15 * math.sin(math.tau * (t + j * 0.13) + 1)
        return
    V.spider_pose(rig, anim, i, n, stage, "pounce")
    if stage == 4:
        t = i / n
        fade = 1.0 if anim != "death" else max(0.0001, 1 - i / 5)
        for nm, ph in rig.embers:
            u = (t + ph) % 1.0
            o = rig.n(nm)
            o.location = rig.rest[nm][0] + Vector((0.03 * math.sin(math.tau * u + ph * 6), 0, 0.35 * u))
            s = max(0.0001, (1 - u) ** 0.7 * fade)
            o.scale = (s, s, s)
        for nm in ("L", "R"):
            rig.n(f"drop{nm}").scale = (1, 1, 1.0 + 0.4 * ((i % 4) / 3))
