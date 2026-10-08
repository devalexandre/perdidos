"""Boiuna Atroz (story_boiuna) — chefe da historia do Arco 1, capitulo 9 (abismo do rio do Arraial do Sumidouro).
A Cobra Grande negra dos rios e tempestades, corrompida por Erevos; so existe na forma atroz (estagio 4, a noite).
Le diferente das serpentes comuns (cinder/river/crystal, que sao enroladas e cheias de espinhos): corpo liso e
lustroso preto-azulado com placas da barriga claras, pescoco alto em S erguido acima das voltas no chao, cabecona
chibi larga com olhos de lanterna de barco (amarelos acesos, aro de latao, pupila em fenda), sobrancelhas de escama,
presas; uma nuvem de tempestade particular por cima dela, que chove e solta raios; e o fogo negro da corrupcao
(pontas violeta) correndo pela crista das costas.
  idle: o pescoco ondula, chove da nuvem, a lingua bifurcada sai; walk: as voltas deslizam em onda;
  attack: recua o pescoco, um raio cai na frente e ela da o bote de boca aberta;
  hit: encolhe, olhos apertados; death: o fogo e a nuvem se desfazem e a cabeca deita sobre as voltas.
Modelo proprio por script; olhos no desenho do Tatu-Pedra (sol_common) com iris de lanterna."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_common_l2 as C

SCALE = {4: 2.5}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 6.0
HEAD_TILT = -0.55

NECK = [(0.0, -0.2, 0.12), (0.0, -0.26, 0.32), (0.0, -0.22, 0.52), (0.0, -0.12, 0.7), (0.0, -0.08, 0.86),
        (0.0, -0.13, 1.0)]
NECK_R = [0.17, 0.165, 0.155, 0.145, 0.135, 0.125]
HC = Vector((0.0, -0.2, 1.12))
HR = (0.3, 0.26, 0.2)
CLOUD = Vector((0.0, 0.14, 1.48))


def _coil_pts():
    """Voltas no chao: da base do pescoco (frente) gira pela esquerda, por tras, pela direita e termina na frente."""
    pts, rad = [], []
    n = 11
    for k in range(n):
        u = k / (n - 1)
        a = -math.pi / 2 - 0.25 - u * (math.tau - 0.7)   # comeca na frente, gira no sentido horario (visto de cima)
        r = 0.4 - 0.1 * u
        pts.append((r * math.cos(a) * 1.08, 0.12 + r * math.sin(a) * 0.9, 0.15 - 0.07 * u))
        rad.append(0.17 - 0.12 * u ** 1.4)
    return pts, rad


def build(stage):
    if stage not in STAGES:
        raise ValueError("so a forma atroz (4)")
    R.reset()
    R.CUR["reach"] = (0.5, 0.5, 0.5)
    rig = R.Rig("story_boiuna")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", (0, 0.0, 0.1), root)
    # ---- voltas no chao (cauda) e pescoco erguido
    cp, cr = _coil_pts()
    rig.coil = C.chain(rig, "coil", cp, cr, body, "boiuna_l2")
    # placas da barriga visiveis por fora das voltas (faixa clara rente ao chao)
    for i in range(len(cp) - 2):
        a, b = Vector(cp[i]), Vector(cp[i + 1])
        m = (a + b) * 0.5
        out = Vector((m.x, m.y - 0.12, 0)).normalized()
        rr = (cr[i] + cr[i + 1]) * 0.5
        d = (b - a).normalized()
        from mathutils import Matrix
        x = d; y = out; z = x.cross(y).normalized()
        M = Matrix((x, y, z)).transposed()
        rig.add_mesh(R.ellipsoid(f"cbelly{i}", m + out * rr * 0.72 + Vector((0, 0, -rr * 0.35)),
                                 ((b - a).length * 0.48, rr * 0.35, rr * 0.45), rot=M.to_euler()), f"cbelly{i}",
                     "boiuna_belly_l2", rig.n(rig.coil[i]))
    rig.neck = C.chain(rig, "neck", NECK, NECK_R, body, "boiuna_l2", belly=(0, -1, 0.15), belly_mat="boiuna_belly_l2")
    # crista de fogo negro pelas costas do pescoco e das voltas
    for i in (1, 3):
        a, b = Vector(NECK[i]), Vector(NECK[i + 1])
        m = (a + b) * 0.5 + Vector((0, NECK_R[i] * 0.85, 0.0))
        C.black_flame(rig, f"nfl{i}", m, (0, 1.0, 0.7), 0.3, 0.075, rig.n(rig.neck[i]), phase=0.17 * i, bend=0.3)
    for i in (2, 5, 8):
        a = Vector(cp[i])
        C.black_flame(rig, f"cfl{i}", a + Vector((0, 0, cr[i] * 0.8)), (a.x * 0.6, (a.y - 0.12) * 0.6, 1.0), 0.32, 0.08,
                      rig.n(rig.coil[i]), phase=0.13 * i + 0.3, bend=0.4 if a.x > 0 else -0.4)
    # ---- cabecona chibi larga no topo do pescoco
    top = rig.n(rig.neck[-1])
    head = rig.empty("head", Vector(NECK[-1]) + Vector((0, 0, 0.04)), top)
    rig.add_mesh(R.ellipsoid("head", HC, HR, seg=28, rings=16), "head", "boiuna_l2", head, group="head")
    # focinho achatado e queixo claro
    rig.add_mesh(R.ellipsoid("snout", HC + Vector((0, -0.17, -0.04)), (0.2, 0.13, 0.12)), "head", "boiuna_l2", head,
                 group="head")
    jaw = rig.empty("jaw", HC + Vector((0, 0.05, -0.1)), head)
    rig.add_mesh(R.ellipsoid("jawm", HC + Vector((0, -0.1, -0.13)), (0.22, 0.17, 0.07)), "jaw", "boiuna_belly_l2", jaw)
    rig.add_mesh(R.ellipsoid("mouthin", HC + Vector((0, -0.12, -0.1)), (0.18, 0.13, 0.04)), "mouthin", "mouth_in", jaw,
                 noline=True, unlit=True, prio=0.9)
    tongue = rig.empty("tongue", HC + Vector((0, -0.2, -0.11)), jaw)
    tb = HC + Vector((0, -0.2, -0.11))
    for sx in (1, -1):
        rig.add_mesh(R.cone(f"tongue{sx}", tb, tb + Vector((0.035 * sx, -0.13, -0.02)), 0.014, 0.004, seg=6, rings=2,
                            bend=(0.01 * sx, 0, 0)), "tongue", "tongue", tongue, noline=True, prio=2.5)
    rig.add_mesh(R.cone("tongue0", tb + Vector((0, 0.05, 0)), tb, 0.018, 0.014, seg=6, rings=1), "tongue", "tongue", tongue,
                 noline=True, prio=2.5)
    for sx in (1, -1):  # presas que aparecem na boca
        b = HC + Vector((0.09 * sx, -0.27, -0.09))
        rig.add_mesh(R.cone(f"fang{sx}", b, b + Vector((0.0, -0.01, -0.07)), 0.022, 0.003, seg=6, rings=2), "fang", "fang_n",
                     head, noline=True, prio=2.6)
    for sx in (1, -1):  # narinas
        rig.add_mesh(R.ellipsoid(f"nost{sx}", HC + Vector((0.05 * sx, -0.29, 0.02)), (0.016, 0.01, 0.012)), "nost",
                     "brow_n", head, noline=True, unlit=True, prio=2.0)
    # olhos de lanterna de barco: aro de latao, vidro amarelo aceso, pupila em fenda, brilhos
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.14 * sx, HC.z + 0.05
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.004, ez))
        e = rig.empty(f"eye{nm}", ep, head)
        rx, rz = 0.1, 0.12
        rig.add_mesh(S.torus(f"ering{nm}", ep, rx * 1.02, 0.02, rot=(math.pi / 2 - 0.45, 0, -0.45 * sx), nu=20, nv=6),
                     f"ering{nm}", "gold_n", e, prio=2.0)
        rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (rx, 0.045, rz), rot=(0.45, 0, -0.45 * sx)), f"eye{nm}", "lantern_eye_l2", e,
                     noline=True, unlit=True, prio=1.8)
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0, -0.03, -0.02)), (rx * 0.62, 0.03, rz * 0.62),
                                 rot=(0.45, 0, -0.45 * sx)), f"iris{nm}", "ember_hot", e, noline=True, unlit=True, prio=2.2)
        rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0, -0.05, -0.02)), (0.016, 0.02, rz * 0.55),
                                 rot=(0.45, 0, -0.45 * sx)), f"slit{nm}", "eye_slit", e, noline=True, unlit=True, prio=4.0)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.035 + 0.01 * sx, -0.06, 0.045)), (0.032, 0.016, 0.032)),
                     f"hl{nm}", "white", e, noline=True, unlit=True, prio=7.0)
        rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.035, -0.06, -0.05)), (0.016, 0.01, 0.016)), f"hl2{nm}", "white", e,
                     noline=True, unlit=True, prio=3.0)
        # sobrancelha de escama grossa, brava
        a = ep + Vector((-0.1 * sx, -0.05, 0.085))
        b = ep + Vector((0.12 * sx, 0.04, 0.15))
        rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.035, 0.026, seg=8, rings=1), f"brow{nm}", "boiuna_belly_l2", head, prio=3.2)
    # chifrinhos de escama atras dos olhos (silhueta de cobra-grande, sem virar dragao)
    for sx in (1, -1):
        b = HC + Vector((0.2 * sx, 0.12, 0.08))
        rig.add_mesh(R.cone(f"scal{sx}", b, b + Vector((0.12 * sx, 0.12, 0.06)), 0.05, 0.006, seg=7, rings=2,
                            bend=(0, 0, 0.02)), "scal", "boiuna_l2", head)
    head.rotation_euler.x += HEAD_TILT
    # ---- nuvem de tempestade particular: chove e solta raios
    cloud = rig.empty("cloud", CLOUD, root)
    for k, (dx, dy, dz, r) in enumerate(((0, 0, 0, 0.17), (0.17, 0.02, -0.03, 0.13), (-0.17, 0.03, -0.02, 0.14),
                                          (0.08, -0.06, 0.07, 0.12), (-0.09, 0.08, 0.08, 0.11), (0.28, 0.05, -0.06, 0.08),
                                          (-0.28, 0.06, -0.05, 0.09))):
        rig.add_mesh(R.ellipsoid(f"cl{k}", CLOUD + Vector((dx, dy, dz)), (r * 1.25, r, r * 0.8)), "cloud", "cloud_n", cloud,
                     group="cloud")
    C.black_flame(rig, "clfl", CLOUD + Vector((0.0, 0.04, 0.08)), (0, 0, 1), 0.15, 0.07, cloud, phase=0.5, bend=0.3)
    C.bolt(rig, "bolt_s", CLOUD + Vector((0.18, -0.05, -0.1)), CLOUD + Vector((0.3, -0.1, -0.5)), cloud, w=0.02, n=3,
           jag=0.05)
    C.bolt(rig, "bolt", CLOUD + Vector((0.0, -0.15, -0.08)), Vector((0.0, -0.75, 0.02)), root, w=0.035, n=6, jag=0.1)
    S.add_motes(rig, "rain", [CLOUD + Vector((-0.32 + 0.64 * ((k * 0.37) % 1.0), -0.05 + 0.1 * (k % 3), -0.1))
                              for k in range(10)], ["drop", "drop2", "cold"], size=0.018, parent=cloud)
    S.add_motes(rig, "spark", [(0, -0.75, 0.05)] * 8, ["bolt", "bolt2", "cold_hot"], size=0.03, parent=root)
    rig.save_rest()
    for nm in ("bolt", "bolt_s"):
        rig.n(nm).scale = (0.0001,) * 3
    rig.n("tongue").scale = (0.0001,) * 3
    S.hide_motes(rig, "spark")
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _rain(rig, t, k=1.0):
    """Gotas caem da nuvem (loop): sobem no indice do ciclo ao contrario."""
    for j, (node, ph) in enumerate(rig.motes["rain"]):
        u = (t * 2 + ph) % 1.0
        o = rig.n(node)
        base = rig.rest[node][0]
        o.location = base + Vector((0.03 * u, 0, -0.75 * u))
        s = max(0.0001, k * (1.0 if u < 0.8 else (1 - u) * 5))
        o.scale = (s * 0.7, s * 0.7, s * 1.6)


def _mouth(rig, o):
    rig.n("jaw").rotation_euler.x += 0.55 * o


def _tongue(rig, out):
    tg = rig.n("tongue")
    if out <= 0.02:
        tg.scale = (0.0001,) * 3
    else:
        tg.scale = (1.0, out, 1.0)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    cloud = rig.n("cloud")
    if anim == "idle":
        C.chain_wave(rig, rig.neck, t, 0.06, axis="y", phase_step=0.8)
        C.chain_wave(rig, rig.neck, t + 0.25, 0.03, axis="x", phase_step=0.6)
        C.chain_wave(rig, rig.coil, t, 0.025, axis="z", phase_step=0.9, start=2)
        head.rotation_euler.y += 0.08 * math.sin(math.tau * t + 0.8)
        _tongue(rig, [0, 0, 0.6, 1.0, 0.5, 0, 0, 0][i])
        _mouth(rig, [0, 0, 0.15, 0.2, 0.1, 0, 0, 0][i])
        cloud.location.z += 0.03 * math.sin(math.tau * t)
        cloud.location.x += 0.03 * math.sin(math.tau * t + 1.0)
        _rain(rig, t)
        if i == 5:
            rig.n("bolt_s").scale = (1.0, 1.0, 1.0)
        C.flames(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
    elif anim == "walk":
        C.chain_wave(rig, rig.coil, t, 0.1, axis="z", phase_step=0.9, start=1)
        C.chain_wave(rig, rig.neck, t, 0.1, axis="y", phase_step=0.8)
        body.location.z += 0.02 * abs(math.sin(math.tau * t))
        head.rotation_euler.y -= 0.06 * math.sin(math.tau * t)
        cloud.location.x += 0.05 * math.sin(math.tau * t)
        _rain(rig, t)
        C.flames(rig, t, sway=0.25)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        C.chain_bend(rig, rig.neck, [-0.07, 0.025, 0.01, 0.0][i], axis="x")
        R.squash(body, [0.88, 1.06, 0.98, 1.0][i])
        S.blink(rig, [0.9, 0.6, 0.0, 0.0][i])
        _mouth(rig, [0.6, 0.3, 0.1, 0.0][i])
        head.rotation_euler.x += [-0.25, 0.06, 0.0, 0.0][i]
        cloud.scale = (1.0 + [0.15, 0.05, 0, 0][i],) * 3
        _rain(rig, i / 4.0)
        C.flames(rig, i / 4.0, k=[1.2, 1.05, 1.0, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Recua o pescoco (S apertado), o raio cai na frente, e ela da o bote de boca aberta."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    back = [0.08, 0.14, 0.16, -0.12, -0.16, -0.1, -0.04, 0.0][i]
    C.chain_bend(rig, rig.neck, back, axis="x", start=1)
    head.rotation_euler.x += [-0.1, -0.15, -0.15, 0.25, 0.3, 0.2, 0.08, 0.0][i]
    _mouth(rig, [0.2, 0.4, 0.5, 1.0, 1.0, 0.7, 0.3, 0.1][i])
    _tongue(rig, [0, 0.5, 0.8, 0, 0, 0, 0, 0][i])
    R.squash(body, [1.03, 1.06, 1.08, 0.94, 0.95, 1.0, 1.0, 1.0][i])
    if i in (2, 3, 4):
        bolt = rig.n("bolt")
        bolt.scale = (1.0, 1.0, 1.0) if i != 4 else (0.8, 0.8, 0.8)
    S.splash(rig, "spark", [0, 0, 0, 0.12, 0.28, 0.44, 0.6, 0][i], Vector((0, -0.75, 0.05)),
             [(0.7 * math.cos(math.pi * k / 7), -0.2 + 0.4 * math.sin(math.pi * k / 7), 1.0 + 0.2 * (k % 2)) for k in range(8)],
             g=4.0, shrink=0.8, floor=0.05)
    cloud = rig.n("cloud")
    cloud.scale = (1.0 + [0.0, 0.03, 0.06, 0.1, 0.07, 0.04, 0.02, 0.0][i],) * 3
    _rain(rig, i / 8, 1.3)
    C.flames(rig, i / 8, k=[1.1, 1.2, 1.3, 1.4, 1.35, 1.2, 1.1, 1.0][i])


def _death(rig, i):
    """O fogo negro e a nuvem se desfazem; o pescoco amolece e a cabeca deita sobre as voltas, olhos fechados."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    C.flames(rig, i / 8, k=[1.2, 0.9, 0.6, 0.35, 0.15, 0.0, 0.0, 0.0][i])
    cloud = rig.n("cloud")
    cs = [1.1, 1.0, 0.8, 0.55, 0.3, 0.1, 0.0001, 0.0001][i]
    cloud.scale = (cs, cs, cs)
    _rain(rig, i / 8, max(0.0001, 1.0 - i / 4))
    fall = [0.0, -0.05, 0.15, 0.36, 0.52, 0.6, 0.57, 0.58][i]
    for j, nm in enumerate(rig.neck[:-1]):
        rig.n(nm).rotation_euler.x += fall * (0.15 + 0.08 * j)
    head.rotation_euler.x += [0.2, 0.1, 0.1, 0.2, 0.3, 0.35, 0.35, 0.35][i]
    R.squash(body, [0.88, 1.04, 0.98, 0.96, 0.95, 0.98, 0.97, 0.97][i])
    S.blink(rig, [0.9, 0.5, 0.7, 0.9, 1.0, 1.0, 1.0, 1.0][i])
    _mouth(rig, [0.7, 0.4, 0.5, 0.3, 0.15, 0.1, 0.1, 0.1][i])
