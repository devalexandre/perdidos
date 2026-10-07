"""Animacoes do personagem jogavel (GDD §17.3, quadros definidos em ANIMS): pose por quadro em FK sobre o
esqueleto de chr_body. Nada de keyframes no .blend: pose(rig, anim, i, n) e deterministica.

Convencoes (personagem olhando para -Y, esquerda = +X, s = +1 esquerda / -1 direita):
  flex(j, a)   gira para a FRENTE (braco/coxa sobem para -Y; cotovelo dobra para frente)
  bend(j, a)   dobra o joelho (canela para tras)
  abduct(j, a, s) afasta o braco do corpo
  twist(j, a)  gira em torno do eixo vertical (a > 0 = vira para a esquerda do personagem)
Depois da pose, os pes sao travados no chao (lock_ground) exceto na morte e no sit."""
import math
from mathutils import Vector
import chr_lib as C

TAU = math.tau
ANIMS = [("idle", 8), ("walk", 8), ("attack_unarmed", 8), ("attack_blade", 8), ("attack_staff", 8),
         ("cast", 8), ("hit", 4), ("death", 8), ("sit", 1)]


def _r(rig, name):
    return rig.j(name).rotation_euler


def flex(rig, name, a):
    _r(rig, name).x -= a


def bend(rig, name, a):
    _r(rig, name).x += a


def abduct(rig, name, a, s):
    _r(rig, name).y -= s * a


def twist(rig, name, a):
    _r(rig, name).z += a


def lean(rig, name, a):
    """Inclina para o lado (a > 0 = para a esquerda do personagem)."""
    _r(rig, name).y += a


def ease(t):
    return C.MR.ease(t)


def keys(t, pts):
    return C.MR.keys(t, pts)


def rest_arms(rig, amt=1.0):
    """Pose neutra da referencia: bracos levemente afastados, cotovelos quase retos, maos relaxadas."""
    for s, nm in ((1, "L"), (-1, "R")):
        abduct(rig, f"uarm_{nm}", 0.10 * amt, s)
        flex(rig, f"farm_{nm}", 0.10 * amt)
        abduct(rig, f"hand_{nm}", -0.08 * amt, s)


def lock_ground(rig):
    """Sobe/desce a raiz para o ponto mais baixo dos pes ficar em z = 0."""
    import bpy
    bpy.context.view_layer.update()
    zs = [rig.anchors[n].matrix_world.translation.z for n in ("heel_L", "toe_L", "heel_R", "toe_R")]
    rig.root.location.z -= min(zs)


# ------------------------------------------------------------------ animacoes
def idle(rig, i, n):
    t = i / n
    br = math.sin(TAU * t)          # respiracao
    br2 = math.sin(TAU * t - 0.6)
    rest_arms(rig)
    _r(rig, "chest").x += 0.018 * br          # peito sobe (inclina para tras) ao inspirar
    rig.j("chest").location.z += 0.0045 * rig.k * (br + 1) / 2
    _r(rig, "neck").x -= 0.012 * br2
    _r(rig, "head").x -= 0.010 * br2
    for s, nm in ((1, "L"), (-1, "R")):
        abduct(rig, f"uarm_{nm}", 0.018 * (br + 1) / 2, s)
        flex(rig, f"farm_{nm}", 0.03 * (br2 + 1) / 2)
    # peso levemente numa perna (contrapposto sutil)
    lean(rig, "pelvis", 0.02); lean(rig, "chest", -0.025)
    bend(rig, "shin_R", 0.06); flex(rig, "thigh_R", 0.03)


def walk(rig, i, n):
    ph = TAU * i / n     # 0 = pe esquerdo na frente (contato)
    c, s_ = math.cos(ph), math.sin(ph)
    A = 0.34
    for sd, nm, sgn in ((1, "L", 1), (-1, "R", -1)):
        cc = c * sgn; ss = s_ * sgn
        flex(rig, f"thigh_{nm}", A * cc + 0.06)
        # joelho dobra na fase de balanco (perna vindo de tras para frente) e um pouco no contato
        swing = max(0.0, -ss)
        bend(rig, f"shin_{nm}", 0.10 + 0.85 * swing ** 1.3 + 0.10 * max(0.0, cc))
        # pe: ponta sobe no contato, calcanhar sobe atras
        _r(rig, f"foot_{nm}").x += -0.25 * max(0.0, cc) * 0.0 + (0.35 * max(0.0, -cc) * (1 - swing)) - 0.45 * swing * 0.6
        # bracos em oposicao
        flex(rig, f"uarm_{nm}", -0.40 * cc)
        flex(rig, f"farm_{nm}", 0.28 + 0.22 * max(0.0, -cc))
        abduct(rig, f"uarm_{nm}", 0.08, sd)
    twist(rig, "chest", -0.10 * c)
    twist(rig, "pelvis", 0.08 * c)
    flex(rig, "spine", 0.05)
    _r(rig, "head").x += 0.03
    twist(rig, "head", 0.05 * c)


