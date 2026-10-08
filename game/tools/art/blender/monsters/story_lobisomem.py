"""Lobisomem Atroz (story_lobisomem) — chefe da historia, Arco 1 cap. 3 (ARCO-1-TERRA-DO-SABIA.md; ARCO-DO-LOBISOMEM.md).
So existe na forma atroz (estagio 4, quadro 240). Substitui, para a historia, o werewolf s4 (bolha pequena).
Lobisomem chibi FORTE, de pe e curvado: cabecona de lobo com focinho, orelhas altas, olhos de ouro aceso com fenda,
sobrancelha brava e bocarra de presas; juba eriçada em volta do pescoco, peito largo com uma lua crescente de pelo
claro, bracos compridos com maos grandes e garras longas, pernas de lobo (digitigradas), rabo felpudo.
Corrupcao: fogo preto de pontas violeta saindo da juba nas costas, fumaca preta subindo. Lua e nevoa: a lua
crescente no peito brilha e uma nevoa lilas rodeia os pes no idle.
  idle: respira pesado (peito e ombros), rosna, orelha mexe, nevoa girando nos pes, o fogo da juba tremula;
  walk: passada pesada e curvada, bracos balancando;
  attack: ergue as duas garras, ruge e desce as garras em X;
  hit: recua, orelhas para tras, olhos apertados;
  death: uiva para cima, cai de joelhos e tomba para tras; o fogo apaga.
Ideias do werewolf.py (peito claro, juba escura, focinho); modelo proprio por script."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_lote1 as C

SCALE = {4: 2.3}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 6.0
HEAD_TILT = -0.32

BC = Vector((0, 0.03, 0.68))
BR = (0.25, 0.2, 0.25)
HC = Vector((0, -0.1, 1.1))
HR = (0.285, 0.25, 0.25)


def build(stage=4):
    if stage not in STAGES:
        raise ValueError("story_lobisomem: so o estagio 4 (atroz)")
    R.reset()
    R.CUR["reach"] = (0.3, 0.3, 0.4)
    rig = R.Rig("story_lobisomem")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # ---- pernas de lobo (coxa, canela para tras, pata) com garrinhas
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.13 * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.04, 0.46), root)
        knee = Vector((hx * 1.15, -0.06, 0.28))
        ank = Vector((hx * 1.15, 0.06, 0.12))
        C.limb(rig, f"thigh{nm}", (hx, 0.04, 0.48), knee, 0.1, 0.07, "wolf_fur_n", leg, group=f"leg{nm}")
        shin = rig.empty(f"shin{nm}", knee, leg)
        C.limb(rig, f"shin{nm}", knee, ank, 0.065, 0.05, "wolf_fur_n", shin, group=f"leg{nm}")
        C.limb(rig, f"foot{nm}", ank, (hx * 1.15, -0.05, 0.035), 0.05, 0.05, "wolf_fur_n", shin, group=f"leg{nm}")
        C.ell(rig, f"paw{nm}", (hx * 1.15, -0.08, 0.04), (0.075, 0.085, 0.04), "wolf_fur_n", shin, group=f"leg{nm}")
        for c in (-1, 0, 1):
            b = Vector((hx * 1.15 + 0.035 * c, -0.15, 0.03))
            rig.add_mesh(R.cone(f"tcl{nm}{c}", b, b + Vector((0.006 * c, -0.05, -0.015)), 0.014, 0.002, seg=5, rings=1),
                         f"tclaw", "fang_n", shin, noline=True)
    # ---- rabo felpudo
    tail = rig.empty("tail", (0, BC.y + 0.16, 0.5), root)
    C.limb(rig, "tail0", (0, BC.y + 0.15, 0.5), (0.05, BC.y + 0.42, 0.42), 0.09, 0.07, "wolf_fur_n", tail, group="tail",
           bend=(0, 0, -0.03))
    C.limb(rig, "tail1", (0.05, BC.y + 0.42, 0.42), (0.12, BC.y + 0.55, 0.6), 0.07, 0.01, "wolf_dark_n", tail, group="tail",
           bend=(0.0, 0.04, 0))
    # ---- tronco curvado: peito largo, barriga clara com lua crescente
    body = rig.empty("body", (0, 0.04, 0.48), root)
    C.ell(rig, "chest", BC, BR, "wolf_fur_n", body, group="torso")
    C.ell(rig, "hips", (0, 0.06, 0.5), (0.19, 0.16, 0.13), "wolf_fur_n", body, group="torso")
    pc = BC + Vector((0, -BR[1] * 0.55, -0.04))
    C.ell(rig, "belly", pc, (BR[0] * 0.66, BR[1] * 0.55, BR[2] * 0.78), "wolf_pale_n", body, group="belly")
    # lua crescente no peito (dois discos: claro e o "recorte" de pelo claro por cima)
    my = S.ysurf(pc, (BR[0] * 0.66, BR[1] * 0.55, BR[2] * 0.78), 0.0, pc.z + 0.05)
    moon = rig.empty("moon", (0, my, pc.z + 0.05), body)
    C.ell(rig, "moon", (0.0, my - 0.012, pc.z + 0.05), (0.075, 0.012, 0.075), "moon_glow", moon, noline=True, unlit=True,
          prio=2.5)
    C.ell(rig, "moon_cut", (0.032, my - 0.022, pc.z + 0.068), (0.062, 0.012, 0.064), "wolf_pale_n", moon, noline=True,
          prio=3.0, group="belly")
    # juba erizada em volta do pescoco e nos ombros (cones)
    mane = rig.empty("mane", (0, 0.02, 0.92), body)
    for k in range(16):
        a = math.tau * k / 16
        front = math.sin(a) < -0.55
        if front:
            continue
        r = 0.24 + 0.02 * (k % 2)
        b = Vector((r * 0.95 * math.cos(a), 0.02 + r * 0.8 * math.sin(a), 0.9 + 0.03 * (k % 3)))
        out = Vector((math.cos(a), math.sin(a) * 0.9, 0.0))
        tip = b + out * (0.12 + 0.04 * (k % 3)) + Vector((0, 0.03, -0.06 + 0.1 * (k % 2)))
        C.limb(rig, f"tuft{k}", b - out * 0.05, tip, 0.075, 0.006, "wolf_dark_n" if k % 2 else "wolf_fur_n", mane,
               group="mane", seg=6, rings=2)
    C.ell(rig, "ruff", (0, 0.04, 0.9), (0.27, 0.22, 0.12), "wolf_dark_n", mane, group="mane")
    # ---- bracos compridos e maos grandes de garra
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.25 * sx, 0.02, 0.84))
        arm = rig.empty(f"arm{nm}", sp, body)
        el = sp + Vector((0.08 * sx, 0.02, -0.22))
        C.ell(rig, f"shoulder{nm}", sp, (0.11, 0.1, 0.1), "wolf_fur_n", arm, group=f"arm{nm}")
        C.limb(rig, f"uarm{nm}", sp, el, 0.085, 0.07, "wolf_fur_n", arm, group=f"arm{nm}")
        fore = rig.empty(f"fore{nm}", el, arm)
        hp = el + Vector((0.03 * sx, -0.08, -0.2))
        C.limb(rig, f"farm{nm}", el, hp, 0.075, 0.06, "wolf_fur_n", fore, group=f"arm{nm}")
        # tufo do cotovelo
        C.limb(rig, f"elt{nm}", el + Vector((0, 0.02, 0)), el + Vector((0.07 * sx, 0.08, -0.03)), 0.04, 0.004,
               "wolf_dark_n", fore, group=f"arm{nm}", seg=6, rings=1)
        C.ell(rig, f"hand{nm}", hp, (0.085, 0.075, 0.07), "wolf_fur_n", fore, group=f"arm{nm}")
        for c in (-1.5, -0.5, 0.5, 1.5):
            b = hp + Vector((0.032 * c, -0.05, -0.04))
            tip = b + Vector((0.012 * c, -0.05, -0.12))
            rig.add_mesh(R.cone(f"claw{nm}{c}", b, tip, 0.018, 0.002, seg=6, rings=3, bend=(0, -0.025, 0.01)),
                         f"claw{nm}", "fang_n", fore, noline=True, prio=1.6)
    # ---- cabecona de lobo
    head = rig.empty("head", (0, HC.y + 0.05, HC.z - HR[2] * 0.9), body)
    C.ell(rig, "head", HC, HR, "wolf_fur_n", head, group="head")
    # bochechas felpudas (tufos para os lados)
    for sx in (1, -1):
        for k in range(3):
            b = HC + Vector((HR[0] * 0.8 * sx, -0.02 + 0.04 * k, -0.07 - 0.03 * k))
            C.limb(rig, f"cheek{sx}{k}", b, b + Vector((0.11 * sx, 0.02, -0.06 - 0.02 * k)), 0.05, 0.004,
                   "wolf_fur_n", head, group="head", seg=6, rings=1)
    # focinho (de cima claro) e mandibula com pivo
    sz = HC.z - 0.09
    sy = S.ysurf(HC, HR, 0, sz)
    C.ell(rig, "snout", (0, sy - 0.1, sz + 0.005), (0.105, 0.16, 0.075), "wolf_pale_n", head, group="snout")
    C.ell(rig, "nose", (0, sy - 0.245, sz + 0.04), (0.045, 0.035, 0.032), "nose_n", head, noline=True, prio=2.5)
    C.ell(rig, "mouth_in", (0, sy - 0.13, sz - 0.06), (0.09, 0.11, 0.04), "mouth_in", head, noline=True, unlit=True)
    C.teeth(rig, "fangup", (0, sy - 0.2, sz - 0.04), 0.15, 4, head, h=0.05, r=0.016, prio=3.0)
    jaw = rig.empty("jaw", (0, sy - 0.02, sz - 0.05), head)
    C.ell(rig, "jaw", (0, sy - 0.1, sz - 0.095), (0.09, 0.13, 0.04), "wolf_pale_n", jaw, group="jaw")
    C.teeth(rig, "fanglo", (0, sy - 0.19, sz - 0.075), 0.12, 2, jaw, h=0.04, r=0.014, down=False, prio=3.0)
    # olhos de ouro aceso com fenda, sobrancelha brava
    rz = 0.14
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.12 * sx, HC.z + 0.04
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.012, ez))
        C.glow_eye(rig, nm, ep, head, 0.1, rz, -0.5 * sx, iris="eye_gold_n", core="eye_gold_c", slit=True)
        S.brow(rig, nm, ep, head, rz / 0.145, 0.1, mat="brow_n", thick=1.1, width=0.72, lift=0.015, prio=3.2)
    # orelhas altas (pivo para mexer)
    for sx, nm in ((1, "L"), (-1, "R")):
        b = HC + Vector((0.14 * sx, 0.04, HR[2] * 0.72))
        ear = rig.empty(f"ear{nm}", b, head)
        tip = b + Vector((0.08 * sx, 0.05, 0.27))
        C.limb(rig, f"ear{nm}", b, tip, 0.085, 0.005, "wolf_fur_n", ear, group=f"ear{nm}", seg=8, rings=3)
        C.limb(rig, f"earin{nm}", b + Vector((0, -0.04, 0.02)), tip + Vector((0, -0.025, -0.05)), 0.05, 0.004,
               "wolf_inner_n", ear, group=f"earin{nm}", seg=8, rings=2)
    # tufo no alto da cabeca
    for k in range(3):
        b = HC + Vector((0.05 * (k - 1), 0.02, HR[2] * 0.85))
        C.limb(rig, f"crest{k}", b, b + Vector((0.04 * (k - 1), 0.1, 0.1 - 0.02 * abs(k - 1))), 0.045, 0.004,
               "wolf_dark_n", head, group="head", seg=6, rings=1)
    head.rotation_euler.x += HEAD_TILT - 0.1   # compensa a corcunda do corpo: rosto de frente para a luz
    # ---- corrupcao: fogo preto saindo da juba nas costas + fumaca
    C.corrupt_flame(rig, "manefire", (0, 0.22, 0.96), mane, size=1.75, n=7, width=1.15, spread=2.4, base_mat="cf_glow",
                    core=None, height=1.0, black_from=0.42, lean=0.8, slim=0.75)
    C.smoke(rig, "smk", [(0.18 * math.cos(k * 2.4), 0.2 + 0.08 * math.sin(k * 2.4), 1.3) for k in range(5)], root,
            size=0.04)
    # nevoa lilas nos pes
    mist = rig.empty("mist", (0, 0, 0), root)
    for k in range(8):
        a = math.tau * k / 8
        p = Vector((0.42 * math.cos(a), 0.32 * math.sin(a), 0.03 + 0.03 * (k % 2)))
        C.ell(rig, f"mist{k}", p, (0.11 - 0.03 * (k % 2), 0.035, 0.018), "mist_n" if k % 2 == 0 else "mist2_n", mist,
              rot=(0, 0, 0.25 * math.sin(a)), part=f"mist{k % 2}", noline=True, unlit=True, prio=0.9)
    body.rotation_euler.x = 0.1   # curvado para a frente
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _arms(rig, ax, az=0.0, fore=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg
        rig.n(f"fore{nm}").rotation_euler.x += fore


def _jaw(rig, o):
    rig.n("jaw").rotation_euler.x += 0.5 * o


def _ears(rig, back=0.0, twitch=0.0):
    rig.n("earL").rotation_euler.x += 0.5 * back
    rig.n("earR").rotation_euler.x += 0.5 * back + 0.35 * twitch


def _legs(rig, t, amp):
    for nm, off in (("L", 0.0), ("R", 0.5)):
        a = math.sin(math.tau * (t + off))
        rig.n(f"leg{nm}").rotation_euler.x = -amp * a
        rig.n(f"leg{nm}").location.z += 0.04 * max(0.0, math.sin(math.tau * (t + off) + math.pi / 2))
        rig.n(f"shin{nm}").rotation_euler.x = 0.3 * max(0.0, a)


def pose(rig, anim, i, n, stage=4):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "smk", t, rise=0.3, spread=1.2)
    if anim != "death":
        C.flicker(rig, "manefire", t, amp=1.1)
    if anim == "idle":
        s = math.sin(math.tau * t)
        rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * t
        R.squash(root, 1.0 + 0.03 * s)
        body.rotation_euler.x += 0.03 * s
        rig.n("mane").scale = (1.0 + 0.04 * s,) * 3
        head.rotation_euler.y = 0.08 * math.sin(math.tau * t)
        head.rotation_euler.x += -0.03 * s
        _arms(rig, 0.08 * math.sin(math.tau * (t - 0.15)), 0.08, -0.05 * s)
        _jaw(rig, 0.25 + 0.15 * max(0.0, s))
        _ears(rig, 0.0, 1.0 if i in (3, 4) else 0.0)
        rig.n("tail").rotation_euler.z = 0.25 * math.sin(math.tau * t)
        rig.n("moon").scale = (1.0 + 0.12 * max(0, s),) * 3
        if i == 6:
            S.blink(rig, 0.95)
    elif anim == "walk":
        rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * t
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.035 * b
        R.squash(root, 1.0 + 0.05 * (b - 0.5))
        _legs(rig, t, 0.55)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"arm{nm}").rotation_euler.x += 0.5 * sg * math.sin(math.tau * t)
        body.rotation_euler.y = 0.08 * math.sin(math.tau * t)
        body.rotation_euler.x += 0.06
        head.rotation_euler.y = -0.06 * math.sin(math.tau * t)
        _jaw(rig, 0.3)
        rig.n("tail").rotation_euler.z = 0.35 * math.sin(math.tau * t + 1.0)
    elif anim == "attack":
        rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * t
        _attack(rig, i)
    elif anim == "hit":
        rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * t
        R.squash(root, [0.86, 1.06, 0.97, 1.0][i])
        R.tilt(root, [-0.16, 0.06, -0.03, 0.0][i], 0.1)
        S.blink(rig, [0.9, 0.6, 0.2, 0.0][i])
        _ears(rig, [1.0, 0.7, 0.3, 0.0][i])
        _jaw(rig, [0.8, 0.5, 0.3, 0.2][i])
        _arms(rig, [-0.6, -0.3, -0.1, 0.0][i], [0.4, 0.2, 0.1, 0.0][i])
        head.rotation_euler.x += [0.15, -0.05, 0.0, 0.0][i]
    elif anim == "death":
        C.hide(rig, "mist")
        _death(rig, i)


def _attack(rig, i):
    """Ergue as duas garras (corpo para tras), ruge, desce as garras cruzando na frente."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    lean = [-0.12, -0.25, -0.3, 0.2, 0.32, 0.25, 0.12, 0.0][i]
    body.rotation_euler.x += lean
    R.squash(root, [0.92, 1.06, 1.1, 0.86, 0.9, 0.96, 1.0, 1.0][i])
    _arms(rig, [-1.2, -2.3, -2.6, -0.5, 0.2, 0.1, -0.1, 0.0][i], [0.4, 0.5, 0.55, -0.1, -0.35, -0.3, -0.1, 0.0][i],
          [0.0, -0.4, -0.6, 0.0, 0.3, 0.2, 0.1, 0.0][i])
    _jaw(rig, [0.4, 0.8, 1.0, 1.0, 0.9, 0.6, 0.4, 0.3][i])
    _ears(rig, [0.3, 0.6, 0.8, 0.2, 0.0, 0.0, 0.0, 0.0][i])
    head.rotation_euler.x += [0.0, -0.12, -0.18, 0.1, 0.12, 0.06, 0.0, 0.0][i]
    if i in (0, 3):
        S.blink(rig, 0.35)
    C.flicker(rig, "manefire", i / 8, amp=1.4, k=[1.0, 1.1, 1.25, 1.3, 1.25, 1.15, 1.05, 1.0][i])


