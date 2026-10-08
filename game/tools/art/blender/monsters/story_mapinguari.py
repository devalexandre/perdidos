"""Mapinguari Atroz (story_mapinguari) — chefe da historia do Arco 1, capitulo 7 (Ruinas de Ratanaba, sala dos
registros). Gigante peludo da floresta corrompido por Erevos; so existe na forma atroz (estagio 4, a noite).
Versao chibi do folclore, sem gore: um olho so, grande, no meio da testa (aceso, com sobrancelha brava em V);
a boca fica na barriga (bocao de dentinhos que ronca e abre no golpe); pes virados para tras (calcanhar na frente,
dedos e garras para tras); bracos compridos ate o chao. Guardiao de ruinas: ombreiras de pedra de Ratanaba com
glifos de luz fria, colar de tabuletas com glifos, pedra-selo nas costas, musgo; fogo negro (pontas violeta) saindo
das ombreiras e da corcunda.
  idle: respira pesado, a boca da barriga mastiga, bracos balancam; walk: passo pesado de um lado para o outro;
  attack: ergue os dois punhos e esmaga o chao (pedras voam) com a boca da barriga rugindo;
  hit: encolhe, olho apertado; death: o fogo apaga, ele senta e tomba de costas, olho fechado.
Modelo proprio por script; olho/sobrancelha no desenho do Tatu-Pedra (sol_common)."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_common_l2 as C

SCALE = {4: 2.55}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 4.0
HEAD_TILT = -0.35

BC = Vector((0, 0.03, 0.56))
BR = (0.4, 0.32, 0.42)
HC = Vector((0, -0.1, 1.08))
HR = (0.33, 0.27, 0.28)
MC = Vector((0, BC.y - BR[1] * 0.93, 0.5))   # boca da barriga


def build(stage):
    if stage not in STAGES:
        raise ValueError("so a forma atroz (4)")
    R.reset()
    R.CUR["reach"] = (0.38, 0.4, 0.5)
    rig = R.Rig("story_mapinguari")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", (0, 0.03, 0.22), root)
    # ---- corpo peludo (barril) com tufos em volta do contorno
    rig.add_mesh(R.ellipsoid("torso", BC, BR, seg=32, rings=20), "torso", "mapi_fur_l2", body, group="fur")
    for k in range(34):
        psi = math.pi * (0.12 + 0.8 * ((k * 0.618) % 1.0))
        om = math.pi * (0.05 + 0.9 * ((k * 0.381 + 0.13) % 1.0))
        p, nrm = S.on_ell(BC, BR, psi, om, 0.97)
        if p.z < 0.22 or (nrm.y < -0.55 and abs(p.x) < 0.25):
            continue
        d = (nrm + Vector((0, 0, -0.55))).normalized()
        rig.add_mesh(R.cone(f"tuft{k}", p, p + d * 0.13, 0.07, 0.006, seg=7, rings=2, bend=(0, 0, -0.02)), "tuft",
                     "mapi_fur_l2", body, group="fur")
    # pelo mais claro na barriga, em volta da boca
    rig.add_mesh(R.ellipsoid("bellyfur", MC + Vector((0, 0.07, 0.03)), (0.27, 0.06, 0.25)), "bellyfur", "warm_skin_l2", body)
    # ---- boca da barriga: labios, bocao escuro, dentinhos em cima e embaixo, lingua
    mouth = rig.empty("mouth", MC, body)
    rig.add_mesh(R.ellipsoid("mouthin", MC + Vector((0, -0.005, 0)), (0.17, 0.03, 0.075)), "mouthin", "mouth_in", mouth,
                 noline=True, unlit=True, prio=2.0)
    rig.add_mesh(R.ellipsoid("tongue", MC + Vector((0, -0.02, -0.035)), (0.09, 0.02, 0.03)), "tongue", "tongue", mouth,
                 noline=True, unlit=True, prio=2.4)
    lipU = rig.empty("lipU", MC + Vector((0, 0, 0.06)), mouth)
    lipD = rig.empty("lipD", MC + Vector((0, 0, -0.06)), mouth)
    rig.add_mesh(R.cone("lipU", (-0.19, MC.y - 0.02, MC.z + 0.01), (0.19, MC.y - 0.02, MC.z + 0.01), 0.026, 0.026, seg=8,
                        rings=8, bend=(0, -0.02, 0.07)), "lip", "nose_n", lipU, group="lip")
    rig.add_mesh(R.cone("lipD", (-0.19, MC.y - 0.02, MC.z - 0.01), (0.19, MC.y - 0.02, MC.z - 0.01), 0.026, 0.026, seg=8,
                        rings=8, bend=(0, -0.02, -0.07)), "lip", "nose_n", lipD, group="lip")
    for j in range(5):
        x = -0.12 + 0.06 * j
        zu = MC.z + 0.065 - 0.18 * (x * x)
        rig.add_mesh(R.cone(f"toothU{j}", (x, MC.y - 0.03, zu), (x, MC.y - 0.04, zu - 0.045), 0.02, 0.004, seg=6, rings=1),
                     "tooth", "fang_n", lipU, noline=True, prio=2.6)
    for j in range(4):
        x = -0.09 + 0.06 * j
        zd = MC.z - 0.065 + 0.18 * (x * x)
        rig.add_mesh(R.cone(f"toothD{j}", (x, MC.y - 0.03, zd), (x, MC.y - 0.04, zd + 0.04), 0.018, 0.004, seg=6, rings=1),
                     "tooth", "fang_n", lipD, noline=True, prio=2.6)
    # ---- pernas curtas e grossas, pes virados para tras (calcanhar na frente, dedos e garras atras)
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.2 * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.05, 0.24), root)
        rig.add_mesh(R.cone(f"thigh{nm}", (hx, 0.05, 0.3), (hx * 1.05, 0.05, 0.08), 0.12, 0.1, seg=12, rings=2), f"leg{nm}",
                     "mapi_fur_l2", leg, group=f"leg{nm}")
        rig.add_mesh(R.ellipsoid(f"heel{nm}", (hx * 1.05, 0.0, 0.06), (0.11, 0.1, 0.06)), f"foot{nm}", "warm_skin_l2", leg,
                     group=f"foot{nm}")
        rig.add_mesh(R.ellipsoid(f"foot{nm}", (hx * 1.05, 0.13, 0.045), (0.12, 0.15, 0.045)), f"foot{nm}", "warm_skin_l2", leg,
                     group=f"foot{nm}")
        for c in (-1, 0, 1):
            b = Vector((hx * 1.05 + 0.06 * c, 0.26, 0.04))
            rig.add_mesh(R.ellipsoid(f"toe{nm}{c}", b, (0.035, 0.04, 0.032)), f"foot{nm}", "warm_skin_l2", leg,
                         group=f"foot{nm}")
            rig.add_mesh(R.cone(f"tclaw{nm}{c}", b + Vector((0, 0.03, 0)), b + Vector((0.01 * c, 0.1, -0.02)), 0.022, 0.003,
                                seg=6, rings=2), "tclaw", "horn_n", leg, noline=True)
    # ---- bracos compridos (ate o chao) com maos grandes de 3 garras
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.36 * sx, BC.y - 0.02, 0.82))
        arm = rig.empty(f"arm{nm}", sp, body)
        ep = sp + Vector((0.12 * sx, -0.06, -0.32))
        hp = ep + Vector((0.03 * sx, -0.04, -0.26))
        rig.add_mesh(R.cone(f"uarm{nm}", sp, ep, 0.12, 0.1, seg=12, rings=3), f"arm{nm}", "mapi_fur_l2", arm, group=f"arm{nm}")
        fore = rig.empty(f"fore{nm}", ep, arm)
        rig.add_mesh(R.cone(f"farm{nm}", ep, hp, 0.1, 0.09, seg=12, rings=3), f"arm{nm}", "mapi_fur_l2", fore, group=f"arm{nm}")
        for k in range(4):  # tufos no antebraco
            p = ep + (hp - ep) * (0.2 + 0.2 * k)
            rig.add_mesh(R.cone(f"atuft{nm}{k}", p + Vector((0.08 * sx, 0, 0)), p + Vector((0.16 * sx, 0.02, -0.08)), 0.045,
                                0.004, seg=6, rings=1), f"arm{nm}", "mapi_fur_l2", fore, group=f"arm{nm}")
        rig.add_mesh(R.ellipsoid(f"hand{nm}", hp + Vector((0, -0.01, -0.03)), (0.11, 0.1, 0.08)), f"hand{nm}", "warm_skin_l2",
                     fore, group=f"hand{nm}")
        for c in (-1, 0, 1):
            b = hp + Vector((0.055 * c, -0.07, -0.06))
            rig.add_mesh(R.cone(f"claw{nm}{c}", b, b + Vector((0.015 * c, -0.07, -0.08)), 0.025, 0.003, seg=6, rings=2,
                                bend=(0, -0.01, 0.01)), "claw", "horn_n", fore, noline=True)
        # ombreira de pedra de Ratanaba com glifo aceso e musgo; fogo negro sai dela
        op = sp + Vector((0.0, 0.0, 0.06))
        rig.add_mesh(R.ellipsoid(f"pauld{nm}", op, (0.16, 0.15, 0.09), rot=(0, -0.45 * sx, 0)), f"pauld{nm}", "basalt_n", arm)
        rig.add_mesh(R.ellipsoid(f"paulm{nm}", op + Vector((0.03 * sx, 0.05, 0.07)), (0.08, 0.07, 0.03)), f"paulm{nm}",
                     "moss_n", arm)
        _glyph(rig, f"pg{nm}", op + Vector((0.05 * sx, -0.13, 0.02)), arm, 0.05)
        C.black_flame(rig, f"sfl{nm}", op + Vector((0.05 * sx, 0.04, 0.06)), (0.2 * sx, 0.15, 1.0), 0.36, 0.1, arm, bend=0.3 * sx,
                      phase=0.25 if sx > 0 else 0.7)
    # ---- colar de tabuletas de pedra com glifos
    for k in range(5):
        a = -0.75 + 1.5 * k / 4
        p = Vector((0.27 * math.sin(a), BC.y - BR[1] * 0.78 * math.cos(a) - 0.02, 0.86 - 0.05 * math.cos(a * 2)))
        rig.add_mesh(R.ellipsoid(f"tab{k}", p, (0.055, 0.025, 0.065), rot=(0.25, 0, -a * 0.8)), f"tab{k}", "basalt_n", body)
        _glyph(rig, f"tg{k}", p + Vector((0, -0.028, 0)), body, 0.032)
    rig.add_mesh(S.torus("cord", (0, BC.y - 0.03, 0.88), 0.3, 0.012, nu=28, yscale=0.95), "cord", "thorn_n", body)
    # ---- pedra-selo nas costas (corcunda) com glifo grande e fogo negro na corcunda
    sp_, sn_ = S.on_ell(BC, BR, 0.55, math.pi / 2, 1.0)
    rig.add_mesh(R.ellipsoid("seal", sp_ + sn_ * 0.04, (0.2, 0.16, 0.06), rot=S.align(sn_)), "seal", "basalt_n", body)
    _glyph(rig, "sg", sp_ + sn_ * 0.1, body, 0.09)
    for k, (psi, om) in enumerate(((0.45, 0.5), (0.25, math.pi / 2), (0.45, math.pi - 0.5))):
        p, nrm = S.on_ell(BC, BR, psi, om, 0.98)
        C.black_flame(rig, f"bfl{k}", p, nrm + Vector((0, 0, 1.4)), 0.4 + 0.06 * (k % 2), 0.11, body, phase=0.23 * k)
    S.add_motes(rig, "smoke", [(0.3 * math.cos(k * 2.4), 0.3 + 0.12 * math.sin(k * 2.4), 1.05 + 0.05 * (k % 2))
                               for k in range(6)], ["bfire_l2", "bfire_core_l2"], size=0.04, parent=body)
    # ---- cabeca chibi fundida no corpo: um olho grande na testa, sobrancelha em V, orelhinhas, focinho
    head = rig.empty("head", (0, -0.02, 0.86), body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "mapi_fur_l2", head, group="head")
    # rosto (pele) na frente da cabeca
    FC = HC + Vector((0, -0.13, -0.03))
    FR = (0.25, 0.16, 0.22)
    rig.add_mesh(R.ellipsoid("face", FC, FR), "face", "warm_skin_l2", head)
    # franja de pelo desgrenhada no alto
    for k in range(9):
        a = -1.2 + 2.4 * k / 8
        p = HC + Vector((HR[0] * 0.9 * math.sin(a), -HR[1] * 0.55 * math.cos(a), HR[2] * 0.75))
        d = Vector((math.sin(a) * 0.7, -0.35, 0.65)).normalized()
        rig.add_mesh(R.cone(f"htuft{k}", p, p + d * (0.13 + 0.04 * (k % 2)), 0.07, 0.006, seg=7, rings=2,
                            bend=(0, -0.02, -0.02)), "htuft", "mapi_fur_l2", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        b = HC + Vector((0.25 * sx, 0.02, 0.06))
        rig.add_mesh(R.ellipsoid(f"ear{nm}", b, (0.06, 0.04, 0.07), rot=(0, 0.4 * sx, 0)), f"ear{nm}", "mapi_fur_l2", head)
        rig.add_mesh(R.ellipsoid(f"earin{nm}", b + Vector((0.0, -0.025, 0)), (0.035, 0.02, 0.045), rot=(0, 0.4 * sx, 0)),
                     f"earin{nm}", "nose_n", head, noline=True)
    ez = FC.z + 0.03
    ep = Vector((0, S.ysurf(FC, FR, 0, ez) + 0.012, ez))
    S.eye(rig, "L", ep, head, 0.15, 0.19, 0.0, mode="glow")
    k = 0.19 / 0.145
    for sx, nm in ((1, "bL"), (-1, "bR")):  # sobrancelha em V sobre o olho unico
        a = ep + Vector((0.02 * sx, -0.04, 0.13)) * k
        b = ep + Vector((0.17 * sx, 0.0, 0.2)) * k
        rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.03 * k, 0.024 * k, seg=8, rings=1), f"brow{nm}", "brow_n", head,
                     noline=True, unlit=True, prio=3.2)
    # narinas no focinho (sem boca no rosto: a boca e da barriga)
    for sx in (1, -1):
        rig.add_mesh(R.ellipsoid(f"nost{sx}", (0.03 * sx, S.ysurf(FC, FR, 0.03, FC.z - 0.11) - 0.004, FC.z - 0.11),
                                 (0.016, 0.01, 0.012)), "nost", "brow_n", head, noline=True, unlit=True, prio=2.0)
    for sx in (1, -1):  # bochechas de luz fria (veias da corrupcao)
        rig.add_mesh(R.ellipsoid(f"vein{sx}", (0.13 * sx, S.ysurf(FC, FR, 0.13, FC.z - 0.07) - 0.004, FC.z - 0.07),
                                 (0.03, 0.01, 0.012), rot=(0, 0.5 * sx, 0)), "vein", "wisp_v", head, noline=True, unlit=True,
                     prio=1.5)
    head.rotation_euler.x += HEAD_TILT
    # ---- particulas: brasas violeta subindo, pedrinhas que voam no golpe
    S.add_motes(rig, "rise", [(0.35 * math.cos(k * 2.1), 0.2 + 0.25 * math.sin(k * 2.1), 0.9 + 0.1 * (k % 3))
                              for k in range(7)], ["wisp_v", "wisp_v2", "cold"], size=0.024, parent=root)
    S.add_motes(rig, "rock", [(0, 0, 0.05)] * 9, ["basalt_n", "fang_n", "cold_hot"], size=0.04, parent=root)
    S.hide_motes(rig, "rock")
    rig.save_rest()
    return rig


def _glyph(rig, nm, p, parent, s):
    """Glifo de Ratanaba aceso (luz fria): olho-espiral = aro + traco + ponto."""
    p = Vector(p)
    rig.add_mesh(S.torus(nm + "o", p, s * 0.6, s * 0.14, rot=(math.pi / 2 - 0.3, 0, 0), nu=14, nv=5), nm, "cold_hot", parent,
                 noline=True, unlit=True, prio=2.8)
    rig.add_mesh(R.ellipsoid(nm + "d", p + Vector((0, -0.004, 0)), (s * 0.2, s * 0.1, s * 0.2)), nm, "cold_hot", parent,
                 noline=True, unlit=True, prio=2.8)
    rig.add_mesh(R.cone(nm + "t", p + Vector((-s * 0.9, -0.004, -s * 0.85)), p + Vector((s * 0.9, -0.004, -s * 0.85)),
                        s * 0.12, s * 0.12, seg=5, rings=1), nm, "cold_hot", parent, noline=True, unlit=True, prio=2.8)


# ------------------------------------------------------------------ animacao
def _mouth(rig, o):
    """o = 0 fechada (sorriso de dentinhos), 1 = rugido."""
    rig.n("lipU").location.z += 0.05 * o
    rig.n("lipD").location.z -= 0.07 * o
    m = rig.n("mouthin")
    m.scale = (1.0 + 0.15 * o, 1.0, 0.5 + 2.2 * o)
    t = rig.n("tongue")
    t.location.z -= 0.05 * o


def _arms(rig, ax, az=0.0, el=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg
        rig.n(f"fore{nm}").rotation_euler.x += el


def _legs(rig, phase, amp, lift):
    for nm, off in (("L", 0.0), ("R", 0.5)):
        leg = rig.n(f"leg{nm}")
        a = math.sin(math.tau * (phase + off))
        leg.rotation_euler.x = -amp * a
        leg.location.z += lift * max(0.0, math.sin(math.tau * (phase + off) + math.pi / 2))


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "rise", t, rise=0.4, spread=1.0)
    S.motes(rig, "smoke", t, rise=0.35, spread=1.5, drift=0.06)
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(body, 1.0 + 0.035 * s)
        head.location.z += 0.012 * math.sin(math.tau * (t - 0.12))
        head.rotation_euler.y += 0.05 * math.sin(math.tau * t)
        _arms(rig, 0.06 * math.sin(math.tau * (t - 0.1)), 0.03 * s)
        _mouth(rig, 0.15 + 0.15 * max(0.0, math.sin(math.tau * 2 * t)))
        C.flames(rig, t)
        if i == n - 3:
            S.blink(rig, 1.0, names=("L",))
    elif anim == "walk":
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.03 * b
        R.squash(root, 1.0 + 0.05 * (b - 0.5))
        root.rotation_euler.y += 0.1 * math.sin(math.tau * t)
        _legs(rig, t, 0.45, 0.06)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"arm{nm}").rotation_euler.x += 0.35 * sg * math.sin(math.tau * t)
        head.rotation_euler.y -= 0.06 * math.sin(math.tau * t)
        _mouth(rig, 0.2)
        C.flames(rig, t, sway=0.2)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        R.squash(root, [0.86, 1.08, 0.96, 1.0][i])
        R.tilt(root, [-0.12, 0.05, 0.0, 0.0][i], 0.3)
        S.blink(rig, [0.9, 0.6, 0.0, 0.0][i], names=("L",))
        head.rotation_euler.x += [-0.12, 0.04, 0.0, 0.0][i]
        _mouth(rig, [0.8, 0.5, 0.25, 0.15][i])
        _arms(rig, [-0.5, -0.3, -0.1, 0.0][i], [0.15, 0.1, 0.03, 0.0][i])
        C.flames(rig, i / 4.0, k=[1.12, 1.05, 1.0, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Ergue os dois punhos acima da cabeca, esmaga o chao na frente; a boca da barriga ruge e pedras voam."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    R.squash(root, [1.06, 1.12, 1.14, 0.8, 0.9, 1.0, 1.02, 1.0][i])
    R.tilt(root, [-0.08, -0.14, -0.16, 0.2, 0.18, 0.1, 0.04, 0.0][i], 0.35)
    _arms(rig, [-1.4, -2.0, -2.25, -0.55, -0.5, -0.35, -0.2, 0.0][i], [0.25, 0.3, 0.3, -0.05, -0.05, 0.0, 0.0, 0.0][i],
          [-0.3, -0.5, -0.6, 0.0, 0.0, 0.0, 0.0, 0.0][i])
    head.rotation_euler.x += [-0.1, -0.16, -0.18, 0.15, 0.12, 0.06, 0.02, 0][i]
    _mouth(rig, [0.3, 0.5, 0.6, 1.0, 1.0, 0.8, 0.45, 0.2][i])
    if i in (0, 1):
        S.blink(rig, 0.4, names=("L",))
    C.flames(rig, i / 8, k=[1.05, 1.12, 1.18, 1.3, 1.25, 1.15, 1.05, 1.0][i])
    vel = [(0.5 * math.cos(math.pi * k / 8), -0.3 + 0.3 * math.sin(math.pi * k / 8), 1.3 + 0.25 * (k % 2)) for k in range(9)]
    S.splash(rig, "rock", [0, 0, 0, 0.1, 0.25, 0.42, 0.6, 0][i], Vector((0, -0.42, 0.1)), vel, g=4.0, shrink=0.6,
             floor=0.06)


def _death(rig, i):
    """O fogo negro apaga; ele cambaleia, senta e tomba de costas, olho fechado."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    C.flames(rig, i / 8, k=[1.2, 0.9, 0.6, 0.35, 0.15, 0.0, 0.0, 0.0][i])
    S.motes(rig, "rise", i / 8, rise=0.4, fade=max(0.0001, 1.0 - i / 5))
    fall = [0.0, 0.08, -0.15, -0.5, -0.95, -1.2, -1.12, -1.15][i]
    R.squash(root, [0.86, 1.04, 0.9, 1.0, 0.95, 1.03, 0.98, 1.0][i])
    R.tilt(root, fall, -0.3)
    if i >= 3:
        root.location.y -= 0.42 * min(1.0, -fall / 1.15)   # deitado de costas: centra o corpo no quadro
        root.location.z += 0.02
    S.blink(rig, [0.9, 0.5, 0.7, 0.9, 1.0, 1.0, 1.0, 1.0][i], names=("L",))
    _mouth(rig, [0.8, 0.6, 0.9, 0.7, 0.5, 0.35, 0.3, 0.3][i])
    _arms(rig, [-0.5, -0.3, -0.9, -1.4, -1.6, -1.5, -1.55, -1.55][i], [0.3, 0.2, 0.6, 0.9, 1.0, 1.0, 1.0, 1.0][i])
    if i >= 2:
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"leg{nm}").rotation_euler.x += [-0.3, -0.6, -0.9, -0.8, -0.85, -0.85][i - 2]
