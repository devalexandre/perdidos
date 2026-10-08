"""Iara Atroz (story_iara) — chefe da historia do Arco 1, capitulo 6 (rio da Cidade Perdida de Z).
Sereia de rio (agua doce, Amazonia) corrompida por Erevos: so existe na forma atroz (estagio 4, a noite).
Chibi, sem sensualizacao: corpete de escamas fechado ate o pescoco com conchas douradas. Sentada numa pedra de rio
dentro de uma poca simples: a cauda de peixe de rio (escamas em meia-lua) desce pela frente da pedra e se deita na
agua, com a nadadeira caudal em leque erguida de frente para a camera; cabelo verde-escuro comprido deitado na pedra,
mechas da frente com a ponta em fogo negro (pontas violeta, a corrupcao), tambem nas pontas da nadadeira;
barbatanas nas orelhas, pente de madreperola no cabelo (o pente que ela deixa ao ser vencida), olhos violeta.
  idle: canta baixinho (boca abre e fecha, notas boiando), cabelo e nadadeira ondulam;
  walk: desliza com a agua (cauda em onda);
  attack: puxa o ar, inclina para a frente e solta o canto (aneis de som e notas de agua saindo da boca);
  hit: recua, olhos apertados, cabelo voa;
  death: o fogo negro apaga e ela deita de lado sobre a pedra, olhos fechados (volta ao fundo do rio, nao morre).
Modelo proprio por script; rosto no desenho do Tatu-Pedra / piloto do Sol (sol_common.eye/brow)."""
import math
from mathutils import Vector, Matrix
import mon_rig as R
import sol_common as S
import story_common_l2 as C

SCALE = {4: 2.6}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 8.0
HEAD_TILT = -0.4

HC = Vector((0, -0.04, 0.88))
HR = (0.25, 0.21, 0.23)
BC = Vector((0, 0.0, 0.52))
BR = (0.14, 0.11, 0.15)
MOUTH = HC + Vector((0, -0.2, -0.13))
LIFT = 0.24                                 # ela fica sentada na pedra: o corpo (pivo body) sobe LIFT
MOUTH_W = MOUTH + Vector((0, 0, LIFT))      # boca nas coordenadas do root (notas e aneis de som)


