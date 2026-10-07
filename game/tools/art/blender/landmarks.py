"""Marcos das nações do Campo de Treino (GDD §9.3) — modelos ORIGINAIS, formas estilizadas e respeitosas (sem
símbolos religiosos). Cada .glb tem a origem no centro do marco no chão; frente (Blender -Y) vira +Z no Godot;
largura em X. Os tamanhos seguem as obstruções de tools/art/build_training_field.gd (_landmark_*).
Materiais só por NOME (o Godot aplica o kit pintado; a cor do material vira tinta):
  Plaster_*, Stone_*, Sand_*, Wood_*, Lacquer_*, Roof_*, Thatch, Cloth_*, Tile_Azulejo, Gold, Leaves.
   .tools/blender/blender -b --python game/tools/art/blender/landmarks.py -- [--preview] [nome ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *

C = {
    "plaster": ("Plaster_White", (0.95, 0.92, 0.85)), "stone": ("Stone_Grey", (0.72, 0.7, 0.66)),
    "stone_warm": ("Stone_Warm", (0.85, 0.78, 0.66)), "marble": ("Stone_Marble", (0.95, 0.94, 0.9)),
    "sand": ("Sand_Stone", (0.92, 0.78, 0.55)), "adobe": ("Plaster_Adobe", (0.78, 0.55, 0.38)),
    "wood": ("Wood_Warm", (0.62, 0.45, 0.3)), "wood_dark": ("Wood_Dark", (0.4, 0.28, 0.2)),
    "lacquer": ("Lacquer_Red", (0.78, 0.2, 0.15)), "roof_dark": ("Roof_Dark", (0.42, 0.44, 0.5)),
    "roof_clay": ("Roof_Clay", (0.85, 0.5, 0.35)), "thatch": ("Thatch", (0.9, 0.75, 0.45)),
    "azulejo": ("Tile_Azulejo", (1, 1, 1)), "gold": ("Gold", (1.0, 0.8, 0.3)), "leaves": ("Leaves", (0.3, 0.5, 0.2)),
    "turf": ("Turf", (0.75, 0.85, 0.6)), "dune": ("Dune_Sand", (1.0, 0.95, 0.85)), "blue": ("Wood_Blue", (0.36, 0.52, 0.85)), "cloth_red": ("Cloth_Red", (0.8, 0.25, 0.2)),
    "yellow": ("Wood_Yellow", (0.95, 0.75, 0.3)), "cloth_tent_a": ("Cloth_TentA", (0.95, 0.9, 0.78)),
    "cloth_tent_b": ("Cloth_TentB", (0.85, 0.7, 0.52)), "water": ("Stone_Water", (0.35, 0.6, 0.65)),
}


def M(key):
    n, c = C[key]
    return mat(n, c)


def bevel(o, w=0.04, seg=2):
    b = o.modifiers.new("bevel", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = 'ANGLE'


def box(center, size, key, bev=0.04, rot=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(0, 0, rot))
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(M(key))
    if bev:
        bevel(o, bev)
    return o


def cyl(center, r, h, key, verts=16, r_top=None, bev=0.03):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r_top is None else r_top, depth=h,
                                    location=(center[0], center[1], center[2] + h / 2))
    o = bpy.context.object
    o.data.materials.append(M(key))
    for p in o.data.polygons:
        p.use_smooth = verts >= 12
    if bev:
        bevel(o, bev)
    return o


def cone(center, r, h, key, verts=16):
    return cyl(center, r, h, key, verts, r_top=0.0, bev=0)


def pyramid(center, w, d, h, key):
    x, y, z = center
    v = [(x - w / 2, y - d / 2, z), (x + w / 2, y - d / 2, z), (x + w / 2, y + d / 2, z), (x - w / 2, y + d / 2, z), (x, y, z + h)]
    f = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]
    return mesh_obj("pyr", v, f, M(key), smooth=False)


def gable_roof(center, w, d, h, key, over=0.4, ridge_x=True, thick=0.18):
    """Telhado de duas águas com espessura; cumeeira ao longo de X (ou Y)."""
    x, y, z = center
    hw, hd = w / 2 + over, d / 2 + over
    if ridge_x:
        v = [(x - hw, y - hd, z), (x + hw, y - hd, z), (x + hw, y, z + h), (x - hw, y, z + h),
             (x - hw, y + hd, z), (x + hw, y + hd, z)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4)]
    else:
        v = [(x - hw, y - hd, z), (x - hw, y + hd, z), (x, y + hd, z + h), (x, y - hd, z + h),
             (x + hw, y - hd, z), (x + hw, y + hd, z)]
        f = [(0, 3, 2, 1), (3, 4, 5, 2)]
    o = mesh_obj("roof", v, f, M(key), smooth=False)
    s = o.modifiers.new("solid", "SOLIDIFY")
    s.thickness = thick
    return o


def gable_ends(center, w, d, h, key):
    x, y, z = center
    for sx in (-1, 1):
        v = [(x + sx * w / 2, y - d / 2, z), (x + sx * w / 2, y + d / 2, z), (x + sx * w / 2, y, z + h)]
        mesh_obj("gable", v, [(0, 1, 2)], M(key), smooth=False)


def hip_roof_curved(center, w, d, h, key, over=0.8, lift=0.35, segs=6):
    """Telhado de quatro águas com beiral levantado nas pontas (pavilhão/casa oriental)."""
    x, y, z = center
    verts, faces = [], []
    rings = []
    for i in range(segs + 1):
        t = i / segs
        sw = (w / 2 + over) * (1 - t) + 0.25 * t
        sd = (d / 2 + over) * (1 - t) + 0.05 * t
        zz = z + h * (t ** 0.8)
        ring = []
        for (cx, cy) in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
            corner_lift = lift * (1 - t) ** 2
            ring.append(len(verts))
            verts.append((x + cx * sw, y + cy * sd, zz + corner_lift))
        rings.append(ring)
    for i in range(segs):
        a, b = rings[i], rings[i + 1]
        for k in range(4):
            j = (k + 1) % 4
            faces.append((a[k], a[j], b[j], b[k]))
    top = rings[-1]
    faces.append((top[0], top[1], top[2], top[3]))
    o = mesh_obj("hip", verts, faces, M(key), smooth=False)
    s = o.modifiers.new("solid", "SOLIDIFY")
    s.thickness = 0.16
    return o


def finish(name, dist=18, target=(0, 0, 2.5)):
    join_all(name)
    export(name)
    preview(name, dist, target)


# ------------------------------------------------------------------ Portugal
def lm_portugal_tower():
    reset()
    cyl((0, 0, 0), 2.35, 0.8, "stone_warm", 20)
    cyl((0, 0, 0.8), 2.2, 6.2, "plaster", 24)
    cyl((0, 0, 4.6), 2.26, 0.7, "azulejo", 24, bev=0)
    cyl((0, 0, 7.0), 2.4, 0.35, "stone_warm", 24)
    for i in range(10):
        a = i * math.tau / 10
        box((math.cos(a) * 2.15, math.sin(a) * 2.15, 7.7), (0.6, 0.45, 0.7), "stone_warm", rot=a)
    box((0, -2.18, 1.6), (1.2, 0.3, 2.3), "wood", 0.05)
    box((0, -2.2, 2.85), (1.5, 0.35, 0.25), "stone_warm")
    for z in (3.7, 5.9):
        for a in (math.pi * 1.5, math.pi * 0.25, math.pi * 0.75, math.pi * 1.1):
            box((math.cos(a) * 2.18, math.sin(a) * 2.18, z), (0.55, 0.3, 0.9), "blue", 0.03, rot=a + math.pi / 2)
    finish("lm_portugal_tower", 22, (0, 0, 3.5))


def lm_portugal_fountain():
    reset()
    cyl((0, 0, 0), 1.6, 0.6, "stone_warm", 24)
    cyl((0, 0, 0.55), 1.35, 0.08, "water", 24, bev=0)
    cyl((0, 0, 0), 0.25, 1.6, "stone_warm", 10)
    cyl((0, 0, 1.6), 0.55, 0.18, "stone_warm", 12)
    cyl((0, 0, 1.78), 0.18, 0.4, "azulejo", 10)
    finish("lm_portugal_fountain", 7, (0, 0, 0.8))


# ------------------------------------------------------------------ Grécia (costa)
def lm_grecia_colonnade():
    reset()
    box((0, 0, 0.12), (9.2, 4.4, 0.25), "marble", 0.05)
    box((0, 0, 0.37), (8.8, 4.0, 0.25), "marble", 0.05)
    for i in range(5):
        for sy in (-1.5, 1.5):
            x = -3.6 + i * 1.8
            cyl((x, sy, 0.5), 0.36, 0.25, "marble", 12)
            cyl((x, sy, 0.75), 0.3, 3.7, "marble", 16, r_top=0.26)
            box((x, sy, 4.55), (0.8, 0.8, 0.22), "marble")
    box((0, 0, 4.85), (8.6, 3.9, 0.45), "marble")
    box((0, 0, 5.2), (8.9, 4.1, 0.25), "marble")
    # frontão baixo (triângulo) nas pontas
    for sx in (-1, 1):
        v = [(sx * 4.4, -2.05, 5.32), (sx * 4.4, 2.05, 5.32), (sx * 4.4, 0, 6.3)]
        mesh_obj("ped", v, [(0, 1, 2)], M("marble"), smooth=False)
    gable_roof((0, 0, 5.32), 8.8, 4.1, 0.98, "roof_clay", over=0.1, ridge_x=True)
    finish("lm_grecia_colonnade", 20, (0, 0, 2.8))


def lm_grecia_broken_column():
    reset()
    cyl((0, 0, 0), 0.42, 0.3, "marble", 12)
    cyl((0, 0, 0.3), 0.32, 1.25, "marble", 16)
    box((0.7, 0.4, 0.15), (0.8, 0.5, 0.3), "marble", 0.06, rot=0.6)
    finish("lm_grecia_broken_column", 6, (0, 0, 0.6))


# ------------------------------------------------------------------ Egito (deserto)
def lm_egito_obelisks():
    reset()
    box((0, 0, 0.2), (3.2, 7.4, 0.4), "sand", 0.05)
    for sy in (-2.3, 2.3):
        box((0, sy, 0.7), (1.5, 1.5, 0.6), "sand", 0.04)
        o = box((0, sy, 4.0), (0.9, 0.9, 6.0), "sand", 0.02)
        bm = bmesh.new(); bm.from_mesh(o.data)
        for v in bm.verts:
            if v.co.z > 0:
                v.co.x *= 0.72; v.co.y *= 0.72
        bm.to_mesh(o.data); bm.free()
        pyramid((0, sy, 7.0), 0.66, 0.66, 0.6, "gold")
    # ruína de pirâmide pequena (silhueta) no meio
    for k in range(3):
        s = 2.4 - k * 0.7
        box((0, 0, 0.4 + k * 0.45 + 0.22), (s, s, 0.45), "sand", 0.03)
    finish("lm_egito_obelisks", 20, (0, 0, 3.0))


def lm_egito_adobe():
    reset()
    box((0, 0, 1.2), (4.0, 3.2, 2.4), "adobe", 0.08)
    box((0, 0, 2.5), (4.2, 3.4, 0.2), "wood", 0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((sx * 1.9, sy * 1.5, 2.75), (0.4, 0.4, 0.3), "adobe", 0.05)
    box((0, -1.62, 0.95), (0.9, 0.1, 1.9), "wood_dark", 0.02)
    for sx in (-1.2, 1.2):
        box((sx, -1.62, 1.6), (0.5, 0.1, 0.5), "wood_dark", 0.02)
    # toldo de pano na frente
    box((0, -2.2, 2.1), (2.4, 1.2, 0.06), "cloth_red", 0.01)
    for sx in (-1.1, 1.1):
        cyl((sx, -2.75, 0), 0.05, 2.1, "wood", 6)
    finish("lm_egito_adobe", 12, (0, 0, 1.3))


# ------------------------------------------------------------------ Celta (terras altas)
def lm_celta_tower():
    reset()
    cyl((0, 0, 0), 2.7, 0.5, "stone", 20)
    cyl((0, 0, 0.5), 2.5, 6.8, "stone", 20, r_top=2.2)
    cone((0, 0, 7.3), 2.45, 2.6, "stone", 20)
    box((0, -2.35, 3.4), (0.8, 0.5, 1.6), "wood_dark", 0.04)
    for z, a in ((5.5, 0.4), (6.3, 2.5), (4.6, 4.2)):
        box((math.cos(a) * 2.25, math.sin(a) * 2.25, z), (0.35, 0.35, 0.7), "wood_dark", 0.02, rot=a)
    finish("lm_celta_tower", 22, (0, 0, 4))


def lm_celta_hut():
    reset()
    cyl((0, 0, 0), 1.7, 1.8, "stone", 16)
    cone((0, 0, 1.6), 2.2, 2.3, "thatch", 16)
    box((0, -1.62, 0.8), (0.8, 0.3, 1.6), "wood_dark", 0.03)
    finish("lm_celta_hut", 10, (0, 0, 1.6))


# ------------------------------------------------------------------ Nórdico
def lm_nordico_longhouse():
    reset()
    box((0, 0, 0.2), (8.4, 4.6, 0.4), "stone", 0.06)
    box((0, 0, 1.4), (8.0, 4.2, 2.1), "wood", 0.04)
    # tábuas verticais (relevo)
    for i in range(17):
        x = -3.9 + i * 0.49
        for sy in (-2.12, 2.12):
            box((x, sy, 1.4), (0.1, 0.06, 2.0), "wood_dark", 0.01)
    gable_roof((0, 0, 2.45), 8.0, 4.2, 2.1, "turf", over=0.55, ridge_x=True, thick=0.35)
    gable_ends((0, 0, 2.45), 8.0, 4.2, 2.1, "wood")
    for sx in (-1, 1):  # tábuas cruzadas na empena
        box((sx * 4.3, -0.6, 4.7), (0.12, 0.14, 1.6), "wood_dark", 0.02, rot=0)
    box((0, -2.2, 1.05), (1.1, 0.12, 1.9), "wood_dark", 0.03)
    finish("lm_nordico_longhouse", 20, (0, 0, 2.0))


# ------------------------------------------------------------------ Eslavo
def lm_eslavo_hut_legs():
    reset()
    for sx in (-0.8, 0.8):
        cyl((sx, 0, 0), 0.22, 2.1, "yellow", 8, r_top=0.14)
        for k in range(3):
            a = -math.pi / 2 + (k - 1) * 0.5
            o = cyl((sx, 0, 0), 0.08, 0.7, "yellow", 6)
            o.rotation_euler = (math.radians(80), 0, a + math.pi / 2)
    box((0, 0, 2.95), (2.8, 2.4, 1.9), "wood", 0.05)
    for z in (2.2, 2.6, 3.0, 3.4, 3.8):
        box((0, -1.22, z), (2.8, 0.08, 0.1), "wood_dark", 0.01)
    gable_roof((0, 0, 3.9), 2.8, 2.4, 1.3, "roof_dark", over=0.3, ridge_x=True)
    gable_ends((0, 0, 3.9), 2.8, 2.4, 1.3, "wood")
    box((0, -1.25, 3.0), (0.7, 0.08, 0.7), "blue", 0.02)
    finish("lm_eslavo_hut_legs", 12, (0, 0, 2.6))


def lm_eslavo_izba():
    reset()
    for i in range(9):  # troncos empilhados (relevo horizontal)
        z = 0.15 + i * 0.25
        for sy in (-1.7, 1.7):
            o = cyl((0, 0, 0), 0.13, 4.5, "wood", 8)
            o.rotation_euler = (0, math.pi / 2, 0)
            o.location = (0, sy, z)
        for sx in (-2.2, 2.2):
            o = cyl((0, 0, 0), 0.13, 3.5, "wood", 8)
            o.rotation_euler = (math.pi / 2, 0, 0)
            o.location = (sx, 0, z)
    box((0, 0, 1.1), (4.3, 3.3, 2.2), "wood_dark", 0)
    gable_roof((0, 0, 2.3), 4.4, 3.4, 1.8, "roof_dark", over=0.4, ridge_x=True)
    gable_ends((0, 0, 2.3), 4.4, 3.4, 1.8, "wood")
    for sx in (-1.1, 1.1):
        box((sx, -1.82, 1.3), (0.8, 0.1, 0.8), "blue", 0.03)
        box((sx, -1.86, 1.85), (1.1, 0.08, 0.25), "blue", 0.02)
    box((0, -1.82, 0.9), (0.8, 0.1, 1.7), "wood_dark", 0.03)
    finish("lm_eslavo_izba", 12, (0, 0, 1.6))


# ------------------------------------------------------------------ China
def lm_china_moongate():
    reset()
    wall = box((0, 0, 2.1), (12.0, 0.6, 4.2), "plaster", 0.05)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1.8, depth=2.0, location=(0, 0, 2.0), rotation=(math.pi / 2, 0, 0))
    hole = bpy.context.object
    m = wall.modifiers.new("hole", "BOOLEAN")
    m.object = hole
    m.operation = 'DIFFERENCE'
    bpy.context.view_layer.objects.active = wall
    bpy.ops.object.modifier_apply(modifier="hole")
    bpy.data.objects.remove(hole)
    box((0, 0, 0.15), (12.2, 0.8, 0.3), "stone", 0.03)
    hip_roof_curved((0, 0, 4.2), 12.0, 0.6, 0.55, "roof_dark", over=0.45, lift=0.3, segs=3)
    # moldura da lua (anel)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.85, minor_radius=0.1, location=(0, -0.32, 2.0), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(M("stone"))
    finish("lm_china_moongate", 22, (0, 0, 2.2))


def lm_china_pavilion():
    reset()
    box((0, 0, 0.15), (4.2, 4.2, 0.3), "stone", 0.05)
    for sx in (-1.6, 1.6):
        for sy in (-1.6, 1.6):
            cyl((sx, sy, 0.3), 0.16, 2.5, "lacquer", 10)
    box((0, 0, 2.85), (3.7, 3.7, 0.25), "lacquer", 0.03)
    hip_roof_curved((0, 0, 3.0), 3.4, 3.4, 1.7, "roof_dark", over=0.9, lift=0.5)
    cyl((0, 0, 4.7), 0.12, 0.5, "gold", 8)
    finish("lm_china_pavilion", 12, (0, 0, 2.2))


def lm_china_lantern():
    reset()
    cyl((0, 0, 0), 0.07, 2.3, "wood_dark", 6)
    box((0.3, 0, 2.2), (0.6, 0.06, 0.06), "wood_dark", 0)
    o = cyl((0.55, 0, 1.55), 0.24, 0.55, "cloth_red", 12)
    for p in o.data.polygons:
        p.use_smooth = True
    finish("lm_china_lantern", 5, (0, 0, 1.4))


# ------------------------------------------------------------------ Japão
def lm_japao_bridge():
    reset()
    prev = None
    n = 12
    for i in range(n + 1):
        t = i / n
        x = -5.0 + t * 10.0
        z = 0.25 + math.sin(t * math.pi) * 1.3
        if prev:
            px, pz = prev
            ang = math.atan2(z - pz, x - px)
            o = box(((x + px) / 2, 0, (z + pz) / 2), (math.hypot(x - px, z - pz) + 0.05, 1.8, 0.16), "wood", 0.02)
            o.rotation_euler = (0, -ang, 0)
        prev = (x, z)
    for i in range(0, n + 1, 2):
        t = i / n
        x = -5.0 + t * 10.0
        z = 0.25 + math.sin(t * math.pi) * 1.3
        for sy in (-0.85, 0.85):
            cyl((x, sy, z), 0.07, 0.8, "lacquer", 8)
    for sy in (-0.85, 0.85):  # corrimão curvo
        pts = []
        for i in range(n + 1):
            t = i / n
            pts.append(Vector((-5.0 + t * 10.0, sy, 0.25 + math.sin(t * math.pi) * 1.3 + 0.8)))
        cu = bpy.data.curves.new("rail", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.07
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for k, p in enumerate(pts):
            sp.points[k].co = (*p, 1)
        o = link(bpy.data.objects.new("rail", cu)); o.data.materials.append(M("lacquer"))
    finish("lm_japao_bridge", 16, (0, 0, 1.0))


def lm_japao_house():
    reset()
    box((0, 0, 0.25), (4.8, 3.6, 0.5), "stone", 0.04)
    box((0, 0, 1.4), (4.6, 3.4, 1.8), "plaster", 0.03)
    for x in (-2.25, -0.75, 0.75, 2.25):
        for sy in (-1.72, 1.72):
            box((x, sy, 1.4), (0.14, 0.1, 1.8), "wood", 0.01)
    box((0, -1.72, 2.25), (4.6, 0.1, 0.14), "wood", 0.01)
    for x in (-1.5, 0, 1.5):
        box((x, -1.74, 1.25), (1.2, 0.05, 1.3), "wood_dark", 0)
    hip_roof_curved((0, 0, 2.3), 4.6, 3.4, 1.4, "roof_dark", over=0.8, lift=0.25)
    finish("lm_japao_house", 12, (0, 0, 1.8))


# ------------------------------------------------------------------ México (ruína na mata)
def lm_mexico_platform():
    reset()
    for k in range(4):
        s = 9.0 - k * 2.0
        box((0, 0, k * 1.0 + 0.5), (s, s, 1.0), "stone", 0.08)
        # friso de pedra em cada nível
        box((0, 0, k * 1.0 + 0.95), (s + 0.15, s + 0.15, 0.12), "stone_warm", 0.02)
    # escadaria na frente
    for k in range(8):
        box((0, -4.6 + k * 0.5, k * 0.5 + 0.25), (2.2, 0.55, 0.5), "stone_warm", 0.03)
    for sx in (-1.25, 1.25):
        o = box((sx, -2.8, 2.0), (0.35, 4.2, 0.4), "stone", 0.03)
        o.rotation_euler = (math.radians(-45), 0, 0)
    # musgo/mato por cima (tufos)
    rng = random.Random(3)
    for i in range(22):
        k = rng.randint(0, 3)
        s = 9.0 - k * 2.0
        a = rng.uniform(0, math.tau)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=rng.uniform(0.35, 0.7),
                                              location=(math.cos(a) * s * 0.45, math.sin(a) * s * 0.45, k + 1.05))
        o = bpy.context.object
        o.scale.z = 0.55
        o.data.materials.append(M("turf"))
    finish("lm_mexico_platform", 22, (0, 0, 2.2))


# ------------------------------------------------------------------ acampamento
def _tent(name, cloth):
    reset()
    L, W, H = 1.8, 1.6, 2.0
    v = [(-L, -W, 0), (L, -W, 0), (L, 0, H), (-L, 0, H), (-L, W, 0), (L, W, 0)]
    o = mesh_obj("tent", v, [(0, 1, 2, 3), (3, 2, 5, 4), (4, 0, 3), ], M(cloth), smooth=False)
    s_ = o.modifiers.new("solid", "SOLIDIFY"); s_.thickness = 0.05
    # porta aberta (abas) na frente (+X)
    mesh_obj("flap", [(L, -W * 0.05, 0), (L + 0.6, -W * 0.7, 0), (L, 0, H * 0.95)], [(0, 1, 2)], M(cloth), smooth=False)
    mesh_obj("flap2", [(L, W * 0.05, 0), (L, 0, H * 0.95), (L + 0.6, W * 0.7, 0)], [(0, 1, 2)], M(cloth), smooth=False)
    for x in (-L - 0.15, L + 0.15):
        cyl((x, 0, 0), 0.05, H + 0.3, "wood", 6)
    cyl((-L - 0.15, 0, H - 0.05), 0.04, 2 * L + 0.3, "wood", 6).rotation_euler = (0, math.pi / 2, 0)
    bpy.context.object.location = (0, 0, H + 0.02)
    for sx in (-1, 1):  # cordas/estacas
        for sy in (-1, 1):
            cyl((sx * (L + 0.1), sy * (W + 0.6), 0), 0.04, 0.35, "wood_dark", 5)
    finish(name, 9, (0, 0, 1.0))


def lm_camp_tent_a():
    _tent("lm_camp_tent_a", "cloth_tent_a")


def lm_camp_tent_b():
    _tent("lm_camp_tent_b", "cloth_tent_b")


def lm_campfire():
    reset()
    rng = random.Random(4)
    for i in range(9):
        a = i * math.tau / 9
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.2, 0.28), location=(math.cos(a) * 0.85, math.sin(a) * 0.85, 0.1))
        o = bpy.context.object; o.scale.z = 0.6; o.data.materials.append(M("stone"))
    for i in range(5):
        a = i * math.tau / 5 + 0.3
        o = cyl((0, 0, 0), 0.08, 1.1, "wood_dark", 7)
        o.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.2)
        o.rotation_euler = (math.radians(60), 0, a - math.pi / 2)
    for x, y in ((-1.6, 0.4), (1.5, -0.6)):  # troncos-banco
        o = cyl((0, 0, 0), 0.22, 1.4, "wood", 10)
        o.rotation_euler = (0, math.pi / 2, math.atan2(y, x) + math.pi / 2)
        o.location = (x, y, 0.2)
    finish("lm_campfire", 7, (0, 0, 0.4))


# ------------------------------------------------------------------ ruínas / dunas (enfeites baixos, andáveis)
def lm_egito_ruins():
    reset()
    rng = random.Random(8)
    # obelisco quebrado deitado + blocos de arenito caídos + base de estátua vazia
    o = box((0, 0, 0.35), (4.2, 0.7, 0.7), "sand", 0.05)
    o.rotation_euler = (0, 0, 0.3)
    pyramid((2.35, 0.7, 0.0), 0.7, 0.7, 0.6, "gold").rotation_euler = (0, math.pi / 2, 0.3)
    for i in range(7):
        a = rng.uniform(0, math.tau); r = rng.uniform(1.2, 3.2)
        sz = rng.uniform(0.45, 0.8)
        b = box((math.cos(a) * r, math.sin(a) * r, sz * 0.35), (sz, sz * 0.8, sz * 0.7), "sand", 0.06, rot=rng.uniform(0, 3))
        b.rotation_euler.x = rng.uniform(-0.25, 0.25)
    box((-2.6, -1.4, 0.3), (1.6, 1.6, 0.6), "sand", 0.05)
    box((-2.6, -1.4, 0.75), (1.2, 1.2, 0.3), "sand", 0.04)
    finish("lm_egito_ruins", 12, (0, 0, 0.4))


def lm_egito_dunes():
    reset()
    rng = random.Random(2)
    for i in range(5):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0,
                                             location=(rng.uniform(-6, 6), rng.uniform(-2, 2), 0))
        o = bpy.context.object
        o.scale = (rng.uniform(3.5, 6.0), rng.uniform(2.0, 3.0), rng.uniform(0.35, 0.6))
        bpy.ops.object.shade_smooth()
        o.data.materials.append(M("dune"))
        d = o.modifiers.new("disp", "DISPLACE"); tx = bpy.data.textures.new("n", "CLOUDS"); tx.noise_scale = 1.2
        d.texture = tx; d.strength = 0.12
    finish("lm_egito_dunes", 20, (0, 0, 0))


def lm_grecia_ruins():
    reset()
    rng = random.Random(6)
    # colunas tombadas em tambores, capitel caído, degraus quebrados
    for k in range(4):
        o = cyl((0, 0, 0), 0.3, 0.9, "marble", 16)
        o.rotation_euler = (0, math.pi / 2, 0.15)
        o.location = (-1.8 + k * 0.95, rng.uniform(-0.1, 0.1), 0.3)
    box((2.6, 0.6, 0.18), (0.8, 0.8, 0.36), "marble", 0.05, rot=0.4)
    for i in range(3):
        box((-0.8 + i * 1.3, -1.6, 0.12), (1.2, 0.9, 0.24 - i * 0.05), "marble", 0.04, rot=rng.uniform(-0.2, 0.2))
    for i in range(5):
        a = rng.uniform(0, math.tau); r = rng.uniform(1.5, 3.0)
        box((math.cos(a) * r, math.sin(a) * r, 0.12), (rng.uniform(0.3, 0.6),) * 2 + (0.25,), "marble", 0.05,
            rot=rng.uniform(0, 3))
    finish("lm_grecia_ruins", 10, (0, 0, 0.3))


ALL = [lm_egito_ruins, lm_egito_dunes, lm_grecia_ruins, lm_camp_tent_a, lm_camp_tent_b, lm_campfire, lm_portugal_tower, lm_portugal_fountain, lm_grecia_colonnade, lm_grecia_broken_column, lm_egito_obelisks,
       lm_egito_adobe, lm_celta_tower, lm_celta_hut, lm_nordico_longhouse, lm_eslavo_hut_legs, lm_eslavo_izba,
       lm_china_moongate, lm_china_pavilion, lm_china_lantern, lm_japao_bridge, lm_japao_house, lm_mexico_platform]
if __name__ == "__main__":
    want = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("--")] if "--" in sys.argv else []
    for fn in ALL:
        if not want or fn.__name__ in want:
            fn()
