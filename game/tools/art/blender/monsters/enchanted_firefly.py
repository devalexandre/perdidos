"""Vaga-lume Encantado (enchanted_firefly), 3 estagios (GDD 10.3 / 10.6).
  s1 Vaga-lume Encantado (pequeno)  s2 Vaga-lume Candeeiro (medio: abdomen-lanterna, antenas acesas, luzinhas)
  s3 Rainha-Lume do Brejo (chefe: coroa, asas grandes douradas, abdomen enorme, fogos-fatuos em volta).
  s4 Rainha-Lume Atroz (forma atroz = a rainha a noite): quitina anil, asas roxas rasgadas com veias de luz fria,
  lanterna-gaiola ciano com um miolo de brasa aparecendo entre as costelas, ferrao, coroa de espinhos com joia
  roxa, mandibulas, olhos fendidos acesos e 4 fogos-fatuos com rastro em orbita.
Voa parado (paira): quica no ar, bate as asas a cada quadro e o abdomen pulsa (troca de rampa por quadro)."""
import math, random
from mathutils import Vector, Euler
import mon_rig as R

SCALE = {1: 1.1, 2: 1.55, 3: 2.6, 4: 2.6}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
NIGHT = {"bug": "chitin_n", "bug_dark": "chitin_dark_n", "gold": "gold_n", "lamp_rib": "nlamp_rib", "lamp1": "nlamp1",
         "lamp2": "nlamp2", "wisp_b": "wisp_c"}
LEAN = 16.0
HOVER = 0.30
LAMPS = ["lamp0", "lamp1", "lamp2"]  # apagado -> aceso -> brilhando


