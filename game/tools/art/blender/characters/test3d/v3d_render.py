"""TESTE Viajante 3D: poses + render (Blender). Saida no mesmo formato de passes do pipeline (pid/prof/normal) para
o v3d_post.py.

  .tools/blender/blender -b --python game/tools/art/blender/characters/test3d/v3d_render.py -- <male|female>
        [--variants traveler,hunter] [--anims idle:4,walk:8,attack_bow:6] [--pitch 35] [--work DIR] [--dirs S,SE]

Duas tecnicas do tutorial (How to Make Animated PIXEL ART Characters Sprites with Blender):
  1. animacao "em dois": cada quadro da folha e uma POSE-CHAVE feita a mao (sem intermediarios automaticos) e as
     chaves ficam SEGURADAS: na linha do tempo do .blend as chaves ficam a cada 2 quadros com interpolacao CONSTANTE;
  2. pixel estavel: a origem do mundo cai numa borda de pixel e, a cada quadro, a raiz do personagem e o pivo da
     cabeca sao ENCAIXADOS na grade de pixels da camera (o rosto nao treme entre quadros).
"""
import sys, os, argparse, json, math, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import numpy as np
from mathutils import Vector, Euler, Matrix
import v3d_model as VM
import chr_lib as C

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("body")
ap.add_argument("--variants", default="traveler,hunter")
ap.add_argument("--anims", default="idle:4,walk:8,attack_bow:6")
ap.add_argument("--pitch", type=float, default=35.0)
ap.add_argument("--work", default=os.path.join(ROOT, ".work", "v3d"))
ap.add_argument("--dirs", default="")
ap.add_argument("--ss", type=int, default=4)
ap.add_argument("--px", type=float, default=80.0, help="altura em px do cranio (sem cabelo) ate a sola")
ap.add_argument("--threads", type=int, default=8)
ap.add_argument("--blend", action="store_true")
ap.add_argument("--lean", type=float, default=12.0, help="inclina o boneco para tras (graus, pivo no chao): rosto de frente")
a = ap.parse_args(argv)

CANVAS = 144
ORIGIN_FRAC = 115 / 144     # origem (pes) numa borda de pixel
anims = [(s.split(":")[0], int(s.split(":")[1])) for s in a.anims.split(",")]
dirs = list(C.DIRS5)
if a.dirs:
    dirs = [d for d in dirs if d[0] in a.dirs.split(",")]

rig = VM.build(a.body)
lean = bpy.data.objects.new("lean", None); bpy.context.scene.collection.objects.link(lean)
rig.turn.parent = lean
lean.rotation_euler.x = -math.radians(a.lean)
sp = rig.sp
H = sp["hip"]
sc = bpy.context.scene
sc.render.use_persistent_data = False
sc.render.threads_mode = 'FIXED'
sc.render.threads = a.threads
p = math.radians(a.pitch)
top = rig.hc.z + sp["head"][2]
ppm = a.px / (top * math.cos(p) + 0.10 * math.sin(p))
cam = C.setup_camera(a.pitch, CANVAS, a.ss, ppm, ORIGIN_FRAC)
PX = 1.0 / ppm


# --------------------------------------------------------------------------------------------- utilitarios
def R(name):
    return rig.j(name).rotation_euler


def upd():
    bpy.context.view_layer.update()


def snap(node):
    """Encaixa a posicao (mundo) do pivo na grade de pixels da camera (tecnica 2 do tutorial)."""
    upd()
    w = node.matrix_world.translation
    Rm = cam.matrix_world.to_3x3()
    right, up = Rm.col[0], Rm.col[1]
    sx, sy = w.dot(right) / PX, w.dot(up) / PX
    dw = right * ((round(sx) - sx) * PX) + up * ((round(sy) - sy) * PX)
    pm = node.parent.matrix_world.to_3x3().inverted() if node.parent else Matrix.Identity(3)
    node.location += pm @ dw


def lock_ground():
    upd()
    zs = [rig.anchors[n].matrix_world.translation.z for n in ("heel_l", "toe_l", "heel_r", "toe_r")]
    rig.root.location.z -= min(zs)


def to_local(node, wpos):
    return node.matrix_world.inverted() @ wpos


