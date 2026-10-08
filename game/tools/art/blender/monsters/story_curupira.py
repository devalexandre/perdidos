"""Curupira Atroz (story_curupira) — chefe da historia, Arco 1 cap. 4 (ARCO-1-TERRA-DE-PINDORAMA.md). So existe na forma
atroz (estagio 4, quadro 240); de dia ele e um menino comum (NPC, sem pes virados).
O protetor da mata virado cacador feral, mas ainda um MENINO chibi (sem gore): cabelo vermelho-fogo em chamas que
escurecem ate ficar pretas nas pontas, com borda violeta (o sinal de Erevos), olhos acesos de verde-folha, sobrancelha
feral e caninos; cipos enrolados nos bracos e nas pernas, saiote e ombreira de folhas, chicote de cipo na mao.
Os PES VIRADOS PARA TRAS ficam bem visiveis (pes grandes, dedos para tras, calcanhar para a frente).
Folhas secas e fumaca preta giram em volta.
  idle: agachado de caçador, balanca, o cabelo de fogo tremula, o chicote mexe, pisca;
  walk: passinhos rapidos (os pes virados marcam o passo);
  attack: puxa o chicote de cipo para tras e estala na frente;
  hit: encolhe, aperta os olhos, o fogo do cabelo baixa;
  death: o fogo do cabelo apaga ate sobrar o cabelo ruivo, ele cai sentado e tomba (volta a ser menino).
Modelo proprio por script; regras de pixel art do stone_armadillo.py / sol_common.py."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_lote1 as C

SCALE = {4: 2.35}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 8.0
HEAD_TILT = -0.42

HC = Vector((0, -0.03, 0.9))
HR = (0.27, 0.235, 0.25)
BC = Vector((0, 0.0, 0.5))
BR = (0.13, 0.1, 0.14)
WHIP = 5


def build(stage=4):
    if stage not in STAGES:
        raise ValueError("story_curupira: so o estagio 4 (atroz)")
    R.reset()
    R.CUR["reach"] = (0.28, 0.32, 0.3)
    rig = R.Rig("story_curupira")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # ---- pernas com os PES VIRADOS PARA TRAS (calcanhar na frente, dedos atras), cipo enrolado na canela
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.08 * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.0, 0.36), root)
        knee = Vector((hx * 1.3, -0.04, 0.2))
        C.limb(rig, f"thigh{nm}", (hx, 0.0, 0.37), knee, 0.05, 0.042, "cur_skin_n", leg, group=f"leg{nm}")
        C.limb(rig, f"shin{nm}", knee, (hx * 1.3, 0.0, 0.06), 0.042, 0.036, "cur_skin_n", leg, group=f"leg{nm}")
        # pe grande para tras: calcanhar redondo na frente, sola comprida para +Y, dedos no fim
        fx = hx * 1.3
        # pe virado para tras e um pouco para fora (os dedos aparecem dos lados mesmo de frente)
        yaw = 0.55 * sx
        fd = Vector((math.sin(yaw), math.cos(yaw), 0))     # direcao calcanhar -> dedos (para tras)
        fs = Vector((fd.y, -fd.x, 0))
        c0 = Vector((fx, -0.02, 0.04))
        C.ell(rig, f"heel{nm}", c0, (0.06, 0.055, 0.045), "cur_skin_n", leg, group=f"leg{nm}")
        C.ell(rig, f"sole{nm}", c0 + fd * 0.1 - Vector((0, 0, 0.005)), (0.065, 0.12, 0.036), "cur_skin_n", leg,
              rot=(0, 0, -yaw), group=f"leg{nm}")
        for c in (-1.5, -0.5, 0.5, 1.5):
            C.ell(rig, f"toe{nm}{c}", c0 + fd * (0.215 - 0.01 * abs(c)) + fs * 0.03 * c - Vector((0, 0, 0.01)),
                  (0.021, 0.028, 0.024), "cur_skin_n", leg, rot=(0, 0, -yaw), part=f"toes{nm}", group=f"toes{nm}")
        # cipo em espiral na canela
        for k in range(2):
            z = 0.1 + 0.07 * k
            rig.add_mesh(S.torus(f"lvine{nm}{k}", (fx * 0.97, -0.02, z), 0.045, 0.012, rot=(0.25 * (1 if k else -1), 0, 0), nu=16),
                         f"lvine{nm}", "vine_n", leg)
    body = rig.empty("body", (0, 0.0, 0.36), root)
    # saiote de folhas (pontas para baixo) e tronco
    C.ell(rig, "torso", BC, BR, "cur_skin_n", body, group="torso")
    for k in range(11):
        a = math.tau * k / 11
        b = Vector((0.13 * math.cos(a), 0.105 * math.sin(a), 0.42))
        out = Vector((math.cos(a), math.sin(a), 0))
        C.limb(rig, f"skirt{k}", b, b + out * 0.07 + Vector((0, 0, -0.13 + 0.02 * (k % 2))), 0.05, 0.006,
               "leaf_n" if k % 2 else "leaf_dark_n", body, group="skirt", seg=6, rings=2)
    rig.add_mesh(S.torus("belt", (0, 0.0, 0.43), 0.13, 0.022, nu=20, yscale=0.82), "belt", "vine_n", body)
    # ombreira de folhas no ombro esquerdo + cipo cruzando o peito
    for k in range(4):
        b = Vector((0.11, 0.0, 0.6)) + Vector((0.02 * k, 0.03 * (k - 1.5), 0.0))
        C.limb(rig, f"pauld{k}", b, b + Vector((0.08, 0.02 * (k - 1.5), -0.08)), 0.045, 0.006, "leaf_n", body,
               group="pauld", seg=6, rings=2)
    C.limb(rig, "sash", (0.12, -0.08, 0.6), (-0.11, -0.09, 0.42), 0.016, 0.016, "vine_n", body, group="sash",
           bend=(0, -0.025, 0))
    # bracos com cipo enrolado; a mao direita segura o chicote de cipo
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.13 * sx, BC.y, BC.z + 0.08))
        arm = rig.empty(f"arm{nm}", sp, body)
        hp = sp + Vector((0.1 * sx, -0.06, -0.17))
        C.limb(rig, f"arm{nm}", sp, hp, 0.04, 0.033, "cur_skin_n", arm, group=f"arm{nm}", bend=(0.02 * sx, 0, 0))
        rig.add_mesh(S.torus(f"avine{nm}", sp + (hp - sp) * 0.55, 0.04, 0.011, rot=(0.0, 0.5 * sx, 0), nu=14), f"avine{nm}",
                     "vine_n", arm)
        C.ell(rig, f"hand{nm}", hp, (0.046, 0.04, 0.048), "cur_skin_n", arm, group=f"arm{nm}")
        for c in (-1, 0, 1):
            b = hp + Vector((0.02 * c, -0.02, -0.03))
            C.limb(rig, f"fing{nm}{c}", b, b + Vector((0.01 * c, -0.02, -0.04)), 0.015, 0.008, "cur_skin_n", arm,
                   group=f"arm{nm}", seg=6, rings=1)
        if nm == "R":
            # chicote: cadeia de segmentos (cada um filho do anterior) com folhinhas
            prev = arm
            p = hp + Vector((0.0, -0.02, -0.02))
            seg_l = 0.09
            for k in range(WHIP):
                w = rig.empty(f"whip{k}", p, prev)
                q = p + Vector((-0.02, 0.01, -seg_l))
                C.limb(rig, f"whipm{k}", p, q, 0.017 - 0.002 * k, 0.015 - 0.002 * k, "vine_n", w, group="whip", seg=6,
                       rings=2)
                if k % 2 == 1:
                    C.ell(rig, f"wleaf{k}", (p + q) / 2 + Vector((0.025, 0, 0)), (0.03, 0.012, 0.018), "leaf_n", w,
                          rot=(0, 0.6, 0), part="wleaf", group="whip")
                prev, p = w, q
    # ---- cabecona de menino, cabelo ruivo + chamas
    head = rig.empty("head", (0, HC.y + 0.02, HC.z - HR[2] * 0.85), body)
    C.ell(rig, "head", HC, HR, "cur_skin_n", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        C.ell(rig, f"ear{nm}", (HR[0] * 0.97 * sx, HC.y + 0.02, HC.z - 0.02), (0.04, 0.03, 0.06), "cur_skin_n", head,
              rot=(0, 0.3 * sx, 0), part="ears")

    def edge(ph):
        return S.bob(ph, 0.85, 1.75, open_=0.95, ramp=0.6) + S.zigzag(ph + 0.2, 13, 0.16)
    rig.add_mesh(S.cap("hair", HC, HR, 0.0, edge, lift=1.06), "hair", "cur_hair_n", head, group="hair")
    # franja em mechas pontudas
    for k in range(5):
        x = -0.12 + 0.06 * k
        z = HC.z + 0.16
        b = Vector((x, S.ysurf(HC, HR, x, z) - 0.01, z))
        C.limb(rig, f"fringe{k}", b + Vector((0, 0.02, 0.04)), b + Vector((0.02 * (k - 2), -0.04, -0.06 - 0.015 * (k % 2))),
               0.04, 0.005, "cur_hair_n", head, group="hair", seg=6, rings=2)
    # olhos acesos de verde-folha, sobrancelha feral, caninos
    rz = 0.15
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.112 * sx, HC.z - 0.01
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.014, ez))
        C.glow_eye(rig, nm, ep, head, 0.096, rz, -0.45 * sx, iris="eye_leaf", core="eye_leaf_c")
        S.brow(rig, nm, ep, head, rz / 0.145, 0.09, mat="cur_hair_n", thick=1.25, width=0.95, lift=-0.005, prio=3.0)
    mz = HC.z - 0.145
    my = S.ysurf(HC, HR, 0.0, mz)
    mouth = rig.empty("mouth", (0, my, mz), head)
    C.ell(rig, "mouth", (0, my + 0.004, mz), (0.07, 0.02, 0.03), "mouth_in", mouth, noline=True, unlit=True, prio=2.0)
    for sx in (1, -1):
        b = Vector((0.035 * sx, my - 0.012, mz + 0.022))
        rig.add_mesh(R.cone(f"canine{sx}", b, b + Vector((0, -0.006, -0.04)), 0.014, 0.002, seg=5, rings=1), "canine",
                     "fang_n", mouth, noline=True, prio=2.8)
    # chamas do cabelo (o fogo do Curupira) — leque grande atras da cabeca
    C.corrupt_flame(rig, "hairfire", HC + Vector((0, 0.14, 0.02)), head, size=1.85, n=7, width=1.2, spread=2.2,
                    base_mat="hair_fire", core=None, height=1.0, black_from=0.55, lean=0.8, slim=0.62,
                    hot="hair_fire_hot")
    head.rotation_euler.x += HEAD_TILT - 0.12   # compensa a corcunda do corpo: rosto de frente para a luz
    # folhas secas e brasas violeta girando, fumaca preta subindo do cabelo
    spots = [(0.42 * math.cos(math.tau * k / 6), 0.34 * math.sin(math.tau * k / 6), 0.25 + 0.12 * (k % 3)) for k in range(6)]
    S.add_motes(rig, "leaves", spots, ["leaf_n", "cf_tip"], size=0.026, parent=root)
    C.smoke(rig, "smk", [HC + Vector((0.12 * math.cos(k * 2.4), 0.12 + 0.05 * math.sin(k * 2.4), 0.5)) for k in range(5)],
            root, size=0.04)
    body.rotation_euler.x = 0.12      # agachado de cacador
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _arms(rig, ax, az=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg


def _whip(rig, angles, side=None):
    for k in range(WHIP):
        rig.n(f"whip{k}").rotation_euler.x += angles[k] if isinstance(angles, (list, tuple)) else angles
        if side is not None:
            rig.n(f"whip{k}").rotation_euler.y += side[k] if isinstance(side, (list, tuple)) else side


def _legs(rig, t, amp):
    for nm, off in (("L", 0.0), ("R", 0.5)):
        a = math.sin(math.tau * (t + off))
        rig.n(f"leg{nm}").rotation_euler.x = -amp * a
        rig.n(f"leg{nm}").location.z += 0.04 * max(0.0, math.sin(math.tau * (t + off) + math.pi / 2))


def pose(rig, anim, i, n, stage=4):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "smk", t, rise=0.3, spread=1.2)
    if anim not in ("death", "hit"):
        C.flicker(rig, "hairfire", t, amp=1.1)
    if anim == "idle":
        s = math.sin(math.tau * t)
        S.motes(rig, "leaves", t, rise=0.06, orbit=1.0)
        R.squash(root, 1.0 + 0.035 * s)
        root.location.z += 0.008 * s
        body.rotation_euler.y = 0.05 * math.sin(math.tau * t)
        head.rotation_euler.y = 0.1 * math.sin(math.tau * (t - 0.15))
        head.rotation_euler.z = 0.05 * math.sin(math.tau * t)
        _arms(rig, (0.1 * s, -0.25 - 0.1 * s), 0.25)
        _whip(rig, [0.15 * math.sin(math.tau * t - 0.6 * k) for k in range(WHIP)],
              [0.2 * math.sin(math.tau * t - 0.7 * k) for k in range(WHIP)])
        rig.n("mouth").scale.z = 1.0 + 0.3 * max(0.0, s)
        if i == 5:
            S.blink(rig, 0.95)
    elif anim == "walk":
        S.motes(rig, "leaves", t, rise=0.06, orbit=1.0)
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.05 * b
        R.squash(root, 1.0 + 0.06 * (b - 0.5))
        _legs(rig, t, 0.6)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"arm{nm}").rotation_euler.x += 0.5 * sg * math.sin(math.tau * t)
        body.rotation_euler.x += 0.08
        head.rotation_euler.y = -0.06 * math.sin(math.tau * t)
        _whip(rig, [0.25 * math.sin(math.tau * t - 0.8 * k) for k in range(WHIP)])
    elif anim == "attack":
        S.motes(rig, "leaves", t, rise=0.06, orbit=1.5)
        _attack(rig, i)
    elif anim == "hit":
        S.motes(rig, "leaves", t, rise=0.06, orbit=1.0)
        C.flicker(rig, "hairfire", t, amp=1.5, k=[0.7, 0.85, 0.95, 1.0][i])
        R.squash(root, [0.84, 1.08, 0.97, 1.0][i])
        R.tilt(root, [-0.18, 0.07, -0.03, 0.0][i], 0.12)
        S.blink(rig, [0.9, 0.6, 0.2, 0.0][i])
        _arms(rig, [-0.9, -0.5, -0.2, 0.0][i], [0.5, 0.3, 0.1, 0.0][i])
        _whip(rig, [0.5, -0.3, 0.1, 0.0][i])
        rig.n("mouth").scale = (0.8, 1, 1.6)
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Puxa o chicote de cipo para tras por cima do ombro e estala na frente (o cipo desenrola)."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    armR = rig.n("armR")
    armR.rotation_euler.x += [-0.6, -2.4, -2.9, -0.8, 0.5, 0.3, 0.0, -0.1][i]
    armR.rotation_euler.y += [0.0, 0.2, 0.3, 0.1, 0.0, 0.0, 0.0, 0.0][i]
    rig.n("armL").rotation_euler.x += [0.3, 0.5, 0.6, -0.4, -0.6, -0.4, -0.2, 0.0][i]
    body.rotation_euler.x += [0.0, -0.15, -0.2, 0.2, 0.3, 0.2, 0.1, 0.0][i]
    body.rotation_euler.z += [0.0, 0.25, 0.35, -0.2, -0.3, -0.15, 0.0, 0.0][i]
    R.squash(root, [0.9, 1.06, 1.1, 0.88, 0.92, 0.97, 1.0, 1.0][i])
    whip = [
        [0.4, 0.3, 0.3, 0.2, 0.2],
        [1.2, 0.8, 0.6, 0.5, 0.4],
        [1.6, 1.0, 0.7, 0.5, 0.3],
        [-0.6, -0.4, 0.2, 0.6, 0.8],
        [-1.0, -0.4, -0.2, 0.0, 0.0],
        [-0.9, -0.2, -0.3, -0.4, -0.5],
        [-0.5, 0.0, 0.1, 0.1, 0.1],
        [0.0, 0.1, 0.1, 0.1, 0.1],
    ][i]
    _whip(rig, whip)
    if i in (0, 1):
        S.blink(rig, 0.3)
    rig.n("mouth").scale = (1.1, 1, [1.0, 1.4, 1.6, 2.0, 2.0, 1.6, 1.3, 1.0][i])
    C.flicker(rig, "hairfire", i / 8, amp=1.4, k=[1.0, 1.1, 1.2, 1.3, 1.25, 1.15, 1.05, 1.0][i])


def _death(rig, i):
    """O fogo do cabelo apaga, ele cambaleia, cai sentado e tomba para tras: volta a ser so um menino ruivo."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "leaves", i / 8, rise=0.06, orbit=0.5)
    if i >= 4:
        S.hide_motes(rig, "leaves")
        S.hide_motes(rig, "smk")
    C.flicker(rig, "hairfire", i / 8, k=[1.1, 0.9, 0.7, 0.5, 0.3, 0.12, 0.0, 0.0][i])
    if i < 3:
        R.squash(root, [0.86, 1.04, 0.95][i])
        root.rotation_euler.y += [0.0, 0.15, -0.1][i]
        S.blink(rig, [0.9, 0.6, 0.8][i])
        _arms(rig, [-0.9, -0.6, -0.3][i], [0.5, 0.4, 0.2][i])
        _whip(rig, [0.4, 0.2, 0.0][i])
    else:
        fall = [-0.35, -0.9, -1.3, -1.36, -1.32][i - 3]
        for nm in ("L", "R"):
            rig.n(f"leg{nm}").rotation_euler.x += -1.0 * min(1.0, (i - 2) / 2)
        R.tilt(root, fall, 0.22)
        root.location.y -= 0.32 * min(1.0, -fall / 1.3)
        root.location.z += [0.0, 0.04, 0.0, 0.02, 0.0][i - 3]
        S.blink(rig, 1.0)
        _arms(rig, -0.8, 0.9)
        _whip(rig, [0.6, 0.4, 0.3, 0.2, 0.1])
    rig.n("mouth").scale = (0.7, 1, [1.6, 1.3, 1.0, 0.8, 0.6, 0.5, 0.5, 0.5][i])