def build(stage):
    R.reset()
    R.CUR["reach"] = (0.2, 0.25, 0.2)
    rig = R.Rig("enchanted_firefly")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    fly = rig.empty("fly", (0, 0.02, HOVER + 0.18), root)
    Z = HOVER
    # torax e cabeca
    rig.add_mesh(R.ellipsoid("thorax", (0, 0.04, Z + 0.17), (0.15, 0.14, 0.14)), "thorax", "bug", fly, group="bug")
    head = rig.empty("head", (0, -0.1, Z + 0.2), fly)
    HC = Vector((0, -0.21, Z + 0.25))
    rig.add_mesh(R.ellipsoid("headm", HC, (0.25, 0.225, 0.24)), "head", "bug", head)
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = HC + Vector((0.115 * sx, -0.18, 0.02))
        eye = rig.empty(f"eye{nm}", ep, head)
        if stage < 4:
            rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (0.092, 0.05, 0.112), rot=(0.2, 0, -0.5 * sx)), f"eye{nm}", "eye", eye,
                         noline=True, unlit=True, prio=1.8)
            rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.03, -0.05, 0.04)), (0.036, 0.02, 0.036)), f"hl{nm}", "white", eye,
                         noline=True, unlit=True, prio=6.0)
            rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.03, -0.05, -0.04)), (0.02, 0.012, 0.02)), f"hl2{nm}", "white",
                         eye, noline=True, unlit=True, prio=3.0)
            rig.add_mesh(R.ellipsoid(f"cheek{nm}", HC + Vector((0.18 * sx, -0.15, -0.08)), (0.04, 0.02, 0.025)), f"cheek{nm}",
                         "blush", head, noline=True, unlit=True, prio=1.2)
        else:
            # olho fendido aceso (luz fria), pupila em fenda, contorno escuro em volta e sobrancelha brava
            rig.add_mesh(R.ellipsoid(f"eyeb{nm}", ep + Vector((0, 0.01, 0)), (0.105, 0.05, 0.12), rot=(0.2, 0, -0.5 * sx)),
                         f"eyeb{nm}", "eye", eye, noline=True, unlit=True, prio=1.6)
            rig.add_mesh(R.ellipsoid(f"eye{nm}", ep + Vector((0, -0.012, -0.01)), (0.085, 0.045, 0.095), rot=(0.2, 0, -0.5 * sx)),
                         f"eye{nm}", "eye_cyan", eye, noline=True, unlit=True, prio=2.0)
            rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0.005 * sx, -0.05, -0.01)), (0.017, 0.02, 0.078),
                                     rot=(0.2, 0, -0.5 * sx)), f"slit{nm}", "eye_slit", eye, noline=True, unlit=True, prio=4.0)
            rig.add_mesh(R.cone(f"brow{nm}", ep + Vector((-0.07 * sx, -0.05, 0.055)), ep + Vector((0.08 * sx, -0.02, 0.135)),
                                0.03, 0.018, seg=6, rings=1), f"brow{nm}", "bug_dark", head, noline=True, unlit=True, prio=2.6)
        if 2 <= stage <= 3:
            # sobrancelha seria (candeeiro/rainha)
            rig.add_mesh(R.cone(f"brow{nm}", ep + Vector((-0.05 * sx, -0.04, 0.085)), ep + Vector((0.06 * sx, -0.02, 0.11)),
                                0.016, 0.014, seg=6, rings=1), f"brow{nm}", "bug_dark", head, noline=True, unlit=True, prio=2)
        # antenas curvas com bolinha na ponta
        ant = rig.empty(f"ant{nm}", HC + Vector((0.07 * sx, -0.05, 0.17)), head)
        a0 = HC + Vector((0.07 * sx, -0.05, 0.17)); a1 = a0 + Vector((0.12 * sx, -0.1, 0.2))
        rig.add_mesh(R.cone(f"ant{nm}", a0, a1, 0.018, 0.012, seg=6, rings=4, bend=(0.03 * sx, 0.04, 0.03)), f"ant{nm}",
                     "bug_dark", ant, group="ant")
        if stage == 4:
            # antena comprida e em gancho, ponta de luz fria
            a2 = a1 + Vector((0.07 * sx, 0.02, 0.1))
            rig.add_mesh(R.cone(f"ant2{nm}", a1, a2, 0.012, 0.008, seg=6, rings=3, bend=(0.03 * sx, 0.03, 0.02)), f"ant{nm}",
                         "bug_dark", ant, group="ant")
            rig.add_mesh(R.ellipsoid(f"antip{nm}", a2, (0.03, 0.03, 0.04)), f"antip{nm}", "cold_hot", ant, unlit=True,
                         noline=True, prio=3.0)
        else:
            rig.add_mesh(R.ellipsoid(f"antip{nm}", a1, (0.035, 0.035, 0.035)), f"antip{nm}",
                         "lamp1" if stage >= 2 else "bug", ant, group=f"antip{nm}")
    if stage == 4:
        _atroz_head(rig, head, HC)
    else:
        rig.add_mesh(R.cone("smile", HC + Vector((-0.04, -0.225, -0.085)), HC + Vector((0.04, -0.225, -0.085)), 0.011, 0.011,
                            seg=6, rings=3, bend=(0, 0, -0.018)), "smile", "bug_dark", head, noline=True, unlit=True, prio=1.5)
    if stage == 3:
        # coroa (crista dourada)
        for k, (dx, h) in enumerate(((-0.12, 0.15), (0.0, 0.22), (0.12, 0.15))):
            b = HC + Vector((dx, 0.02, 0.17))
            rig.add_mesh(R.cone(f"crown{k}", b, b + Vector((dx * 0.4, 0.0, h)), 0.055, 0.01, seg=6, rings=1), f"crown{k}",
                         "gold", head, group="crown")
        rig.add_mesh(R.ellipsoid("crownband", HC + Vector((0, 0.02, 0.165)), (0.13, 0.11, 0.03)), "crownband", "gold", head,
                     group="crown")
        rig.add_mesh(R.ellipsoid("jewel", HC + Vector((0, -0.09, 0.19)), (0.03, 0.02, 0.03)), "jewel", "wisp_b", head,
                     noline=True, unlit=True, prio=3)
    head.rotation_euler.x = -0.4  # rosto levantado para a camera alta
    # abdomen: parte de cima verde, lanterna embaixo (pulsa)
    abd = rig.empty("abd", (0, 0.12, Z + 0.16), fly)
    big = {1: 1.0, 2: 1.15, 3: 1.3, 4: 1.36}[stage]
    AC = Vector((0, 0.3, Z + 0.1))
    ar = (0.17 * big, 0.21 * big, 0.17 * big)
    if stage == 4:
        _atroz_abdomen(rig, abd, AC, ar)
    else:
        rig.add_mesh(R.plate("abdtop", AC, (ar[0] * 1.04, ar[1] * 1.04, ar[2] * 1.04), 0.9, 2.6, 0.35, math.pi - 0.35, bulge=0.05),
                     "abdtop", "bug", abd)
        lamp = R.ellipsoid("lamp", AC, ar)
        rig.add_mesh(lamp, "lamp1", "lamp1", abd, glow=True)
        rig.lamp = lamp
    if 2 <= stage <= 3:
        # nervuras de lanterna de papel
        for k in range(3):
            psi = 0.55 + 0.5 * k
            rig.add_mesh(R.plate(f"rib{k}", AC, (ar[0] * 1.02, ar[1] * 1.02, ar[2] * 1.02), psi - 0.05, psi + 0.05, -2.4, 5.5,
                                 bulge=0.0, res=8), f"rib{k}", "lamp_rib", abd, noline=True)
    # patinhas
    for k, y in enumerate((-0.03, 0.05, 0.13)):
        for sx in (1, -1):
            b = Vector((0.08 * sx, y, Z + 0.07))
            rig.add_mesh(R.cone(f"leg{k}{sx}", b, b + Vector((0.07 * sx, -0.02, -0.1)), 0.016, 0.01, seg=5, rings=2,
                                bend=(0.02 * sx, 0, 0.02)), f"leg{k}", "bug_dark", fly, noline=True)
    # asas (4): par da frente maior; pivo na base
    wmat = "wing_gold" if stage >= 2 else "wing"
    wsz = {1: 1.0, 2: 1.15, 3: 1.45, 4: 1.55}[stage]
    for sx, nm in ((1, "L"), (-1, "R")):
        for fr, (dy, ln, wd) in enumerate(((0.0, 0.2, 0.08), (0.1, 0.16, 0.065))):
            base = Vector((0.06 * sx, 0.08 + dy, Z + 0.28))
            w = rig.empty(f"wing{nm}{fr}", base, fly)
            c = base + Vector((0.15 * sx * wsz, 0.1 + 0.06 * fr, 0.06))
            if stage == 4:
                _tattered_wing(rig, w, f"wing{nm}{fr}", c, ln * wsz, wd * wsz * 1.15,
                               (0.25, 0.25 * sx, (0.45 + 0.5 * fr) * sx), seed=3 + 2 * fr + (sx > 0))
                continue
            rig.add_mesh(R.ellipsoid(f"wing{nm}{fr}", c, (ln * wsz, wd * wsz, 0.012),
                                     rot=(0.25, 0.25 * sx, (0.45 + 0.5 * fr) * sx)), f"wing{nm}{fr}", wmat, w,
                         group=f"wing{nm}{fr}")
    # luzinhas em orbita (s2) / fogos-fatuos (s3)
    rig.motes = []
    nm_ = {1: 0, 2: 3, 3: 6, 4: 0}[stage]
    if stage == 4:
        _atroz_wisps(rig, root, Z)
    for k in range(nm_):
        a = k * math.tau / max(1, nm_)
        r = 0.42 if stage == 2 else 0.5
        p = Vector((r * math.cos(a), r * math.sin(a), Z + 0.1 + 0.15 * (k % 2)))
        m = rig.empty(f"mote{k}", p, root)
        mat = "wisp_b" if (stage == 3 and k % 2) else "lamp2"
        rig.add_mesh(R.ellipsoid(f"mote{k}", p, (0.04 + 0.01 * (stage == 3),) * 3, seg=8, rings=5), f"mote{k}", mat, m,
                     noline=True, unlit=True, prio=2.5, glow=True)
        rig.motes.append((f"mote{k}", a, p.z, r))
    # clarao do ataque (esfera chapada na frente do abdomen), escondido fora do golpe
    FP = Vector((0, -0.5, Z + 0.12))
    flash = rig.empty("flash", FP, root)
    rig.add_mesh(R.ellipsoid("flash", FP, (0.2, 0.2, 0.2)), "flash", "lamp2", flash,
                 unlit=True, prio=1.5, glow=True)
    if stage == 4:
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
        rig.part_info[rig.parts["flash"]]["mat"] = "wisp_c"   # clarao de luz fria
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ forma atroz (s4)
def _atroz_head(rig, head, HC):
    """Coroa de espinhos (ouro velho) com joia roxa, mandibulas em pinca e boca brava."""
    for k, (ang, h, lean) in enumerate(((-1.0, 0.17, 0.5), (-0.5, 0.24, 0.25), (0.0, 0.3, 0.0), (0.5, 0.24, -0.25),
                                         (1.0, 0.17, -0.5))):
        b = HC + Vector((0.12 * math.sin(ang), 0.02 - 0.05 * math.cos(ang), 0.16))
        tip = b + Vector((-lean * 0.18, 0.03, h))
        rig.add_mesh(R.cone(f"crown{k}", b, tip, 0.045, 0.004, seg=6, rings=4, bend=(-lean * 0.06, 0.02, -0.01)),
                     f"crown{k}", "gold", head, group="crown")
        if k in (1, 3):
            # espinho lateral no meio do espinho grande
            m = b.lerp(tip, 0.45)
            rig.add_mesh(R.cone(f"thorn{k}", m, m + Vector((-lean * 0.35, -0.02, 0.05)), 0.018, 0.003, seg=5, rings=1),
                         f"crown{k}", "gold", head, group="crown")
    rig.add_mesh(R.ellipsoid("crownband", HC + Vector((0, 0.0, 0.165)), (0.15, 0.12, 0.035)), "crownband", "gold", head,
                 group="crown")
    rig.add_mesh(R.ellipsoid("jewel", HC + Vector((0, -0.12, 0.19)), (0.04, 0.025, 0.045)), "jewel", "wisp_v", head,
                 noline=True, unlit=True, prio=3)
    # mandibulas (pinca): pivo na base, abrem no ataque
    for sx, nm in ((1, "L"), (-1, "R")):
        b = HC + Vector((0.075 * sx, -0.19, -0.13))
        m = rig.empty(f"mand{nm}", b, head)
        rig.add_mesh(R.cone(f"mand{nm}", b, b + Vector((-0.045 * sx, -0.12, -0.05)), 0.03, 0.004, seg=7, rings=4,
                            bend=(0.05 * sx, -0.01, 0.0)), f"mand{nm}", "fang_n", m, prio=1.8)
    rig.add_mesh(R.cone("mouth", HC + Vector((-0.045, -0.225, -0.085)), HC + Vector((0.045, -0.225, -0.085)), 0.012, 0.012,
                        seg=6, rings=3, bend=(0, 0, 0.02)), "mouth", "bug_dark", head, noline=True, unlit=True, prio=1.5)


