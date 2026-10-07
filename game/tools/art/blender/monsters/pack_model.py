"""Adaptador de modelos PRONTOS (packs CC0: Quaternius, Kenney, KayKit...) para o pipeline de monstros.
Diretriz do dono (28/09/2026): "o que der para pegar pronto, pega e modifica". O modelo importado vira nosso:
  - cores: cada material liso vira uma peca (MATMAP: nome do material -> rampa de post.py); modelos com textura
    (atlas de cores chapadas) sao lidos por cor numa 2a renderizacao "albedo" e cada cor do atlas vira uma peca
    (COLORMAP: cor do atlas -> rampa). Assim o pack e repintado so com a paleta mestra;
  - reforma: escala de ossos (cabeca maior, pernas curtas...), ossos escondidos (asas, armas), pecas nossas
    presas a ossos (gorro, chifres, musgo, rabo extra) com attach();
  - animacao: as acoes do pack (Idle/Walk/Attack/HitReact/Death) amostradas em N quadros + squash & stretch nosso
    por cima (mon_rig.squash/tilt). Tudo passa pelo mesmo cel shading/contorno/paleta (post.py).
Nunca publicar a silhueta do pack sem mudanca (GDD 17.0.2). Registrar o pack em game/assets/monsters/LICENSES.md.
Especies prontas usam pack_species.PackSpecies (configuracao declarativa)."""
import os, math
import bpy
from mathutils import Vector, Euler, Matrix
import mon_rig as R

PACK_PID = 250
MUTE_IK = False   # pid reservado: "superficie com textura", trocado pela cor do atlas (COLORMAP) na reducao


class Pack:
    def __init__(self):
        self.armature = None
        self.meshes = []
        self.holder = None
        self.bone_rest_scale = {}
        self.bone_rest_rot = {}


def _srgb(c):
    return tuple(int(round(255 * (x ** (1 / 2.2) if x > 0.0031308 else x * 12.92))) for x in c[:3])


def _image_node(mat):
    if not mat or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            return n
    return None


def _base_color(mat):
    if mat is None:
        return (0.8, 0.8, 0.8)
    if mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                return tuple(n.inputs['Base Color'].default_value[:3])
    return tuple(mat.diffuse_color[:3])


def _albedo_material(img_node):
    key = f"ALB_{img_node.image.name}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    nt = m.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img_node.image; tex.interpolation = 'Closest'
    em = nt.nodes.new('ShaderNodeEmission'); out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(tex.outputs['Color'], em.inputs['Color']); nt.links.new(em.outputs[0], out.inputs['Surface'])
    return m


def _nearest(c, colormap):
    best, bd = None, 1e18
    for rgb, part in colormap:
        d = sum((a - b) ** 2 for a, b in zip(c, rgb))
        if d < bd:
            best, bd = part, d
    return best


def _flat_albedo(rgb_lin):
    m = bpy.data.materials.new("ALBF")
    nt = m.node_tree; nt.nodes.clear()
    em = nt.nodes.new('ShaderNodeEmission'); out = nt.nodes.new('ShaderNodeOutputMaterial')
    em.inputs['Color'].default_value = (*rgb_lin, 1.0)
    nt.links.new(em.outputs[0], out.inputs['Surface'])
    return m


