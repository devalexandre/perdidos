"""Biblioteca do lado do Blender do pipeline de PERSONAGENS (docs/arte-personagens-blender.md).

Mesma ideia do pipeline de monstros do B3 (game/tools/art/blender/monsters/mon_rig.py, reaproveitado aqui:
reset, camera, reducao por voto da maioria, primitivas): o Blender nao faz a cor final. Cada peca tem um id
(pid) e todas usam o material "PASS" que emite R = pid + profundidade, G/B = normal na camera. O tom (cel
shading com rampas), os contornos, as mascaras de personalizacao e as camadas saem do chr_post.py.

Diferencas para os monstros:
  * pid por FACE (atributo "fpid" da malha) alem do pid do objeto: detalhes (bordados, costuras, faixas) sao
    faces pintadas na propria malha, sem geometria extra;
  * esqueleto humano de pivos (empties) compartilhado por masculino e feminino (mesmos nomes e hierarquia);
  * variantes: cada objeto pertence a um GRUPO ("body", "outfit:<id>", "hair:<id>", "head:<id>",
    "weapon:<id>", "ear:<id>"); o render liga so os grupos de cada conjunto (ver render_chr.py);
  * ancoras 2D por quadro (olhos, boca, maos, cabeca) projetadas pela camera, para a camada de olhos.

Convencoes: metros, chao em z = 0, personagem olhando para -Y (camera no S). Lado esquerdo do personagem = +X.
"""
import bpy, bmesh, math, os, sys, json, time
import numpy as np
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "monsters"))
import mon_rig as MR  # noqa: E402  (pipeline do B3: reset, camera, reducao, primitivas)

TAU = math.tau
MAX_PIDS = 4000   # ids em uint16 (o R float32 ainda separa pid e profundidade com folga)
DEPTH_NEAR = MR.DEPTH_NEAR
DEPTH_RANGE = MR.DEPTH_RANGE
# Linhas da folha (GDD 17.3) + as 3 espelhadas (opcionais, para quando o motor usar 8 linhas reais).
DIRS5 = [("S", 0.0), ("SE", 45.0), ("E", 90.0), ("NE", 135.0), ("N", 180.0)]
DIRS_EXTRA = [("NW", 225.0), ("W", 270.0), ("SW", 315.0)]