def _atroz_abdomen(rig, abd, AC, ar):
    """Lanterna-gaiola: aneis de luz fria com frestas por onde aparece o miolo de brasa; casca de quitina em cima;
    ferrao de brasa na ponta."""
    rig.add_mesh(R.plate("abdtop", AC, (ar[0] * 1.05, ar[1] * 1.05, ar[2] * 1.05), 0.75, 2.7, 0.6, math.pi - 0.6,
                         bulge=0.06), "abdtop", "bug", abd)
    # espinhos na casca
    for k, psi in enumerate((1.2, 1.7, 2.2)):
        d = R.shell_dir(psi, math.pi / 2)
        p = AC + Vector((d.x * ar[0], d.y * ar[1], d.z * ar[2])) * 1.05
        rig.add_mesh(R.cone(f"aspike{k}", p, p + Vector((0, 0.05, 0.09 - 0.015 * k)), 0.03, 0.003, seg=5, rings=1),
                     "aspike", "bug_dark", abd)
    rig.core = R.ellipsoid("core", AC, (ar[0] * 0.86, ar[1] * 0.86, ar[2] * 0.86))
    rig.add_mesh(rig.core, "core", "ember_core", abd, unlit=True, noline=True, prio=1.2)
    rig.lamp = []
    edges = [(0.0, 0.5), (0.64, 1.1), (1.24, 1.7), (1.84, 2.3), (2.44, 3.14)]
    for k, (p0, p1) in enumerate(edges):
        o = R.plate(f"cage{k}", AC, ar, p0, p1, -math.pi / 2, 1.5 * math.pi, bulge=0.05, res=12)
        rig.add_mesh(o, "nlamp1", "nlamp1", abd, glow=True)
        rig.lamp.append(o)
    rig.lamp_names = {-1: "nlamp_off", 0: "nlamp0", 1: "nlamp1", 2: "nlamp2"}
    # ferrao
    b = AC + Vector((0, ar[1] * 0.9, -0.02))
    rig.add_mesh(R.cone("sting", b, b + Vector((0, 0.2, -0.1)), 0.06, 0.004, seg=8, rings=4, bend=(0, 0.02, 0.03)),
                 "sting", "bug", abd)
    rig.add_mesh(R.ellipsoid("stingtip", b + Vector((0, 0.19, -0.095)), (0.025, 0.025, 0.025)), "stingtip", "ember_hot",
                 abd, unlit=True, noline=True, prio=3.0)


