"""Corvo da Montanha (mountain_tengu) — Ilhas do Sol Nascente. Ave chibi inspirada no tengu-corvo do folclore
japones: penas de corvo, mascara clara no rosto, bico-nariz, topete, asas-bracos e leque de penas (no chefe).
Sem objetos religiosos (nada de gorro de asceta, contas ou papel ritual). Modelo proprio por script (piloto
07/10/2026), mesmas regras de pixel art do stone_armadillo.py.
  s1 Corvo da Montanha (pequeno): filhote convencido, cachecol vermelho; golpe = bicada com bate-asa.
  s3 Tengu do Vendaval (chefe): mais alto e ereto, rosto vermelho com bico comprido, juba de penas brancas, asas
     grandes meio abertas, cachecol comprido esvoacando, leque de penas na asa e folhas girando no vento; golpe =
     ergue o leque e varre o ar (rajada de vento com folhas).
  s4 Tengu da Asa Noturna (atroz = o chefe a noite): penas roxo-negras, asas rasgadas com penas-lamina, leque de
     laminas com fio de luz fria, olhos de brasa, bico com serrilha, juba lilas, penas roxas e fogos-fatuos em volta.
STAGES = (1, 3, 4) como a leva reserve. Pose por quadro em pose()."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

SCALE = {1: 1.15, 3: 2.15, 4: 2.15}
FRAME = {1: 96, 3: 240, 4: 240}
STAGES = (1, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"crow": "crow_n", "crow_face": "pale_n", "tengu_red": "hood_n", "fur_white": "pale_n", "beak": "gold_n",
         "chicken_leg": "gold_n", "cap": "hood_n", "wood": "thorn_n", "leaf_g": "wisp_v", "leaf_o": "wisp_v2",
         "brow": "brow_n"}
LEAN = 8.0
HEAD_TILT = -0.42


def _dims(stage):
    if stage == 1:
        return dict(BC=Vector((0, 0.03, 0.3)), BR=(0.2, 0.18, 0.21), HC=Vector((0, -0.04, 0.68)), HR=(0.25, 0.215, 0.23),
                    leg=0.12, wing=1.0)
    return dict(BC=Vector((0, 0.03, 0.4)), BR=(0.2, 0.18, 0.27), HC=Vector((0, -0.04, 0.86)), HR=(0.235, 0.205, 0.22),
                leg=0.17, wing=1.35)


def build(stage):
    if stage not in STAGES:
        raise ValueError("estagios: 1, 3 (chefe), 4 (atroz)")
    R.reset()
    D = _dims(stage)
    BC, BR, HC, HR = D["BC"], D["BR"], D["HC"], D["HR"]
    boss, night = stage >= 3, stage == 4
    R.CUR["reach"] = (0.2, 0.25, 0.2) if not boss else (0.24, 0.3, 0.26)
    rig = R.Rig("mountain_tengu")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", (0, 0.02, D["leg"]), root)
    # ---- corpo de penas + peito claro
    rig.add_mesh(R.ellipsoid("torso", BC, BR), "torso", "crow", body, group="torso")
    chest_c = BC + Vector((0, -BR[1] * 0.55, -0.01))
    rig.add_mesh(R.ellipsoid("chest", chest_c, (BR[0] * 0.72, BR[1] * 0.55, BR[2] * 0.78)), "chest",
                 "crow_face" if not boss else "fur_white", body, group="chest")
    # penas do peito (escamas em V) no chefe
    if boss:
        for k in range(3):
            z = chest_c.z + 0.08 - 0.07 * k
            y = S.ysurf(chest_c, (BR[0] * 0.72, BR[1] * 0.55, BR[2] * 0.78), 0, z) - 0.004
            w = 0.09 - 0.015 * k
            rig.add_mesh(R.cone(f"chv{k}", (-w, y + 0.02, z + 0.02), (w, y + 0.02, z + 0.02), 0.008, 0.008, seg=5, rings=6,
                                bend=(0, -0.02, -0.035)), f"chv{k}", "crow_face", body, noline=True, unlit=True, prio=1.3)
    # ---- rabo em leque
    tail = rig.empty("tail", (0, BC.y + BR[1] * 0.8, BC.z - BR[2] * 0.5), body)
    nt = 3 if not boss else 5
    for k in range(nt):
        a = (k - (nt - 1) / 2) * 0.32
        b = Vector((0, BC.y + BR[1] * 0.7, BC.z - BR[2] * 0.45))
        ln = 0.22 if not boss else 0.36
        tip = b + Vector((math.sin(a) * ln * 0.6, ln * 0.9, -0.02 + 0.06 * math.cos(a)))
        rig.add_mesh(R.cone(f"tailf{k}", b, tip, 0.05, 0.012 if not night else 0.003, seg=6, rings=3,
                            bend=(0, 0, 0.03)), f"tailf{k}", "crow", tail, group=f"tailf{k}")
    # ---- pernas finas e pes de 3 dedos
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.085 * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.02, D["leg"] + 0.06), root)
        rig.add_mesh(R.cone(f"shin{nm}", (hx, 0.02, D["leg"] + 0.08), (hx, -0.0, 0.03), 0.026, 0.02, seg=8, rings=2),
                     f"shin{nm}", "chicken_leg", leg, group=f"leg{nm}")
        for c in (-1, 0, 1):
            b = Vector((hx, -0.0, 0.025))
            ln = 0.075 if not night else 0.09
            rig.add_mesh(R.cone(f"toe{nm}{c}", b, b + Vector((0.045 * c, -ln, -0.01)), 0.02, 0.01, seg=6, rings=1),
                         f"toe{nm}{c}", "chicken_leg", leg, group=f"leg{nm}")
        rig.add_mesh(R.cone(f"toeb{nm}", Vector((hx, 0, 0.025)), Vector((hx, 0.05, 0.015)), 0.018, 0.008, seg=6, rings=1),
                     f"toeb{nm}", "chicken_leg", leg, group=f"leg{nm}")
    # ---- asas (bracos): pivo no ombro; penas primarias na ponta
    wk = D["wing"]
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((BR[0] * 0.8 * sx, BC.y, BC.z + BR[2] * 0.5))
        w = rig.empty(f"wing{nm}", sp, body)
        wc = sp + Vector((0.06 * sx, 0.02, -0.13 * wk))
        rig.add_mesh(R.ellipsoid(f"wingm{nm}", wc, (0.065 * wk, 0.13 * wk, 0.17 * wk), rot=(0.2, -0.25 * sx, 0)), f"wingm{nm}",
                     "crow", w, group=f"wing{nm}")
        nf = 3 if not boss else 5
        for k in range(nf):
            b = wc + Vector((0.02 * sx, 0.03 + 0.03 * k, -0.08 * wk))
            ln = (0.16 + 0.03 * (k % 2)) * wk * (1.25 if night else 1.0)
            tip = b + Vector((0.035 * sx, 0.03 + 0.05 * k, -ln))
            rig.add_mesh(R.cone(f"prim{nm}{k}", b, tip, 0.038 * wk, 0.006 if not night else 0.002, seg=6, rings=3,
                                bend=(0.01 * sx, 0.02, 0)), f"prim{nm}{k}", "crow" if not night or k % 2 else "fang_n", w,
                         group=f"wing{nm}")
    # asas grandes nas costas do chefe (meio abertas) — silhueta
    if boss:
        for sx, nm in ((1, "L"), (-1, "R")):
            bp = Vector((0.08 * sx, BC.y + BR[1] * 0.6, BC.z + BR[2] * 0.55))
            bw = rig.empty(f"bwing{nm}", bp, body)
            for k in range(6):
                a = 0.25 + 0.2 * k
                ln = (0.5 - 0.04 * k) * (1.1 if night else 1.0)
                tip = bp + Vector((math.cos(a) * ln * sx, 0.12 + 0.03 * k, math.sin(a) * ln * 0.6 + 0.25 - 0.09 * k))
                mat = "crow" if (not night or k % 2 == 0) else "fang_n"
                rig.add_mesh(R.cone(f"bfeat{nm}{k}", bp, tip, 0.07 - 0.004 * k, 0.012 if not night else 0.002, seg=6,
                                    rings=4, bend=(0, 0.03, 0.04)), f"bfeat{nm}{k}", mat, bw, group=f"bwing{nm}")
    # ---- cabeca grande com mascara clara, topete, bico
    head = rig.empty("head", (0, HC.y + 0.03, HC.z - HR[2] * 0.75), body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "crow", head, group="head")
    MC = HC + Vector((0, -HR[1] * 0.58, -0.005))
    MR = (HR[0] * 0.88, HR[1] * 0.5, HR[2] * 0.92)
    rig.add_mesh(R.ellipsoid("mask", MC, MR), "mask", "crow_face" if not boss else "tengu_red", head, group="mask")
    # bico de corvo (o "nariz" do tengu): de cima + de baixo
    bz = MC.z - 0.06
    by = S.ysurf(MC, MR, 0, bz)
    bl = 0.15 if not boss else 0.22
    rig.add_mesh(R.cone("beak_up", (0, by + 0.03, bz + 0.005), (0, by - bl, bz - 0.04), 0.055, 0.006, seg=10, rings=4,
                        bend=(0, 0, 0.015)), "beak_up", "beak", head, prio=1.4)
    jaw = rig.empty("jaw", (0, by + 0.02, bz - 0.025), head)
    rig.add_mesh(R.cone("beak_lo", (0, by + 0.02, bz - 0.025), (0, by - bl * 0.7, bz - 0.06), 0.035, 0.005, seg=8, rings=2),
                 "beak_lo", "beak", jaw, prio=1.3)
    rig.add_mesh(R.ellipsoid("mouth_in", (0, by - 0.02, bz - 0.03), (0.03, 0.04, 0.012)), "mouth_in", "mouth_in", head,
                 noline=True, unlit=True)
    if night:
        for k in range(3):  # serrilha no bico
            p = Vector((0.0, by - 0.02 - 0.035 * k, bz - 0.022 - 0.012 * k))
            for sx in (1, -1):
                rig.add_mesh(R.cone(f"serr{k}{sx}", p + Vector((0.022 * sx * (1 - 0.25 * k), 0, 0)),
                                    p + Vector((0.022 * sx * (1 - 0.25 * k), -0.008, -0.03)), 0.009, 0.002, seg=5, rings=1),
                             "serr", "fang_n", head, noline=True, prio=2.2)
    # olhos grandes sobre a mascara
    rz = 0.14 if not boss else 0.14
    rx = 0.1 if not boss else 0.098
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.105 * sx, MC.z + 0.035
        ep = Vector((ex, S.ysurf(MC, MR, ex, ez) + 0.014, ez))
        S.eye(rig, nm, ep, head, rx, rz, -0.45 * sx, mode="ember" if night else "normal")
        k = rz / 0.145
        if stage == 1:
            S.brow(rig, nm, ep, head, k, 0.03, mat="brow", thick=0.8, width=0.85, lift=-0.01, prio=2.6)   # convencido
        else:
            # sobrancelha branca e grossa do tengu (le no rosto vermelho)
            S.brow(rig, nm, ep, head, k, 0.08, mat="brow_w" if not night else "brow_wn", thick=1.7, width=1.15, lift=-0.02,
                   prio=3.0)
        if not night:
            cx, cz = 0.165 * sx, MC.z - 0.07
            S.cheek(rig, nm, Vector((cx, S.ysurf(MC, MR, cx, cz) + 0.008, cz)), head, k=0.9, yaw=-0.7 * sx)
    # topete de penas
    crest = rig.empty("crest", HC + Vector((0, 0.02, HR[2] * 0.9)), head)
    nc = 3 if not boss else 5
    for k in range(nc):
        a = (k - (nc - 1) / 2) * 0.35
        b = HC + Vector((math.sin(a) * 0.06, 0.02, HR[2] * 0.85))
        ln = (0.17 if not boss else 0.26) * (1 - 0.18 * abs(k - (nc - 1) / 2))
        tip = b + Vector((math.sin(a) * ln * 0.7, ln * 0.55, ln * 0.85))
        rig.add_mesh(R.cone(f"crest{k}", b, tip, 0.045, 0.006, seg=6, rings=4, bend=(0, 0.04, 0.02)), f"crest{k}",
                     "crow" if (not boss or k % 2 == 0) else "fur_white", crest, group="crest")
    if boss:
        # juba de penas brancas em volta da cabeca (borda em ponta)
        def edge(ph):
            return S.bob(ph, 1.25, 2.3, open_=1.0, ramp=0.6) + S.zigzag(ph, 14, 0.3)
        rig.add_mesh(S.cap("mane", HC + Vector((0, 0.03, 0)), (HR[0] * 1.08, HR[1] * 1.1, HR[2] * 1.05), 1.25, edge, lift=1.0,
                           nu=42), "mane", "fur_white", head, group="mane")
    head.rotation_euler.x += HEAD_TILT
    # ---- cachecol vermelho (pescoco) com ponta solta
    nz = BC.z + BR[2] * 0.82
    rig.add_mesh(S.torus("scarf", (0, BC.y - 0.01, nz), BR[0] * 0.72, 0.04, squash=1.2, yscale=0.95, nu=24), "scarf", "cap",
                 body, group="scarf")
    sct = rig.empty("scarft", (BR[0] * 0.45, BC.y + BR[1] * 0.4, nz), body)
    ln = 0.2 if not boss else 0.42
    for k in range(2):
        b = Vector((BR[0] * 0.45, BC.y + BR[1] * 0.4, nz - 0.01))
        rig.add_mesh(R.cone(f"scarft{k}", b, b + Vector((0.08 + 0.05 * k, ln * (0.8 + 0.25 * k), -0.06 - 0.04 * k)), 0.04,
                            0.03, seg=6, rings=4, bend=(0.02, 0, 0.04)), f"scarft{k}", "cap", sct, group="scarf")
    # ---- leque de penas na asa direita (chefe)
    if boss:
        wr = rig.n("wingR")
        hp = Vector((-BR[0] * 0.8 - 0.1, BC.y - 0.08, BC.z + BR[2] * 0.5 - 0.3))
        fan = rig.empty("fan", hp, wr)
        rig.add_mesh(R.cone("fanh", hp, hp + Vector((0, -0.02, 0.14)), 0.022, 0.02, seg=6, rings=1), "fanh", "wood", fan)
        fb = hp + Vector((0, -0.025, 0.13))
        for k in range(9):
            a = math.radians(-64 + 16 * k)
            ln = 0.3 if not night else 0.34
            tip = fb + Vector((math.sin(a) * ln, -0.01, math.cos(a) * ln))
            mat = ("fur_white" if k % 2 else "crow") if not night else ("fang_n" if k % 2 else "crow")
            rig.add_mesh(R.cone(f"fanf{k}", fb, tip, 0.05, 0.012 if not night else 0.002, seg=6, rings=3,
                                bend=(0, -0.01, 0)), f"fanf{k}", mat, fan, group="fan")
            if night:
                rig.add_mesh(R.cone(f"fane{k}", fb + (tip - fb) * 0.55, tip, 0.012, 0.002, seg=5, rings=1), "fane", "cold_hot",
                             fan, unlit=True, noline=True, prio=2.5)
        rig.add_mesh(R.ellipsoid("fanc", fb, (0.05, 0.03, 0.04)), "fanc", "gold" if not night else "ember", fan,
                     unlit=night, noline=night)
    # ---- particulas: penas soltas (dano/morte), folhas no vento (chefe), penas roxas e fogos-fatuos (atroz)
    S.add_motes(rig, "feather", [(0.0, 0.0, 0.5)] * 6, ["crow", "crow_face"] if not boss else ["crow", "fur_white"],
                size=0.03, parent=root)
    S.hide_motes(rig, "feather")
    if boss:
        spots = [(0.55 * math.cos(math.tau * k / 6), 0.45 * math.sin(math.tau * k / 6), 0.35 + 0.25 * (k % 3))
                 for k in range(6)]
        S.add_motes(rig, "leaf", spots, ["leaf_g", "leaf_o"] if not night else ["wisp_v", "wisp_c"], size=0.026,
                    parent=root)
        S.add_motes(rig, "gust", [(0.0, 0.0, 0.5)] * 8, ["wind", "leaf_g"] if not night else ["wisp_v", "cold"],
                    size=0.04, parent=root)
        S.hide_motes(rig, "gust")
    if night:
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _wings(rig, ax, az=0.0):
    """ax > 0 = asas para tras; az > 0 = abre para os lados (bate-asa)."""
    for nm, sg in (("L", 1), ("R", -1)):
        w = rig.n(f"wing{nm}")
        w.rotation_euler.x += ax
        w.rotation_euler.y += -az * sg


def _bwings(rig, a):
    for nm, sg in (("L", 1), ("R", -1)):
        if f"bwing{nm}" in rig.nodes:
            rig.n(f"bwing{nm}").rotation_euler.y += -a * sg


def _jaw(rig, o):
    rig.n("jaw").rotation_euler.x += 0.5 * o


def _feathers(rig, u, origin, spread=1.0):
    vel = [(0.5 * math.cos(k * 1.9) * spread, 0.4 * math.sin(k * 1.9) * spread, 0.6 + 0.15 * (k % 3)) for k in range(6)]
    S.splash(rig, "feather", u, origin, vel, g=0.9, shrink=0.55, floor=0.15)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    boss, night = stage >= 3, stage == 4
    D = _dims(stage)
    hc = D["HC"]
    if boss:
        S.motes(rig, "leaf", t, rise=0.08, orbit=1.0)
        _bwings(rig, 0.06 * math.sin(math.tau * t))
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(root, 1.0 + 0.04 * s)
        head.location.z += 0.01 * math.sin(math.tau * (t - 0.15))
        # passarinho: vira a cabeca de lado aos trancos
        head.rotation_euler.z = [0, 0, 0.18, 0.18, 0.18, 0, -0.12, 0][i]
        rig.n("crest").rotation_euler.x = 0.12 * math.sin(math.tau * (t - 0.25))
        _wings(rig, 0.0, 0.06 * max(0.0, s))
        rig.n("tail").rotation_euler.x = -0.1 * s
        rig.n("scarft").rotation_euler.z = 0.15 * math.sin(math.tau * t)
        if i == n - 2:
            S.blink(rig, 1.0)
        if boss:
            rig.n("fan").rotation_euler.y = 0.12 * math.sin(math.tau * t)   # abana o leque
        if night:
            _jaw(rig, 0.2 + 0.15 * max(0, s))
    elif anim == "walk":
        # passinhos rapidos com quique duplo, cabeca de pombo (vai e volta), asas meio abertas no equilibrio
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.035 * b
        R.squash(root, 1.0 + 0.05 * (b - 0.5))
        root.rotation_euler.y = 0.07 * math.sin(math.tau * t)
        for nm, off in (("L", 0.0), ("R", 0.5)):
            lg = rig.n(f"leg{nm}")
            a = math.sin(math.tau * (t + off))
            lg.rotation_euler.x = -0.6 * a
            lg.location.z += 0.04 * max(0.0, math.sin(math.tau * (t + off) + math.pi / 2))
        head.location.y += -0.03 * math.sin(math.tau * 2 * t)
        head.rotation_euler.x += 0.05 * math.sin(math.tau * 2 * t)
        _wings(rig, 0.1, 0.2 + 0.1 * math.sin(math.tau * 2 * t))
        rig.n("tail").rotation_euler.z = 0.2 * math.sin(math.tau * t)
        rig.n("scarft").rotation_euler.z = 0.3 * math.sin(math.tau * t + 1.0)
    elif anim == "attack":
        if not boss:
            _attack_peck(rig, i)
        else:
            _attack_fan(rig, i, night)
    elif anim == "hit":
        R.squash(root, [0.82, 1.1, 0.95, 1.02][i])
        if i == 0:
            R.tilt(root, -0.14, 0.12); S.blink(rig, 0.85); _jaw(rig, 0.8)
            _wings(rig, -0.3, 0.9)
            head.rotation_euler.x += 0.2
        elif i == 1:
            R.tilt(root, 0.05, -0.1); S.blink(rig, 0.5); _jaw(rig, 0.4); _wings(rig, -0.1, 0.5)
        rig.n("crest").rotation_euler.x = [-0.4, 0.3, -0.1, 0][i]
        _feathers(rig, [0.15, 0.4, 0.65, 0.9][i], Vector((0, -0.05, hc.z - 0.15)))
    elif anim == "death":
        _death(rig, i, stage)


def _attack_peck(rig, i):
    """s1: recua a cabeca e abre as asas, bicada para a frente com o bico aberto, volta."""
    root, head = rig.root, rig.n("head")
    R.squash(root, [0.88, 0.82, 1.14, 0.92, 1.0, 1.04, 0.98, 1.0][i])
    tl = [-0.14, -0.2, 0.34, 0.4, 0.28, 0.12, 0.04, 0.0][i]
    R.tilt(root, tl, 0.1 if tl < 0 else -0.08)
    _wings(rig, [0.2, 0.3, -0.4, -0.3, -0.1, 0.0, 0.0, 0.0][i], [0.6, 1.0, 1.2, 0.8, 0.5, 0.3, 0.1, 0][i])
    head.location.y += [0.03, 0.05, -0.06, -0.08, -0.05, -0.02, 0, 0][i]
    _jaw(rig, [0.2, 0.5, 1.0, 0.3, 0.0, 0.4, 0.1, 0][i])
    if i < 2:
        S.blink(rig, [0.3, 0.5][i])
    rig.n("crest").rotation_euler.x = [0.3, 0.45, -0.3, -0.35, -0.2, 0, 0, 0][i]


def _attack_fan(rig, i, night):
    """Chefe: ergue o leque (asa direita) por cima da cabeca, varre o ar na diagonal e solta a rajada (vento + folhas)."""
    root, head = rig.root, rig.n("head")
    wr, wl = rig.n("wingR"), rig.n("wingL")
    R.squash(root, [0.92, 1.08, 1.1, 0.9, 0.95, 1.0, 1.0, 1.0][i])
    # asa direita: sobe (x negativo = para a frente/cima, y abre)
    wr.rotation_euler.x += [-0.8, -2.2, -1.6, -0.6, -0.4, -0.3, -0.1, 0.0][i]
    wr.rotation_euler.y += [0.4, 0.6, 0.2, -0.5, -0.6, -0.4, -0.1, 0.0][i]
    wr.rotation_euler.z += [0.0, -0.2, 0.3, 0.7, 0.6, 0.4, 0.1, 0.0][i]
    wl.rotation_euler.y += -[0.5, 0.8, 0.5, 0.3, 0.3, 0.2, 0.1, 0.0][i]
    _bwings(rig, [0.3, 0.6, 0.4, -0.1, 0.0, 0.1, 0.05, 0.0][i])
    R.tilt(root, [-0.08, -0.14, 0.1, 0.22, 0.18, 0.1, 0.04, 0.0][i], 0.1 if i < 2 else -0.1)
    root.rotation_euler.z += [0.1, 0.2, 0.0, -0.25, -0.2, -0.1, 0.0, 0.0][i]
    _jaw(rig, [0.1, 0.4, 0.8, 1.0, 0.6, 0.3, 0.1, 0.0][i])
    if i < 2:
        S.blink(rig, 0.3)
    # rajada: vento e folhas para a frente
    u = [0, 0, 0, 0.15, 0.35, 0.55, 0.75, 0][i]
    vel = [(-0.4 + 0.11 * k, -0.7 - 0.08 * (k % 3), 0.25 + 0.12 * (k % 4)) for k in range(8)]
    S.splash(rig, "gust", u, Vector((0.05, -0.2, 0.55)), vel, g=0.3, shrink=0.4, floor=0.15)
    S.motes(rig, "leaf", [0, 0.05, 0.1, 0.25, 0.4, 0.55, 0.7, 0.85][i], rise=0.1, orbit=1.0,
            orbit_r=[0, 0, 0, 0.2, 0.3, 0.2, 0.1, 0][i])


def _death(rig, i, stage):
    """Bate as asas fraco, gira e tomba de lado; penas soltas flutuando; fica com olhos fechados e asa aberta."""
    root, head = rig.root, rig.n("head")
    hc = _dims(stage)["HC"]
    R.squash(root, [0.84, 1.08, 1.0, 0.95, 0.9, 1.02, 0.98, 1.0][i])
    roll = [0.0, 0.15, 0.4, 0.9, 1.35, 1.45, 1.42, 1.42][i]
    root.rotation_euler.y += roll
    # pivo no pe esquerdo (+X): o corpo deita para o lado sem afundar no chao
    px = 0.12 if stage == 1 else 0.17
    root.location.x += px - px * math.cos(roll)
    root.location.z += px * math.sin(roll)
    root.location.x -= (0.3 if stage == 1 else 0.45) * (roll / 1.42)   # deitado: centra o corpo no quadro
    root.location.z += [0, 0.04, 0.06, 0.02, 0.0, 0.03, 0.0, 0.0][i]
    _wings(rig, [-0.2, -0.5, -0.2, 0.0, 0.0, 0.0, 0.0, 0.0][i], [0.8, 1.0, 0.5, 0.3, 0.45, 0.55, 0.5, 0.5][i])
    S.blink(rig, 0.85 if i == 0 else (0.5 if i < 3 else 1.0))
    _jaw(rig, [0.8, 0.5, 0.6, 0.5, 0.4, 0.3, 0.3, 0.3][i])
    rig.n("crest").rotation_euler.x = [-0.3, 0.2, 0.3, 0.4, 0.5, 0.5, 0.5, 0.5][i]
    _feathers(rig, [0.1, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 0][i], Vector((0, -0.05, hc.z - 0.1)), spread=0.8)
