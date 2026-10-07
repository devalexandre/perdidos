"""Renderiza o personagem jogavel (todas as animacoes x direcoes x conjuntos de camadas) para o chr_post.py.

  .tools/blender/blender -b --python game/tools/art/blender/characters/render_chr.py -- <male|female>
       [--pitch 35] [--anims idle:8,walk:8] [--sets outfit:traveler,hair:spiky] [--dirs S,SE] [--dirs8]
       [--work .work/c3] [--threads 6] [--no-blend]

Conjuntos (cada um e uma renderizacao por quadro; o pos-processamento separa as camadas pelo grupo das pecas):
  outfit:<id>   corpo + roupa                       -> folha do corpo (com mascara de pele)
  hair:<id>     corpo + Viajante + cabelo           -> so os pixels do cabelo (ja com oclusao da cabeca)
  head:<id>     corpo + chapeu                      -> so o chapeu
  ear:<id>      corpo + brinco                      -> so o brinco
  weapon:<id>   corpo + Viajante + arma             -> arma na frente (oclusao pelo corpo)
  weaponb:<id>  so a arma                           -> arma atras do corpo (variante _back, linhas NE/N)
Saidas: <work>/npz/<body>/<set>.npz (+ .json: pecas, ancoras por quadro, camera) e o modelo em
game/tools/art/blender/characters/blend/chr_<body>.blend."""
import sys, os, argparse, json, time, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import numpy as np
from mathutils import Euler
import chr_lib as C
import chr_body as B
import chr_anim as A

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("body")
ap.add_argument("--pitch", type=float, default=35.0)
ap.add_argument("--anims", default="")
ap.add_argument("--sets", default="")
ap.add_argument("--dirs", default="")
ap.add_argument("--dirs8", action="store_true")
ap.add_argument("--work", default=os.path.join(ROOT, ".work", "c3"))
ap.add_argument("--threads", type=int, default=6)
ap.add_argument("--ss", type=int, default=4)
ap.add_argument("--no-blend", action="store_true")
ap.add_argument("--base", default="q", choices=["q", "proc"], help="q = base pronta Quaternius; proc = corpo procedural")
a = ap.parse_args(argv)

CANVAS = 144          # quadro final 96 + folga (recorte fixo no pos)
ORIGIN_FRAC = 0.80    # pes (origem) nesta fracao da altura do canvas
BODY_PX = 78.0        # cranio (sem cabelo) ate a ponta do pe, em px, no corpo masculino

anims = A.ANIMS
if a.anims:
    anims = [(s.split(":")[0], int(s.split(":")[1])) for s in a.anims.split(",")]
dirs = list(C.DIRS5) + (list(C.DIRS_EXTRA) if a.dirs8 else [])
if a.dirs:
    dirs = [d for d in dirs if d[0] in a.dirs.split(",")]
if a.sets:
    sets = a.sets.split(",")
else:
    sets = ([f"outfit:{o}" for o in B.OUTFITS] + [f"hair:{h}" for h in B.HAIR[a.body]]) if a.body in B.HAIR else []


def set_groups(s):
    kind, vid = s.split(":")
    if kind == "outfit":
        return ["body", s]
    if kind == "hair":
        return ["body", "outfit:traveler", s]
    if kind in ("head", "ear"):
        return ["body", s]
    if kind == "weapon":
        return ["body", "outfit:traveler", s]
    if kind == "weaponb":
        return [f"weapon:{vid}"]
    if kind == "npc":
        return ["body", s]
    raise ValueError(s)


if a.body.startswith("npc:"):
    import chr_npc as NPC
    npc_id = a.body.split(":", 1)[1]
    rig = NPC.build(npc_id)
    sets = [a.body]
    cfg = rig.npc
    rig.posture = cfg.get("pose", {})
    if not a.anims:
        anims = [(x.split(":")[0], int(x.split(":")[1])) for x in cfg.get("anims", ["idle:8", "walk:8"])]
    a.body = f"npc_{npc_id}"
elif a.base == "q":
    import chr_qbody as QB
    rig = QB.build(a.body)
else:
    rig = B.build(a.body)  # sempre o modelo inteiro: tabela de pecas igual em todos os renders
POSE = A.pose
if getattr(rig, "base", "") == "quaternius":
    import chr_qbody as QB
    POSE = QB.pose