def _tattered_wing(rig, piv, name, c, ln, wd, rot, seed):
    """Asa rasgada: disco levemente abaulado com recortes na borda de fora + veias de luz fria."""
    rnd = random.Random(seed)
    M = Euler(rot).to_matrix()
    N = 36

    def h(x, y):
        return 0.028 * max(0.0, 1 - (x / ln) ** 2 - (y / wd) ** 2)
    rim = []
    for j in range(N):
        th = math.tau * j / N
        x, y = math.cos(th), math.sin(th)
        r = 1.0
        if x > -0.15 and j % 3 == 1:
            r = 0.62 + 0.14 * rnd.random()   # rasgo
        elif x > 0.3 and j % 3 == 2:
            r = 1.06
        rim.append((x * r * ln, y * r * wd))
    mid = [(x * 0.5, y * 0.5) for x, y in rim]
    loc = [(0.0, 0.0)] + mid + rim
    verts = [c + M @ Vector((x, y, h(x, y))) for x, y in loc]
    faces = []
    for j in range(N):
        a, b = 1 + j, 1 + (j + 1) % N
        faces.append((0, a, b))
        faces.append((a, a + N, b + N, b))
    o = R._obj_from(name, verts, faces)
    R._fix_normals(o, c - M @ Vector((0, 0, 1.0)))
    rig.add_mesh(o, name, "wing_n", piv, group=name)
    # veias: da raiz (lado do corpo) em leque ate a borda
    root = (-0.8 * ln, 0.0)
    for k, (tx, ty) in enumerate(((0.85 * ln, 0.05 * wd), (0.45 * ln, 0.62 * wd), (0.45 * ln, -0.6 * wd))):
        p0 = c + M @ Vector((root[0], root[1], h(*root) + 0.004))
        p1 = c + M @ Vector((tx, ty, h(tx, ty) + 0.004))
        rig.add_mesh(R.cone(f"{name}v{k}", p0, p1, 0.011, 0.006, seg=6, rings=3, bend=M @ Vector((0, 0, 0.022))),
                     "vein", "vein_n", piv, unlit=True, noline=True, prio=2.2)


