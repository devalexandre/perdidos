"""Base PRONTA (CC0, Quaternius) para o personagem: corpo com esqueleto humanoide de 65 ossos (padrao UE), cabelos,
roupas modulares e as bibliotecas de animacao UAL1/UAL2 no MESMO esqueleto. Licencas em
game/assets/characters/LICENSES.md. Os pacotes ficam em .work/c3/packs/ (fora do jogo; os zips em game/downloads/).

O que este modulo faz (lado do Blender):
  * importa o corpo (Superhero_<Male|Female>_FullBody), apaga olhos/sobrancelhas 3D (os olhos sao desenhados em
    pixel art pela camada de olhos) e liga as malhas ao material de passes (pid por objeto / por material);
  * importa as acoes de UAL1 e UAL2 e toca qualquer uma por nome e fase (0..1) no esqueleto do corpo;
  * ajusta a proporcao para o padrao do jogo (GDD §17.0.B, ~5,7 cabecas): cabeca maior, tronco/membros mais finos
    (escala de pose por osso, sem mexer na malha);
  * cria os PIVOS com os nomes que o resto do pipeline usa (pelvis, chest, head, uarm_L ... foot_R), presos aos ossos,
    para que as pecas procedurais (roupas, bolsa, chapeus, armas, ancoras do rosto e dos pes) sigam a animacao."""
import os, sys, math
import bpy
from mathutils import Vector as V, Matrix
import chr_lib as C

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
PACKS = os.path.join(ROOT, ".work", "c3", "packs")
UBC = os.path.join(PACKS, "universal-base-characters", "Universal Base Characters[Standard]")
UAL1 = os.path.join(PACKS, "universal-animation-library", "Universal Animation Library[Standard]", "Unreal-Godot", "UAL1_Standard.glb")
UAL2 = os.path.join(PACKS, "universal-animation-library-2", "Universal Animation Library 2[Standard]", "Unreal-Godot", "UAL2_Standard.glb")
OUTFITS = os.path.join(PACKS, "modular-outfits-fantasy", "Modular Character Outfits - Fantasy[Standard]", "Exports",
                       "glTF (Godot-Unreal)")
HAIRS = os.path.join(UBC, "Hairstyles", "Rigged to Head Bone", "glTF (Godot -Unreal)")

# pivo do pipeline -> osso Quaternius
BONE_OF = {"pelvis": "pelvis", "spine": "spine_01", "chest": "spine_03", "neck": "neck_01", "head": "Head",
           "uarm_L": "upperarm_l", "farm_L": "lowerarm_l", "hand_L": "hand_l", "uarm_R": "upperarm_r",
           "farm_R": "lowerarm_r", "hand_R": "hand_r", "thigh_L": "thigh_l", "shin_L": "calf_l", "foot_L": "foot_l",
           "thigh_R": "thigh_r", "shin_R": "calf_r", "foot_R": "foot_r"}


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def load_base(body):
    """Importa o corpo + acoes. Retorna (armature, [malhas do corpo])."""
    fn = os.path.join(UBC, "Base Characters", "Godot - UE", f"Superhero_{'Male' if body == 'male' else 'Female'}_FullBody.gltf")
    objs = _import(fn)
    arm = next(o for o in objs if o.type == 'ARMATURE')
    arm.name = "QArmature"
    meshes = []
    for o in objs:
        if o.type == 'MESH' and (o.parent is None or o.name.startswith("Icosphere")):
            bpy.data.objects.remove(o)
        elif o.type == 'MESH' and (o.name.startswith("Eyes") or o.name.startswith("Eyebrows")):
            bpy.data.objects.remove(o)
        elif o.type == 'MESH':
            meshes.append(o)
    # acoes (UAL1 + UAL2): importa e descarta os manequins
    for path in (UAL1, UAL2):
        for o in _import(path):
            bpy.data.objects.remove(o, do_unlink=True)
    strip_scale_curves()
    return arm, meshes


def _fcurve_lists(act):
    if hasattr(act, "layers") and act.layers:
        for layer in act.layers:
            for strip in layer.strips:
                for cb in getattr(strip, "channelbags", []):
                    yield cb.fcurves
    elif hasattr(act, "fcurves"):
        yield act.fcurves


