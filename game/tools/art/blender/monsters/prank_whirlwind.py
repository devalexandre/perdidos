"""Redemoinho Arteiro (prank_whirlwind): redemoinho do Saci, 3 estagios (GDD 10.3 / 10.6).
  s1 Redemoinho Arteiro (pequeno)  s2 Rodamoinho Traquinas (medio: gravetos e pedrinhas, gorro com borla)
  s3 Ventania do Gorro Vermelho (chefe: tornado de folhas douradas, olhos brilhando, cachimbo com fumaca).
  s4 Ventania Atroz (forma atroz = o chefe a noite): tempestade anil/roxa com duas camadas de funil girando em sentidos
  opostos, raios piscando, nuvem carregada com olhos de brasa e sorriso de dentes, gorro virado capuz carmim-negro
  rasgado com pontas de chifre, e em orbita espinhos, galhos, pedras de basalto e brasas.
Corpo = bolota de poeira com rosto arteiro + funil de fitas de vento girando + folhas em orbita + gorro
vermelho. Tudo gira em loop (simetria de 120 graus das fitas) e quica (pulinhos)."""
import math
from mathutils import Vector
import mon_rig as R

SCALE = {1: 1.15, 2: 1.55, 3: 2.75, 4: 2.62}
LEAN = 22.0
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
NIGHT = {"wind": "storm_n", "dust": "storm_d_n", "dust_dark": "brow_n", "mouth": "eye_slit", "cap": "hood_n",
         "cap_band": "obsidian_n", "wood": "thorn_n", "smoke": "cloud_n", "pebble": "basalt_n", "eye_glow": "eye_ember"}
PUFF_C = Vector((0, 0, 0.66))
PUFF_R = (0.25, 0.23, 0.22)
SYM = math.tau / 3   # as fitas repetem a cada 120 graus -> giro em loop


def _funnel_r(z):
    return 0.05 + 0.30 * max(0.0, z / 0.62) ** 1.25