def _atroz_wisps(rig, root, Z):
    """4 fogos-fatuos (roxo/ciano) com chama e rastro de 3 bolinhas atras na orbita."""
    rig.wisps = []
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        r = 0.56
        z = Z + 0.08 + 0.2 * (k % 2)
        col, col2 = ("wisp_v", "wisp_v2") if k % 2 else ("wisp_c", "wisp_c2")
        pieces = []
        for j, (lag, sz) in enumerate(((0.0, 1.0), (0.3, 0.72), (0.55, 0.5), (0.78, 0.32))):
            nm = f"wisp{k}_{j}"
            p = Vector((r * math.cos(a - lag), r * math.sin(a - lag), z))
            e = rig.empty(nm, p, root)
            rr = 0.052 * sz
            rig.add_mesh(R.ellipsoid(nm, p, (rr, rr, rr * 1.15), seg=8, rings=6), col if j == 0 else col2,
                         col if j == 0 else col2, e, noline=True, unlit=True, prio=3.0, glow=True)
            if j == 0:
                # chama de 3 linguas tortas (le como fogo, nao como gota) + miolo claro
                for q, (dx, hh, rr0, bx) in enumerate(((0.0, 0.2, 0.046, 0.035), (0.03, 0.12, 0.026, -0.03),
                                                        (-0.03, 0.1, 0.024, 0.025))):
                    rig.add_mesh(R.cone(f"{nm}f{q}", p + Vector((dx * 0.6, 0, 0.02)), p + Vector((dx, 0, hh)), rr0, 0.003,
                                        seg=8, rings=4, bend=(bx, 0, 0)), col, col, e, noline=True, unlit=True, prio=3.0,
                                 glow=True)
                rig.add_mesh(R.ellipsoid(nm + "c", p + Vector((0, -0.035, 0.0)), (0.026, 0.016, 0.034)), "wisp_core",
                             "white", e, noline=True, unlit=True, prio=5.0)
            pieces.append((nm, lag, sz))
        rig.wisps.append((pieces, a, z, r))


