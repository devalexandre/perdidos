"""Olha um modelo de pack antes de configurar a especie: renderiza o albedo (cores do pack) de frente (S), lado (E)
e costas (N) na camera do jogo e lista as cores mais usadas (para o COLORMAP) e os materiais.
  .tools/blender/blender -b --python game/tools/art/blender/monsters/pack_probe.py -- <modelo.gltf> [yaw] [acao]
Saida: .work/b3/packs/_probe/<nome>_albedo.png + cores no terminal."""
import sys, os, math, collections
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bpy
import numpy as np
from mathutils import Euler
import mon_rig as R
import pack_model as PM

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:]
path = argv[0]; yaw = float(argv[1]) if len(argv) > 1 else 0.0; act = argv[2] if len(argv) > 2 else None
R.reset()
rig = R.Rig("probe")
# colormap "tudo" para forcar a leitura por textura: uma entrada qualquer
pk = PM.import_model(rig, path, colormap=[("#ff00ff", "x", "skin")], yaw_deg=yaw, albedo_all=True)
PM.fit(pk, 1.2, act)
print("[probe] materiais:", sorted({s.material.name for o in pk.meshes for s in o.material_slots if s.material}))
if pk.armature:
    print("[probe] acoes:", [a.name for a in bpy.data.actions])
R.setup_camera(55, 160, 2)
sc = bpy.context.scene
outd = os.path.join(ROOT, ".work", "b3", "packs", "_probe"); os.makedirs(outd, exist_ok=True)
for o, k, pm, am in rig.albedo_slots:
    o.material_slots[k].material = am
# materiais lisos: albedo = cor base
strip = []
hist = collections.Counter()
for ang in (0, 90, 180):
    rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
    f = os.path.join(outd, "_p.exr"); sc.render.filepath = f
    bpy.ops.render.render(write_still=True)
    a = R._load_exr(f)
    rgb = np.clip(a[..., :3], 0, 1)
    srgb = (np.where(rgb > 0.0031308, 1.055 * np.power(rgb, 1 / 2.4) - 0.055, rgb * 12.92) * 255).astype(np.uint8)
    srgb[a[..., 3] < 0.5] = (40, 40, 40)
    strip.append(srgb)
    for c in srgb[a[..., 3] >= 0.5].reshape(-1, 3):
        hist[tuple(int(x) // 8 * 8 for x in c)] += 1
img = np.concatenate(strip, 1)
name = os.path.splitext(os.path.basename(path))[0]
bi = bpy.data.images.new("p", img.shape[1], img.shape[0])
px = np.concatenate([img[::-1].astype(np.float32) / 255, np.ones(img.shape[:2] + (1,), np.float32)], -1)
bi.pixels.foreach_set(px.ravel()); bi.filepath_raw = os.path.join(outd, f"{name}_albedo.png"); bi.file_format = 'PNG'; bi.save()
tot = sum(hist.values())
print("[probe] cores (sRGB/8, % da area):")
for c, n in hist.most_common(24):
    print(f"   #{c[0]:02x}{c[1]:02x}{c[2]:02x}  {100 * n / tot:5.1f}%")
print("[probe] ok", bi.filepath_raw)