def ribbon(name, z0, h, a0, span, rise, rscale=1.0, width=0.75):
    """Fita helicoidal de vento em volta do eixo Z (u = volta, v = largura)."""
    def fn(u, v):
        a = a0 + span * u
        z = z0 + h * width * v + rise * u
        r = _funnel_r(z) * rscale * (1.0 + 0.08 * math.sin(math.pi * v))
        return Vector((r * math.cos(a), r * math.sin(a), z))
    return R.surface(name, fn, 16, 2, (0, 0, z0 + h * 0.5))


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.22, 0.22, 0.22)
    rig = R.Rig("prank_whirlwind")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # funil: 3 niveis x 3 fitas (defasadas 120 graus), pivo no eixo
    swirl = rig.empty("swirl", (0, 0, 0), root)
    levels = 4 if stage >= 2 else 3
    for lv in range(levels):
        z0 = 0.04 + lv * 0.15
        for k in range(3):
            nm = f"rib{lv}_{k}"
            mat = "wind" if (lv + k) % 2 == 0 else "dust"
            rig.add_mesh(ribbon(nm, z0, 0.16, k * SYM + lv * 0.7, 1.7, 0.07), nm, mat, swirl)
    if stage == 4:
        # segunda camada de funil, mais larga e rasgada, girando ao contrario
        swirl2 = rig.empty("swirl2", (0, 0, 0), root)
        for lv in range(3):
            z0 = 0.1 + lv * 0.17
            for k in range(3):
                nm = f"orib{lv}_{k}"
                rig.add_mesh(ribbon(nm, z0, 0.11, k * SYM + lv * 1.1 + 0.5, 1.1, 0.1, rscale=1.42, width=0.6), nm,
                             "dust" if (lv + k) % 2 else "wind", swirl2)
    # bolota de poeira com rosto
    puff = rig.empty("puff", PUFF_C, root)
    pbody = rig.empty("pbody", PUFF_C, puff)
    rig.add_mesh(R.ellipsoid("puffmesh", PUFF_C, PUFF_R), "puff", "dust" if stage < 4 else "cloud_n", pbody, group="puff")
    if stage == 4:
        # nuvem carregada: calombos em volta da bolota
        for k, (a, z, rr) in enumerate(((0.5, 0.05, 0.1), (2.6, 0.05, 0.1), (1.57, 0.1, 0.11), (3.6, -0.05, 0.09),
                                        (5.8, -0.05, 0.09))):
            p = PUFF_C + Vector((0.2 * math.cos(a), 0.18 * math.sin(a), z))
            rig.add_mesh(R.ellipsoid(f"lump{k}", p, (rr, rr, rr * 0.85)), "puff", "cloud_n", pbody, group="puff")
    # fita de vento em volta da cabeca (atras do rosto: so na metade de tras)
    for k in range(2):
        nm = f"hair{k}"
        def fn(u, v, k=k):
            a = math.radians(20 + 140 * u) + k * math.pi * 0.5
            z = PUFF_C.z - 0.08 + 0.14 * v + 0.10 * u
            r = 0.27 + 0.03 * math.sin(math.pi * v)
            return Vector((r * math.cos(a), r * math.sin(a), z))
        rig.add_mesh(R.surface(nm, fn, 12, 2, PUFF_C), nm, "wind", pbody)
    face = rig.empty("face", PUFF_C + Vector((0, -0.2, 0.02)), pbody)
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = PUFF_C + Vector((0.095 * sx, -0.205, 0.035))
        eye = rig.empty(f"eye{nm}", ep, face)
        rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (0.08, 0.035, 0.095), rot=(0.3, 0, -0.45 * sx)), f"eye{nm}",
                     "white" if stage < 4 else "ember_core", eye, prio=1.6, **({} if stage < 4 else dict(unlit=True)))
        # pupila olhando de lado (arteiro)
        pp = ep + Vector((0.03, -0.035, -0.01))
        rig.add_mesh(R.ellipsoid(f"pup{nm}", pp, (0.035, 0.02, 0.05), rot=(0.3, 0, -0.45 * sx)), f"pup{nm}",
                     "eye_glow" if stage == 3 else "eye", eye, noline=True, unlit=True, prio=3.0)
        if stage < 4:
            rig.add_mesh(R.ellipsoid(f"hl{nm}", pp + Vector((-0.012, -0.02, 0.02)), (0.014, 0.01, 0.014)), f"hl{nm}", "white",
                         eye, noline=True, unlit=True, prio=4.0)
        # palpebra de cima inclinada (olhar maroto)
        tilt = 0.02 + 0.015 * stage
        rig.add_mesh(R.cone(f"lid{nm}", ep + Vector((-0.07 * sx, -0.035, 0.07 - tilt)), ep + Vector((0.07 * sx, -0.03, 0.07 + tilt)),
                            0.022, 0.022, seg=8, rings=1), f"lid{nm}", "dust_dark", eye, noline=True, unlit=True, prio=2.5)
    # sorriso maroto (canto levantado)
    rig.add_mesh(R.cone("grin", PUFF_C + Vector((-0.07, -0.215, -0.07)), PUFF_C + Vector((0.08, -0.205, -0.045)),
                        0.016 if stage < 4 else 0.024, 0.02 if stage < 4 else 0.03, seg=6, rings=3, bend=(0, 0, -0.03)),
                 "grin", "mouth", face, noline=True, unlit=True, prio=2.0)
    if stage == 4:
        # dentes serrilhados no sorriso
        g0, g1 = PUFF_C + Vector((-0.07, -0.235, -0.052)), PUFF_C + Vector((0.08, -0.225, -0.027))
        for k in range(5):
            u = 0.1 + 0.8 * k / 4
            b = g0.lerp(g1, u) + Vector((0, 0, -0.03 * 4 * u * (1 - u)))
            rig.add_mesh(R.cone(f"tooth{k}", b + Vector((0, 0, 0.012)), b + Vector((0, -0.006, -0.03)), 0.014, 0.002, seg=5,
                                rings=1), "tooth", "fang_n", face, noline=True, unlit=True, prio=3.0)
    if stage >= 3:
        # cachimbo com fumaca
        pb = PUFF_C + Vector((0.09, -0.22, -0.06))
        rig.add_mesh(R.cone("pipe", pb, pb + Vector((0.14, -0.08, -0.02)), 0.014, 0.018, seg=6, rings=1), "pipe", "wood", face)
        bowl = pb + Vector((0.15, -0.09, 0.0))
        rig.add_mesh(R.ellipsoid("bowl", bowl, (0.03, 0.03, 0.035)), "bowl", "wood", face)
        smoke = rig.empty("smoke", bowl, face)
        for i in range(3):
            rig.add_mesh(R.ellipsoid(f"smoke{i}", bowl + Vector((0.02 * i, 0.0, 0.06 + 0.07 * i)), (0.03 + 0.012 * i,) * 3,
                                     seg=10, rings=6), f"smoke{i}", "smoke", smoke)
        if stage == 4:
            rig.add_mesh(R.ellipsoid("bowlfire", bowl + Vector((0, 0, 0.03)), (0.024, 0.024, 0.012)), "bowlfire", "ember_hot",
                         face, noline=True, unlit=True, prio=4.0)
    # gorro vermelho do Saci (ponta caida para tras)
    cap = rig.empty("cap", PUFF_C + Vector((0, 0.02, 0.19)), puff)
    cb = PUFF_C + Vector((0, 0.03, 0.15))
    ch = 0.24 + 0.06 * (stage - 1)
    cb = cb + Vector((0, 0.04, 0.0))
    rig.add_mesh(R.ellipsoid("capband", cb, (0.17, 0.155, 0.05), rot=(-0.35, 0, 0)), "capband", "cap_band", cap)
    if stage == 4:
        _atroz_hood(rig, cap, cb)
    else:
        rig.add_mesh(R.cone("cap", cb + Vector((0, 0.01, 0.02)), cb + Vector((0.02, 0.2, ch * 0.75)), 0.155, 0.03, seg=14,
                            rings=6, bend=(0, -0.02, 0.12)), "cap", "cap", cap)
    if 2 <= stage <= 3:
        tip = cb + Vector((0.02, 0.2, ch * 0.75))
        rig.add_mesh(R.ellipsoid("tassel", tip + Vector((0, 0.03, -0.03)), (0.045, 0.045, 0.045)), "tassel", "gold", cap)
    # folhas (e gravetos/pedrinhas) em orbita
    orbit = rig.empty("orbit", (0, 0, 0), root)
    n_leaf = {1: 5, 2: 7, 3: 10, 4: 0}[stage]
    mats = ["leaf_o", "leaf_y", "leaf_g", "leaf_o", "leaf_y", "leaf_r", "leaf_g", "leaf_o", "leaf_y", "leaf_y"]
    rig.leaves = []
    for i in range(n_leaf):
        a = i * math.tau / n_leaf + 0.4
        z = 0.12 + 0.62 * ((i * 0.37) % 1.0)
        r = _funnel_r(z) + 0.13
        p = Vector((r * math.cos(a), r * math.sin(a), z))
        lf = rig.empty(f"leaf{i}", p, orbit)
        m = mats[i] if stage < 3 else ("leaf_y" if i % 3 else "leaf_o")
        rig.add_mesh(R.ellipsoid(f"leaf{i}", p, (0.075, 0.042, 0.014), rot=(0.5 * i, 0.8, a), seg=8, rings=5),
                     f"leaf{i}", m, lf, group=f"leaf{i}")
        rig.leaves.append((f"leaf{i}", a, z, r))
    if 2 <= stage <= 3:
        for i in range(3 if stage == 2 else 5):
            a = i * math.tau / 3 + 1.2
            z = 0.25 + 0.2 * i % 0.6
            r = _funnel_r(z) + 0.17
            p = Vector((r * math.cos(a), r * math.sin(a), z))
            st = rig.empty(f"peb{i}", p, orbit)
            rig.add_mesh(R.ellipsoid(f"peb{i}", p, (0.04, 0.035, 0.03), seg=7, rings=5), f"peb{i}", "pebble", st)
            rig.leaves.append((f"peb{i}", a, z, r))
            if i < 2:
                q = p + Vector((0, 0, 0.1))
                tw = rig.empty(f"twig{i}", q, orbit)
                rig.add_mesh(R.cone(f"twig{i}", q + Vector((-0.07, 0, 0)), q + Vector((0.07, 0.02, 0.03)), 0.012, 0.008, seg=5,
                                    rings=1), f"twig{i}", "wood", tw)
                rig.leaves.append((f"twig{i}", a + 0.5, z + 0.1, r))
    if stage == 4:
        _atroz_debris(rig, orbit)
        _atroz_bolts(rig, root)
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ forma atroz (s4)
def _atroz_hood(rig, cap, cb):
    """Capuz carmim-negro: gorro caido para tras mais curto, duas pontas de chifre e barra rasgada."""
    rig.add_mesh(R.cone("cap", cb + Vector((0, 0.02, 0.02)), cb + Vector((0.0, 0.26, 0.2)), 0.165, 0.02, seg=14, rings=6,
                        bend=(0, 0.02, 0.07)), "cap", "cap", cap)
    for sx in (1, -1):
        b = cb + Vector((0.095 * sx, -0.01, 0.05))
        rig.add_mesh(R.cone(f"hornc{sx}", b, b + Vector((0.13 * sx, 0.03, 0.27)), 0.065, 0.004, seg=10, rings=6,
                            bend=(0.07 * sx, 0.0, -0.02)), f"hornc{sx}", "cap", cap)
    for k in range(9):
        a = math.radians(-10 + 200 * k / 8)
        p = cb + Vector((0.172 * math.cos(a), 0.158 * math.sin(a) + 0.01, -0.035))
        ln = 0.07 + 0.045 * ((k * 5) % 3)
        rig.add_mesh(R.cone(f"hem{k}", p, p + Vector((0.025 * math.cos(a), 0.03 * math.sin(a) + 0.01, -ln)), 0.034, 0.003,
                            seg=5, rings=1), "hem", "cap", cap)


