"""Pecas compartilhadas dos chefes da historia do Arco 1 (lote 2: Iara, Mapinguari, Cuca, Boiuna, Boitata).
Ver ARCO-1-TERRA-DE-PINDORAMA.md. Os chefes da historia so existem na forma atroz (estagio 4, quadro 240, paleta noturna).
  - fogo negro da corrupcao de Erevos: lingua de fogo preta (contorno violeta) com miolo roxo e ponta violeta;
    sinal comum a todos os chefes da historia (black_flame + flames para tremular/apagar);
  - corrente de segmentos (serpente, cauda de peixe, cabelo comprido): cada segmento e um pivo filho do anterior,
    entao girar os pivos dobra a corrente inteira (chain + chain_wave);
  - notas musicais e aneis de som (canto da Iara), gotas de chuva, raio em zigue-zague.
Rosto (olho chibi, sobrancelha, bochecha) e particulas vem do sol_common.py (piloto aprovado das Ilhas do Sol).
Modelo proprio por script (sem malha de terceiros)."""
import math
from mathutils import Vector
import mon_rig as R
import sol_common as S

Z = Vector((0, 0, 1))


# ------------------------------------------------------------------ fogo negro (corrupcao)
def _flame_shape(name, base, up, side, fwd, h, w, v0=0.0, v1=1.0, grow=1.0, off=0.0, lobes=3, curl=0.3, ph=0.0):
    """Superficie de labareda: gota redonda embaixo que afina e se divide em 'lobes' linguas no alto, ponta
    curvada para o lado (curl). v0..v1 = faixa de altura (0 = pe, 1 = ponta); grow engorda (para a ponta violeta
    cobrir o corpo preto); off empurra para a camera."""
    def rad(v, th):
        bulb = math.sin(math.pi * 0.5 * min(1.0, v / 0.3)) ** 0.5
        taper = (1.0 - v) ** 0.65 * (1.0 + 0.14 * math.sin(math.pi * 3.0 * v + ph))   # lingua ondulada
        lob = 1.0 + 0.55 * v * max(0.0, math.cos(lobes * th + ph)) ** 2
        return w * bulb * taper * lob * grow

    def fn(u, v):
        th = math.tau * u
        vv = v0 + (v1 - v0) * v
        r = rad(vv, th)
        c = base + up * (h * vv) + side * (curl * h * vv * vv) + fwd * off
        return c + (side * math.cos(th) + fwd * math.sin(th)) * r
    return R.surface(name, fn, 18, 8, base + up * (h * (v0 + v1) * 0.5) + side * (curl * h * 0.3))