# ------------------------------------------------------------------ material de passes
def pass_material():
    """Como mon_rig.pass_material, mas pid = atributo de face 'fpid' (se > 0) senao o pid do objeto."""
    m = bpy.data.materials.get("CPASS")
    if m:
        return m
    m = bpy.data.materials.new("CPASS")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    out = N('ShaderNodeOutputMaterial')
    em = N('ShaderNodeEmission')
    geo = N('ShaderNodeNewGeometry')
    ao = N('ShaderNodeAttribute'); ao.attribute_type = 'OBJECT'; ao.attribute_name = 'pid'
    af = N('ShaderNodeAttribute'); af.attribute_type = 'GEOMETRY'; af.attribute_name = 'fpid'
    gt = N('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.5
    sub = N('ShaderNodeMath'); sub.operation = 'SUBTRACT'
    mul = N('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    addp = N('ShaderNodeMath'); addp.operation = 'ADD'
    L(af.outputs['Fac'], gt.inputs[0])
    L(af.outputs['Fac'], sub.inputs[0]); L(ao.outputs['Fac'], sub.inputs[1])
    L(gt.outputs[0], mul.inputs[0]); L(sub.outputs[0], mul.inputs[1])
    L(ao.outputs['Fac'], addp.inputs[0]); L(mul.outputs[0], addp.inputs[1])
    vn = N('ShaderNodeVectorTransform'); vn.vector_type = 'NORMAL'; vn.convert_from = 'WORLD'; vn.convert_to = 'CAMERA'
    vp = N('ShaderNodeVectorTransform'); vp.vector_type = 'POINT'; vp.convert_from = 'WORLD'; vp.convert_to = 'CAMERA'
    sn = N('ShaderNodeSeparateXYZ'); sp = N('ShaderNodeSeparateXYZ')
    d0 = N('ShaderNodeMath'); d0.operation = 'SUBTRACT'; d0.inputs[1].default_value = DEPTH_NEAR - DEPTH_RANGE
    d1 = N('ShaderNodeMath'); d1.operation = 'DIVIDE'; d1.inputs[1].default_value = 2 * DEPTH_RANGE
    d2 = N('ShaderNodeClamp'); d2.inputs['Max'].default_value = 1.0
    d3 = N('ShaderNodeMath'); d3.operation = 'MULTIPLY'; d3.inputs[1].default_value = 0.998
    add = N('ShaderNodeMath'); add.operation = 'ADD'
    comb = N('ShaderNodeCombineXYZ')
    bf = N('ShaderNodeMath'); bf.operation = 'MULTIPLY_ADD'; bf.inputs[1].default_value = -2.0; bf.inputs[2].default_value = 1.0
    sc_ = N('ShaderNodeVectorMath'); sc_.operation = 'SCALE'
    L(geo.outputs['Backfacing'], bf.inputs[0]); L(geo.outputs['Normal'], sc_.inputs[0]); L(bf.outputs[0], sc_.inputs['Scale'])
    L(sc_.outputs[0], vn.inputs[0]); L(vn.outputs[0], sn.inputs[0])
    L(geo.outputs['Position'], vp.inputs[0]); L(vp.outputs[0], sp.inputs[0])
    L(sp.outputs['Z'], d0.inputs[0]); L(d0.outputs[0], d1.inputs[0]); L(d1.outputs[0], d2.inputs['Value'])
    L(d2.outputs[0], d3.inputs[0]); L(d3.outputs[0], add.inputs[1]); L(addp.outputs[0], add.inputs[0])
    L(add.outputs[0], comb.inputs['X']); L(sn.outputs['X'], comb.inputs['Y']); L(sn.outputs['Y'], comb.inputs['Z'])
    L(comb.outputs[0], em.inputs['Color']); em.inputs['Strength'].default_value = 1.0
    L(em.outputs[0], out.inputs['Surface'])
    return m


# ------------------------------------------------------------------ esqueleto + pecas
class Rig:
    """Esqueleto de pivos (empties, FK) + registro de pecas (pid -> material/flags/grupo)."""

    def __init__(self, name):
        self.name = name
        self.parts = {}
        self.part_info = [None]
        self.nodes = {}
        self.joints = {}
        self.world_loc = {}
        self.rest = {}
        self.meshes = []
        self.groups = {}       # grupo -> [objetos]
        self.anchors = {}      # nome -> empty (pontos projetados por quadro)
        self.turn = self.joint("turn", (0, 0, 0))
        self.root = self.joint("root", (0, 0, 0), self.turn)

    def pid(self, part, mat, group, **flags):
        if part not in self.parts:
            self.parts[part] = len(self.part_info)
            self.part_info.append(dict(name=part, mat=mat, group=group, **flags))
            assert len(self.part_info) < MAX_PIDS, "pids demais"
        return self.parts[part]

    def joint(self, name, loc, parent=None):
        o = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(o)
        o.empty_display_size = 0.04
        base = Vector((0, 0, 0))
        if parent is not None:
            o.parent = parent
            base = self.world_loc.get(parent.name, Vector((0, 0, 0)))
        self.world_loc[name] = Vector(loc)
        o.location = Vector(loc) - base
        o.rotation_mode = 'XYZ'
        self.nodes[name] = o
        self.joints[name] = o
        return o

    def anchor(self, name, loc, parent):
        """Ponto que sera projetado em 2D a cada quadro (olhos, boca...)."""
        o = self.joint(name, loc, parent)
        self.anchors[name] = o
        return o

    def add(self, obj, part, mat, parent, group="body", **flags):
        """Registra uma malha (em coordenadas do MODELO) presa ao pivo parent."""
        obj["pid"] = float(self.pid(part, mat, group, **flags))
        warp = getattr(self, "warp", None)
        if warp is not None:          # base pronta: leva a peca do espaco do modelo procedural para o corpo importado
            warp(obj, parent.name)
        obj.data.materials.clear()
        obj.data.materials.append(pass_material())
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Translation(-self.world_loc.get(parent.name, Vector((0, 0, 0))))
        self.meshes.append(obj)
        self.nodes[obj.name] = obj
        self.groups.setdefault(group, []).append(obj)
        obj["group"] = group
        return obj

    def face_parts(self, obj, fn, group=None):
        """Pinta pids por face: fn(centro, normal) -> (part, mat, flags) ou None (fica o pid do objeto).
        Coordenadas do modelo (repouso)."""
        me = obj.data
        grp = group or obj.get("group", "body")
        attr = me.attributes.get("fpid") or me.attributes.new("fpid", 'FLOAT', 'FACE')
        vals = [0.0] * len(me.polygons)
        for p in me.polygons:
            r = fn(Vector(p.center), Vector(p.normal))
            if r:
                part, mat, flags = r
                vals[p.index] = float(self.pid(part, mat, grp, **flags))
        attr.data.foreach_set("value", vals)
        me.update()

    def save_rest(self):
        for k, o in self.nodes.items():
            self.rest[k] = (o.location.copy(), o.rotation_euler.copy(), o.scale.copy())

    def reset_pose(self):
        for k, (l, r, s) in self.rest.items():
            o = self.nodes[k]
            o.location = l; o.rotation_euler = r; o.scale = s

    def j(self, name):
        return self.joints[name]

    def show_groups(self, groups):
        on = set(groups)
        for g, objs in self.groups.items():
            vis = g in on
            for o in objs:
                o.hide_render = not vis
                o.hide_viewport = not vis


# ------------------------------------------------------------------ geometria
def _obj(name, verts, faces, smooth=True):
    return MR._obj_from(name, verts, faces, smooth)


def _outward(o, axis_pts):
    """Vira as faces para fora do eixo (polilinha axis_pts): funciona para tubos/loft."""
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    pts = [Vector(p) for p in axis_pts]
    for f in bm.faces:
        c = f.calc_center_median()
        best, bp = 1e9, pts[0]
        for a, b in zip(pts, pts[1:]):
            ab = b - a
            t = max(0.0, min(1.0, (c - a).dot(ab) / max(ab.length_squared, 1e-9)))
            q = a + ab * t
            d = (c - q).length
            if d < best:
                best, bp = d, q
        if f.normal.dot(c - bp) < 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free(); me.update()


def loft(name, sections, seg=16, cap0=True, cap1=True, arc=None):
    """Superficie por secoes elipticas. sections: [(centro (x,y,z), rx, ry), ...] (plano horizontal) ou
    [(centro, rx, ry, eixo_up)] para secoes inclinadas. arc=(a0, a1) em radianos (0 = +X, pi/2 = -Y frente
    do personagem... usamos angulo medido de -Y: 0 = frente) para superficies abertas (saias, casacos)."""
    verts, faces = [], []
    closed = arc is None
    n = seg if closed else seg + 1
    for sec in sections:
        c = Vector(sec[0]); rx, ry = sec[1], sec[2]
        up = Vector(sec[3]).normalized() if len(sec) > 3 else Vector((0, 0, 1))
        ex = Vector((1, 0, 0)); ex = (ex - up * ex.dot(up)).normalized()
        ey = up.cross(ex)  # aponta para -Y quando up = z?  (z x x = y) -> +Y; frente = -ey
        for i in range(n):
            if closed:
                t = TAU * i / seg
            else:
                t = arc[0] + (arc[1] - arc[0]) * i / seg
            # t medido a partir da frente (-Y), girando para o lado esquerdo do personagem (+X)
            verts.append(c + ex * (math.sin(t) * rx) - ey * (math.cos(t) * ry))
    rows = len(sections)
    for j in range(rows - 1):
        for i in range(seg):
            a = j * n + i; b = j * n + (i + 1) % n if closed else j * n + i + 1
            faces.append((a, b, b + n, a + n))
    axis = [Vector(s[0]) for s in sections]
    if closed and cap0:
        verts.append(axis[0]); ci = len(verts) - 1
        for i in range(seg):
            faces.append((ci, (i + 1) % n, i))
    if closed and cap1:
        verts.append(axis[-1]); ci = len(verts) - 1
        o = (rows - 1) * n
        for i in range(seg):
            faces.append((ci, o + i, o + (i + 1) % n))
    ob = _obj(name, verts, faces)
    _outward(ob, axis if len(axis) > 1 else [axis[0], axis[0] + Vector((0, 0, 0.01))])
    return ob


def capsule(name, a, b, ra, rb=None, seg=14, rings=6, squash=(1.0, 1.0)):
    """Tubo afunilado de a ate b com pontas arredondadas (juntas sem buraco). squash = (lado, frente)."""
    rb = ra if rb is None else rb
    a, b = Vector(a), Vector(b)
    ax = (b - a)
    L = ax.length
    d = ax.normalized()
    # base ortonormal: e1 ~ X do mundo (lado), e2 ~ frente
    e1 = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    e1 = (e1 - d * e1.dot(d)).normalized(); e2 = d.cross(e1)
    prof = []  # (t ao longo do eixo em metros, raio)
    for k in range(rings + 1):  # calota de baixo (em a)
        th = (math.pi / 2) * (1 - k / rings)
        prof.append((-ra * math.sin(th) * 0.9, ra * math.cos(th)))
    for k in range(1, 4):
        s = k / 4
        prof.append((L * s, ra + (rb - ra) * s))
    for k in range(rings + 1):
        th = (math.pi / 2) * k / rings
        prof.append((L + rb * math.sin(th) * 0.9, rb * math.cos(th)))
    verts, faces = [], []
    for (t, r) in prof:
        c = a + d * t
        for i in range(seg):
            ang = TAU * i / seg
            verts.append(c + e1 * (math.cos(ang) * r * squash[0]) + e2 * (math.sin(ang) * r * squash[1]))
    R = len(prof)
    for j in range(R - 1):
        for i in range(seg):
            p = j * seg + i; q = j * seg + (i + 1) % seg
            faces.append((p, q, q + seg, p + seg))
    ob = _obj(name, verts, faces)
    _outward(ob, [a - d * ra, b + d * rb])
    return ob


def ellipsoid(name, center, radii, seg=18, rings=12, rot=(0, 0, 0)):
    return MR.ellipsoid(name, center, radii, seg, rings, rot)


def box(name, center, size, rot=(0, 0, 0), bevel=0.3):
    """Caixa arredondada (superelipsoide) centrada, tamanho total size."""
    c = Vector(center)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    seg, rings = 16, 10
    e = max(0.08, bevel)
    verts, faces = [], []
    R = Euler(rot).to_matrix()

    def sp(x, p):
        return math.copysign(abs(x) ** p, x)
    for j in range(1, rings):
        th = math.pi * j / rings
        for i in range(seg):
            ph = TAU * i / seg
            x = sp(math.sin(th), e) * sp(math.cos(ph), e)
            y = sp(math.sin(th), e) * sp(math.sin(ph), e)
            z = sp(math.cos(th), e)
            verts.append(c + R @ Vector((x * sx, y * sy, z * sz)))
    top = len(verts); verts.append(c + R @ Vector((0, 0, sz)))
    bot = len(verts); verts.append(c + R @ Vector((0, 0, -sz)))
    for j in range(rings - 2):
        for i in range(seg):
            a = j * seg + i; b = j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    for i in range(seg):
        faces.append((top, (i + 1) % seg, i))
        base = (rings - 2) * seg
        faces.append((bot, base + i, base + (i + 1) % seg))
    o = _obj(name, verts, faces)
    MR._fix_normals(o, c)
    return o


def strip(name, pts, width, normal=(0, -1, 0), thick=0.006):
    """Fita (alca, faixa, borda) ao longo de pts, com largura e espessura pequenas; normais para o lado de
    'normal'. Vira uma caixa fina (le dos dois lados)."""
    pts = [Vector(p) for p in pts]
    nrm = Vector(normal).normalized()
    verts, faces = [], []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(nrm).normalized() * (width / 2)
        off = nrm * thick
        verts += [p - side + off, p + side + off, p + side - off, p - side - off]
    n = len(pts)
    for i in range(n - 1):
        a = i * 4; b = (i + 1) * 4
        for k in range(4):
            faces.append((a + k, a + (k + 1) % 4, b + (k + 1) % 4, b + k))
    faces.append((0, 3, 2, 1)); o4 = (n - 1) * 4; faces.append((o4, o4 + 1, o4 + 2, o4 + 3))
    o = _obj(name, verts, faces, smooth=False)
    _outward(o, pts)
    return o


def lock(name, root, tip, r0, bend=(0, 0, 0), seg=8, rings=6, flat=1.0, twist_axis=None, r1=0.0):
    """Mecha de cabelo: cone curvo e achatado (flat < 1 achata na direcao 'twist_axis' ou frente)."""
    root, tip, bend = Vector(root), Vector(tip), Vector(bend)
    axis = tip - root
    d = axis.normalized()
    t1 = Vector(twist_axis) if twist_axis else d.orthogonal()
    t1 = (t1 - d * t1.dot(d)).normalized(); t2 = d.cross(t1)
    verts, faces = [], []
    for j in range(rings + 1):
        s = j / rings
        p = root + axis * s + bend * (4 * s * (1 - s))
        r = r0 * (1 - s) ** 0.85 + r1 * s
        for i in range(seg):
            a = TAU * i / seg
            verts.append(p + t1 * (math.cos(a) * r) + t2 * (math.sin(a) * r * flat))
    for j in range(rings):
        for i in range(seg):
            a = j * seg + i; b = j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    verts.append(root); ri = len(verts) - 1
    for i in range(seg):
        faces.append((ri, (i + 1) % seg, i))
    o = _obj(name, verts, faces)
    mid = root + axis * 0.5 + bend
    _outward(o, [root, mid, tip])
    return o


def join(objs, name):
    """Junta varias malhas numa so (mantem o atributo fpid)."""
    ctx = bpy.context
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    ctx.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = ctx.view_layer.objects.active
    o.name = name
    return o


# ------------------------------------------------------------------ camera, render, ancoras
def setup_camera(pitch_deg, canvas_px, ss, ppm, origin_frac):
    return MR.setup_camera(pitch_deg, canvas_px, ss, ppm=ppm, origin_frac=origin_frac)


def project(cam, co, canvas_px):
    from bpy_extras.object_utils import world_to_camera_view
    v = world_to_camera_view(bpy.context.scene, cam, co)
    return (float(v.x * canvas_px), float((1.0 - v.y) * canvas_px), float(v.z))


def frame_anchors(rig, cam, canvas_px):
    """{nome: [x, y, prof, fx, fy, fz]} — posicao em px do canvas + direcao 'frente' do pivo na camera
    (fz < 0 = virado para a camera)."""
    bpy.context.view_layer.update()
    out = {}
    cm = cam.matrix_world.to_3x3().inverted()
    for k, o in rig.anchors.items():
        mw = o.matrix_world
        x, y, z = project(cam, mw.translation, canvas_px)
        fwd = (mw.to_3x3() @ Vector((0, -1, 0))).normalized()
        fc = cm @ fwd
        out[k] = [round(x, 3), round(y, 3), round(z, 4), round(fc.x, 4), round(fc.y, 4), round(fc.z, 4)]
    return out


def reduce_frame(exr_path, ss, prio):
    """Como mon_rig.reduce_frame (voto da maioria ponderado por prioridade), mas com ids uint16."""
    im = bpy.data.images.load(exr_path, check_existing=False)
    W, H = im.size
    a = np.empty(W * H * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    a = a.reshape(H, W, 4)[::-1]
    alpha = a[..., 3] > 0.5
    r = a[..., 0]
    pid = np.where(alpha, np.floor(r + 1e-5), 0).astype(np.int32)
    depth = np.where(alpha, r - pid, 1.0)
    h, w = H // ss, W // ss

    def blocks(x):
        return x.reshape(h, ss, w, ss).transpose(0, 2, 1, 3).reshape(h, w, ss * ss)
    P = blocks(pid); D = blocks(depth); NX = blocks(a[..., 1]); NY = blocks(a[..., 2])
    best = np.zeros((h, w), np.int32); bestc = np.full((h, w), -1.0)
    for i in np.unique(P):
        c = (P == i).sum(-1) * (1.0 if i == 0 else prio[i])
        m = c > bestc
        best[m] = i; bestc[m] = c[m]
    sel = P == best[..., None]
    cnt = np.maximum(sel.sum(-1), 1)
    nx = (NX * sel).sum(-1) / cnt; ny = (NY * sel).sum(-1) / cnt
    dmin = np.where(sel, D, 9.0).min(-1)
    dmin[best == 0] = 1.0
    return best.astype(np.uint16), dmin.astype(np.float32), nx.astype(np.float16), ny.astype(np.float16)