def strip_scale_curves():
    """As acoes chaveiam a escala de todos os ossos; sem isso a escala de pose (proporcao) nao valeria."""
    for act in bpy.data.actions:
        for fcs in _fcurve_lists(act):
            for fc in [f for f in fcs if f.data_path.endswith(".scale")]:
                fcs.remove(fc)


def import_parts(path, arm):
    """Importa pecas (roupa/cabelo) riggadas no mesmo esqueleto e religa ao armature do corpo."""
    objs = _import(path)
    out = []
    for o in objs:
        if o.type == 'MESH' and o.parent is not None and o.parent.type == 'ARMATURE':
            # Mantem a relacao LOCAL com o esqueleto (como as malhas do corpo), nao a posicao no mundo: o armature
            # do corpo ja foi escalado para a altura (arm.scale = g); copiar matrix_world deixava a peca em tamanho
            # cheio no espaco 1/g do esqueleto, e com g longe de 1 (crianca, height < 1) o modificador Armature
            # deformava a peca pelos ossos errados (bracos em T, cabeca sumindo). Adulto: g ~ 1, diferenca minima.
            pinv, basis = o.matrix_parent_inverse.copy(), o.matrix_basis.copy()
            o.parent = arm
            o.matrix_parent_inverse = pinv
            o.matrix_basis = basis
            for m in o.modifiers:
                if m.type == 'ARMATURE':
                    m.object = arm
            out.append(o)
    for o in objs:
        if o not in out:
            bpy.data.objects.remove(o, do_unlink=True)
    return out


def set_action(arm, name, phase, loop=True):
    """Pose do esqueleto na fase (0..1) da acao `name` (UAL1/UAL2)."""
    act = bpy.data.actions[name]
    ad = arm.animation_data or arm.animation_data_create()
    if ad.action != act:
        ad.action = act
        if hasattr(ad, "action_slot") and act.slots:
            ad.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    if loop:
        f = f0 + (f1 - f0) * (phase % 1.0)
    else:
        f = f0 + (f1 - f0) * min(1.0, max(0.0, phase))
    bpy.context.scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))


