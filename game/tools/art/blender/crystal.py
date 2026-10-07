"""Cristal de renascimento da praça (Porto do Despertar) — aglomerado facetado original. Um prisma central alto
+ 6 menores inclinados, pontas lapidadas, base de pedra. Material "Crystal" (o Godot usa env_crystal.gdshader:
emissivo com gradiente, borda fresnel, facetas). Gera crystal_cluster.glb (~3,6 m)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import *


def prism(base, axis, radius, length, sides, rng, m):
    axis = axis.normalized()
    q = axis.to_track_quat('Z', 'Y')
    verts, faces = [], []
    tip_len = radius * rng.uniform(1.2, 1.8)
    for ring, (h, r) in enumerate([(0.0, radius * 0.85), (length * 0.15, radius), (length - tip_len, radius * 0.95)]):
        for i in range(sides):
            a = i * math.tau / sides + (0.15 if ring == 2 else 0.0) * 0
            v = Vector((math.cos(a) * r * rng.uniform(0.92, 1.08), math.sin(a) * r * rng.uniform(0.92, 1.08), h))
            verts.append(base + q @ v)
    top = len(verts)
    verts.append(base + q @ Vector((radius * 0.1, 0, length)))
    for ring in range(2):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((ring * sides + i, ring * sides + j, (ring + 1) * sides + j, (ring + 1) * sides + i))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((2 * sides + i, 2 * sides + j, top))
    faces.append(tuple(reversed(range(sides))))
    mesh_obj("prism", verts, faces, m, smooth=False)


reset()
rng = random.Random(5)
cm = mat("Crystal", (0.55, 0.8, 1.0), emit=2.0)
stone = mat("Stone_Base", (0.6, 0.57, 0.52))
prism(Vector((0, 0, 0.2)), Vector((0, 0, 1)), 0.55, 3.6, 6, rng, cm)
for k in range(6):
    a = k * math.tau / 6 + 0.3
    ax = Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 1))
    prism(Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.15)), ax, rng.uniform(0.18, 0.3), rng.uniform(0.9, 1.9), 6, rng, cm)
# base: rochas facetadas em anel
for k in range(9):
    a = k * math.tau / 9
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.35, 0.55),
                                          location=(math.cos(a) * 0.95, math.sin(a) * 0.95, 0.12))
    o = bpy.context.object
    o.scale.z = 0.55
    o.data.materials.append(stone)
join_all("crystal_cluster")
export("crystal_cluster")
preview("crystal_cluster", 9, (0, 0, 1.6))
