"""Mula-sem-Cabeca Atroz (story_mula) — chefe da historia, Arco 1 cap. 2 (ARCO-1-TERRA-DE-PINDORAMA.md). So existe na
forma atroz (estagio 4, quadro 240). Sem componente religioso (como a Mula de Brasa).
v2 (07/10/2026, pedido do dono: ler como MULA em todas as direcoes, principalmente S e SE):
  - corpo de mula chibi bem visivel de frente: peito largo e claro, as duas patas dianteiras a mostra, pescoco
    musculoso quase em pe; manta de tropeiro com tachas, peitoral de couro com argolas e cabresto solto (corda
    pendurada) no toco do pescoco; ferraduras em brasa;
  - o fogo sai do pescoco como uma TOCHA alta e estreita, em camadas (miolo amarelo-claro -> ouro -> laranja ->
    vermelho -> pontas PRETAS com borda violeta = o sinal de Erevos, o mesmo do Boitata), sempre de frente para a
    camera; linguas finas dos lados; olhos de brasa, sobrancelha de fumaca e boca de dentes de brasa no fogo;
  - parada, a mula fica levemente de 3/4 (giro de 0,32 rad) e o modelo inclina para longe da camera (LEAN), para o
    volume do corpo aparecer de frente.
  idle: a tocha tremula e respira, raspa o casco no chao (faiscas), o cabresto balanca;
  walk: trote (pares diagonais), a tocha deita para tras;
  attack: empina, escoiceia com as patas da frente e desce pisando (faiscas), a tocha cresce e a boca abre;
  hit: encolhe, a tocha baixa e os olhos apertam;
  death: dobra os joelhos, deita e a tocha encolhe ate sobrar a brasa negra.
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
LEAN = 10.0
IDLE_YAW = 0.32

BC = Vector((0, 0.12, 0.54))
BR = (0.24, 0.38, 0.22)
NECK0 = Vector((0, -0.2, 0.62))
NECK1 = Vector((0, -0.25, 0.96))
LEGS = (("FL", 0.13, -0.17), ("FR", -0.13, -0.17), ("BL", 0.14, 0.36), ("BR", -0.14, 0.36))
# camadas da tocha (de tras para a frente): material, meia-largura, altura da ponta, avanco para a camera, altura do bojo
TORCH = (("cf_black", 0.135, 0.98, 0.0, 0.13), ("ember_dim", 0.14, 0.7, 0.025, 0.12), ("ember", 0.115, 0.55, 0.05, 0.11),
         ("ember_hot", 0.08, 0.4, 0.075, 0.1), ("ember_core", 0.045, 0.24, 0.1, 0.085))


def _torch(rig, base, parent):
    """Tocha em camadas, pivo 'torch' (gira de frente para a camera no pose)."""
    tp = rig.empty("torch", base, parent)
    for j, (mat, w, h, fwd, bz) in enumerate(TORCH):
        lay = rig.empty(f"tl{j}", base, tp)
        b = base + Vector((0, -fwd, bz))
        for o in (R.ellipsoid(f"tlb{j}", b, (w, w, w * 0.95)),
                  R.cone(f"tlc{j}", b, base + Vector((0.012 * (j % 2), -fwd, h)), w * 0.98, 0.004, seg=14, rings=5,
                         bend=(0.03 if j % 2 else -0.025, 0, 0))):
            # camada achatada (lamina de frente para a camera): as camadas de dentro ficam sempre na frente
            for v in o.data.vertices:
                v.co.y = b.y + (v.co.y - b.y) * 0.22
            o.data.update()
            rig.add_mesh(o, f"torch{j}", mat, lay, unlit=True, noline=True, prio=2.0 + 0.4 * j)
    # faisca violeta na ponta preta
    rig.add_mesh(R.ellipsoid("ttip", base + Vector((0.0, 0.0, 0.93)), (0.02, 0.02, 0.03)), "ttip", "cf_tip", rig.n("tl0"),
                 unlit=True, noline=True, prio=4.0)
    return tp


def build(stage=4):
    if stage not in STAGES:
        raise ValueError("story_mula: so o estagio 4 (atroz)")
    R.reset()
    R.CUR["reach"] = (0.42, 0.55, 0.3)
    rig = R.Rig("story_mula")
    rig.turn.scale = (SCALE[stage],) * 3
    rig.set_lean(LEAN)
    root = rig.root
    body = rig.empty("body", BC, root)
    C.ell(rig, "barrel", BC, BR, "mula_fur_n", body, group="barrel")
    C.ell(rig, "chest", BC + Vector((0, -0.3, 0.03)), (0.22, 0.17, 0.21), "mula_fur_n", body, group="barrel")
    C.ell(rig, "rump", BC + Vector((0, 0.27, 0.04)), (0.23, 0.2, 0.21), "mula_fur_n", body, group="barrel")
    # peito e barriga claros
    C.ell(rig, "breast", BC + Vector((0, -0.42, -0.02)), (0.15, 0.08, 0.15), "mula_pale_n", body, group="breast")
    C.ell(rig, "belly", BC + Vector((0, 0.0, -0.12)), (0.17, 0.3, 0.1), "mula_pale_n", body, group="belly")
    # manta de tropeiro rasgada com tachas de latao
    def blanket_edge(ph):
        side = abs(math.cos(ph))
        return 0.75 + 0.5 * side + S.zigzag(ph, 16, 0.07)
    rig.add_mesh(S.cap("blanket", BC + Vector((0, 0.06, 0.0)), (BR[0] * 1.0, 0.2, BR[2] * 1.02), 0.0, blanket_edge,
                       lift=1.06), "blanket", "mula_blanket_n", body, group="blanket")
    for k in range(6):
        sx = 1 if k % 2 else -1
        p = BC + Vector((BR[0] * 0.86 * sx, 0.06 - 0.14 + 0.14 * (k // 2), BR[2] * 0.42))
        C.ell(rig, f"stud{k}", p, (0.018, 0.018, 0.018), "gold_n", body, part="stud", noline=True)
    # peitoral de couro com argolas
    pc = BC + Vector((0, -0.3, -0.02))
    rig.add_mesh(S.torus("breastcollar", pc, 0.21, 0.022, rot=(0.25, 0, 0), nu=26, yscale=0.85), "breastcollar",
                 "mula_strap_n", body)
    for sx in (1, -1):
        C.ell(rig, f"ring{sx}", pc + Vector((0.15 * sx, -0.13, 0.0)), (0.026, 0.012, 0.026), "gold_n", body,
              part="ring", noline=True, prio=2.0)
    # pescoco musculoso quase em pe, toco queimado com o cabresto solto
    neck = rig.empty("neck", NECK0, body)
    C.limb(rig, "neck", NECK0, NECK1, 0.17, 0.125, "mula_fur_n", neck, group="barrel", bend=(0, -0.03, 0.0))
    C.limb(rig, "neckfront", NECK0 + Vector((0, -0.08, -0.02)), NECK1 + Vector((0, -0.05, -0.06)), 0.1, 0.07,
           "mula_pale_n", neck, group="breast", bend=(0, -0.03, 0))
    rig.add_mesh(S.torus("stump", NECK1 + Vector((0, 0.0, -0.01)), 0.11, 0.035, nu=22), "stump", "mula_char_n", neck)
    rig.add_mesh(S.torus("halter", NECK1 + Vector((0, 0.0, -0.1)), 0.13, 0.02, rot=(-0.2, 0, 0), nu=22), "halter",
                 "mula_strap_n", neck)
    rope = rig.empty("rope", NECK1 + Vector((0.0, -0.13, -0.11)), neck)
    r0 = NECK1 + Vector((0.0, -0.13, -0.11))
    C.ell(rig, "hring", r0, (0.026, 0.012, 0.026), "gold_n", rope, noline=True, prio=2.0)
    r1 = r0 + Vector((0.03, -0.05, -0.18))
    r2 = r1 + Vector((-0.02, -0.02, -0.14))
    C.limb(rig, "rope1", r0, r1, 0.016, 0.015, "mula_rope_n", rope, group="rope", seg=6, rings=3, bend=(0.01, -0.02, 0))
    C.limb(rig, "rope2", r1, r2, 0.015, 0.012, "mula_rope_n", rope, group="rope", seg=6, rings=3)
    C.ell(rig, "ropeend", r2, (0.022, 0.022, 0.028), "mula_rope_n", rope, group="rope")
    # tocha de fogo corrompido + linguas finas dos lados
    fire = rig.empty("fire", NECK1, neck)
    _torch(rig, NECK1 + Vector((0, 0, 0.0)), fire)
    C.corrupt_flame(rig, "tongues", NECK1 + Vector((0, 0.03, 0.05)), fire, size=1.25, n=4, width=1.0, spread=1.6,
                    base_mat="ember", core=None, height=1.0, black_from=0.45, lean=0.9, slim=0.55, hot="ember_hot")
    # rosto no fogo: preso a tocha (sempre de frente para a camera, como a chama); some de costas (NE, N)
    face = rig.empty("face", NECK1 + Vector((0, -0.16, 0.3)), rig.n("torch"))
    fz = NECK1.z + 0.3
    fy = NECK1.y - 0.17
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = Vector((0.065 * sx, fy, fz))
        e = rig.empty(f"eye{nm}", ep, face)
        C.ell(rig, f"eyew{nm}", ep, (0.058, 0.025, 0.05), "eye", e, rot=(0.2, 0, -0.25 * sx), part=f"eyew{nm}",
              noline=True, unlit=True, prio=5.0)
        C.ell(rig, f"iris{nm}", ep + Vector((0.003 * sx, -0.016, -0.004)), (0.045, 0.016, 0.036), "eye_ember", e,
              rot=(0.2, 0, -0.25 * sx), part=f"iris{nm}", noline=True, unlit=True, prio=5.5)
        C.ell(rig, f"core{nm}", ep + Vector((0.003 * sx, -0.026, -0.008)), (0.018, 0.01, 0.016), "ember_core", e,
              part=f"core{nm}", noline=True, unlit=True, prio=7.0)
        C.ell(rig, f"hl{nm}", ep + Vector((-0.014 + 0.004 * sx, -0.03, 0.012)), (0.011, 0.006, 0.011), "white", e,
              part=f"hl{nm}", noline=True, unlit=True, prio=8.0)
        a = ep + Vector((-0.055 * sx, -0.02, 0.025))
        b = ep + Vector((0.055 * sx, -0.005, 0.075))
        rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.02, 0.009, seg=8, rings=1), f"brow{nm}", "cf_black", face,
                     noline=True, unlit=True, prio=6.0)
    mouth = rig.empty("mouth", (0, fy - 0.01, fz - 0.11), face)
    C.ell(rig, "mouth", (0, fy - 0.01, fz - 0.11), (0.075, 0.02, 0.028), "fire_mouth", mouth, noline=True, unlit=True,
          prio=5.0)
    C.teeth(rig, "mtooth", (0, fy - 0.03, fz - 0.09), 0.12, 4, mouth, h=0.03, r=0.012, mat="ember_core", prio=7.0)
    C.teeth(rig, "mtoothlo", (0, fy - 0.03, fz - 0.135), 0.07, 2, mouth, h=0.025, r=0.011, mat="ember_core", down=False,
            prio=7.0)
    # crina de fogo atras do pescoco
    for k in range(2):
        p = NECK0 + (NECK1 - NECK0) * (0.3 + 0.35 * k) + Vector((0, 0.12, 0.0))
        C.corrupt_flame(rig, f"mane{k}", p, neck, size=0.7, n=3, spread=0.6, base_mat="ember", core=None, height=0.9,
                        lean=0.3, slim=0.8)
    # rabo de fogo
    tail = rig.empty("tail", BC + Vector((0, BR[1] * 0.95, 0.12)), body)
    tb = BC + Vector((0, BR[1] * 0.95, 0.12))
    C.limb(rig, "tailroot", tb + Vector((0, -0.05, 0.0)), tb + Vector((0, 0.08, 0.02)), 0.05, 0.035, "mula_fur_n", tail,
           group="barrel")
    C.corrupt_flame(rig, "tailf", tb + Vector((0, 0.1, 0.0)), tail, size=0.9, n=3, spread=0.6, base_mat="ember",
                    core=None, height=1.0, lean=0.25, slim=0.8)
    # pernas (as da frente bem a mostra), cascos escuros, ferraduras em brasa
    for nm, x, y in LEGS:
        hip = Vector((x, y, 0.5))
        leg = rig.empty(f"leg{nm}", hip, root)
        knee = Vector((x * 1.05, y - 0.01, 0.25))
        front = nm.startswith("F")
        C.limb(rig, f"up{nm}", hip, knee, 0.085 if front else 0.08, 0.055, "mula_fur_n", leg, group=f"leg{nm}")
        low = rig.empty(f"low{nm}", knee, leg)
        C.limb(rig, f"lo{nm}", knee, (x * 1.05, y - 0.02, 0.07), 0.052, 0.046, "mula_fur_n", low, group=f"leg{nm}")
        C.ell(rig, f"fet{nm}", (x * 1.05, y - 0.02, 0.095), (0.068, 0.068, 0.04), "mula_dark_n", low, part="fetlock",
              group=f"fet{nm}")
        C.ell(rig, f"hoof{nm}", (x * 1.05, y - 0.03, 0.037), (0.07, 0.078, 0.042), "hoof", low, group=f"hoof{nm}")
        rig.add_mesh(S.torus(f"shoe{nm}", (x * 1.05, y - 0.035, 0.012), 0.062, 0.017, nu=18, yscale=1.1), f"shoe{nm}",
                     "shoe_ember", low, unlit=True, noline=True, prio=2.5)
    S.add_motes(rig, "spark", [(0.0, 0.0, 0.1)] * 8, ["ember_hot", "ember", "cf_tip"], size=0.022, parent=root)
    S.hide_motes(rig, "spark")
    C.smoke(rig, "smk", [NECK1 + Vector((0.07 * math.cos(k * 2.3), 0.05 * math.sin(k * 2.3), 0.9)) for k in range(5)],
            fire, size=0.045)
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ animacao
def _leg(rig, nm, swing, bend=0.0):
    rig.n(f"leg{nm}").rotation_euler.x += swing
    rig.n(f"low{nm}").rotation_euler.x += bend


def _face(rig, squint=0.0, mouth=0.0):
    for nm in ("L", "R"):
        rig.n(f"eye{nm}").scale.z *= max(0.15, 1 - squint)
    m = rig.n("mouth")
    m.scale = (1.0 + 0.2 * mouth, 1.0, max(0.3, 1.0 + 1.6 * mouth))


def _fire(rig, t, k=1.0, amp=1.0, side=1.0, yaw=0.0):
    """Tocha de frente para a camera (desconta o giro da direcao e o giro de 3/4), camadas tremulando."""
    tp = rig.n("torch")
    tp.rotation_euler.z = -math.radians(R.CUR["dir"]) - yaw
    tp.scale = (max(k, 0.0001),) * 3
    if R.CUR["dir"] >= 120:
        rig.n("face").scale = (0.0001,) * 3
    for j in range(len(TORCH)):
        lay = rig.n(f"tl{j}")
        u = math.tau * (2 * t + 0.21 * j)
        s = 1.0 + 0.1 * amp * math.sin(u) + 0.04 * amp * math.sin(2 * u + j)
        lay.scale = (1.0 - 0.04 * amp * math.sin(u), 1.0, s)
        lay.rotation_euler.y = 0.07 * amp * math.sin(u + 1.3) * (1.0 if j < 3 else 0.5)
    C.flicker(rig, "tongues", t, amp=amp, k=side)
    rig.n("tongues").rotation_euler.z -= yaw
    for j in range(2):
        C.flicker(rig, f"mane{j}", t + 0.3 * j, k=side)
        rig.n(f"mane{j}").rotation_euler.z -= yaw
    C.flicker(rig, "tailf", t + 0.5, k=side)
    rig.n("tailf").rotation_euler.z -= yaw


def _sparks(rig, u, origin, n_up=1.0):
    vel = [(0.5 * math.cos(math.tau * k / 8), 0.4 * math.sin(math.tau * k / 8), 0.9 * n_up + 0.2 * (k % 3)) for k in range(8)]
    S.splash(rig, "spark", u, origin, vel, g=3.0, shrink=0.8, floor=0.03)


def pose(rig, anim, i, n, stage=4):
    t = i / n
    root, body, neck, fire = rig.root, rig.n("body"), rig.n("neck"), rig.n("fire")
    S.motes(rig, "smk", t, rise=0.2, spread=1.2)
    rope = rig.n("rope")
    if anim == "idle":
        s = math.sin(math.tau * t)
        root.rotation_euler.z += IDLE_YAW
        _fire(rig, t, yaw=IDLE_YAW)
        R.squash(root, 1.0 + 0.025 * s)
        body.rotation_euler.x = 0.02 * s
        neck.rotation_euler.x = 0.05 * math.sin(math.tau * (t - 0.2))
        neck.rotation_euler.y = 0.05 * math.sin(math.tau * t)
        rig.n("tail").rotation_euler.z = 0.3 * math.sin(math.tau * t)
        rope.rotation_euler.x = 0.15 * math.sin(math.tau * (t - 0.3))
        rope.rotation_euler.y = 0.12 * math.sin(math.tau * t)
        paw = [0, 0, 0, 0.6, 1.0, 0.4, 0.9, 0.0][i]
        _leg(rig, "FR", -0.45 * paw, 0.9 * paw)
        rig.n("legFR").location.z += 0.04 * paw
        if i in (5, 6, 7):
            _sparks(rig, [0, 0, 0, 0, 0, 0.15, 0.3, 0.45][i], (-0.14, -0.22, 0.05), 0.6)
        _face(rig, 0.95 if i == 2 else 0.0, 0.15 + 0.15 * max(0, s))
    elif anim == "walk":
        _fire(rig, t, amp=1.2)
        fire.rotation_euler.x = -0.18   # a tocha deita para tras no trote
        b = abs(math.sin(math.tau * t))
        root.location.z += 0.035 * b
        R.squash(root, 1.0 + 0.05 * (b - 0.5))
        for nm, ph in (("FL", 0.0), ("BR", 0.0), ("FR", 0.5), ("BL", 0.5)):
            a = math.sin(math.tau * (t + ph))
            _leg(rig, nm, -0.55 * a, 0.7 * max(0.0, math.sin(math.tau * (t + ph) + math.pi / 2)))
        neck.rotation_euler.x = 0.06 * math.sin(math.tau * 2 * t)
        rope.rotation_euler.x = 0.3 * math.sin(math.tau * 2 * t + 0.8)
        rig.n("tail").rotation_euler.z = 0.35 * math.sin(math.tau * t + 1.0)
        _face(rig, 0.0, 0.2)
    elif anim == "attack":
        _attack(rig, i)
    elif anim == "hit":
        root.rotation_euler.z += IDLE_YAW
        _fire(rig, t, k=[0.75, 0.9, 1.04, 1.0][i], amp=1.5, yaw=IDLE_YAW)
        R.squash(root, [0.84, 1.08, 0.97, 1.0][i])
        R.tilt(root, [-0.12, 0.05, -0.02, 0.0][i], 0.4)
        neck.rotation_euler.x = [0.3, -0.12, 0.04, 0.0][i]
        rope.rotation_euler.x = [-0.6, 0.4, -0.15, 0.0][i]
        _face(rig, [0.9, 0.6, 0.2, 0.0][i], [0.6, 0.3, 0.1, 0.0][i])
        for nm in ("FL", "FR"):
            _leg(rig, nm, [0.2, -0.1, 0.0, 0.0][i], [0.3, 0.1, 0, 0][i])
    elif anim == "death":
        _death(rig, i)


def _attack(rig, i):
    """Empina (pivo nas patas de tras), escoiceia no ar, desce pisando com faiscas; a tocha cresce e a boca abre."""
    root, neck, fire = rig.root, rig.n("neck"), rig.n("fire")
    rear = [-0.12, -0.3, -0.41, -0.35, 0.04, 0.06, 0.02, 0.0][i]
    R.tilt(root, rear, 0.36)
    if i == 4:
        R.squash(root, 0.84)
    elif i == 5:
        R.squash(root, 1.06)
    kick = [0.3, -0.6, -1.2, -0.4, 0.2, 0.0, 0.0, 0.0][i]
    for nm, ph in (("FL", 0.0), ("FR", 0.35)):
        _leg(rig, nm, kick + ph * (-0.6 if i in (1, 2, 3) else 0.0), [0.6, 1.2, 0.5, 1.0, 0.0, 0.0, 0.0, 0.0][i])
    for nm in ("BL", "BR"):
        _leg(rig, nm, -rear * 0.8, 0.0)
    neck.rotation_euler.x = [0.05, -0.1, -0.15, -0.1, 0.1, 0.05, 0.0, 0.0][i]
    fire.rotation_euler.x = -rear * 0.8 - neck.rotation_euler.x - [0, 0, 0, 0, 0.12, 0.08, 0.04, 0][i]
    rig.n("rope").rotation_euler.x = [0.1, 0.5, 0.8, 0.6, -0.5, -0.2, 0.1, 0.0][i]
    k = [1.0, 1.05, 1.12, 1.16, 1.22, 1.12, 1.05, 1.0][i]
    _fire(rig, i / 8, k=k, amp=1.5)
    _face(rig, [0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0][i], [0.2, 0.5, 0.8, 0.9, 1.0, 0.7, 0.4, 0.2][i])
    _sparks(rig, [0, 0, 0, 0, 0.08, 0.22, 0.38, 0.55][i], (0.0, -0.24, 0.05), 1.0)


def _death(rig, i):
    """Dobra os joelhos da frente, depois os de tras, deita; a tocha encolhe ate sobrar a brasa negra."""
    root, neck, fire = rig.root, rig.n("neck"), rig.n("fire")
    fr = [0.2, 0.6, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i]
    bk = [0.0, 0.0, 0.3, 0.7, 1.0, 1.0, 1.0, 1.0][i]
    for nm in ("FL", "FR"):
        _leg(rig, nm, -0.9 * fr, 2.0 * fr)
    for nm in ("BL", "BR"):
        _leg(rig, nm, 1.0 * bk, -2.0 * bk)
    root.location.z -= 0.2 * max(fr, bk) * (0.6 + 0.4 * bk)
    R.tilt(root, 0.2 * fr - 0.18 * bk, -0.1)
    if i == 0:
        R.squash(root, 0.88)
    if i >= 5:
        root.rotation_euler.y += [0.12, 0.18, 0.18][i - 5]
    neck.rotation_euler.x = [0.15, 0.25, 0.3, 0.35, 0.45, 0.55, 0.6, 0.6][i]
    fire.rotation_euler.x = -neck.rotation_euler.x - 0.1
    rig.n("rope").rotation_euler.x = [0.3, 0.5, 0.6, 0.6, 0.7, 0.8, 0.8, 0.8][i]
    k = [0.9, 0.78, 0.64, 0.5, 0.38, 0.28, 0.22, 0.2][i]
    _fire(rig, i / 8, k=k, amp=0.6, side=max(0.0, 1.0 - i * 0.22))
    _face(rig, [0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i], [0.6, 0.4, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0][i])
    if i >= 3:
        rig.n("face").scale = (0.0001,) * 3
    if i >= 5:
        S.hide_motes(rig, "smk")