def _hit_pose(rig, amt):
    flex(rig, "spine", -0.20 * amt)
    flex(rig, "chest", -0.12 * amt)
    _r(rig, "head").x += 0.25 * amt
    for sd, nm in ((1, "L"), (-1, "R")):
        abduct(rig, f"uarm_{nm}", 0.10 + 0.35 * amt, sd)
        flex(rig, f"farm_{nm}", 0.10 + 0.5 * amt)
    bend(rig, "shin_L", 0.15 * amt); bend(rig, "shin_R", 0.25 * amt)
    flex(rig, "thigh_R", -0.15 * amt)
    rig.root.location.y += 0.04 * amt


def hit(rig, i, n):
    amt = [0.75, 1.0, 0.55, 0.2][min(i, 3)] if n == 4 else math.sin(math.pi * (i + 0.5) / n)
    _hit_pose(rig, amt)


def death(rig, i, n):
    """Joelhos cedem e tomba de lado, sempre para a ESQUERDA DA TELA (le como 'deitado' em qualquer direcao,
    como nos sprites classicos; cair para longe/perto da camera some na perspectiva). Pivo nos pes."""
    from mathutils import Quaternion, Vector as Vec
    t = i / max(1, n - 1)
    k = rig.k
    kneel = keys(t, [(0.0, 0.25), (0.35, 1.0), (0.7, 0.55), (1.0, 0.45)])
    fall = keys(t, [(0.0, 0.0), (0.2, 0.05), (0.62, 0.8), (0.85, 1.0), (1.0, 1.0)])
    bounce = keys(t, [(0.0, 0.0), (0.84, 0.0), (0.92, 0.03), (1.0, 0.0)])
    _hit_pose(rig, keys(t, [(0.0, 1.0), (0.5, 0.5), (1.0, 0.0)]))
    a = math.radians(getattr(rig, "cur_dir", 0.0))
    # esquerda da tela e um pouco para longe da camera (encurta o corpo deitado para caber no quadro de 96)
    left = Vec((-math.cos(a), math.sin(a), 0.0)); away = Vec((math.sin(a), math.cos(a), 0.0))
    d = (left * 0.82 + away * 0.57).normalized()
    q = Quaternion(Vec((0, 0, 1)).cross(d), 1.52 * fall)
    rig.root.rotation_euler = q.to_euler('XYZ')
    # centraliza o corpo deitado sobre a origem (quadril perto dos pes originais)
    rig.root.location += -d * (0.78 * k * fall)
    rig.root.location.z += (-0.14 * kneel * (1 - fall) + 0.10 * fall + bounce) * k
    for sd, nm in ((1, "L"), (-1, "R")):
        flex(rig, f"thigh_{nm}", 0.55 * kneel * (1 - fall) + 0.45 * fall * (1.0 if nm == "L" else 0.3))
        bend(rig, f"shin_{nm}", 1.0 * kneel * (1 - fall) + 0.8 * fall * (1.0 if nm == "L" else 0.3))
        abduct(rig, f"uarm_{nm}", 0.25 + 0.35 * fall, sd)
        flex(rig, f"farm_{nm}", 0.3 * fall)
    _r(rig, "head").x -= 0.15 * fall


def sit(rig, i, n):
    """Sentado no chao, pernas cruzadas a frente, maos nos joelhos."""
    k = rig.k
    rig.root.location.z -= 0.80 * k
    rig.root.location.y += 0.15 * k      # quadril para tras: pernas cruzadas ficam sobre a origem
    for sd, nm in ((1, "L"), (-1, "R")):
        flex(rig, f"thigh_{nm}", 1.45)
        abduct(rig, f"thigh_{nm}", 0.55, sd)
        twist(rig, f"thigh_{nm}", 0.25 * sd)
        bend(rig, f"shin_{nm}", 2.45)
        twist(rig, f"shin_{nm}", -0.9 * sd)
        flex(rig, f"uarm_{nm}", 0.45)
        abduct(rig, f"uarm_{nm}", 0.22, sd)
        flex(rig, f"farm_{nm}", 0.55)
    flex(rig, "spine", 0.10)
    _r(rig, "head").x += 0.02


