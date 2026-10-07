"""Personagem jogavel sobre a BASE PRONTA Quaternius (chr_qbase.py): corpo + esqueleto + animacoes UAL1/UAL2.

Fluxo (mesma interface de chr_body.build, usada por render_chr.py com --base q):
  1. importa o corpo Superhero (masculino/feminino) e as acoes;
  2. proporcao compacta do jogo (GDD §17.0.B): rosto curto esculpido, volumes moderados, membros fortes;
     escalas por osso sem heranca, altura total ajustada;
  3. mede o corpo DEFORMADO (secoes do tronco, cabeca, olhos, pes) e cria pivos presos aos ossos;
  4. as pecas procedurais de chr_body (roupas, cabelos, chapeus, brincos, armas) sao construidas no espaco do modelo
     procedural e ENTORTADAS para o corpo importado (rig.warp): tronco por secao, cabeca por eixo com o nivel dos
     olhos casado; pecas dos membros ja nascem nas juntas importadas;
  5. pose por quadro: acao Quaternius na fase certa -> copiada ("assada") para a pose -> correcoes do jogo
     (postura relaxada no idle, sentar no chao, morte tombando de lado na tela) -> escala de proporcao.
"""
import math, os
import bpy
from mathutils import Vector as V, Matrix, Quaternion, Euler
import chr_lib as C
import chr_body as B
import chr_qbase as Q

# escalas de pose no corpo base Superhero; o perfil chunky encurta e alarga torso e membros
# Proporcao por osso (x, y, z) do osso: x/z = espessura, y = comprimento. Sem heranca de escala (os dedos herdam a
# da mao). Dois estilos: "chunky" (padrao; silhueta compacta, rosto esculpido antes da escala) e
# "slender" (primeira versao esguia, mantida apenas para comparacao).
PROPS = {
    "slender": {"spine_01": (0.82, 1.0, 0.82), "spine_02": (0.80, 1.0, 0.80), "spine_03": (0.80, 1.0, 0.80),
                "pelvis": (0.88, 1.0, 0.88), "neck_01": (0.85, 1.30, 0.85), "clavicle_l": (0.74, 1.0, 0.74),
                "clavicle_r": (0.74, 1.0, 0.74), "upperarm_l": (0.78, 1.0, 0.78), "upperarm_r": (0.78, 1.0, 0.78),
                "lowerarm_l": (0.80, 1.0, 0.80), "lowerarm_r": (0.80, 1.0, 0.80), "thigh_l": (0.84, 1.0, 0.84),
                "thigh_r": (0.84, 1.0, 0.84), "calf_l": (0.86, 1.0, 0.86), "calf_r": (0.86, 1.0, 0.86),
                "Head": (1.55,) * 3, "hand_l": (0.84,) * 3, "hand_r": (0.84,) * 3},
    # Revisao facial: a referencia Samsara orienta volumes, sem considerar a versao gerada aprovada.
    # Moderar ombros e coxas; ampliar a cabeca somente depois de esculpir queixo, bochechas e nariz.
    # (x, y, z) = (largura, comprimento, profundidade); Y e comprimido sem achatar o personagem no render.
    "chunky": {"spine_01": (1.10, 0.78, 1.08), "spine_02": (1.12, 0.78, 1.10), "spine_03": (1.02, 0.80, 1.04),
               "pelvis": (1.10, 0.83, 1.06), "neck_01": (1.10, 0.70, 1.10), "clavicle_l": (1.04, 0.98, 1.04),
               "clavicle_r": (1.04, 0.98, 1.04), "upperarm_l": (1.28, 0.56, 1.26), "upperarm_r": (1.28, 0.56, 1.26),
               "lowerarm_l": (1.26, 0.55, 1.24), "lowerarm_r": (1.26, 0.55, 1.24), "thigh_l": (1.24, 0.60, 1.20),
               "thigh_r": (1.24, 0.60, 1.20), "calf_l": (1.20, 0.62, 1.18), "calf_r": (1.20, 0.62, 1.18),
               "Head": (2.40,) * 3, "hand_l": (1.38,) * 3, "hand_r": (1.38,) * 3, "foot_l": (1.42,) * 3,
               "foot_r": (1.42,) * 3, "ball_l": (1.30,) * 3, "ball_r": (1.30,) * 3},
}
STYLE = os.environ.get("CHR_STYLE", "chunky")
THIN = PROPS[STYLE]
TOP_TARGET = {"male": 1.78, "female": 1.72}   # alto da cabeca (sem cabelo), metros, ja com a cabeca maior
HEIGHT_MUL = {"slender": 1.0, "chunky": 1.05}   # idle: ~87 px de altura em folha 96×96, margem para chapéus
# animacao do jogo -> (acao, laco?, fase inicial, fase final)
QANIM = {"idle": ("Idle_Loop", True, 0.0, 1.0), "walk": ("Walk_Loop", True, 0.0, 1.0),
         "attack_unarmed": ("Punch_Cross", False, 0.0, 0.95), "attack_blade": ("Sword_Regular_A", False, 0.0, 0.95),
         "attack_staff": ("Sword_Regular_B", False, 0.0, 0.95), "cast": ("Spell_Simple_Shoot", False, 0.0, 0.95),
         "hit": ("Hit_Chest", False, 0.05, 0.75), "death": ("Death01", False, 0.0, 1.0),
         "sit": ("Sitting_Idle_Loop", True, 0.0, 0.0)}
PART_OF_BONE = {"Head": "head", "neck_01": "neck", "spine_03": "torso", "spine_02": "torso", "spine_01": "torso",
                "pelvis": "pelvis", "clavicle_l": "torso", "clavicle_r": "torso",
                "upperarm_l": "uarm_L", "lowerarm_l": "farm_L", "hand_l": "hand_L",
                "upperarm_r": "uarm_R", "lowerarm_r": "farm_R", "hand_r": "hand_R",
                "thigh_l": "thigh_L", "calf_l": "shin_L", "foot_l": "foot_L", "ball_l": "foot_L",
                "thigh_r": "thigh_R", "calf_r": "shin_R", "foot_r": "foot_R", "ball_r": "foot_R"}


def _bone_part(name):
    if name in PART_OF_BONE:
        return PART_OF_BONE[name]
    side = name[-1]
    return "hand_L" if side == "l" else ("hand_R" if side == "r" else "torso")


NECK_LEN = 1.30     # pescoco mais longo (o do super-heroi e curto; a gola escondia o queixo)
HEAD_PITCH = -0.12  # rosto um pouco para cima em todas as poses (le melhor com a camera alta)


