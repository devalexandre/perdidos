"""Pecas compartilhadas das especies das Ilhas do Sol Nascente feitas no Blender (piloto 07/10/2026):
pond_kappa (kappa), mountain_tengu (corvo/tengu) e paper_lantern (lanterna de papel).
  - olho chibi no desenho do Tatu-Pedra (olho escuro grande, iris embaixo, brilho grande + pequeno), com variantes
    acesas da forma atroz (luz fria com fenda ou brasa);
  - sobrancelha (cone curto, ponta de dentro mais baixa = bravo, mais alta = curioso/preocupado) e bochecha;
  - toro (prato do kappa, aros da lanterna), "capa" de cabelo/penas presa a um elipsoide com borda em zigue-zague;
  - particulas em loop (gotas, penas, brasas, fogos-fatuos) e gotas balisticas (respingo do golpe).
Modelo proprio por script (sem malha de terceiros); proporcoes copiadas do stone_armadillo.py."""
import math
from mathutils import Vector
import mon_rig as R
from venom_common import align, on_ell, blink, show  # noqa: F401  (reexportados para as especies)


# ------------------------------------------------------------------ rosto
def eye(rig, nm, ep, piv, rx, rz, yaw, mode="normal", iris="iris", tilt=0.25):
    """Olho grande no desenho do Tatu (eye 0.11 x 0.145, iris, hl, hl2), escalado por rz.
    mode: normal | glow (iris de brasa do chefe) | cold (forma atroz: luz fria com fenda) | ember (forma atroz: brasa).
    Devolve o pivo do olho (piscar = escala z do pivo)."""
    k = rz / 0.145
    e = rig.empty(f"eye{nm}", ep, piv)
    sx = 1 if nm.endswith("L") else -1
    rig.add_mesh(R.ellipsoid(f"eye{nm}", ep, (rx, 0.05 * k, rz), rot=(tilt, 0, yaw)), f"eye{nm}", "eye", e,
                 noline=True, unlit=True, prio=1.8)
    if mode in ("normal", "glow"):
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.03, -0.045)) * k, (rx * 0.71, 0.026 * k, rz * 0.48),
                                 rot=(tilt, 0, yaw)), f"iris{nm}", "eye_glow" if mode == "glow" else iris, e,
                     noline=True, unlit=True, prio=1.5)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.035 + 0.008 * sx, -0.055, 0.042)) * k, (0.04 * k, 0.02 * k, 0.04 * k)),
                     f"hl{nm}", "white", e, noline=True, unlit=True, prio=7.0)
        rig.add_mesh(R.ellipsoid(f"hl2{nm}", ep + Vector((0.035, -0.055, -0.05)) * k, (0.02 * k, 0.012 * k, 0.02 * k)),
                     f"hl2{nm}", "white", e, noline=True, unlit=True, prio=3.0)
    elif mode == "cold":
        # olho aceso de luz fria, fenda escura e um brilho pequeno (le no escuro)
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.025, -0.02)) * k, (rx * 0.8, 0.026 * k, rz * 0.72),
                                 rot=(tilt, 0, yaw)), f"iris{nm}", "eye_cyan", e, noline=True, unlit=True, prio=1.7)
        rig.add_mesh(R.ellipsoid(f"slit{nm}", ep + Vector((0.004 * sx, -0.05, -0.02)) * k, (0.016 * k, 0.02 * k, rz * 0.6),
                                 rot=(tilt, 0, yaw)), f"slit{nm}", "eye_slit", e, noline=True, unlit=True, prio=4.0)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.04 + 0.008 * sx, -0.06, 0.04)) * k, (0.024 * k, 0.014 * k, 0.024 * k)),
                     f"hl{nm}", "white", e, noline=True, unlit=True, prio=7.0)
    else:  # ember
        rig.add_mesh(R.ellipsoid(f"iris{nm}", ep + Vector((0.0, -0.03, -0.03)) * k, (rx * 0.78, 0.026 * k, rz * 0.56),
                                 rot=(tilt, 0, yaw)), f"iris{nm}", "eye_ember", e, noline=True, unlit=True, prio=1.6)
        rig.add_mesh(R.ellipsoid(f"core{nm}", ep + Vector((0.0, -0.05, -0.035)) * k, (rx * 0.37, 0.02 * k, rz * 0.31),
                                 rot=(tilt, 0, yaw)), f"core{nm}", "ember_core", e, noline=True, unlit=True, prio=3.5)
        rig.add_mesh(R.ellipsoid(f"hl{nm}", ep + Vector((-0.04 + 0.008 * sx, -0.06, 0.03)) * k, (0.026 * k, 0.014 * k, 0.026 * k)),
                     f"hl{nm}", "white", e, noline=True, unlit=True, prio=7.0)
    return e


