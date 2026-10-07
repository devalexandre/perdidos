"""Aranha-Armadeira (wandering_spider, Phoneutria) — fauna peconhenta do Brasil. Modelo proprio por script
(venom_common.spider): cefalotorax-cabeca chibi com olhos grandes e sobrancelha brava, quelíceras ruivas com
presas, abdomen marrom-acinzentado com faixas escuras em "V" e pintas claras, 8 patas articuladas listradas
(claro/escuro). Marca da especie: parada e no golpe ergue as patas da frente (postura de "armar").
  s1 Aranha-Armadeira (quadro 96)   s2 Armadeira Veterana (144): maior, patas peludas, faixas mais fortes
  s3 Armadeira Rainha dos Desvaos (240, chefe — "Matriarca"): modelo proprio de chefe. Sempre empinada, com os
     dois pares da frente erguidos e canelas-lamina de marfim (foices); abdomen enorme com faixas douradas e ruivas,
     manto de teia pendurado dos dois lados ate o chao, 5 filhotes no dorso, coroa alta de cerdas ruivas, olhos
     acesos. Golpe: empina ainda mais e crava as foices no chao.
  s4 Aranha-Armadeira Atroz (240): mutacao noturna, outra silhueta — baixa e larga, 10 patas eriçadas de cerdas
     roxas com espinho no joelho, abdomen erguido atras como lanterna bioluminescente (faixas e pintas de luz fria),
     crista de espinhos, presas-sabre enormes pingando peconha, 8 olhos de brasa, fogos-fatuos e aro de luar."""
import math
from mathutils import Vector
import mon_rig as R
import venom_common as V

Z = V.Z

SCALE = {1: 0.92, 2: 1.3, 3: 1.82, 4: 1.66}
FRAME = {1: 96, 2: 144, 3: 240, 4: 240}
STAGES = (1, 2, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"ws_body": "chitin_n", "ws_abd": "chitin_n", "ws_dark": "obsidian_n", "ws_pale": "pale_n",
         "ws_fang": "fur_wine_n", "claw": "fang_n", "brow": "brow_n", "ws_leg": "chitin_n", "gold": "gold_n",
         "fur_white": "pale_n"}


def pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    # cefalotorax: faixa escura no meio + margens claras
    rig.add_mesh(R.plate("ctstripe", V.CT_C, ct_r, 0.35, 1.95, math.pi / 2 - 0.13, math.pi / 2 + 0.13, bulge=0.0, res=5,
                         lift=1.02), "ctstripe", "ws_band", head, noline=True)
    # abdomen: faixas escuras em V (chevrons) e pintas claras aos pares
    bands = (0.55, 0.95, 1.35, 1.75) if stage == 1 else (0.45, 0.8, 1.15, 1.5, 1.85)
    for j, ps in enumerate(bands):
        w = 0.09 + 0.01 * j
        for side, (o0, o1) in enumerate(((0.45, math.pi / 2 - 0.02), (math.pi / 2 + 0.02, math.pi - 0.45))):
            # V: a ponta do meio fica mais para tras
            sh = 0.08 if side == 0 else 0.08
            nm = f"chev{j}_{side}"
            rig.add_mesh(R.plate(nm, ab_c, ab_r, ps - w - sh * 0.5, ps + w - sh * 0.5, o0, o1, bulge=0.0, res=5,
                                 lift=1.018), "chev", "gold" if (stage == 3 and j % 2 == 1) else "ws_dark", abd,
                         noline=True, group="abd")
        if j < len(bands) - 1:
            for sx in (1, -1):
                p, n = V.on_ell(ab_c, ab_r, ps + 0.2, math.pi / 2 - 0.32 * sx, 1.01)
                rig.add_mesh(R.ellipsoid(f"dot{j}{sx}", p, (0.035, 0.035, 0.012), rot=V.align(n), seg=10, rings=6),
                             "dot", "ws_pale", abd, noline=True, group="abd")


def extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    if stage >= 3:
        # coroa de cerdas ruivas atras dos olhos
        crown = rig.empty("crown", V.CT_C + Vector((0, 0.05, ct_r[2])), head)
        for j, om in enumerate((-0.55, -0.27, 0.0, 0.27, 0.55)):
            p, n = V.on_ell(V.CT_C, ct_r, 1.6, math.pi / 2 + om, 0.95)
            h = 0.16 - 0.04 * abs(om) / 0.27
            up = (n + Vector((0, 0.3, 1.2))).normalized()
            rig.add_mesh(R.cone(f"crown{j}", p, p + up * h, 0.035, 0.004, seg=6, rings=2, bend=(0, 0.02, 0)),
                         f"crown{j}", "ws_fang", crown, group="crown")
        # saco de ovos de seda nas costas
        p, n = V.on_ell(ab_c, ab_r, 0.9, math.pi / 2, 1.0)
        rig.add_mesh(R.ellipsoid("eggsac", p + n * 0.04, (0.12, 0.1, 0.08), seg=14, rings=10), "eggsac", "fur_white",
                     abd)
        for j in range(3):
            q = p + n * 0.04 + Vector(((j - 1) * 0.07, 0.02 * j, 0.06))
            rig.add_mesh(R.ellipsoid(f"egg{j}", q, (0.035, 0.035, 0.03), seg=8, rings=6), "egg", "ws_pale", abd,
                         noline=True)
    if stage == 4:
        # laminas dorsais no abdomen, peconha de luz fria nas presas, brasas
        rig.blades = []
        for j, (ps, h) in enumerate(((0.55, 0.16), (0.95, 0.2), (1.35, 0.2), (1.75, 0.15))):
            for sx in (1, -1):
                p, n = V.on_ell(ab_c, ab_r, ps, math.pi / 2 - 0.55 * sx, 0.98)
                up = (n + Vector((0, 0.5, 0.6))).normalized()
                rig.add_mesh(R.cone(f"blade{j}{sx}", p, p + up * h, 0.05, 0.004, seg=5, rings=2,
                                    bend=(0.02 * sx, 0.03, 0)), f"blade{j}{sx}", "ws_dark", abd, group=f"blade{j}{sx}")
        for nm in ("L", "R"):
            fb = rig.n(f"fang{nm}")
            # gota de peconha (luz fria) na ponta da presa
            tip = Vector(fb.data.vertices[-1].co)
            rig.add_mesh(R.ellipsoid(f"drop{nm}", tip + Vector((0, 0, -0.03)), (0.018, 0.018, 0.028), seg=8, rings=6),
                         "drop", "cold_hot", rig.n(f"chel{nm}"), unlit=True, noline=True, prio=4.0)
        ep = rig.empty("embers", (0, 0, 0), rig.root)
        rig.embers = []
        for j in range(6):
            a = j * math.tau / 6 + 0.4
            p = Vector((0.5 * math.cos(a), 0.15 + 0.45 * math.sin(a), 0.2 + 0.07 * (j % 3)))
            e = rig.empty(f"emb{j}", p, ep)
            rig.add_mesh(R.ellipsoid(f"emb{j}", p, (0.022, 0.022, 0.03), seg=8, rings=5), "emb" if j % 2 else "embc",
                         "wisp_c" if j % 2 else "ember_hot", e, unlit=True, noline=True, prio=4.0)
            rig.embers.append((f"emb{j}", j / 6.0))


CFG = dict(id="wandering_spider", scale=SCALE,
           mats=dict(body="ws_body", abd="ws_abd", dark="ws_dark", pale="ws_pale", fang="ws_fang", leg="ws_leg",
                     leg_band="ws_dark", leg_dark="ws_dark"),
           ct_r=(0.3, 0.29, 0.24), ab_c=(0, 0.44, 0.34), ab_r=(0.26, 0.32, 0.23),
           leg_len=(0.66, 0.6, 0.54, 0.62), leg_w=0.052, knee_h=0.24, hairy=True, eye=0.12, fang_len=0.075,
           head_tilt=-0.42,
           pattern=pattern, extras=extras, night=NIGHT)