def import_model(rig, path, matmap=None, colormap=None, parent=None, yaw_deg=0.0, default_mat="skin", flags=None,
                 hide_objects=(), albedo_all=False):
    """Importa .glb/.gltf/.fbx/.obj. matmap: {nome_material: (peca, rampa)} ou {nome: rampa};
    colormap: [(cor_hex_ou_rgb, peca, rampa, flags), ...] para atlas/texturas e cores lisas sem nome no matmap."""
    flags = flags or {}
    matmap = matmap or {}
    cmap = []
    for ent in (colormap or []):
        rgb, part, ramp = ent[0], ent[1], ent[2]
        fl = ent[3] if len(ent) > 3 else {}
        if isinstance(rgb, str):
            rgb = tuple(int(rgb.lstrip('#')[k:k + 2], 16) for k in (0, 2, 4))
        cmap.append((rgb, rig.pid(part, ramp, **fl)))
    rig.colormap = cmap
    rig.albedo_slots = []
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path, bone_heuristic='TEMPERANCE')
    elif ext == ".blend":
        # .blend original do pack: ossos com a orientacao do autor (o glTF adivinha) -> reforma por osso confiavel
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects]
            dst.actions = [n for n in src.actions]
        for o in dst.objects:
            if o is not None and o.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(o)
        for im in bpy.data.images:
            if im.source == 'FILE' and not im.has_data:
                cand = os.path.join(os.path.dirname(path), os.path.basename(im.filepath.replace("\\", "/")))
                for d in (os.path.dirname(path), os.path.dirname(os.path.dirname(path))):
                    for dp, dn, fn in os.walk(d):
                        if os.path.basename(cand) in fn:
                            im.filepath = os.path.join(dp, os.path.basename(cand)); im.reload()
                            break
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise ValueError(f"formato nao suportado: {path}")
    new = [o for o in bpy.data.objects if o not in before]
    pk = Pack()
    holder = rig.empty(f"pack_{os.path.basename(path)}", (0, 0, 0), parent or rig.root)
    pk.holder = holder
    for o in new:
        helper = o.type == 'MESH' and (o.hide_render or (len(o.data.vertices) <= 8 and not any(
            m.type == 'ARMATURE' for m in o.modifiers)))
        if helper or any(h.lower() in o.name.lower() for h in hide_objects):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        if o.parent is None:
            o.parent = holder
        if o.type == 'ARMATURE':
            pk.armature = o
        elif o.type == 'MESH':
            pk.meshes.append(o)
            for i, slot in enumerate(o.material_slots):
                m = slot.material
                mname = m.name if m else "none"
                base = mname.split(".")[0]
                img = _image_node(m)
                if albedo_all:
                    print(f"[pack] material {mname}: base {_srgb(_base_color(m))} textura {img.image.name if img else None}")
                    pm = R.pass_material(PACK_PID)
                    rig.albedo_slots.append((o, i, pm, _albedo_material(img) if img else _flat_albedo(_base_color(m))))
                    slot.material = pm
                    continue
                if img is not None and cmap:
                    img.image.colorspace_settings.name = 'sRGB'
                    pm = R.pass_material(PACK_PID)
                    rig.albedo_slots.append((o, i, pm, _albedo_material(img)))
                    slot.material = pm
                    continue
                if base in matmap or mname in matmap:
                    v = matmap.get(base, matmap.get(mname))
                    part, ramp = (v if isinstance(v, tuple) else (base, v))
                    pid = rig.pid(part, ramp, **flags.get(part, {}))
                elif cmap:
                    pid = _nearest(_srgb(_base_color(m)), cmap)
                else:
                    pid = rig.pid(base, default_mat, **flags.get(base, {}))
                slot.material = R.pass_material(pid)
            if not o.material_slots:
                o.data.materials.append(R.pass_material(rig.pid("none", default_mat)))
            o["pid"] = 0.0
            for poly in o.data.polygons:   # low poly facetado -> liso (o cel shading faz as faixas)
                poly.use_smooth = True
            rig.meshes.append(o)
    holder.rotation_euler = Euler((0, 0, math.radians(yaw_deg)))
    if pk.armature is not None:
        ad = pk.armature.animation_data
        if ad:
            for t in ad.nla_tracks:
                t.mute = True
        for b in pk.armature.pose.bones:
            b.rotation_mode = 'QUATERNION'
            b.ik_stretch = 0.0
            for c in b.constraints:   # IK do pack sem esticar: pernas encurtadas ficam curtas (pes sobem; fit desce tudo)
                if c.type == 'IK':
                    c.use_stretch = False
                    c.mute = MUTE_IK
    return pk


def fit(pk, height, action=None):
    """Escala e centraliza o pack: altura (m) = height, pes em z = 0, centro do corpo na origem (x, y)."""
    if action:
        play(pk, action, 0, 1)
    bpy.context.view_layer.update()
    lo, hi = bbox(pk)
    s = height / max(1e-6, hi.z - lo.z)
    h = pk.holder
    h.scale = (s, s, s)
    bpy.context.view_layer.update()
    lo, hi = bbox(pk)
    c = (lo + hi) / 2
    h.location = h.location - Vector((c.x, c.y, lo.z))
    bpy.context.view_layer.update()
    return s


def bbox(pk):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in pk.meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def bone_scale(pk, bone, s):
    """Reforma permanente: escala um osso (e filhos), ex. cabeca 1.5x para ficar chibi; (x, y, z) com y = ao
    longo do osso (pernas curtas: (1, 0.6, 1))."""
    pb = pk.armature.pose.bones.get(bone) if pk.armature else None
    if pb is None:
        print(f"[pack] osso '{bone}' nao existe")
        return
    if isinstance(s, (int, float)):
        pk.bone_rest_scale[bone] = Vector((s, s, s))
        return
    # (grossura, comprimento, grossura): o "comprimento" vai no eixo local mais alinhado com o membro (direcao ate o
    # 1o filho, ou a do proprio osso) — o glTF adivinha a orientacao dos ossos, entao o eixo Y nem sempre e o membro
    b = pk.armature.data.bones[bone]
    d = (b.children[0].head_local - b.head_local) if b.children else (b.tail_local - b.head_local)
    if d.length < 1e-6:
        d = b.tail_local - b.head_local
    m = b.matrix_local.to_3x3()
    axes = [m.col[k].normalized() for k in range(3)]
    k = max(range(3), key=lambda i: abs(axes[i].dot(d.normalized())))
    v = [s[0], s[0], s[0]]
    v[k] = s[1]
    pk.bone_rest_scale[bone] = Vector(v)