def brow(rig, nm, ep, piv, k, grump, mat="brow", width=1.0, thick=1.0, lift=0.0, prio=2.2):
    """Sobrancelha sobre o olho ep (desenho do Tatu, escalado por k = rz/0.145). grump > 0 = ponta de dentro mais
    baixa (bravo); grump < 0 = mais alta (curioso/preocupado)."""
    sx = 1 if nm.endswith("L") else -1
    a = ep + Vector((-0.095 * sx * width, -0.03, 0.13 - grump + lift)) * k
    b = ep + Vector((0.08 * sx * width, 0.055, 0.16 + lift)) * k
    return rig.add_mesh(R.cone(f"brow{nm}", a, b, 0.024 * k * thick, 0.02 * k * thick, seg=8, rings=1), f"brow{nm}", mat,
                        piv, noline=True, unlit=True, prio=prio)


def cheek(rig, nm, p, piv, k=1.0, yaw=0.0, mat="blush"):
    return rig.add_mesh(R.ellipsoid(f"cheek{nm}", p, (0.05 * k, 0.02 * k, 0.03 * k), rot=(0, 0, yaw)), f"cheek{nm}", mat,
                        piv, noline=True, unlit=True, prio=1.2)


# ------------------------------------------------------------------ formas
def torus(name, center, rmaj, rmin, rot=(0, 0, 0), nu=20, nv=8, squash=1.0, yscale=1.0):
    """Toro deitado (eixo z) em center; squash achata o tubo na vertical; yscale = aro eliptico (cinto)."""
    from mathutils import Euler
    c = Vector(center)
    M = Euler(rot).to_matrix()

    def fn(u, v):
        a = math.tau * u; b = math.tau * v
        p = Vector(((rmaj + rmin * math.cos(b)) * math.cos(a), (rmaj * yscale + rmin * math.cos(b)) * math.sin(a),
                    rmin * math.sin(b) * squash))
        return c + M @ p
    o = R.surface(name, fn, nu, nv, c, closed_u=True)
    # normais para fora do tubo (o _fix_normals do centro do toro erra por dentro)
    import bmesh
    me = o.data; bm = bmesh.new(); bm.from_mesh(me)
    for f in bm.faces:
        q = M.inverted() @ (f.calc_center_median() - c)
        a = math.atan2(q.y / yscale, q.x)
        ring = Vector((rmaj * math.cos(a), rmaj * yscale * math.sin(a), 0))
        if f.normal.dot(M @ (q - ring)) < 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free(); me.update()
    return o


def cap(name, C, radii, th0, edge, lift=1.04, nu=40, nv=6, phase=0.0):
    """Capa sobre o elipsoide (cabelo, penas, gorro): do angulo polar th0 (a partir do topo) ate edge(phi) (phi = 0 em
    +X, -pi/2 = frente -Y). Borda em zigue-zague = edge com termo dente."""
    C = Vector(C)

    def fn(u, v):
        ph = math.tau * u + phase
        th = th0 + (edge(ph) - th0) * v
        k = lift * (1.0 + 0.03 * math.sin(math.pi * v))
        return C + Vector((radii[0] * math.sin(th) * math.cos(ph), radii[1] * math.sin(th) * math.sin(ph),
                           radii[2] * math.cos(th))) * k
    return R.surface(name, fn, nu, nv, C, closed_u=True)


def zigzag(ph, n, amp):
    """Dente triangular: n pontas por volta, amplitude amp (rad)."""
    u = (ph * n / math.tau) % 1.0
    return amp * (1.0 - abs(2.0 * u - 1.0))


def front_off(ph):
    """Distancia angular (0..pi) do azimute ph ate a frente (-Y)."""
    return abs(math.atan2(math.sin(ph + math.pi / 2), math.cos(ph + math.pi / 2)))


