"""Buriti (Mauritia flexuosa) estilizado — palmeira das veredas do cerrado (Terra do Sabiá). Original.
Tronco reto cinza com anéis, coroa de folhas em LEQUE (costapalmadas, pregueadas, com pontas franjadas) em
pecíolos longos, e 2–3 folhas secas penduradas. Gera buriti_a.glb e buriti_b.glb."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *


def fan_leaf(origin, direction, tilt, radius, pleats, rng, leaf_mat, stalk_mat, droop=0.0):
    """Leque: pecíolo + disco de ~200° pregueado em zigue-zague, pontas divididas."""
    d = Vector((direction.x, direction.y, 0)).normalized()
    side = Vector((-d.y, d.x, 0))
    stalk_len = radius * 0.9
    tip = origin + d * stalk_len * math.cos(tilt) + Vector((0, 0, stalk_len * math.sin(tilt)))
    # pecíolo (tubo fino)
    cu = bpy.data.curves.new("stalk", "CURVE"); cu.dimensions = '3D'; cu.bevel_depth = 0.035; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(1)
    sp.points[0].co = (*origin, 1); sp.points[1].co = (*tip, 1)
    o = link(bpy.data.objects.new("stalk", cu)); o.data.materials.append(stalk_mat)
    # lâmina: fatias em leque; cada fatia é uma prega (vale/crista)
    verts, faces = [], []
    center_i = 0
    verts.append(tip)
    span = math.radians(200)
    up = Vector((0, 0, 1))
    n = pleats * 2
    for i in range(n + 1):
        a = -span / 2 + span * i / n
        dirv = (d * math.cos(a) + side * math.sin(a)).normalized()
        # a lâmina abre para cima/para fora; prega alterna altura
        fold = 0.12 * radius * (1 if i % 2 == 0 else -1)
        r1 = radius * (0.55 + 0.05 * rng.random())
        r2 = radius * (1.0 + 0.1 * rng.random())
        lift1 = (math.cos(a) * 0.35 - droop) * r1 + fold * 0.5
        lift2 = (math.cos(a) * 0.25 - droop * 1.6) * r2 + fold - 0.25 * r2 * abs(math.sin(a))
        verts.append(tip + dirv * r1 + up * lift1)
        verts.append(tip + dirv * r2 + up * lift2)
    for i in range(n):
        a0, b0 = 1 + i * 2, 2 + i * 2
        a1, b1 = 1 + (i + 1) * 2, 2 + (i + 1) * 2
        faces.append((center_i, a0, a1))
        if i % 2 == 0 or rng.random() < 0.6:  # pontas franjadas: algumas fatias externas somem
            faces.append((a0, b0, b1, a1))
    mesh_obj("fan", verts, faces, leaf_mat, smooth=False)


def buriti(name, seed, height):
    reset()
    rng = random.Random(seed)
    bark = mat("Bark_Buriti", (0.45, 0.4, 0.35))
    leaf = mat("Leaves_Buriti", (0.3, 0.55, 0.2))
    dry = mat("Leaves_BuritiDry", (0.55, 0.4, 0.2))
    # tronco reto, levemente cônico, com anéis
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.28, depth=height, location=(0, 0, height / 2))
    t = bpy.context.object
    t.data.materials.append(bark)
    bm = bmesh.new(); bm.from_mesh(t.data)
    for v in bm.verts:
        k = v.co.z / height + 0.5
        s = 1.15 - 0.3 * k
        v.co.x *= s; v.co.y *= s
    bm.to_mesh(t.data); bm.free()
    for p in t.data.polygons:
        p.use_smooth = True
    top = Vector((0, 0, height))
    n = 12
    for i in range(n):
        a = i * math.tau / n + rng.uniform(-0.2, 0.2)
        tilt = math.radians(rng.uniform(10, 45)) if i % 3 else math.radians(rng.uniform(55, 75))
        fan_leaf(top, Vector((math.cos(a), math.sin(a), 0)), tilt, rng.uniform(1.7, 2.2), 9, rng, leaf, bark,
                 droop=rng.uniform(0.1, 0.35))
    for i in range(3):
        a = rng.uniform(0, math.tau)
        fan_leaf(top + Vector((0, 0, -0.4)), Vector((math.cos(a), math.sin(a), 0)), math.radians(-60), 1.6, 7, rng,
                 dry, bark, droop=0.4)
    # cachos de coquinhos (buriti) sob a copa
    for i in range(3):
        a = rng.uniform(0, math.tau)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.3,
                                              location=top + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, -0.7)))
        c = bpy.context.object
        c.scale.z = 1.4
        c.data.materials.append(mat("Fruit_Buriti", (0.45, 0.2, 0.1)))
    o = join_all(name)
    export(name)
    preview(name, 16, (0, 0, height * 0.6))


buriti("buriti_a", 11, 8.5)
buriti("buriti_b", 23, 10.0)