def _atroz_debris(rig, orbit):
    """Detritos da tempestade em orbita: espinhos, galhos com forquilha, pedras de basalto e brasas."""
    items = [("thorn", 0.18, 0.4), ("stone", 0.3, 0.12), ("ember", 0.55, 0.3), ("branch", 0.22, 0.65),
             ("thorn", 0.45, 0.55), ("stone", 0.62, 0.35), ("ember", 0.1, 0.72), ("branch", 0.5, 0.2),
             ("thorn", 0.35, 0.78), ("stone", 0.15, 0.6), ("ember", 0.7, 0.5), ("ember", 0.4, 0.18),
             ("thorn", 0.6, 0.28)]
    n = len(items)
    for i, (kind, zf, jit) in enumerate(items):
        a = i * math.tau / n + 0.3
        z = 0.1 + 0.7 * zf
        r = _funnel_r(z) * 1.42 + 0.1 + 0.06 * jit
        p = Vector((r * math.cos(a), r * math.sin(a), z))
        nm = f"deb{i}"
        e = rig.empty(nm, p, orbit)
        tang = Vector((-math.sin(a), math.cos(a), 0.25 * (i % 2 - 0.5)))
        if kind == "thorn":
            rig.add_mesh(R.cone(nm, p - tang * 0.05, p + tang * 0.07, 0.028, 0.003, seg=5, rings=2,
                                bend=(0, 0, 0.015)), "thorn", "wood", e)
        elif kind == "branch":
            b0, b1 = p - tang * 0.1, p + tang * 0.1
            rig.add_mesh(R.cone(nm, b0, b1, 0.017, 0.008, seg=5, rings=2, bend=(0, 0, 0.02)), "branch", "wood", e)
            m = b0.lerp(b1, 0.55)
            rig.add_mesh(R.cone(nm + "f", m, m + Vector((0, 0, 0.07)) + tang * 0.03, 0.01, 0.004, seg=5, rings=1),
                         "branch", "wood", e)
        elif kind == "stone":
            rig.add_mesh(R.ellipsoid(nm, p, (0.05, 0.04, 0.036), rot=(0.4 * i, 0.3, a), seg=6, rings=4), "stone",
                         "pebble", e)
        else:
            rr = 0.028 if i % 2 else 0.022
            rig.add_mesh(R.ellipsoid(nm, p, (rr, rr, rr * 1.2), seg=8, rings=5), "deb_ember" if i % 2 else "deb_ember2",
                         "ember_hot" if i % 2 else "ember", e, noline=True, unlit=True, prio=4.0)
        rig.leaves.append((nm, a, z, r))