sc = bpy.context.scene
# persistent data + ligar/desligar grupos entre renders deixava quadros (ou pecas) vazios: desligado
sc.render.use_persistent_data = False
sc.render.threads_mode = 'FIXED'
sc.render.threads = a.threads
# escala: o corpo masculino (k=1) mede BODY_PX do cranio a ponta do pe na camera inclinada
p = math.radians(a.pitch)
h_proj = 1.729 * math.cos(p) + 0.14 * math.sin(p)
ppm = BODY_PX / h_proj
cam = C.setup_camera(a.pitch, CANVAS, a.ss, ppm, ORIGIN_FRAC)
if not a.no_blend:
    bd = os.path.join(HERE, "blend"); os.makedirs(bd, exist_ok=True)
    rig.show_groups(list(rig.groups.keys()))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bd, f"chr_{a.body}.blend"), compress=True)

outdir = os.path.join(a.work, "npz", a.body); os.makedirs(outdir, exist_ok=True)
tmp = os.path.join(a.work, "tmp", a.body); os.makedirs(tmp, exist_ok=True)
exr = os.path.join(tmp, "frame.exr")
sc.render.filepath = exr
prio = np.ones(C.MAX_PIDS, np.float32)
for i, info in enumerate(rig.part_info[1:], 1):
    prio[i] = info.get('prio', 1.0)
ND = len(dirs)
data = {s: {} for s in sets}
anchors = {}
t0 = time.time()
for anim, nfr in anims:
    arr = {s: (np.zeros((ND, nfr, CANVAS, CANVAS), np.uint16), np.ones((ND, nfr, CANVAS, CANVAS), np.float32),
               np.zeros((ND, nfr, CANVAS, CANVAS), np.float16), np.zeros((ND, nfr, CANVAS, CANVAS), np.float16))
           for s in sets}
    anchors[anim] = []
    for di, (dname, ang) in enumerate(dirs):
        row = []
        for f in range(nfr):
            rig.reset_pose()
            rig.cur_dir = ang
            POSE(rig, anim, f, nfr)
            rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
            row.append(C.frame_anchors(rig, cam, CANVAS))
            for s in sets:
                rig.show_groups(set_groups(s))
                bpy.ops.render.render(write_still=True)
                P_, D_, NX, NY = C.reduce_frame(exr, a.ss, prio)
                arr[s][0][di, f] = P_; arr[s][1][di, f] = D_; arr[s][2][di, f] = NX; arr[s][3][di, f] = NY
        anchors[anim].append(row)
    for s in sets:
        data[s][f"{anim}_id"], data[s][f"{anim}_d"], data[s][f"{anim}_nx"], data[s][f"{anim}_ny"] = arr[s]
    print(f"[chr] {a.body} {anim}: {nfr} q x {ND} dir x {len(sets)} conj ({time.time() - t0:.1f}s)", flush=True)

meta = dict(body=a.body, canvas=CANVAS, pitch=a.pitch, ss=a.ss, ppm=ppm, origin_frac=ORIGIN_FRAC,
            dirs=[d[0] for d in dirs], anims=[[x, n] for x, n in anims], parts=rig.part_info, anchors=anchors)
for s in sets:
    fn = os.path.join(outdir, s.replace(":", "__"))
    # acrescenta animacoes ja renderizadas antes (render incremental por animacao)
    old = {}
    if os.path.exists(fn + ".npz") and a.anims:
        try:
            z = np.load(fn + ".npz"); old = {k: z[k] for k in z.files}
            om = json.load(open(fn + ".json"))
        except Exception:
            old, om = {}, None
    else:
        om = None
    if om and om.get("dirs") == meta["dirs"] and om.get("pitch") == meta["pitch"]:
        keep = [x for x in om["anims"] if x[0] not in dict(anims)]
        merged = dict(old); merged.update(data[s])
        m2 = dict(meta); m2["anims"] = keep + meta["anims"]
        m2["anchors"] = {**{x[0]: om["anchors"][x[0]] for x in keep}, **anchors}
        # pids precisam bater: o modelo e deterministico, entao a tabela e a mesma
        np.savez_compressed(fn + ".npz", **merged)
        json.dump(dict(m2, set=s), open(fn + ".json", "w"))
    else:
        np.savez_compressed(fn + ".npz", **data[s])
        json.dump(dict(meta, set=s), open(fn + ".json", "w"))
if os.path.exists(exr):
    os.remove(exr)
print("[chr] ok", outdir, f"{time.time() - t0:.1f}s")
