"""Biblioteca do lado do Blender para o pipeline de monstros (docs/arte-monstros-blender.md).

Ideia: o Blender NAO faz a cor final. Cada peca (objeto) do modelo tem um id (custom prop "pid") e
todas usam o mesmo material "PASS", que emite (Cycles, 1 amostra, sem filtro):
    R = pid + profundidade normalizada (0..0.998)     G = normal.x (camera)     B = normal.y (camera)
Assim uma unica renderizacao por quadro da o mapa de pecas, a profundidade e as normais. A reducao para
o tamanho final (supersample -> voto da maioria com prioridade por peca) e feita aqui com numpy; o
tom (cel shading com rampas da paleta mestra), os contornos e a montagem das folhas ficam em post.py.

Convencoes do modelo: metros do jogo (48 px = 1 m), chao em z = 0, criatura olhando para -Y (camera).
Hierarquia: "turn" (giro da direcao) > "root" (pulo, inclinacao, squash & stretch com pivo nos pes)
> grupos (corpo, cabeca, pernas...). As especies definem build(stage) e pose(rig, anim, i, n).
"""
import bpy, bmesh, math, os, json, time
import numpy as np
from mathutils import Vector, Matrix, Euler

TAU = math.tau
# Ordem das linhas na folha (GDD 17.3): S, SE, E, NE, N. Angulo = giro do modelo (0 = de frente).
DIRS = [("S", 0.0), ("SE", 45.0), ("E", 90.0), ("NE", 135.0), ("N", 180.0)]
DEPTH_NEAR = 30.0   # distancia camera -> alvo (orto); profundidade normalizada em [D-R, D+R]
DEPTH_RANGE = 12.0


# ------------------------------------------------------------------ cena
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 1
    sc.cycles.use_denoising = False
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.filter_width = 0.01
    sc.cycles.max_bounces = 0
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'OPEN_EXR'
    sc.render.image_settings.color_depth = '32'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.use_persistent_data = True
    w = bpy.data.worlds.new("w")
    sc.world = w
    return sc


def pass_material(pid=None):
    """Material de passes. pid=None: le o id da peca do objeto (custom prop "pid"); pid=n: id fixo (modelos
    importados com varios materiais por malha, pack_model.py)."""
    key = "PASS" if pid is None else f"PASS_{pid}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    out = N('ShaderNodeOutputMaterial')
    em = N('ShaderNodeEmission')
    geo = N('ShaderNodeNewGeometry')
    if pid is None:
        attr = N('ShaderNodeAttribute'); attr.attribute_type = 'OBJECT'; attr.attribute_name = 'pid'
        pid_out = attr.outputs['Fac']
    else:
        attr = N('ShaderNodeValue'); attr.outputs[0].default_value = float(pid)
        pid_out = attr.outputs[0]
    vn = N('ShaderNodeVectorTransform'); vn.vector_type = 'NORMAL'; vn.convert_from = 'WORLD'; vn.convert_to = 'CAMERA'
    vp = N('ShaderNodeVectorTransform'); vp.vector_type = 'POINT'; vp.convert_from = 'WORLD'; vp.convert_to = 'CAMERA'
    sn = N('ShaderNodeSeparateXYZ'); sp = N('ShaderNodeSeparateXYZ')
    d0 = N('ShaderNodeMath'); d0.operation = 'SUBTRACT'; d0.inputs[1].default_value = DEPTH_NEAR - DEPTH_RANGE
    d1 = N('ShaderNodeMath'); d1.operation = 'DIVIDE'; d1.inputs[1].default_value = 2 * DEPTH_RANGE
    d2 = N('ShaderNodeClamp'); d2.inputs['Max'].default_value = 1.0
    d3 = N('ShaderNodeMath'); d3.operation = 'MULTIPLY'; d3.inputs[1].default_value = 0.998
    add = N('ShaderNodeMath'); add.operation = 'ADD'
    comb = N('ShaderNodeCombineXYZ')
    L = nt.links.new
    # superficie aberta vista por dentro (fitas do redemoinho, asas): vira a normal para a camera
    bf = N('ShaderNodeMath'); bf.operation = 'MULTIPLY_ADD'; bf.inputs[1].default_value = -2.0; bf.inputs[2].default_value = 1.0
    sc_ = N('ShaderNodeVectorMath'); sc_.operation = 'SCALE'
    L(geo.outputs['Backfacing'], bf.inputs[0]); L(geo.outputs['Normal'], sc_.inputs[0]); L(bf.outputs[0], sc_.inputs['Scale'])
    L(sc_.outputs[0], vn.inputs[0]); L(vn.outputs[0], sn.inputs[0])
    L(geo.outputs['Position'], vp.inputs[0]); L(vp.outputs[0], sp.inputs[0])
    L(sp.outputs['Z'], d0.inputs[0]); L(d0.outputs[0], d1.inputs[0]); L(d1.outputs[0], d2.inputs['Value'])
    L(d2.outputs[0], d3.inputs[0]); L(d3.outputs[0], add.inputs[1]); L(pid_out, add.inputs[0])
    L(add.outputs[0], comb.inputs['X']); L(sn.outputs['X'], comb.inputs['Y']); L(sn.outputs['Y'], comb.inputs['Z'])
    L(comb.outputs[0], em.inputs['Color']); em.inputs['Strength'].default_value = 1.0
    L(em.outputs[0], out.inputs['Surface'])
    return m