def bone_rot(pk, bone, euler):
    """Rotacao extra fixa somada a animacao (ex.: bracos do jiangshi esticados para frente)."""
    pk.bone_rest_rot[bone] = Euler(euler).to_quaternion()


def _fcurve_lists(act):
    if getattr(act, "fcurves", None) is not None:  # API antiga
        yield act.fcurves
    for layer in getattr(act, "layers", []):       # acoes em camadas (Blender 4.4+)
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                yield bag.fcurves


def _strip_channel(data_path):
    """Tira das acoes os canais que a reforma sobrescreve (senao a animacao do pack desfaz a escala)."""
    for act in bpy.data.actions:
        for fcs in _fcurve_lists(act):
            for fc in [f for f in fcs if f.data_path == data_path]:
                fcs.remove(fc)


def bone_head(pk, bone, tail=False):
    """Posicao (mundo, modelo em descanso) da cabeca/ponta de um osso — para posicionar pecas nossas."""
    bpy.context.view_layer.update()
    pb = pk.armature.pose.bones[bone]
    return pk.armature.matrix_world @ (pb.tail if tail else pb.head)


def attach(obj, pk, bone):
    """Prende uma peca nossa (criada em coordenadas do mundo, pose atual) a um osso do pack."""
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    obj.parent = pk.armature
    obj.parent_type = 'BONE'
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = mw


def actions():
    return [a.name for a in bpy.data.actions]


def _find_action(name):
    for a in bpy.data.actions:
        if a.name == name or a.name.split("|")[-1] == name:
            return a
    for a in bpy.data.actions:
        if a.name.lower().endswith(name.lower()):
            return a
    return None


def play(pk, action_name, i, n, loop=True, span=(0.0, 1.0)):
    """Pose do pack no quadro i de n da acao. loop: t = i/n; golpe/morte: t = i/(n-1) (termina na ultima pose).
    span: trecho da acao usado (0..1)."""
    if pk.armature is None:
        return
    act = _find_action(action_name)
    if act is None:
        raise KeyError(f"acao '{action_name}' nao encontrada; tem: {actions()}")
    ad = pk.armature.animation_data or pk.armature.animation_data_create()
    ad.action = act
    if hasattr(ad, "action_slot") and len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    t = i / n if loop else i / max(1, n - 1)
    t = span[0] + (span[1] - span[0]) * t
    f = f0 + (f1 - f0) * t
    for pb in pk.armature.pose.bones:   # canais sem curva na acao voltam ao descanso (senao a reforma acumula)
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
    # congela a pose (sem acao ligada) para somar a reforma sem a animacao sobrescrever no render
    pose = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in pk.armature.pose.bones}
    ad.action = None
    for pb in pk.armature.pose.bones:
        l, q, sc = pose[pb.name]
        pb.location = l
        pb.rotation_quaternion = q @ pk.bone_rest_rot[pb.name] if pb.name in pk.bone_rest_rot else q
        rs = pk.bone_rest_scale.get(pb.name)
        pb.scale = Vector((sc.x * rs.x, sc.y * rs.y, sc.z * rs.z)) if rs is not None else sc


def group_bbox(pk, groups, min_w=0.5):
    """Caixa (mundo, pose atual) dos vertices com peso >= min_w nos grupos dados (ex.: ["Head"]) — para achar o
    rosto e posicionar olhos/chapeus."""
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in pk.meshes:
        idx = {g.index for g in o.vertex_groups if g.name in groups}
        if not idx:
            continue
        sel = [v.index for v in o.data.vertices if any(g.group in idx and g.weight >= min_w for g in v.groups)]
        if not sel:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for k in sel:
            w = ev.matrix_world @ me.vertices[k].co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def delete_group_verts(pk, groups, min_w=0.5):
    """Apaga da malha os vertices com peso >= min_w nos grupos (ex.: cabeca original trocada pela nossa)."""
    import bmesh
    for o in pk.meshes:
        idx = {g.index for g in o.vertex_groups if g.name in groups}
        if not idx:
            continue
        kill = {v.index for v in o.data.vertices if any(g.group in idx and g.weight >= min_w for g in v.groups)}
        if not kill:
            continue
        bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[k] for k in kill], context='VERTS')
        bm.to_mesh(o.data); bm.free(); o.data.update()
