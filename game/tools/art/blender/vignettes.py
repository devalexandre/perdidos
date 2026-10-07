"""Vinhetas culturais das nações do Campo de Treino (revisão 5) — modelos ORIGINAIS, estilizados e respeitosos
(sem símbolos religiosos como emblema de poder; GDD §4.0). Materiais só por nome (o Godot aplica o kit pintado).
   .tools/blender/blender -b --python game/tools/art/blender/vignettes.py -- [--preview] [nome ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import landmarks as L

B, CY, CO, GR = L.box, L.cyl, L.cone, L.gable_roof
for k, n, c in [("clay", "Plaster_Clay", (0.72, 0.42, 0.3)), ("terracotta", "Plaster_Terracotta", (0.8, 0.45, 0.28)),
                ("reed", "Thatch", (0.85, 0.72, 0.42)), ("stone_warm2", "Stone_Warm", (0.85, 0.78, 0.66)),
                ("stone_moss", "Stone_Mossy", (0.62, 0.66, 0.55)), ("wood_carved", "Wood_Carved", (0.55, 0.38, 0.24)),
                ("paint_red", "Wood_PaintRed", (0.8, 0.28, 0.2)), ("paint_blue", "Wood_Blue", (0.36, 0.52, 0.85)),
                ("paint_yellow", "Wood_Yellow", (0.95, 0.75, 0.3)), ("rope", "Wood_Rope", (0.75, 0.62, 0.4)),
                ("azul", "Tile_Azulejo", (1, 1, 1)), ("plaster", "Plaster_White", (0.95, 0.92, 0.85)),
                ("roof_clay", "Roof_Clay", (0.85, 0.5, 0.35)), ("stone_grey", "Stone_Grey", (0.72, 0.7, 0.66))]:
    L.C[k] = (n, c)


def smooth_obj(o):
    for p in o.data.polygons:
        p.use_smooth = True


def lathe(profile, key, segs=20, loc=(0, 0, 0)):
    """perfil [(r, z), ...] girado em Z."""
    verts, faces = [], []
    for i, (r, z) in enumerate(profile):
        for s in range(segs):
            a = s * math.tau / segs
            verts.append((loc[0] + math.cos(a) * r, loc[1] + math.sin(a) * r, loc[2] + z))
    for i in range(len(profile) - 1):
        for s in range(segs):
            j = (s + 1) % segs
            faces.append((i * segs + s, i * segs + j, (i + 1) * segs + j, (i + 1) * segs + s))
    o = mesh_obj("lathe", verts, faces, L.M(key), smooth=True)
    return o


# ---------------------------------------------------------------- Portugal
def vg_portugal_house():
    reset()
    B((0, 0, 1.4), (4.2, 3.2, 2.8), "plaster", 0.06)
    B((0, -1.62, 0.45), (4.3, 0.06, 0.9), "azul", 0.0)       # barrado de azulejo
    B((0, -1.62, 2.55), (4.3, 0.06, 0.3), "azul", 0.0)       # faixa sob o beiral
    B((0, -1.66, 1.05), (0.95, 0.1, 2.0), "paint_blue", 0.02)
    for sx in (-1.4, 1.4):
        B((sx, -1.66, 1.7), (0.7, 0.08, 0.8), "paint_blue", 0.02)
        B((sx, -1.7, 1.25), (0.9, 0.18, 0.08), "plaster", 0.02)
    GR((0, 0, 2.8), 4.2, 3.2, 1.3, "roof_clay", over=0.35, ridge_x=True)
    L.gable_ends((0, 0, 2.8), 4.2, 3.2, 1.3, "plaster")
    B((1.3, 0.6, 3.6), (0.5, 0.5, 1.2), "plaster", 0.04)
    for x in (-1.4, 1.4):  # vasos de flores na janela
        B((x, -1.8, 1.2), (0.7, 0.2, 0.18), "terracotta", 0.03)
    L.finish("vg_portugal_house", 12, (0, 0, 1.6))


def vg_portugal_wall():
    reset()
    B((0, 0, 0.6), (5.0, 0.35, 1.2), "plaster", 0.05)
    B((0, -0.19, 0.45), (5.0, 0.02, 0.5), "azul", 0.0)
    B((0, 0, 1.25), (5.1, 0.45, 0.1), "stone_warm2", 0.02)
    for x in (-2.0, 0.2, 1.9):  # vasos de barro em cima do muro
        lathe([(0.0, 0), (0.18, 0.02), (0.22, 0.2), (0.16, 0.34), (0.19, 0.38)], "terracotta", 14, (x, 0, 1.3))
    L.finish("vg_portugal_wall", 9, (0, 0, 0.8))


# ---------------------------------------------------------------- Grécia
def amphora(x, y, s, key="terracotta", tilt=0.0):
    o = lathe([(0.0, 0.0), (0.12, 0.02), (0.3, 0.35), (0.34, 0.55), (0.24, 0.85), (0.1, 1.0), (0.11, 1.12), (0.14, 1.15)],
              key, 18)
    o.scale = (s, s, s); o.location = (x, y, 0); o.rotation_euler = (tilt, 0, 0)
    for sx in (-1, 1):
        cu = bpy.data.curves.new("h", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.025
        sp = cu.splines.new('BEZIER'); sp.bezier_points.add(2)
        for i, p in enumerate([(sx * 0.1, 0, 1.05), (sx * 0.3, 0, 1.0), (sx * 0.28, 0, 0.8)]):
            bp = sp.bezier_points[i]; bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
        h = link(bpy.data.objects.new("h", cu)); h.data.materials.append(L.M(key))
        h.parent = o


def vg_greek_amphorae():
    reset()
    amphora(0, 0, 1.0); amphora(0.55, 0.3, 0.85); amphora(-0.5, 0.35, 0.8)
    amphora(0.9, -0.5, 0.8, tilt=1.4)
    B((-0.3, -0.7, 0.15), (1.2, 0.5, 0.3), "stone_warm2", 0.04)
    L.finish("vg_greek_amphorae", 6, (0, 0, 0.6))


def vg_greek_steps():
    reset()
    for i in range(4):
        B((0, i * 0.55, 0.15 + i * 0.3), (4.0 - i * 0.2, 0.6, 0.3), "stone_warm2", 0.04)
    for sx in (-2.1, 2.1):
        B((sx, 0.8, 0.6), (0.4, 2.4, 1.2), "stone_warm2", 0.05)
    L.finish("vg_greek_steps", 8, (0, 0.8, 0.6))


# ---------------------------------------------------------------- Egito
def vg_reed_boat():
    reset()
    cu = bpy.data.curves.new("boat", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.5; cu.bevel_resolution = 4
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(3)
    for i, (p, r) in enumerate([((-2.0, 0, 0.9), 0.3), ((-1.0, 0, 0.3), 0.9), ((1.0, 0, 0.3), 0.9), ((2.0, 0, 0.9), 0.3)]):
        bp = sp.bezier_points[i]; bp.co = p; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    o = link(bpy.data.objects.new("boat", cu)); o.data.materials.append(L.M("reed")); o.scale = (1, 1.0, 0.7)
    for x in (-1.2, -0.4, 0.4, 1.2):  # amarrações
        CY((x, 0, 0.05), 0.3, 0.06, "rope", 12, bev=0).rotation_euler = (0, math.pi / 2, 0)
    L.finish("vg_reed_boat", 7, (0, 0, 0.4))


# ---------------------------------------------------------------- Celta
def vg_standing_stones():
    reset()
    rng = random.Random(9)
    n = 9
    for i in range(n):
        a = i * math.tau / n
        h = rng.uniform(1.6, 2.6)
        o = B((math.cos(a) * 3.6, math.sin(a) * 3.6, h / 2 - 0.1), (0.7, 0.45, h), "stone_moss", 0.12, rot=a + math.pi / 2)
        o.rotation_euler.x = rng.uniform(-0.08, 0.08)
    L.finish("vg_standing_stones", 14, (0, 0, 1.0))


# ---------------------------------------------------------------- Nórdico
def vg_carved_post():
    reset()
    CY((0, 0, 0), 0.22, 3.0, "wood_carved", 10)
    for z in (0.6, 1.2, 1.8, 2.4):  # anéis entalhados (motivo geométrico)
        CY((0, 0, z), 0.26, 0.12, "wood_dark", 10)
    CO((0, 0, 3.0), 0.3, 0.5, "wood_carved", 10)
    for k in range(4):
        a = k * math.pi / 2
        B((math.cos(a) * 0.23, math.sin(a) * 0.23, 2.1), (0.08, 0.08, 0.3), "paint_red", 0.01, rot=a)
    L.finish("vg_carved_post", 6, (0, 0, 1.5))


# ---------------------------------------------------------------- Eslavo
def vg_crane_well():
    reset()
    CY((0, 0, 0), 0.8, 0.8, "wood", 8)            # poço de madeira (octogonal)
    CY((0, 0, 0.78), 0.62, 0.03, "stone_grey", 16, bev=0)
    CY((1.8, 0, 0), 0.12, 2.8, "wood_dark", 8)    # forquilha
    o = CY((0, 0, 0), 0.07, 5.2, "wood", 8)       # vara (grua) em balanço
    o.rotation_euler = (0, math.radians(-68), 0); o.location = (3.6, 0, 1.6)
    B((4.2, 0, 1.25), (0.5, 0.4, 0.5), "stone_grey", 0.05)  # contrapeso
    CY((0.0, 0, 3.2), 0.015, 1.9, "rope", 4)
    CY((0.0, 0, 1.3), 0.18, 0.3, "wood", 10)      # balde
    L.finish("vg_crane_well", 10, (1.5, 0, 1.5))


# ---------------------------------------------------------------- China
def vg_stone_bridge():
    reset()
    n = 14
    prev = None
    for i in range(n + 1):
        t = i / n
        x = -4.0 + t * 8.0
        z = 0.2 + math.sin(t * math.pi) * 1.4
        if prev:
            px, pz = prev
            o = B(((x + px) / 2, 0, (z + pz) / 2), (math.hypot(x - px, z - pz) + 0.04, 2.0, 0.28), "stone_grey", 0.03)
            o.rotation_euler = (0, -math.atan2(z - pz, x - px), 0)
            if i % 2 == 0:
                for sy in (-1.0, 1.0):
                    B((x, sy, z + 0.35), (0.14, 0.14, 0.6), "stone_grey", 0.02)
        prev = (x, z)
    for sy in (-1.0, 1.0):
        pts = [Vector((-4.0 + t / n * 8.0, sy, 0.2 + math.sin(t / n * math.pi) * 1.4 + 0.62)) for t in range(n + 1)]
        cu = bpy.data.curves.new("rail", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.06
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for k, p in enumerate(pts):
            sp.points[k].co = (*p, 1)
        o = link(bpy.data.objects.new("rail", cu)); o.data.materials.append(L.M("stone_grey"))
    L.finish("vg_stone_bridge", 14, (0, 0, 1.0))


# ---------------------------------------------------------------- Japão
def vg_stone_lantern():
    reset()
    B((0, 0, 0.1), (0.6, 0.6, 0.2), "stone_moss", 0.04)
    CY((0, 0, 0.2), 0.12, 0.6, "stone_grey", 8)
    B((0, 0, 0.85), (0.5, 0.5, 0.1), "stone_grey", 0.03)
    B((0, 0, 1.05), (0.34, 0.34, 0.3), "stone_grey", 0.02)
    CO((0, 0, 1.2), 0.45, 0.3, "stone_grey", 4)
    CY((0, 0, 1.48), 0.06, 0.12, "stone_grey", 8)
    L.finish("vg_stone_lantern", 5, (0, 0, 0.7))


# ---------------------------------------------------------------- México
def vg_clay_pots():
    reset()
    for x, y, s in ((0, 0, 1.0), (0.55, 0.25, 0.75), (-0.45, 0.3, 0.7), (0.2, -0.55, 0.6)):
        o = lathe([(0.0, 0), (0.18, 0.02), (0.36, 0.22), (0.38, 0.4), (0.24, 0.62), (0.2, 0.7), (0.24, 0.74)], "terracotta", 18)
        o.scale = (s, s, s); o.location = (x, y, 0)
        cy = CY((x, y, 0.35 * s), 0.385 * s, 0.07 * s, "paint_yellow", 18, bev=0)
    L.finish("vg_clay_pots", 5, (0, 0, 0.4))


ALL = [vg_portugal_house, vg_portugal_wall, vg_greek_amphorae, vg_greek_steps, vg_reed_boat, vg_standing_stones,
       vg_carved_post, vg_crane_well, vg_stone_bridge, vg_stone_lantern, vg_clay_pots]
if __name__ == "__main__":
    want = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("--")] if "--" in sys.argv else []
    for fn in ALL:
        if not want or fn.__name__ in want:
            fn()
