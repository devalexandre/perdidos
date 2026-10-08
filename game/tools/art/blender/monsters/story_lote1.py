"""Pecas compartilhadas dos chefes da historia (Arco 1, lote 1): story_saci, story_mula, story_lobisomem,
story_curupira e story_pisadeira (ARCO-1-TERRA-DE-PINDORAMA.md). Os chefes da historia so existem na forma atroz
(estagio 4, quadro 240), corrompidos por Erevos.

Sinal comum da corrupcao: **fogo que escurece ate ficar preto nas pontas, com borda violeta** (o mesmo do Boitata,
cap. 2 do arco) e fumaca preta subindo. Cada chefe mostra o sinal num lugar proprio do corpo (ponta do gorro do Saci,
pescoco da Mula, juba do Lobisomem, cabelo do Curupira, pontas do cabelo da Pisadeira).

  - corrupt_flame(): tufo de linguas de fogo; cada lingua = base de cor (brasa ou escura) + metade de cima preta
    (contorno violeta) + faisca violeta na ponta; flicker() faz tremular em loop;
  - smoke(): baforadas de fumaca preta/violeta subindo (particulas do sol_common);
  - glow_eye(): olho chibi aceso com cor escolhida (brasa, ouro, folha) — mesmo desenho do S.eye(mode="ember");
  - limb(): cone de membro com grupo (sem linha entre as partes do mesmo membro).
Materiais em <id>_mats.json (so cores da paleta-mestra.gpl; o post.py le esse arquivo sozinho).
Modelo proprio por script (sem malha de terceiros); rosto e regras de pixel art do stone_armadillo.py/sol_common.py."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

# materiais comuns da corrupcao (definidos em cada <id>_mats.json)
FIRE_BLACK = "cf_black"     # metade de cima da lingua: preto (Base 1), contorno violeta
FIRE_TIP = "cf_tip"         # faisca na ponta: violeta claro
FIRE_DARK = "cf_dark"       # base escura (roxo) das linguas de fumaca
SMOKE = ("cf_smoke", "cf_smoke2")


def corrupt_flame(rig, nm, base, parent, size=1.0, n=5, width=0.75, spread=1.0, base_mat="ember",
                  core=("ember_hot", "ember_core"), height=1.0, black_from=0.45, prio=2.0, body=False, slim=1.0,
                  lean=0.5, hot=None, **_old):
    """Fogo corrompido em leque, sempre de frente para a camera (o flicker() gira o pivo contra a direcao do quadro,
    como um pixel artista desenharia a chama igual nas 5 direcoes). Cria o pivo nm e as linguas nm_t<j>
    (rig.flames[nm]). Cada lingua: base de cor base_mat, metade de cima PRETA com borda violeta e faisca violeta na
    ponta; as linguas ficam atras do corpo, entao o preto so aparece no contorno de cima.
    body = gota de fogo grande embaixo (camadas: base_mat, core[0] e core[1] na frente) — o fogaréu da Mula.
    width = meia-abertura do leque (rad); spread = afastamento das bases; slim afina as linguas."""
    base = Vector(base)
    s = size
    piv = rig.empty(nm, base, parent)
    lst = []
    z0 = (0.13 if body else 0.0) * s
    for j in range(n):
        u = 0.0 if n == 1 else 2.0 * j / (n - 1) - 1.0
        th = width * u
        bx = math.sin(th) * (0.1 if body else 0.055) * s * spread
        b = base + Vector((bx, 0.025 * s, z0 + (0.0 if body else 0.0)))
        jit = 0.82 + 0.3 * ((j * 7) % 5) / 4
        h = (0.42 if body else 0.32) * s * height * (1.0 - 0.38 * abs(u)) * jit
        ax = Vector((math.sin(th) * lean, 0.0, math.cos(th))).normalized()
        tip = b + ax * h
        r0 = (0.085 if body else 0.07) * s * slim * (1.0 - 0.25 * abs(u))
        tp = rig.empty(f"{nm}_t{j}", b, piv)
        mid = b + (tip - b) * black_from
        curl = Vector((0.03 * s * (1 if j % 2 else -1), 0.0, 0.0))
        # a parte de baixo (cor) fica na frente de todas as pontas pretas: o preto so aparece no contorno de cima
        fwd = Vector((0, -0.035 * s, 0))
        rig.add_mesh(R.cone(f"{nm}_lo{j}", b + fwd, mid + (tip - b) * 0.1 + fwd, r0, r0 * 0.75, seg=10, rings=2), f"{nm}_lo",
                     base_mat, tp, unlit=True, noline=True, prio=prio)
        rig.add_mesh(R.cone(f"{nm}_hi{j}", mid - fwd, tip - fwd, r0 * 0.78, 0.003, seg=10, rings=5, bend=curl), f"{nm}_hi",
                     FIRE_BLACK, tp, unlit=True, noline=True, prio=prio + 0.2)
        if hot:
            # veio claro na frente da parte de baixo (chama de dois tons)
            rig.add_mesh(R.cone(f"{nm}_hot{j}", b + fwd * 2, b + (mid - b) * 0.85 + fwd * 2, r0 * 0.5, r0 * 0.15, seg=8,
                                rings=2), f"{nm}_hotv", hot, tp, unlit=True, noline=True, prio=prio + 0.4)
        g = tip - ax * 0.028 * s - fwd
        rig.add_mesh(R.ellipsoid(f"{nm}_gl{j}", g, (0.014 * s, 0.012 * s, 0.022 * s), seg=8, rings=5),
                     f"{nm}_gl", FIRE_TIP, tp, unlit=True, noline=True, prio=prio + 1.5)
        lst.append((f"{nm}_t{j}", (j * 0.37) % 1.0))
    if body:
        bc = base + Vector((0, 0, 0.1 * s))
        rig.add_mesh(R.ellipsoid(f"{nm}_bulb", bc, (0.14 * s, 0.07 * s, 0.13 * s)), f"{nm}_body", base_mat, piv,
                     unlit=True, noline=True, prio=prio)
        rig.add_mesh(R.cone(f"{nm}_cone", bc, bc + Vector((0, 0, 0.36 * s * height)), 0.135 * s, 0.01, seg=14, rings=4),
                     f"{nm}_body", base_mat, piv, unlit=True, noline=True, prio=prio)
        if core:
            hc = base + Vector((0, -0.06 * s, 0.085 * s))
            rig.add_mesh(R.ellipsoid(f"{nm}_hot", hc, (0.095 * s, 0.03 * s, 0.085 * s)), f"{nm}_hot", core[0], piv,
                         unlit=True, noline=True, prio=prio + 0.4)
            rig.add_mesh(R.cone(f"{nm}_hotc", hc, hc + Vector((0.01 * s, 0, 0.24 * s * height)), 0.09 * s, 0.006, seg=12,
                                rings=3, bend=(0.02 * s, 0, 0)), f"{nm}_hot", core[0], piv, unlit=True, noline=True,
                         prio=prio + 0.4)
            cc = base + Vector((0, -0.1 * s, 0.07 * s))
            rig.add_mesh(R.ellipsoid(f"{nm}_core", cc, (0.05 * s, 0.02 * s, 0.05 * s)), f"{nm}_core", core[1], piv,
                         unlit=True, noline=True, prio=prio + 0.8)
            rig.add_mesh(R.cone(f"{nm}_corec", cc, cc + Vector((-0.005 * s, 0, 0.12 * s)), 0.046 * s, 0.004, seg=10,
                                rings=2), f"{nm}_core", core[1], piv, unlit=True, noline=True, prio=prio + 0.8)
    elif core:
        c = base + Vector((0, -0.04 * s, 0.05 * s))
        rig.add_mesh(R.ellipsoid(f"{nm}_core", c, (0.06 * s, 0.03 * s, 0.07 * s)), f"{nm}_core", core[0], piv,
                     unlit=True, noline=True, prio=prio + 0.6)
        rig.add_mesh(R.ellipsoid(f"{nm}_core2", c + Vector((0, -0.025 * s, -0.01 * s)),
                                 (0.03 * s, 0.015 * s, 0.035 * s)), f"{nm}_core2", core[1], piv,
                     unlit=True, noline=True, prio=prio + 1.2)
    if not hasattr(rig, "flames"):
        rig.flames = {}
    rig.flames[nm] = lst
    return piv


def flicker(rig, nm, t, amp=1.0, k=1.0, face=True):
    """t em ciclos (loop). Cada lingua estica/encolhe e balanca com fase propria; k = tamanho geral (0 = apagado).
    face: gira o leque de frente para a camera (contra o giro da direcao do quadro)."""
    if face:
        rig.n(nm).rotation_euler.z = -math.radians(R.CUR["dir"])
    for j, (node, ph) in enumerate(rig.flames.get(nm, [])):
        o = rig.n(node)
        u = math.tau * (2 * t + ph)
        s = max(0.0001, k * (1.0 + 0.22 * amp * math.sin(u) + 0.08 * amp * math.sin(2 * u + j)))
        w = max(0.0001, k * (1.0 - 0.08 * amp * math.sin(u)))
        o.scale = (w, w, s)
        o.rotation_euler.y = 0.14 * amp * math.sin(u + 1.7)
    if k < 0.01:
        rig.n(nm).scale = (0.0001,) * 3
    elif k < 1.0:
        rig.n(nm).scale = (max(k, 0.0001),) * 3


def smoke(rig, nm, spots, parent, size=0.035, prio=3.0):
    return S.add_motes(rig, nm, spots, list(SMOKE), size=size, parent=parent, prio=prio)


def glow_eye(rig, nm, ep, piv, rx, rz, yaw, iris="eye_ember", core="ember_core", tilt=0.25, slit=False):
    """Olho grande escuro com iris acesa (cor iris), miolo claro e brilho; slit = fenda escura (fera)."""
    k = rz / 0.145
    e = rig.empty(f"eye{nm}", ep, piv)
    sx = 1 if nm.endswith("L") else -1
    rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (rx, 0.05 * k, rz), rot=(tilt, 0, yaw)), f"eye{nm}", "eye", e,
                 noline=True, unlit=True, prio=1.8)
    rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.03, -0.03)) * k, (rx * 0.78, 0.026 * k, rz * 0.6),
                             rot=(tilt, 0, yaw)), f"iris{nm}", iris, e, noline=True, unlit=True, prio=1.6)
    if slit:
        rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0.0, -0.05, -0.03)) * k, (0.017 * k, 0.02 * k, rz * 0.5),
                                 rot=(tilt, 0, yaw)), f"slit{nm}", "eye_slit", e, noline=True, unlit=True, prio=4.0)
    else:
        rig.add_mesh(R.ellipsoid(f"core{nm}", ep + Vector((0.0, -0.05, -0.04)) * k, (rx * 0.36, 0.02 * k, rz * 0.3),
                                 rot=(tilt, 0, yaw)), f"core{nm}", core, e, noline=True, unlit=True, prio=3.5)
    rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.04 + 0.008 * sx, -0.06, 0.035)) * k, (0.028 * k, 0.014 * k, 0.028 * k)),
                 f"hl{nm}", "white", e, noline=True, unlit=True, prio=7.0)
    rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.035, -0.06, -0.06)) * k, (0.014 * k, 0.01 * k, 0.014 * k)),
                 f"hl2{nm}", "white", e, noline=True, unlit=True, prio=3.0)
    return e


def limb(rig, nm, a, b, r0, r1, mat, parent, group=None, bend=(0, 0, 0), seg=10, rings=3, **kw):
    return rig.add_mesh(R.cone(nm, a, b, r0, r1, seg=seg, rings=rings, bend=bend), nm, mat, parent,
                        group=group or nm, **kw)


def ell(rig, nm, c, r, mat, parent, rot=(0, 0, 0), part=None, **kw):
    return rig.add_mesh(R.ellipsoid(nm, c, r, rot=rot), part or nm, mat, parent, **kw)


def teeth(rig, nm, center, width, n, parent, h=0.03, r=0.012, mat="fang_n", down=True, y=0.0, prio=2.6):
    """Fileira de dentes pontudos (sorriso/rosnado) ao longo de x."""
    for j in range(n):
        x = -width / 2 + width * (j + 0.5) / n
        b = Vector(center) + Vector((x, y - 0.004 * (1 - abs(x) / max(width, 1e-6)), 0))
        tip = b + Vector((0, -0.006, -h if down else h))
        rig.add_mesh(R.cone(f"{nm}{j}", b, tip, r, 0.002, seg=5, rings=1), nm, mat, parent, noline=True, prio=prio)


def hide(rig, name):
    rig.n(name).scale = (0.0001, 0.0001, 0.0001)
