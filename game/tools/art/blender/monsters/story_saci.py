"""Saci Atroz (story_saci) — chefe da historia, Arco 1 cap. 1 (ARCO-1-TERRA-DO-SABIA.md). So existe na forma atroz
(estagio 4, quadro 240): o Saci tomado pela corrupcao de Erevos.
Menino chibi de uma perna so, de calcao, de pe dentro de um redemoinho escuro de fitas de fumaca (o menino e a
figura principal; o vento e um anel em volta da perna — diferente do prank_whirlwind, que e o proprio tornado com
rosto). Gorro vermelho EM BRASA com a ponta pegando o fogo corrompido (preto nas pontas, borda violeta) e fumaca
preta subindo; olhos de brasa, sobrancelha de arteiro bravo, sorriso de dentes. Palha e folhas secas giram no vento.
Sem cachimbo.
  idle: o redemoinho gira, o menino flutua no vento e balanca, o fogo do gorro tremula, pisca;
  walk: pulinhos numa perna so (quique duplo, squash no apoio);
  attack: agacha, sobe girando no redemoinho (que abre), despenca;
  hit: achata, aperta os olhos, o gorro dobra;
  death: o vento desmancha, ele gira, cai sentado e o gorro voa e apaga (no arco ele cai sem o gorro).
Modelo proprio por script; regras de pixel art do stone_armadillo.py / sol_common.py."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_lote1 as C

SCALE = {4: 2.25}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 8.0
HEAD_TILT = -0.42

HC = Vector((0, -0.03, 0.98))
HR = (0.27, 0.235, 0.255)
BC = Vector((0, 0.0, 0.62))
BR = (0.13, 0.105, 0.15)
HIP = 0.44
SPIRAL = 3


def build(stage=4):
    if stage not in STAGES:
        raise ValueError("story_saci: so o estagio 4 (atroz)")
    R.reset()
    R.CUR["reach"] = (0.3, 0.3, 0.32)
    rig = R.Rig("story_saci")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # ---- redemoinho: fitas em espiral em volta da perna (pivo proprio, gira no idle)
    whirl = rig.empty("whirl", (0, 0, 0), root)
    for k in range(SPIRAL):
        a0 = math.tau * k / SPIRAL
        z0, z1 = 0.02 + 0.03 * k, 0.5 + 0.04 * (k % 2)

        def fn(u, v, a0=a0, z0=z0, z1=z1, k=k):
            a = a0 + 1.35 * math.tau * u
            z = z0 + (z1 - z0) * u
            r = 0.07 + 0.36 * (u ** 0.85)
            w = (0.035 + 0.05 * u) * (1 - 0.5 * abs(2 * u - 1) ** 3)
            zz = z + (v - 0.5) * w
            return Vector((r * math.cos(a), r * math.sin(a) * 0.92, zz))
        rig.add_mesh(R.surface(f"rib{k}", fn, 48, 2, (0, 0, 0.25)), f"rib{k}", "whirl_n" if k % 2 == 0 else "whirl_d_n",
                     whirl, group="whirl")
    # palha e folhas secas girando no vento + fumaca preta subindo do redemoinho
    spots = []
    for k in range(7):
        a = math.tau * k / 7
        spots.append((0.38 * math.cos(a), 0.34 * math.sin(a), 0.12 + 0.06 * (k % 3) + 0.04 * k))
    S.add_motes(rig, "debris", spots, ["straw_n", "cf_tip", "straw_n", "cf_smoke2"], size=0.022, parent=root)
    C.smoke(rig, "wsmoke", [(0.3 * math.cos(a), 0.25 * math.sin(a), 0.42) for a in (0.3, 2.1, 3.9, 5.2)], root, size=0.04)
    # ---- perna unica (a outra nao existe: calcao fechado do lado direito)
    leg = rig.empty("leg", (0.03, 0.0, HIP), root)
    C.limb(rig, "thigh", (0.04, 0.0, HIP + 0.02), (0.03, -0.02, 0.24), 0.062, 0.048, "saci_skin_n", leg, group="leg")
    C.limb(rig, "shin", (0.03, -0.02, 0.26), (0.02, 0.0, 0.06), 0.048, 0.04, "saci_skin_n", leg, group="leg")
    C.ell(rig, "foot", (0.02, -0.05, 0.035), (0.06, 0.09, 0.035), "saci_skin_n", leg, group="leg")
    for c in (-1, 0, 1):
        C.ell(rig, f"toe{c}", (0.02 + 0.03 * c, -0.13, 0.03), (0.02, 0.022, 0.018), "saci_skin_n", leg, part="toes",
              group="leg")
    body = rig.empty("body", (0, 0.0, HIP), root)
    # calcao (rasgado embaixo) e tronco
    C.ell(rig, "shorts", (0, 0.0, HIP + 0.03), (0.15, 0.12, 0.1), "saci_short_n", body)
    for k in range(5):
        a = -math.pi / 2 + (k - 2) * 0.5
        b = Vector((0.14 * math.cos(a), 0.11 * math.sin(a), HIP - 0.03))
        C.limb(rig, f"rag{k}", b, b + Vector((0.01 * math.cos(a), 0.02 * math.sin(a), -0.07)), 0.03, 0.004,
               "saci_short_n", body, group="shorts_rag", seg=5, rings=1)
    C.ell(rig, "stump", (-0.075, -0.0, HIP - 0.04), (0.055, 0.055, 0.045), "saci_short_n", body)
    C.ell(rig, "torso", BC, BR, "saci_skin_n", body, group="torso")
    C.ell(rig, "belly", BC + Vector((0, -0.05, -0.04)), (0.1, 0.07, 0.09), "saci_skin_n", body, group="torso")
    # bracos (mao aberta de arteiro)
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.13 * sx, BC.y, BC.z + 0.08))
        arm = rig.empty(f"arm{nm}", sp, body)
        hp = sp + Vector((0.12 * sx, -0.05, -0.17))
        C.limb(rig, f"arm{nm}", sp, hp, 0.042, 0.034, "saci_skin_n", arm, group=f"arm{nm}", bend=(0.02 * sx, 0, 0))
        C.ell(rig, f"hand{nm}", hp, (0.048, 0.04, 0.05), "saci_skin_n", arm, group=f"arm{nm}")
        for c in (-1, 0, 1):
            b = hp + Vector((0.022 * c, -0.02, -0.03))
            C.limb(rig, f"fing{nm}{c}", b, b + Vector((0.012 * c, -0.025, -0.045)), 0.016, 0.01, "saci_skin_n", arm,
                   group=f"arm{nm}", seg=6, rings=1)
    # ---- cabecona
    head = rig.empty("head", (0, HC.y + 0.02, HC.z - HR[2] * 0.85), body)
    C.ell(rig, "head", HC, HR, "saci_skin_n", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        C.ell(rig, f"ear{nm}", (HR[0] * 0.98 * sx, HC.y + 0.02, HC.z - 0.02), (0.045, 0.03, 0.06), "saci_skin_n", head,
              rot=(0, 0.3 * sx, 0), part="ears")
    # cabelo curtinho crespo aparecendo embaixo do gorro (calombinhos)
    for k in range(9):
        a = math.pi * (0.05 + 0.9 * k / 8)
        p = HC + Vector((HR[0] * 0.9 * math.cos(a), HR[1] * 0.75 * math.sin(a), HR[2] * 0.38))
        C.ell(rig, f"curl{k}", p, (0.045, 0.045, 0.035), "saci_hair_n", head, part="hair", group="hair")
    # olhos de brasa, sobrancelha de arteiro bravo
    rz = 0.15
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.115 * sx, HC.z - 0.005
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.014, ez))
        C.glow_eye(rig, nm, ep, head, 0.098, rz, -0.45 * sx)
        S.brow(rig, nm, ep, head, rz / 0.145, 0.085, mat="brow", thick=1.3, width=1.0, lift=0.0, prio=3.0)
    # sorriso arteiro de dentes (meio torto)
    mz = HC.z - 0.14
    my = S.ysurf(HC, HR, 0.02, mz)
    mouth = rig.empty("mouth", (0.02, my, mz), head)
    C.ell(rig, "mouth", (0.02, my + 0.004, mz), (0.1, 0.02, 0.04), "mouth_in", mouth, rot=(0, -0.12, 0),
          noline=True, unlit=True, prio=2.0)
    C.teeth(rig, "tooth", (0.02, my - 0.012, mz + 0.03), 0.17, 6, mouth, h=0.034, r=0.015)
    C.teeth(rig, "toothlo", (0.02, my - 0.01, mz - 0.034), 0.12, 4, mouth, h=0.026, r=0.013, down=False)
    # ---- gorro em brasa: copa sobre a cabeca + ponta comprida dobrando para tras, fogo corrompido na ponta
    capp = rig.empty("cap", HC + Vector((0, 0, HR[2] * 0.6)), head)

    def edge(ph):
        return 0.9 - 0.18 * S.front_w(ph, 1.2) + S.zigzag(ph, 14, 0.03)
    rig.add_mesh(S.cap("capdome", HC + Vector((0, 0.03, 0.02)), (HR[0] * 0.98, HR[1] * 1.0, HR[2] * 1.02), 0.0, edge,
                       lift=1.04), "capdome", "saci_cap_n", capp, group="cap")
    tipb = rig.empty("captip", HC + Vector((0, 0.06, HR[2] * 0.95)), capp)
    t0 = HC + Vector((0, 0.04, HR[2] * 0.8))
    t1 = t0 + Vector((0.08, 0.17, 0.13))
    t2 = t1 + Vector((0.13, 0.08, -0.03))
    C.limb(rig, "cone1", t0, t1, 0.15, 0.075, "saci_cap_n", tipb, group="cap", bend=(0, -0.03, 0.04), seg=14)
    C.limb(rig, "cone2", t1, t2, 0.075, 0.03, "saci_cap_n", tipb, group="cap", bend=(0, 0, 0.03), seg=12)
    # brasas acesas na costura do gorro (rachaduras)
    for k, (u, a) in enumerate(((0.3, 0.2), (0.6, -0.4), (0.8, 0.5))):
        p = t0 + (t1 - t0) * u + Vector((0.07 * math.cos(a) * (1 - u), -0.09 * (1 - u * 0.4), 0.02))
        C.ell(rig, f"seam{k}", p, (0.022, 0.012, 0.03), "ember_core", tipb, part="seam", noline=True, unlit=True, prio=2.5)
    C.corrupt_flame(rig, "capfire", t2 + Vector((0.01, 0.0, -0.01)), tipb, size=1.2, n=5, spread=0.8, up=(0.25, 0.25, 1),
                    base_mat="ember", height=1.0)
    C.smoke(rig, "csmoke", [t2 + Vector((0.03 * math.cos(k * 2.1), 0.03 * math.sin(k * 2.1), 0.14)) for k in range(5)],
            tipb, size=0.035)
    head.rotation_euler.x += HEAD_TILT
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _arms(rig, ax, az=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg


def _wind(rig, t, spin=1.0, k=1.0, smoke=True):
    w = rig.n("whirl")
    w.rotation_euler.z = math.tau * spin * t / SPIRAL * SPIRAL
    w.scale = (max(k, 0.0001), max(k, 0.0001), max(k, 0.0001))
    S.motes(rig, "debris", t, rise=0.06, orbit=1.0 * spin, orbit_r=0.0)
    if k < 0.01:
        S.hide_motes(rig, "debris")
    if smoke:
        S.motes(rig, "wsmoke", t, rise=0.25, spread=1.0)
    else:
        S.hide_motes(rig, "wsmoke")


def pose(rig, anim, i, n, stage=4):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    cap = rig.n("captip")
    C.flicker(rig, "capfire", t)
    S.motes(rig, "csmoke", t, rise=0.3, spread=0.8)
    if anim == "idle":
        s = math.sin(math.tau * t)
        _wind(rig, t)
        root.location.z += 0.02 + 0.02 * s
        R.squash(root, 1.0 + 0.03 * math.sin(math.tau * (t + 0.25)))
        body.rotation_euler.y = 0.06 * math.sin(math.tau * t)
        head.rotation_euler.y = 0.08 * math.sin(math.tau * (t - 0.15))
        head.location.z += 0.008 * math.sin(math.tau * (t - 0.2))
        _arms(rig, (0.15 * s, -0.15 * s), 0.2)
        cap.rotation_euler.y = 0.08 * math.sin(math.tau * (t - 0.3))
        rig.n("mouth").scale.z = 1.0 + 0.15 * max(0, s)
        if i == 6:
            S.blink(rig, 0.95)
    elif anim == "walk":
        # dois pulinhos por ciclo numa perna so
        u = (2 * t) % 1.0
        hop = math.sin(math.pi * u)
        root.location.z += 0.1 * hop
        R.squash(root, [0.86, 1.08, 1.1, 1.04, 1.0, 1.02, 1.04, 0.92][int(u * 8) % 8])
        rig.n("leg").rotation_euler.x = 0.3 * math.sin(math.tau * u) - 0.1
        root.rotation_euler.x += 0.08 * hop
        _arms(rig, (-0.5 * hop, 0.4 * hop), 0.35 * hop)
        _wind(rig, t, spin=1.0, k=0.85)
        cap.rotation_euler.x = -0.25 * hop
        head.rotation_euler.y = 0.06 * math.sin(math.tau * t)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        _wind(rig, t * 0.5)
        sq = [0.82, 1.1, 0.96, 1.02][i]
        R.squash(root, sq)
        R.tilt(root, [-0.18, 0.08, -0.03, 0.0][i], 0.12)
        S.blink(rig, [0.9, 0.6, 0.2, 0.0][i])
        _arms(rig, [-1.0, -0.6, -0.2, 0.0][i], [0.6, 0.4, 0.2, 0.1][i])
        cap.rotation_euler.x = [0.5, -0.3, 0.15, 0.0][i]
        rig.n("mouth").scale = (0.7, 1, 1.6)
        C.flicker(rig, "capfire", t, k=[1.4, 1.2, 1.05, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Agacha, sobe girando no redemoinho aberto, despenca."""
    root, head = rig.root, rig.n("head")
    cap = rig.n("captip")
    up = [0.0, -0.02, 0.12, 0.22, 0.26, 0.2, 0.0, 0.0][i]
    spin = [0.0, -0.15, 0.6, 1.6, 2.6, 3.4, 4.0, 4.0][i]   # voltas (mod 1 no ultimo = de frente)
    root.location.z += up
    root.rotation_euler.z += math.tau * spin / 4.0 if i in (2, 3, 4, 5) else 0.0
    R.squash(root, [0.82, 0.76, 1.18, 1.12, 1.08, 1.0, 0.74, 1.02][i])
    _arms(rig, [0.6, 0.8, -0.9, -1.4, -1.5, -1.2, -0.4, 0.0][i], [0.2, 0.3, 1.0, 1.3, 1.3, 1.0, 0.5, 0.2][i])
    k = [1.0, 0.9, 1.25, 1.45, 1.55, 1.45, 1.6, 1.15][i]
    rig.n("whirl").rotation_euler.z = math.tau * i / 8 * 2
    rig.n("whirl").scale = (k, k, [1.0, 0.9, 1.3, 1.45, 1.5, 1.35, 0.7, 0.95][i])
    S.motes(rig, "debris", i / 8 * 2, rise=0.1, orbit=1.0, orbit_r=0.12 * (k - 1))
    S.motes(rig, "wsmoke", i / 8, rise=0.3)
    if i < 2:
        S.blink(rig, 0.4)
        head.rotation_euler.x += 0.08
    rig.n("mouth").scale = (1.15, 1, [1.0, 1.2, 1.6, 1.6, 1.5, 1.4, 1.9, 1.2][i])
    cap.rotation_euler.x = [0.0, 0.1, -0.5, -0.6, -0.55, -0.4, 0.4, 0.1][i]
    C.flicker(rig, "capfire", i / 8, amp=1.4, k=[1.0, 1.0, 1.25, 1.4, 1.4, 1.3, 1.5, 1.1][i])


