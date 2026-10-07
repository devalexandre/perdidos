"""Especie feita a partir de um modelo de pack CC0 (declarativo). Cada arquivo de especie faz:
    import pack_species as PS
    S = PS.PackSpecies("spirit_fox_cub", PS.pack("ultimate-animated-animals", "Fox.gltf"), ...)
    FRAME, ANIMS, STAGES, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
Parametros principais:
  heights {estagio: m}  altura final do modelo (define o tamanho; relativo ao Viajante, GDD 10.2.1)
  matmap / colormap     repintura com rampas da paleta (post.MATS)
  bones {osso: escala}  reforma (heranca de escala desligada: cada osso tem a propria escala)
  stage_bones {estagio: {osso: escala}}  reforma extra por estagio
  rot_bones {osso: (x, y, z)}  rotacao fixa somada a animacao (radianos)
  actions {anim: nome ou (nome, inicio, fim)}  acoes do pack por animacao nossa
  extras(rig, pk, stage)       pecas nossas (primitivas de mon_rig) presas a ossos com PM.attach
  motion: "walk" (trote com quique), "hop" (pulinhos), "fly" (paira) — squash & stretch nosso por cima
  after_pose(rig, anim, i, n, stage)  ajuste final por quadro (brilhos, chamas...)"""
import os, math
import bpy
from mathutils import Vector
import mon_rig as R
import pack_model as PM

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
PACKS = os.path.join(ROOT, ".work", "b3", "packs")
DEFAULT_ACTIONS = {"idle": "Idle", "walk": "Walk", "attack": "Attack", "hit": "Idle_HitReact1", "death": "Death"}