class Rig:
    """Registro das pecas (pid -> material/flags) e dos nos de animacao."""

    def __init__(self, name):
        self.name = name
        self.parts = {}        # nome da peca -> pid
        self.part_info = [None]  # pid -> dict(name, mat, flags)
        self.nodes = {}        # nome -> objeto (empty ou malha)
        self.rest = {}         # nome -> (loc, rot, scale) de repouso
        self.meshes = []
        # "lean": inclina o modelo inteiro para longe da camera (topo para tras) sem mexer no ponto do chao;
        # compensa o achatamento da camera alta em criaturas verticais/flutuantes (rosto mais de frente)
        self.lean = self.empty("lean")
        self.turn = self.empty("turn", parent=self.lean)
        self.root = self.empty("root", parent=self.turn)

    # --- pecas
    def set_lean(self, deg):
        self.lean.rotation_euler.x = -math.radians(deg)

    def pid(self, part, mat, **flags):
        """Id da peca (cria se nao existe). flags: unlit, noline, prio (peso no voto), group (linhas internas
        so entre grupos diferentes), glow."""
        if part not in self.parts:
            self.parts[part] = len(self.part_info)
            self.part_info.append(dict(name=part, mat=mat, **flags))
            assert len(self.part_info) < 250
        return self.parts[part]

    def empty(self, name, loc=(0, 0, 0), parent=None):
        """Pivo de animacao em loc (coordenadas do MODELO, como as malhas); parent = outro pivo."""
        o = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(o)
        self.world_loc = getattr(self, 'world_loc', {})
        base = Vector((0, 0, 0))
        if parent is not None:
            o.parent = parent
            base = self.world_loc.get(parent.name, Vector((0, 0, 0)))
        self.world_loc[name] = Vector(loc)
        o.location = Vector(loc) - base
        self.nodes[name] = o
        return o

    def add_mesh(self, obj, part, mat, parent=None, **flags):
        obj["pid"] = float(self.pid(part, mat, **flags))
        if not obj.data.materials:
            obj.data.materials.append(pass_material())
        else:
            obj.data.materials[0] = pass_material()
        if parent is not None:
            obj.parent = parent
            # malhas em coordenadas do modelo: desfaz so a posicao acumulada do pivo
            obj.matrix_parent_inverse = Matrix.Translation(-self.world_loc.get(parent.name, Vector((0, 0, 0))))
        self.meshes.append(obj)
        self.nodes[obj.name] = obj
        return obj

    def set_part(self, obj, part, mat=None, **flags):
        """Troca a peca de um objeto (ex.: abdomen do vaga-lume aceso/apagado)."""
        info = self.part_info[self.parts[part]] if part in self.parts else None
        obj["pid"] = float(self.pid(part, mat or (info and info['mat']), **flags))

    def save_rest(self):
        for k, o in self.nodes.items():
            self.rest[k] = (o.location.copy(), o.rotation_euler.copy(), o.scale.copy())

    def reset_pose(self):
        for k, (l, r, s) in self.rest.items():
            o = self.nodes[k]
            o.location = l; o.rotation_euler = r; o.scale = s

    def n(self, name):
        return self.nodes[name]


