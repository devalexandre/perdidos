"""Cuca Atroz (story_cuca) — chefe da historia do Arco 1, capitulo 8 (Tuneis da Terra Oca, camara do caldeirao).
Decisao do dono (07/10/2026): a Cuca e uma bruxa JOVEM, bonita e elegante, de ar misterioso e sorriso confiante,
sem sensualizacao (vestido longo fechado, gola alta, nada de decote ou pose) e chibi de rosto expressivo.
Design 100% original: a referencia de clima citada (bruxa bonita, misteriosa, urbana-folclorica) NAO e copiada
(nada de figurino, penteado, rosto ou elemento reconhecivel de serie/atriz). Nunca a Cuca jacare do Sitio do Picapau
Amarelo (obra autoral). So existe na forma atroz (estagio 4, a noite).
Chibi: cabelo preto longo e volumoso com reflexo violeta e duas mechas cobre, franja de lado, grampo de lua
crescente; olhos grandes amendoados acesos em verde (a luz da pocao), cilios, sobrancelha fina arqueada, sorriso de
canto, pinta; vestido vinho longo bordado de luas e folhas de erva, capa curta de gola alta com debrum dourado,
colar de amuletos (lua, pedra, chavinha), unhas pintadas. Um caldeirao pequeno flutua ao lado dela, a pocao verde
borbulha e o fogo debaixo dele e o fogo negro da corrupcao (pontas violeta); a mao erguida segura uma chama negra.
  idle: a chama danca na palma, o caldeirao boia e borbulha, o cabelo balanca; walk: desliza, o vestido ondula;
  attack: feitico-cantiga (ergue a mao, notas e fumaca negra voam para a frente, o caldeirao espirra pocao);
  hit: encolhe, olhos apertados; death: se desfaz em fumaca e mariposas (o corpo gira e encolhe dentro da fumaca;
  sobram mariposas voando e o caldeirao tombado).
Modelo proprio por script; olhos no desenho do Tatu-Pedra (sol_common), em versao amendoada."""
import math
from mathutils import Vector, Matrix
import mon_rig as R
import sol_common as S
import story_common_l2 as C

SCALE = {4: 3.0}
FRAME = {4: 240}
STAGES = (4,)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
LEAN = 7.0
HEAD_TILT = -0.42

HC = Vector((0, -0.02, 0.98))
HR = (0.28, 0.24, 0.25)
NECK = Vector((0, 0.0, 0.7))
POT = Vector((0.4, -0.12, 0.3))     # caldeirao flutuando a direita dela (lado +X)
POT_R = (0.15, 0.14, 0.11)