def _zigzag(rig, piv, name, pts, r0, mat):
    for k in range(len(pts) - 1):
        rig.add_mesh(R.cone(f"{name}_{k}", pts[k], pts[k + 1], r0 * (1 - 0.18 * k), r0 * (1 - 0.18 * (k + 1)), seg=5,
                            rings=1), name, mat, piv, unlit=True, noline=True, prio=3.5)


def _atroz_bolts(rig, root):
    """Raios: 3 em volta do funil (piscam por quadro) e 1 grande que cai na frente no ataque."""
    rig.bolts = []
    for k in range(3):
        a = k * math.tau / 3 + 0.9
        piv = rig.empty(f"bolt{k}", (0, 0, 0.4), root)
        pts = []
        for j in range(5):
            z = 0.78 - 0.17 * j
            rr = _funnel_r(z) * 1.42 + 0.12 + (0.05 if j % 2 else -0.02)
            aa = a + (0.18 if j % 2 else -0.05) + 0.06 * j
            pts.append(Vector((rr * math.cos(aa), rr * math.sin(aa), z)))
        _zigzag(rig, piv, f"bolt{k}", pts, 0.02, "bolt" if k != 1 else "bolt2")
        rig.bolts.append(f"bolt{k}")
    piv = rig.empty("strike", (0, -0.45, 0.0), root)
    pts = [Vector((0.02, -0.3, 0.95)), Vector((-0.07, -0.38, 0.72)), Vector((0.06, -0.44, 0.5)), Vector((-0.05, -0.5, 0.28)),
           Vector((0.03, -0.55, 0.05))]
    _zigzag(rig, piv, "strike", pts, 0.032, "bolt")
    rig.add_mesh(R.ellipsoid("strikeglow", Vector((0.03, -0.55, 0.03)), (0.13, 0.09, 0.025)), "strikeglow", "bolt2", piv,
                 unlit=True, noline=True, prio=2.0)


