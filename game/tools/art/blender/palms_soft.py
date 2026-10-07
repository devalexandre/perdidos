"""Palmeiras MACIAS (sem folhas facetadas): folhas são cards pintados com alfa (Bria, ver
assets/environment/painted/REGISTRO.md: card_palm_fan / card_palm_frond), em planos subdivididos e curvados.
 - buriti_soft_a/b: buriti das veredas (leques em pecíolos longos, coroa redonda, folhas secas pendentes)
 - palm_soft_a/b: palmeira de folhas-pena arqueadas (coqueiro/tamareira) para Egito e cidade
Materiais: "Card_Fan", "Card_Frond", "Card_FanDry", "Bark_Palm", "Fruit_Buriti" (o Godot aplica o kit).
   .tools/blender/blender -b --python game/tools/art/blender/palms_soft.py -- [--preview]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *


def card(name, pivot, direction, length, width, bend, twist, m, cup=0.0, segs=6):
    """Plano (UV 0..1; u na largura, v=1 na base) com base no pivot, estendido ao longo de 'direction'
    (vetor 3D), curvando 'bend' (queda na ponta, m) e 'cup' (concavidade lateral)."""
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    verts, faces, uvs = [], [], []
    cols = 3
    for j in range(segs + 1):
        t = j / segs
        for i in range(cols):
            s = i / (cols - 1) - 0.5
            p = pivot + d * length * t + side * width * s + Vector((0, 0, -bend * t * t)) + up * (cup * (s * s) * 4 * math.sin(t * math.pi))
            p = p + side * (twist * t * s)
            verts.append(p)
            uvs.append((i / (cols - 1), t))  # glTF inverte V: base do card = base da imagem
    for j in range(segs):
        for i in range(cols - 1):
            a = j * cols + i
            faces.append((a, a + 1, a + cols + 1, a + cols))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new()
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
        poly.use_smooth = True
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(m)
    return o


def trunk(height, lean, r0, r1, bark, rings=True):
    cu = bpy.data.curves.new("trunk", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 1.0; cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(3)
    pts = [Vector((0, 0, -0.2)), Vector((lean.x * 0.2, lean.y * 0.2, height * 0.35)),
           Vector((lean.x * 0.6, lean.y * 0.6, height * 0.7)), Vector((lean.x, lean.y, height))]
    for i, p in enumerate(pts):
        bp = sp.bezier_points[i]; bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
        bp.radius = r0 + (r1 - r0) * i / 3
    o = link(bpy.data.objects.new("trunk", cu)); o.data.materials.append(bark)
    return pts[-1]


def buriti(name, seed, height):
    reset()
    rng = random.Random(seed)
    bark = mat("Bark_Palm", (0.55, 0.5, 0.44))
    fan = mat("Card_Fan", (0.3, 0.55, 0.2))
    dry = mat("Card_FanDry", (0.6, 0.45, 0.25))
    stalk = mat("Bark_Stalk", (0.45, 0.5, 0.3))
    top = trunk(height, Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0)), 0.3, 0.22, bark)
    n = 14
    for i in range(n):
        a = i * math.tau / n + rng.uniform(-0.2, 0.2)
        elev = rng.uniform(-0.1, 0.9) if i % 3 else rng.uniform(0.9, 1.3)
        d = Vector((math.cos(a) * math.cos(elev), math.sin(a) * math.cos(elev), math.sin(elev)))
        L = rng.uniform(1.1, 1.5)
        tip = top + d * L
        # pecíolo
        cu = bpy.data.curves.new("st", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.04
        s = cu.splines.new('POLY'); s.points.add(1); s.points[0].co = (*top, 1); s.points[1].co = (*tip, 1)
        o = link(bpy.data.objects.new("st", cu)); o.data.materials.append(stalk)
        # leque (card) a partir da ponta do pecíolo, um pouco mais inclinado para fora/baixo
        d2 = (d + Vector((0, 0, -0.35))).normalized()
        card("fan", tip - d2 * 0.1, d2, rng.uniform(2.0, 2.5), rng.uniform(2.1, 2.5), rng.uniform(0.3, 0.7), 0.0, fan,
             cup=0.25)
    for i in range(3):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -1)).normalized()
        card("dry", top + Vector((0, 0, -0.3)), d, 1.8, 1.6, 0.0, 0.0, dry, cup=0.2)
    for i in range(3):
        a = rng.uniform(0, math.tau)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.28,
                                             location=top + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, -0.6)))
        c = bpy.context.object; c.scale.z = 1.5
        bpy.ops.object.shade_smooth()
        c.data.materials.append(mat("Fruit_Buriti", (0.5, 0.25, 0.12)))
    join_all(name)
    export(name)
    preview(name, 16, (0, 0, height * 0.7))


def palm(name, seed, height):
    reset()
    rng = random.Random(seed)
    bark = mat("Bark_Palm", (0.6, 0.48, 0.36))
    frond = mat("Card_Frond", (0.3, 0.55, 0.2))
    top = trunk(height, Vector((rng.uniform(0.8, 1.4), rng.uniform(-0.3, 0.3), 0)), 0.26, 0.17, bark)
    n = 12
    for i in range(n):
        a = i * math.tau / n + rng.uniform(-0.15, 0.15)
        elev = rng.uniform(0.2, 0.6) if i % 2 else rng.uniform(-0.1, 0.25)
        d = Vector((math.cos(a) * math.cos(elev), math.sin(a) * math.cos(elev), math.sin(elev)))
        card("frond", top, d, rng.uniform(2.6, 3.2), rng.uniform(1.0, 1.25), rng.uniform(1.1, 1.8), 0.0, frond,
             cup=-0.15, segs=8)
    for i in range(4):
        a = rng.uniform(0, math.tau)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.16,
                                             location=top + Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, -0.3)))
        bpy.ops.object.shade_smooth()
        bpy.context.object.data.materials.append(mat("Fruit_Buriti", (0.5, 0.35, 0.15)))
    join_all(name)
    export(name)
    preview(name, 14, (0, 0, height * 0.7))


buriti("buriti_soft_a", 11, 8.0)
buriti("buriti_soft_b", 23, 9.5)
palm("palm_soft_a", 5, 6.0)
palm("palm_soft_b", 9, 7.0)
