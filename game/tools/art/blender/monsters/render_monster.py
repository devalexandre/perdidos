"""Renderiza um monstro (todas as animacoes x 5 direcoes) para o pos-processamento (post.py).
  .tools/blender/blender -b --python game/tools/art/blender/monsters/render_monster.py -- <id> <estagio>
       [--pitch 55] [--work .work/b3] [--anims idle:8,walk:8,...] [--dirs S,E] [--no-blend]
Saidas: <work>/npz/<id>_s<n>.npz (+ .json com a tabela de pecas) e o modelo em repouso em
game/tools/art/blender/monsters/blend/<id>_s<n>.blend."""
import sys, os, importlib, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import mon_rig as R

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("id"); ap.add_argument("stage", type=int)
ap.add_argument("--pitch", type=float, default=55.0)
ap.add_argument("--work", default=os.path.join(ROOT, ".work", "b3"))
ap.add_argument("--anims", default="")
ap.add_argument("--dirs", default="")
ap.add_argument("--no-blend", action="store_true")
ap.add_argument("--zoom", type=int, default=1, help="depuracao: modelo e quadro z vezes maiores (nao instalar)")
a = ap.parse_args(argv)
mod = importlib.import_module(a.id)
# GDD 17.2: pequeno 64, medio 96, grande 144, chefe 240
frame = mod.FRAME[a.stage] * a.zoom
anims = getattr(mod, "ANIMS", [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)])
if a.anims:
    anims = [(s.split(":")[0], int(s.split(":")[1])) for s in a.anims.split(",")]
canvas = (int(frame * 1.5) + 1) // 2 * 2
ss = 4 if frame <= 96 else (3 if frame <= 144 else 2)
if a.zoom > 1:
    ss = 2
rig = mod.build(a.stage)
if a.zoom > 1:
    rig.turn.scale = rig.turn.scale * a.zoom
    rig.rest["turn"] = (rig.turn.location.copy(), rig.turn.rotation_euler.copy(), rig.turn.scale.copy())
R.setup_camera(a.pitch, canvas, ss, origin_frac=getattr(mod, "ORIGIN_FRAC", 0.64))
os.makedirs(os.path.join(a.work, "npz"), exist_ok=True)
if not a.no_blend:
    bd = os.path.join(HERE, "blend"); os.makedirs(bd, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0  # sem .blend1
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bd, f"{a.id}_s{a.stage}.blend"), compress=True)
out = os.path.join(a.work, "npz", f"{a.id}_s{a.stage}{'_zoom' if a.zoom > 1 else ''}.npz")
R.render_all(rig, mod.pose, anims, out, os.path.join(a.work, "tmp", f"{a.id}_s{a.stage}"), canvas, ss, a.stage,
             only_dirs=a.dirs.split(",") if a.dirs else None)
import json
m = json.load(open(out[:-4] + ".json")); m.update(frame=frame, pitch=a.pitch, ss=ss)
json.dump(m, open(out[:-4] + ".json", "w"), indent=1)
print("[mon] ok", out)