# ------------------------------------------------------------------ geometria
def _obj_from(name, verts, faces, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if smooth:
        me.shade_smooth() if hasattr(me, 'shade_smooth') else [setattr(p, 'use_smooth', True) for p in me.polygons]
    return o


def _fix_normals(o, center):
    """Vira as faces para fora do centro dado (superficies abertas)."""
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    c = Vector(center)
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median() - c) < 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free(); me.update()


def ellipsoid(name, center, radii, seg=24, rings=16, rot=(0, 0, 0)):
    verts, faces = [], []
    for j in range(1, rings):
        th = math.pi * j / rings
        for i in range(seg):
            ph = TAU * i / seg
            verts.append((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
    top = len(verts); verts.append((0, 0, 1)); bot = len(verts); verts.append((0, 0, -1))
    for j in range(rings - 2):
        for i in range(seg):
            a = j * seg + i; b = j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    for i in range(seg):
        faces.append((top, (i + 1) % seg, i))
        base = (rings - 2) * seg
        faces.append((bot, base + i, base + (i + 1) % seg))
    R = Euler(rot).to_matrix()
    verts = [Vector(center) + R @ Vector((v[0] * radii[0], v[1] * radii[1], v[2] * radii[2])) for v in verts]
    o = _obj_from(name, verts, faces)
    _fix_normals(o, center)
    return o


def surface(name, fn, nu, nv, center, closed_u=False):
    """Superficie parametrica fn(u, v) -> Vector, u,v em [0,1]. Normais para fora de center."""
    us = nu if closed_u else nu + 1
    verts = [fn(i / nu, j / nv) for j in range(nv + 1) for i in range(us)]
    faces = []
    for j in range(nv):
        for i in range(nu):
            a = j * us + i; b = j * us + ((i + 1) % us if closed_u else i + 1)
            faces.append((a, b, b + us, a + us))
    o = _obj_from(name, verts, faces)
    _fix_normals(o, center)
    return o


def shell_dir(psi, om):
    """Direcao no casco: psi 0 = traseira (+Y) .. pi = frente (-Y); om 90 graus = topo."""
    return Vector((math.cos(om) * math.sin(psi), math.cos(psi), math.sin(om) * math.sin(psi)))


def plate(name, center, radii, psi0, psi1, om0, om1, bulge=0.06, res=6, lift=1.0):
    """Placa abaulada de um casco elipsoidal (bordas no raio*lift, centro mais alto -> tom por placa)."""
    c = Vector(center)

    def fn(u, v):
        psi = psi0 + (psi1 - psi0) * u
        om = om0 + (om1 - om0) * v
        d = shell_dir(psi, om)
        k = lift * (1.0 + bulge * (math.sin(math.pi * u) * math.sin(math.pi * v)) ** 0.6)
        return c + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * k
    return surface(name, fn, res, res, center)


def cone(name, base, tip, r0, r1=0.0, seg=12, rings=4, bend=(0, 0, 0)):
    """Cone/afunilado de base a tip (r1 = raio na ponta). bend: desvio (vetor) no meio (curva)."""
    base, tip, bend = Vector(base), Vector(tip), Vector(bend)
    axis = (tip - base)
    ax = axis.normalized()
    t1 = ax.orthogonal().normalized(); t2 = ax.cross(t1)
    verts, faces = [], []
    for j in range(rings + 1):
        s = j / rings
        p = base + axis * s + bend * (4 * s * (1 - s))
        r = r0 + (r1 - r0) * s
        for i in range(seg):
            a = TAU * i / seg
            verts.append(p + (t1 * math.cos(a) + t2 * math.sin(a)) * r)
    for j in range(rings):
        for i in range(seg):
            a = j * seg + i; b = j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    verts.append(base); verts.append(tip)
    bi, ti = len(verts) - 2, len(verts) - 1
    for i in range(seg):
        faces.append((bi, (i + 1) % seg, i))
        o = rings * seg
        faces.append((ti, o + i, o + (i + 1) % seg))
    ob = _obj_from(name, verts, faces)
    # normais para fora do eixo: usar centro no meio do eixo funciona para formas convexas
    _fix_normals(ob, base + axis * 0.5 + bend * 0.5)
    return ob


# ------------------------------------------------------------------ camera e render
def setup_camera(pitch_deg, canvas_px, ss, ppm=48.0, origin_frac=0.70):
    """Camera ortografica olhando para +Y, inclinada pitch_deg para baixo. A origem do mundo (pes) cai
    na coluna central e na linha origin_frac (de cima) da tela de canvas_px."""
    sc = bpy.context.scene
    CUR["pitch"] = pitch_deg
    cam = bpy.data.objects.get("cam")
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    size_m = canvas_px / ppm
    cam.data.ortho_scale = size_m
    cam.data.clip_start = 0.1; cam.data.clip_end = 200
    p = math.radians(pitch_deg)
    fwd = Vector((0, math.cos(p), -math.sin(p)))
    up = Vector((0, math.sin(p), math.cos(p)))
    # a origem deve ficar (origin_frac - 0.5) * size abaixo do centro da tela
    target = up * ((origin_frac - 0.5) * size_m)
    cam.location = target - fwd * DEPTH_NEAR
    cam.rotation_euler = Euler((math.pi / 2 - p, 0, 0))
    sc.render.resolution_x = sc.render.resolution_y = canvas_px * ss
    sc.render.resolution_percentage = 100
    return cam


def _load_exr(path):
    im = bpy.data.images.load(path, check_existing=False)
    W, H = im.size
    a = np.empty(W * H * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(H, W, 4)[::-1]  # topo primeiro


PACK_PID = 250  # = pack_model.PACK_PID (superficie com textura -> cor do atlas)


def reduce_frame(exr_path, ss, prio, alb_path=None, cmap=None):
    """EXR supersample -> (pid uint8, depth f16, nx f16, ny f16) no tamanho final por voto da maioria
    ponderado (prio[pid]; fundo = 1). Normais = media das subamostras da peca vencedora.
    alb_path/cmap (modelos com textura): a cor do albedo (sRGB) escolhe a peca mais proxima do COLORMAP."""
    a = _load_exr(exr_path)
    H, W = a.shape[:2]
    alpha = a[..., 3] > 0.5
    r = a[..., 0]
    pid = np.where(alpha, np.floor(r + 1e-5), 0).astype(np.int32)
    depth = np.where(alpha, r - pid, 1.0)
    if alb_path is not None and cmap:
        sel = pid == PACK_PID
        if sel.any():
            b = _load_exr(alb_path)[..., :3][sel]
            b = np.clip(b, 0, 1)
            srgb = np.where(b > 0.0031308, 1.055 * np.power(b, 1 / 2.4) - 0.055, b * 12.92) * 255
            cols = np.array([c for c, _ in cmap], np.float32)
            ids = np.array([p for _, p in cmap], np.int32)
            d = ((srgb[:, None, :] - cols[None, :, :]) ** 2).sum(-1)
            pid[sel] = ids[d.argmin(1)]
    h, w = H // ss, W // ss

    def blocks(x):
        return x.reshape(h, ss, w, ss).transpose(0, 2, 1, 3).reshape(h, w, ss * ss)
    P = blocks(pid); D = blocks(depth); NX = blocks(a[..., 1]); NY = blocks(a[..., 2])
    ids = np.unique(P)
    best = np.zeros((h, w), np.int32); bestc = np.full((h, w), -1.0)
    for i in ids:
        c = (P == i).sum(-1) * (1.0 if i == 0 else prio[i])
        m = c > bestc
        best[m] = i; bestc[m] = c[m]
    sel = P == best[..., None]
    cnt = np.maximum(sel.sum(-1), 1)
    nx = (NX * sel).sum(-1) / cnt; ny = (NY * sel).sum(-1) / cnt
    dmin = np.where(sel, D, 9.0).min(-1)
    dmin[best == 0] = 1.0
    return best.astype(np.uint8), dmin.astype(np.float32), nx.astype(np.float16), ny.astype(np.float16)


def render_all(rig, pose_fn, anims, out_npz, tmp_dir, canvas_px, ss, stage, only_dirs=None):
    """Renderiza todas as animacoes x 5 direcoes e grava out_npz + out_npz.json (tabela de pecas)."""
    sc = bpy.context.scene
    os.makedirs(tmp_dir, exist_ok=True)
    exr = os.path.join(tmp_dir, "frame.exr")
    sc.render.filepath = exr
    prio = np.ones(256, np.float32)
    data = {}
    t0 = time.time()
    for anim, nfr in anims:
        P = np.zeros((5, nfr, canvas_px, canvas_px), np.uint8)
        Dp = np.ones((5, nfr, canvas_px, canvas_px), np.float32)
        NX = np.zeros((5, nfr, canvas_px, canvas_px), np.float16)
        NY = np.zeros((5, nfr, canvas_px, canvas_px), np.float16)
        for di, (dname, ang) in enumerate(DIRS):
            if only_dirs and dname not in only_dirs:
                continue
            for f in range(nfr):
                rig.reset_pose()
                CUR["dir"] = ang
                pose_fn(rig, anim, f, nfr, stage)
                rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
                CUR["dir"] = ang
                for i, info in enumerate(rig.part_info[1:], 1):
                    prio[i] = info.get('prio', 1.0)
                sc.render.filepath = exr
                bpy.ops.render.render(write_still=True)
                alb = None
                slots = getattr(rig, "albedo_slots", None)
                if slots:
                    for o, k, pm, am in slots:
                        o.material_slots[k].material = am
                    alb = exr[:-4] + "_alb.exr"
                    sc.render.filepath = alb
                    bpy.ops.render.render(write_still=True)
                    for o, k, pm, am in slots:
                        o.material_slots[k].material = pm
                P[di, f], Dp[di, f], NX[di, f], NY[di, f] = reduce_frame(exr, ss, prio, alb,
                                                                          getattr(rig, "colormap", None))
        data[f"{anim}_id"] = P; data[f"{anim}_d"] = Dp; data[f"{anim}_nx"] = NX; data[f"{anim}_ny"] = NY
        print(f"[mon] {rig.name} s{stage} {anim}: {nfr} quadros x 5 dir ({time.time() - t0:.1f}s)", flush=True)
    np.savez_compressed(out_npz, **data)
    meta = dict(name=rig.name, stage=stage, canvas=canvas_px, anims=[[a, n] for a, n in anims],
                parts=rig.part_info)
    json.dump(meta, open(out_npz[:-4] + ".json", "w"), indent=1)
    if os.path.exists(exr):
        os.remove(exr)


# ------------------------------------------------------------------ utilitarios de animacao
def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# direcao atual (graus) e alcance no chao para o lado da camera; definidos pelo render_all / especie
CUR = dict(dir=0.0, reach=(0.3, 0.5, 0.4))


def cam_dir_local():
    """Direcao (no espaco do modelo) que aponta para a camera na direcao atual."""
    a = math.radians(CUR["dir"])
    return Vector((-math.sin(a), -math.cos(a), 0.0))


def near_point():
    """Ponto do chao da criatura mais perto da camera (elipse frente/tras/lado)."""
    d = cam_dir_local()
    fr, bk, sd = CUR["reach"]
    ry = fr if d.y < 0 else bk
    r = 1.0 / math.sqrt((d.x / sd) ** 2 + (d.y / ry) ** 2 + 1e-9)
    return d * r


def squash(node, s, anchored=True):
    """Squash & stretch (s > 1 estica na vertical, s < 1 achata; ~volume constante). Como no 2D, a borda
    de baixo na tela fica parada: a expansao horizontal tem pivo no ponto do chao mais perto da camera."""
    k = s ** -0.45
    node.scale = Vector((node.scale.x * k, node.scale.y * k, node.scale.z * s))
    if anchored:
        p = near_point()
        node.location.x += p.x * (1 - k)
        node.location.y += p.y * (1 - k)


def keys(t, pts):
    """Interpolacao suave por pontos-chave [(t, valor), ...] com t em 0..1."""
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            u = ease((t - t0) / max(1e-6, t1 - t0))
            if isinstance(v0, (tuple, list)):
                return tuple(a + (b - a) * u for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * u
    return pts[-1][1]


def tilt(node, angle, pivot_y):
    """Inclina para frente/tras (eixo X) com pivo no chao em y = pivot_y (pes da frente ou de tras), sem
    enterrar a outra ponta no chao."""
    node.rotation_euler.x += angle
    node.location.y += pivot_y - pivot_y * math.cos(angle)
    node.location.z += -pivot_y * math.sin(angle)