def build(stage):
    if stage not in STAGES:
        raise ValueError("so a forma atroz (4)")
    R.reset()
    R.CUR["reach"] = (0.35, 0.3, 0.4)
    rig = R.Rig("story_iara")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # ---- poca simples de agua escura do rio com uma ondinha clara, e a pedra de rio onde ela senta
    pond = rig.empty("pond", (0.05, -0.02, 0.0), root)
    rig.add_mesh(R.ellipsoid("pond", (0.05, -0.04, 0.006), (0.56, 0.42, 0.006), seg=40), "pond", "kappa_skin_n", pond,
                 noline=True, prio=0.8)
    rig.add_mesh(S.torus("ripple", (0.05, -0.04, 0.012), 0.47, 0.01, nu=40, yscale=0.36 / 0.47), "ripple", "cold", pond,
                 unlit=True, noline=True, prio=1.0)
    rock = rig.empty("rock", (0, 0.12, 0.0), root)
    rig.add_mesh(R.ellipsoid("rock", (0, 0.14, 0.24), (0.36, 0.3, 0.27), seg=20, rings=12), "rock", "basalt_n", rock)
    rig.add_mesh(R.ellipsoid("rock2", (-0.3, 0.02, 0.07), (0.13, 0.11, 0.08), seg=14, rings=8), "rock2", "basalt_n", rock)
    rig.add_mesh(R.ellipsoid("rock3", (0.27, 0.26, 0.08), (0.12, 0.1, 0.09), seg=14, rings=8), "rock3", "basalt_n", rock)
    rig.add_mesh(R.ellipsoid("rmoss", (-0.18, 0.26, 0.42), (0.13, 0.1, 0.05), rot=(0.5, -0.4, 0)), "rmoss", "moss_n", rock)
    body = rig.empty("body", (0, 0.04, 0.36), root)
    # ---- cauda de peixe de rio: sai do quadril, desce pela frente da pedra e se deita na agua para a direita;
    # escamas em meia-lua, nadadeira caudal em leque erguida de frente para a camera
    hip = LIFT
    pts = [(0, 0.03, 0.38 + hip), (0.02, -0.1, 0.33 + hip), (0.06, -0.2, 0.42), (0.1, -0.27, 0.27), (0.17, -0.31, 0.13),
           (0.28, -0.31, 0.065), (0.37, -0.25, 0.065), (0.43, -0.17, 0.1)]
    rad = [0.14, 0.135, 0.125, 0.115, 0.1, 0.085, 0.068, 0.05]
    rig.tail = C.chain(rig, "tail", pts, rad, root, "iara_scale_l2", group="tail")
    for i in range(len(pts) - 1):   # escamas em meia-lua (2 fileiras por segmento, viradas para cima/camera)
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        d = (b - a).normalized()
        o = (Vector((0, -0.6, 1.0)) - d * Vector((0, -0.6, 1.0)).dot(d)).normalized()
        sd = d.cross(o).normalized()
        rr = (rad[i] + rad[i + 1]) * 0.5
        for k, (u, w) in enumerate(((0.2, -0.5), (0.2, 0.5), (0.55, -0.9), (0.55, 0.0), (0.55, 0.9), (0.9, -0.5),
                                    (0.9, 0.5))):
            q = a + (b - a) * u
            n = (o * math.cos(w) + sd * math.sin(w)).normalized()
            c = q + n * rr * 0.99
            M = Matrix((sd, d, n)).transposed()
            rig.add_mesh(R.ellipsoid(f"scale{i}{k}", c, (rr * 0.34, rr * 0.26, rr * 0.1), rot=M.to_euler()), "tscale",
                         "iara_scale_l2", rig.n(rig.tail[i]), prio=1.2)   # mesma cor: so o contorno desenha a escama
    end = rig.n(rig.tail[-1])
    ep = Vector(pts[-1])
    fin = rig.empty("fin", ep, end)
    camf = Vector((0, 0.57, -0.82))
    d0 = Vector((0.62, 0.62, 0.43)).normalized()
    d0 = (d0 - camf * d0.dot(camf)).normalized()        # no plano de frente para a camera
    s0 = camf.cross(d0).normalized()

    def ffn(u, v):
        th = -0.7 + 1.4 * u
        r = 0.03 + v * 0.3 * (0.55 + 0.45 * abs(th) / 0.7)   # nadadeira caudal em leque com entalhe no meio
        return ep + (d0 * math.cos(th) + s0 * math.sin(th)) * r
    rig.add_mesh(R.surface("fin", ffn, 24, 6, ep - camf * 0.3), "fin", "wing_n", fin)
    for k in range(7):
        th = -0.62 + 1.24 * k / 6
        dd = d0 * math.cos(th) + s0 * math.sin(th)
        ln = 0.3 * (0.55 + 0.45 * abs(th) / 0.7) - 0.02
        rig.add_mesh(R.cone(f"finr{k}", ep + dd * 0.04 - camf * 0.01, ep + dd * ln - camf * 0.01, 0.008, 0.004, seg=5,
                            rings=1), "finray", "pale_n", fin, noline=True, unlit=True, prio=1.6)
    for k, th in enumerate((-0.66, 0.66)):
        dd = d0 * math.cos(th) + s0 * math.sin(th)
        ln = 0.3 * (0.55 + 0.45 * abs(th) / 0.7)
        C.black_flame(rig, f"ffl{k}", ep + dd * ln * 0.9, dd * 0.3 + Vector((0, 0, 0.8)), 0.13, 0.04, fin, phase=0.4 * k,
                      bend=0.3 if k else -0.3)
    # babado de barbatanas na cintura (esconde a juncao do corpete com a cauda)
    for k in range(10):
        a = math.tau * k / 10
        p = Vector((0.15 * math.cos(a), 0.035 + 0.125 * math.sin(a), 0.42))
        d = Vector((0.6 * math.cos(a), 0.5 * math.sin(a), -1.0)).normalized()
        rig.add_mesh(R.ellipsoid(f"frill{k}", p + d * 0.05, (0.055, 0.03, 0.075), rot=S.align(d)), "frill", "iara_scale_l2", body,
                     group="frill")
    # ---- corpete de conchas fechado (gola alta) e bracos
    rig.add_mesh(R.ellipsoid("torso", BC, BR), "torso", "iara_scale_l2", body, group="torso")
    for k, (x, z, s) in enumerate(((-0.06, 0.55, 0.06), (0.06, 0.55, 0.06), (0.0, 0.47, 0.065))):
        y = S.ysurf(BC, BR, x, z) + 0.01
        rig.add_mesh(R.ellipsoid(f"shell{k}", (x, y, z), (s, 0.022, s * 0.85), rot=(0.3, 0, 0)), f"shell{k}", "gold_n", body)
        for j in (-1, 0, 1):  # sulcos da concha
            rig.add_mesh(R.cone(f"shr{k}{j}", (x, y - 0.018, z - s * 0.6), (x + j * s * 0.6, y - 0.022, z + s * 0.55), 0.005,
                                0.004, seg=4, rings=1), "shellridge", "thorn_n", body, noline=True, unlit=True)
    rig.add_mesh(S.torus("collar", (0, -0.005, 0.655), 0.085, 0.022, nu=20, squash=1.0, yscale=0.85), "collar", "gold_n",
                 body)
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.13 * sx, -0.0, 0.6))
        arm = rig.empty(f"arm{nm}", sp, body)
        hp = sp + Vector((0.07 * sx, -0.07, -0.16))
        rig.add_mesh(R.ellipsoid(f"puff{nm}", sp, (0.06, 0.055, 0.05)), f"puff{nm}", "pale_n", arm, group=f"arm{nm}")
        rig.add_mesh(R.cone(f"arm{nm}", sp, hp, 0.04, 0.033, seg=10, rings=2), f"arm{nm}", "moon_skin_l2", arm, group=f"arm{nm}")
        rig.add_mesh(R.ellipsoid(f"hand{nm}", hp + Vector((0, -0.01, -0.02)), (0.045, 0.04, 0.05)), f"hand{nm}", "moon_skin_l2",
                     arm, group=f"arm{nm}")
        rig.add_mesh(S.torus(f"cuff{nm}", sp + (hp - sp) * 0.8, 0.036, 0.011, rot=S.align(hp - sp), nu=14), f"cuff{nm}",
                     "gold_n", arm)
    # ---- cabeca chibi
    head = rig.empty("head", (0, -0.01, 0.66), body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "moon_skin_l2", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.108 * sx, HC.z - 0.01
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.012, ez))
        S.eye(rig, nm, ep, head, 0.092, 0.138, -0.42 * sx, mode="normal", iris="wisp_v")
        k = 0.135 / 0.145
        S.brow(rig, nm, ep, head, k, 0.06, mat="brow_n", thick=1.0, width=0.9, lift=-0.01, prio=3.0)
    jaw = rig.empty("jaw", MOUTH, head)
    rig.add_mesh(R.ellipsoid("mouth", MOUTH, (0.035, 0.02, 0.022)), "mouth", "mouth_in", jaw, noline=True, unlit=True,
                 prio=2.5)
    # barbatanas no lugar das orelhas
    for sx, nm in ((1, "L"), (-1, "R")):
        b = HC + Vector((0.22 * sx, 0.02, 0.05))
        ear = rig.empty(f"ear{nm}", b, head)
        for j, (dz, ln) in enumerate(((0.09, 0.16), (0.0, 0.14), (-0.08, 0.1))):
            rig.add_mesh(R.cone(f"ear{nm}{j}", b, b + Vector((0.13 * sx, 0.05, dz + 0.04)).normalized() * ln, 0.035, 0.006,
                                seg=6, rings=2), f"ear{nm}", "wing_n", ear, group=f"ear{nm}")
    # cabelo: capa com franja aberta no rosto + volume atras + mechas compridas ate a agua
    hairp = rig.empty("hair", HC, head)

    def edge(ph):
        fr = S.front_off(ph) < 0.9
        return S.bob(ph, 0.62, 2.2, open_=0.75, ramp=0.7) + S.zigzag(ph + 0.1, 16, 0.1 if fr else 0.16)
    rig.add_mesh(S.cap("hair", HC, HR, 0.0, edge, lift=1.07, nv=8), "hair", "iara_hair_l2", hairp)
    rig.add_mesh(R.ellipsoid("hairback", HC + Vector((0, 0.1, -0.08)), (0.27, 0.17, 0.24)), "hairback", "iara_hair_l2",
                 hairp)
    # cabelo comprido: um manto de cabelo preso atras da cabeca (ja inclinada) que desce ate o chao e se abre atras da
    # cauda, borda de mechas em zigue-zague; fica no pivo "mane" do corpo (a inclinacao da cabeca nao o empurra)
    neck = Vector((0, -0.01, 0.66))
    Rx = Matrix.Rotation(HEAD_TILT, 3, "X")

    def hrot(p):
        return neck + Rx @ (Vector(p) - neck)
    mane = rig.empty("mane", hrot(HC + Vector((0, 0.12, 0))), body)
    # 7 mechas largas (pecas separadas = linhas de mecha entre elas) da nuca ate o chao, abertas em leque atras da cauda
    for j in range(7):
        a = -1.55 + 3.1 * j / 6
        top = hrot(HC + Vector((math.sin(a) * HR[0] * 0.8, math.cos(a) * HR[1] * 0.85 + 0.03, 0.02)))
        bot = Vector((math.sin(a) * 0.34, 0.2 + math.cos(a) * 0.2, 0.2 + 0.03 * (j % 2)))   # deita na pedra
        out = Vector((math.sin(a), math.cos(a) * 0.7, 0)).normalized()
        rig.add_mesh(R.cone(f"strand{j}", top, bot, 0.1, 0.01, seg=10, rings=6, bend=out * 0.1), f"strand{j}",
                     "iara_hair_l2", mane, group="mane")
    rig.locks = ["mane"]
    # mechas laterais (de tras das orelhas ate a cintura), emolduram o rosto sem cobri-lo; pontas em fogo negro
    for j, sx in enumerate((1, -1)):
        a = hrot(HC + Vector((0.2 * sx, 0.05, -0.08)))
        tip = Vector((0.3 * sx, -0.02, 0.4))
        lk = rig.empty(f"lock{j}", a, body)
        rig.add_mesh(R.cone(f"lock{j}", a, tip, 0.075, 0.04, seg=10, rings=5, bend=(0.05 * sx, -0.02, 0.0)), f"lock{j}",
                     "iara_hair_l2", lk)
        C.black_flame(rig, f"hfl{j}", tip + Vector((0.02 * sx, -0.02, -0.03)), (0.35 * sx, -0.1, 1.0), 0.2, 0.045, lk,
                      phase=0.3 * j)
    # pente de madreperola com golfinho (fragmento de Maria) preso do lado esquerdo
    cp = HC + Vector((0.15, -0.04, 0.19))
    rig.add_mesh(R.ellipsoid("comb", cp, (0.06, 0.02, 0.035), rot=(0.4, 0.5, 0)), "comb", "horn_n", hairp, prio=2.0)
    rig.add_mesh(R.ellipsoid("combd", cp + Vector((0.0, -0.022, 0.005)), (0.025, 0.008, 0.012), rot=(0.4, 0.5, 0.3)),
                 "combd", "wisp_c2", hairp, noline=True, unlit=True, prio=3.0)
    head.rotation_euler.x += HEAD_TILT
    # ---- particulas: gotas de luz fria subindo, 2 notas boiando, notas/aneis do canto, respingo
    S.add_motes(rig, "rise", [(0.05 + 0.45 * math.cos(k * 1.9), -0.04 + 0.34 * math.sin(k * 1.9), 0.03) for k in range(7)],
                ["cold_hot", "wisp_v", "cold"], size=0.022, parent=root)
    rig.hum = []
    for j, p in enumerate(((0.42, -0.05, 1.05 + LIFT), (-0.4, 0.0, 0.92 + LIFT))):
        C.note(rig, f"hum{j}", p, root, mat="cold_hot" if j == 0 else "wisp_v", k=0.85, double=j == 1)
        rig.hum.append(f"hum{j}")
    rig.sing = []
    for j in range(3):
        C.sound_ring(rig, f"ring{j}", MOUTH_W + Vector((0, -0.06, 0)), root, 0.11, mat="cold_hot" if j % 2 == 0 else "cold")
        rig.sing.append(f"ring{j}")
    rig.notes = []
    for j in range(4):
        C.note(rig, f"note{j}", MOUTH_W + Vector((0, -0.08, 0)), root, mat=("cold_hot", "wisp_v", "cold", "wisp_v")[j], k=0.9,
               double=j % 2 == 1)
        rig.notes.append(f"note{j}")
    S.add_motes(rig, "drop", [(0, 0, 0.5)] * 7, ["drop", "drop2", "cold"], size=0.024, parent=root)
    body.location.z += LIFT   # sentada na pedra
    rig.save_rest()
    for nm in rig.sing + rig.notes:
        rig.n(nm).scale = (0.0001,) * 3
    S.hide_motes(rig, "drop")
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _arms(rig, ax, az=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax
        a.rotation_euler.y += -az * sg


def _mouth(rig, o):
    m = rig.n("jaw")
    m.scale = (1.0 + 0.4 * o, 1.0, 0.6 + 1.9 * o)


def _hair(rig, t, amp=1.0, lift=0.0):
    """Manto de cabelo balanca devagar; mechas da frente balancam para os lados (lift = jogadas para fora)."""
    m = rig.n("mane")
    m.rotation_euler.z += 0.035 * amp * math.sin(math.tau * t)
    m.rotation_euler.x += 0.025 * amp * math.sin(math.tau * t + 1.0) + 0.3 * lift
    for j, sx in enumerate((1, -1)):
        o = rig.n(f"lock{j}")
        o.rotation_euler.y += sx * (0.06 * amp * math.sin(math.tau * t + j * 0.8) + lift)
        o.rotation_euler.x += 0.05 * amp * math.sin(math.tau * t + j * 1.3)


def _hum(rig, t, on=True):
    for j, nm in enumerate(rig.hum):
        o = rig.n(nm)
        if not on:
            o.scale = (0.0001,) * 3
            continue
        o.location.z += 0.06 * math.sin(math.tau * (t + j * 0.5))
        o.location.x += 0.02 * math.cos(math.tau * (t + j * 0.5))
        o.rotation_euler.y += 0.25 * math.sin(math.tau * (t + j * 0.5))


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "rise", t, rise=0.5, spread=0.8)
    if anim == "idle":
        s = math.sin(math.tau * t)
        body.location.z += 0.018 * s
        R.squash(body, 1.0 + 0.025 * s)
        head.rotation_euler.y += 0.07 * math.sin(math.tau * t)
        head.location.z += 0.008 * math.sin(math.tau * (t - 0.15))
        C.chain_wave(rig, rig.tail, t, 0.06, axis="z", phase_step=0.7, start=2)
        _hair(rig, t)
        _arms(rig, -0.15 + 0.08 * math.sin(math.tau * t), 0.1)
        _mouth(rig, 0.35 + 0.35 * max(0.0, math.sin(math.tau * 2 * t)))
        _hum(rig, t)
        C.flames(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
    elif anim == "walk":
        b = abs(math.sin(math.tau * t))
        body.location.z += 0.03 * b
        root.rotation_euler.y += 0.06 * math.sin(math.tau * t)
        C.chain_wave(rig, rig.tail, t, 0.16, axis="z", phase_step=0.9, start=1)
        body.rotation_euler.x += 0.05
        _hair(rig, t, 1.6, 0.0)
        for nm in rig.locks:
            rig.n(nm).rotation_euler.x += 0.12
        _arms(rig, 0.25, 0.25)
        _mouth(rig, 0.2)
        _hum(rig, t)
        C.flames(rig, t, sway=0.2)
        rig.n("pond").rotation_euler.z += 0.15 * math.sin(math.tau * t)
    elif anim == "attack":
        _attack(rig, i)
        C.flames(rig, t, k=[1.0, 1.08, 1.15, 1.2, 1.15, 1.1, 1.05, 1.0][i])
    elif anim == "hit":
        R.squash(body, [0.86, 1.08, 0.97, 1.0][i])
        body.rotation_euler.x += [-0.12, 0.05, 0.02, 0][i]
        head.rotation_euler.x += [-0.18, 0.05, 0.0, 0][i]   # recua: o rosto aparece
        S.blink(rig, [0.9, 0.6, 0.0, 0.0][i])
        _mouth(rig, [0.8, 0.5, 0.3, 0.3][i])
        _arms(rig, [-0.8, -0.4, -0.2, -0.15][i], [0.6, 0.3, 0.1, 0.1][i])
        _hair(rig, 0.0, 1.0, [0.35, 0.2, 0.05, 0.0][i])
        _hum(rig, t, on=False)
        C.flames(rig, i / 4.0, k=[1.12, 1.05, 1.0, 1.0][i])
        S.splash(rig, "drop", [0.12, 0.3, 0.48, 0.7][i], Vector((0, -0.05, 0.5 + LIFT)),
                 [(-0.4, 0.1, 0.9), (0.4, 0.05, 0.85), (0.0, 0.3, 1.0), (-0.2, -0.2, 0.7), (0.25, -0.15, 0.75),
                  (0.4, 0.25, 0.6), (-0.4, 0.25, 0.65)], g=3.0, shrink=0.9)
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Puxa o ar (recua, bracos abertos, olhos fechados) e solta o canto: aneis de som e notas de agua saindo da boca."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    lean = [-0.16, -0.24, 0.16, 0.22, 0.2, 0.16, 0.08, 0.0][i]
    body.rotation_euler.x += lean
    R.squash(body, [1.05, 1.08, 0.94, 0.97, 1.0, 1.0, 1.0, 1.0][i])
    head.rotation_euler.x += [-0.12, -0.18, 0.08, 0.1, 0.1, 0.06, 0.03, 0][i]
    _arms(rig, [-0.6, -0.9, -1.3, -1.2, -1.1, -0.8, -0.4, -0.15][i], [0.7, 0.9, 0.45, 0.4, 0.4, 0.3, 0.2, 0.1][i])
    _mouth(rig, [0.4, 0.2, 1.0, 1.0, 0.95, 0.8, 0.5, 0.3][i])
    if i in (0, 1):
        S.blink(rig, 0.85)
    _hair(rig, i / 8, 1.0, [0.1, 0.15, -0.1, -0.15, -0.12, -0.08, -0.03, 0][i])
    C.chain_wave(rig, rig.tail, i / 8, 0.08, axis="z", start=2)
    _hum(rig, 0, on=False)
    # aneis de som: saem em sequencia da boca, crescem e avancam
    for j, nm in enumerate(rig.sing):
        u = (i - 2 - j * 1.2) / 4.0
        o = rig.n(nm)
        if u < 0 or u > 1:
            o.scale = (0.0001,) * 3
            continue
        s = 0.5 + 1.3 * u
        o.scale = (s, s, s)
        o.location.y -= 0.12 + 0.4 * u
        o.location.z += 0.05 * u
    # notas: espalham para a frente e para os lados
    dirs = [(-0.3, -0.5, 0.1), (0.3, -0.5, 0.18), (-0.12, -0.6, 0.25), (0.18, -0.65, 0.02)]
    for j, nm in enumerate(rig.notes):
        u = (i - 2 - j * 0.6) / 4.5
        o = rig.n(nm)
        if u < 0 or u > 1:
            o.scale = (0.0001,) * 3
            continue
        d = Vector(dirs[j])
        o.location += d * (0.2 + 0.5 * u)
        o.rotation_euler.y += 0.5 * math.sin(math.tau * u + j)
        s = 1.0 + 0.3 * u
        o.scale = (s, s, s)


def _death(rig, i):
    """O fogo negro apaga, ela amolece e deita de lado sobre a cauda, olhos fechados (volta ao fundo do rio)."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    C.flames(rig, i / 8, k=[1.05, 0.85, 0.6, 0.35, 0.15, 0.0, 0.0, 0.0][i])
    _hum(rig, 0, on=False)
    S.motes(rig, "rise", i / 8, rise=0.5, spread=0.8, fade=max(0.0001, 1.0 - i / 5))
    side = [0.0, 0.1, 0.3, 0.6, 0.85, 0.95, 0.91, 0.93][i]
    body.rotation_euler.y += side
    body.location.z -= 0.2 * (1 - math.cos(side))
    body.rotation_euler.x += [0.2, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0][i]
    R.squash(body, [0.88, 1.04, 1.0, 0.98, 0.95, 1.02, 0.99, 1.0][i])
    head.rotation_euler.x += [0.25, 0.1, -0.05, -0.1, -0.12, -0.12, -0.12, -0.12][i]
    head.rotation_euler.y += [0.0, 0.0, 0.1, 0.2, 0.25, 0.25, 0.25, 0.25][i]
    S.blink(rig, [0.9, 0.5, 0.6, 0.85, 1.0, 1.0, 1.0, 1.0][i])
    _mouth(rig, [0.9, 0.6, 0.4, 0.2, 0.1, 0.05, 0.05, 0.05][i])
    _arms(rig, [-0.9, -0.5, -0.2, 0.0, 0.1, 0.15, 0.15, 0.15][i], [0.6, 0.3, 0.6, 0.9, 1.0, 1.0, 1.0, 1.0][i])
    _hair(rig, 0, 0.0, [0.3, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0][i])
    C.chain_wave(rig, rig.tail, 0.25, [0.1, 0.05, 0.0, 0, 0, 0, 0, 0][i], axis="z")
    S.splash(rig, "drop", [0, 0, 0, 0, 0.12, 0.3, 0.5, 0][i], Vector((-0.3, 0.0, 0.25)),
             [(-0.3, 0.1, 0.8), (0.3, 0.1, 0.7), (0.0, 0.3, 0.9), (-0.2, -0.2, 0.6), (0.2, -0.2, 0.6), (0.4, 0.2, 0.5),
              (-0.4, 0.2, 0.55)], g=3.0, shrink=0.9)