def _death(rig, i):
    """Uiva para cima, cai de joelhos e tomba para tras; o fogo da juba apaga."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    if i < 2:
        head.rotation_euler.x += [-0.35, -0.5][i]
        _jaw(rig, 1.0)
        S.blink(rig, 0.8)
        _arms(rig, [-0.4, -0.6][i], 0.4)
        R.squash(root, [0.92, 1.06][i])
    elif i < 4:
        k = [0.5, 1.0][i - 2]
        root.location.z -= 0.2 * k
        for nm in ("L", "R"):
            rig.n(f"leg{nm}").rotation_euler.x += -0.9 * k
            rig.n(f"shin{nm}").rotation_euler.x += 1.4 * k
        body.rotation_euler.x += 0.25 * k
        _arms(rig, -0.3, 0.3)
        S.blink(rig, 0.9)
        _jaw(rig, 0.6)
    else:
        fall = [-0.6, -1.15, -1.32, -1.28][i - 4]
        root.location.z -= 0.2 * (1 - min(1.0, -fall / 1.4)) + 0.02
        for nm in ("L", "R"):
            rig.n(f"leg{nm}").rotation_euler.x += -0.9 + 0.5 * min(1.0, -fall / 1.4)
            rig.n(f"shin{nm}").rotation_euler.x += 1.4 * (1 - 0.5 * min(1.0, -fall / 1.4))
        R.tilt(root, fall, 0.25)
        root.location.y -= 0.72 * min(1.0, -fall / 1.4)
        _arms(rig, -0.9, 0.7)
        S.blink(rig, 1.0)
        _jaw(rig, 0.5)
        _ears(rig, 0.6)
    C.flicker(rig, "manefire", i / 8, k=[1.2, 1.1, 0.8, 0.55, 0.35, 0.15, 0.0, 0.0][i])
    if i >= 5:
        S.hide_motes(rig, "smk")