def ik_arm(nm, target_root, pole_root):
    """IK analitico de 2 ossos: mao (pulso) em target (espaco da raiz), cotovelo para o lado de pole."""
    upd()
    rootm = rig.root.matrix_world
    tgt = rootm @ Vector(target_root)
    pole = rootm.to_3x3() @ Vector(pole_root)
    sh, el, hd = rig.j(f"shoulder_{nm}"), rig.j(f"elbow_{nm}"), rig.j(f"hand_{nm}")
    a = (Vector(rig.world_loc[f"elbow_{nm}"]) - Vector(rig.world_loc[f"shoulder_{nm}"])).length
    b = (Vector(rig.world_loc[f"hand_{nm}"]) - Vector(rig.world_loc[f"elbow_{nm}"])).length
    S = sh.matrix_world.translation
    d = tgt - S
    L = min(max(d.length, abs(a - b) + 1e-3), a + b - 1e-3)
    dn = d.normalized()
    ca = (a * a + L * L - b * b) / (2 * a * L)
    al = math.acos(max(-1, min(1, ca)))
    pp = (pole - dn * pole.dot(dn)).normalized()
    E = S + dn * (a * math.cos(al)) + pp * (a * math.sin(al))
    # ombro: direcao de repouso (no espaco do pai) -> direcao desejada
    rest_dir = (Vector(rig.world_loc[f"elbow_{nm}"]) - Vector(rig.world_loc[f"shoulder_{nm}"])).normalized()
    pinv = sh.parent.matrix_world.to_3x3().inverted()
    want = (pinv @ (E - S)).normalized()
    q = rest_dir.rotation_difference(want)
    sh.rotation_euler = q.to_euler('XYZ')
    upd()
    rest2 = (Vector(rig.world_loc[f"hand_{nm}"]) - Vector(rig.world_loc[f"elbow_{nm}"])).normalized()
    pinv = el.parent.matrix_world.to_3x3().inverted()
    want2 = (pinv @ (S + dn * L - el.matrix_world.translation)).normalized()
    el.rotation_euler = rest2.rotation_difference(want2).to_euler('XYZ')
    upd()


def rest_arms(open_=0.10):
    R("shoulder_l").y -= open_
    R("shoulder_r").y += open_
    R("elbow_l").x -= 0.12
    R("elbow_r").x -= 0.12


# --------------------------------------------------------------------------------------------- poses-chave
def pose_idle(i, n):
    """2 chaves seguradas 2 quadros cada (A A B B): respiracao de 1 px, bracos abrem um pouco."""
    k = 1 if i >= n // 2 else 0
    rest_arms(0.10 + 0.04 * k)
    rig.j("chest").location.z += PX * 0.9 * k / math.cos(p)
    R("chest").x += 0.02 * k
    R("head").x -= 0.03 * k
    R("elbow_l").x -= 0.05 * k; R("elbow_r").x -= 0.05 * k
    if "tail" in rig.joints:
        R("tail").x += 0.06 * k


WALK = dict(  # graus; quadro 0 = contato (perna esquerda na frente), 1 baixo, 2 passagem, 3 alto, 4.. espelho
    thigh=[-26, -16, -2, 12, 22, 12, -8, -22],
    knee=[6, 20, 8, 10, 16, 48, 54, 24],
)


def pose_walk(i, n):
    rest_arms(0.08)
    for nm, off in (("l", 0), ("r", 4)):
        f = (i + off) % 8
        th = WALK["thigh"][f]; kn = WALK["knee"][f]
        R(f"thigh_{nm}").x += math.radians(th)
        R(f"knee_{nm}").x += math.radians(kn)
        R(f"ankle_{nm}").x += -math.radians(th + kn) * (0.85 if kn < 30 else 0.4)
        R(f"shoulder_{nm}").x += -math.radians(th) * 1.0
        R(f"elbow_{nm}").x += -math.radians(10 + max(0, -th) * 0.9)
    R("hips").x += 0.06
    R("chest").x += 0.02
    R("head").x -= 0.06
    R("chest").z += math.radians(5) * (1 if i % 8 in (0, 1, 7) else -1 if i % 8 in (3, 4, 5) else 0)
    if "tail" in rig.joints:
        R("tail").x += 0.10 + 0.10 * (1 if i % 4 in (1, 2) else 0)
        R("tail").y += 0.08 * (1 if i % 8 < 4 else -1)


