"""Boitata Atroz (story_boitata) — chefe FINAL do Arco 1 (Caverna do Reino Encoberto, andar 5).
A serpente de fogo que protegia os campos das queimadas, corrompida e enterrada por Erevos; so existe na forma atroz
(estagio 4, a noite). O mais imponente dos chefes da historia, sem virar dragao generico (sem asas, sem patas, sem
chifres de dragao): escamas negras, o corpo faz um arco alto por tras da cabeca (silhueta de "portal de fogo"),
VARIOS OLHOS acesos ao longo do corpo (piscam em sequencia), o corpo todo envolto em fogo vivo (miolo amarelo-claro,
amarelo, laranja-avermelhado) cujas PONTAS ficaram pretas com borda violeta (a corrupcao): coroa de labaredas por fora
do arco, juba de fogo na cabeca, fogo nas costas do pescoco e na cauda; juntas das escamas em brasa, barriga quente. Cabecona chibi expressiva: dois olhos grandes
de brasa com brilho, sobrancelhas de escama, focinho curto, presas.
  idle: o arco respira, os olhos do corpo piscam um de cada vez, a juba e a crista tremulam;
  walk: as voltas deslizam em onda; attack: recua e sopra fogo em leque (3 jorros) para a frente;
  hit: recua, olhos apertados;
  death: ele NAO morre — adormece: as chamas negras apagam, os olhos do corpo fecham um a um, a cabeca deita sobre
  as voltas, e no fim acende uma chaminha laranja de verdade no alto da cabeca (o fogo dele de volta).
Modelo proprio por script; rosto no desenho do Tatu-Pedra (sol_common)."""
import math
from mathutils import Vector, Matrix
import mon_rig as R
import sol_common as S
import story_common_l2 as C

SCALE = {4: 2.1}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 6.0
HEAD_TILT = -0.5

NECK = [(0.0, -0.26, 0.14), (0.0, -0.33, 0.36), (0.0, -0.3, 0.58), (0.0, -0.2, 0.78), (0.0, -0.17, 0.95),
        (0.0, -0.22, 1.08)]
NECK_R = [0.2, 0.19, 0.175, 0.16, 0.15, 0.14]
COIL = [(0.0, -0.26, 0.14), (0.3, -0.2, 0.15), (0.5, 0.0, 0.17), (0.5, 0.24, 0.3), (0.36, 0.38, 0.58), (0.12, 0.44, 0.84),
        (-0.14, 0.44, 0.84), (-0.38, 0.36, 0.55), (-0.5, 0.18, 0.24), (-0.46, -0.06, 0.13), (-0.3, -0.24, 0.1),
        (-0.12, -0.36, 0.08)]
COIL_R = [0.2, 0.2, 0.195, 0.185, 0.175, 0.165, 0.15, 0.135, 0.12, 0.1, 0.08, 0.06]
HC = Vector((0.0, -0.32, 1.22))
HR = (0.38, 0.32, 0.26)


def _frame(a, b, out_hint):
    d = (b - a).normalized()
    o = (out_hint - d * out_hint.dot(d))
    if o.length < 1e-4:
        o = Vector((0, 0, 1)) - d * d.z
    o.normalize()
    return d, o


