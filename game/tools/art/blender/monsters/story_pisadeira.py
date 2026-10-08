"""Pisadeira Atroz (story_pisadeira) — chefe da historia, Arco 1 cap. 5 (ARCO-1-TERRA-DO-SABIA.md). So existe na
forma atroz (estagio 4, quadro 240). Capitulo de terror, mas no estilo chibi e sem gore.
Velha magra e corcunda, agachada na ponta dos pes (a que sobe no peito de quem dorme): cabeleira branca desgrenhada
ate o chao, olhos ARREGALADOS (brancos, pupila pequena violeta, olheiras fundas), nariz comprido, sorriso fino de
poucos dentes; bracos compridos e finos com dedos longos e unhas enormes; camisola rasgada.
Tema de sono e pesadelo: lua crescente pairando atras do ombro e nevoa lilas nos pes. Corrupcao: fogo preto de pontas
violeta saindo do alto da cabeleira, fumaca preta subindo.
  idle: balanca devagar, entorta a cabeca aos trancos, os dedos tamborilam, a lua sobe e desce; nao pisca;
  walk: anda na ponta dos pes, curvada, bracos pendurados;
  attack: salta e desce pisando com as duas maos (a nevoa espalha);
  hit: tranco para tras, os olhos arregalam ainda mais, o cabelo arrepia;
  death: encolhe e afunda na propria camisola; a lua cai e a nevoa sobe.
Modelo proprio por script; regras de pixel art do stone_armadillo.py / sol_common.py."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S
import story_lote1 as C

SCALE = {4: 2.5}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 8.0
HEAD_TILT = -0.4

HC = Vector((0, -0.08, 0.86))
HR = (0.24, 0.215, 0.24)
BC = Vector((0, 0.04, 0.52))
BR = (0.13, 0.11, 0.15)


def crescent(name, center, rad, thick, a0, a1, yaw=0.0):
    """Lua crescente: arco de tubo com espessura maxima no meio e pontas finas (plano XZ)."""
    c = Vector(center)

    def fn(u, v):
        a = a0 + (a1 - a0) * u
        r = thick * max(0.04, math.sin(math.pi * u)) ** 0.8
        b = math.tau * v
        p = Vector(((rad + r * math.cos(b)) * math.cos(a), r * math.sin(b) * 0.6, (rad + r * math.cos(b)) * math.sin(a)))
        p = Vector((p.x * math.cos(yaw) - p.y * math.sin(yaw), p.x * math.sin(yaw) + p.y * math.cos(yaw), p.z))
        return c + p
    return R.surface(name, fn, 24, 10, c + Vector((rad * math.cos((a0 + a1) / 2), 0, rad * math.sin((a0 + a1) / 2))))


def build(stage=4):
    if stage not in STAGES:
        raise ValueError("story_pisadeira: so o estagio 4 (atroz)")
    R.reset()
    R.CUR["reach"] = (0.32, 0.3, 0.34)
    rig = R.Rig("story_pisadeira")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    # ---- pernas finas dobradas (agachada), pes compridos na ponta, unhas
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = 0.08 * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.04, 0.34), root)
        knee = Vector((hx * 2.3, -0.06, 0.3))
        ank = Vector((hx * 1.9, 0.04, 0.08))
        C.limb(rig, f"thigh{nm}", (hx, 0.04, 0.34), knee, 0.04, 0.032, "pis_skin_n", leg, group=f"leg{nm}")
        C.ell(rig, f"knee{nm}", knee, (0.036, 0.034, 0.036), "pis_skin_n", leg, group=f"leg{nm}")
        C.limb(rig, f"shin{nm}", knee, ank, 0.03, 0.026, "pis_skin_n", leg, group=f"leg{nm}")
        C.limb(rig, f"foot{nm}", ank, ank + Vector((0.01 * sx, -0.12, -0.06)), 0.03, 0.022, "pis_skin_n", leg,
               group=f"leg{nm}")
        for c in (-1, 0, 1):
            b = ank + Vector((0.01 * sx + 0.02 * c, -0.13, -0.065))
            rig.add_mesh(R.cone(f"tnail{nm}{c}", b, b + Vector((0.008 * c, -0.05, -0.008)), 0.011, 0.002, seg=5, rings=1),
                         "tnail", "pis_nail_n", leg, noline=True)
    # ---- camisola rasgada (saia em sino com barra em zigue-zague) e tronco corcunda
    body = rig.empty("body", (0, 0.04, 0.34), root)
    C.ell(rig, "torso", BC, BR, "pis_gown_n", body, group="gown")
    C.ell(rig, "hump", BC + Vector((0, 0.08, 0.08)), (0.12, 0.1, 0.1), "pis_gown_n", body, group="gown")

    def skirt(u, v):
        a = math.tau * u
        z = 0.48 - 0.32 * v
        r = 0.12 + 0.13 * v
        rag = 0.05 * v * (1 - abs(2 * ((u * 9) % 1.0) - 1))
        return Vector((r * math.cos(a), 0.04 + r * 0.85 * math.sin(a), z + rag))
    rig.add_mesh(R.surface("skirt", skirt, 36, 4, (0, 0.04, 0.35), closed_u=True), "skirt", "pis_gown_n", body, group="gown")
    # ---- bracos compridos e finos, dedos longos com unhas enormes
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.12 * sx, BC.y - 0.01, BC.z + 0.09))
        arm = rig.empty(f"arm{nm}", sp, body)
        el = sp + Vector((0.09 * sx, -0.06, -0.17))
        C.limb(rig, f"uarm{nm}", sp, el, 0.034, 0.026, "pis_skin_n", arm, group=f"arm{nm}")
        # manga rasgada
        C.limb(rig, f"slv{nm}", sp, sp + Vector((0.05 * sx, -0.02, -0.1)), 0.05, 0.035, "pis_gown_n", arm,
               group=f"slv{nm}", seg=8, rings=1)
        fore = rig.empty(f"fore{nm}", el, arm)
        hp = el + Vector((0.02 * sx, -0.1, -0.15))
        C.limb(rig, f"farm{nm}", el, hp, 0.026, 0.022, "pis_skin_n", fore, group=f"arm{nm}")
        C.ell(rig, f"hand{nm}", hp, (0.035, 0.03, 0.035), "pis_skin_n", fore, group=f"arm{nm}")
        fing = rig.empty(f"fing{nm}", hp, fore)
        for c in (-1.5, -0.5, 0.5, 1.5):
            b = hp + Vector((0.02 * c, -0.02, -0.02))
            m = b + Vector((0.012 * c, -0.04, -0.05))
            C.limb(rig, f"fg{nm}{c}", b, m, 0.012, 0.009, "pis_skin_n", fing, group=f"arm{nm}", seg=6, rings=1)
            rig.add_mesh(R.cone(f"nail{nm}{c}", m, m + Vector((0.01 * c, -0.05, -0.1)), 0.011, 0.002, seg=6, rings=3,
                                bend=(0, -0.025, 0.0)), f"nail{nm}", "pis_nail_n", fing, noline=True, prio=1.5)
    # ---- cabeca: cabeleira desgrenhada ate embaixo, olhos arregalados, nariz comprido
    head = rig.empty("head", (0, HC.y + 0.04, HC.z - HR[2] * 0.85), body)
    C.ell(rig, "head", HC, HR, "pis_skin_n", head, group="head")

    def edge(ph):
        return S.bob(ph, 0.7, 2.2, open_=0.75, ramp=0.5) + S.zigzag(ph + 0.3, 15, 0.14)
    rig.add_mesh(S.cap("hair", HC, HR, 0.0, edge, lift=1.08), "hair", "pis_hair_n", head, group="hair")
    # mechas compridas descendo pelas costas e pelos lados (pivo para balancar)
    hairs = rig.empty("hairs", HC + Vector((0, 0.05, 0.0)), head)
    for k in range(11):
        a = math.pi * (-0.15 + 1.3 * k / 10)          # de lado a lado passando por tras
        b = HC + Vector((HR[0] * 0.95 * math.cos(a), 0.02 + HR[1] * 0.9 * math.sin(a), -0.02))
        ln = 0.38 + 0.12 * ((k * 5) % 3) / 2
        tip = b + Vector((0.06 * math.cos(a), 0.05 * math.sin(a), -ln))
        C.limb(rig, f"strand{k}", b, tip, 0.06, 0.008, "pis_hair_n", hairs, group="hairs", seg=7, rings=3,
               bend=(0.03 * math.cos(a + 1.0), 0.02, 0))
    # mechas arrepiadas no alto
    for k in range(4):
        a = math.pi * (0.1 + 0.8 * k / 3)
        b = HC + Vector((HR[0] * 0.75 * math.cos(a), 0.05 + HR[1] * 0.3 * math.sin(a), HR[2] * 0.7))
        C.limb(rig, f"frizz{k}", b, b + Vector((0.13 * math.cos(a), 0.1, 0.02)), 0.04, 0.006,
               "pis_hair_n", head, group="hair", seg=6, rings=3, bend=(0, 0, 0.04))
    # olhos arregalados: branco grande, iris violeta pequena, pupila, brilho, olheira funda
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.1 * sx, HC.z + 0.0
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.012, ez))
        e = rig.empty(f"eye{nm}", ep, head)
        C.ell(rig, f"eyew{nm}", ep, (0.088, 0.04, 0.1), "stare_white", e, rot=(0.25, 0, -0.42 * sx), part=f"eyew{nm}",
              noline=True, unlit=True, prio=1.8)
        C.ell(rig, f"sock{nm}", ep + Vector((0, 0.014, 0.0)), (0.106, 0.035, 0.12), "eye_bag", e, rot=(0.25, 0, -0.42 * sx),
              part=f"sock{nm}", noline=True, unlit=True, prio=1.6)
        pv = rig.empty(f"pupil{nm}", ep, e)
        C.ell(rig, f"iris{nm}", ep + Vector((-0.008 * sx, -0.035, -0.005)), (0.04, 0.012, 0.042), "stare_iris", pv,
              noline=True, unlit=True, prio=3.0)
        C.ell(rig, f"pup{nm}", ep + Vector((-0.008 * sx, -0.045, -0.005)), (0.016, 0.01, 0.018), "stare_pupil", pv,
              noline=True, unlit=True, prio=4.0)
        C.ell(rig, f"hl{nm}", ep + Vector((-0.024 * sx + 0.01, -0.05, 0.03)), (0.013, 0.008, 0.013), "white", e,
              noline=True, unlit=True, prio=6.0)
        bag = ep + Vector((0.0, -0.02, -0.1))
        rig.add_mesh(R.cone(f"bag{nm}", bag + Vector((-0.07 * sx, 0, 0.02)), bag + Vector((0.07 * sx, 0.01, 0.0)), 0.014,
                            0.01, seg=6, rings=4, bend=(0, -0.01, -0.02)), f"bag{nm}", "eye_bag", head, noline=True,
                     unlit=True, prio=2.0)
        S.brow(rig, nm, ep, head, 0.8, -0.03, mat="pis_hair_n", thick=1.0, width=0.9, lift=0.03, prio=2.5)
    # nariz comprido e curvo
    nz = HC.z - 0.09
    ny = S.ysurf(HC, HR, 0, nz)
    C.limb(rig, "nose", (0, ny + 0.02, nz + 0.04), (0, ny - 0.11, nz - 0.04), 0.04, 0.016, "pis_skin_n", head,
           group="nose", bend=(0, -0.02, 0.02), seg=8, rings=3)
    # sorriso fino de poucos dentes
    mz = HC.z - 0.2
    my = S.ysurf(HC, HR, 0, mz)
    mouth = rig.empty("mouth", (0, my, mz), head)
    rig.add_mesh(R.cone("mouth", (-0.12, my + 0.0, mz + 0.035), (0.12, my + 0.0, mz + 0.035), 0.024, 0.024, seg=8, rings=6,
                        bend=(0, -0.012, -0.05)), "mouth", "mouth_in", mouth, noline=True, unlit=True, prio=2.0)
    for k, x in enumerate((-0.05, 0.015, 0.06)):
        b = Vector((x, my - 0.016, mz + 0.0 - 0.02 * (1 - abs(x) / 0.1) + 0.012))
        rig.add_mesh(R.cone(f"mt{k}", b, b + Vector((0, -0.004, -0.025)), 0.012, 0.004, seg=5, rings=1), "mtooth",
                     "pis_nail_n", mouth, noline=True, prio=3.0)
    # corrupcao: fogo preto saindo do alto da cabeleira
    C.corrupt_flame(rig, "hairfire", HC + Vector((0, 0.12, 0.1)), head, size=1.4, n=6, width=1.1, spread=2.2,
                    base_mat="cf_dark", core=None, height=1.0, black_from=0.35, lean=0.8, slim=0.7, hot="cf_tip")
    head.rotation_euler.x += HEAD_TILT - 0.22   # compensa a corcunda do corpo: rosto de frente para a luz
    # lua crescente pairando atras do ombro direito (dela)
    moon = rig.empty("moon", (-0.36, 0.12, 1.08), root)
    rig.add_mesh(crescent("moon", (-0.36, 0.12, 1.08), 0.11, 0.06, math.radians(110), math.radians(330), yaw=0.0), "moon",
                 "moon_n", moon)
    C.ell(rig, "moonstar", (-0.2, 0.1, 1.22), (0.018, 0.018, 0.018), "cf_tip", moon, noline=True, unlit=True, prio=2.0)
    # nevoa lilas no chao
    mist = rig.empty("mist", (0, 0, 0), root)
    for k in range(8):
        a = math.tau * k / 8
        p = Vector((0.4 * math.cos(a), 0.32 * math.sin(a), 0.03 + 0.03 * (k % 2)))
        C.ell(rig, f"mist{k}", p, (0.11 - 0.03 * (k % 2), 0.035, 0.018), "mist_n" if k % 2 == 0 else "mist2_n", mist,
              rot=(0, 0, 0.25 * math.sin(a)), part=f"mist{k % 2}", noline=True, unlit=True, prio=0.9)
    C.smoke(rig, "smk", [HC + Vector((0.1 * math.cos(k * 2.4), 0.14 + 0.05 * math.sin(k * 2.4), 0.45)) for k in range(5)],
            root, size=0.035)
    body.rotation_euler.x = 0.22      # corcunda
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _arms(rig, ax, az=0.0, fore=0.0):
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg
        rig.n(f"fore{nm}").rotation_euler.x += fore


def _fingers(rig, curl, alt=0.0):
    rig.n("fingL").rotation_euler.x += curl + alt
    rig.n("fingR").rotation_euler.x += curl - alt


def _stare(rig, k=1.0, dx=0.0, dz=0.0):
    for nm in ("L", "R"):
        e = rig.n(f"eye{nm}")
        e.scale = (k, k, k)
        p = rig.n(f"pupil{nm}")
        p.location.x += dx
        p.location.z += dz


def pose(rig, anim, i, n, stage=4):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    S.motes(rig, "smk", t, rise=0.28, spread=1.2)
    moon = rig.n("moon")
    if anim != "death":
        C.flicker(rig, "hairfire", t, amp=1.1)
        rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * t
        moon.location.z += 0.03 * math.sin(math.tau * t)
        moon.rotation_euler.y = 0.1 * math.sin(math.tau * t)
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(root, 1.0 + 0.025 * s)
        body.rotation_euler.y = 0.07 * s
        # entorta a cabeca aos trancos (segura e muda)
        tilt = [0.0, 0.0, 0.28, 0.28, 0.28, -0.12, -0.12, 0.0][i]
        head.rotation_euler.y = tilt
        _stare(rig, 1.0, [0.0, 0.0, 0.006, 0.006, 0.006, -0.006, -0.006, 0.0][i])
        _arms(rig, 0.06 * s, 0.05)
        _fingers(rig, 0.2 * math.sin(math.tau * 2 * t), 0.25 * math.sin(math.tau * 2 * t + 1.5))
        rig.n("hairs").rotation_euler.y = 0.05 * math.sin(math.tau * (t - 0.2))
        rig.n("mouth").scale.x = 1.0 + 0.08 * s
    elif anim == "walk":
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.04 * b
        R.squash(root, 1.0 + 0.04 * (b - 0.5))
        for nm, off in (("L", 0.0), ("R", 0.5)):
            a = math.sin(math.tau * (t + off))
            rig.n(f"leg{nm}").rotation_euler.x = -0.4 * a
            rig.n(f"leg{nm}").location.z += 0.04 * max(0.0, math.sin(math.tau * (t + off) + math.pi / 2))
        body.rotation_euler.y = 0.1 * math.sin(math.tau * t)
        head.rotation_euler.y = -0.1 * math.sin(math.tau * t)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"arm{nm}").rotation_euler.x += 0.25 * sg * math.sin(math.tau * t + 0.6)
        rig.n("hairs").rotation_euler.x = 0.06 * math.sin(math.tau * 2 * t)
        _fingers(rig, 0.15)
        _stare(rig, 1.0)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        R.squash(root, [0.86, 1.08, 0.97, 1.0][i])
        R.tilt(root, [-0.2, 0.07, -0.03, 0.0][i], 0.12)
        _stare(rig, [1.3, 1.18, 1.06, 1.0][i])
        _arms(rig, [-0.8, -0.4, -0.1, 0.0][i], [0.5, 0.3, 0.1, 0.0][i])
        rig.n("hairs").scale = (1.0 + [0.25, 0.15, 0.05, 0.0][i],) * 3
        head.rotation_euler.x += [0.18, -0.06, 0.0, 0.0][i]
        C.flicker(rig, "hairfire", t, amp=1.5, k=[1.3, 1.15, 1.05, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Agacha, salta com os bracos para cima e desce pisando com as duas maos (a nevoa espalha)."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    up = [0.0, -0.02, 0.14, 0.24, 0.1, 0.0, 0.0, 0.0][i]
    root.location.z += up
    R.squash(root, [0.84, 0.78, 1.14, 1.1, 1.0, 0.76, 0.92, 1.0][i])
    body.rotation_euler.x += [0.05, 0.1, -0.15, -0.2, 0.25, 0.4, 0.2, 0.0][i]
    _arms(rig, [0.3, 0.5, -2.2, -2.6, -1.2, -0.6, -0.3, 0.0][i], [0.3, 0.3, 0.5, 0.45, 0.25, 0.2, 0.1, 0.0][i],
          [0.0, 0.0, -0.4, -0.3, 0.2, 0.4, 0.2, 0.0][i])
    _fingers(rig, [0.4, 0.5, -0.3, -0.4, 0.3, 0.6, 0.3, 0.0][i])
    _stare(rig, [1.0, 1.05, 1.15, 1.2, 1.2, 1.25, 1.1, 1.0][i])
    rig.n("mouth").scale = (1.0 + [0, 0, 0.2, 0.3, 0.3, 0.4, 0.2, 0][i], 1, 1.0 + [0, 0, 1.0, 1.5, 1.5, 2.0, 1.0, 0][i])
    k = [1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 1.25, 1.1][i]
    rig.n("mist").scale = (k, k, 1.0 + 0.6 * (k - 1))
    C.flicker(rig, "hairfire", i / 8, amp=1.4, k=[1.0, 1.05, 1.2, 1.3, 1.2, 1.3, 1.1, 1.0][i])


def _death(rig, i):
    """Encolhe e afunda na camisola, a cabeca pende, os olhos fecham; a lua cai e a nevoa sobe."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    u = i / 7
    C.flicker(rig, "hairfire", i / 8, k=max(0.0, 1.1 - 0.22 * i))
    if i == 0:
        R.squash(root, 0.84)
        _stare(rig, 1.3)
    else:
        sq = 1.0 - 0.42 * R.ease(u)
        root.scale = (1.0 + 0.25 * R.ease(u), 1.0 + 0.25 * R.ease(u), sq)
        head.rotation_euler.x += 0.5 * R.ease(u)
        head.rotation_euler.y = 0.3 * R.ease(u)
        for nm in ("L", "R"):
            e = rig.n(f"eye{nm}")
            e.scale.z *= max(0.12, 1.0 - 1.2 * u)
    _arms(rig, -0.3 + 0.6 * u, 0.4 * u)
    _fingers(rig, 0.6 * u)
    rig.n("mist").rotation_euler.z = math.tau * 2 / 8 * (i / 8)
    k = 1.0 + 0.2 * u
    rig.n("mist").scale = (k, k, 1.0 + 2.0 * u)
    moon = rig.n("moon")
    moon.location.z -= 0.75 * R.ease(u)
    moon.rotation_euler.y = -1.2 * R.ease(u)
    if i >= 6:
        S.hide_motes(rig, "smk")