# arco: alvos dos pulsos no espaco da raiz (frente = -Y), corda puxada ate o queixo
BOW = [
    # (yaw quadril, yaw peito, mao esq, mao dir, polo esq, polo dir, arco_inclina, flecha, puxada)
    (-0.20, -0.25, (0.09, -0.12, 0.10), (0.00, -0.12, 0.08), (1, 0.3, -1), (-1, 0.3, -1), 0.9, False, 0.0),
    (-0.40, -0.55, (0.05, -0.19, 0.21), (0.02, -0.15, 0.20), (1, 0, -1), (-1, 0.5, 0.2), 0.12, True, 0.0),
    (-0.45, -0.65, (0.04, -0.20, 0.22), (-0.03, -0.06, 0.22), (1, 0, -1), (-1, 0.5, 0.6), 0.10, True, 0.5),
    (-0.48, -0.72, (0.035, -0.21, 0.225), (-0.065, 0.01, 0.235), (1, 0, -1), (-1, 0.3, 0.8), 0.10, True, 1.0),
    (-0.48, -0.72, (0.035, -0.21, 0.225), (-0.12, 0.07, 0.25), (1, 0, -1), (-1, 0.4, 0.6), 0.10, False, 0.0),
    (-0.30, -0.40, (0.08, -0.16, 0.13), (-0.10, 0.02, 0.10), (1, 0.2, -1), (-1, 0.3, -1), 0.6, False, 0.0),
]


def pose_bow(i, n):
    yh, yc, hl, hr, pl, pr, tilt, arrow, draw = BOW[min(i, len(BOW) - 1)]
    R("hips").z += yh
    R("chest").z += yc - yh
    R("head").z -= yc * 0.85
    R("head").x -= 0.04
    # pernas abertas (base de tiro)
    R("thigh_l").x -= 0.25; R("thigh_l").y -= 0.10
    R("thigh_r").x += 0.20; R("thigh_r").y += 0.10
    R("knee_l").x += 0.15; R("knee_r").x += 0.12
    R("ankle_l").x += 0.05; R("ankle_r").x -= 0.25
    Hh = H
    ik_arm("l", (hl[0], hl[1], Hh + hl[2]), pl)
    ik_arm("r", (hr[0], hr[1], Hh + hr[2]), pr)
    rig.pose_extra = dict(tilt=tilt, arrow=arrow, draw=draw)


POSES = {"idle": pose_idle, "walk": pose_walk, "attack_bow": pose_bow}


def place_bow(show):
    """Arco na mao esquerda, vertical, curvatura para o arqueiro; corda ate a mao direita se puxada."""
    upd()
    ex = getattr(rig, "pose_extra", None) or dict(tilt=0.0, arrow=False, draw=0.0)
    hl = rig.j("hand_l").matrix_world.translation + (rig.j("hand_l").matrix_world.to_3x3() @ Vector((0, 0, -0.03)))
    rootm = rig.root.matrix_world
    b = rig.j("bow")
    b.location = rootm.inverted() @ hl
    b.rotation_euler = Euler((ex["tilt"], -0.12, 0.0))
    upd()
    top = rig.anchors["bow_top"].matrix_world.translation
    bot = rig.anchors["bow_bot"].matrix_world.translation
    grip = b.matrix_world.translation
    back = (b.matrix_world.to_3x3() @ Vector((0, 1, 0))).normalized()   # para o arqueiro
    if ex["draw"] > 0:
        nock = rig.anchors["nock"].matrix_world.translation + (rig.j("hand_r").matrix_world.to_3x3() @ Vector((0, 0, -0.02)))
    else:
        nock = (top + bot) / 2 + back * (0.07 + (0.035 if ex["arrow"] else 0.0))
    if ex["arrow"] and ex["draw"] == 0:
        nock = grip + back * 0.10

    def stretch(o, p0, p1):
        d = p1 - p0
        L = max(d.length, 1e-4)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        o.matrix_world = Matrix.Translation(p0) @ rot @ Matrix.Diagonal((1, 1, L, 1))
    o = bpy.data.objects
    stretch(o["string_a"], top, nock)
    stretch(o["string_b"], bot, nock)
    fwd = (grip - nock).normalized()
    stretch(o["arrow"], nock - fwd * 0.01, grip + fwd * 0.08)
    stretch(o["arrowhead"], grip + fwd * 0.07, grip + fwd * 0.12)
    for nm in ("arrow", "arrowhead"):
        o[nm].hide_render = not (show and ex["arrow"])