# ------------------------------------------------------------------ chefe (s3): Matriarca-Armadeira
def queen_leg(rig, stage, nm, hp, kp, hip, knee, foot, d, sx, k, lw):
    if k <= 1:
        # canela-lamina (foice de marfim) ao longo da canela, ponta passando do pe
        a = knee.lerp(foot, 0.12)
        b = foot + d * 0.1 + Vector((0, 0, 0.06))
        rig.add_mesh(R.cone(nm + "sc", a, b, lw * 1.25, 0.006, seg=7, rings=4, bend=(0, 0, 0.1)), nm + "sc", "ws_blade",
                     kp, group=nm + "s")
    # tufo ruivo no joelho
    rig.add_mesh(R.cone(nm + "tf", knee, knee + (d * 0.3 + Z).normalized() * 0.1, lw * 0.7, 0.005, seg=6, rings=1),
                 "tuft", "ws_fang", kp, noline=True)


def queen_pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    rig.add_mesh(R.plate("ctstripe", V.CT_C, ct_r, 0.35, 1.95, math.pi / 2 - 0.13, math.pi / 2 + 0.13, bulge=0.0,
                         res=5, lift=1.02), "ctstripe", "ws_band", head, noline=True)
    for j, ps in enumerate((0.4, 0.75, 1.1, 1.45, 1.8)):
        w = 0.08
        for side, (o0, o1) in enumerate(((0.5, math.pi / 2 - 0.02), (math.pi / 2 + 0.02, math.pi - 0.5))):
            rig.add_mesh(R.plate(f"chev{j}_{side}", ab_c, ab_r, ps - w - 0.04, ps + w - 0.04, o0, o1, bulge=0.0, res=5,
                                 lift=1.018), "chev" if j % 2 == 0 else "chevg", "ws_dark" if j % 2 == 0 else "gold",
                         abd, noline=True, group="abd")


def queen_extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    crown = rig.empty("crown", V.CT_C + Vector((0, 0.05, ct_r[2])), head)
    for j, om in enumerate((-0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75)):
        p, n = V.on_ell(V.CT_C, ct_r, 1.2, math.pi / 2 + om, 0.95)
        h = 0.3 - 0.13 * abs(om) / 0.75
        up = (n * 0.6 + Vector((0, 0.35, 1.2))).normalized()
        rig.add_mesh(R.cone(f"crown{j}", p, p + up * h, 0.05, 0.005, seg=7, rings=3, bend=(0, 0.04, 0)),
                     f"crown{j}", "ws_fang" if j % 2 == 0 else "gold", crown, group="crown")
    for sx in (1, -1):
        V.web_cape(rig, f"cape{sx}", ab_c, ab_r, sx, abd, "ws_silk", "ws_silk_line")
    rig.babies = []
    for j, (ps, om) in enumerate(((1.6, 1.25), (1.6, 1.9), (1.1, 1.0), (1.1, 1.57), (1.1, 2.15), (0.6, 1.57))):
        p, n = V.on_ell(ab_c, ab_r, ps, om, 1.0)
        rig.babies.append(V.spiderling(rig, f"baby{j}", p + n * 0.035, abd, "ws_body", "ws_leg"))
    V.add_motes(rig, [(0.6 * math.cos(a), 0.2 + 0.6 * math.sin(a), 0.3 + 0.1 * (j % 3))
                      for j, a in enumerate([k * math.tau / 6 for k in range(6)])], ["ws_silk_mote"], 0.02)


# ------------------------------------------------------------------ atroz (s4): mutacao noturna
def atroz_leg(rig, stage, nm, hp, kp, hip, knee, foot, d, sx, k, lw):
    side = Vector((-d.y, d.x, 0)) * sx
    for j, f in enumerate((0.25, 0.55, 0.8)):
        hb = knee.lerp(foot, f)
        rig.add_mesh(R.cone(nm + f"br{j}", hb, hb + (d * 0.5 + Z + side * 0.3).normalized() * (0.13 - 0.03 * j),
                            lw * 0.55, 0.004, seg=5, rings=1), "bristle", "ws_bristle", kp, noline=True, prio=1.4)
    for j, f in enumerate((0.35, 0.75)):
        hb = hip.lerp(knee, f)
        rig.add_mesh(R.cone(nm + f"bf{j}", hb, hb + (Z + side * 0.4).normalized() * 0.1, lw * 0.55, 0.004, seg=5,
                            rings=1), "bristle", "ws_bristle", hp, noline=True, prio=1.4)
    rig.add_mesh(R.cone(nm + "ks", knee, knee + (Z * 1.0 + d * 0.25).normalized() * 0.2, lw * 0.9, 0.005, seg=6, rings=2,
                        bend=(0, 0.03, 0)), nm + "ks", "ws_dark", kp, group=nm + "s")


