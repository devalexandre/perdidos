"""Lanterna Travessa (paper_lantern) — Ilhas do Sol Nascente. Objeto assombrado inspirado nas lanternas de papel
do folclore japones (lanterna que ganha rosto e lingua). Sem escrita ritual nem simbolos. Modelo proprio por script
(piloto 07/10/2026), mesmas regras de pixel art do stone_armadillo.py; flutua (lean como o vaga-lume).
  s1 Lanterna Travessa (pequena): papel creme aceso, nervuras vermelhas, tampas laqueadas, alca, borla; olhos
     grandes, sobrancelha marota (uma alta, outra baixa), sorrisao com a lingua de fora e uma chama-topete;
     golpe = enche as bochechas e cospe brasas.
  s3 Lanterna do Desfile (chefe): lanterna alta de papel vermelho com faixas e tampas douradas, coroa de pontas,
     tres borlas douradas compridas, chama grande e tres lanterninhas-filhas em orbita (o desfile); golpe = cospe uma
     rajada de brasas e as filhas avancam.
  s4 Lanterna da Chama Violeta (atroz = o chefe a noite): papel rasgado e queimado aceso por dentro em violeta,
     nervuras negras, rasgos com chamas roxas lambendo, sorriso de dentes, olhos frios acesos, chama violeta alta,
     borlas queimadas e fogos-fatuos roxos no lugar das filhas.
STAGES = (1, 3, 4) como a leva reserve. Pose por quadro em pose()."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

SCALE = {1: 1.3, 3: 2.2, 4: 2.2}
FRAME = {1: 96, 3: 240, 4: 240}
STAGES = (1, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"paper": "vlamp", "lantern_paper": "vlamp", "lantern_rib": "vlamp_rib", "gold": "gold_n", "cap": "hood_n",
         "brow": "brow_n", "tongue": "wisp_v2", "eye_cyan": "eye_violet", "paper_cream": "vlamp"}
LEAN = 24.0
HOVER = 0.22


def _dims(stage):
    if stage == 1:
        return dict(LC=Vector((0, 0, HOVER + 0.3)), LR=(0.27, 0.25, 0.3), ribs=7)
    return dict(LC=Vector((0, 0, HOVER + 0.4)), LR=(0.27, 0.25, 0.4), ribs=9)


def _r_at(LR, dz):
    q = 1 - (dz / LR[2]) ** 2
    return math.sqrt(max(0.0, q))


def build(stage):
    if stage not in STAGES:
        raise ValueError("estagios: 1, 3 (chefe), 4 (atroz)")
    R.reset()
    D = _dims(stage)
    LC, LR = D["LC"], D["LR"]
    boss, night = stage >= 3, stage == 4
    R.CUR["reach"] = (0.15, 0.15, 0.15)
    rig = R.Rig("paper_lantern")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", LC, root)
    paper = "lantern_paper" if stage == 1 else "paper"
    rig.add_mesh(R.ellipsoid("paper", LC, LR, seg=32, rings=20), "paper", paper, body, group="paper")
    # nervuras (aros) do papel
    nr = D["ribs"]
    rig.ribs = []
    for k in range(nr):
        dz = LR[2] * (-0.82 + 1.64 * k / (nr - 1))
        r = _r_at(LR, dz)
        rib = S.torus(f"rib{k}", LC + Vector((0, 0, dz)), LR[0] * r * 1.0, 0.009, nu=32, nv=6,
                      yscale=LR[1] / LR[0])
        rig.add_mesh(rib, f"rib{k}", "lantern_rib", body, noline=True)
        rig.ribs.append(f"rib{k}")
    if boss:
        # faixas douradas largas perto das tampas
        for k, dz in enumerate((-0.62, 0.62)):
            z = LR[2] * dz
            r = _r_at(LR, z)
            rig.add_mesh(S.torus(f"band{k}", LC + Vector((0, 0, z)), LR[0] * r * 1.01, 0.03, nu=32, nv=6, squash=1.4,
                                 yscale=LR[1] / LR[0]), f"band{k}", "gold", body)
    # tampas laqueadas (em cima e embaixo) com aro
    capm = "lacquer"
    for k, sg in enumerate((1, -1)):
        z = LC.z + sg * LR[2] * 0.93
        r = LR[0] * 0.42
        h = 0.05 if not boss else 0.08
        rig.add_mesh(R.cone(f"lid{k}", (0, 0, z - sg * 0.01), (0, 0, z + sg * h), r, r * 0.92, seg=24, rings=1), f"lid{k}",
                     capm, body)
        rig.add_mesh(S.torus(f"lidrim{k}", (0, 0, z + sg * h), r * 0.95, 0.018, nu=24), f"lidrim{k}",
                     "gold" if boss else capm, body)
    top = LC.z + LR[2] * 0.93 + (0.05 if not boss else 0.08)
    bot = LC.z - LR[2] * 0.93 - (0.05 if not boss else 0.08)
    # alca em cima (aro de pe)
    rig.add_mesh(S.torus("handle", (0, 0.04, top + 0.06), 0.075, 0.014, rot=(math.pi / 2, 0, 0), nu=20), "handle", "lacquer",
                 body)
    if boss:
        # coroa de pontas douradas em volta da tampa de cima
        for k in range(8):
            a = math.tau * k / 8
            b = Vector((math.cos(a) * LR[0] * 0.45, math.sin(a) * LR[0] * 0.45, top - 0.01))
            rig.add_mesh(R.cone(f"crown{k}", b, b + Vector((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.11 if k % 2 else 0.07)),
                                0.03, 0.004, seg=5, rings=1), f"crown{k}", "gold", body, group="crown")
    # chama-topete saindo da tampa (tremula)
    fl = rig.empty("flame", (0, -0.02, top + 0.02), body)
    fk = 1.0 if not boss else 1.6
    fm = ("ember", "ember_hot", "ember_core") if not night else ("wisp_v2", "wisp_v", "bolt2")
    # gota de fogo: bojo redondo embaixo, ponta curva em cima; miolo claro grande na frente
    rig.add_mesh(R.ellipsoid("flameb", (0, -0.02, top + 0.06 * fk), (0.06 * fk, 0.05 * fk, 0.06 * fk)), "flame0", fm[0], fl,
                 unlit=True, noline=True, prio=2.0)
    rig.add_mesh(R.cone("flame0", (0, -0.02, top + 0.07 * fk), (0.03, -0.01, top + 0.24 * fk), 0.055 * fk, 0.004, seg=10,
                        rings=4, bend=(0.03, 0, 0.0)), "flame0", fm[0], fl, unlit=True, noline=True, prio=2.0)
    rig.add_mesh(R.ellipsoid("flame1", (0, -0.05, top + 0.075 * fk), (0.042 * fk, 0.03 * fk, 0.06 * fk)), "flame1", fm[1], fl,
                 unlit=True, noline=True, prio=2.6)
    rig.add_mesh(R.ellipsoid("flame2", (0, -0.075, top + 0.06 * fk), (0.022 * fk, 0.015 * fk, 0.03 * fk)), "flame2", fm[2], fl,
                 unlit=True, noline=True, prio=3.2)
    # borla(s) embaixo
    tas = rig.empty("tassel", (0, 0, bot), body)
    tl = 0.13 if not boss else 0.26
    tx = (0.0,) if not boss else (-0.1, 0.0, 0.1)
    tr = 0.02 if not boss else 0.012
    for j, x in enumerate(tx):
        b = Vector((x, 0, bot))
        rig.add_mesh(R.ellipsoid(f"tknot{j}", b + Vector((0, 0, -0.02)), (0.025, 0.025, 0.025)), f"tknot{j}",
                     "gold" if boss else "cap", tas)
        for c in (-1, 0, 1):
            rig.add_mesh(R.cone(f"tstr{j}{c}", b + Vector((0.01 * c, 0, -0.03)), b + Vector((0.025 * c, 0.01, -0.03 - tl * (1 - 0.12 * abs(c)))),
                                tr, tr * 0.6, seg=6, rings=2), f"tstr{j}", "gold" if boss else "cap", tas, group=f"tas{j}")
    # ---- rosto no papel da frente
    face_z = LC.z + LR[2] * (0.26 if not boss else 0.28)
    rz = 0.13 if not boss else 0.145
    rx = 0.1 if not boss else 0.105
    for sx, nm in ((1, "L"), (-1, "R")):
        ex = 0.108 * sx
        ep = Vector((ex, S.ysurf(LC, LR, ex, face_z) + 0.012, face_z))
        S.eye(rig, nm, ep, body, rx, rz, -0.4 * sx, mode="cold" if night else "normal", tilt=0.05)
        k = rz / 0.145
        if stage == 1:
            # marota: esquerda levantada, direita baixa
            S.brow(rig, nm, ep, body, k, -0.03 if sx > 0 else 0.04, mat="brow", thick=0.8, width=0.85, lift=0.0, prio=2.6)
        else:
            S.brow(rig, nm, ep, body, k, 0.07, mat="eye", thick=1.25, lift=-0.02, prio=3.0)
        if not night:
            cx, cz = 0.18 * sx, face_z - 0.12
            S.cheek(rig, nm, Vector((cx, S.ysurf(LC, LR, cx, cz) + 0.006, cz)), body, k=1.0, yaw=-0.6 * sx)
    # boca: sorrisao (meia-lua escura) + lingua de fora
    mz = face_z - (0.17 if not boss else 0.22)
    my = S.ysurf(LC, LR, 0, mz)
    mouth = rig.empty("mouth", (0, my, mz), body)
    mw = 0.11 if not boss else 0.14
    rig.add_mesh(R.ellipsoid("mouth", (0, my + 0.002, mz), (mw, 0.03, 0.055 if not boss else 0.065), rot=(0.3, 0, 0)), "mouth",
                 "mouth_in", mouth, noline=True, unlit=True, prio=2.0)
    # labio de cima: a borda reta do sorriso (papel por cima) — chapeia a metade de cima da boca
    rig.add_mesh(R.ellipsoid("lip", (0, my - 0.002, mz + 0.045), (mw * 1.1, 0.03, 0.028), rot=(0.3, 0, 0)), "lip", paper,
                 mouth, group="paper", prio=2.2)
    tg = rig.empty("tongue", (0, my - 0.02, mz - 0.01), mouth)
    tlen = 0.12 if not boss else 0.16
    rig.add_mesh(R.cone("tongue", (0.02, my - 0.02, mz - 0.01), (0.035, my - 0.07, mz - tlen), 0.04, 0.032, seg=10, rings=4,
                        bend=(0.0, -0.025, 0.0)), "tongue", "tongue", tg, noline=False, prio=2.2)
    if boss:
        for sx in (1, -1):  # dentinhos
            b = Vector((0.065 * sx, my - 0.03, mz + 0.012))
            rig.add_mesh(R.cone(f"tooth{sx}", b, b + Vector((0, -0.006, -0.04 if not night else -0.06)), 0.018, 0.003, seg=5,
                                rings=1), "tooth", "fur_white" if not night else "fang_n", mouth, noline=True, prio=2.6)
        if night:
            for j in range(3):
                b = Vector((-0.04 + 0.04 * j, my - 0.03, mz - 0.045))
                rig.add_mesh(R.cone(f"ltooth{j}", b, b + Vector((0, -0.006, 0.035)), 0.014, 0.003, seg=5, rings=1),
                             "ltooth", "fang_n", mouth, noline=True, prio=2.6)
    if night:
        _atroz_tears(rig, body, LC, LR)
    # ---- particulas: brasas cuspidas (golpe), fumaca (morte), filhas do desfile / fogos-fatuos (chefe)
    S.add_motes(rig, "spit", [(0.0, 0.0, 0.5)] * 7, ["ember_hot", "ember_core", "ember"] if not night else
                ["wisp_v", "bolt2", "wisp_v2"], size=0.03 if not boss else 0.035, parent=root)
    S.hide_motes(rig, "spit")
    S.add_motes(rig, "smoke", [(0.0, 0.0, 0.5)] * 5, ["smoke"] if not night else ["cloud_n"], size=0.04, parent=rig.turn)
    S.hide_motes(rig, "smoke")
    if boss:
        rig.kids = []
        for j in range(3):
            a = math.tau * j / 3 + 0.5
            # o desfile: as filhas rodam em volta da base (nunca passam na frente do rosto)
            p = Vector((0.66 * math.cos(a), 0.5 * math.sin(a), HOVER + 0.12 + 0.06 * j))
            _kid(rig, j, p, root, night)
    rig.save_rest()
    if night:
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    return rig


def _kid(rig, j, p, root, night):
    """Lanterninha-filha (desfile) com olhinhos e boquinha; no atroz vira fogo-fatuo roxo com olhos."""
    k = rig.empty(f"kid{j}", p, root)
    r = (0.075, 0.07, 0.085)
    rig.add_mesh(R.ellipsoid(f"kidp{j}", p, r, seg=16, rings=10), f"kidp{j}", "lantern_paper" if not night else "wisp_v", k,
                 unlit=night, noline=night)
    if not night:
        for dz in (-0.04, 0.0, 0.04):
            rz = math.sqrt(max(0, 1 - (dz / r[2]) ** 2))
            rig.add_mesh(S.torus(f"kidr{j}{dz}", p + Vector((0, 0, dz)), r[0] * rz, 0.006, nu=16, nv=5, yscale=r[1] / r[0]),
                         f"kidr{j}", "lantern_rib", k, noline=True)
        for sg in (1, -1):
            rig.add_mesh(R.cone(f"kidl{j}{sg}", p + Vector((0, 0, sg * r[2] * 0.85)), p + Vector((0, 0, sg * (r[2] + 0.025))),
                                0.035, 0.03, seg=10, rings=1), f"kidl{j}", "lacquer", k)
    else:
        rig.add_mesh(R.cone(f"kidf{j}", p + Vector((0, 0, 0.04)), p + Vector((0, 0.02, 0.18)), 0.06, 0.004, seg=8, rings=3),
                     f"kidf{j}", "wisp_v2", k, unlit=True, noline=True, prio=2.0)
    for sg in (1, -1):
        rig.add_mesh(R.ellipsoid(f"kide{j}{sg}", p + Vector((0.03 * sg, -r[1] * 0.95, 0.01)), (0.016, 0.01, 0.024)),
                     f"kide{j}", "eye" if not night else "eye_violet", k, noline=True, unlit=True, prio=4.0)
    rig.add_mesh(R.ellipsoid(f"kidm{j}", p + Vector((0, -r[1] * 0.97, -0.03)), (0.022, 0.008, 0.012)), f"kidm{j}",
                 "mouth_in" if not night else "eye_violet", k, noline=True, unlit=True, prio=3.0)
    rig.kids.append(f"kid{j}")


def _atroz_tears(rig, body, LC, LR):
    """Rasgos queimados no papel com chama violeta lambendo para fora."""
    rig.licks = []
    for j, (psi, om) in enumerate(((1.35, 0.25), (1.25, 2.85), (0.6, 1.3), (1.6, 3.9), (1.0, 5.2))):
        p, n = S.on_ell(LC, LR, psi, om, 1.0)
        rig.add_mesh(R.ellipsoid(f"tear{j}", p + n * 0.008, (0.07, 0.055, 0.012), rot=S.align(n), seg=12, rings=6),
                     f"tear{j}", "burnt", body, unlit=True, noline=True, prio=1.6)
        rig.add_mesh(R.ellipsoid(f"tearin{j}", p + n * 0.012, (0.04, 0.03, 0.01), rot=S.align(n), seg=10, rings=5),
                     f"tearin{j}", "wisp_v", body, unlit=True, noline=True, prio=2.0)
        e = rig.empty(f"lick{j}", p, body)
        up = (n * 0.6 + Vector((0, 0, 1))).normalized()
        rig.add_mesh(R.cone(f"lickc{j}", p + n * 0.01, p + n * 0.02 + up * 0.13, 0.035, 0.003, seg=8, rings=3,
                            bend=n * 0.02), f"lickc{j}", "wisp_v2", e, unlit=True, noline=True, prio=2.2)
        rig.licks.append(f"lick{j}")


# ------------------------------------------------------------------ animacao
def _flame(rig, i, k=1.0):
    f = rig.n("flame")
    s = [1.0, 1.15, 0.92, 1.1, 0.95, 1.18, 0.9, 1.05][i % 8] * k
    f.scale = (1.0 / math.sqrt(max(s, 0.05)) if s > 0.05 else 0.0001,) * 2 + (max(s, 0.0001),)
    f.rotation_euler.y = [0.0, 0.12, -0.08, 0.1, -0.12, 0.05, -0.05, 0.08][i % 8]


def _tongue(rig, a, out=1.0):
    t = rig.n("tongue")
    t.rotation_euler.y += a
    t.scale = (1, out, out)


def _kids(rig, t, reach=0.0):
    for j, nm in enumerate(getattr(rig, "kids", [])):
        o = rig.n(nm)
        base = rig.rest[nm][0]
        a = math.atan2(base.y, base.x) + math.tau * t
        r = Vector((base.x, base.y, 0)).length
        o.location = Vector((r * math.cos(a), r * math.sin(a) - reach, base.z + 0.05 * math.sin(math.tau * (t * 2 + j / 3))))


def _licks(rig, i):
    for j, nm in enumerate(getattr(rig, "licks", [])):
        s = [1.0, 1.3, 0.8, 1.2, 0.9, 1.35, 0.85, 1.1][(i + 3 * j) % 8]
        rig.n(nm).scale = (1, 1, s)


def _accordion(rig, s):
    """Lanterna sanfona: achata sem alargar (as nervuras juntam)."""
    b = rig.n("body")
    b.scale.z *= s
    b.scale.x *= 1.0 + (1.0 - s) * 0.25
    b.scale.y *= 1.0 + (1.0 - s) * 0.25


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body = rig.root, rig.n("body")
    boss, night = stage >= 3, stage == 4
    LC = _dims(stage)["LC"]
    _flame(rig, i)
    if night:
        _licks(rig, i)
    if anim == "idle":
        s = math.sin(math.tau * t)
        root.location.z += 0.035 * s
        R.squash(root, 1.0 + 0.035 * math.sin(math.tau * t + 1.2), anchored=False)
        body.rotation_euler.y = 0.08 * math.sin(math.tau * t + 0.5)
        rig.n("tassel").rotation_euler.y = -0.25 * math.sin(math.tau * t)
        _tongue(rig, 0.25 * math.sin(math.tau * 2 * t))
        _kids(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
    elif anim == "walk":
        # flutua para a frente: inclina, quica mais, borla e lingua ficam para tras
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.06 * b
        R.tilt(root, 0.16, 0.0)
        body.rotation_euler.y = 0.12 * math.sin(math.tau * t)
        R.squash(root, 1.0 + 0.06 * (b - 0.5), anchored=False)
        rig.n("tassel").rotation_euler.x = -0.5 - 0.15 * b
        _tongue(rig, 0.35 * math.sin(math.tau * 2 * t), 1.1)
        _kids(rig, t * 1.0)
    elif anim == "attack":
        # 0-1 enche (estica para cima, bochechas, olhos apertados), 2 cospe (achata para a frente, boca aberta),
        # 3-5 brasas voando, 6-7 volta
        sq = [1.12, 1.2, 0.78, 0.9, 1.0, 1.05, 0.98, 1.0][i]
        _accordion(rig, sq)
        R.tilt(root, [-0.15, -0.22, 0.3, 0.24, 0.14, 0.06, 0.02, 0.0][i], 0.0)
        root.location.z += [0.04, 0.08, 0.0, 0.0, 0.02, 0.02, 0.01, 0.0][i]
        if i < 2:
            S.blink(rig, [0.4, 0.6][i])
            rig.n("mouth").scale = (0.6, 1, 0.4)
            _tongue(rig, 0.0, 0.0001)
        else:
            m = [1.0, 1.0, 1.4, 1.35, 1.2, 1.1, 1.0, 1.0][i]
            rig.n("mouth").scale = (m, 1, m * 1.2)
            _tongue(rig, 0.0, [1, 1, 0.3, 0.4, 0.7, 0.9, 1, 1][i])
        _flame(rig, i, [1.3, 1.6, 0.7, 0.9, 1.1, 1.0, 1.0, 1.0][i])
        u = [0, 0, 0.12, 0.28, 0.44, 0.6, 0.74, 0][i]
        vel = [(-0.12 + 0.04 * k, -0.45 - 0.06 * (k % 3), 0.3 + 0.12 * (k % 3)) for k in range(7)]
        S.splash(rig, "spit", u, LC + Vector((0, -0.25, -0.15)), vel, g=0.6, shrink=0.7, floor=0.1)
        _kids(rig, 0.1 * i, reach=[0, 0, 0.05, 0.12, 0.15, 0.1, 0.05, 0][i])
    elif anim == "hit":
        # amassa como sanfona, olhos apertados, chama encolhe, inclina
        _accordion(rig, [0.72, 1.12, 0.94, 1.02][i])
        R.tilt(root, [-0.2, 0.08, -0.04, 0.0][i], 0.0)
        body.rotation_euler.y = [0.25, -0.12, 0.05, 0.0][i]
        if i < 2:
            S.blink(rig, [0.9, 0.5][i])
        _flame(rig, i, [0.5, 1.3, 0.9, 1.0][i])
        _tongue(rig, [0.6, -0.4, 0.2, 0][i], 1.15)
        rig.n("tassel").rotation_euler.y = [0.6, -0.4, 0.2, 0][i]
        _kids(rig, 0.03 * i)
    elif anim == "death":
        _death(rig, i, stage, LC)


def _death(rig, i, stage, LC):
    """A chama apaga (fumaca), a lanterna fecha como sanfona, cai no chao e tomba; fica dobrada de olhos fechados."""
    root, body = rig.root, rig.n("body")
    _flame(rig, i, [0.7, 0.4, 0.15, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001][i])
    acc = [0.85, 0.75, 0.62, 0.5, 0.45, 0.42, 0.42, 0.42][i]
    _accordion(rig, acc)
    # cai do ar ate o chao (corpo fechado fica com a base no chao)
    drop = [0.0, 0.05, 0.12, 0.2, 0.22, 0.22, 0.22, 0.22][i] * (1.0 if stage == 1 else 1.0)
    root.location.z -= drop * (HOVER / 0.22)
    # a base do corpo abaixa junto com a sanfona: compensa para pousar
    lr = _dims(stage)["LR"]
    body.location.z -= (1 - acc) * (lr[2] * 0.0)
    roll = [0.0, 0.1, 0.25, 0.5, 0.9, 1.15, 1.1, 1.12][i]
    root.rotation_euler.y += roll
    root.location.z += 0.12 * math.sin(roll) * (lr[0] / 0.27)
    root.location.x -= 0.08 * roll / 1.12
    S.blink(rig, 0.6 if i < 2 else 1.0)
    _tongue(rig, [0.4, -0.3, 0.6, 0.8, 0.9, 0.9, 0.9, 0.9][i], [1.1, 1.2, 1.25, 1.3, 1.3, 1.3, 1.3, 1.3][i])
    rig.n("tassel").rotation_euler.y = [0.4, -0.3, 0.2, -0.2, 0.3, 0.0, 0.0, 0.0][i]
    vel = [(0.05 * math.cos(k * 2.1), 0.05 * math.sin(k * 2.1), 0.3 + 0.06 * k) for k in range(5)]
    S.splash(rig, "smoke", [0, 0, 0.2, 0.45, 0.7, 0.95, 1.2, 0][i], LC + Vector((0, 0, _dims(stage)["LR"][2] + 0.1)), vel,
             g=0.1, shrink=0.55, floor=0.1)
    if getattr(rig, "kids", None):
        # as filhas caem junto e apagam
        for j, nm in enumerate(rig.kids):
            o = rig.n(nm)
            o.location.z -= [0, 0.03, 0.08, 0.14, 0.18, 0.2, 0.2, 0.2][i]
            s = max(0.0001, 1.0 - 0.18 * i)
            o.scale = (s, s, s)
    if stage == 4:
        k = max(0.0001, 1 - 0.25 * i)
        for nm in getattr(rig, "licks", []):
            rig.n(nm).scale = (k, k, k)