def bind_joints(rig, arm):
    """Pivos do pipeline presos aos ossos (mesmos nomes do esqueleto procedural)."""
    bpy.context.view_layer.update()
    J = {}
    for jn, bn in BONE_OF.items():
        pb = arm.pose.bones[bn]
        head = arm.matrix_world @ pb.head
        e = bpy.data.objects.new(jn, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = arm
        e.parent_type = 'BONE'
        e.parent_bone = bn
        bpy.context.view_layer.update()
        e.matrix_world = Matrix.Translation(head)
        rig.world_loc[jn] = head.copy()
        rig.nodes[jn] = e
        rig.joints[jn] = e
        J[jn] = e
    return J


def pass_meshes(rig, meshes, group, part_of_mat, default=("skin", "skin")):
    """Liga malhas riggadas ao material de passes, SEM reparentar (o armature continua deformando).
    part_of_mat(nome_do_material) -> (peca, material_do_pos) define o pid por face (atributo fpid)."""
    for o in meshes:
        names = [m.name if m else "" for m in o.data.materials]
        me = o.data
        attr = me.attributes.get("fpid") or me.attributes.new("fpid", 'FLOAT', 'FACE')
        pids = []
        for n in names:
            part, mat = part_of_mat(n) or default
            pids.append(float(rig.pid(part, mat, group)))
        vals = [pids[p.material_index] if p.material_index < len(pids) else pids[0] for p in me.polygons]
        attr.data.foreach_set("value", vals)
        me.update()
        o["pid"] = float(rig.pid(*(part_of_mat(names[0]) or default), group) if names else rig.pid(default[0], default[1], group))
        me.materials.clear()
        me.materials.append(C.pass_material())
        rig.meshes.append(o)
        rig.groups.setdefault(group, []).append(o)
        o["group"] = group


# ------------------------------------------------------------------ cor da textura por face (roupas modulares)
_TEX_CACHE = {}


def _tex_array(img):
    """Textura (bpy image) -> array numpy RGB 0..1 reduzida a 512 px (amostragem por face)."""
    import numpy as np
    key = img.filepath or img.name
    if key in _TEX_CACHE:
        return _TEX_CACHE[key]
    arr = None
    try:
        venv = os.path.join(ROOT, ".tools", "pyvenv", "lib", "python3.13", "site-packages")
        if venv not in sys.path:
            sys.path.append(venv)          # Pillow do venv do projeto (mesmo Python 3.13 do Blender)
        from PIL import Image
        path = bpy.path.abspath(img.filepath)
        arr = np.asarray(Image.open(path).convert("RGB").resize((512, 512)), dtype=np.float32) / 255.0
    except Exception:
        w, h = img.size
        px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px)
        arr = px.reshape(h, w, 4)[::-1, :, :3]
        step = max(1, w // 512)
        arr = arr[::step, ::step]
    _TEX_CACHE[key] = arr
    return arr


def _mat_image(mat):
    if mat is None or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            inp = n.inputs.get("Base Color")
            if inp and inp.is_linked:
                src = inp.links[0].from_node
                if src.type == 'TEX_IMAGE':
                    return src.image
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            return n.image
    return None


def color_class(rgb):
    """Classe de cor de uma amostra: light, green, dkgreen, brown, dark, gray, blue, red."""
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    if v < 0.10:
        return "dark"
    if 0.17 < h < 0.48 and s > 0.22:
        return "green" if v > 0.22 else "dkgreen"
    if 0.52 < h < 0.72 and s > 0.20:
        return "blue"
    if s < 0.16:
        return "light" if v > 0.55 else ("gray" if v > 0.28 else "dark")
    if v > 0.55 and s < 0.35:
        return "light"
    if (h < 0.03 or h > 0.93) and s > 0.45:
        return "red"
    return "brown" if v > 0.16 else "dark"


def face_colors(o):
    """[(classe, rgb)] por face, pela cor da textura no centro UV da face."""
    import numpy as np
    me = o.data
    uv = me.uv_layers.active.data if me.uv_layers.active else None
    out = []
    imgs = [(_mat_image(m), m) for m in me.materials]
    arrs = [(_tex_array(i) if i else None) for i, _ in imgs]
    for p in me.polygons:
        mi = min(p.material_index, len(arrs) - 1)
        arr = arrs[mi] if arrs else None
        if arr is None or uv is None:
            out.append(("light", (0.8, 0.8, 0.8))); continue
        us = [uv[li].uv for li in p.loop_indices]
        u = sum(x.x for x in us) / len(us); v = sum(x.y for x in us) / len(us)
        H, W = arr.shape[:2]
        x = int((u % 1.0) * (W - 1)); y = int((1.0 - (v % 1.0)) * (H - 1))
        rgb = tuple(float(c) for c in arr[y, x])
        out.append((color_class(rgb), rgb))
    return out


# referencias de cor das texturas (Peasant/Ranger) -> classe
REF_COLORS = {"cloth_light": [(147, 142, 118), (162, 166, 147), (139, 131, 106)],
              "cloth_dark": [(31, 18, 9), (28, 15, 7), (35, 21, 10), (51, 38, 34), (32, 18, 9), (44, 27, 12)],
              "brown": [(56, 36, 16), (81, 59, 33), (77, 55, 46), (55, 34, 16), (95, 76, 36), (78, 58, 26), (52, 34, 14),
                        (80, 52, 20), (104, 70, 28), (65, 42, 17)],
              "leather": [(74, 44, 24), (96, 60, 32), (84, 51, 28), (96, 61, 36), (116, 75, 44), (111, 70, 39),
                          (128, 84, 45), (89, 54, 30), (121, 81, 47), (69, 41, 23)],
              "green": [(51, 81, 29), (39, 70, 22), (74, 101, 41)],
              "dkgreen": [(6, 26, 11), (8, 28, 13), (11, 33, 16), (15, 38, 17), (23, 49, 25), (10, 32, 13)],
              "metal": [(129, 143, 133), (108, 118, 111), (155, 176, 166), (134, 150, 141), (140, 151, 136),
                        (122, 135, 127), (159, 167, 150), (186, 204, 176), (148, 169, 160), (110, 121, 114)]}


def ref_class(rgb):
    c = tuple(x * 255 for x in rgb)
    best, bk = 1e9, "brown"
    for k, refs in REF_COLORS.items():
        for r in refs:
            d = sum((a - b) ** 2 for a, b in zip(c, r))
            if d < best:
                best, bk = d, k
    return bk