def build(stage):
    if stage not in STAGES:
        raise ValueError("so a forma atroz (4)")
    R.reset()
    R.CUR["reach"] = (0.35, 0.3, 0.4)
    rig = R.Rig("story_cuca")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", (0, 0.03, 0.05), root)
    # ---- vestido longo em sino, barra ondulada (anima no andar)
    skirt = rig.empty("skirt", (0, 0.03, 0.45), body)

    def dfn(u, v):
        a = math.tau * u
        z = 0.68 - 0.66 * v
        r = 0.12 + 0.24 * v ** 1.3
        wave = 0.03 * math.sin(a * 6) * v ** 3
        return Vector(((r + wave) * math.cos(a), 0.03 + (r + wave) * math.sin(a) * 0.92, z))
    rig.add_mesh(R.surface("dress", dfn, 36, 9, (0, 0.03, 0.35)), "dress", "dress_l2", skirt, group="dress")
    rig.add_mesh(R.ellipsoid("bodice", (0, 0.03, 0.6), (0.13, 0.115, 0.12)), "dress", "dress_l2", body, group="dress")
    # bordados: luas crescentes douradas e folhas de erva na saia
    for k, (a, z, kind) in enumerate(((-1.95, 0.22, "moon"), (-1.2, 0.14, "leaf"), (-1.57, 0.36, "moon"),
                                      (-0.75, 0.3, "leaf"), (-2.4, 0.33, "leaf"), (-0.5, 0.12, "moon"),
                                      (-2.65, 0.12, "moon"))):
        v = (0.68 - z) / 0.66
        r = (0.12 + 0.24 * v ** 1.3) * 1.02
        p = Vector((r * math.cos(a), 0.03 + r * math.sin(a) * 0.92, z))
        nrm = Vector((math.cos(a), math.sin(a), 0.25)).normalized()
        if kind == "moon":
            rig.add_mesh(S.torus(f"emb{k}", p, 0.026, 0.008, rot=S.align(nrm), nu=12, nv=4), "emb_moon", "gold_n", skirt,
                         noline=True, unlit=True, prio=1.6)
            rig.add_mesh(R.ellipsoid(f"embc{k}", p + nrm * 0.006 + Vector((0.012, 0, 0.008)), (0.02, 0.006, 0.02),
                                     rot=S.align(nrm)), "emb_cut", "dress_l2", skirt, noline=True, unlit=True, prio=1.7)
        else:
            rig.add_mesh(R.ellipsoid(f"emb{k}", p, (0.012, 0.005, 0.03), rot=S.align(nrm)), "emb_leaf", "moss_n", skirt,
                         noline=True, unlit=True, prio=1.6)
    rig.add_mesh(S.torus("hem", (0, 0.03, 0.035), 0.355, 0.016, nu=36, yscale=0.92), "hem", "gold_n", skirt)

    # capa curta de gola alta (aberta na frente) com debrum dourado
    def kfn(u, v):
        a = -math.pi / 2 + math.pi * (0.22 + 1.56 * u)
        z = 0.74 - 0.3 * v
        r = 0.14 + 0.14 * v
        return Vector((r * math.cos(a), 0.05 + r * math.sin(a) * 0.95, z + 0.02 * S.zigzag(a, 9, 1.0) * v))
    rig.add_mesh(R.surface("cape", kfn, 24, 5, (0, 0.12, 0.6)), "cape", "hat", body)
    rig.add_mesh(R.cone("collar", (0, 0.05, 0.68), (0, 0.05, 0.8), 0.13, 0.16, seg=20, rings=2), "collar", "hat", body)
    rig.add_mesh(S.torus("collartrim", (0, 0.05, 0.8), 0.16, 0.012, nu=24), "collartrim", "gold_n", body)
    # colar de amuletos (lua, pedra, chavinha)
    rig.add_mesh(S.torus("am_moon", (0.0, -0.13, 0.6), 0.022, 0.007, rot=(math.pi / 2 - 0.4, 0, 0), nu=12), "amulet",
                 "gold_n", body, prio=2.4)
    rig.add_mesh(R.ellipsoid("am_stone", (-0.05, -0.12, 0.61), (0.016, 0.01, 0.022)), "am_stone", "cold_hot", body,
                 noline=True, unlit=True, prio=2.4)
    rig.add_mesh(R.cone("am_key", (0.05, -0.12, 0.63), (0.055, -0.12, 0.58), 0.008, 0.008, seg=5, rings=1), "amulet",
                 "gold_n", body, prio=2.4)
    # ---- bracos: mangas com boca larga, maos finas, unhas pintadas; a direita (lado -X) erguida com a chama negra
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((0.13 * sx, 0.03, 0.66))
        arm = rig.empty(f"arm{nm}", sp, body)
        ep = sp + (Vector((0.1, -0.08, -0.16)) if sx > 0 else Vector((-0.13, -0.1, 0.02)))
        rig.add_mesh(R.cone(f"sleeve{nm}", sp, ep, 0.045, 0.07, seg=12, rings=3), f"sleeve{nm}", "dress_l2", arm,
                     group=f"arm{nm}")
        rig.add_mesh(S.torus(f"cuff{nm}", ep, 0.066, 0.01, rot=S.align(ep - sp), nu=16), f"cuff{nm}", "gold_n", arm)
        hand = rig.empty(f"hand{nm}", ep, arm)
        hp = ep + (ep - sp).normalized() * 0.04
        rig.add_mesh(R.ellipsoid(f"hand{nm}", hp, (0.035, 0.03, 0.04)), f"hand{nm}", "moon_skin_l2", hand, group=f"hand{nm}")
        for c in (-1, 0, 1):
            b = hp + Vector((0.018 * c, -0.02, 0.01))
            tip = b + (Vector((0.008 * c, -0.02, -0.045)) if sx > 0 else Vector((0.01 * c, -0.02, 0.05)))
            rig.add_mesh(R.cone(f"fing{nm}{c}", b, tip, 0.009, 0.007, seg=5, rings=1), f"hand{nm}", "moon_skin_l2", hand,
                         group=f"hand{nm}")
            rig.add_mesh(R.ellipsoid(f"nail{nm}{c}", tip, (0.009, 0.007, 0.011)), "nail", "wisp_v", hand, noline=True,
                         unlit=True, prio=2.5)
        if sx < 0:
            C.black_flame(rig, "palm", hp + Vector((0, -0.02, 0.06)), (0, 0, 1), 0.22, 0.055, hand, phase=0.2, bend=0.3)
    # ---- cabeca chibi
    head = rig.empty("head", NECK, body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "moon_skin_l2", head, group="head")
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.112 * sx, HC.z - 0.02
        ep = Vector((ex, S.ysurf(HC, HR, ex, ez) + 0.012, ez))
        # olho amendoado: mais largo que alto e inclinado (canto de fora mais alto)
        e = S.eye(rig, nm, ep, head, 0.1, 0.118, -0.42 * sx, mode="normal", iris="brew_l2", tilt=0.25)
        e.rotation_euler.y = -0.22 * sx
        # sobrancelha fina, arqueada e confiante
        a = ep + Vector((-0.07 * sx, -0.03, 0.14))
        m = ep + Vector((0.01 * sx, -0.015, 0.175))
        b = ep + Vector((0.1 * sx, 0.03, 0.15))
        rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.011, 0.007, seg=6, rings=4, bend=(m - (a + b) * 0.5) * 1.2), f"brow{nm}",
                     "brow_n", head, noline=True, unlit=True, prio=3.0)
        # cilios no canto de fora
        for j in range(2):
            c0 = ep + Vector((0.085 * sx, -0.02, 0.05 - 0.035 * j))
            rig.add_mesh(R.cone(f"lash{nm}{j}", c0, c0 + Vector((0.045 * sx, 0.0, 0.03 - 0.01 * j)), 0.011, 0.003, seg=5,
                                rings=1), "lash", "brow_n", e, noline=True, unlit=True, prio=3.2)
    # sorriso de canto + pinta
    mz = HC.z - 0.15
    my = S.ysurf(HC, HR, 0.0, mz)
    jaw = rig.empty("jaw", (0, my, mz), head)
    rig.add_mesh(R.cone("smile", (-0.04, my - 0.006, mz + 0.008), (0.05, my - 0.004, mz + 0.022), 0.011, 0.009, seg=6,
                        rings=5, bend=(0, -0.004, -0.018)), "smile", "nose_n", jaw, noline=True, unlit=True, prio=2.6)
    rig.add_mesh(R.ellipsoid("mouthin", (0.005, my - 0.002, mz - 0.004), (0.035, 0.008, 0.012)), "mouthin", "mouth_in", jaw,
                 noline=True, unlit=True, prio=2.0)
    rig.add_mesh(R.ellipsoid("mole", (0.1, S.ysurf(HC, HR, 0.1, mz + 0.02) - 0.003, mz + 0.02), (0.008, 0.005, 0.008)),
                 "mole", "brow_n", head, noline=True, unlit=True, prio=2.8)
    # ---- cabelo preto volumoso: calota com franja de lado, volume atras e mechas compridas ate a cintura
    hairp = rig.empty("hair", HC, head)

    def edge(ph):
        side = math.atan2(math.sin(ph + math.pi / 2), math.cos(ph + math.pi / 2))  # 0 = frente
        fr = 0.42 + 0.35 * max(0.0, math.sin(side)) ** 1.5   # franja de lado (mais comprida de um lado)
        return S.bob(ph, fr, 1.95, open_=0.7, ramp=0.7) + S.zigzag(ph + 0.4, 12, 0.08)
    rig.add_mesh(S.cap("hair", HC, HR, 0.0, edge, lift=1.08, nv=8), "hair", "witch_hair_l2", hairp)
    rig.add_mesh(R.ellipsoid("hairvol", HC + Vector((0, 0.1, 0.02)), (0.33, 0.24, 0.27)), "hairvol", "witch_hair_l2", hairp)
    gp = HC + Vector((-0.17, -0.1, 0.17))   # grampo de lua crescente
    rig.add_mesh(S.torus("pin", gp, 0.04, 0.012, rot=(math.pi / 2 - 0.5, 0.3, 0), nu=14), "pin", "gold_n", hairp, prio=2.4)
    rig.add_mesh(R.ellipsoid("pincut", gp + Vector((0.02, -0.012, 0.012)), (0.03, 0.012, 0.03)), "pincut", "witch_hair_l2",
                 hairp, prio=2.6)
    # mechas compridas (no corpo, para a inclinacao da cabeca nao empurra-las)
    Rx = Matrix.Rotation(HEAD_TILT, 3, "X")

    def hrot(p):
        return NECK + Rx @ (Vector(p) - NECK)
    mane = rig.empty("mane", hrot(HC + Vector((0, 0.12, 0))), body)
    rig.strands = []
    for j in range(9):
        a = -1.75 + 3.5 * j / 8
        top = hrot(HC + Vector((math.sin(a) * HR[0] * 0.95, math.cos(a) * HR[1] * 0.9 + 0.04, 0.0)))
        bot = Vector((math.sin(a) * 0.3, 0.12 + math.cos(a) * 0.17, 0.36 + 0.05 * (j % 2)))
        out = Vector((math.sin(a), math.cos(a) * 0.7, 0)).normalized()
        copper = j in (1, 7)
        st = rig.empty(f"strand{j}", top, mane)
        rig.add_mesh(R.cone(f"strand{j}", top, bot, 0.1, 0.012, seg=10, rings=6, bend=out * 0.1 + Vector((0, 0, -0.02))),
                     f"strand{j}" if copper else "strands", "copper_l2" if copper else "witch_hair_l2", st,
                     group=None if copper else "mane")
        rig.strands.append(f"strand{j}")
    head.rotation_euler.x += HEAD_TILT
    # ---- caldeirao pequeno flutuando, fogo negro embaixo
    pot = rig.empty("pot", POT, root)
    rig.add_mesh(R.ellipsoid("potb", POT, POT_R, seg=24, rings=14), "potb", "fur_slate_n", pot)
    rz = POT.z + POT_R[2] * 0.72
    rig.add_mesh(S.torus("potrim", (POT.x, POT.y, rz), POT_R[0] * 0.8, 0.024, nu=24, yscale=POT_R[1] / POT_R[0]), "potrim",
                 "fur_slate_n", pot)
    rig.add_mesh(R.ellipsoid("brew", (POT.x, POT.y, rz + 0.006), (POT_R[0] * 0.75, POT_R[1] * 0.75, 0.01)), "brew",
                 "brew_l2", pot, noline=True, unlit=True, prio=1.4)
    for k, (dx, dy) in enumerate(((0.04, -0.01), (-0.05, 0.02))):
        rig.add_mesh(R.ellipsoid(f"brewbub{k}", (POT.x + dx, POT.y + dy, rz + 0.016), (0.022, 0.022, 0.016)), "bubs", "brew2_l2",
                     pot, noline=True, unlit=True, prio=1.8)
    C.black_flame(rig, "pfl", POT + Vector((0, -0.02, -POT_R[2] - 0.13)), (0, 0, 1), 0.2, 0.08, pot, phase=0.5, bend=0.3)
    # ---- particulas
    S.add_motes(rig, "bub", [POT + Vector((0.07 * math.cos(k * 2.3), 0.06 * math.sin(k * 2.3), POT_R[2] * 0.8))
                             for k in range(5)], ["brew_l2", "brew2_l2"], size=0.022, parent=pot)
    S.add_motes(rig, "rise", [(0.3 * math.cos(k * 2.1), 0.1 + 0.2 * math.sin(k * 2.1), 0.6 + 0.12 * (k % 3))
                              for k in range(6)], ["wisp_v", "brew2_l2", "bfire_l2"], size=0.022, parent=root)
    # feitico-cantiga: notas e fumaca negra para a frente
    rig.notes = []
    hpR = Vector((-0.27, -0.1, 0.72))
    for j in range(4):
        C.note(rig, f"note{j}", hpR + Vector((0, -0.05, 0.1)), root, mat=("brew_l2", "wisp_v", "bfire_tip_l2", "brew2_l2")[j],
               k=0.8, double=j % 2 == 1)
        rig.notes.append(f"note{j}")
    S.add_motes(rig, "puff", [(0, 0, 0.6)] * 8, ["bfire_l2", "bfire_core_l2"], size=0.05, parent=root)
    S.add_motes(rig, "splash", [(0, 0, 0.5)] * 6, ["brew_l2", "brew2_l2"], size=0.03, parent=root)
    # morte: mariposas (asas violeta com olho dourado) saindo da fumaca
    rig.moths = []
    for j in range(5):
        p = Vector((-0.2 + 0.1 * j, -0.05 + 0.03 * (j % 2), 0.4 + 0.08 * (j % 3)))
        mo = rig.empty(f"moth{j}", p, root)
        rig.add_mesh(R.ellipsoid(f"mothb{j}", p, (0.012, 0.012, 0.03)), "mothb", "bfire_l2", mo, noline=True, unlit=True,
                     prio=3.0)
        for sx in (1, -1):
            w = rig.empty(f"moth{j}w{sx}", p, mo)
            rig.add_mesh(R.ellipsoid(f"mothw{j}{sx}", p + Vector((0.045 * sx, 0, 0.01)), (0.045, 0.008, 0.035),
                                     rot=(0, 0.3 * sx, 0)), "mothw", "wing_n", w, prio=2.8)
            rig.add_mesh(R.ellipsoid(f"motho{j}{sx}", p + Vector((0.05 * sx, -0.01, 0.015)), (0.012, 0.006, 0.012)),
                         "motho", "ember_hot", w, noline=True, unlit=True, prio=3.5)
        rig.moths.append(f"moth{j}")
    rig.save_rest()
    for nm in rig.notes + rig.moths:
        rig.n(nm).scale = (0.0001,) * 3
    S.hide_motes(rig, "puff")
    S.hide_motes(rig, "splash")
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _hair(rig, t, amp=1.0, lift=0.0):
    m = rig.n("mane")
    m.rotation_euler.z += 0.03 * amp * math.sin(math.tau * t)
    m.rotation_euler.x += 0.02 * amp * math.sin(math.tau * t + 1.0) + lift
    for j, nm in enumerate(rig.strands):
        rig.n(nm).rotation_euler.y += 0.05 * amp * math.sin(math.tau * t + j * 0.7)