# --------------------------------------------------------------------------------------------- render
outdir = os.path.join(a.work, "npz", a.body); os.makedirs(outdir, exist_ok=True)
tmp = os.path.join(a.work, "tmp", a.body); os.makedirs(tmp, exist_ok=True)
exr = os.path.join(tmp, "frame.exr")
sc.render.filepath = exr
prio = np.ones(C.MAX_PIDS, np.float32)
for i, info in enumerate(rig.part_info[1:], 1):
    prio[i] = info.get("prio", 1.0)
hair = f"hair:{sp['hair']}"
keyed = [rig.root, rig.turn] + [o for k, o in rig.joints.items() if k not in ("root", "turn")]
tl = 1          # linha do tempo do .blend: chave a cada 2 quadros ("em dois")
markers = []
t0 = time.time()
for var in a.variants.split(","):
    data = {}
    for anim, nfr in anims:
        groups = ["body", hair, f"outfit:{var}"] + (["weapon:bow"] if anim == "attack_bow" else [])
        rig.show_groups(groups)
        ND = len(dirs)
        arr = [np.zeros((ND, nfr, CANVAS, CANVAS), np.uint16), np.ones((ND, nfr, CANVAS, CANVAS), np.float32),
               np.zeros((ND, nfr, CANVAS, CANVAS), np.float16), np.zeros((ND, nfr, CANVAS, CANVAS), np.float16)]
        markers.append((f"{var}:{anim}", tl))
        for di, (dname, ang) in enumerate(dirs):
            for f in range(nfr):
                rig.reset_pose()
                rig.pose_extra = None
                rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
                POSES[anim](f, nfr)
                lock_ground()
                snap(rig.root)
                snap(rig.j("head"))
                if anim == "attack_bow":
                    place_bow(True)
                if a.blend and di == 0:
                    for o in keyed:
                        o.keyframe_insert("location", frame=tl); o.keyframe_insert("rotation_euler", frame=tl)
                    tl += 2
                bpy.ops.render.render(write_still=True)
                P_, D_, NX, NY = C.reduce_frame(exr, a.ss, prio)
                arr[0][di, f] = P_; arr[1][di, f] = D_; arr[2][di, f] = NX; arr[3][di, f] = NY
        data[f"{anim}_id"], data[f"{anim}_d"], data[f"{anim}_nx"], data[f"{anim}_ny"] = arr
        print(f"[v3d] {a.body} {var} {anim}: {nfr} q x {len(dirs)} dir ({time.time() - t0:.1f}s)", flush=True)
    meta = dict(body=a.body, variant=var, canvas=CANVAS, pitch=a.pitch, ss=a.ss, ppm=ppm, origin_frac=ORIGIN_FRAC,
                dirs=[d[0] for d in dirs], anims=[[x, n] for x, n in anims], parts=rig.part_info)
    np.savez_compressed(os.path.join(outdir, f"{var}.npz"), **data)
    json.dump(meta, open(os.path.join(outdir, f"{var}.json"), "w"))
if a.blend:
    for o in keyed:
        if o.animation_data and o.animation_data.action:
            act = o.animation_data.action
            fcs = getattr(act, "fcurves", None)
            if fcs is None:   # Blender 5: acoes em camadas
                fcs = [fc for l in act.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
            for fc in fcs:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'CONSTANT'
    for nm, fr in markers:
        sc.timeline_markers.new(nm, frame=fr)
    sc.frame_start, sc.frame_end = 1, tl
    rig.show_groups(list(rig.groups.keys()))
    bd = os.path.join(HERE, "blend"); os.makedirs(bd, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bd, f"v3d_{a.body}.blend"), compress=True)
if os.path.exists(exr):
    os.remove(exr)
print("[v3d] ok", outdir, f"{time.time() - t0:.1f}s")