def _wisps(rig, t, spread=1.0, fade=1.0, speed=1.0):
    for pieces, a0, z0, r0 in rig.wisps:
        for nm, lag, sz in pieces:
            a = a0 + math.tau * t * speed - lag * (0.6 + 0.4 * speed)
            r = r0 * spread
            o = rig.n(nm)
            o.location = Vector((r * math.cos(a), r * math.sin(a), z0 + 0.05 * math.sin(math.tau * 2 * t + a0 - lag)))
            k = max(0.0001, fade if lag == 0 else fade ** 1.5)
            o.scale = (k, k, k * (1.0 + 0.15 * math.sin(math.tau * 4 * t + a0)) if lag == 0 else k)


def _atroz_pose(rig, anim, i, n):
    t = i / n
    for nm, sg in (("L", 1), ("R", -1)):
        rig.n(f"mand{nm}").rotation_euler.z = 0.0
    core = ["ember_core", "ember_hot", "ember_core", "ember_core", "ember_hot", "ember_core", "ember_hot", "ember_core"][i % 8]
    if anim == "idle":
        _wisps(rig, t)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"mand{nm}").rotation_euler.z = sg * 0.12 * max(0.0, math.sin(math.tau * 2 * t))
    elif anim == "walk":
        _wisps(rig, t, speed=1.0)
    elif anim == "attack":
        # mandibulas abrem na carga e fecham no disparo; fogos-fatuos voam para fora e voltam
        op = [0.35, 0.55, -0.1, -0.12, -0.05, 0.1, 0.05, 0.0][i]
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"mand{nm}").rotation_euler.z = sg * op
        _wisps(rig, t * 1.5, spread=[1.0, 0.8, 1.35, 1.6, 1.5, 1.3, 1.1, 1.0][i], speed=1.5)
        core = "ember_core" if i in (1, 2, 3) else core
    elif anim == "hit":
        _wisps(rig, 0.04 * i, spread=[1.25, 1.15, 1.05, 1.0][i])
        core = "ember_hot" if i == 0 else core
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"mand{nm}").rotation_euler.z = sg * [0.4, 0.2, 0.05, 0][i]
    elif anim == "death":
        _wisps(rig, t, spread=1 + 0.4 * t, fade=max(0.0001, 1 - i / 4))
        core = ["ember_core", "ember_hot", "ember_core", "ember", "ember_hot", "ember_dim", "chitin_dark_n",
                "chitin_dark_n"][i]
    rig.set_part(rig.core, "core_" + core, core, unlit=True, noline=True, prio=1.2)


def _lamp(rig, level):
    """level 0..2 (apagado..brilhando) ou -1 = morto."""
    names = getattr(rig, "lamp_names", None) or {-1: "lamp_off", 0: "lamp0", 1: "lamp1", 2: "lamp2"}
    for o in (rig.lamp if isinstance(rig.lamp, list) else [rig.lamp]):
        rig.set_part(o, names[level], names[level], glow=True)


def _wings(rig, phase, amp=0.7, rest=0.1):
    for nm, sg in (("L", 1), ("R", -1)):
        for fr in (0, 1):
            w = rig.n(f"wing{nm}{fr}")
            w.rotation_euler.y = -sg * (rest + amp * math.sin(math.tau * phase + fr * 0.8))


def _motes(rig, t, spread=1.0):
    for nm, a0, z0, r0 in rig.motes:
        a = a0 + math.tau * t
        rig.n(nm).location = Vector((r0 * spread * math.cos(a), r0 * spread * math.sin(a),
                                     z0 + 0.05 * math.sin(math.tau * 2 * t + a0)))