def _pot(rig, t, amp=1.0):
    p = rig.n("pot")
    p.location.z += 0.04 * amp * math.sin(math.tau * t)
    p.rotation_euler.y += 0.08 * amp * math.sin(math.tau * t + 0.6)


def _smile(rig, o):
    """o > 0 = boca abre (canta/ri)."""
    rig.n("jaw").scale = (1.0, 1.0, 1.0 + 1.4 * o)


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    if anim != "death":
        S.motes(rig, "bub", t, rise=0.15, spread=0.4)
        S.motes(rig, "rise", t, rise=0.4, spread=0.8)
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(body, 1.0 + 0.025 * s)
        head.rotation_euler.y += 0.08 * math.sin(math.tau * t)
        head.rotation_euler.z += 0.05 * math.sin(math.tau * t + 0.5)   # inclina a cabeca, confiante
        rig.n("armR").rotation_euler.x += 0.08 * math.sin(math.tau * t)
        rig.n("handR").rotation_euler.z += 0.3 * math.sin(math.tau * t)
        _hair(rig, t)
        _pot(rig, t)
        rig.n("skirt").rotation_euler.z += 0.06 * math.sin(math.tau * t)
        C.flames(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
    elif anim == "walk":
        b = abs(math.sin(math.tau * t))
        body.location.z += 0.025 * b
        body.rotation_euler.y += 0.05 * math.sin(math.tau * t)
        sk = rig.n("skirt")
        sk.rotation_euler.x += 0.08
        sk.rotation_euler.z += 0.12 * math.sin(math.tau * t)
        R.squash(sk, 1.0 + 0.04 * math.sin(math.tau * 2 * t), anchored=False)
        _hair(rig, t, 1.6, 0.06)
        _pot(rig, t + 0.3, 1.4)
        C.flames(rig, t, sway=0.25)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        R.squash(body, [0.88, 1.06, 0.98, 1.0][i])
        body.rotation_euler.x += [-0.16, 0.05, 0.0, 0.0][i]
        head.rotation_euler.x += [-0.15, 0.04, 0.0, 0.0][i]
        S.blink(rig, [0.9, 0.6, 0.0, 0.0][i])
        _smile(rig, [0.8, 0.4, 0.1, 0.0][i])
        _hair(rig, 0.0, 0.0, [0.12, 0.06, 0.02, 0.0][i])
        rig.n("armR").rotation_euler.x += [0.4, 0.2, 0.05, 0.0][i]
        C.flames(rig, i / 4.0, k=[1.2, 1.05, 1.0, 1.0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Feitico-cantiga: ergue a mao da chama, canta (notas) e sopra fumaca negra para a frente; o caldeirao espirra."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    armR = rig.n("armR")
    armR.rotation_euler.x += [-0.2, -0.45, -0.6, 0.35, 0.45, 0.3, 0.15, 0.0][i]
    armR.rotation_euler.y += [0.1, 0.25, 0.3, -0.1, -0.15, -0.1, 0.0, 0.0][i]
    rig.n("armL").rotation_euler.x += [-0.1, -0.3, -0.5, -0.8, -0.7, -0.5, -0.25, -0.1][i]
    body.rotation_euler.x += [-0.05, -0.1, -0.14, 0.12, 0.14, 0.08, 0.03, 0.0][i]
    head.rotation_euler.x += [-0.05, -0.1, -0.12, 0.08, 0.1, 0.05, 0.02, 0][i]
    _smile(rig, [0.2, 0.4, 0.5, 1.0, 1.0, 0.8, 0.5, 0.2][i])
    if i in (1, 2):
        S.blink(rig, 0.5)
    _hair(rig, i / 8, 1.0, [0.0, -0.03, -0.05, 0.08, 0.1, 0.06, 0.02, 0.0][i])
    _pot(rig, i / 8, 1.0)
    rig.n("pot").location.z += [0, 0.03, 0.06, 0.0, 0.02, 0.01, 0, 0][i]
    C.flames(rig, i / 8, k=[1.1, 1.25, 1.4, 1.5, 1.4, 1.25, 1.1, 1.0][i])
    dirs = [(-0.15, -0.55, 0.15), (0.15, -0.55, 0.25), (-0.05, -0.65, 0.05), (0.25, -0.5, 0.1)]
    for j, nm in enumerate(rig.notes):
        u = (i - 3 - j * 0.5) / 4.0
        o = rig.n(nm)
        if u < 0 or u > 1:
            o.scale = (0.0001,) * 3
            continue
        o.location += Vector(dirs[j]) * (0.15 + 0.55 * u)
        o.rotation_euler.y += 0.5 * math.sin(math.tau * u + j)
        o.scale = (1.0 + 0.2 * u,) * 3
    S.splash(rig, "puff", [0, 0, 0, 0.1, 0.22, 0.34, 0.46, 0.56][i], Vector((-0.27, -0.15, 0.82)),
             [(-0.2 + 0.07 * k, -0.75, 0.3 + 0.1 * (k % 3)) for k in range(8)], g=0.8, shrink=-0.6, floor=0.1)
    S.splash(rig, "splash", [0, 0, 0, 0.1, 0.22, 0.34, 0.46, 0][i], POT + Vector((0, 0, 0.12)),
             [(0.1 * math.cos(k * 1.1), -0.4 + 0.1 * math.sin(k * 1.1), 0.9 + 0.1 * (k % 2)) for k in range(6)], g=3.5,
             shrink=0.5, floor=0.08)


def _death(rig, i):
    """Se desfaz em fumaca e mariposas: o fogo apaga, ela gira e encolhe dentro da fumaca negra e as mariposas voam;
    no fim sobram tres mariposas e o caldeirao tombado no chao."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    C.flames(rig, i / 8, k=[1.2, 0.9, 0.6, 0.3, 0.1, 0.0, 0.0, 0.0][i])
    S.hide_motes(rig, "bub")
    S.motes(rig, "rise", i / 8, rise=0.4, fade=max(0.0001, 1.0 - i / 4))
    sc = [1.0, 0.98, 0.9, 0.7, 0.45, 0.2, 0.0001, 0.0001][i]
    R.squash(body, [0.9, 1.05, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i])
    body.scale = (body.scale.x * sc, body.scale.y * sc, body.scale.z * sc)
    body.rotation_euler.z += [0.0, 0.2, 0.6, 1.2, 2.0, 2.8, 3.2, 3.2][i]
    head.rotation_euler.x += [0.22, 0.1, 0.0, 0.0, 0, 0, 0, 0][i]
    S.blink(rig, [0.9, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i])
    _smile(rig, [0.8, 0.5, 0.2, 0.0, 0, 0, 0, 0][i])
    # nuvem de fumaca negra que cresce e some
    S.splash(rig, "puff", [0, 0.1, 0.22, 0.36, 0.5, 0.64, 0.8, 0][i], Vector((0, 0.0, 0.5)),
             [(0.35 * math.cos(k * 0.8), 0.25 * math.sin(k * 0.8), 0.3 + 0.1 * (k % 3)) for k in range(8)], g=0.3,
             shrink=-0.9, floor=0.1)
    # mariposas: saem do centro e voam em espiral para cima, batendo as asas
    for j, nm in enumerate(rig.moths):
        o = rig.n(nm)
        u = (i - 2 - j * 0.35) / 5.0
        if u <= 0 or (j >= 3 and i == 7):
            o.scale = (0.0001,) * 3
            continue
        u = min(u, 1.0)
        a = j * 1.3 + u * 3.0
        base = rig.rest[nm][0]
        o.location = base + Vector((0.18 * math.cos(a) * u, 0.12 * math.sin(a) * u, 0.45 * u))
        o.scale = (1.3, 1.3, 1.3)
        flap = 0.9 * math.sin(i * 2.4 + j)
        rig.n(f"{nm}w1").rotation_euler.y += flap
        rig.n(f"{nm}w-1").rotation_euler.y -= flap
    # o caldeirao cai e tomba
    pot = rig.n("pot")
    pot.location.z -= [0.0, 0.0, 0.05, 0.12, 0.2, 0.26, 0.26, 0.26][i]
    pot.rotation_euler.y += [0.0, 0.0, 0.1, 0.3, 0.6, 0.85, 0.8, 0.82][i]
    if i >= 4:
        rig.n("brew").scale = (0.0001,) * 3
