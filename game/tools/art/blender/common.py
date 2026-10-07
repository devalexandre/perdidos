"""Utilitários dos modelos originais do cenário (GDD §17.0.A). Rodar os scripts com:
   .tools/blender/blender -b --python game/tools/art/blender/<script>.py -- [--preview]
Exportam .glb para game/assets/environment/blender/ (materiais só com NOME: o Godot troca pelos do kit em
tools/art/env_kit/build_pack_kit.gd). Com --preview renderizam um PNG de conferência (EEVEE, câmera a 45°)."""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "environment", "blender")
PREVIEW = "--preview" in sys.argv


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.85
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, verts, faces, material, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return o


def join_all(name):
    objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def export(name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_apply=True, export_yup=True)
    print("exported", path)


def preview(name, dist=14.0, target=(0, 0, 3)):
    if not PREVIEW:
        return
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=60)
    g = bpy.context.object
    g.data.materials.append(mat("PreviewGround", (0.35, 0.5, 0.2)))
    bpy.ops.object.light_add(type='SUN')
    s = bpy.context.object
    s.data.energy = 4
    s.rotation_euler = (math.radians(50), 0, math.radians(35))
    s.data.color = (1, 0.9, 0.75)
    s.data.angle = math.radians(6)
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    cam = bpy.data.cameras.new("c")
    co = link(bpy.data.objects.new("c", cam))
    sc.camera = co
    t = Vector(target)
    co.location = t + Vector((0, -dist * math.cos(math.radians(40)), dist * math.sin(math.radians(40))))
    co.rotation_euler = (math.radians(50), 0, 0)
    cam.lens = 40
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x = 800
    sc.render.resolution_y = 800
    sc.view_settings.view_transform = 'AgX'
    sc.render.filepath = os.path.join(OUT, "_preview_" + name + ".png")
    bpy.ops.render.render(write_still=True)
    print("preview", sc.render.filepath)