def _blink(rig, amt):
    for nm in ("L", "R"):
        rig.n(f"eye{nm}").scale.z *= max(0.15, 1.0 - amt)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, fly, head, abd = rig.root, rig.n("fly"), rig.n("head"), rig.n("abd")
    if stage == 4:
        _atroz_pose(rig, anim, i, n)
    _show_flash = False
    rig.n("flash").scale = (0.0001,) * 3
    if anim == "idle":
        fly.location.z += 0.05 * math.sin(math.tau * t)
        R.squash(fly, 1.0 + 0.05 * math.sin(math.tau * t + 1.0), anchored=False)
        _wings(rig, i * 0.5 + 0.25)  # asa sobe e desce a cada quadro
        lv = [0, 1, 2, 2, 1, 0, 0, 1][i]
        _lamp(rig, lv)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"ant{nm}").rotation_euler.x = 0.15 * math.sin(math.tau * t + (0 if sg > 0 else 0.6))
        abd.rotation_euler.x = 0.08 * math.sin(math.tau * t)
        if i == 5:
            _blink(rig, 1.0)
        _motes(rig, t)
    elif anim == "walk":
        fly.location.z += 0.06 * math.sin(math.tau * 2 * t)
        fly.rotation_euler.x = 0.18
        R.squash(fly, 1.0 + 0.06 * math.sin(math.tau * 2 * t), anchored=False)
        _wings(rig, i * 0.5 + 0.25, amp=0.85)
        _lamp(rig, [1, 2, 1, 0, 1, 2, 1, 0][i])
        abd.rotation_euler.x = -0.1 + 0.1 * math.sin(math.tau * 2 * t)
        head.rotation_euler.x += -0.05
        _motes(rig, t)
    elif anim == "attack":
        # 0-1 recolhe o abdomen (carregando), 2-4 estica e dispara um clarao, 5-7 volta
        curl = [0.35, 0.6, -0.5, -0.65, -0.55, -0.2, 0.05, 0.0][i]
        abd.rotation_euler.x = curl
        R.squash(fly, [0.85, 0.78, 1.2, 1.12, 1.0, 0.95, 1.0, 1.0][i], anchored=False)
        fly.location.z += [0.0, -0.04, 0.05, 0.06, 0.04, 0.02, 0.0, 0.0][i]
        fly.rotation_euler.x = [-0.15, -0.25, 0.3, 0.35, 0.25, 0.1, 0.0, 0.0][i]
        _wings(rig, i * 0.5 + 0.25, amp=0.9 if i >= 2 else 0.4, rest=0.35 if i in (2, 3, 4) else 0.1)
        _lamp(rig, [1, 2, 2, 2, 2, 1, 1, 1][i])
        if i in (2, 3, 4):
            s = [0.55, 1.0, 0.7][i - 2]
            rig.n("flash").scale = (s,) * 3
        if i in (1, 2, 3):
            for nm in ("L", "R"):
                rig.n(f"eye{nm}").scale.z *= 0.75
        _motes(rig, t, spread=[1.0, 0.8, 1.3, 1.5, 1.4, 1.2, 1.1, 1.0][i])
    elif anim == "hit":
        R.squash(fly, [0.75, 1.18, 0.95, 1.02][i], anchored=False)
        fly.rotation_euler.x = [-0.35, 0.15, -0.05, 0][i]
        fly.location.z += [-0.06, 0.03, 0.0, 0.0][i]
        _wings(rig, 0.25, amp=[0.9, 0.2, 0.6, 0.4][i], rest=0.4 if i == 0 else 0.1)
        _lamp(rig, [0, 2, 0, 1][i])
        if i < 2:
            _blink(rig, 1.0)
        _motes(rig, 0.03 * i, spread=1.2)
    elif anim == "death":
        # tonto: gira, asas param, cai rodopiando, bate no chao de barriga para cima, luz se apaga
        drop = [0.0, 0.05, 0.15, 0.3, 0.45, 0.5, 0.5, 0.5][i]
        fly.location.z -= drop
        fly.rotation_euler.z = [0, 0.6, 1.4, 2.4, 3.14, 3.14, 3.14, 3.14][i]
        roll = [0, 0.2, 0.6, 1.4, 2.6, 3.0, 3.1, 3.14][i]
        fly.rotation_euler.y = roll
        fly.location.z += 0.12 * math.sin(roll) if i >= 3 else 0.0
        R.squash(fly, [0.8, 1.15, 1.05, 1.0, 0.8, 1.06, 0.97, 1.0][i], anchored=False)
        _wings(rig, 0.25, amp=[0.8, 0.6, 0.4, 0.2, 0.0, 0.0, 0.0, 0.0][i], rest=[0.1, 0.2, 0.3, 0.4, -0.3, -0.35, -0.35, -0.35][i])
        _lamp(rig, [2, 1, 2, 0, 1, 0, -1, -1][i])
        _blink(rig, 1.0)
        for k, (nm, a0, z0, r0) in enumerate(rig.motes):
            rig.n(nm).scale = (max(0.0001, 1 - i / 4),) * 3
        _motes(rig, t, spread=1 + 0.3 * t)