def _death(rig, i):
    """O vento desmancha, ele gira, cai de costas e o gorro voa, cai ao lado e apaga."""
    root, head = rig.root, rig.n("head")
    capp = rig.n("cap")
    k = [1.0, 0.7, 0.4, 0.15, 0.0, 0.0, 0.0, 0.0][i]
    _wind(rig, i / 8, k=k, smoke=i < 3)
    if i < 4:
        root.rotation_euler.z += math.tau * [0.0, 0.2, 0.5, 0.85][i]
        root.location.z += [0.0, 0.06, 0.08, 0.04][i]
        R.squash(root, [0.84, 1.06, 1.04, 1.0][i])
        S.blink(rig, [0.9, 0.7, 0.7, 0.8][i])
        _arms(rig, [-0.9, -1.3, -1.4, -1.0][i], [0.6, 1.1, 1.2, 0.8][i])
    else:
        fall = [-0.9, -1.35, -1.3, -1.32][i - 4]
        R.tilt(root, fall, 0.28)
        root.location.y -= 0.8 * min(1.0, -fall / 1.0)
        root.location.z += [0.06, 0.0, 0.02, 0.0][i - 4]
        S.blink(rig, 1.0)
        _arms(rig, -0.9, 0.9)
        rig.n("leg").rotation_euler.x += -0.6
    rig.n("mouth").scale = (0.6, 1, [1.6, 1.4, 1.2, 1.0, 0.9, 0.7, 0.6, 0.6][i])
    # gorro voa para o lado e cai no chao (sai do pivo da cabeca: compensa com deslocamento grande)
    if i >= 2:
        u = min(1.0, (i - 2) / 4)
        # deslocamento pensado no mundo (para o lado e ate o chao), levado para o espaco da cabeca inclinada
        from mathutils import Matrix
        fall = 0.0 if i < 4 else [-0.9, -1.35, -1.3, -1.32][i - 4]
        d = Vector((0.32 * u, -0.05 * u, 0.2 * math.sin(math.pi * u) - 0.55 * u))
        capp.location += Matrix.Rotation(-(fall + HEAD_TILT), 3, 'X') @ d
        capp.rotation_euler.y += -1.2 * u
        capp.rotation_euler.x += 0.6 * u
    C.flicker(rig, "capfire", i / 8, k=[1.2, 1.0, 0.8, 0.5, 0.25, 0.0, 0.0, 0.0][i])
    if i >= 5:
        S.hide_motes(rig, "csmoke")
