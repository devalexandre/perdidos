"""Kappa da Lagoa (pond_kappa) — Ilhas do Sol Nascente. Releitura chibi do kappa do folclore japones: casco nas
costas, bico, franja em volta do prato de agua no topo da cabeca, maos e pes de pato. Modelo proprio por script
(piloto 07/10/2026), mesmas regras de pixel art do stone_armadillo.py (rosto, olhos, sobrancelha, bochecha).
  s1 Kappa da Lagoa (pequeno): curioso e arteiro; golpe = tapa com as duas maos e a agua do prato espirra.
  s3 Kappa do Remanso (chefe): lutador do remanso — corpo largo, cinto de pano com abas, pepino no cinto, casco
     grande com calombos de musgo, folha de vitoria-regia e taboas nas costas, franja comprida; golpe = pisada de
     lutador (ergue a perna, pisa, levanta onda) e empurrao com as duas maos.
  s4 Kappa do Poco Escuro (atroz = o chefe a noite): pele anil, casco de obsidiana com cristas de osso, franja de
     alga negra pingando, agua do prato acesa (luz fria), olhos frios em fenda, presas no bico, garras compridas,
     fogos-fatuos frios em volta e gotas subindo.
STAGES = (1, 3, 4) como a leva reserve (o s2 reaproveita o s1 depois). Pose por quadro em pose()."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

SCALE = {1: 1.18, 3: 2.2, 4: 2.2}
FRAME = {1: 96, 3: 240, 4: 240}
STAGES = (1, 3, 4)
ANIMS = [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
NIGHT = {"kappa_skin": "kappa_skin_n", "kappa_hair": "kappa_hair_n", "kappa_shell": "obsidian_n", "kappa_rim": "horn_n",
         "kappa_belly": "skin_n", "beak": "gold_n", "pond": "pond_n", "cloth_blue": "hood_n", "moss": "moss_n",
         "brow_g": "brow_n", "leaf": "moss_n", "wood": "thorn_n"}
LEAN = 8.0
HEAD_TILT = -0.45
CROWN = 0.25        # franja + prato girados para a frente (ver build)


def _dims(stage):
    """Proporcoes: o chefe tem corpo de lutador (largo) e a cabeca proporcionalmente menor."""
    if stage == 1:
        return dict(BC=Vector((0, 0.02, 0.33)), BR=(0.2, 0.17, 0.21), HC=Vector((0, -0.07, 0.71)), HR=(0.27, 0.215, 0.245),
                    hip=0.1, sh=0.2, hand=1.0)
    return dict(BC=Vector((0, 0.03, 0.36)), BR=(0.27, 0.22, 0.25), HC=Vector((0, -0.08, 0.80)), HR=(0.26, 0.225, 0.235),
                hip=0.14, sh=0.25, hand=1.2)


def _ysurf(C, Rr, x, z, front=True):
    """y da superficie do elipsoide (C, Rr) no ponto (x, z) do lado da frente."""
    q = 1 - ((x - C.x) / Rr[0]) ** 2 - ((z - C.z) / Rr[2]) ** 2
    return C.y - Rr[1] * math.sqrt(max(0.0, q))


def build(stage):
    if stage not in STAGES:
        raise ValueError("estagios: 1, 3 (chefe), 4 (atroz)")
    R.reset()
    D = _dims(stage)
    BC, BR, HC, HR = D["BC"], D["BR"], D["HC"], D["HR"]
    R.CUR["reach"] = (0.2 if stage == 1 else 0.26, 0.24 if stage == 1 else 0.32, 0.22 if stage == 1 else 0.3)
    rig = R.Rig("pond_kappa")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    boss = stage >= 3
    night = stage == 4
    body = rig.empty("body", (0, 0.02, 0.16), root)
    # ---- tronco: barriga (plastrao) na frente, casco de placas nas costas, aro do casco em volta
    rig.add_mesh(R.ellipsoid("torso", BC, BR), "torso", "kappa_skin", body, group="torso")
    pc = Vector((0, BC.y - BR[1] * 0.62, BC.z - 0.01))
    rig.add_mesh(R.ellipsoid("plastron", pc, (BR[0] * 0.8, BR[1] * 0.5, BR[2] * 0.86)), "plastron", "kappa_belly", body,
                 group="plastron")
    for k, dz in enumerate((0.06, -0.04)):
        z = BC.z + dz * (BR[2] / 0.21)
        w = BR[0] * (0.66 if k == 0 else 0.62)
        y = _ysurf(pc, (BR[0] * 0.8, BR[1] * 0.5, BR[2] * 0.86), 0, z) + 0.004
        rig.add_mesh(R.cone(f"scute{k}", (-w, y + 0.03, z), (w, y + 0.03, z), 0.009, 0.009, seg=6, rings=6,
                            bend=(0, -0.035, -0.01)), f"scute{k}", "kappa_rim", body, noline=True, unlit=True, prio=1.4)
    SC = BC + Vector((0, 0.05, 0.02))
    SR = (BR[0] * 1.12, BR[1] * 1.15, BR[2] * 1.12) if not boss else (BR[0] * 1.14, BR[1] * 1.25, BR[2] * 1.16)
    rig.add_mesh(R.plate("shell_c", SC, SR, 0.0, 0.55, 0.0, math.tau, bulge=0.1, res=10), "shell_c", "kappa_shell", body)
    for ring, (p0, p1, cols, off) in enumerate(((0.55, 1.05, 6, 0.3), (1.05, 1.47, 8, 0.0))):
        for c in range(cols):
            o0 = off + math.tau * c / cols; o1 = off + math.tau * (c + 1) / cols
            nm = f"shell_{ring}_{c}"
            rig.add_mesh(R.plate(nm, SC, SR, p0, p1, o0, o1, bulge=0.12, res=6), nm, "kappa_shell", body)
    rig.add_mesh(R.plate("shell_rim", SC, SR, 1.42, 1.66, 0.0, math.tau, bulge=0.0, res=20, lift=1.04), "shell_rim",
                 "kappa_rim", body)
    # ---- rabinho
    tail = rig.empty("tail", (0, BC.y + BR[1] * 0.8, 0.17), body)
    rig.add_mesh(R.cone("tail", (0, BC.y + BR[1] * 0.85, 0.18), (0, BC.y + BR[1] * 0.85 + 0.12, 0.08), 0.05, 0.012, seg=8,
                        rings=3, bend=(0, 0, -0.02)), "tail", "kappa_skin", tail)
    # ---- pernas curtas e pes de pato
    for sx, nm in ((1, "L"), (-1, "R")):
        hx = D["hip"] * sx
        leg = rig.empty(f"leg{nm}", (hx, 0.0, 0.17), root)
        rig.add_mesh(R.cone(f"thigh{nm}", (hx, 0.0, 0.2), (hx * 1.15, -0.02, 0.06), 0.06 if boss else 0.052, 0.048, seg=10,
                            rings=2), f"thigh{nm}", "kappa_skin", leg, group=f"leg{nm}")
        fx = hx * 1.18
        rig.add_mesh(R.ellipsoid(f"foot{nm}", (fx, -0.06, 0.032), (0.075, 0.095, 0.032)), f"foot{nm}", "kappa_skin", leg,
                     group=f"leg{nm}")
        for c in (-1, 0, 1):
            b = Vector((fx + 0.042 * c, -0.13, 0.03))
            rig.add_mesh(R.ellipsoid(f"toe{nm}{c}", b, (0.024, 0.03, 0.02)), f"toe{nm}{c}", "kappa_skin", leg,
                         group=f"leg{nm}")
            if night:
                rig.add_mesh(R.cone(f"tclaw{nm}{c}", b + Vector((0, -0.02, 0)), b + Vector((0.008 * c, -0.07, -0.015)), 0.014,
                                    0.003, seg=5, rings=1), f"tclaw{nm}", "fang_n", leg, noline=True)
    # ---- bracos e maos de pato
    for sx, nm in ((1, "L"), (-1, "R")):
        sp = Vector((D["sh"] * sx, BC.y - 0.04, BC.z + BR[2] * 0.45))
        arm = rig.empty(f"arm{nm}", sp, body)
        hk = D["hand"]
        hp = sp + Vector((0.07 * sx * hk, -0.08 * hk, -0.16 * hk))
        rig.add_mesh(R.cone(f"arm{nm}", sp, hp, 0.052 * hk, 0.04 * hk, seg=10, rings=3, bend=(0.015 * sx, 0, 0)), f"arm{nm}",
                     "kappa_skin", arm, group=f"arm{nm}")
        rig.add_mesh(R.ellipsoid(f"hand{nm}", hp, (0.055 * hk, 0.05 * hk, 0.045 * hk)), f"hand{nm}", "kappa_skin", arm,
                     group=f"arm{nm}")
        for c in (-1, 0, 1):
            b = hp + Vector((0.03 * c * hk, -0.03 * hk, -0.025 * hk))
            tip = b + Vector((0.02 * c * hk, -0.035 * hk, -0.045 * hk))
            rig.add_mesh(R.cone(f"fing{nm}{c}", b, tip, 0.02 * hk, 0.014 * hk, seg=6, rings=1), f"fing{nm}{c}", "kappa_skin",
                         arm, group=f"arm{nm}")
            if night:
                rig.add_mesh(R.cone(f"claw{nm}{c}", tip, tip + Vector((0.012 * c, -0.05, -0.06)) * hk, 0.014 * hk, 0.002,
                                    seg=5, rings=2, bend=(0, -0.01, 0.01)), f"claw{nm}", "fang_n", arm, noline=True)
    # ---- cabeca grande (chibi), rosto levantado para a camera
    head = rig.empty("head", (0, HC.y + 0.03, HC.z - HR[2] * 0.8), body)
    rig.add_mesh(R.ellipsoid("head", HC, HR), "head", "kappa_skin", head, group="head")
    # franja em volta do prato: curta na testa, chanel nos lados e atras, borda em zigue-zague
    th0 = 0.40
    back = 1.95 if boss else 1.82

    def edge(ph):
        fr = S.front_off(ph) < 0.8
        return S.bob(ph, 0.4, back + 0.2, open_=0.85, ramp=0.6) + S.zigzag(ph + math.pi / 18, 18, 0.1 if fr else 0.2)
    # franja e prato num pivo "crown" girado para a frente: com a cabeca levantada (HEAD_TILT) o prato fica de cara
    # para a camera alta e a franja nao desce sobre os olhos
    crown = rig.empty("crown", HC, head)
    rig.add_mesh(S.cap("hair", HC, HR, th0, edge, lift=1.05, phase=0.0), "hair", "kappa_hair", crown)
    # prato (aro claro) com agua e brilho
    top = HC + Vector((0, 0.005, HR[2] * 0.93))
    rmaj = 0.105 if stage == 1 else 0.115
    rig.add_mesh(S.torus("dish", top, rmaj, 0.026, squash=0.9), "dish", "kappa_rim", crown)
    rig.add_mesh(R.ellipsoid("water", top + Vector((0, 0, 0.012)), (rmaj * 0.98, rmaj * 0.98, 0.014)), "water", "pond",
                 crown, group="water", unlit=night, noline=True)
    wh = rig.empty("wavehl", top + Vector((-0.035, -0.03, 0.027)), crown)
    rig.add_mesh(R.ellipsoid("wavehl", top + Vector((-0.035, -0.03, 0.027)), (0.032, 0.018, 0.006)), "wavehl",
                 "drop2" if not night else "cold_hot", wh, noline=True, unlit=True, prio=3.0)
    # olhos grandes no desenho do Tatu
    rz = 0.158 if stage == 1 else 0.145
    for sx, nm in ((1, "L"), (-1, "R")):
        ex, ez = 0.122 * sx, HC.z + 0.01
        ep = Vector((ex, _ysurf(HC, HR, ex, ez) + 0.012, ez))
        S.eye(rig, nm, ep, head, 0.104 if stage == 1 else 0.096, rz, -0.45 * sx, mode="cold" if night else "normal")
        k = rz / 0.145
        if stage == 1:
            S.brow(rig, nm, ep, head, k, -0.015, mat="brow_g", lift=0.012, thick=0.7, width=0.75)        # curioso
        elif stage == 3:
            S.brow(rig, nm, ep, head, k, 0.07, mat="brow_g", thick=1.25, width=0.95, lift=-0.035, prio=3.0)         # lutador decidido
        else:
            S.brow(rig, nm, ep, head, k, 0.08, mat="brow_n", thick=1.25, width=0.95, lift=-0.035, prio=3.0)  # bravo
        if not night:
            cx, cz = 0.19 * sx, HC.z - 0.105
            S.cheek(rig, nm, Vector((cx, _ysurf(HC, HR, cx, cz) + 0.008, cz)), head, k=1.0, yaw=-0.7 * sx)
    # bico de pato (de cima + de baixo, boca entre os dois)
    bz = HC.z - 0.145
    by = _ysurf(HC, HR, 0, bz)
    bk = 0.8 if stage == 1 else 0.95
    rig.add_mesh(R.ellipsoid("beak_up", (0, by - 0.035 * bk, bz + 0.01), (0.085 * bk, 0.065 * bk, 0.036 * bk), rot=(0.25, 0, 0)),
                 "beak_up", "beak", head, prio=1.3)
    rig.add_mesh(R.ellipsoid("mouth_in", (0, by - 0.022 * bk, bz - 0.022 * bk), (0.06 * bk, 0.04 * bk, 0.02 * bk)),
                 "mouth_in", "mouth_in", head, noline=True, unlit=True)
    jaw = rig.empty("jaw", (0, by - 0.005, bz - 0.01), head)
    rig.add_mesh(R.ellipsoid("beak_lo", (0, by - 0.025 * bk, bz - 0.03 * bk), (0.07 * bk, 0.052 * bk, 0.026 * bk),
                             rot=(0.15, 0, 0)), "beak_lo", "beak", jaw, prio=1.3)
    for sx in (1, -1):  # narinas
        rig.add_mesh(R.ellipsoid(f"nost{sx}", (0.022 * sx, by - 0.075 * bk, bz + 0.036 * bk), (0.008, 0.006, 0.006)),
                     "nost", "brow_g" if not night else "brow_n", head, noline=True, unlit=True, prio=2.0)
    if night:
        for sx in (1, -1):  # presas descendo do bico
            b = Vector((0.045 * sx, by - 0.06 * bk, bz - 0.005))
            rig.add_mesh(R.cone(f"fang{sx}", b, b + Vector((0.006 * sx, -0.012, -0.055)), 0.016, 0.003, seg=6, rings=2),
                         "fang", "fang_n", head, noline=True, prio=2.4)
    crown.rotation_euler.x = CROWN
    if boss:
        _boss_parts(rig, body, head, D, SC, SR, night, edge)
    head.rotation_euler.x += HEAD_TILT
    # gotas (respingo do prato no golpe / no dano / derramando na morte) e onda no chao (pisada do chefe)
    S.add_motes(rig, "drop", [(0.0, 0.0, 0.5)] * 7, ["drop", "drop2", "drop"], size=0.026 if stage == 1 else 0.022,
                parent=root)
    S.hide_motes(rig, "drop")
    if boss:
        S.add_motes(rig, "wave", [(0.0, 0.0, 0.05)] * 10, ["drop", "drop2"] if not night else ["cold", "cold_hot"],
                    size=0.03, parent=root)
        S.hide_motes(rig, "wave")
    if night:
        _atroz_parts(rig, root, head, HC, HR)
        for info in rig.part_info[1:]:
            info["mat"] = NIGHT.get(info["mat"], info["mat"])
    rig.save_rest()
    return rig


def _boss_parts(rig, body, head, D, SC, SR, night, edge):
    """Chefe: cinto de lutador com abas, pepino, calombos de musgo no aro do casco, vitoria-regia e taboas nas costas
    (s3); cristas de osso e alga pingando no lugar das plantas (s4)."""
    BC, BR, HC, HR = D["BC"], D["BR"], D["HC"], D["HR"]
    wz = BC.z - BR[2] * 0.42
    rig.add_mesh(S.torus("belt", (0, BC.y, wz), BR[0] * 0.93, 0.045, squash=1.3, yscale=BR[1] / BR[0] * 1.02, nu=28),
                 "belt", "cloth_blue", body)
    fy = BC.y - BR[1] * 0.9
    rig.add_mesh(R.ellipsoid("knot", (0, fy - 0.02, wz), (0.06, 0.035, 0.05)), "knot", "cloth_blue", body)
    flaps = rig.empty("flaps", (0, fy - 0.03, wz - 0.03), body)
    for k, dx in enumerate((-0.05, 0.0, 0.05)):
        b = Vector((dx, fy - 0.03, wz - 0.03))
        rig.add_mesh(R.cone(f"flap{k}", b, b + Vector((dx * 0.3, -0.03, -0.13)), 0.022, 0.016, seg=6, rings=2),
                     f"flap{k}", "cloth_blue", flaps)
    # calombos de musgo (s3) / espinhos de osso (s4) no aro do casco
    for k in range(9):
        om = math.pi * (0.05 + 0.9 * k / 8)
        p, n = S.on_ell(SC, SR, 1.5, om, 1.04)
        if om > math.pi * 0.5:
            pass
        if night:
            rig.add_mesh(R.cone(f"rimspk{k}", p, p + (n * 1.0 + Vector((0, 0.5, 0.25))).normalized() * 0.12, 0.04, 0.004,
                                seg=6, rings=2), "rimspk", "fang_n", body, group="rimspk")
        else:
            rig.add_mesh(R.ellipsoid(f"knob{k}", p, (0.045, 0.045, 0.035), rot=S.align(n), seg=10, rings=6), "knob", "moss",
                         body, group="knob")
    if night:
        # crista de osso no meio do casco (3 laminas) e alga negra pingando da franja
        for k, (psi, h) in enumerate(((0.35, 0.16), (0.75, 0.2), (1.1, 0.15))):
            p, n = S.on_ell(SC, SR, psi, math.pi / 2, 0.98)
            up = (n + Vector((0, 0.6, 0.8))).normalized()
            rig.add_mesh(R.cone(f"crest{k}", p, p + up * h, 0.07, 0.004, seg=5, rings=3, bend=(0, 0.03, 0)), f"crest{k}",
                         "fang_n", body, group=f"crest{k}")
        for k in range(8):
            ph = math.pi * (0.15 + 0.7 * k / 7) * (1 if k % 2 else -1) - math.pi / 2 + math.pi
            th = edge(ph) - 0.12
            p = HC + Vector((HR[0] * math.sin(th) * math.cos(ph), HR[1] * math.sin(th) * math.sin(ph),
                             HR[2] * math.cos(th))) * 1.05
            ln = 0.16 + 0.05 * (k % 3)
            rig.add_mesh(R.cone(f"weed{k}", p, p + Vector((0.03 * math.cos(ph), 0.04, -ln)), 0.032, 0.008, seg=6, rings=3,
                                bend=(0.02, 0, 0)), "weed", "kappa_hair", rig.n("crown"), group="weedhair")
        return
    # pepino enfiado no cinto (lado esquerdo do kappa)
    cb = Vector((BR[0] * 0.42, BC.y - BR[1] * 0.98, wz - 0.03))
    ct = cb + Vector((0.1, -0.05, 0.2))
    rig.add_mesh(R.cone("cuke", cb, ct, 0.042, 0.034, seg=10, rings=4, bend=(0.02, -0.01, 0)), "cuke", "leaf", body)
    rig.add_mesh(R.ellipsoid("cuke_end", ct, (0.03, 0.03, 0.02), rot=(0.2, -0.45, 0)), "cuke_end", "moss", body)
    # vitoria-regia (folha redonda com borda levantada) no alto do casco e 3 taboas
    p, n = S.on_ell(SC, SR, 0.62, math.pi / 2, 1.0)
    lp = p + n * 0.02
    rig.add_mesh(R.ellipsoid("pad", lp, (0.2, 0.18, 0.018), rot=S.align(n)), "pad", "leaf", body, group="pad")
    rig.add_mesh(S.torus("padrim", lp + n * 0.012, 0.19, 0.018, rot=S.align(n), nu=24, yscale=0.9), "padrim", "leaf", body,
                 group="pad")
    reeds = rig.empty("reeds", lp, body)
    for k, (dx, dy, h) in enumerate(((-0.08, 0.06, 0.42), (0.03, 0.1, 0.5), (0.1, 0.03, 0.36))):
        b = lp + Vector((dx, dy, 0.0))
        tip = b + Vector((dx * 0.4, 0.06, h))
        rig.add_mesh(R.cone(f"stalk{k}", b, tip, 0.012, 0.008, seg=5, rings=3, bend=(0.02, 0, 0)), f"stalk{k}", "leaf",
                     reeds, noline=True)
        cat = b + (tip - b) * 0.78
        rig.add_mesh(R.ellipsoid(f"cattail{k}", cat, (0.028, 0.028, 0.06)), f"cattail{k}", "wood", reeds,
                     group=f"cattail{k}")


def _atroz_parts(rig, root, head, HC, HR):
    """Fogos-fatuos frios em orbita e gotas de luz fria subindo do prato."""
    spots = []
    for k in range(5):
        a = math.tau * k / 5 + 0.4
        spots.append((0.48 * math.cos(a), 0.4 * math.sin(a), 0.55 + 0.18 * (k % 2)))
    S.add_motes(rig, "wisp", spots, ["wisp_c", "wisp_c2"], size=0.04, parent=root)
    top = HC + Vector((0, 0.0, HR[2]))
    S.add_motes(rig, "rise", [top + Vector((0.05 * math.cos(k * 2.4), 0.04 * math.sin(k * 2.4), 0.0)) for k in range(5)],
                ["cold_hot", "cold"], size=0.018, parent=head)


# ------------------------------------------------------------------ animacao
def _legs(rig, phase, amp, lift):
    for nm, off in (("L", 0.0), ("R", 0.5)):
        leg = rig.n(f"leg{nm}")
        a = math.sin(math.tau * (phase + off))
        leg.rotation_euler.x = -amp * a
        leg.location.z += lift * max(0.0, math.sin(math.tau * (phase + off) + math.pi / 2))


def _arms(rig, ax, az=0.0, ay=0.0):
    """ax > 0 = bracos para tras, < 0 = para a frente/cima; az abre para os lados."""
    for nm, sg in (("L", 1), ("R", -1)):
        a = rig.n(f"arm{nm}")
        a.rotation_euler.x += ax if not isinstance(ax, tuple) else ax[0 if sg > 0 else 1]
        a.rotation_euler.y += -az * sg
        a.rotation_euler.z += ay * sg


def _jaw(rig, open_):
    rig.n("jaw").rotation_euler.x += 0.55 * open_
    rig.n("jaw").location.z -= 0.012 * open_


def _ripple(rig, t, amp=1.0):
    """Brilho da agua do prato passeia (agua mexendo)."""
    o = rig.n("wavehl")
    o.location.x += 0.03 * amp * math.sin(math.tau * t)
    o.location.y += 0.02 * amp * math.cos(math.tau * t)


def _dish_world(rig, stage):
    """Posicao aproximada do prato (coordenadas do root) para o respingo."""
    D = _dims(stage)
    return D["HC"] + Vector((0, -0.08, D["HR"][2] + 0.02))


def pose(rig, anim, i, n, stage):
    t = i / n
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    boss = stage >= 3
    night = stage == 4
    dish = _dish_world(rig, stage)
    if boss:
        # postura de lutador: bracos abertos, pernas afastadas
        _arms(rig, -0.1, 0.12)
    if night:
        S.motes(rig, "wisp", t, rise=0.05, orbit=1.0)
        S.motes(rig, "rise", t, rise=0.22, spread=0.6)
    if anim == "idle":
        s = math.sin(math.tau * t)
        R.squash(root, 1.0 + (0.04 if not boss else 0.05) * s)
        head.location.z += 0.012 * math.sin(math.tau * (t - 0.15))
        head.rotation_euler.y = (0.09 if stage == 1 else 0.04) * math.sin(math.tau * t)   # inclina a cabeca (curioso)
        _arms(rig, 0.12 * math.sin(math.tau * (t - 0.1)))
        rig.n("tail").rotation_euler.z = 0.3 * math.sin(math.tau * t)
        _ripple(rig, t)
        if i == n - 2:
            S.blink(rig, 1.0)
        if night:
            head.location.x += 0.006 * math.sin(math.tau * 4 * t)   # rosnado
            _jaw(rig, 0.15 + 0.1 * max(0, s))
        elif stage == 3:
            _jaw(rig, 0.25 + (0.25 if i in (2, 3) else 0.0))   # bufa
    elif anim == "walk":
        # gingado de pato: balanca de um lado para o outro, quique duplo, bracos opostos as pernas
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.04 * b
        R.squash(root, 1.0 + 0.06 * (b - 0.5))
        root.rotation_euler.y = (0.12 if not boss else 0.09) * math.sin(math.tau * t)
        _legs(rig, t, 0.55, 0.05)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"arm{nm}").rotation_euler.x += 0.45 * sg * math.sin(math.tau * t)
        head.rotation_euler.y = -0.07 * math.sin(math.tau * t)
        head.rotation_euler.x += 0.05 * math.sin(math.tau * 2 * t + 1.0)
        rig.n("tail").rotation_euler.z = 0.4 * math.sin(math.tau * t + 1.2)
        _ripple(rig, 2 * t, 1.4)
    elif anim == "attack":
        if stage == 1:
            _attack_slap(rig, i, dish)
        else:
            _attack_stomp(rig, i, dish, night)
    elif anim == "hit":
        if i == 0:
            R.squash(root, 0.84); R.tilt(root, -0.14, 0.12)
            head.rotation_euler.x += 0.2; S.blink(rig, 0.85); _jaw(rig, 0.6)
            _arms(rig, -0.9, 0.5)
        elif i == 1:
            R.squash(root, 1.1); R.tilt(root, 0.06, -0.1); S.blink(rig, 0.5); _jaw(rig, 0.3)
            _arms(rig, -0.4, 0.3)
        elif i == 2:
            R.squash(root, 0.95)
        else:
            R.squash(root, 1.02)
        # agua pula do prato
        S.splash(rig, "drop", [0.12, 0.3, 0.48, 0.7][i], dish,
                 [(-0.25, 0.1, 0.9), (0.25, 0.05, 0.85), (0.0, 0.3, 1.0), (-0.12, -0.2, 0.7), (0.15, -0.15, 0.75),
                  (0.3, 0.25, 0.6), (-0.3, 0.25, 0.65)], g=3.0, shrink=0.9)
    elif anim == "death":
        _death(rig, i, dish, stage)


def _attack_slap(rig, i, dish):
    """s1: prepara (recua, bracos para tras), tapa com as duas maos para a frente e a agua do prato espirra."""
    root, head = rig.root, rig.n("head")
    sq = [0.88, 0.8, 1.16, 0.9, 1.0, 1.03, 0.98, 1.0][i]
    tl = [-0.12, -0.18, 0.24, 0.3, 0.2, 0.1, 0.04, 0.0][i]
    R.squash(root, sq)
    R.tilt(root, tl, 0.08 if tl < 0 else -0.12)
    _arms(rig, [0.6, 0.95, -1.55, -1.35, -1.1, -0.6, -0.2, 0.0][i], [0.1, 0.2, 0.15, 0.1, 0.1, 0.05, 0, 0][i])
    if i < 2:
        S.blink(rig, [0.3, 0.55][i])
        head.rotation_euler.x += 0.08
    _jaw(rig, [0, 0, 0.8, 0.9, 0.6, 0.3, 0.1, 0][i])
    S.splash(rig, "drop", [0, 0, 0.12, 0.28, 0.44, 0.6, 0.74, 0][i], dish + Vector((0, -0.05, 0)),
             [(-0.15, -0.5, 0.9), (0.15, -0.55, 0.85), (0.0, -0.65, 1.1), (-0.25, -0.4, 0.7), (0.25, -0.45, 0.75),
              (0.05, -0.35, 1.2), (-0.05, -0.7, 0.6)], g=3.2, shrink=0.8)


def _attack_stomp(rig, i, dish, night):
    """Chefe: ergue a perna direita de lado (pisada de lutador), pisa (onda de agua em volta), empurra com as maos."""
    root, body, head = rig.root, rig.n("body"), rig.n("head")
    legR, legL = rig.n("legR"), rig.n("legL")
    roll = [0.14, 0.24, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0][i]
    root.rotation_euler.y += roll
    root.location.x += 0.1 * math.sin(roll) * 2
    root.location.z += [0.02, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0][i]
    legR.rotation_euler.y += [-0.7, -1.15, 0.0, 0, 0, 0, 0, 0][i]
    legR.location.z += [0.06, 0.12, 0.0, 0, 0, 0, 0, 0][i]
    sq = [1.04, 1.08, 0.74, 1.1, 1.0, 0.96, 1.0, 1.0][i]
    R.squash(root, sq)
    if i >= 3:
        R.tilt(root, [0.26, 0.3, 0.18, 0.08, 0.0][i - 3], -0.15)
    _arms(rig, [-0.3, -0.5, 0.3, -1.5, -1.45, -0.9, -0.4, 0.0][i], [0.7, 0.9, 0.4, 0.05, 0.05, 0.2, 0.3, 0.35][i] - 0.35)
    if i in (0, 1):
        S.blink(rig, 0.35)
    _jaw(rig, [0.2, 0.3, 0.7, 1.0, 0.8, 0.4, 0.15, 0.0][i])
    if i == 2:
        head.rotation_euler.x += 0.1
    # onda no chao em volta dos pes depois da pisada
    u = [0, 0, 0.12, 0.3, 0.5, 0.7, 0.9, 0][i]
    # leque de agua para os lados e para tras (nada desce na frente dos pes)
    vel = [(0.75 * math.cos(math.pi * k / 9), 0.45 * math.sin(math.pi * k / 9) + 0.1, 1.1 + 0.2 * (k % 2)) for k in range(10)]
    S.splash(rig, "wave", u, Vector((-0.14, 0.0, 0.08)), vel, g=3.6, shrink=0.75, floor=0.08)
    S.splash(rig, "drop", u, dish, [(-0.3, -0.2, 0.8), (0.3, -0.2, 0.8), (0, 0.2, 1.0), (-0.2, 0.3, 0.6), (0.2, 0.3, 0.6),
                                    (0, -0.4, 0.9), (0.4, 0, 0.7)], g=3.0, shrink=0.9)


def _death(rig, i, dish, stage):
    """Cambaleia, a agua do prato derrama, cai de costas no casco, gira no casco e fica de barriga para cima."""
    root, head = rig.root, rig.n("head")
    boss = stage >= 3
    back = 0.2 if stage == 1 else 0.3
    fall = [0.0, 0.0, -0.55, -1.2, -1.5, -1.42, -1.45, -1.45][i]
    sq = [0.84, 1.08, 1.0, 1.0, 0.92, 1.03, 0.98, 1.0][i]
    R.squash(root, sq)
    if i == 1:
        root.rotation_euler.y += 0.22
    R.tilt(root, fall, back)
    if i >= 2:
        root.location.y -= back * (2.4 if stage == 1 else 1.4) * min(1.0, -fall / 1.4)   # deitado: centra o corpo no quadro
    if i >= 3:
        root.location.z += [0.06, 0.0, 0.03, 0.0, 0.0][i - 3] + (0.0 if not boss else 0.02)
    if i >= 5:
        root.rotation_euler.y += [0.18, -0.1, 0.0][i - 5]   # balanca no casco
    S.blink(rig, 0.85 if i == 0 else (0.5 if i < 3 else 1.0))
    _jaw(rig, [0.7, 0.4, 0.8, 0.6, 0.5, 0.3, 0.3, 0.3][i])
    if i >= 3:
        _arms(rig, -0.6 + 0.3 * math.sin(i * 2.0), 0.5)
        for nm, sg in (("L", 1), ("R", -1)):
            rig.n(f"leg{nm}").rotation_euler.x += -0.5 + 0.35 * sg * math.sin(i * 2.3) * (1 if i < 7 else 0)
    else:
        _arms(rig, [-0.9, -0.5, -1.2][i], [0.5, 0.3, 0.6][i])
    # agua derrama do prato e o prato fica vazio
    if i >= 2:
        if i >= 4:
            rig.n("water").scale = (0.0001, 0.0001, 0.0001)
        rig.n("wavehl").scale = (0.0001, 0.0001, 0.0001)
    S.splash(rig, "drop", [0, 0.1, 0.25, 0.45, 0.65, 0.85, 0, 0][i], dish + Vector((0, 0.1, 0)),
             [(-0.3, 0.6, 0.5), (0.3, 0.6, 0.45), (0.0, 0.8, 0.6), (-0.15, 0.5, 0.8), (0.15, 0.5, 0.75), (0.4, 0.4, 0.3),
              (-0.4, 0.4, 0.35)], g=2.5, shrink=0.9)
