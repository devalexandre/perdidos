"""Guias de pose PROPRIAS (manequim do nosso rig, corpo sem cabeca) para o kit do ChatGPT.
Baseado em .work/d/tools/guide_render.py; mesma camera/escala do render_chr.py (BODY_PX 78, pitch 35), canvas 208.

blender -b --python render_guides.py -- male --out .work/guides_pindorama/render [--ss 4] [--only walk:S]
Saida: <out>/<body>.npz  (<anim>_id [D,F,H,W] uint16 em px do canvas 208*ss) e <body>.json
       (partes, juntas 2D por quadro, ponto do pescoco = base do cranio).

Correcoes sobre o prototipo:
  * andar: bracos balancam de verdade (amplitude ~2x da do rig, cotovelo dobra no braco que vai a frente);
  * perfil L: o quadril e o tronco ficam de lado (o idle do rig torce a pelve; aqui a torcao e zerada no perfil).
"""
import sys, os, argparse, json, math
CH = "/home/devalexandre/projects/devalexandre/game-mmo/game/tools/art/blender/characters"
sys.path.insert(0, CH)
import bpy, bmesh, numpy as np
from mathutils import Euler, Vector
import chr_lib as C
import chr_qbody as QB

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("body")
ap.add_argument("--anims", default="idle:4,walk:8,attack_unarmed:6,cast:6,hit:3,death:5,sit:1")
ap.add_argument("--dirs", default="S,SE,E,NE,N")
ap.add_argument("--ss", type=int, default=4)
ap.add_argument("--pitch", type=float, default=35.0)
ap.add_argument("--swing", type=float, default=0.45, help="amplitude do balanco dos bracos (rad, maximo)")
ap.add_argument("--only", default="")
ap.add_argument("--out", required=True)
a = ap.parse_args(argv)

CANVAS, ORIGIN_FRAC, BODY_PX = 208, 0.62, 78.0   # canvas maior que o do jogo: a queda e o sentar nao saem do quadro
rig = QB.build(a.body, want=[])          # so o corpo (sem roupa, sem cabelo)
rig.anchor("head_base", rig.J["head"].matrix_world.translation.copy(), rig.J["head"])
# manequim inteiro (copia escondida pelo build) sem as faces da cabeca
src = rig.body_mesh
vg = {g.index: g.name for g in src.vertex_groups}
best = []
for v in src.data.vertices:
    w = max(v.groups, key=lambda g: g.weight, default=None)
    best.append(vg.get(w.group, "") if w else "")
bm = bmesh.new(); bm.from_mesh(src.data)
kill = [f for f in bm.faces if max(set(n := [best[v.index] for v in f.verts]), key=n.count) == "Head"]
bmesh.ops.delete(bm, geom=kill, context='FACES')
bm.to_mesh(src.data); bm.free(); src.data.update()
src.data.materials.clear(); src.data.materials.append(C.pass_material())
src["pid"] = float(rig.pid("torso", "skin", "mannequin"))
src.hide_render = False
rig.groups.setdefault("mannequin", []).append(src)
rig.save_rest()
rig.show_groups(["mannequin"])

sc = bpy.context.scene
p = math.radians(a.pitch)
ppm = BODY_PX / (1.729 * math.cos(p) + 0.14 * math.sin(p))
cam = C.setup_camera(a.pitch, CANVAS, a.ss, ppm, ORIGIN_FRAC)
os.makedirs(a.out, exist_ok=True)
exr = os.path.join(a.out, f"_frame_{a.body}.exr"); sc.render.filepath = exr
prio = np.ones(C.MAX_PIDS, np.float32)
for i, info in enumerate(rig.part_info[1:], 1):
    prio[i] = info.get('prio', 1.0)
arm = rig.arm
ARM_BONES = QB.ARM_BONES


