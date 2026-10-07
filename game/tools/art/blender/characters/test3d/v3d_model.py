"""TESTE "Viajante 3D" (06/10/2026): o personagem jogavel modelado INTEIRO no Blender, sem base pronta de corpo,
sem gerador de imagem e sem pixel desenhado fora do Blender. Rosto, olhos, boca e sobrancelhas sao GEOMETRIA
(decalques projetados na cabeca por ray cast); cabelo em mechas modeladas.

Reaproveita do pipeline existente: chr_lib (pivos FK, material de passes pid/profundidade/normal, primitivas,
camera e reducao por voto) e, no pos, chr_post (cel shading em rampas, linha interna, contorno colorido).

Convencoes: metros, chao em z = 0, olhando para -Y, lado esquerdo do personagem = +X.
Grupos: "body" (pele, cabeca, rosto), "hair:<estilo>", "outfit:traveler", "outfit:hunter", "weapon:bow",
"mount:donkey".
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import chr_lib as C  # noqa: E402
import mon_rig as MR  # noqa: E402

TAU = math.tau

# --------------------------------------------------------------------------------------------- proporcao
# ~2,7 cabecas (cabeca com cabelo ~37% da altura): chibi Ragnarok/Samsara.
SPEC = {
    "male": dict(hip=0.43, sw=0.122, waist=0.100, chest=0.118, hem=0.132, boot=0.92, hand=1.15, hair="spiky",
                 head=(0.168, 0.156, 0.166), eye_h=0.072, eye_w=0.052, lash=0.013, legs=0.050),
    "female": dict(hip=0.42, sw=0.110, waist=0.090, chest=0.108, hem=0.150, boot=0.86, hand=1.05,
                   hair="ponytail", head=(0.166, 0.154, 0.166), eye_h=0.078, eye_w=0.054, lash=0.016, legs=0.045),
}


def V(*a):
    return Vector(a)


def mirror(p, s):
    return Vector((p[0] * s, p[1], p[2]))


# --------------------------------------------------------------------------------------------- geometria
def deform_head(o, center, radii):
    """Esfera -> cabeca chibi: bochecha cheia, queixo pequeno, nuca recolhida, rosto achatado (olhos de frente)."""
    me = o.data
    cx, cy, cz = center
    rx, ry, rz = radii
    for v in me.vertices:
        x = (v.co.x - cx) / rx; y = (v.co.y - cy) / ry; z = (v.co.z - cz) / rz
        if z < 0:
            t = -z
            x *= 1 - 0.20 * t ** 1.8 - 0.10 * t ** 4
            if y > 0:
                y *= 1 - 0.38 * t ** 1.3
            else:
                y *= 1 - 0.18 * t ** 2
            z *= 1 - 0.06 * t
        if y < 0:
            y *= 0.86 + 0.14 * min(1.0, abs(x) * 1.3)   # rosto plano no meio, bochechas redondas
        v.co = Vector((cx + x * rx, cy + y * ry, cz + z * rz))
    me.update()


def disk(cx, cz, w, h, seg=20, rings=4, squash_top=1.0, tilt=0.0):
    """Malha 2D (x, z) de elipse (verts, faces). squash_top < 1 achata a metade de cima. tilt em rad."""
    verts = [(cx, cz)]
    faces = []
    for r in range(1, rings + 1):
        k = r / rings
        for i in range(seg):
            a = TAU * i / seg
            x = math.cos(a) * w / 2 * k
            z = math.sin(a) * h / 2 * k * (squash_top if math.sin(a) > 0 else 1.0)
            xr = x * math.cos(tilt) - z * math.sin(tilt)
            zr = x * math.sin(tilt) + z * math.cos(tilt)
            verts.append((cx + xr, cz + zr))
    for i in range(seg):
        faces.append((0, 1 + i, 1 + (i + 1) % seg))
    for r in range(1, rings):
        o0 = 1 + (r - 1) * seg; o1 = 1 + r * seg
        for i in range(seg):
            j = (i + 1) % seg
            faces.append((o0 + i, o1 + i, o1 + j, o0 + j))
    return verts, faces


def band(pts_in, pts_out):
    """Faixa 2D entre duas polilinhas de mesmo tamanho."""
    verts = list(pts_in) + list(pts_out)
    n = len(pts_in)
    faces = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    return verts, faces


def arc_band(cx, cz, w, h, a0, a1, thick, seg=10, flick=0.0, tilt=0.0):
    """Faixa em arco sobre a elipse (cilio superior / sobrancelha). Espessura maior no meio-externo."""
    pin, pout = [], []
    for i in range(seg + 1):
        t = i / seg
        a = a0 + (a1 - a0) * t
        x = math.cos(a) * w / 2; z = math.sin(a) * h / 2
        th = thick * (0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.15)))
        if t > 0.85 and flick:
            th += flick * (t - 0.85) / 0.15
        n = Vector((math.cos(a) / (w / 2), math.sin(a) / (h / 2))).normalized()
        p0 = Vector((x, z)) - n * th * 0.35
        p1 = Vector((x, z)) + n * th * 0.65
        for p, lst in ((p0, pin), (p1, pout)):
            xr = p.x * math.cos(tilt) - p.y * math.sin(tilt)
            zr = p.x * math.sin(tilt) + p.y * math.cos(tilt)
            lst.append((cx + xr, cz + zr))
    return band(pin, pout)


def decal(name, target, verts2d, faces, offset):
    """Projeta uma malha 2D (x, z) na superficie da frente de 'target' (raio em +Y), afastada 'offset' pela normal.
    E assim que o rosto e desenhado: tudo e geometria do Blender."""
    vs = []
    for (x, z) in verts2d:
        ok, loc, nrm, _ = target.ray_cast(Vector((x, -2.0, z)), Vector((0, 1, 0)))
        if not ok:
            ok, loc, nrm, _ = target.ray_cast(Vector((x * 0.9, -2.0, z)), Vector((0, 1, 0)))
        vs.append(loc + nrm * offset if ok else Vector((x, -0.1, z)))
    o = MR._obj_from(name, vs, faces, smooth=False)
    # normais para a camera (frente)
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free(); me.update()
    return o


def ring(name, z0, z1, r0, r1, y=0.0, seg=20):
    return C.loft(name, [((0, y, z0), r0[0], r0[1]), ((0, y, z1), r1[0], r1[1])], seg=seg, cap0=False, cap1=False)


def cut_faces(o, fn):
    """Apaga as faces cujo centro satisfaz fn(centro)."""
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    dead = [f for f in bm.faces if fn(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context='FACES')
    bm.to_mesh(me); bm.free(); me.update()


def unit_capsule(name, r):
    """Capsula de (0,0,0) a (0,0,1) para ser esticada por quadro (corda do arco)."""
    return C.capsule(name, (0, 0, 0), (0, 0, 1), r, seg=6, rings=2)


# --------------------------------------------------------------------------------------------- esqueleto
class Body:
    pass


def build(body):
    MR.reset()
    sp = SPEC[body]
    rig = C.Rig(f"v3d_{body}")
    rig.body = body
    rig.sp = sp
    H = sp["hip"]
    J = rig.joint
    hips = J("hips", (0, 0, H), rig.root)
    chest = J("chest", (0, 0, H + 0.10), hips)
    neck = J("neck", (0, 0, H + 0.24), chest)
    head = J("head", (0, 0, H + 0.290), neck)
    sw = sp["sw"]
    for s, nm in ((1, "l"), (-1, "r")):
        sh = J(f"shoulder_{nm}", (s * sw, 0.0, H + 0.213), chest)
        el = J(f"elbow_{nm}", (s * (sw + 0.014), 0.004, H + 0.118), sh)
        J(f"hand_{nm}", (s * (sw + 0.020), -0.002, H + 0.030), el)
        th = J(f"thigh_{nm}", (s * 0.062, 0, H - 0.015), hips)
        kn = J(f"knee_{nm}", (s * 0.064, -0.004, H * 0.52), th)
        an = J(f"ankle_{nm}", (s * 0.066, 0, 0.078), kn)
        rig.anchor(f"heel_{nm}", (s * 0.066, 0.05, 0.0), an)
        rig.anchor(f"toe_{nm}", (s * 0.066, -0.11, 0.004), an)
    rig.anchor("nock", (0, 0, 0), rig.j("hand_r"))
    hc = Vector((0, 0.004, H + 0.290 + 0.150))     # centro do cranio
    rig.hc = hc
    build_skin(rig, hc)
    build_face(rig, hc)
    build_hair(rig, hc, sp["hair"])
    build_traveler(rig)
    build_hunter(rig)
    build_bow(rig)
    rig.j("head").rotation_euler.x = -0.22   # queixo um pouco para cima: rosto de frente na camera a 35 graus
    rig.save_rest()
    return rig


# --------------------------------------------------------------------------------------------- pele e rosto
def build_skin(rig, hc):
    sp = rig.sp
    j = rig.j
    rx, ry, rz = sp["head"]
    hd = C.ellipsoid("head", (0, 0, 0), (1, 1, 1), seg=40, rings=28)
    for v in hd.data.vertices:
        v.co = Vector((v.co.x * rx + hc.x, v.co.y * ry + hc.y, v.co.z * rz + hc.z))
    deform_head(hd, hc, (rx, ry, rz))
    rig.head_obj = hd
    rig.add(hd, "head", "skin", j("head"))
    # orelhas pequenas (quase sempre sob o cabelo)
    for s in (1, -1):
        e = C.ellipsoid(f"ear_{s}", (s * rx * 0.93, 0.01, hc.z - 0.03), (0.022, 0.03, 0.04), seg=10, rings=8)
        rig.add(e, f"ear_{s}", "skin", j("head"))
    H = sp["hip"]
    nk = C.capsule("neck", (0, 0.010, H + 0.21), (0, 0.010, H + 0.31), 0.034)
    rig.add(nk, "neck", "skin", j("neck"))
    # maos grandes (luva sem dedos = pele) + polegar
    k = sp["hand"]
    for s, nm in ((1, "l"), (-1, "r")):
        p = rig.world_loc[f"hand_{nm}"]
        h = C.ellipsoid(f"hand_{nm}", p + V(0, -0.004, -0.030 * k), (0.040 * k, 0.036 * k, 0.046 * k), seg=14, rings=10)
        rig.add(h, f"hand_{nm}", "skin", j(f"hand_{nm}"))
        t = C.ellipsoid(f"thumb_{nm}", p + V(-s * 0.026 * k, -0.026 * k, -0.018 * k), (0.016 * k, 0.016 * k, 0.024 * k),
                        seg=8, rings=6)
        rig.add(t, f"thumb_{nm}", "skin", j(f"hand_{nm}"))


def build_face(rig, hc):
    """Olhos de anime grandes e de frente, sobrancelhas e boca: decalques de geometria na cabeca."""
    sp = rig.sp
    hd = rig.head_obj
    pj = rig.j("head")
    ez = hc.z - 0.036
    ex = 0.064
    w, h = sp["eye_w"], sp["eye_h"]
    female = rig.body == "female"
    for s, nm in ((1, "l"), (-1, "r")):
        cx = s * ex
        # branco do olho (um pouco achatado em cima: o cilio cobre)
        v, f = disk(cx, ez, w, h, seg=22, rings=4)
        rig.add(decal(f"sclera_{nm}", hd, v, f, 0.0030), f"sclera_{nm}", "sclera", pj, noline=True, prio=2.0)
        # iris (dois tons: metade de cima escura) + pupila + brilho
        icx = cx - s * 0.004
        v, f = disk(icx, ez - 0.003, w * 0.74, h * 0.90, seg=22, rings=4)
        rig.add(decal(f"iris_{nm}", hd, v, f, 0.0042), f"iris_{nm}", "iris", pj, noline=True, prio=3.0)
        v, f = disk(icx, ez + 0.012, w * 0.74, h * 0.40, seg=18, rings=3)
        rig.add(decal(f"irisd_{nm}", hd, v, f, 0.0050), f"irisd_{nm}", "iris_dark", pj, noline=True, prio=3.0)
        v, f = disk(icx, ez - 0.002, w * 0.34, h * 0.46, seg=14, rings=2)
        rig.add(decal(f"pupil_{nm}", hd, v, f, 0.0058), f"pupil_{nm}", "pupil", pj, noline=True, prio=3.0)
        v, f = disk(icx + s * 0.010, ez + 0.012, 0.015, 0.017, seg=10, rings=2)
        rig.add(decal(f"shine_{nm}", hd, v, f, 0.0068), f"shine_{nm}", "shine", pj, noline=True, prio=6.0)
        # cilio superior grosso com ponta para fora
        a0, a1 = (math.radians(200), math.radians(-20)) if s < 0 else (math.radians(-20), math.radians(200))
        if s > 0:
            v, f = arc_band(cx, ez + 0.002, w * 1.08, h * 1.02, math.radians(200), math.radians(-25), sp["lash"],
                            seg=14, flick=0.0)
        else:
            v, f = arc_band(cx, ez + 0.002, w * 1.08, h * 1.02, math.radians(-20), math.radians(205), sp["lash"],
                            seg=14, flick=0.0)
        # ponta externa (asa): o lado externo e +X no olho esquerdo
        rig.add(decal(f"lash_{nm}", hd, v, f, 0.0075), f"lash_{nm}", "lash", pj, noline=True, prio=4.0)
        wing = disk(cx + s * (w * 0.52), ez + h * 0.20, 0.020 if female else 0.014, 0.012, seg=10, rings=2,
                    tilt=s * 0.5)
        rig.add(decal(f"wing_{nm}", hd, wing[0], wing[1], 0.0075), f"lash_{nm}", "lash", pj, noline=True)
        # cilio de baixo (fino, so as pontas) no feminino
        if female:
            v, f = arc_band(cx, ez - 0.004, w * 0.96, h * 0.98, math.radians(-150), math.radians(-30), 0.006, seg=8)
            rig.add(decal(f"lashb_{nm}", hd, v, f, 0.0070), f"lashb_{nm}", "lash_low", pj, noline=True, prio=1.5)
        # sobrancelha (cor do cabelo), em parte sob a franja
        if s > 0:
            v, f = arc_band(cx + 0.004, ez + h * 0.80, w * 1.2, 0.03, math.radians(160), math.radians(30), 0.010, seg=8)
        else:
            v, f = arc_band(cx - 0.004, ez + h * 0.80, w * 1.2, 0.03, math.radians(150), math.radians(20), 0.010, seg=8)
        rig.add(decal(f"brow_{nm}", hd, v, f, 0.0040), f"brow_{nm}", "brow", pj, noline=True, prio=2.0)
        # bochecha rosada
        v, f = disk(cx + s * 0.012, ez - h * 0.78, 0.034, 0.016, seg=12, rings=2)
        rig.add(decal(f"blush_{nm}", hd, v, f, 0.0025), f"blush_{nm}", "blush", pj, noline=True, prio=0.6)
    # boca pequena (sorriso leve)
    mz = hc.z - 0.118
    pts_in = [(-0.016 + 0.032 * t / 6, mz + 0.004 * (1 - (2 * t / 6 - 1) ** 2) - 0.002) for t in range(7)]
    pts_out = [(x, z + 0.0075) for x, z in pts_in]
    v, f = band(pts_in, pts_out)
    rig.add(decal("mouth", hd, v, f, 0.0030), "mouth", "mouth", pj, noline=True, prio=3.0)
    # nariz: so um ponto de sombra
    v, f = disk(0.0, hc.z - 0.085, 0.010, 0.008, seg=8, rings=1)
    rig.add(decal("nose", hd, v, f, 0.0022), "nose", "nose", pj, noline=True, prio=0.8)


# --------------------------------------------------------------------------------------------- cabelo
def _lock(rig, grp, name, root, tip, r0, bend=(0, 0, 0), flat=0.5, axis=(1, 0, 0), r1=0.0, mat="hair", clump=None,
          seg=10, rings=7, parent="head", **fl):
    o = C.lock(name, root, tip, r0, bend=bend, seg=seg, rings=rings, flat=flat, twist_axis=axis, r1=r1)
    if clump:
        fl["clump"] = clump
    rig.add(o, name, mat, rig.j(parent), group=grp, **fl)
    return o


def build_hair(rig, hc, style):
    grp = f"hair:{style}"
    rx, ry, rz = rig.sp["head"]
    j = rig.j("head")
    # calota: cobre o cranio inteiro menos a janela do rosto
    cap = C.ellipsoid("hair_cap", (0, 0, 0), (1, 1, 1), seg=36, rings=24)
    for v in cap.data.vertices:
        v.co = Vector((v.co.x * (rx + 0.010), v.co.y * (ry + 0.014) + 0.006, v.co.z * (rz + 0.016))) + hc + V(0, 0, 0.008)
    deform_head(cap, hc + V(0, 0.006, 0.008), (rx + 0.010, ry + 0.014, rz + 0.016))
    cut_faces(cap, lambda c: (c.z < hc.z - 0.12) or (c.y < -0.02 and c.z < hc.z + 0.075)
              or (c.y < 0.035 and c.z < hc.z + 0.01))
    rig.add(cap, "hair_cap", "hair", j, group=grp, clump="cap")
    top = hc.z + rz
    # franja: mechas que nascem no alto da testa e caem para a frente, pontas alternadas
    female = style == "ponytail"
    xs = [-0.125, -0.080, -0.035, 0.012, 0.058, 0.104, 0.140] if not female else \
        [-0.128, -0.084, -0.040, 0.005, 0.050, 0.095, 0.135]
    tips = [0.085, 0.100, 0.075, 0.105, 0.082, 0.098, 0.088]
    for i, x0 in enumerate(xs):
        side = abs(x0) / 0.165
        root = V(x0 * 0.55, -0.045, top - 0.010)
        tz = hc.z + tips[i] - side * 0.05 + (0.012 if female and 2 <= i <= 4 else 0.0)
        tip = V(x0 * 1.06 + (0.012 if x0 > 0 else -0.012) * side, -ry * 0.92 - 0.004 + side * 0.06, tz)
        sweep = -0.02 if female else 0.0
        _lock(rig, grp, f"bang_{i}", root, tip + V(sweep, 0, 0), 0.050 - 0.006 * side,
              bend=(0.0, -0.028 - 0.01 * (1 - side), 0.02), flat=0.40, axis=(1, 0, 0), clump=f"bang{i % 3}")
    # mechas laterais na frente das orelhas
    for s in (1, -1):
        L = 0.17 if female else 0.07
        _lock(rig, grp, f"side_{s}", V(s * (rx - 0.012), 0.0, hc.z + 0.09), V(s * (rx + 0.012), -0.02, hc.z - L),
              0.045, bend=(s * 0.03, -0.02, 0.0), flat=0.45, axis=(0, 1, 0), clump=f"side{s}")
        if female:
          _lock(rig, grp, f"side2_{s}", V(s * (rx - 0.01), 0.03, hc.z + 0.10), V(s * (rx + 0.03), 0.01, hc.z - L * 0.85),
              0.05, bend=(s * 0.04, 0.0, 0.0), flat=0.5, axis=(0, 1, 0), clump=f"side{s}")
    if style == "spiky":
        # mechas deitadas sobre o cranio (telhas), pontas soltas para tras/baixo e um pouco para fora
        spikes = [  # (azimute: 0 = frente, elevacao, comprimento, largura)
            (-0.35, 1.15, 0.13, 0.060), (0.35, 1.15, 0.13, 0.060), (0.0, 1.30, 0.12, 0.060),
            (-1.0, 0.95, 0.12, 0.058), (1.0, 0.95, 0.12, 0.058), (-1.6, 0.80, 0.11, 0.056), (1.6, 0.80, 0.11, 0.056),
            (-2.2, 0.75, 0.13, 0.058), (2.2, 0.75, 0.13, 0.058), (math.pi, 0.85, 0.12, 0.060),
            (-2.7, 0.35, 0.11, 0.056), (2.7, 0.35, 0.11, 0.056), (math.pi, 0.25, 0.10, 0.056),
            (-2.5, 0.05, 0.07, 0.05), (2.5, 0.05, 0.07, 0.05),
        ]
        for i, (az, el, ln, wd) in enumerate(spikes):
            d = V(math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))
            base = hc + V(d.x * (rx + 0.01), d.y * (ry + 0.01), d.z * (rz + 0.01)) + V(0, 0.006, 0.012)
            # tangente "para baixo/para tras" na superficie
            down = V(0, 0.7 if abs(az) < 1.7 else 0.25, -1.0)
            tg = (down - d * down.dot(d)).normalized()
            tip = base + tg * ln * 0.75 + d * 0.026
            side = d.cross(tg).normalized()
            _lock(rig, grp, f"spike_{i}", base - tg * 0.02, tip, wd, bend=tuple(d * 0.03), flat=0.38,
                  axis=tuple(side), clump="cap" if i > 2 else "spt")
    else:
        # feminino: volume liso em cima + rabo de cavalo alto
        for i, az in enumerate((-1.9, -1.2, 1.2, 1.9, 2.6, -2.6, math.pi)):
            d = V(math.sin(az), -math.cos(az), 0.0)
            base = hc + V(d.x * rx * 0.7, d.y * ry * 0.7, rz * 0.65)
            tip = hc + V(d.x * (rx + 0.03), d.y * (ry + 0.03) + 0.01, -0.07)
            _lock(rig, grp, f"back_{i}", base, tip, 0.06, bend=(d.x * 0.04, d.y * 0.04, 0.0), flat=0.5,
                  axis=tuple(V(-d.y, d.x, 0)), clump=f"bk{i % 2}")
        tie = hc + V(0, ry * 0.80, rz * 0.62)
        rig.joint("tail", tuple(tie), rig.j("head"))
        o = C.ellipsoid("hair_tie", tie, (0.034, 0.03, 0.03), seg=12, rings=8)
        rig.add(o, "hair_tie", "tie", j, group=grp)
        tails = [(0.0, 0.0, 0.075), (-0.035, 0.02, 0.06), (0.035, 0.02, 0.06), (0.0, 0.05, 0.055)]
        for i, (dx, dy, r0) in enumerate(tails):
            root = tie + V(dx * 0.5, 0.02, 0.01)
            tip = tie + V(dx * 2.2, 0.16 + dy, -0.30 + abs(dx) * 1.5)
            _lock(rig, grp, f"tail_{i}", root, tip, r0, bend=(dx * 0.6, 0.07, 0.07), flat=0.7, axis=(1, 0, 0),
                  clump=f"tl{i % 2}", rings=9, parent="tail")
        o = C.ellipsoid("tail_puff", tie + V(0, 0.05, 0.03), (0.06, 0.05, 0.05), seg=12, rings=8)
        rig.add(o, "tail_puff", "hair", rig.j("tail"), group=grp, clump="tl0")


# --------------------------------------------------------------------------------------------- roupas
def _legs_and_boots(rig, grp, pants, boot, boot_top, cuff=None):
    sp = rig.sp
    j = rig.j
    for s, nm in ((1, "l"), (-1, "r")):
        th = rig.world_loc[f"thigh_{nm}"]; kn = rig.world_loc[f"knee_{nm}"]; an = rig.world_loc[f"ankle_{nm}"]
        o = C.capsule(f"{grp}_thigh_{nm}", th, kn, sp["legs"] + 0.004, sp["legs"] - 0.002)
        rig.add(o, f"{grp}_thigh_{nm}", pants, j(f"thigh_{nm}"), group=grp)
        o = C.capsule(f"{grp}_calf_{nm}", kn, an + V(0, 0, 0.02), sp["legs"] - 0.003, sp["legs"] - 0.010)
        rig.add(o, f"{grp}_calf_{nm}", pants, j(f"knee_{nm}"), group=grp)
        k = sp["boot"]
        # bota grande e redonda: pe + cano
        o = C.box(f"{grp}_boot_{nm}", an + V(s * 0.004, -0.030 * k, -0.034), (0.100 * k, 0.175 * k, 0.090 * k), bevel=0.42)
        rig.add(o, f"{grp}_boot_{nm}", boot, j(f"ankle_{nm}"), group=grp)
        o = C.capsule(f"{grp}_shaft_{nm}", an + V(0, 0.004, -0.02), an + V(0, 0.004, boot_top), 0.050 * k, 0.052 * k)
        rig.add(o, f"{grp}_shaft_{nm}", boot, j(f"ankle_{nm}"), group=grp)
        o = C.box(f"{grp}_sole_{nm}", an + V(s * 0.004, -0.030 * k, -0.070), (0.104 * k, 0.180 * k, 0.026), bevel=0.5)
        rig.add(o, f"{grp}_sole_{nm}", "sole", j(f"ankle_{nm}"), group=grp)
        if cuff:
            o = ring(f"{grp}_cuff_{nm}", an.z + boot_top - 0.01, an.z + boot_top + 0.022, (0.058 * k, 0.058 * k),
                     (0.066 * k, 0.064 * k))
            for v in o.data.vertices:
                v.co.x += an.x; v.co.y += an.y
            rig.add(o, f"{grp}_cuff_{nm}", cuff, j(f"ankle_{nm}"), group=grp)


def _arms(rig, grp, sleeve, cuff, bracer=None):
    j = rig.j
    for s, nm in ((1, "l"), (-1, "r")):
        sh = rig.world_loc[f"shoulder_{nm}"]; el = rig.world_loc[f"elbow_{nm}"]; hd = rig.world_loc[f"hand_{nm}"]
        o = C.capsule(f"{grp}_uarm_{nm}", sh + V(-s * 0.004, 0, 0.0), el, 0.046, 0.042)
        rig.add(o, f"{grp}_uarm_{nm}", sleeve, j(f"shoulder_{nm}"), group=grp)
        o = C.capsule(f"{grp}_farm_{nm}", el, hd + V(0, 0, 0.012), 0.041, 0.044)
        rig.add(o, f"{grp}_farm_{nm}", sleeve, j(f"elbow_{nm}"), group=grp)
        o = ring(f"{grp}_cuffr_{nm}", hd.z + 0.004, hd.z + 0.030, (0.048, 0.048), (0.045, 0.045))
        for v in o.data.vertices:
            v.co.x += hd.x; v.co.y += hd.y
        rig.add(o, f"{grp}_cuffr_{nm}", cuff, j(f"elbow_{nm}"), group=grp)
        if bracer and nm == "l":
            o = C.capsule(f"{grp}_bracer_{nm}", el + (hd - el) * 0.35, hd + V(0, 0, 0.03), 0.047, 0.049)
            rig.add(o, f"{grp}_bracer_{nm}", bracer, j(f"elbow_{nm}"), group=grp)


def _torso(rig, grp, cloth, hem_flare=1.0, hem_z=None):
    sp = rig.sp
    H = sp["hip"]
    j = rig.j
    hz = hem_z if hem_z is not None else H - 0.085
    hem = sp["hem"] * hem_flare
    lower = C.loft(f"{grp}_skirt", [((0, 0.004, hz), hem, hem * 0.80), ((0, 0.004, (hz + H + 0.04) / 2 - 0.01), sp["hem"] * 0.92, 0.094),
                                    ((0, 0.004, H + 0.04), sp["waist"] + 0.006, 0.084)], seg=24, cap0=False)
    rig.add(lower, f"{grp}_skirt", cloth, j("hips"), group=grp)
    upper = C.loft(f"{grp}_chest", [((0, 0.004, H + 0.02), sp["waist"] + 0.004, 0.082),
                                    ((0, 0.004, H + 0.11), sp["chest"], 0.086),
                                    ((0, 0.006, H + 0.185), sp["chest"] + 0.004, 0.084),
                                    ((0, 0.008, H + 0.228), sp["sw"] - 0.01, 0.070),
                                    ((0, 0.008, H + 0.250), 0.060, 0.050)], seg=24)
    rig.add(upper, f"{grp}_chest", cloth, j("chest"), group=grp)
    # ombros arredondados
    for s, nm in ((1, "l"), (-1, "r")):
        o = C.ellipsoid(f"{grp}_delt_{nm}", rig.world_loc[f"shoulder_{nm}"] + V(-s * 0.012, 0, -0.008), (0.054, 0.056, 0.05),
                        seg=14, rings=10)
        rig.add(o, f"{grp}_delt_{nm}", cloth, j("chest"), group=grp)


def build_traveler(rig):
    """Viajante: tunica azul com capuz caido, cinto com fivela, bolsa de couro a tiracolo, calca, botas grandes."""
    grp = "outfit:traveler"
    sp = rig.sp
    H = sp["hip"]
    j = rig.j
    female = rig.body == "female"
    _torso(rig, grp, "tunic", hem_flare=1.0)
    # barra da tunica (faixa mais clara)
    hz = H - 0.085
    o = ring(f"{grp}_hemband", hz - 0.002, hz + 0.022, (sp["hem"] + 0.004, sp["hem"] * 0.80 + 0.004),
             (sp["hem"] * 0.985 + 0.003, sp["hem"] * 0.79 + 0.003), y=0.004, seg=24)
    rig.add(o, f"{grp}_hemband", "tunic_trim", j("hips"), group=grp)
    # gola + capuz caido nas costas
    o = ring(f"{grp}_collar", H + 0.222, H + 0.250, (0.082, 0.070), (0.064, 0.056), y=0.010)
    rig.add(o, f"{grp}_collar", "tunic_trim", j("chest"), group=grp)
    o = C.ellipsoid(f"{grp}_hood", (0, 0.075, H + 0.225), (0.10, 0.045, 0.062), seg=16, rings=10)
    rig.add(o, f"{grp}_hood", "tunic_dark", j("chest"), group=grp)
    # decote em V (pele) + cordao
    o = C.ellipsoid(f"{grp}_vneck", (0, -0.078, H + 0.218), (0.024, 0.012, 0.030), seg=10, rings=8)
    rig.add(o, f"{grp}_vneck", "tunic_dark", j("chest"), group=grp)
    # cinto + fivela
    o = ring(f"{grp}_belt", H + 0.000, H + 0.034, (sp["waist"] + 0.016, 0.094), (sp["waist"] + 0.014, 0.092), y=0.004)
    rig.add(o, f"{grp}_belt", "belt", j("hips"), group=grp)
    o = C.box(f"{grp}_buckle", (0, -0.094, H + 0.017), (0.036, 0.016, 0.032), bevel=0.3)
    rig.add(o, f"{grp}_buckle", "brass", j("hips"), group=grp, prio=2.0)
    # alca a tiracolo (ombro esquerdo -> quadril direito) + bolsa
    strap = [V(0.085, -0.074, H + 0.215), V(0.03, -0.092, H + 0.16), V(-0.04, -0.098, H + 0.09),
             V(-0.105, -0.075, H + 0.03)]
    o = C.strip(f"{grp}_strap", strap, 0.020, normal=(0, -1, 0), thick=0.006)
    rig.add(o, f"{grp}_strap", "strap", j("chest"), group=grp)
    strapb = [V(0.085, 0.07, H + 0.215), V(0.02, 0.09, H + 0.15), V(-0.05, 0.095, H + 0.08), V(-0.105, 0.07, H + 0.03)]
    o = C.strip(f"{grp}_strapb", strapb, 0.020, normal=(0, 1, 0), thick=0.006)
    rig.add(o, f"{grp}_strapb", "strap", j("chest"), group=grp)
    o = C.box(f"{grp}_bag", (-0.130, -0.012, H - 0.025), (0.055, 0.110, 0.090), bevel=0.35)
    rig.add(o, f"{grp}_bag", "bag", j("hips"), group=grp)
    o = C.box(f"{grp}_flap", (-0.150, -0.012, H - 0.008), (0.022, 0.114, 0.058), bevel=0.4)
    rig.add(o, f"{grp}_flap", "bag_flap", j("hips"), group=grp)
    _arms(rig, grp, "tunic", "tunic_trim")
    _legs_and_boots(rig, grp, "leggings" if female else "pants", "boot", 0.06)


def build_hunter(rig):
    """Roupa de titulo (teste de FORMA): cacador do arco. Tunica verde, colete de couro aberto, capa curta com
    capuz pontudo nas costas, aljava com flechas, bracadeira no braco do arco, botas altas com dobra."""
    grp = "outfit:hunter"
    sp = rig.sp
    H = sp["hip"]
    j = rig.j
    _torso(rig, grp, "forest", hem_flare=1.08, hem_z=H - 0.135)
    # colete aberto na frente
    o = C.loft(f"{grp}_vest", [((0, 0.006, H + 0.01), sp["waist"] + 0.016, 0.094),
                               ((0, 0.006, H + 0.11), sp["chest"] + 0.012, 0.096),
                               ((0, 0.008, H + 0.19), sp["chest"] + 0.012, 0.094)], seg=24, cap0=False, cap1=False,
               arc=(0.55, TAU - 0.55))
    rig.add(o, f"{grp}_vest", "leather", j("chest"), group=grp)
    # cinto largo
    o = ring(f"{grp}_belt", H - 0.006, H + 0.036, (sp["waist"] + 0.024, 0.102), (sp["waist"] + 0.022, 0.100), y=0.004)
    rig.add(o, f"{grp}_belt", "belt", j("hips"), group=grp)
    o = C.box(f"{grp}_buckle", (0, -0.104, H + 0.015), (0.03, 0.014, 0.030), bevel=0.3)
    rig.add(o, f"{grp}_buckle", "brass", j("hips"), group=grp, prio=2.0)
    # capa curta (capelete) em sino sobre os ombros
    cz = H + 0.262
    o = C.loft(f"{grp}_cape", [((0, 0.012, cz), 0.07, 0.062), ((0, 0.016, cz - 0.04), 0.135, 0.105),
                               ((0, 0.020, cz - 0.10), 0.180, 0.135), ((0, 0.026, cz - 0.15), 0.195, 0.150)],
               seg=28, cap0=False, cap1=False)
    rig.add(o, f"{grp}_cape", "cape", j("chest"), group=grp)
    o = ring(f"{grp}_capehem", cz - 0.155, cz - 0.138, (0.197, 0.152), (0.192, 0.148), y=0.026, seg=28)
    rig.add(o, f"{grp}_capehem", "cape_trim", j("chest"), group=grp)
    # capuz pontudo caido nas costas
    o = C.lock(f"{grp}_hood", (0, 0.08, cz + 0.005), (0, 0.20, cz - 0.17), 0.105, bend=(0, 0.04, 0.03), seg=14,
               rings=8, flat=0.55, twist_axis=(1, 0, 0))
    rig.add(o, f"{grp}_hood", "cape", j("chest"), group=grp)
    # broche
    o = C.ellipsoid(f"{grp}_brooch", (0.0, -0.075, cz - 0.02), (0.018, 0.012, 0.018), seg=10, rings=8)
    rig.add(o, f"{grp}_brooch", "brass", j("chest"), group=grp, prio=2.0)
    # aljava nas costas, flechas para cima por cima do ombro direito
    qa, qb = V(0.07, 0.15, H - 0.02), V(-0.07, 0.15, H + 0.25)
    o = C.capsule(f"{grp}_quiver", qa, qb, 0.042, 0.046)
    rig.add(o, f"{grp}_quiver", "leather_dark", j("chest"), group=grp)
    for i, dx in enumerate((-0.02, 0.0, 0.02)):
        base = qb + V(dx, 0.0, 0.0)
        tip = base + (qb - qa).normalized() * 0.08 + V(dx, 0, 0)
        o = C.lock(f"{grp}_fletch_{i}", base, tip, 0.022, flat=0.4, twist_axis=(1, 0, 0))
        rig.add(o, f"{grp}_fletch_{i}", "fletch" if i != 1 else "fletch_red", j("chest"), group=grp)
    _arms(rig, grp, "forest", "forest_trim", bracer="leather")
    _legs_and_boots(rig, grp, "pants_brown", "boot_dark", 0.15, cuff="leather")


def build_bow(rig):
    """Arco (grupo weapon:bow): pivo proprio 'bow' posto na mao esquerda a cada quadro; corda em dois trechos
    esticados por quadro ate o ponto 'nock' (mao direita); flecha idem."""
    grp = "weapon:bow"
    b = rig.joint("bow", (0, 0, 0), rig.root)
    pts = []
    for i in range(9):
        t = -1 + 2 * i / 8
        pts.append(V(0, 0.07 * t * t - 0.02 * (1 - t * t), 0.26 * t))
    for i in range(8):
        r = 0.016 if abs(i - 3.5) < 1.2 else 0.012
        o = C.capsule(f"bow_{i}", pts[i], pts[i + 1], r, r * 0.95, seg=8, rings=2)
        rig.add(o, f"bow_{i}", "wood" if abs(i - 3.5) > 1.2 else "bow_grip", b, group=grp, clump="bow")
    rig.anchor("bow_top", tuple(pts[-1]), b)
    rig.anchor("bow_bot", tuple(pts[0]), b)
    rig.bow_tips = (pts[-1], pts[0])
    st = rig.root
    for nm in ("string_a", "string_b"):
        o = unit_capsule(nm, 0.0045)
        rig.add(o, nm, "string", st, group=grp, prio=5.0, noline=True)
    o = unit_capsule("arrow", 0.0065)
    rig.add(o, "arrow", "arrow", st, group=grp, prio=4.0)
    o = C.lock("arrowhead", (0, 0, 0), (0, 0, 0.05), 0.016, flat=0.4, twist_axis=(1, 0, 0))
    rig.add(o, "arrowhead", "steel", st, group=grp, prio=4.0)