def atroz_pattern(rig, stage, abd, head, ab_c, ab_r, ct_r):
    for j, ps in enumerate((0.45, 0.85, 1.25, 1.65)):
        w = 0.07
        for side, (o0, o1) in enumerate(((0.5, math.pi / 2 - 0.02), (math.pi / 2 + 0.02, math.pi - 0.5))):
            rig.add_mesh(R.plate(f"chev{j}_{side}", ab_c, ab_r, ps - w - 0.04, ps + w - 0.04, o0, o1, bulge=0.0, res=5,
                                 lift=1.02), "glowband", "cold" if j % 2 else "cold_hot", abd, noline=True, unlit=True,
                         prio=1.6)
        for sx in (1, -1):
            p, n = V.on_ell(ab_c, ab_r, ps + 0.2, math.pi / 2 - 0.45 * sx, 1.012)
            rig.add_mesh(R.ellipsoid(f"dot{j}{sx}", p, (0.045, 0.045, 0.012), rot=V.align(n), seg=10, rings=6),
                         "glowdot", "wisp_v", abd, noline=True, unlit=True, prio=1.6)
    rig.add_mesh(R.plate("ctstripe", V.CT_C, ct_r, 0.35, 1.95, math.pi / 2 - 0.1, math.pi / 2 + 0.1, bulge=0.0, res=5,
                         lift=1.02), "ctstripe", "cold", head, noline=True, unlit=True)


def atroz_extras(rig, stage, abd, head, ab_c, ab_r, ct_r):
    # crista de espinhos: cefalotorax + abdomen
    for j, (ps, om, h) in enumerate(((1.3, 1.57, 0.26), (1.0, 1.2, 0.18), (1.0, 1.94, 0.18))):
        p, n = V.on_ell(V.CT_C, ct_r, ps, om, 0.97)
        up = (n + Vector((0, 0.4, 0.8))).normalized()
        rig.add_mesh(R.cone(f"cspk{j}", p, p + up * h, 0.06, 0.005, seg=6, rings=2, bend=(0, 0.04, 0)), f"cspk{j}",
                     "ws_dark", head, group=f"cspk{j}")
    for j, (ps, h) in enumerate(((0.5, 0.24), (0.95, 0.32), (1.4, 0.3), (1.8, 0.2))):
        for sx in (1, -1):
            p, n = V.on_ell(ab_c, ab_r, ps, math.pi / 2 - 0.85 * sx, 0.98)
            up = (n + Vector((0, 0.3, 0.7))).normalized()
            rig.add_mesh(R.cone(f"aspk{j}{sx}", p, p + up * h, 0.065, 0.005, seg=6, rings=2,
                                bend=(0.03 * sx, 0.03, 0)), f"aspk{j}{sx}", "ws_dark", abd, group=f"aspk{j}{sx}")
        p, n = V.on_ell(ab_c, ab_r, ps, math.pi / 2, 0.98)
        rig.add_mesh(R.cone(f"rspk{j}", p, p + (n + Vector((0, 0.3, 0.6))).normalized() * h * 0.8, 0.055, 0.005,
                            seg=6, rings=2), f"rspk{j}", "ws_dark", abd, group=f"rspk{j}")
    # presas-sabre com gota de peconha
    for nm, sx in (("L", 1), ("R", -1)):
        chel = rig.n(f"chel{nm}")
        cc = Vector((0.065 * sx, V.CT_C.y - ct_r[1] * 0.92, V.CT_C.z - ct_r[2] * 0.55))
        b = cc + Vector((0.01 * sx, -0.03, -0.05))
        tip = b + Vector((-0.06 * sx, -0.08, -0.26))
        rig.add_mesh(R.cone(f"saber{nm}", b, tip, 0.045, 0.006, seg=7, rings=4, bend=(-0.02 * sx, -0.05, 0)),
                     f"saber{nm}", "ws_saber", chel, prio=2.0)
        rig.add_mesh(R.ellipsoid(f"drop{nm}", tip + Vector((0, 0, -0.03)), (0.024, 0.024, 0.036), seg=8, rings=6),
                     "drop", "cold_hot", chel, unlit=True, noline=True, prio=4.0)
    V.add_motes(rig, [(0.75 * math.cos(a), 0.25 + 0.6 * math.sin(a), 0.35 + 0.12 * (j % 3))
                      for j, a in enumerate([k * math.tau / 8 + 0.3 for k in range(8)])], ["wisp_c", "wisp_v", "ember_hot"],
                0.03)