def walk_arms(amp):
    """Refaz os bracos do andar com balanco amplo, em oposicao as coxas (fase medida na propria acao)."""
    bpy.context.view_layer.update()
    fwd = {}
    for s_ in ("l", "r"):
        pb = arm.pose.bones[f"thigh_{s_}"]
        d = (pb.tail - pb.head).normalized()
        fwd[s_] = -d.y
    m = max(1e-3, max(abs(fwd["l"]), abs(fwd["r"])))
    for pb in arm.pose.bones:
        if pb.name.split("_")[0] in ARM_BONES:
            pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    QB.relaxed(arm, arm_down=1.40, elbow=0.12)
    for s_, o_ in (("l", "r"), ("r", "l")):
        sw = max(-amp, min(amp, fwd[o_] / 0.45 * amp))   # a coxa oposta a frente -> braco a frente
        QB.rot_world(arm, f"upperarm_{s_}", (1, 0, 0), -sw)
        QB.rot_world(arm, f"lowerarm_{s_}", (1, 0, 0), -0.05 * max(0.0, sw))


def side_on():
    """Perfil: desfaz a torcao do quadril/tronco em torno do eixo vertical (o corpo fica realmente de lado)."""
    def yaw_of(lb, rb):
        bpy.context.view_layer.update()
        v = arm.pose.bones[lb].head - arm.pose.bones[rb].head   # eixo lateral (esq - dir) no armature
        return math.atan2(v.y, v.x)
    y = yaw_of("thigh_l", "thigh_r")          # quadril
    if abs(y) > 0.02:
        QB.rot_world(arm, "pelvis", (0, 0, 1), -y)
    y = yaw_of("upperarm_l", "upperarm_r")    # ombros
    if abs(y) > 0.02:
        QB.rot_world(arm, "spine_02", (0, 0, 1), -y)


dirs = [d for d in C.DIRS5 if d[0] in a.dirs.split(",")]
anims = [(s.split(":")[0], int(s.split(":")[1])) for s in a.anims.split(",")]
only = set(a.only.split(",")) if a.only else None
data, joints, neck = {}, {}, {}
N = CANVAS * a.ss
JN = list(rig.J.keys()) + ["heel_L", "toe_L", "heel_R", "toe_R", "head_base"]
for anim, nfr in anims:
    ds = [d for d in dirs if only is None or f"{anim}:{d[0]}" in only]
    ids = np.zeros((len(ds), nfr, N, N), np.uint16)
    joints[anim], neck[anim] = {}, {}
    for di, (dn, ang) in enumerate(ds):
        jrow, nrow = [], []
        for f in range(nfr):
            rig.reset_pose(); rig.cur_dir = ang
            QB.pose(rig, anim, f, nfr)
            if anim == "walk":
                walk_arms(a.swing)
            if dn == "E" and anim in ("idle", "walk") and not os.environ.get("NO_SIDE"):
                side_on()
            if anim not in ("death", "sit"):
                import chr_anim as A
                A.lock_ground(rig)
            if anim == "sit":   # centra o quadril na origem (a acao senta atras e as pernas saiam do canvas)
                bpy.context.view_layer.update()
                pel = arm.matrix_world @ arm.pose.bones["pelvis"].head
                rig.root.location.x -= pel.x; rig.root.location.y -= pel.y - 0.06
            rig.turn.rotation_euler = Euler((0, 0, math.radians(ang)))
            bpy.context.view_layer.update()
            jr = {}
            for k in JN:
                o = rig.J.get(k) or rig.anchors.get(k)
                x, y, z = C.project(cam, o.matrix_world.translation, N)
                jr[k] = [round(x / a.ss, 3), round(y / a.ss, 3), round(z, 4)]
            jrow.append(jr); nrow.append(jr["head_base"][:2])
            bpy.ops.render.render(write_still=True)
            P_, D_, NX, NY = C.reduce_frame(exr, 1, prio)
            ids[di, f] = P_
            print("[guide]", a.body, anim, dn, f, flush=True)
        joints[anim][dn] = jrow; neck[anim][dn] = nrow
    data[f"{anim}_id"] = ids
    data[f"{anim}_dirs"] = np.array([d[0] for d in ds])
np.savez_compressed(os.path.join(a.out, f"{a.body}.npz"), **data)
json.dump(dict(parts=rig.part_info, joints=joints, neck=neck, canvas=CANVAS, origin=[CANVAS / 2, CANVAS * ORIGIN_FRAC], ss=a.ss, pitch=a.pitch,
               anims=anims, dirs=[d[0] for d in dirs]), open(os.path.join(a.out, f"{a.body}.json"), "w"))
if os.path.exists(exr):
    os.remove(exr)
print("[guide] ok")