# A cabeca e escalada em torno de um ponto entre o rosto e o centro do cranio (nao da base do pescoco): a cabeca
# grande fica SOBRE os ombros em vez de projetada para a frente (a "corcunda" da primeira tentativa).
HEAD_WARP_XY = {"slender": 1.08, "chunky": 0.96}   # cabelo/chapeus: largura relativa a altura do cranio
HEAD_PIVOT = {"slender": (0.0, -0.02, 0.02), "chunky": (0.0, -0.075, 0.050)}   # m, relativo a base da cabeca (mundo)
# Postura ereta somada a toda pose: (osso, eixo do mundo, angulo). Negativo em X = inclina para tras.
POSTURE = {"slender": [], "chunky": [("spine_01", (1, 0, 0), -0.025), ("spine_03", (1, 0, 0), -0.020), ("Head", (1, 0, 0), -0.025)]}


def apply_proportions(arm, rig=None):
    props = getattr(rig, "q_thin", THIN) if rig is not None else THIN
    for bn, f in props.items():
        if bn not in arm.pose.bones:
            continue
        if not isinstance(f, (list, tuple)):
            f = (f, 1.0, f)
        elif len(f) == 2:
            f = (f[0], 1.0, f[1])
        arm.pose.bones[bn].scale = tuple(f)
    hs = props.get("Head", (1.0,) * 3)[0]
    pv = V(getattr(rig, "q_head_pivot", HEAD_PIVOT[STYLE]) if rig is not None else HEAD_PIVOT[STYLE])
    pb = arm.pose.bones["Head"]
    # escala em torno de P: x' = s*x + (1-s)*P  -> translacao (1-s)*P, levada ao espaco local do osso
    local = pb.bone.matrix_local.to_3x3().inverted() @ (pv * (1.0 - hs))
    pb.location = local