def build(stage):
    if stage not in STAGES:
        raise ValueError("so a forma atroz (4)")
    R.reset()
    R.CUR["reach"] = (0.6, 0.6, 0.65)
    rig = R.Rig("story_boitata")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", (0, 0.05, 0.1), root)
    # ---- corpo: voltas no chao que sobem num arco alto por tras e voltam pela esquerda ate a cauda
    rig.coil = C.chain(rig, "coil", COIL, COIL_R, body, "scale_black_l2", ring_mat="ember")
    rig.neck = C.chain(rig, "neck", NECK, NECK_R, body, "scale_black_l2", belly=(0, -1, 0.1), belly_mat="leaf_o",
                       ring_mat="ember")
    center = Vector((0, 0.1, 0.3))
    # placas da barriga (violeta) no lado de dentro/baixo do arco e listras de brasa apagada entre as escamas
    for i in range(len(COIL) - 1):
        a, b = Vector(COIL[i]), Vector(COIL[i + 1])
        m = (a + b) * 0.5
        d, o = _frame(a, b, center - m)
        rr = (COIL_R[i] + COIL_R[i + 1]) * 0.5
        x = d.cross(o).normalized()
        M = Matrix((x, o, d)).transposed()
        rig.add_mesh(R.ellipsoid(f"cbelly{i}", m + o * rr * 0.72, (rr * 0.6, rr * 0.35, (b - a).length * 0.5),
                                 rot=M.to_euler()), f"cbelly{i}", "leaf_o", rig.n(rig.coil[i]))
    # ---- olhos ao longo do corpo (por fora do arco), acesos, com palpebra de escama
    rig.beyes = []
    for k, (i, side) in enumerate(((2, 1), (4, 1), (5, 1), (7, -1), (8, -1), (3, 1), (6, -1))):
        a, b = Vector(COIL[i]), Vector(COIL[i + 1])
        m = a + (b - a) * 0.45
        d, o = _frame(a, b, (m - center) * 0.4 + Vector((0, -1.0, 0.5)))
        rr = COIL_R[i] * 0.98
        p = m + o * rr
        piv = rig.empty(f"beye{k}", p, rig.n(rig.coil[i]))
        x = d.cross(o).normalized()
        M = Matrix((x, d, o)).transposed()   # z local = normal para fora
        rot = M.to_euler()
        s = 0.095 if k < 5 else 0.075
        rig.add_mesh(R.ellipsoid(f"beyeb{k}", p, (s * 1.25, s, s * 0.5), rot=rot), "beye_ball", "eye_ember", piv, unlit=True,
                     noline=True, prio=2.6)
        rig.add_mesh(R.ellipsoid(f"beyec{k}", p + o * s * 0.3, (s * 0.55, s * 0.6, s * 0.35), rot=rot), "beye_core",
                     "ember_core", piv, unlit=True, noline=True, prio=3.2)
        rig.add_mesh(R.ellipsoid(f"beyep{k}", p + o * s * 0.42, (s * 0.12, s * 0.5, s * 0.2), rot=rot), "beye_pupil",
                     "eye_slit", piv, unlit=True, noline=True, prio=3.6)
        rig.add_mesh(R.ellipsoid(f"beyeh{k}", p + o * s * 0.5 + x * s * 0.35 + d * s * 0.2, (s * 0.22,) * 3), "beye_hl",
                     "white", piv, unlit=True, noline=True, prio=5.0)
        # palpebra (casca de escama que fecha por cima): escala z do pivo 'beyelid' de 0 a 1
        lid = rig.empty(f"beyelid{k}", p, rig.n(rig.coil[i]))
        rig.add_mesh(R.ellipsoid(f"beyel{k}", p + o * s * 0.15, (s * 1.4, s * 1.15, s * 0.6), rot=rot), "beye_lid",
                     "scale_black_l2", lid, prio=6.0)
        rig.beyes.append((f"beye{k}", f"beyelid{k}"))
    # ---- o corpo inteiro envolto em fogo vivo (pontas pretas com borda violeta = corrupcao): coroa de labaredas
    # por fora do arco e das voltas, fogo na cauda e nas costas do pescoco
    for j, i in enumerate(range(1, 11)):
        a, b = Vector(COIL[i]), Vector(COIL[i + 1])
        m = (a + b) * 0.5
        d, o = _frame(a, b, Vector((m.x, (m.y - center.y) * 0.5, m.z - center.z)) + Vector((0, 0.15, 0.25)))
        up = (o * 0.55 + Vector((0, 0.1, 1.0))).normalized()
        h = 0.3 + 0.08 * math.sin(j * 1.9) ** 2 + (0.1 if i in (4, 5, 6) else 0.0)
        C.fire_flame(rig, f"afl{j}", m + o * COIL_R[i] * 0.55 + Vector((0, COIL_R[i] * 0.45, 0)), up, h, 0.11 + 0.02 * (i in (4, 5, 6)), rig.n(rig.coil[i]),
                     phase=0.13 * j, bend=0.35 if m.x >= 0 else -0.35)
    tip = Vector(COIL[-1])
    C.fire_flame(rig, "tailfl", tip + Vector((0.0, -0.02, 0.02)), (-0.3, -0.4, 1.0), 0.3, 0.08, rig.n(rig.coil[-1]),
                 phase=0.7, bend=-0.4)
    for j, i in enumerate((1, 2, 3)):
        a, b = Vector(NECK[i]), Vector(NECK[i + 1])
        m = (a + b) * 0.5 + Vector((0, NECK_R[i] * 0.7, 0))
        C.fire_flame(rig, f"nfl{j}", m, (0, 0.8, 1.0), 0.28, 0.1, rig.n(rig.neck[i]), phase=0.3 + 0.2 * j, bend=0.3)
    # ---- cabecona chibi
    top = rig.n(rig.neck[-1])
    head = rig.empty("head", Vector(NECK[-1]) + Vector((0, 0, 0.03)), top)
    rig.add_mesh(R.ellipsoid("head", HC, HR, seg=28, rings=16), "head", "scale_black_l2", head, group="head")
    rig.add_mesh(R.ellipsoid("snout", HC + Vector((0, -0.2, -0.08)), (0.24, 0.15, 0.12)), "head", "scale_black_l2", head,
                 group="head")
    jaw = rig.empty("jaw", HC + Vector((0, 0.05, -0.1)), head)
    rig.add_mesh(R.ellipsoid("jawm", HC + Vector((0, -0.1, -0.13)), (0.23, 0.18, 0.07)), "jaw", "leaf_o", jaw)
    rig.add_mesh(R.ellipsoid("mouthin", HC + Vector((0, -0.13, -0.1)), (0.19, 0.13, 0.04)), "mouthin", "ember", jaw,
                 noline=True, unlit=True, prio=0.9)
    for sx in (1, -1):  # presas
        b = HC + Vector((0.11 * sx, -0.31, -0.12))
        rig.add_mesh(R.cone(f"fang{sx}", b, b + Vector((0.0, -0.01, -0.075)), 0.024, 0.003, seg=6, rings=2), "fang",
                     "fang_n", head, noline=True, prio=2.6)
    for sx in (1, -1):  # narinas que soltam fumaca
        rig.add_mesh(R.ellipsoid(f"nost{sx}", HC + Vector((0.06 * sx, -0.34, -0.01)), (0.018, 0.01, 0.012)), "nost",
                     "bfire_core_l2", head, noline=True, unlit=True, prio=2.0)
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.165 * sx, HC.z + 0.04
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) - 0.012, ez))
        # olho chibi aceso (no corpo preto o olho escuro do Tatu sumiria): globo de brasa clara, iris vermelha
        # embaixo, pupila em fenda, dois brilhos
        rx, rz, rot = 0.135, 0.165, (0.55, 0, -0.45 * sx)
        e = rig.empty(f"eye{nm}", ep, head)
        rig.add_mesh(R.ellipsoid(f"eyeb{nm}", ep, (rx, 0.05, rz), rot=rot), f"eyeb{nm}", "ember_hot", e, noline=True,
                     unlit=True, prio=1.8)
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0, -0.025, -0.04)), (rx * 0.78, 0.03, rz * 0.62), rot=rot),
                     f"iris{nm}", "eye_ember", e, noline=True, unlit=True, prio=2.0)
        rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0, -0.05, -0.035)), (0.02, 0.02, rz * 0.5), rot=rot),
                     f"slit{nm}", "eye_slit", e, noline=True, unlit=True, prio=4.0)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.04 + 0.01 * sx, -0.06, 0.06)), (0.04, 0.02, 0.04)), f"hl{nm}",
                     "white", e, noline=True, unlit=True, prio=7.0)
        rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.04, -0.06, -0.06)), (0.02, 0.012, 0.02)), f"hl2{nm}", "white",
                     e, noline=True, unlit=True, prio=3.0)
        a = ep + Vector((-0.1 * sx, -0.04, 0.15))
        b = ep + Vector((0.13 * sx, 0.04, 0.21))
        rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.026, 0.02, seg=8, rings=1), f"brow{nm}", "leaf_o", head, prio=3.2)
    # juba de fogo em volta da cabeca (no lugar de chifres)
    for j, (ang, h) in enumerate(((-1.25, 0.3), (-0.6, 0.38), (0.0, 0.44), (0.6, 0.38), (1.25, 0.3))):
        p = HC + Vector((math.sin(ang) * HR[0] * 0.85, math.cos(ang) * HR[1] * 0.5 + 0.08, HR[2] * 0.6))
        up = Vector((math.sin(ang) * 0.7, 0.4, 1.0))
        C.fire_flame(rig, f"mfl{j}", p, up, h, 0.1, head, phase=0.21 * j + 0.05, bend=0.35 if ang > 0 else -0.35)
    # chaminha laranja de verdade (so acende no fim da morte: o fogo dele de volta)
    C.black_flame(rig, "truefire", HC + Vector((0, 0.0, HR[2] * 0.9)), (0, 0, 1), 0.22, 0.06, head, phase=0.0, bend=0.3,
                  mats=("ember", "ember_hot", "ember_core"))
    rig.flames = [f for f in rig.flames if f[0] != "truefire"]
    head.rotation_euler.x += HEAD_TILT
    # ---- sopro de fogo em leque (golpe): 3 jorros (esquerda, centro, direita) de linguas que acendem da boca
    rig.breath = []
    mouth = HC + Vector((0, -0.32, -0.12))
    for r_, dx in enumerate((-0.5, 0.0, 0.5)):
        d = Vector((dx, -1.0, -0.55)).normalized()
        for j in range(3):
            p = Vector((0, mouth.y + 0.04, 0.98)) + d * (0.07 + 0.09 * j)
            nm = f"breath{r_}{j}"
            pv = rig.empty(nm, p, root)
            C.fire_flame(rig, f"brf{r_}{j}", p, d + Vector((0, 0, 0.35)), 0.22 + 0.05 * j, 0.08 + 0.025 * j, pv,
                         phase=0.2 * j + r_ * 0.3, bend=0.25 * (1 if dx >= 0 else -1), tip=0.8)
            rig.breath.append(nm)
    rig.flames = [f for f in rig.flames if not f[0].startswith("brf")]
    # ---- particulas: brasas violeta e fumaca preta subindo
    S.add_motes(rig, "rise", [(0.5 * math.cos(k * 1.9), 0.15 + 0.35 * math.sin(k * 1.9), 0.6 + 0.2 * (k % 3))
                              for k in range(8)], ["ember", "ember_hot", "wisp_v"], size=0.025, parent=root)
    S.add_motes(rig, "smoke", [(0.35 * math.cos(k * 2.4), 0.35 + 0.1 * math.sin(k * 2.4), 1.1 + 0.05 * (k % 2))
                               for k in range(6)], ["bfire_l2", "bfire_core_l2"], size=0.05, parent=root)
    rig.save_rest()
    for nm in rig.breath + ["truefire"]:
        rig.n(nm).scale = (0.0001,) * 3
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _mouth(rig, o):
    rig.n("jaw").rotation_euler.x += 0.55 * o