def _attack(rig, i, n, style):
    t = i / n
    # antecipacao (0..0.3), golpe (0.3..0.55), segura, volta
    if style == "unarmed":
        wind = keys(t, [(0.0, 0.0), (0.25, 1.0), (0.4, -0.2), (0.6, -0.1), (1.0, 0.0)])
        strike = keys(t, [(0.0, 0.0), (0.3, 0.0), (0.42, 1.0), (0.62, 1.0), (1.0, 0.0)])
        twist(rig, "chest", 0.35 * wind - 0.45 * strike)
        twist(rig, "pelvis", 0.15 * wind - 0.2 * strike)
        flex(rig, "uarm_R", -0.3 * wind + 1.45 * strike)
        abduct(rig, "uarm_R", 0.2 * wind + 0.05, -1)
        flex(rig, "farm_R", 1.6 * wind + 1.5 * (1 - strike) * (1 - wind) * 0.3 + 0.1 * strike)
        flex(rig, "uarm_L", 0.9 + 0.2 * wind - 0.2 * strike)
        flex(rig, "farm_L", 1.5)
        abduct(rig, "uarm_L", 0.15, 1)
        flex(rig, "thigh_L", 0.35 * (wind + strike) / 1.5)
        bend(rig, "shin_L", 0.3)
        flex(rig, "thigh_R", -0.2)
        bend(rig, "shin_R", 0.25)
        flex(rig, "spine", 0.10 * strike)
        rig.root.location.y -= 0.06 * rig.k * strike
    elif style == "blade":
        # corte diagonal: mao direita sobe atras do ombro e desce cruzando o corpo
        up = keys(t, [(0.0, 0.0), (0.28, 1.0), (0.38, 0.6), (0.52, -0.2), (0.7, -0.2), (1.0, 0.0)])
        cut = keys(t, [(0.0, 0.0), (0.3, 0.0), (0.48, 1.0), (0.7, 1.0), (1.0, 0.0)])
        flex(rig, "uarm_R", 2.3 * up + 0.6 * cut * (1 - up))
        abduct(rig, "uarm_R", 0.5 * up - 0.3 * cut + 0.1, -1)
        twist(rig, "uarm_R", 0.4 * cut)
        flex(rig, "farm_R", 0.9 * up + 0.3)
        twist(rig, "chest", 0.40 * up - 0.55 * cut)
        twist(rig, "pelvis", 0.15 * up - 0.25 * cut)
        flex(rig, "spine", 0.14 * cut)
        flex(rig, "uarm_L", 0.4 * cut + 0.1)
        abduct(rig, "uarm_L", 0.35, 1)
        flex(rig, "farm_L", 0.6)
        flex(rig, "thigh_R", 0.45 * cut)
        bend(rig, "shin_R", 0.45 * cut + 0.1)
        flex(rig, "thigh_L", -0.25 * cut)
        bend(rig, "shin_L", 0.15)
        rig.root.location.y -= 0.07 * rig.k * cut
    else:  # staff: duas maos, golpe de cima para baixo a frente
        up = keys(t, [(0.0, 0.0), (0.3, 1.0), (0.4, 0.7), (0.55, 0.0), (1.0, 0.0)])
        hitv = keys(t, [(0.0, 0.0), (0.35, 0.0), (0.52, 1.0), (0.72, 1.0), (1.0, 0.0)])
        for nm, sd in (("R", -1), ("L", 1)):
            flex(rig, f"uarm_{nm}", 2.4 * up + 1.0 * hitv * (1 - up) + 0.25)
            abduct(rig, f"uarm_{nm}", 0.12 - 0.25 * hitv, sd)
            flex(rig, f"farm_{nm}", 0.5 + 0.6 * up)
        flex(rig, "spine", -0.12 * up + 0.2 * hitv)
        _r(rig, "head").x += -0.1 * up + 0.1 * hitv
        flex(rig, "thigh_L", 0.45 * hitv)
        bend(rig, "shin_L", 0.45 * hitv + 0.1)
        flex(rig, "thigh_R", -0.2 * hitv)
        rig.root.location.y -= 0.06 * rig.k * hitv


def cast(rig, i, n):
    """Conjurar: maos se juntam no peito, sobem e abrem para a frente (liberacao)."""
    t = i / n
    gather = keys(t, [(0.0, 0.0), (0.3, 1.0), (0.5, 1.0), (0.62, 0.0), (1.0, 0.0)])
    push = keys(t, [(0.0, 0.0), (0.45, 0.0), (0.62, 1.0), (0.85, 1.0), (1.0, 0.0)])
    for nm, sd in (("L", 1), ("R", -1)):
        flex(rig, f"uarm_{nm}", 0.9 * gather + 1.35 * push)
        abduct(rig, f"uarm_{nm}", -0.25 * gather + 0.10 * push + 0.1, sd)
        flex(rig, f"farm_{nm}", 1.55 * gather + 0.25 * push)
        twist(rig, f"uarm_{nm}", 0.3 * sd * gather)
    flex(rig, "spine", -0.08 * gather + 0.08 * push)
    _r(rig, "head").x += -0.08 * gather + 0.05 * push
    flex(rig, "thigh_L", 0.3 * push)
    bend(rig, "shin_L", 0.3 * push)
    flex(rig, "thigh_R", -0.15 * push)
    rig.root.location.y -= 0.04 * rig.k * push


POSE = {"idle": idle, "walk": walk, "hit": hit, "death": death, "sit": sit, "cast": cast,
        "attack_unarmed": lambda r, i, n: _attack(r, i, n, "unarmed"),
        "attack_blade": lambda r, i, n: _attack(r, i, n, "blade"),
        "attack_staff": lambda r, i, n: _attack(r, i, n, "staff")}
NO_GROUND_LOCK = {"death", "sit"}


def pose(rig, anim, i, n):
    POSE[anim](rig, i, n)
    # postura propria (NPCs: curvado, peito estufado...) somada a qualquer animacao: {"pivo": [x, y, z] rad}
    for jn, rot in getattr(rig, "posture", {}).items():
        r = _r(rig, jn)
        r.x += rot[0]; r.y += rot[1]; r.z += rot[2]
    if anim not in NO_GROUND_LOCK:
        lock_ground(rig)