def _eval_verts(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return vs


def _keep_bones(o, keep):
    """Apaga as faces cujo osso dominante nao esta em keep."""
    import bmesh
    vg = {g.index: g.name for g in o.vertex_groups}
    best = []
    for v in o.data.vertices:
        w = max(v.groups, key=lambda gg: gg.weight, default=None)
        best.append(vg.get(w.group, "") if w else "")
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = [f for f in bm.faces if max(set(n := [best[v.index] for v in f.verts]), key=n.count) not in keep]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(o.data); bm.free(); o.data.update()


def _face_parts_by_bone(rig, o, group, mat="skin", extra=None):
    """pid por face = osso de maior peso (linhas internas entre bracos/tronco/pernas como no corpo procedural)."""
    vg = {g.index: g.name for g in o.vertex_groups}
    best = []
    for v in o.data.vertices:
        w = max(v.groups, key=lambda g: g.weight, default=None)
        best.append(vg.get(w.group, "") if w else "")
    me = o.data
    attr = me.attributes.get("fpid") or me.attributes.new("fpid", 'FLOAT', 'FACE')
    vals = []
    for p in me.polygons:
        names = [best[i] for i in p.vertices]
        bn = max(set(names), key=names.count)
        part = _bone_part(bn)
        m = mat
        if extra:
            r = extra(p, bn)
            if r:
                part, m = r
        vals.append(float(rig.pid(part, m, group, prio=1.2 if part == "head" else 1.0)))
    attr.data.foreach_set("value", vals)
    me.update()


def reshape_head(meshes):
    """Sculpt the existing weighted head in rest space: short jaw, rounded cheeks, shallow nose.

    Keeps topology, weights and armature intact. The imported adult nose/chin must not simply be enlarged.
    All measurements come from the source mesh, so both body variants use the same normalized treatment.
    """
    for obj in meshes:
        group = obj.vertex_groups.get("Head")
        if group is None:
            continue
        weighted = []
        for vertex in obj.data.vertices:
            weight = next((g.weight for g in vertex.groups if g.group == group.index), 0.0)
            if weight > 0.5:
                weighted.append((vertex, weight, obj.matrix_world @ vertex.co))
        if not weighted:
            continue
        bottom = min(p.z for _, _, p in weighted)
        top = max(p.z for _, _, p in weighted)
        height = top - bottom
        front = min(p.y for _, _, p in weighted)
        back = max(p.y for _, _, p in weighted)
        face_plane = front + (back - front) * 0.14
        inverse = obj.matrix_world.inverted()
        for vertex, weight, original in weighted:
            t = (original.z - bottom) / height
            target = original.copy()
            # Lift the lower face; preserve the crown so hair and rig keep a stable reference.
            target.z = bottom + height * _interp([(0.0, 0.20), (0.35, 0.47), (0.65, 0.71), (1.0, 1.0)], t)
            target.x *= _interp([(0.0, 1.24), (0.35, 1.18), (0.65, 1.06), (1.0, 1.0)], t)
            if target.y < face_plane:
                target.y = face_plane + (target.y - face_plane) * 0.18
            vertex.co = inverse @ original.lerp(target, weight)
        obj.data.update()


def build(body, want=None, props=None, extra=None, name=None):
    C.MR.reset()
    P = dict(B.BODY[body])
    if props:
        P.update(props)
    k = P["h"]
    rig = C.Rig(name or f"chr_{body}")
    rig.body, rig.k, rig.base = body, k, "quaternius"
    arm, meshes = Q.load_base(body)
    if STYLE == "chunky":
        reshape_head(meshes)
    rig.arm = arm
    for b in arm.data.bones:   # proporcao por osso sem propagar; os dedos acompanham a escala da mao
        b.inherit_scale = 'FULL' if b.name.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb") else 'NONE'
    arm.parent = rig.root
    qp = (props or {}).get("q", {})          # NPCs: {"height": x, "head": s, "thin": {osso: f ou [fx, fz]}}
    rig.q_thin = dict(THIN)
    for bn, f in qp.get("thin", {}).items():   # NPC: multiplica o estilo (espessura [x, z] ou [x, y, z])
        f = (f, 1.0, f) if not isinstance(f, (list, tuple)) else ((f[0], 1.0, f[1]) if len(f) == 2 else tuple(f))
        b = rig.q_thin.get(bn, (1.0, 1.0, 1.0))
        rig.q_thin[bn] = tuple(x * y for x, y in zip(b, f))
    if "head" in qp:                            # multiplicador da cabeca do estilo
        rig.q_thin["Head"] = tuple(x * qp["head"] for x in rig.q_thin.get("Head", (1.0,) * 3))
    apply_proportions(arm, rig)
    bpy.context.view_layer.update()
    # altura: escala global para o alto da cabeca bater com o alvo
    top = max(v.z for o in meshes for v in _eval_verts(o))
    g = TOP_TARGET[body] * HEIGHT_MUL[STYLE] * qp.get("height", 1.0) / top
    arm.scale = (g, g, g)
    bpy.context.view_layer.update()
    rig.g = g
    J = Q.bind_joints(rig, arm)
    rig.J = J
    body_mesh = max(meshes, key=lambda o: len(o.data.vertices))
    bv = _eval_verts(body_mesh)
    _measure(rig, arm, bv)
    # corpo: so cabeca e pescoco ficam no grupo "body" (as roupas modulares trazem bracos/maos; o resto do corpo
    # atravessaria a roupa); olhos/sobrancelhas 3D removidos (camada de olhos 2D)
    rig.body_mesh = body_mesh
    keep = {"Head", "neck_01"}
    for o in meshes:
        src = o.copy(); src.data = o.data.copy()          # copia inteira para body_skin (partes a mostra)
        bpy.context.scene.collection.objects.link(src)
        src.hide_render = True
        if o is body_mesh:
            rig.body_mesh = src
            _face_parts_by_bone(rig, src, "body")
        _keep_bones(o, keep)
        _face_parts_by_bone(rig, o, "body")
        o.data.materials.clear()
        o.data.materials.append(C.pass_material())
        o["pid"] = float(rig.pid("torso", "skin", "body"))
        rig.meshes.append(o); rig.groups.setdefault("body", []).append(o); o["group"] = "body"
    # cabelo raspado (mascara B): casca do cabelo procedural, entortada para a cabeca importada
    W = lambda loc: V(tuple(x * k for x in loc))  # noqa: E731
    rig.W, rig.P = W, _q_props(rig, P)
    rig.warp = lambda obj, parent: _warp(rig, obj, parent)
    buzz = C.loft("buzz", B.head_sections(W, grow=0.006)[4:], seg=20, cap0=False)
    s1 = k
    B._cut(buzz, lambda c, n: c.y < -0.035 * s1 and c.z < 1.668 * k or (c.z < 1.585 * k and abs(c.x) > 0.07 * s1 and c.y < 0.03 * s1)
           or (c.z < 1.56 * k))
    rig.add(buzz, "buzz", "buzz", J["head"], "body")
    _anchors(rig, arm)
    groups = want
    if groups is None or any(gg.startswith("outfit:") for gg in groups):
        for o in B.OUTFITS:
            if groups is None or f"outfit:{o}" in groups:
                Q_OUTFITS[o](rig, body, rig.P, W, J)
    for h in B.HAIR[body]:
        if groups is None or f"hair:{h}" in groups:
            B.HAIR_BUILD[h](rig, body, rig.P, W, J)
    if groups is None:
        B.earrings(rig, body, rig.P, W, J)
        B.heads(rig, body, rig.P, W, J)
        B.weapons(rig, body, rig.P, W, J)
    if extra:
        extra(rig, body, rig.P, W, J)
    rig.warp = None
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ medidas e mapeamentos
def _measure(rig, arm, bv):
    """Secoes do tronco, cabeca e pes do corpo importado (ja deformado pela proporcao)."""
    wl = rig.world_loc
    k = rig.k
    sh_z = wl["uarm_L"].z
    secs = []
    z = 0.70
    while z < 1.95:
        lim = 0.24 if z < sh_z - 0.06 else 0.15
        sl = [v for v in bv if abs(v.z - z) < 0.012 and abs(v.x) < lim]
        if len(sl) > 6:
            xs = [v.x for v in sl]; ys = [v.y for v in sl]
            secs.append((z, (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2, (max(ys) + min(ys)) / 2))
        z += 0.02
    rig.q_secs = secs
    head_vs = [v for v in bv if v.z > wl["head"].z - 0.02]
    top = max(v.z for v in head_vs)
    rig.q_head = dict(pivot=wl["head"].copy(), top=top,
                      w=max(v.x for v in head_vs) - min(v.x for v in head_vs),
                      d=max(v.y for v in head_vs) - min(v.y for v in head_vs),
                      yc=(max(v.y for v in head_vs) + min(v.y for v in head_vs)) / 2,
                      chin=min(v.z for v in bv if abs(v.x) < 0.02 * k and v.y < wl["head"].y - 0.04 and v.z > wl["neck"].z))
    # pontos do rosto (proporcionais ao cranio importado; os olhos anime ficam na altura dos olhos originais)
    hp, ht = rig.q_head["pivot"], top
    H = ht - hp.z
    if STYLE == "chunky":   # chibi: olhos grandes e mais baixos no rosto
        fh = top - rig.q_head["chin"]
        chin = rig.q_head["chin"]
        rig.q_face = dict(eye_z=chin + 0.46 * fh, brow_z=chin + 0.60 * fh, nose_z=chin + 0.31 * fh, mouth_z=chin + 0.20 * fh)
    else:
        rig.q_face = dict(eye_z=hp.z + 0.47 * H, brow_z=hp.z + 0.56 * H, nose_z=hp.z + 0.30 * H, mouth_z=hp.z + 0.16 * H)
    # pes
    fb = {}
    for nm, bn in (("L", "l"), ("R", "r")):
        ank = arm.matrix_world @ arm.pose.bones[f"foot_{bn}"].head
        ball = arm.matrix_world @ arm.pose.bones[f"ball_{bn}"].head
        tip = arm.matrix_world @ arm.pose.bones[f"ball_{bn}"].tail
        fb[nm] = (ank, ball, tip)
    rig.q_feet = fb

    def shoe_box(nm, height):
        ank, ball, tip = fb[nm]
        heel = ank.y + 0.050 * rig.g
        toe = tip.y - 0.012
        cen = V((ank.x, (heel + toe) / 2, height * k / 2 - 0.004))
        return cen, abs(heel - toe) + 0.012, 0.018
    rig.shoe_box = shoe_box
    rig.toe_y = {nm: fb[nm][2].y + 0.055 for nm in fb}


def _q_props(rig, P):
    """Raios dos membros medidos no corpo importado (em unidades do modelo procedural: /k)."""
    k = rig.k
    Pq = dict(P)
    g = rig.g
    if rig.body == "male":
        arm_r, leg_r = (0.047, 0.038, 0.030), (0.070, 0.046, 0.034)
    else:
        arm_r, leg_r = (0.036, 0.029, 0.024), (0.066, 0.046, 0.032)
    Pq["arm_r"] = tuple(r * g / k for r in arm_r)
    Pq["leg_r"] = tuple(r * g / k for r in leg_r)
    return Pq


def _interp(pts, x):
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    (x0, y0), (x1, y1) = pts[-2], pts[-1]
    return y1 + (y1 - y0) / (x1 - x0) * (x - x1)


def _zmap_torso(rig, z):
    k, wl = rig.k, rig.world_loc
    pts = [(0.0, 0.0), (0.085 * k, wl["foot_L"].z), (0.490 * k, wl["shin_L"].z), (0.885 * k, wl["thigh_L"].z),
           (1.040 * k, wl["spine"].z), (1.220 * k, wl["chest"].z + (wl["uarm_L"].z - wl["chest"].z) * 0.25),
           (1.345 * k, wl["uarm_L"].z), (1.395 * k, wl["neck"].z), (1.465 * k, wl["head"].z)]
    return _interp(pts, z)


def _qsec(rig, z):
    s = rig.q_secs
    if z <= s[0][0]:
        return s[0][1:]
    for a, b in zip(s, s[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(x + (y - x) * t for x, y in zip(a[1:], b[1:]))
    return s[-1][1:]


def _warp_torso(rig, co):
    k = rig.k
    zq = _zmap_torso(rig, co.z)
    zm = max(0.80, min(1.40, co.z / k))
    rx, ry, yc = B._torso_r(rig.P, zm)
    rx, ry, yc = rx * k, ry * k, yc * k
    qrx, qry, qyc = _qsec(rig, min(max(zq, rig.q_secs[0][0]), rig.world_loc["neck"].z + 0.02))
    fx = max(0.6, min(1.6, qrx / rx)); fy = max(0.6, min(1.8, qry / ry))
    return V((co.x * fx, qyc + (co.y - yc) * fy, zq))


def _warp_head(rig, co):
    """Cabeca procedural -> cabeca esculpida. Z casa queixo/olhos/sobrancelha/topo.
    X/Y partem da altura do cranio; chunky usa 1.04 em largura e 0.96 em profundidade,
    acomodando as mechas ao rosto mais curto sem achata-las pela largura bruta da malha."""
    k = rig.k
    h = rig.q_head
    f = rig.q_face
    pts = [(1.436 * k, h["chin"]), (1.546 * k, f["eye_z"]), (1.578 * k, f["brow_z"]), (1.729 * k, h["top"])]
    zq = _interp(pts, co.z)
    sz = (h["top"] - h["chin"]) / ((1.729 - 1.436) * k)
    sy = sz * HEAD_WARP_XY.get(STYLE, 1.0)
    sx = sz * (1.04 if STYLE == "chunky" else HEAD_WARP_XY.get(STYLE, 1.0))
    return V((co.x * sx, h["yc"] + (co.y - 0.009 * k) * sy, zq))


HEAD_JOINTS = {"head"}
TORSO_JOINTS = {"pelvis", "spine", "chest", "neck", "root", "turn"}


def _warp(rig, obj, parent):
    if parent in HEAD_JOINTS:
        fn = _warp_head
    elif parent in TORSO_JOINTS:
        fn = _warp_torso
    else:
        return
    me = obj.data
    mw = obj.matrix_world
    inv = mw.inverted()
    for v in me.vertices:
        v.co = inv @ fn(rig, mw @ v.co)
    me.update()


def _anchors(rig, arm):
    """Ancoras do rosto (na cabeca importada), mao/pega e pes (trava no chao)."""
    J, wl, k = rig.J, rig.world_loc, rig.k
    h, f = rig.q_head, rig.q_face
    ex = h["w"] * (0.145 if STYLE == "chunky" else 0.19)
    front = h["yc"] - h["d"] / 2
    ey = front + h["d"] * 0.06
    rig.anchor("eye_L", V((ex, ey, f["eye_z"])), J["head"])
    rig.anchor("eye_R", V((-ex, ey, f["eye_z"])), J["head"])
    rig.anchor("eye_sL", V((ex * 1.75, ey + h["d"] * 0.13, f["eye_z"])), J["head"])
    rig.anchor("eye_sR", V((-ex * 1.75, ey + h["d"] * 0.13, f["eye_z"])), J["head"])
    rig.anchor("brow_L", V((ex * 1.02, ey - 0.002, f["brow_z"])), J["head"])
    rig.anchor("brow_R", V((-ex * 1.02, ey - 0.002, f["brow_z"])), J["head"])
    rig.anchor("nose", V((0, front - 0.004, f["nose_z"])), J["head"])
    rig.anchor("mouth", V((0, ey + 0.004, f["mouth_z"])), J["head"])
    rig.anchor("head_top", V((0, h["yc"], h["top"])), J["head"])
    for nm in ("L", "R"):
        hd = (wl[f"hand_{nm}"] - wl[f"farm_{nm}"]).normalized()
        rig.anchor(f"grip_{nm}", wl[f"hand_{nm}"] + hd * 0.075 * rig.g + V((0, -0.01, 0)), J[f"hand_{nm}"])
        ank, ball, tip = rig.q_feet[nm]
        rig.anchor(f"heel_{nm}", V((ank.x, ank.y + 0.045 * rig.g, 0.0)), J[f"foot_{nm}"])
        rig.anchor(f"toe_{nm}", V((tip.x, tip.y, 0.0)), J[f"foot_{nm}"])


# ------------------------------------------------------------------ poses
def _bake(arm):
    """Copia a pose avaliada da acao e solta a acao (as correcoes/escala nao sao sobrescritas no render)."""
    vals = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        l, q = vals[pb.name]
        pb.location = l
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = q


def rot_world(arm, bone, axis, angle):
    """Gira o osso em torno de um eixo do MUNDO (do armature), com pivo na cabeca do osso; filhos acompanham."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones[bone]
    M = pb.matrix.copy()
    head = M.to_translation()
    R = Matrix.Translation(head) @ Quaternion(V(axis).normalized(), angle).to_matrix().to_4x4() @ Matrix.Translation(-head)
    pb.matrix = R @ M


def _relax_idle(arm, amt=1.0):
    # pernas mais juntas (a acao abre a base de luta) e bracos soltos ao lado do corpo
    rot_world(arm, "thigh_l", (0, 1, 0), 0.10 * amt)
    rot_world(arm, "thigh_r", (0, 1, 0), -0.10 * amt)
    rot_world(arm, "calf_l", (0, 1, 0), -0.05 * amt)
    rot_world(arm, "calf_r", (0, 1, 0), 0.05 * amt)
    rot_world(arm, "upperarm_l", (0, 1, 0), 0.20 * amt)
    rot_world(arm, "upperarm_r", (0, 1, 0), -0.20 * amt)
    rot_world(arm, "lowerarm_l", (1, 0, 0), -0.35 * amt)
    rot_world(arm, "lowerarm_r", (1, 0, 0), -0.35 * amt)


def rest_pose(arm):
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)


FINGER_CURL = {"slender": -0.35, "chunky": -1.35}   # punhos compactos e legiveis no corpo atarracado


def relaxed(arm, arm_down=1.38, elbow=0.14, spread=0.0):
    """Pose neutra da referencia a partir do T: bracos soltos ao lado do corpo, cotovelo quase reto, maos relaxadas."""
    rot_world(arm, "upperarm_l", (0, 1, 0), arm_down)
    rot_world(arm, "upperarm_r", (0, 1, 0), -arm_down)
    rot_world(arm, "lowerarm_l", (1, 0, 0), -elbow)
    rot_world(arm, "lowerarm_r", (1, 0, 0), -elbow)
    for s, sg in (("l", 1), ("r", -1)):
        rot_world(arm, f"hand_{s}", (1, 0, 0), -0.10)
        rot_world(arm, f"thigh_{s}", (0, 1, 0), sg * spread)
        # dedos levemente dobrados (mao relaxada, nao espalmada)
        for f in ("index", "middle", "ring", "pinky", "thumb"):
            for j in ("01", "02", "03"):
                bn = f"{f}_{j}_{s}"
                if bn in arm.pose.bones:
                    rot_world(arm, bn, (1, 0, 0), FINGER_CURL[STYLE] * (0.5 if f == "thumb" else 1.0))


ARM_BONES = ("clavicle", "upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb")


def _walk_arms(rig):
    """Bracos do andar: a acao dobra o cotovelo a 90 graus (vira "alca" em pixel art). Refaz os bracos soltos e
    balanca em oposicao as pernas, na fase medida das coxas da propria acao."""
    arm = rig.arm
    bpy.context.view_layer.update()
    fwd = {}
    for s_ in ("l", "r"):
        pb = arm.pose.bones[f"thigh_{s_}"]
        d = (pb.tail - pb.head).normalized()
        fwd[s_] = -d.y           # coxa para a frente (-Y) = positivo
    for pb in arm.pose.bones:
        if pb.name.split("_")[0] in ARM_BONES:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
    relaxed(arm, arm_down=1.45, elbow=0.30)
    for s_, o_ in (("l", "r"), ("r", "l")):
        sw = max(-0.5, min(0.5, fwd[o_] * 1.1))   # braco acompanha a perna oposta
        rot_world(arm, f"upperarm_{s_}", (1, 0, 0), -sw)
        rot_world(arm, f"lowerarm_{s_}", (1, 0, 0), -0.25 * max(0.0, sw))


def _idle_custom(rig, t):
    """Idle de respiracao sobre a pose relaxada (as acoes prontas sao todas em base de luta)."""
    arm = rig.arm
    rest_pose(arm)
    br = math.sin(math.tau * t)
    br2 = math.sin(math.tau * t - 0.6)
    relaxed(arm, arm_down=(1.47 if STYLE == "slender" else 1.36) - 0.02 * (br + 1) / 2,
            elbow=(0.14 if STYLE == "slender" else 0.18) + 0.03 * (br2 + 1) / 2)
    rot_world(arm, "spine_03", (1, 0, 0), -0.018 * br)
    rot_world(arm, "neck_01", (1, 0, 0), 0.010 * br2)
    rot_world(arm, "Head", (1, 0, 0), 0.010 * br2)
    # peso numa perna (contrapposto sutil)
    rot_world(arm, "pelvis", (0, 1, 0), 0.02)
    rot_world(arm, "spine_02", (0, 1, 0), -0.025)
    rot_world(arm, "calf_r", (1, 0, 0), 0.06)


def pose(rig, anim, i, n):
    import chr_anim as A
    arm = rig.arm
    act, loop, p0, p1 = QANIM[anim]
    t = (i / n) if loop else (i / max(1, n - 1))
    Q.set_action(arm, act, p0 + (p1 - p0) * t, loop=loop)
    bpy.context.view_layer.update()
    _bake(arm)
    apply_proportions(arm, rig)
    rig.root.rotation_euler = Euler((0, 0, 0))
    if anim == "idle":
        _idle_custom(rig, t)
    elif anim == "walk":
        _walk_arms(rig)
    elif anim == "sit":
        _sit_ground(rig)
    elif anim == "death":
        _death_turn(rig, t)
    if anim != "death":
        rot_world(arm, "Head", (1, 0, 0), HEAD_PITCH)
        for bn, ax, ang in POSTURE[STYLE]:
            rot_world(arm, bn, ax, ang)
    for jn, rot in getattr(rig, "posture", {}).items():   # NPCs
        bn = Q.BONE_OF.get(jn, jn)
        rot_world(arm, bn, (1, 0, 0), -rot[0]) if rot[0] else None
    if anim not in ("death", "sit"):
        A.lock_ground(rig)
    else:
        bpy.context.view_layer.update()


def _sit_ground(rig):
    """Sentar no chao: a acao senta numa cadeira; esticamos as pernas para a frente e baixamos o quadril."""
    arm = rig.arm
    for s in ("l", "r"):
        rot_world(arm, f"calf_{s}", (1, 0, 0), 1.25)
        rot_world(arm, f"thigh_{s}", (0, 0, 1), 0.18 if s == "l" else -0.18)
    bpy.context.view_layer.update()
    zs = [rig.anchors[n].matrix_world.translation.z for n in ("heel_L", "toe_L", "heel_R", "toe_R")]
    pel = arm.matrix_world @ arm.pose.bones["pelvis"].head
    drop = pel.z - 0.13 * rig.g * 7.0 * 0.1 - 0.06
    rig.root.location.z -= min(drop, pel.z - 0.14)
    rig.root.location.y += 0.10


def _death_turn(rig, t):
    """Death01 cai para tras; giramos o corpo (pivo nos pes) enquanto cai para ele deitar atravessado na tela."""
    ang = math.radians(getattr(rig, "cur_dir", 0.0))
    target = math.radians(55.0)   # costas para a esquerda da tela e um pouco para longe da camera
    d = (target - ang + math.pi) % math.tau - math.pi
    alt = (-target - ang + math.pi) % math.tau - math.pi   # ou para a direita
    if abs(alt) < abs(d) - 0.3:
        d = alt
    prog = C.MR.keys(t, [(0.0, 0.0), (0.3, 0.15), (0.75, 1.0), (1.0, 1.0)])
    rig.root.rotation_euler = Euler((0, 0, d * prog))


# ------------------------------------------------------------------ roupas sobre pecas modulares Quaternius
def _sex(rig):
    return "Male" if rig.body == "male" else "Female"


def _mod(rig, part):
    """Caminho da peca modular (Male_/Female_), com o nome de pauldron que muda entre os sexos."""
    s = _sex(rig)
    if part == "Ranger_Acc_Pauldron" and s == "Female":
        part = "Ranger_Acc_Pauldrons"
    if part == "Ranger_Feet_Boots" and s == "Female":
        part = "Ranger_Feet"
    return os.path.join(Q.OUTFITS, "Modular Parts", f"{s}_{part}.gltf")


def _mirror_obj(o):
    """Copia espelhada em X (troca os grupos _l/_r): ombreira do outro lado."""
    import bmesh
    c = o.copy(); c.data = o.data.copy()
    bpy.context.scene.collection.objects.link(c)
    me = c.data
    for v in me.vertices:
        v.co.x = -v.co.x
    bm = bmesh.new(); bm.from_mesh(me)
    for f in bm.faces:
        f.normal_flip()
    bm.to_mesh(me); bm.free()
    for vg in c.vertex_groups:
        n = vg.name
        if n.endswith("_l"):
            vg.name = n[:-2] + "_TMPR"
        elif n.endswith("_r"):
            vg.name = n[:-2] + "_l"
    for vg in c.vertex_groups:
        if vg.name.endswith("_TMPR"):
            vg.name = vg.name[:-5] + "_r"
    me.update()
    return c


HAND_BONES = ("hand_", "index_", "middle_", "ring_", "pinky_", "thumb_")


def qpart(rig, part, group, cmap, special=None, drop=None, mirror=False, prio=1.0, only=None, hands="skin"):
    """Peca modular riggada no esqueleto do corpo. cmap: classe de cor -> material do pos (None = apaga);
    pele (material MI_Regular_*) vira 'skin'. special(centro, normal, classe, osso) -> material ou None;
    drop(centro, classe, osso) -> True apaga a face."""
    import bmesh
    fpart = part
    if only is None:
        only = [part]
    objs = Q.import_parts(_mod(rig, fpart), rig.arm)
    keep = []
    for o in objs:   # arquivo traz varios objetos (ex.: Arms + Arms_Bracer): fica so o pedido
        base = o.name.split(".")[0].split("_", 1)[1] if "_" in o.name else o.name
        if base in only or base.replace("Pauldrons", "Pauldron") in only or base.replace("Feet", "Feet_Boots") in only:
            keep.append(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)
    objs = keep
    part = only[0]
    if mirror:
        objs = objs + [_mirror_obj(o) for o in objs]
    short = part.split("_", 1)[1] if "_" in part else part
    for o in objs:
        fc = Q.face_colors(o)
        mats = [m.name if m else "" for m in o.data.materials]
        vg = {g.index: g.name for g in o.vertex_groups}
        best = []
        for v in o.data.vertices:
            w = max(v.groups, key=lambda gg: gg.weight, default=None)
            best.append(vg.get(w.group, "") if w else "")
        mw = o.matrix_world
        vals, kill = [], []
        for p, (cls0, rgb) in zip(o.data.polygons, fc):
            names = [best[i] for i in p.vertices]
            bn = max(set(names), key=names.count)
            mname = mats[min(p.material_index, len(mats) - 1)] if mats else ""
            cls = "skin" if "Regular" in mname or "Superhero" in mname else Q.ref_class(rgb)
            if hands and bn.startswith(HAND_BONES):
                cls = "skin" if hands == "skin" else "hand"
            cen = mw @ p.center
            nrm = (mw.to_3x3() @ p.normal).normalized()
            if drop and drop(cen, cls, bn):
                kill.append(p.index); vals.append(0.0); continue
            m = "skin" if cls == "skin" else (hands if cls == "hand" else None)
            if special and m is None:
                m = special(cen, nrm, cls, bn)
            if m is None:
                m = cmap.get(cls, cmap.get("*"))
            if m is None:
                kill.append(p.index); vals.append(0.0); continue
            bp = _bone_part(bn)
            vals.append(float(rig.pid(f"{short}_{bp}_{m}", m, group, prio=prio)))
        me = o.data
        attr = me.attributes.get("fpid") or me.attributes.new("fpid", 'FLOAT', 'FACE')
        attr.data.foreach_set("value", vals)
        if kill:
            bm = bmesh.new(); bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.faces[i] for i in kill], context='FACES')
            bm.to_mesh(me); bm.free()
        me.update()
        me.materials.clear(); me.materials.append(C.pass_material())
        o["pid"] = float(rig.pid(f"{short}_base", next(iter(cmap.values())) or "skin", group))
        o["group"] = group
        rig.meshes.append(o); rig.groups.setdefault(group, []).append(o)
    return objs


def body_skin(rig, group, bones, mat=None, inflate=0.0, special=None, prio=1.0):
    """Copia do corpo so nas partes indicadas: pele a mostra (antebracos numa roupa de manga curta) ou, com mat,
    roupa justa que segue o corpo exatamente (jeans), inflada 'inflate' metros ao longo da normal."""
    import bmesh
    src = rig.body_mesh
    c = src.copy(); c.data = src.data.copy()
    bpy.context.scene.collection.objects.link(c)
    me = c.data
    vg = {g.index: g.name for g in c.vertex_groups}
    best = []
    for v in me.vertices:
        w = max(v.groups, key=lambda gg: gg.weight, default=None)
        best.append(vg.get(w.group, "") if w else "")
    bm = bmesh.new(); bm.from_mesh(me)
    kill = []
    for f in bm.faces:
        names = [best[v.index] for v in f.verts]
        bn = max(set(names), key=names.count)
        if bn not in bones:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    if inflate:
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * (inflate / max(1e-6, c.matrix_world.to_scale().x))
    bm.to_mesh(me); bm.free(); me.update()
    if mat:
        attr = me.attributes.get("fpid") or me.attributes.new("fpid", 'FLOAT', 'FACE')
        mw = c.matrix_world
        vals = []
        for p in me.polygons:
            names = [best2[i] for i in p.vertices] if False else None
            m = special(mw @ p.center, (mw.to_3x3() @ p.normal).normalized()) if special else None
            m = m or mat
            vals.append(float(rig.pid(f"{group}_{m}_body", m, group, prio=prio)))
        attr.data.foreach_set("value", vals)
        me.update()
    me.materials.clear(); me.materials.append(C.pass_material())
    c["pid"] = float(rig.pid("torso", "skin", "body"))
    c["group"] = group
    rig.meshes.append(c); rig.groups.setdefault(group, []).append(c)
    return c


FOREARM = {"lowerarm_l", "lowerarm_r"}
LEGS = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}


def q_traveler(rig, body, P, W, J):
    g = "outfit:traveler"; k = rig.k
    front = lambda c, n, cls, bn: "tee" if abs(c.x) < 0.040 * rig.g and n.y < -0.3 and c.z > rig.world_loc["spine"].z - 0.02 else None  # noqa
    qpart(rig, "Peasant_Body", g, {"*": "hoodie"}, special=front)
    qpart(rig, "Peasant_Arms", g, {"*": "hoodie"},
          special=lambda c, n, cls, bn: "hoodie_rib" if bn.startswith("lowerarm") and cls in ("cloth_dark", "leather") else None)
    zh = 0.115 * rig.g   # jeans justo: as proprias pernas do corpo, infladas, pintadas de brim
    body_skin(rig, g, LEGS, mat="denim", inflate=0.010 * rig.g, special=lambda c, n: "denim_hem" if c.z < zh else None)
    zs = 0.125 * rig.g   # tenis: corta o cano da bota da peca Peasant
    qpart(rig, "Peasant_Feet", g, {"*": "sneaker"}, drop=lambda c, cls, bn: c.z > zs,
          special=lambda c, n, cls, bn: "sole" if c.z < 0.030 * rig.g else
          ("lace" if n.z > 0.45 and c.y < rig.q_feet["L"][0].y - 0.02 and c.z > 0.06 * rig.g else None))
    _traveler_extras(rig, P, W, J, g)


def _traveler_extras(rig, P, W, J, g):
    """Capuz, bordas do ziper, cordoes e a bolsa carteiro (procedurais, entortados para o corpo)."""
    k = rig.k; bust = P["bust"]
    for s in (1, -1):
        pts = [W((s * 0.052, -0.118 - bust * 0.5, 0.90)), W((s * 0.055, -0.128 - bust, 1.08)),
               W((s * 0.056, -0.134 - bust, 1.20)), W((s * 0.052, -0.118, 1.33)), W((s * 0.040, -0.075, 1.40))]
        rig.add(C.strip(f"zip_{s}", pts, 0.020 * k, normal=(0, -1, 0), thick=0.010), f"zip_{'L' if s > 0 else 'R'}", "hoodie_edge", J["chest"], g, prio=1.4)
        cord = [W((s * 0.030, -0.120, 1.37)), W((s * 0.034, -0.140 - bust, 1.27)), W((s * 0.032, -0.142 - bust, 1.20))]
        rig.add(C.strip(f"cord_{s}", cord, 0.010 * k, normal=(0, -1, 0), thick=0.012), f"cord_{'L' if s > 0 else 'R'}", "cord", J["chest"], g, prio=1.2)
    hood = C.ellipsoid("hood", W((0, 0.092, 1.380)), (0.100 * k, 0.048 * k, 0.056 * k), rot=(0.35, 0, 0))
    rig.add(hood, "hood", "hoodie", J["chest"], g, prio=1.0)
    collar = C.loft("collar", [(W((0, 0.020, 1.365)), P["neck_r"] * k + 0.040, P["neck_r"] * k + 0.038),
                               (W((0, 0.024, 1.420)), P["neck_r"] * k + 0.034, P["neck_r"] * k + 0.032)],
                    seg=20, arc=(0.55, math.tau - 0.55), cap0=False, cap1=False)
    rig.add(collar, "hood_collar", "hoodie", J["chest"], g)
    fr = [W((0.118, -0.050, 1.395)), W((0.100, -0.132 - bust * 0.4, 1.30)), W((0.030, -0.150 - bust, 1.17)),
          W((-0.070, -0.142, 1.05)), W((-0.150, -0.118, 0.955))]
    bk = [W((0.124, 0.030, 1.395)), W((0.090, 0.128, 1.28)), W((-0.020, 0.132, 1.12)), W((-0.140, 0.110, 0.98)),
          W((-0.170, 0.050, 0.93))]
    rig.add(C.strip("strap_f", fr, 0.030 * k, normal=(0, -1, 0.2), thick=0.008), "strap_f", "strap", J["chest"], g, prio=1.6)
    rig.add(C.strip("strap_b", bk, 0.030 * k, normal=(0, 1, 0.2), thick=0.008), "strap_b", "strap", J["chest"], g, prio=1.6)
    bag = C.box("bag", W((-0.200, -0.040, 0.885)), (0.070 * k, 0.190 * k, 0.160 * k), rot=(0, 0, -0.25), bevel=0.45)
    rig.face_parts(bag, lambda c, n: ("bag_flap", "bag_flap", {}) if c.z > 0.905 * k and n.x < 0.5 else None, g)
    rig.add(bag, "bag", "bag", J["pelvis"], g, prio=1.2)


def q_apprentice(rig, body, P, W, J):
    g = "outfit:apprentice"; k = rig.k
    qpart(rig, "Ranger_Body", g, {"green": "vest", "leather": "leather", "brown": "leather", "metal": "brass",
                                  "cloth_light": "shirt", "*": "leather"})
    qpart(rig, "Ranger_Arms", g, {"dkgreen": "shirt", "green": "shirt", "leather": "leather", "*": "leather"},
          drop=lambda c, cls, bn: bn in FOREARM and cls in ("dkgreen", "green"))
    body_skin(rig, g, FOREARM)
    qpart(rig, "Ranger_Arms", g, {"metal": "brass", "*": "leather"}, only=["Ranger_Arms_Bracer"])
    qpart(rig, "Ranger_Acc_Pauldron", g, {"*": "leather"})
    qpart(rig, "Ranger_Legs", g, {"*": "olive_pants"})
    qpart(rig, "Ranger_Feet_Boots", g, {"metal": "brass", "*": "boot"})
    # faixa vermelha com ponta, aba branca, alca diagonal
    sash = B._shell(rig, W, "app_sash", [0.94, 0.98, 1.02, 1.06], 0.040)
    rig.add(sash, "app_sash", "sash", J["pelvis"], g, prio=1.3)
    rig.add(C.ellipsoid("app_knot", W((0.110, -0.112, 0.985)), (0.040 * k, 0.030 * k, 0.040 * k)), "app_knot", "sash", J["pelvis"], g, prio=1.4)
    tail = C.strip("app_sash_tail", [W((0.120, -0.118, 0.97)), W((0.140, -0.126, 0.80)), W((0.150, -0.118, 0.60)), W((0.152, -0.108, 0.52))],
                   0.070 * k, normal=(0.3, -1, 0), thick=0.008)
    rig.face_parts(tail, lambda c, n: ("app_sash_stripe", "sash_stripe", {}) if 0.60 * k < c.z < 0.66 * k else None, g)
    rig.add(tail, "app_sash_tail", "sash", J["pelvis"], g, prio=1.4)
    B._skirt(rig, W, J, g, "app_flap", "shirt", 0.95, 0.60, 0.160, 0.180, 0.0, yb=-0.01,
             cut=lambda c, n: abs(B._ang(c)) > 1.15 or (c.z < (0.62 + 0.10 * max(0.0, c.x / k) * 3) * k))


def q_branch_coat(rig, body, P, W, J):
    g = "outfit:branch_coat"; k = rig.k
    qpart(rig, "Peasant_Body", g, {"cloth_light": "shirt", "*": "shirt"})
    qpart(rig, "Peasant_Arms", g, {"*": "navy"},
          special=lambda c, n, cls, bn: "gold" if bn.startswith("lowerarm") and cls in ("cloth_dark", "leather", "brown") else None)
    qpart(rig, "Peasant_Legs", g, {"*": "char_pants"})
    qpart(rig, "Ranger_Feet_Boots", g, {"metal": "gold", "*": "navy_boot"})
    coat = B._shell(rig, W, "bc_coat", [0.96, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.034, arc=(0.34, math.tau - 0.34))
    rig.face_parts(coat, lambda c, n: ("bc_lapel", "gold", {"prio": 1.4}) if abs(B._ang(c)) < 0.45 else None, g)
    rig.add(coat, "bc_coat", "navy", J["chest"], g, prio=1.05)
    collar = C.loft("bc_collar", [(W((0, 0.018, 1.360)), P["neck_r"] * k + 0.056, P["neck_r"] * k + 0.052),
                                  (W((0, 0.022, 1.470)), P["neck_r"] * k + 0.046, P["neck_r"] * k + 0.042)],
                    seg=24, arc=(0.75, math.tau - 0.75))
    rig.face_parts(collar, lambda c, n: ("bc_collar_rim", "gold", {"prio": 1.4}) if c.z > 1.455 * k or abs(B._ang(c)) < 0.85 else None, g)
    rig.add(collar, "bc_collar", "navy", J["chest"], g, prio=1.1)
    B._skirt(rig, W, J, g, "bc_skirt", "navy", 1.00, 0.40, 0.170, 0.225, 0.36, trim="gold", emb="gold")
    belt = B._shell(rig, W, "bc_belt", [0.975, 1.00, 1.03], 0.046)
    rig.add(belt, "bc_belt", "belt", J["pelvis"], g, prio=1.3)
    rig.add(C.box("bc_buckle", W((0, -0.136, 1.003)), (0.050 * k, 0.018 * k, 0.040 * k)), "bc_buckle", "gold", J["pelvis"], g, prio=2.0)
    for x in (-0.012, 0.012):
        t = C.strip(f"bc_tassel{x}", [W((x, -0.140, 0.985)), W((x * 1.5, -0.143, 0.88)), W((x * 2, -0.138, 0.80))], 0.012 * k,
                    normal=(0, -1, 0), thick=0.006)
        rig.add(t, f"bc_tassel{x}", "gold", J["pelvis"], g, prio=1.8)
    rig.add(C.ellipsoid("bc_brooch", W((0, -0.114, 1.360)), (0.016 * k, 0.010 * k, 0.020 * k)), "bc_brooch", "gem_green", J["chest"], g, prio=3.0, noline=True)


def q_master_armor(rig, body, P, W, J):
    g = "outfit:master_armor"; k = rig.k
    qpart(rig, "Ranger_Body", g, {"green": "iron", "leather": "crimson", "brown": "crimson", "metal": "gold", "*": "iron"})
    qpart(rig, "Ranger_Body", g, {"metal": "gold", "*": "belt"}, only=["Ranger_Body_Belt_1"])
    qpart(rig, "Ranger_Arms", g, {"dkgreen": "crimson", "green": "crimson", "*": "iron"}, hands="glove")
    qpart(rig, "Ranger_Arms", g, {"metal": "gold", "*": "iron"}, only=["Ranger_Arms_Bracer"])
    qpart(rig, "Ranger_Acc_Pauldron", g, {"metal": "iron", "*": "iron"}, mirror=(rig.body == "male"),
          special=lambda c, n, cls, bn: "gold" if cls == "metal" and n.z < -0.2 else None)
    qpart(rig, "Ranger_Legs", g, {"*": "char_pants"})
    qpart(rig, "Ranger_Feet_Boots", g, {"metal": "gold", "*": "iron_boot"})
    B._skirt(rig, W, J, g, "ma_skirt", "crimson", 1.00, 0.42, 0.175, 0.235, 0.42, trim="gold", emb="gold")
    for s in (1, -1):
        pn = C.strip(f"ma_panel{s}", [W((s * 0.060, -0.148, 0.99)), W((s * 0.066, -0.158, 0.80)), W((s * 0.070, -0.158, 0.52))],
                     0.070 * k, normal=(0, -1, 0), thick=0.008)
        rig.face_parts(pn, lambda c, n: ("ma_panel_rim", "gold", {"prio": 1.5}) if c.z < 0.55 * k else None, g)
        rig.add(pn, f"ma_panel{s}", "jade", J["pelvis"], g, prio=1.3)
    rig.add(C.ellipsoid("ma_gem", W((0, -0.150, 1.003)), (0.014 * k, 0.008 * k, 0.016 * k)), "ma_gem", "gem_amber", J["pelvis"], g, prio=3.0, noline=True)
    sc = C.loft("ma_scarf", [(W((0, 0.012, 1.355)), P["neck_r"] * k + 0.064, P["neck_r"] * k + 0.062),
                             (W((0, 0.010, 1.395)), P["neck_r"] * k + 0.056, P["neck_r"] * k + 0.054),
                             (W((0, 0.010, 1.440)), P["neck_r"] * k + 0.038, P["neck_r"] * k + 0.036)], seg=24)
    rig.add(sc, "ma_scarf", "scarf", J["chest"], g, prio=1.4)


def q_leather_jerkin(rig, body, P, W, J):
    g = "outfit:leather_jerkin"; k = rig.k
    qpart(rig, "Peasant_Body", g, {"cloth_light": "tee", "*": "leather"})
    qpart(rig, "Peasant_Arms", g, {"*": "tee"})
    body_skin(rig, g, LEGS, mat="denim", inflate=0.010 * rig.g, special=lambda c, n: "denim_hem" if c.z < 0.115 * rig.g else None)
    qpart(rig, "Peasant_Feet", g, {"*": "sneaker"}, drop=lambda c, cls, bn: c.z > 0.125 * rig.g,
          special=lambda c, n, cls, bn: "sole" if c.z < 0.030 * rig.g else None)
    vest = B._shell(rig, W, "lj_vest", [0.90, 0.96, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.034, arc=(0.10, math.tau - 0.10))
    rig.face_parts(vest, lambda c, n: ("lj_ties", "strap_dark", {"prio": 1.4}) if abs(B._ang(c)) < 0.30 and int(c.z / k * 30) % 3 == 0 else None, g)
    rig.add(vest, "lj_vest", "leather", J["chest"], g, prio=1.05)


Q_OUTFITS = {"traveler": q_traveler, "apprentice": q_apprentice, "branch_coat": q_branch_coat,
             "master_armor": q_master_armor, "leather_jerkin": q_leather_jerkin}