def _body_eyes(rig, t, closed=None):
    """Os olhos do corpo piscam um de cada vez (closed = lista de 0..1 por olho, para a morte)."""
    for k, (ev, lid) in enumerate(rig.beyes):
        if closed is not None:
            c = closed[k]
        else:
            ph = (t * 1.0 + k * 0.37) % 1.0
            c = 1.0 if ph < 0.12 else 0.0
        o = rig.n(lid)
        o.scale = (1.0, 1.0, max(0.0001, c)) if c > 0.02 else (0.0001,) * 3
        if c > 0.6:
            rig.n(ev).scale = (1.0, 1.0, 0.3)


def _breath(rig, u):
    """u 0..1: o jorro avanca (linguas acendem da boca para a frente)."""
    for j, nm in enumerate(rig.breath):
        o = rig.n(nm)
        v = u * 3.2 - (j % 3)
        if v <= 0 or u <= 0:
            o.scale = (0.0001,) * 3
            continue
        s = min(1.0, v) * (1.0 + 0.15 * math.sin(j * 2.1 + u * 9))
        o.scale = (s, s, s)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    if anim != "death":
        S.motes(rig, "rise", t, rise=0.5, spread=1.0)
        S.motes(rig, "smoke", t, rise=0.35, spread=1.5, drift=0.06)
    if anim == "idle":
        R.squash(body, 1.0 + 0.02 * math.sin(math.tau * t))
        C.chain_wave(rig, rig.neck, t, 0.05, axis="y", phase_step=0.8)
        C.chain_wave(rig, rig.neck, t + 0.25, 0.025, axis="x", phase_step=0.6)
        C.chain_wave(rig, rig.coil, t, 0.02, axis="x", phase_step=0.7, start=3)
        head.rotation_euler.y += 0.07 * math.sin(math.tau * t + 0.8)
        _mouth(rig, 0.12 + 0.1 * max(0.0, math.sin(math.tau * 2 * t)))
        _body_eyes(rig, t)
        C.flames(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
    elif anim == "walk":
        C.chain_wave(rig, rig.coil, t, 0.06, axis="z", phase_step=0.9, start=1)
        C.chain_wave(rig, rig.neck, t, 0.08, axis="y", phase_step=0.8)
        body.location.z += 0.02 * abs(math.sin(math.tau * t))
        head.rotation_euler.y -= 0.06 * math.sin(math.tau * t)
        _body_eyes(rig, t)
        C.flames(rig, t, sway=0.22)
    elif anim == "attack":
        back = [0.05, 0.09, 0.1, -0.06, -0.09, -0.07, -0.03, 0.0][i]
        C.chain_bend(rig, rig.neck, back, axis="x", start=1)
        head.rotation_euler.x += [-0.1, -0.15, -0.18, 0.15, 0.2, 0.15, 0.06, 0.0][i]
        _mouth(rig, [0.2, 0.4, 0.5, 1.0, 1.0, 0.9, 0.5, 0.15][i])
        R.squash(body, [1.03, 1.05, 1.07, 0.95, 0.96, 1.0, 1.0, 1.0][i])
        _breath(rig, [0, 0, 0, 0.35, 0.7, 1.0, 0.9, 0][i])
        _body_eyes(rig, t)
        C.flames(rig, t, k=[1.05, 1.1, 1.15, 1.2, 1.18, 1.12, 1.05, 1.0][i])
        if i in (1, 2):
            S.blink(rig, 0.4)
    elif anim == "hit":
        C.chain_bend(rig, rig.neck, [-0.06, 0.02, 0.01, 0.0][i], axis="x")
        R.squash(body, [0.9, 1.05, 0.98, 1.0][i])
        S.blink(rig, [0.9, 0.6, 0.0, 0.0][i])
        _mouth(rig, [0.6, 0.3, 0.1, 0.0][i])
        head.rotation_euler.x += [-0.25, 0.06, 0.0, 0.0][i]
        _body_eyes(rig, 0, closed=[[0.9, 0.5, 0.0, 0.0][i]] * len(rig.beyes))
        C.flames(rig, i / 4.0, k=[1.15, 1.05, 1.0, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _death(rig, i):
    """Adormece: o fogo negro apaga, os olhos do corpo fecham um a um, a cabeca deita sobre as voltas; no fim acende a
    chaminha laranja (o fogo verdadeiro dele de volta)."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    C.flames(rig, i / 8, k=[1.2, 0.95, 0.7, 0.45, 0.22, 0.05, 0.0, 0.0][i])
    S.motes(rig, "smoke", i / 8, rise=0.4, spread=1.4, fade=max(0.0001, 1.0 - i / 4))
    S.hide_motes(rig, "rise")
    nb = len(rig.beyes)
    _body_eyes(rig, 0, closed=[min(1.0, max(0.0, (i - 1 - k * 0.6) / 1.2)) for k in range(nb)])
    fall = [0.0, -0.04, 0.1, 0.24, 0.36, 0.42, 0.41, 0.41][i]
    for j, nm in enumerate(rig.neck[:-1]):
        rig.n(nm).rotation_euler.x += fall * (0.18 + 0.08 * j)
    C.chain_bend(rig, rig.coil, -0.02 * fall, axis="x", start=3, end=8)
    head.rotation_euler.x += [0.2, 0.1, 0.0, -0.15, -0.3, -0.4, -0.38, -0.38][i]   # deita com o rosto para cima
    R.squash(body, [0.9, 1.03, 0.98, 0.96, 0.95, 0.97, 0.97, 0.97][i])
    S.blink(rig, [0.9, 0.5, 0.7, 0.9, 1.0, 1.0, 1.0, 1.0][i])
    _mouth(rig, [0.6, 0.4, 0.4, 0.25, 0.1, 0.05, 0.05, 0.05][i])
    tf = rig.n("truefire")
    k = [0, 0, 0, 0, 0, 0.0, 0.6, 0.9][i]
    tf.scale = (k, k, k) if k > 0 else (0.0001,) * 3