def bob(ph, front, back, open_=0.75, ramp=0.6):
    """Borda de franja 'chanel': front (franja alta) ate open_ rad da frente, depois desce suave ate back."""
    d = front_off(ph)
    u = min(1.0, max(0.0, (d - open_) / ramp))
    return front + (back - front) * R.ease(u)


def front_w(ph, width=0.9):
    """1 na frente (-Y), 0 atras: peso suave para abrir a franja no rosto."""
    d = math.atan2(math.sin(ph + math.pi / 2), math.cos(ph + math.pi / 2))  # 0 = frente
    return max(0.0, math.cos(min(math.pi, abs(d) / width * (math.pi / 2))))


# ------------------------------------------------------------------ particulas
def add_motes(rig, nm, spots, mats, size=0.03, parent=None, prio=4.0):
    """Particulas em loop: spots [(x, y, z)], mats alternados. Guarda em rig.motes[nm]."""
    ep = rig.empty(f"{nm}_grp", (0, 0, 0), parent or rig.root)
    lst = []
    for j, p in enumerate(spots):
        p = Vector(p)
        e = rig.empty(f"{nm}{j}", p, ep)
        m = mats[j % len(mats)]
        s = size * (1.0 if j % 3 else 1.25)
        rig.add_mesh(R.ellipsoid(f"{nm}m{j}", p, (s, s, s * 1.35), seg=8, rings=5), f"{nm}_{m}", m, e, unlit=True,
                     noline=True, prio=prio)
        lst.append((f"{nm}{j}", (j * 0.37) % 1.0))
    if not hasattr(rig, "motes"):
        rig.motes = {}
    rig.motes[nm] = lst
    return ep


def motes(rig, nm, t, rise=0.4, spread=1.0, fade=1.0, drift=0.05, orbit=0.0, orbit_r=0.0):
    """t em ciclos (loop). Sobe e encolhe; orbit != 0 gira em volta do eixo z (fogos-fatuos)."""
    for j, (node, ph) in enumerate(rig.motes.get(nm, [])):
        u = (t + ph) % 1.0
        o = rig.n(node)
        base = rig.rest[node][0]
        if orbit:
            a = math.atan2(base.y, base.x) + math.tau * orbit * t
            r = Vector((base.x, base.y, 0)).length + orbit_r
            o.location = Vector((r * math.cos(a), r * math.sin(a), base.z + rise * math.sin(math.tau * (t + ph))))
            s = fade
        else:
            o.location = base + Vector((drift * spread * math.sin(math.tau * u + ph * 7), 0.02 * spread, rise * u))
            s = max(0.0001, (1 - u) ** 0.7 * fade)
        s = max(0.0001, s)
        o.scale = (s, s, s)


def hide_motes(rig, nm):
    for node, ph in rig.motes.get(nm, []):
        rig.n(node).scale = (0.0001, 0.0001, 0.0001)


def splash(rig, nm, u, origin, vel, g=2.2, shrink=0.6, floor=0.2):
    """Gotas balisticas: u = tempo (0 = saindo de origin); vel[j] = velocidade inicial de cada gota (m/u).
    O grupo das gotas deve estar na origem do modelo (add_motes com parent = root)."""
    for j, (node, ph) in enumerate(rig.motes.get(nm, [])):
        o = rig.n(node)
        if u <= 0:
            o.scale = (0.0001, 0.0001, 0.0001)
            continue
        v = Vector(vel[j % len(vel)])
        p = Vector(origin) + v * u + Vector((0, 0, -0.5 * g * u * u))
        if p.z < floor:
            # a gota "some" ao cair (nao desce abaixo dos pes na tela: o post.py ergueria o quadro inteiro)
            o.scale = (0.0001, 0.0001, 0.0001)
            continue
        o.location = p
        s = max(0.0001, 1.0 - shrink * u)
        o.scale = (s, s, s)


def ysurf(C, Rr, x, z):
    """y da superficie do elipsoide (C, Rr) no ponto (x, z), lado da frente (-Y)."""
    q = 1 - ((x - C.x) / Rr[0]) ** 2 - ((z - C.z) / Rr[2]) ** 2
    return C.y - Rr[1] * math.sqrt(max(0.0, q))