def black_flame(rig, nm, base, up, h, w, parent, phase=0.0, bend=0.55, mats=("bfire_l2", "bfire_core_l2", "bfire_tip_l2"),
                prio=2.2, tongues=3):
    """Fogo negro em base, apontando para up, altura h e largura w: gota redonda embaixo que se abre em linguas
    (tongues) no alto, ponta curvada; corpo preto com contorno violeta, miolo roxo e as pontas violeta (o quarto de
    cima). Pivo = nm (a escala anima a chama)."""
    base = Vector(base)
    up = Vector(up).normalized()
    side = up.cross(Vector((0, -1, 0)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    fwd = side.cross(up).normalized()  # aponta para a camera (-Y) quando up = Z
    piv = rig.empty(nm, base, parent)
    body, core, tipm = mats
    ph = phase * 5.0
    # linguas: (deslocamento lateral em w, altura relativa, largura relativa, curvatura)
    tg = [(0.0, 1.0, 1.0, bend)]
    if tongues >= 2:
        tg.append((0.62, 0.7, 0.62, bend + 0.45))
    if tongues >= 3:
        tg.append((-0.62, 0.58, 0.58, -bend - 0.2))
    for k, (dx, hh, ww, cu) in enumerate(tg):
        b = base + side * (dx * w) + fwd * (0.02 * w * k)
        rig.add_mesh(_flame_shape(f"{nm}_b{k}", b, up, side, fwd, h * hh, w * ww, 0.0, 1.0, lobes=2, curl=cu, ph=ph + k),
                     f"{nm}_body", body, piv, unlit=True, noline=True, prio=prio)
        # faixa roxa no meio e ponta violeta no alto (degrade preto -> roxo -> violeta)
        rig.add_mesh(_flame_shape(f"{nm}_m{k}", b, up, side, fwd, h * hh, w * ww, 0.42, 0.84, grow=1.08, off=w * 0.04,
                                  lobes=2, curl=cu, ph=ph + k), f"{nm}_core", core, piv, unlit=True, noline=True,
                     prio=prio + 0.3)
        rig.add_mesh(_flame_shape(f"{nm}_t{k}", b, up, side, fwd, h * hh, w * ww, 0.8, 1.0, grow=1.14, off=w * 0.06,
                                  lobes=2, curl=cu, ph=ph + k), f"{nm}_tip", tipm, piv, unlit=True, noline=True,
                     prio=prio + 0.6)
    # miolo roxo no pe da lingua grande (brilho por dentro do fogo negro)
    rig.add_mesh(_flame_shape(f"{nm}_k", base + fwd * (w * 0.3), up, side, fwd, h * 0.42, w * 0.5, 0.0, 1.0, off=w * 0.3,
                              lobes=1, curl=bend * 0.5, ph=ph), f"{nm}_core", core, piv, unlit=True, noline=True,
                 prio=prio + 0.4)
    if not hasattr(rig, "flames"):
        rig.flames = []
    rig.flames.append((nm, phase))
    return piv


def _fire_shape(name, base, up, side, fwd, h, w, v0=0.0, v1=1.0, grow=1.0, off=0.0, curl=0.3, ph=0.0, flat=0.75):
    """Labareda larga (fogo vivo): bojo redondo embaixo, borda ondulada que tremula, ponta curvada para o lado.
    flat < 1 achata na direcao da camera (a lingua fica larga de frente, como no desenho 2D)."""
    def rad(v):
        bulb = math.sin(math.pi * 0.5 * min(1.0, v / 0.32)) ** 0.45
        return w * bulb * (1.0 - v) ** 0.55 * (1.0 + 0.2 * math.sin(math.pi * 3.2 * v + ph)) * grow

    def fn(u, v):
        th = math.tau * u
        vv = v0 + (v1 - v0) * v
        r = rad(vv)
        c = base + up * (h * vv) + side * (curl * h * vv * vv) + fwd * off
        return c + (side * math.cos(th) + fwd * (math.sin(th) * flat)) * r
    return R.surface(name, fn, 18, 9, base + up * (h * (v0 + v1) * 0.5) + side * (curl * h * 0.3))


def fire_flame(rig, nm, base, up, h, w, parent, phase=0.0, bend=0.4, tongues=3, share=True, tip=0.74, prio=2.0):
    """Fogo vivo da serpente de fogo (Boitata): miolo amarelo-claro -> amarelo -> laranja-avermelhado, e so as
    PONTAS pretas com borda violeta (a corrupcao de Erevos). Linguas largas e onduladas, nao laminas.
    share=True: todas as chamas usam as mesmas 4 pecas (economiza ids). Pivo = nm; anima com flames()."""
    base = Vector(base)
    up = Vector(up).normalized()
    side = up.cross(Vector((0, -1, 0)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    fwd = side.cross(up).normalized()
    piv = rig.empty(nm, base, parent)
    pn = (lambda k: f"fire_{k}") if share else (lambda k: f"{nm}_{k}")
    ph = phase * 5.0
    tg = [(0.0, 1.0, 1.0, bend)]
    if tongues >= 2:
        tg.append((0.7, 0.66, 0.68, bend + 0.5))
    if tongues >= 3:
        tg.append((-0.7, 0.56, 0.62, -bend - 0.35))
    for k, (dx, hh, ww, cu) in enumerate(tg):
        b = base + side * (dx * w) - fwd * (0.05 * w * k)
        rig.add_mesh(_fire_shape(f"{nm}_b{k}", b, up, side, fwd, h * hh, w * ww, 0.0, 1.0, curl=cu, ph=ph + k),
                     pn("body"), "ember", piv, unlit=True, noline=True, prio=prio)
        rig.add_mesh(_fire_shape(f"{nm}_t{k}", b, up, side, fwd, h * hh, w * ww, tip, 1.0, grow=1.12, off=w * 0.06,
                                 curl=cu, ph=ph + k), pn("tip"), "bfire_l2", piv, unlit=True, noline=True,
                     prio=prio + 0.6)
    # miolo: amarelo e amarelo-claro na frente da lingua grande
    rig.add_mesh(_fire_shape(f"{nm}_m", base + fwd * (w * 0.3), up, side, fwd, h * 0.62, w * 0.72, 0.0, 1.0, off=w * 0.3,
                             curl=bend * 0.6, ph=ph), pn("mid"), "ember_hot", piv, unlit=True, noline=True, prio=prio + 0.3)
    rig.add_mesh(_fire_shape(f"{nm}_k", base + fwd * (w * 0.5), up, side, fwd, h * 0.36, w * 0.45, 0.0, 1.0, off=w * 0.5,
                             curl=bend * 0.4, ph=ph), pn("core"), "ember_core", piv, unlit=True, noline=True, prio=prio + 0.5)
    if not hasattr(rig, "flames"):
        rig.flames = []
    rig.flames.append((nm, phase))
    return piv


def flames(rig, t, k=1.0, only=None, sway=0.12):
    """Tremula todas as chamas (t em ciclos; loop fecha com t inteiro). k < 1 encolhe (apagando); k = 0 some."""
    for nm, ph in getattr(rig, "flames", []):
        if only and not nm.startswith(only):
            continue
        o = rig.n(nm)
        if k <= 0.02:
            o.scale = (0.0001, 0.0001, 0.0001)
            continue
        a = math.tau * (2 * t + ph)
        s = (1.0 + 0.18 * math.sin(a) + 0.08 * math.sin(2 * a + 1.3)) * k
        wdt = k * (1.0 - 0.08 * math.sin(a))
        o.scale = (wdt, wdt, max(0.0001, s))
        o.rotation_euler.y += sway * math.sin(a + 0.7)
        o.rotation_euler.x += sway * 0.5 * math.sin(a * 0.5 + ph * 3)


# ------------------------------------------------------------------ corrente de segmentos
def chain(rig, nm, pts, radii, parent, mat, flat=1.0, joint=True, belly=None, belly_mat=None, ring_mat=None,
          group=None, seg=16):
    """Corrente: pts[i] = pivo i (filho do i-1), segmento i = cone de pts[i] a pts[i+1] com esfera na junta.
    flat < 1 achata na direcao y local (cauda de peixe). belly = vetor 'frente' (placas da barriga mais claras).
    Devolve a lista de nomes dos pivos."""
    names = []
    par = parent
    for i, p in enumerate(pts):
        piv = rig.empty(f"{nm}{i}", p, par)
        names.append(f"{nm}{i}")
        par = piv
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        r0, r1 = radii[i], radii[i + 1]
        piv = rig.n(names[i])
        part = f"{nm}_s{i}"
        g = group or None
        rig.add_mesh(R.cone(part, a, b, r0, r1, seg=seg, rings=3), part, mat, piv, group=g)
        if joint:
            rig.add_mesh(R.ellipsoid(part + "j", a, (r0, r0, r0), seg=14, rings=10), part, mat, piv, group=g)
        if belly is not None:
            d = (b - a).normalized()
            fw = Vector(belly)
            fw = (fw - d * fw.dot(d)).normalized()
            m = a + (b - a) * 0.5 + fw * ((r0 + r1) * 0.5 * 0.72)
            ln = (b - a).length * 0.55
            from mathutils import Matrix
            # placa achatada alinhada ao segmento
            x = d.cross(fw).normalized()
            M = Matrix((x, fw, d)).transposed()
            rig.add_mesh(R.ellipsoid(part + "b", m, ((r0 + r1) * 0.5 * 0.62, (r0 + r1) * 0.5 * 0.4, ln),
                                     rot=M.to_euler()), part + "b", belly_mat, piv)
        if ring_mat:
            rig.add_mesh(S.torus(part + "r", a, r0 * 1.0, r0 * 0.12, rot=S.align(Vector(b) - Vector(a))), part + "r",
                         ring_mat, piv)
    tip = rig.empty(f"{nm}{len(pts)}", pts[-1], rig.n(names[-1]))
    names.append(f"{nm}{len(pts)}")
    return names


def chain_wave(rig, names, t, amp, axis="z", phase_step=0.6, ramp=1.0, start=0):
    """Onda pela corrente: cada pivo gira amp*sin(2pi t - i*phase_step) no eixo dado (z = lado, x = frente/tras)."""
    for i, n in enumerate(names[start:-1], start):
        w = min(1.0, (i - start + 1) / max(1.0, ramp))
        a = amp * w * math.sin(math.tau * t - i * phase_step)
        o = rig.n(n)
        if axis == "z":
            o.rotation_euler.z += a
        elif axis == "x":
            o.rotation_euler.x += a
        else:
            o.rotation_euler.y += a


def chain_bend(rig, names, ang, axis="x", start=0, end=None):
    """Dobra uniforme (soma ang em cada pivo de start a end)."""
    for n in names[start:end if end is not None else len(names) - 1]:
        o = rig.n(n)
        setattr(o.rotation_euler, axis, getattr(o.rotation_euler, axis) + ang)


# ------------------------------------------------------------------ canto (Iara) e tempestade (Boiuna)
def note(rig, nm, p, parent, mat="cold_hot", k=1.0, double=False):
    """Nota musical (colcheia): cabeca + haste + bandeirinha. Pivo nm em p."""
    p = Vector(p)
    piv = rig.empty(nm, p, parent)
    rig.add_mesh(R.ellipsoid(f"{nm}h", p, (0.045 * k, 0.025 * k, 0.034 * k), rot=(0, -0.45, 0)), f"{nm}", mat, piv,
                 unlit=True, prio=4.0)
    top = p + Vector((0.036 * k, 0, 0.13 * k))
    rig.add_mesh(R.cone(f"{nm}s", p + Vector((0.036 * k, 0, 0.0)), top, 0.011 * k, 0.011 * k, seg=6, rings=1), f"{nm}",
                 mat, piv, unlit=True, prio=4.0)
    rig.add_mesh(R.cone(f"{nm}f", top, top + Vector((0.05 * k, 0, -0.06 * k)), 0.016 * k, 0.006 * k, seg=6, rings=2,
                        bend=(0.01 * k, 0, 0.015 * k)), f"{nm}", mat, piv, unlit=True, prio=4.0)
    if double:
        p2 = p + Vector((0.1 * k, 0, 0.02 * k))
        rig.add_mesh(R.ellipsoid(f"{nm}h2", p2, (0.045 * k, 0.025 * k, 0.034 * k), rot=(0, -0.45, 0)), f"{nm}", mat, piv,
                     unlit=True, prio=4.0)
        rig.add_mesh(R.cone(f"{nm}s2", p2 + Vector((0.036 * k, 0, 0)), p2 + Vector((0.036 * k, 0, 0.13 * k)), 0.011 * k,
                            0.011 * k, seg=6, rings=1), f"{nm}", mat, piv, unlit=True, prio=4.0)
        rig.add_mesh(R.cone(f"{nm}b", top, p2 + Vector((0.036 * k, 0, 0.13 * k)), 0.016 * k, 0.016 * k, seg=6, rings=1),
                     f"{nm}", mat, piv, unlit=True, prio=4.0)
    return piv


def sound_ring(rig, nm, p, parent, r, mat="cold", thick=0.016):
    """Anel de som de frente para a camera (no plano xz), expande por escala do pivo."""
    piv = rig.empty(nm, p, parent)
    rig.add_mesh(S.torus(nm + "m", p, r, thick, rot=(math.pi / 2, 0, 0), nu=28, nv=6), nm, mat, piv, unlit=True,
                 noline=True, prio=3.0)
    return piv


def bolt(rig, nm, top, bottom, parent, mats=("bolt", "bolt2"), w=0.03, n=5, jag=0.09, seed=1):
    """Raio em zigue-zague de top a bottom (pivo nm no topo)."""
    top, bottom = Vector(top), Vector(bottom)
    piv = rig.empty(nm, top, parent)
    pts = [top]
    for j in range(1, n):
        u = j / n
        off = jag * (1 if (j + seed) % 2 else -1) * (1.0 - 0.3 * u)
        pts.append(top + (bottom - top) * u + Vector((off, 0, 0)))
    pts.append(bottom)
    for j in range(n):
        rig.add_mesh(R.cone(f"{nm}{j}", pts[j], pts[j + 1], w * (1.0 - 0.12 * j), w * (0.88 - 0.12 * j), seg=6, rings=1),
                     f"{nm}", mats[0], piv, unlit=True, prio=4.5)
        rig.add_mesh(R.ellipsoid(f"{nm}j{j}", pts[j], (w * 1.2,) * 3, seg=8, rings=5), f"{nm}", mats[0], piv, unlit=True,
                     prio=4.5)
    return piv


def show(rig, name, on, k=1.0):
    o = rig.n(name)
    if on:
        s = rig.rest[name][2]
        o.scale = (s[0] * k, s[1] * k, s[2] * k)
    else:
        o.scale = (0.0001, 0.0001, 0.0001)
