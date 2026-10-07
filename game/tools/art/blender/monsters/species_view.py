"""Vista rapida (depuracao) de uma especie: pose idle 0 renderizada em alta (EEVEE, cor por peca) de S, SE, E, N.
  .tools/blender/blender -b --python game/tools/art/blender/monsters/species_view.py -- <id> <estagio> [anim] [quadro]
Saida: .work/b3/look/view_<id>_s<n>.png"""
import sys, os, importlib, math, random
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bpy
from mathutils import Euler
import mon_rig as R

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:]
mid, st = argv[0], int(argv[1]); anim = argv[2] if len(argv) > 2 else "idle"; fr = int(argv[3]) if len(argv) > 3 else 0
mod = importlib.import_module(mid)
rig = mod.build(st)
nfr = dict(mod.ANIMS).get(anim, 8) if hasattr(mod, "ANIMS") else 8
random.seed(3)
cols = {}
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    for k, slot in enumerate(o.material_slots):
        m = bpy.data.materials.new("v"); m.diffuse_color = (random.random(), random.random(), random.random(), 1)
        slot.material = m
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'RANDOM'
sc.display.shading.show_object_outline = True
sc.render.film_transparent = False
R.setup_camera(55, mod.FRAME[st], 1)
sc.render.resolution_x = sc.render.resolution_y = 360
sc.render.image_settings.file_format = 'PNG'
outs = []
for ang in (0, 45, 90, 180):
    rig.reset_pose(); mod.pose(rig, anim, fr, nfr, st)
    rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
    f = os.path.join(ROOT, ".work", "b3", "look", f"_v{ang}.png"); sc.render.filepath = f
    bpy.ops.render.render(write_still=True); outs.append(f)
import numpy as np
ims = []
for f in outs:
    im = bpy.data.images.load(f); a = np.array(im.pixels[:]).reshape(360, 360, 4); ims.append(a)
strip = np.concatenate(ims, 1)
out = bpy.data.images.new("strip", strip.shape[1], strip.shape[0]); out.pixels.foreach_set(strip.astype(np.float32).ravel())
out.filepath_raw = os.path.join(ROOT, ".work", "b3", "look", f"view_{mid}_s{st}.png"); out.file_format = 'PNG'; out.save()
print("[view] ok", out.filepath_raw)