def _orbit(rig, t, spread=1.0, lift=0.0, speed=1.0):
    for nm, a0, z0, r0 in rig.leaves:
        o = rig.n(nm)
        a = a0 + math.tau * t * speed
        r = r0 * spread
        z = z0 + lift + 0.03 * math.sin(math.tau * t * 2 + a0 * 3)
        base = rig.rest[nm][0]
        o.location = Vector((r * math.cos(a), r * math.sin(a), z)) - Vector((r0 * math.cos(a0), r0 * math.sin(a0), z0)) + base
        o.rotation_euler.z = a - a0


def _blink(rig, amt):
    for nm in ("L", "R"):
        rig.n(f"eye{nm}").scale.z *= max(0.15, 1.0 - amt)


def _bolts(rig, on):
    for k, nm in enumerate(rig.bolts):
        rig.n(nm).scale = rig.rest[nm][2] if k in on else (0.0001,) * 3


def _atroz_pose(rig, anim, i, n):
    """Forma atroz: funil de fora gira ao contrario, raios piscam, raio grande cai na frente no golpe."""
    t = i / n
    sw2 = rig.n("swirl2")
    rig.n("strike").scale = (0.0001,) * 3
    if anim == "idle":
        sw2.rotation_euler.z = -SYM * t
        _bolts(rig, [k for k in range(3) if (i + 3 * k) % 4 == 0])
    elif anim == "walk":
        sw2.rotation_euler.z = -SYM * t * 2
        _bolts(rig, [k for k in range(3) if (i + 2 * k) % 5 == 0])
    elif anim == "attack":
        sw2.rotation_euler.z = -[0, 0.3, 1.0, 1.9, 2.8, 3.6, 4.4, 2 * SYM][i] * 0.5
        _bolts(rig, {0: [], 1: [0, 1, 2], 2: [0, 2], 3: [1], 4: [0, 1], 5: [2], 6: [], 7: []}[i])
        if i in (3, 4):
            rig.n("strike").scale = (1.0, 1.0, 1.0) if i == 3 else (0.85, 0.85, 1.0)
    elif anim == "hit":
        sw2.rotation_euler.z = 0.3 * (1 - t)
        _bolts(rig, [0, 1, 2] if i == 0 else ([1] if i == 1 else []))
    elif anim == "death":
        sw2.rotation_euler.z = -[0, 1.0, 2.2, 3.6, 4.6, 5.2, 5.5, 5.6][i]
        k = [1.0, 1.0, 0.85, 0.55, 0.3, 0.12, 0.0, 0.0][i]
        sw2.scale = Vector((1 + (1 - k) * 0.5, 1 + (1 - k) * 0.5, max(0.0001, k))) if k > 0.05 else (0.0001,) * 3
        _bolts(rig, [0, 1, 2] if i == 1 else ([2] if i == 2 else []))