MATS_BOSS = dict(body="ws_body", abd="ws_abd", dark="ws_dark", pale="ws_pale", fang="ws_fang", leg="ws_leg",
                 leg_band="ws_dark", leg_dark="ws_dark")
CFG3 = dict(id="wandering_spider", scale=SCALE, mats=MATS_BOSS,
            ct_r=(0.32, 0.31, 0.26), ab_c=(0, 0.56, 0.44), ab_r=(0.36, 0.42, 0.33),
            leg_len=(0.82, 0.76, 0.62, 0.74), leg_w=0.062, knee_h=0.32, hairy=True, eye=0.12, fang_len=0.09,
            head_tilt=-0.42, leg_hook=queen_leg, pattern=queen_pattern, extras=queen_extras)
NIGHT4 = {"ws_body": "chitin_n", "ws_abd": "chitin_n", "ws_dark": "obsidian_n", "ws_pale": "pale_n",
          "ws_fang": "fur_wine_n", "claw": "fang_n", "brow": "brow_n", "ws_leg": "chitin_n", "ws_band": "obsidian_n",
          "ws_saber": "fang_n"}
CFG4 = dict(id="wandering_spider", scale=SCALE, mats=MATS_BOSS,
            ct_r=(0.31, 0.3, 0.24), ab_c=(0, 0.56, 0.4), ab_r=(0.34, 0.44, 0.3),
            leg_phi=(-64.0, -32.0, -2.0, 26.0, 52.0), leg_len=(0.92, 0.86, 0.78, 0.74, 0.84), leg_w=0.056,
            knee_h=0.4, hairy=False, eye=0.11, fang_len=0.05, head_tilt=-0.4,
            small_eyes=((2.0, 0.2, 0.034), (2.25, 0.95, 0.03), (1.85, 0.55, 0.026)),
            leg_hook=atroz_leg, pattern=atroz_pattern, extras=atroz_extras, night=NIGHT4)
POSE3 = {"tilt": -0.24, "raise": (1.15, 0.7), "attack": "slam"}
POSE4 = {"tilt": -0.04, "raise": (0.75, 0.0), "abd": 0.55, "attack": "lunge"}


def build(stage):
    if stage == 3:
        rig = V.spider(CFG3, 3)
    elif stage == 4:
        rig = V.spider(CFG4, 4)
    else:
        return V.spider(CFG, stage)
    return rig


def pose(rig, anim, i, n, stage):
    if stage >= 3:
        V.boss_spider_pose(rig, anim, i, n, stage, POSE3 if stage == 3 else POSE4)
        t = i / n
        if stage == 3 and anim in ("idle", "walk", "attack", "hit"):
            for j, b in enumerate(rig.babies):
                rig.n(b).location.z += 0.025 * max(0.0, math.sin(math.tau * (t * (2 if anim == "walk" else 1) + j * 0.3)))
        if stage == 4:
            for nm in ("L", "R"):
                rig.n(f"drop{nm}").scale = (1, 1, 1.0 + 0.5 * ((i % 4) / 3))
        return
    V.spider_pose(rig, anim, i, n, stage, "rear")
