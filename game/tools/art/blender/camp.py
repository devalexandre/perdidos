"""Acampamento dos Viajantes (ponto de nascimento do Campo de Treino) e rancho dos Mestres — modelos originais.
Materiais só por nome (o Godot aplica o kit pintado; cor do material = tinta):
  Stone_*, Wood_*, Cloth_*, Thatch, Plaster_*, Roof_*, Ember (brasa emissiva), Lamp_Glow (vidro aceso),
  Sign_Board (tábua da placa: cor por instância no Godot).
   .tools/blender/blender -b --python game/tools/art/blender/camp.py -- [--preview] [nome ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import landmarks as L  # reaproveita box/cyl/cone/gable_roof/M


def add_mat(key, name, color):
    L.C[key] = (name, color)


add_mat("ember", "Ember", (1.0, 0.45, 0.12))
add_mat("glow", "Lamp_Glow", (1.0, 0.8, 0.45))
add_mat("stone_dark", "Stone_Dark", (0.42, 0.4, 0.38))
add_mat("ash", "Stone_Ash", (0.3, 0.28, 0.27))
add_mat("charred", "Wood_Charred", (0.28, 0.2, 0.16))
add_mat("canvas", "Cloth_Canvas", (0.96, 0.9, 0.78))
add_mat("canvas_b", "Cloth_CanvasB", (0.9, 0.8, 0.64))
add_mat("stripe_red", "Cloth_StripeRed", (0.78, 0.3, 0.24))
add_mat("stripe_teal", "Cloth_StripeTeal", (0.3, 0.62, 0.6))
add_mat("rug", "Cloth_Rug", (0.72, 0.32, 0.22))
add_mat("board", "Sign_Board", (1.0, 1.0, 1.0))
add_mat("plaster_ochre", "Plaster_Ochre", (0.95, 0.8, 0.58))
add_mat("clay", "Plaster_Clay", (0.72, 0.42, 0.3))
add_mat("hammock", "Cloth_Hammock", (0.95, 0.72, 0.3))
B, CY, CO, GR = L.box, L.cyl, L.cone, L.gable_roof


def campfire_v2():
    reset()
    rng = random.Random(4)
    CY((0, 0, 0), 1.05, 0.03, "ash", 24, bev=0)
    for i in range(11):
        a = i * math.tau / 11
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=rng.uniform(0.2, 0.27),
                                              location=(math.cos(a) * 0.92, math.sin(a) * 0.92, 0.1))
        o = bpy.context.object; o.scale.z = 0.62; o.data.materials.append(L.M("stone_dark"))
        bpy.ops.object.shade_smooth()
    for i in range(6):  # lenha em pirâmide
        a = i * math.tau / 6 + 0.2
        o = CY((0, 0, 0), 0.075, 1.0, "charred" if i % 2 else "wood", 8)
        o.location = (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.05)
        o.rotation_euler = (math.radians(58), 0, a - math.pi / 2)
    for i in range(9):  # brasas
        a = rng.uniform(0, math.tau); r = rng.uniform(0.05, 0.45)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.06, 0.11),
                                              location=(math.cos(a) * r, math.sin(a) * r, 0.05))
        bpy.context.object.data.materials.append(L.M("ember"))
    L.finish("camp_fire_v2", 5, (0, 0, 0.3))


def tent_v2(name, canvas, stripe):
    reset()
    Lh, W, H = 1.9, 1.7, 2.1
    v = [(-Lh, -W, 0), (Lh, -W, 0), (Lh, 0, H), (-Lh, 0, H), (-Lh, W, 0), (Lh, W, 0)]
    o = mesh_obj("tent", v, [(0, 1, 2, 3), (3, 2, 5, 4), (4, 0, 3)], L.M(canvas), smooth=False)
    s_ = o.modifiers.new("solid", "SOLIDIFY"); s_.thickness = 0.05
    # faixas coloridas na barra e na cumeeira
    for sy in (-1, 1):
        v2 = [(-Lh - 0.01, sy * (W + 0.01), 0.02), (Lh + 0.01, sy * (W + 0.01), 0.02),
              (Lh + 0.01, sy * (W - 0.19), 0.26), (-Lh - 0.01, sy * (W - 0.19), 0.26)]
        mesh_obj("stripe", v2, [(0, 1, 2, 3) if sy < 0 else (3, 2, 1, 0)], L.M(stripe), smooth=False)
    B((0, 0, H + 0.03), (2 * Lh + 0.1, 0.18, 0.1), stripe, 0.02)
    # porta: interior escuro + abas abertas amarradas
    mesh_obj("door", [(Lh + 0.02, -W * 0.55, 0), (Lh + 0.02, W * 0.55, 0), (Lh + 0.02, 0, H * 0.9)], [(0, 1, 2)],
             L.M("charred"), smooth=False)
    mesh_obj("flap", [(Lh, -W * 0.05, 0), (Lh + 0.55, -W * 0.8, 0.1), (Lh, 0, H * 0.95)], [(0, 1, 2)], L.M(canvas), False)
    mesh_obj("flap2", [(Lh, W * 0.05, 0), (Lh, 0, H * 0.95), (Lh + 0.55, W * 0.8, 0.1)], [(0, 1, 2)], L.M(canvas), False)
    for x in (-Lh - 0.15, Lh + 0.15):
        CY((x, 0, 0), 0.05, H + 0.35, "wood", 6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            CY((sx * (Lh + 0.1), sy * (W + 0.65), 0), 0.035, 0.3, "wood_dark", 5)
    # tapete na entrada e bandeirola
    B((Lh + 1.0, 0, 0.02), (1.2, 1.5, 0.04), "rug", 0.01)
    mesh_obj("pennant", [(Lh + 0.15, 0, H + 0.35), (Lh + 0.15, 0, H + 0.05), (Lh + 0.75, 0, H + 0.2)], [(0, 1, 2)],
             L.M(stripe), smooth=False)
    L.finish(name, 9, (0, 0, 1.0))


def signpost():
    reset()
    CY((0, 0, 0), 0.08, 2.1, "wood_dark", 8)
    B((0, 0, 0.08), (0.3, 0.3, 0.16), "stone_dark", 0.03)
    # tábua em seta (aponta para +X no Blender)
    v = [(0.05, -0.05, 1.45), (0.95, -0.05, 1.45), (1.2, -0.05, 1.63), (0.95, -0.05, 1.81), (0.05, -0.05, 1.81)]
    o = mesh_obj("board", v, [(0, 1, 2, 3, 4)], L.M("board"), smooth=False)
    s_ = o.modifiers.new("solid", "SOLIDIFY"); s_.thickness = 0.07
    CY((0, 0, 2.1), 0.1, 0.06, "wood_dark", 8)
    L.finish("camp_signpost", 5, (0, 0, 1.3))


def lantern_post():
    reset()
    CY((0, 0, 0), 0.07, 2.4, "wood_dark", 8)
    B((0.25, 0, 2.35), (0.6, 0.07, 0.07), "wood_dark", 0.01)
    CY((0.5, 0, 1.75), 0.012, 0.55, "wood_dark", 4)
    B((0.5, 0, 1.6), (0.26, 0.26, 0.34), "glow", 0.02)
    CO((0.5, 0, 1.77), 0.24, 0.18, "wood_dark", 4)
    B((0.5, 0, 1.42), (0.3, 0.3, 0.04), "wood_dark", 0.01)
    L.finish("camp_lantern", 5, (0, 0, 1.3))


def well():
    reset()
    CY((0, 0, 0), 1.0, 0.8, "stone", 20)
    CY((0, 0, 0.78), 0.82, 0.03, "ash", 20, bev=0)
    for sx in (-0.9, 0.9):
        B((sx, 0, 1.3), (0.14, 0.14, 1.9), "wood", 0.02)
    B((0, 0, 1.95), (1.9, 0.1, 0.1), "wood_dark", 0.01)
    GR((0, 0, 2.2), 2.0, 1.4, 0.7, "roof_clay", over=0.2, ridge_x=True, thick=0.1)
    CY((0.2, 0, 1.2), 0.18, 0.28, "wood", 10)
    L.finish("camp_well", 7, (0, 0, 1.2))


def rancho():
    reset()
    # casa de pau a pique (5 x 3.6) com varanda de telhado de sapê, rede, potes de barro, banco
    B((0, 0, 1.15), (5.0, 3.6, 2.3), "plaster_ochre", 0.08)
    B((0, -1.82, 1.0), (1.0, 0.1, 2.0), "wood_dark", 0.02)
    for sx in (-1.6, 1.6):
        B((sx, -1.83, 1.3), (0.8, 0.08, 0.7), "blue", 0.02)
    B((0, 0, 0.1), (5.2, 3.8, 0.2), "stone", 0.03)
    GR((0, 0, 2.3), 5.0, 3.6, 1.7, "thatch", over=0.55, ridge_x=True, thick=0.3)
    L.gable_ends((0, 0, 2.3), 5.0, 3.6, 1.7, "plaster_ochre")
    # varanda na frente
    for sx in (-2.4, 0, 2.4):
        CY((sx, -3.2, 0), 0.1, 2.3, "wood", 8)
    B((0, -3.2, 2.3), (5.2, 0.16, 0.16), "wood", 0.02)
    v = [(-2.8, -1.9, 2.55), (2.8, -1.9, 2.55), (2.8, -3.6, 2.15), (-2.8, -3.6, 2.15)]
    o = mesh_obj("porch", v, [(0, 1, 2, 3)], L.M("thatch"), smooth=False)
    s_ = o.modifiers.new("solid", "SOLIDIFY"); s_.thickness = 0.2
    # rede entre dois esteios
    pts = [Vector((-2.3, -3.2, 1.5)), Vector((-1.2, -3.2, 0.9)), Vector((0.0, -3.2, 0.85)), Vector((1.0, -3.2, 1.5))]
    cu = bpy.data.curves.new("rede", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.22; cu.bevel_resolution = 1
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        bp = sp.bezier_points[i]; bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    o = link(bpy.data.objects.new("rede", cu)); o.data.materials.append(L.M("hammock")); o.scale.y = 0.4
    # potes de barro e banco
    for x, s in ((2.0, 0.35), (2.4, 0.28), (1.7, 0.25)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=s, location=(x, -2.4, s * 0.9))
        bpy.ops.object.shade_smooth(); bpy.context.object.data.materials.append(L.M("clay"))
    B((-1.5, -2.3, 0.4), (1.6, 0.4, 0.08), "wood", 0.02)
    for sx in (-2.1, -0.9):
        B((sx, -2.3, 0.2), (0.1, 0.35, 0.4), "wood", 0.01)
    L.finish("camp_rancho", 16, (0, -1, 1.5))


ALL = [campfire_v2, lambda: tent_v2("camp_tent_v2_a", "canvas", "stripe_red"),
       lambda: tent_v2("camp_tent_v2_b", "canvas_b", "stripe_teal"), signpost, lantern_post, well, rancho]
for fn in ALL:
    fn()