def pose(rig, anim, i, n, stage):
    t = i / n
    root, swirl, puff, cap = rig.root, rig.n("swirl"), rig.n("puff"), rig.n("cap")
    spin = SYM * t  # um terco de volta por ciclo = loop perfeito
    if stage == 4:
        _atroz_pose(rig, anim, i, n)
    if anim == "idle":
        swirl.rotation_euler.z = spin * 2
        root.location.z += 0.03 + 0.03 * math.sin(math.tau * t)
        R.squash(puff, 1.0 + 0.06 * math.sin(math.tau * t + 0.8), anchored=False)
        cap.rotation_euler.x = 0.12 * math.sin(math.tau * t)
        cap.rotation_euler.y = 0.08 * math.sin(math.tau * t + 1.3)
        _orbit(rig, t)
        if i == n - 3:
            _blink(rig, 1.0)
        if stage >= 3:
            rig.n("smoke").location.z += 0.04 * t; rig.n("smoke").scale = (1 + 0.3 * t,) * 3
    elif anim == "walk":
        # pulinhos: dois por ciclo, estica no ar e achata ao tocar
        ph = (2 * t) % 1.0
        hop = 4 * ph * (1 - ph)
        root.location.z += 0.12 * hop
        R.squash(root, 0.85 + 0.3 * hop if ph > 0.1 else 0.8)
        root.rotation_euler.x = -0.12
        swirl.rotation_euler.z = spin * 3
        cap.rotation_euler.x = 0.25 * hop - 0.05
        _orbit(rig, t, speed=1.0, lift=0.02 * hop)
    elif anim == "attack":
        # prepara (achata e torce para tras), estica e avanca girando rapido, folhas voando para fora, volta
        sq = [0.82, 0.72, 1.28, 1.22, 0.78, 1.1, 0.95, 1.0][i]
        lean = [-0.12, -0.22, 0.2, 0.26, 0.16, 0.06, 0.0, 0.0][i]
        spread = [1.0, 0.85, 1.2, 1.32, 1.4, 1.28, 1.12, 1.0][i]
        R.squash(root, sq)
        R.tilt(root, lean, -0.12 if lean > 0 else 0.12)
        swirl.rotation_euler.z = [0, -0.5, 1.2, 2.6, 3.8, 4.6, 5.3, 6.28][i]
        cap.rotation_euler.x = [0.2, 0.35, -0.35, -0.5, 0.25, 0.15, 0.0, 0.0][i]
        _orbit(rig, t * 2.5, spread=spread)
        if i in (1, 2, 3):
            for nm in ("L", "R"):
                rig.n(f"eye{nm}").scale.z *= 0.75  # olhar decidido
    elif anim == "hit":
        sq = [0.72, 1.2, 0.92, 1.03][i]
        R.squash(root, sq)
        R.tilt(root, [-0.16, 0.08, -0.04, 0][i], 0.12)
        cap.location.z += [0.12, 0.06, 0.0, 0.0][i]
        cap.rotation_euler.x = [0.5, -0.2, 0.1, 0][i]
        swirl.rotation_euler.z = -0.4 * (1 - t)
        _orbit(rig, 0.05 * i, spread=[1.1, 1.06, 1.02, 1.0][i])
        if i < 2:
            _blink(rig, 1.0)
    elif anim == "death":
        # gira rapido e estica, desmancha: fitas abrem, bolota murcha, folhas espalham e caem; sobra o gorro no chao
        swirl.rotation_euler.z = [0, 2.0, 4.5, 7.5, 9.5, 10.5, 11.0, 11.2][i]
        k = [1.0, 1.0, 0.9, 0.65, 0.4, 0.2, 0.0, 0.0][i]
        R.squash(root, [0.8, 1.3, 1.15, 1.0, 1.0, 1.0, 1.0, 1.0][i], anchored=False)
        swirl.scale = Vector((1 + (1 - k) * 0.3, 1 + (1 - k) * 0.3, max(0.0001, k))) if k > 0.05 else (0.0001,) * 3
        _blink(rig, 1.0 if i >= 1 else 0.6)
        spread = [1.0, 1.1, 1.2, 1.28, 1.32, 1.35, 1.35, 1.35][i]
        fall = [0, 0, 0, 0.2, 0.45, 0.62, 0.72, 0.72][i]
        for nm, a0, z0, r0 in rig.leaves:
            o = rig.n(nm)
            a = a0 + [0, 0.8, 1.6, 2.2, 2.6, 2.8, 2.9, 2.9][i]
            r = r0 * spread * [1.0, 1.0, 1.0, 0.85, 0.7, 0.55, 0.48, 0.48][i]  # caem juntando perto do gorro
            z = max(0.02, z0 * (1 - fall / 0.72) + 0.02 * (1 - fall / 0.72)) if i >= 3 else z0
            o.location = Vector((r * math.cos(a), r * math.sin(a), z)) - Vector((r0 * math.cos(a0), r0 * math.sin(a0), z0)) \
                + rig.rest[nm][0]
            if i >= 6:
                o.rotation_euler = (0, 0, a)
                o.scale = (1.0, 1.0, 0.6)
        rig.n("pbody").scale = (max(0.0001, k),) * 3
        # o gorro cai girando e fica no chao
        drop = [0, 0, 0, 0.2, 0.45, 0.66, 0.7, 0.7][i]
        puff.location.z -= drop
        cap.rotation_euler.x = [0, 0, 0.2, 0.5, 0.9, 1.2, 1.3, 1.3][i]
        cap.location.z += [0, 0, 0, 0, 0, 0.0, 0.02, 0.0][i]