# Reforma "filhote" para o esqueleto do Ultimate Animated Animals (Fox, ShibaInu, Husky, Wolf, Horse, Deer...):
# cabeca grande e levantada, pescoco/corpo/patas curtos e grossos, rabo fofo.
ANIMAL_SPINE = ["Back", "Torso", "Torso2", "Torso3"]
ANIMAL_LEGS = ["FrontUpperLeg.L", "FrontLowerLeg.L", "FrontUpperLeg.R", "FrontLowerLeg.R", "BackLeg.L",
               "BackUpperLeg.L", "BackLowerLeg.L", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R"]
# so a raiz de cada perna recebe escala (os filhos herdam): coxa da frente e "BackLeg" de tras
ANIMAL_LEG_ROOTS = ["FrontUpperLeg.L", "FrontUpperLeg.R", "BackLeg.L", "BackLeg.R"]


def animal_chibi(head=2.8, neck=(1.3, 0.5, 1.3), spine=(1.4, 0.5, 1.4), legs=(1.3, 0.6, 1.3), tail=(2.2, 0.6, 2.2),
                 ears=1.2, ntail=8):
    b = {"Head": head}
    b.update({f"Neck{k}": neck for k in (1, 2, 3)})
    b.update({x: spine for x in ANIMAL_SPINE})
    b.update({x: legs for x in ANIMAL_LEG_ROOTS})
    b.update({f"Tail{k}": tail for k in range(1, ntail + 1)})
    b.update({f"Ear{k}.{s}": ears for k in range(1, 5) for s in "LR"})
    return b


def head_box(pk, groups=("Head",)):
    lo, hi = PM.group_bbox(pk, list(groups))
    return lo, hi, (lo + hi) / 2


def pack(*parts):
    """Caminho de um arquivo dentro de .work/b3/packs (procura o nome em subpastas: glTF/, Big/glTF/...)."""
    base = os.path.join(PACKS, parts[0])
    name = parts[-1]
    sub = os.path.join(base, *parts[1:])
    if os.path.exists(sub):
        return sub
    for dp, dn, fn in os.walk(base):
        if name in fn and (len(parts) < 3 or parts[1] in dp):
            return os.path.join(dp, name)
    raise FileNotFoundError(sub)


class PackSpecies:
    def __init__(self, sid, path, heights, frames=None, yaw=0.0, matmap=None, colormap=None, bones=None,
                 stage_bones=None, rot_bones=None, hide_bones=(), hide_objects=(), actions=None, extras=None,
                 motion="walk", lean=0.0, after_pose=None, stages=(1, 2), anims=None, fit_action=None,
                 hop_height=0.12, hover=0.0, flags=None, leg_bones=()):
        self.sid, self.path, self.heights = sid, path, heights
        self.FRAME = frames or {1: 96, 2: 144, 3: 240}
        self.yaw, self.matmap, self.colormap = yaw, matmap, colormap
        self.bones = bones or {}
        self.stage_bones = stage_bones or {}
        self.rot_bones = rot_bones or {}
        self.hide_bones, self.hide_objects = hide_bones, hide_objects
        self.actions = dict(DEFAULT_ACTIONS, **(actions or {}))
        self.extras, self.after_pose = extras, after_pose
        self.motion, self.lean = motion, lean
        self.STAGES = stages
        self.ANIMS = anims or [("idle", 8), ("walk", 8), ("attack", 8), ("hit", 4), ("death", 8)]
        self.fit_action = fit_action or self._act("idle")[0]
        self.hop_height, self.hover = hop_height, hover
        self.flags = flags or {}
        self.leg_bones = leg_bones

    def _act(self, anim):
        a = self.actions[anim]
        return (a, 0.0, 1.0) if isinstance(a, str) else a

    # ------------------------------------------------------------------ modelo
    def build(self, stage):
        R.reset()
        R.CUR["reach"] = (0.25, 0.3, 0.25)
        rig = R.Rig(self.sid)
        rig.set_lean(self.lean)
        pk = PM.import_model(rig, self.path, self.matmap, self.colormap, parent=rig.root, yaw_deg=self.yaw,
                             hide_objects=self.hide_objects, flags=self.flags)
        if pk.armature is not None:
            legs = set(self.leg_bones)
            for b in pk.armature.data.bones:
                # pernas herdam a escala (a coxa curta encurta a canela junto); o resto e independente
                b.inherit_scale = 'FULL' if (b.name in legs or (b.parent and b.parent.name in legs)) else 'NONE'
            bs = dict(self.bones)
            bs.update(self.stage_bones.get(stage, {}))
            for b, s in bs.items():
                PM.bone_scale(pk, b, s)
            for b in self.hide_bones:
                PM.bone_scale(pk, b, 0.001)
            for b, e in self.rot_bones.items():
                PM.bone_rot(pk, b, e)
        PM.fit(pk, self.heights[stage], self.fit_action if pk.armature else None)
        rig.pack = pk
        # pecas nossas em coordenadas do modelo ja ajustado (m); presas aos ossos na pose de descanso
        if self.extras:
            self.extras(rig, pk, stage)
        # altura final = modelo inteiro (pack + pecas nossas): reescala pelo "turn" (pivo no chao)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        zmax = 0.0
        for o in rig.meshes:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            if len(me.vertices):
                zmax = max(zmax, max((ev.matrix_world @ v.co).z for v in me.vertices))
            ev.to_mesh_clear()
        if zmax > 0:
            k = self.heights[stage] / zmax
            print(f"[pack] {self.sid} s{stage}: altura antes {zmax:.3f} m -> escala {k:.3f}")
            rig.turn.scale = (k, k, k)
        rig.save_rest()
        # reach do squash ancorado ~ metade do comprimento no chao
        lo, hi = PM.bbox(pk)
        k = rig.turn.scale.x
        R.CUR["reach"] = (max(0.1, -lo.y / k), max(0.1, hi.y / k), max(0.1, (hi.x - lo.x) / 2 / k))
        rig.reach = R.CUR["reach"]
        return rig

    # ------------------------------------------------------------------ animacao
    pitch = 55.0
    _base = {}

    def _screen_low(self, rig):
        """Menor y*sin(p) + z*cos(p) dos vertices (mundo): o ponto mais baixo na tela da camera do jogo."""
        p = math.radians(R.CUR.get("pitch", self.pitch))
        sp, cp = math.sin(p), math.cos(p)
        dg = bpy.context.evaluated_depsgraph_get()
        m = 1e9
        for o in rig.meshes:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            mw = ev.matrix_world
            for vv in me.vertices:
                w = mw @ vv.co
                m = min(m, w.y * sp + w.z * cp)
            ev.to_mesh_clear()
        return m

    def pose(self, rig, anim, i, n, stage):
        R.CUR["reach"] = rig.reach
        pk = rig.pack
        name, a0, a1 = self._act(anim)
        loop = anim in ("idle", "walk")
        if pk.armature is not None:
            PM.play(pk, name, i, n, loop=loop, span=(a0, a1))
        t = i / n
        root = rig.root
        if anim == "idle":
            s = math.sin(math.tau * t)
            R.squash(root, 1.0 + 0.04 * s)
            if self.motion == "fly":
                root.location.z += self.hover + 0.05 * math.sin(math.tau * t)
        elif anim == "walk":
            if self.motion == "hop":
                ph = (2 * t) % 1.0
                hop = 4 * ph * (1 - ph)
                root.location.z += self.hop_height * hop
                R.squash(root, 0.85 + 0.3 * hop if ph > 0.1 else 0.82)
            elif self.motion == "fly":
                root.location.z += self.hover + 0.06 * math.sin(math.tau * 2 * t)
                R.squash(root, 1.0 + 0.05 * math.sin(math.tau * 2 * t), anchored=False)
            else:
                b = abs(math.sin(math.tau * t))
                root.location.z += 0.03 * b
                R.squash(root, 1.0 + 0.06 * (b - 0.5))
        elif anim == "attack":
            sq = [0.86, 0.8, 1.16, 1.1, 0.88, 1.04, 0.97, 1.0][min(i, 7)]
            R.squash(root, sq)
            if self.motion == "fly":
                root.location.z += self.hover
        elif anim == "hit":
            R.squash(root, [0.8, 1.12, 0.95, 1.02][min(i, 3)])
            if self.motion == "fly":
                root.location.z += self.hover * [0.8, 1.0, 0.95, 1.0][min(i, 3)]
        elif anim == "death":
            R.squash(root, [0.85, 1.08, 0.95, 0.85, 1.04, 0.97, 1.0, 1.0][min(i, 7)])
            if self.motion == "fly":
                root.location.z += self.hover * max(0.0, 1 - i / 3)
        if self.after_pose:
            self.after_pose(rig, anim, i, n, stage)
        # nunca abaixo do chao (acoes de morte/voo do pack descem o corpo): sobe o root o que faltar
        bpy.context.view_layer.update()
        lo, hi = PM.bbox(pk)
        if lo.z < 0:
            root.location.z += -lo.z / max(1e-6, rig.turn.scale.z)
        # golpe/morte do pack jogam o corpo para a frente/lado: na tela isso desce o sprite e faz o parado "flutuar"
        # (o recorte usa o ponto mais baixo de todos os quadros). Empurra para longe da camera o que passar do parado.
        v = self._screen_low(rig)
        key = R.CUR["dir"]
        if anim == "idle" and i == 0:
            self._base[key] = v
        elif anim in ("attack", "death", "hit") and key in self._base:
            over = self._base[key] - v - 0.06
            if over > 0:
                p = math.radians(R.CUR.get("pitch", self.pitch))
                d = over / math.sin(p)          # m no chao (mundo), para longe da camera = +Y
                a = math.radians(key)
                k = max(1e-6, rig.turn.scale.x)
                root.location.x += d * math.sin(a) / k   # (0, d) do mundo no espaco girado do "turn"
                root.location.y += d * math.cos(a) / k


# ------------------------------------------------------------------ pecas nossas
def add(rig, pk, bone, obj, part, mat, **flags):
    """Registra uma peca nossa (malha de mon_rig) e prende ao osso (ou ao root se bone=None)."""
    rig.add_mesh(obj, part, mat, None, **flags)
    if bone and pk.armature is not None:
        PM.attach(obj, pk, bone)
    else:
        obj.parent = rig.root
    return obj


def bpos(pk, bone, tail=False):
    return PM.bone_head(pk, bone, tail)


def eye_pair(rig, pk, bone, center, side, r, forward=Vector((0, -1, 0)), iris="eye", hl=True, prio=2.0, yaw=0.45):
    """Olhos grandes e brilhantes (padrao do projeto) em volta de center (m), afastados side no eixo X."""
    out = []
    for sx, nm in ((1, "L"), (-1, "R")):
        p = center + Vector((side * sx, 0, 0))
        e = add(rig, pk, bone, R.ellipsoid(f"eye{nm}", p, (r, r * 0.5, r * 1.15), rot=(0.25, 0, -yaw * sx)),
                f"eye{nm}", iris, noline=True, unlit=True, prio=prio)
        out.append(e)
        if hl:
            add(rig, pk, bone, R.ellipsoid(f"hl{nm}", p + Vector((-r * 0.35, -r * 0.6, r * 0.4)), (r * 0.38,) * 3),
                f"hl{nm}", "white", noline=True, unlit=True, prio=prio * 3)
    return out


def chibi_head(rig, pk, bone, center, size, skin="skin", muzzle=None, nose="nose", ear="pointy", ear_mat=None,
               ear_in="nose", snout=0.55, brows=False, cheeks=True, eye_mat="eye", tilt=0.3, prefix="h", head_up=0.45,
               beak=None, snout_w=1.0, snout_h=1.0):
    """Cabeca de filhote no padrao do projeto (igual ao Tatu-Pedra): esfera grande, focinho, nariz, olhos grandes com
    brilho, orelhas (pointy = raposa/gato, round = urso/tanuki, long = cavalo/cabra, none), bochechas. Presa ao osso
    da cabeca do pack (a animacao do pack mexe a cabeca). size = raio (m). Olhando para -Y."""
    c = Vector(center)
    r = size
    # pivo proprio (rosto levantado para a camera alta, como o Tatu-Pedra), preso ao osso da cabeca do pack
    piv = rig.empty(f"{prefix}pivot", c, rig.root)
    bone_ = bone

    def add(rig_, pk_, _bone, obj, part, mat, **fl):
        rig_.add_mesh(obj, part, mat, piv, **fl)
        return obj
    add(rig, pk, bone, R.ellipsoid(f"{prefix}head", c, (r, r * 0.92, r * 0.9)), f"{prefix}head", skin, group=f"{prefix}head")
    sn = c + Vector((0, -r * 0.82, -r * 0.28))
    if beak:
        b0 = c + Vector((0, -r * 0.78, -r * 0.18))
        add(rig, pk, bone, R.cone(f"{prefix}beak", b0, b0 + Vector((0, -r * 0.55, -r * 0.2)), r * 0.28, r * 0.03, seg=8,
                                  rings=3, bend=(0, 0, -r * 0.08)), f"{prefix}beak", beak)
    elif snout > 0:
        add(rig, pk, bone, R.ellipsoid(f"{prefix}snout", sn, (r * 0.42 * snout_w, r * snout, r * 0.34 * snout_h), rot=(0.25, 0, 0)),
            f"{prefix}snout", muzzle or skin, group=f"{prefix}head")
        if nose:
            add(rig, pk, bone, R.ellipsoid(f"{prefix}nose", sn + Vector((0, -r * snout * 0.9, r * 0.14)), (r * 0.16, r * 0.1, r * 0.12)),
                f"{prefix}nose", nose, noline=True, prio=2.0)
    for sx, nm in ((1, "L"), (-1, "R")):
        ep = c + Vector((0.36 * r * sx, -0.8 * r, 0.16 * r))
        add(rig, pk, bone, R.ellipsoid(f"{prefix}eye{nm}", ep, (0.25 * r, 0.14 * r, 0.31 * r), rot=(tilt, 0, -0.38 * sx)),
            f"{prefix}eye{nm}", eye_mat, noline=True, unlit=True, prio=1.8)
        add(rig, pk, bone, R.ellipsoid(f"{prefix}hl{nm}", ep + Vector((-0.08 * r, -0.13 * r, 0.1 * r)), (0.1 * r,) * 3),
            f"{prefix}hl{nm}", "white", noline=True, unlit=True, prio=6.0)
        if brows:
            add(rig, pk, bone, R.cone(f"{prefix}brow{nm}", ep + Vector((-0.2 * r * sx, -0.1 * r, 0.3 * r)),
                                      ep + Vector((0.25 * r * sx, -0.02 * r, 0.42 * r)), 0.05 * r, 0.04 * r, seg=6, rings=1),
                f"{prefix}brow{nm}", "brow", noline=True, unlit=True, prio=2.0)
        if cheeks:
            add(rig, pk, bone, R.ellipsoid(f"{prefix}cheek{nm}", c + Vector((0.6 * r * sx, -0.72 * r, -0.2 * r)),
                                           (0.14 * r, 0.05 * r, 0.09 * r), rot=(0, 0, -0.7 * sx)),
                f"{prefix}cheek{nm}", "blush", noline=True, unlit=True, prio=1.2)
        if ear == "none":
            continue
        em = ear_mat or skin
        if ear == "pointy":
            b0 = c + Vector((0.55 * r * sx, 0.05 * r, 0.62 * r)); b1 = b0 + Vector((0.18 * r * sx, 0.05 * r, 0.62 * r))
            add(rig, pk, bone, R.cone(f"{prefix}ear{nm}", b0, b1, 0.3 * r, 0.03 * r, seg=8, rings=2), f"{prefix}ear{nm}", em)
            add(rig, pk, bone, R.cone(f"{prefix}earin{nm}", b0 + Vector((0, -0.12 * r, 0.06 * r)), b1 + Vector((0, -0.1 * r, -0.12 * r)),
                                      0.17 * r, 0.02 * r, seg=8, rings=1), f"{prefix}earin{nm}", ear_in, noline=True)
        elif ear == "round":
            p = c + Vector((0.62 * r * sx, 0.05 * r, 0.62 * r))
            add(rig, pk, bone, R.ellipsoid(f"{prefix}ear{nm}", p, (0.26 * r, 0.14 * r, 0.26 * r)), f"{prefix}ear{nm}", em)
            add(rig, pk, bone, R.ellipsoid(f"{prefix}earin{nm}", p + Vector((0, -0.1 * r, -0.02 * r)), (0.15 * r, 0.06 * r, 0.15 * r)),
                f"{prefix}earin{nm}", ear_in, noline=True)
        elif ear == "long":
            b0 = c + Vector((0.5 * r * sx, 0.1 * r, 0.55 * r)); b1 = b0 + Vector((0.45 * r * sx, 0.1 * r, 0.35 * r))
            add(rig, pk, bone, R.cone(f"{prefix}ear{nm}", b0, b1, 0.16 * r, 0.05 * r, seg=8, rings=2), f"{prefix}ear{nm}", em)
    piv.rotation_euler.x = -head_up
    if bone_ and pk.armature is not None:
        PM.attach(piv, pk, bone_)
    rig.head_pivot = piv
    return c


def hide_animal_head(pk, groups=None):
    """Tira a cabeca original do pack da malha (vertices dos grupos Head/Ear*); a nossa cabeca de filhote entra no
    lugar, presa ao mesmo osso (a animacao do pack continua mexendo a cabeca)."""
    groups = groups or ["Head"] + [f"Ear{k}.{s}" for k in range(1, 5) for s in "LR"]
    PM.delete_group_verts(pk, groups)


def fluff_body(rig, pk, fur, belly=None, bones=("Back", "Torso", "Torso2", "Torso3"), fat=1.0, prefix="fb"):
    """Corpo gordinho nosso (uma elipsoide lisa) por cima do tronco fino do pack, preso ao meio da coluna; as patas,
    o pescoco e o rabo do pack continuam animando."""
    lo, hi = PM.group_bbox(pk, list(bones), 0.3)
    thick = max(hi.x - lo.x, hi.z - lo.z) * 0.5
    print(f"[pack] corpo: espessura {thick:.3f} m")
    front, back = bpos(pk, bones[-1], True), bpos(pk, bones[0])
    c = (front + back) / 2 + Vector((0, 0, -0.1 * thick))
    L = (front - back).length
    mid = bones[len(bones) // 2]
    radii = (thick * 1.3 * fat, L * 0.5 + thick * 0.45, thick * 1.25 * fat)
    add(rig, pk, mid, R.ellipsoid(f"{prefix}", c, radii), f"{prefix}", fur, group=prefix)
    rig.body = (mid, c, radii)
    if belly:
        add(rig, pk, mid, R.ellipsoid(f"{prefix}belly", c + Vector((0, -0.1 * L, -0.55 * thick * fat)),
                                      (thick * 0.95 * fat, L * 0.42, thick * 0.75 * fat)), f"{prefix}belly", belly)
    return thick


def animal_cub(sid, base, heights, fur, matmap, head=None, extra=None, bones=None, actions=None, head_frac=0.4,
               head_offset=(0.0, -0.25, 0.45), body=True, belly=None, fat=1.0, **kw):
    """Filhote a partir do esqueleto/animacoes do Ultimate Animated Animals: corpo do pack reformado
    (animal_chibi), cabeca nossa (chibi_head) e pecas extras. head: kwargs de chibi_head; extra(rig, pk, stage, c, r)."""
    b = dict(bones or {})
    hk = dict(skin=fur, muzzle=fur)
    hk.update(head or {})

    def extras(rig, pk, stage):
        h0 = bpos(pk, "Head")
        hgt = heights[stage]
        r = head_frac * hgt * 0.8
        c = h0 + Vector(head_offset) * r
        hide_animal_head(pk)
        if body:
            fluff_body(rig, pk, fur, belly, fat=fat)
        kk = dict(hk)
        if callable(kk.get("brows")):
            kk["brows"] = kk["brows"](stage)
        chibi_head(rig, pk, "Head", c, r, **kk)
        if extra:
            extra(rig, pk, stage, c, r)
    acts = {"attack": "Attack", "hit": "Idle_HitReact1", "death": "Death"}
    acts.update(actions or {})
    return PackSpecies(sid, pack("ultimate-animated-animals", base), heights=heights, matmap=matmap, bones=b,
                       extras=extras, actions=acts, leg_bones=ANIMAL_LEGS, **kw)


def tail_ring(pk, n=8):
    """Posicoes (inicio, fim) dos ossos do rabo, para pecas ao longo dele."""
    return [(bpos(pk, f"Tail{k}"), bpos(pk, f"Tail{k}", True)) for k in range(1, n + 1)
            if pk.armature and f"Tail{k}" in pk.armature.pose.bones]


def spots(rig, pk, bone, center, radius, n, mat, size, seed=1, up_only=True, prefix="spot"):
    """Manchas/rosetas (jaguar) espalhadas numa casca esferica em volta de center, presas ao osso."""
    import random
    rnd = random.Random(seed)
    out = []
    for k in range(n):
        th = rnd.uniform(0.2, 1.3 if up_only else 2.8)
        ph = rnd.uniform(0, math.tau)
        d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
        p = Vector(center) + Vector((d.x * radius[0], d.y * radius[1], d.z * radius[2]))
        q = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        out.append(add(rig, pk, bone, R.ellipsoid(f"{prefix}{k}", p, (size, size * 0.8, size * 0.25), rot=q, seg=8, rings=5),
                       f"{prefix}{k}", mat, noline=True))
    return out
