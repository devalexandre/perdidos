"""Efeito "anime" da Faisca (arcane_spark): renderiza no Blender (EEVEE, sem luz) os quadros em alta da
explosao em cogumelo e da lanca de fogo, com sombreamento toon (rampa de cor em faixas, sem textura) e
contorno de anime (casco invertido). Saida: quadros RGBA soltos em <OUT>/<peca>/NNNN.png e
<OUT>/<peca>/meta.json (pivo do chao em px e metros por px). Quem monta as folhas do jogo e o
build_anime_fx.py (contorno ja vem daqui; o brilho aditivo e tirado do quadro la).

  .tools/blender/blender -b --factory-startup -P game/tools/art/fx/anime/fire_lance_blender.py -- OUT

Formas: bolhas de metaball (a uniao de esferas da a nuvem "couve-flor" da explosao de anime) que crescem,
sobem e se desfazem; espinhos (cones) atras da bola no estouro; anel de fumaca em bolinhas que sai pelo
chao e sobe; lanca = fuso afinando para cima com labaredas laterais que tremem. Tudo procedural (sem
imagem de entrada). Cores: rampas quentes da paleta-mestra (nao quantizadas no quadro final).
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGV[0] if ARGV else ".work/fx-pilot/raw")
ONLY = set(ARGV[1].split(",")) if len(ARGV) > 1 else None

# --- explosao
BLAST_FRAMES = 24
BLAST_PX = 320
BLAST_WORLD = 3.4          # m cobertos pela largura do quadro
BLAST_ELEV_DEG = 38.0      # camera do Blender um pouco de cima (o jogo olha a 57 graus; a peca e billboard)
# --- lanca
LANCE_FRAMES = 6
LANCE_PX = (128, 448)
LANCE_WORLD = 3.0          # m cobertos pela altura do quadro
LANCE_ELEV_DEG = 8.0
OUTLINE_FIRE = 0.028       # espessura do contorno (m)
OUTLINE_SMOKE = 0.024


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


# rampas (posicao, cor sRGB): fogo do vermelho-vinho ao creme; fumaca cinza-quente
FIRE_RAMP = [(0.0, "#9c1f10"), (0.30, "#e0441c"), (0.47, "#f9862a"), (0.62, "#ffc23c"), (0.77, "#ffe98a"),
             (0.88, "#fffbe8")]
SPIKE_RAMP = [(0.0, "#b3260f"), (0.45, "#ec5a1e"), (0.7, "#ff9a2e")]
SMOKE_RAMP = [(0.0, "#7a6f68"), (0.40, "#a89e92"), (0.68, "#d8d0c2"), (0.86, "#f1ebde")]
LANCE_RAMP = [(0.0, "#c62f12"), (0.28, "#f6741f"), (0.48, "#ffb534"), (0.66, "#ffe68a"), (0.80, "#fffdf2")]
FIRE_LINE = "#5a0d07"
SMOKE_LINE = "#3a2f2b"
LANCE_LINE = "#7e1608"
# luz "pintada" (de cima, esquerda, frente da camera)
LIGHT = Vector((-0.45, -0.6, 0.75)).normalized()


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.eevee.taa_render_samples = 16
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0, 0, 0)
    return sc


def toon_material(name, ramp, w_light=0.42, w_face=0.58, noise=0.10):
    """Emissao = rampa constante(luz pintada + quanto a face olha para a camera + calor + ruido)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LIGHT
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    lam = nt.nodes.new("ShaderNodeMapRange")
    lam.inputs["From Min"].default_value = -1.0
    nt.links.new(dot.outputs["Value"], lam.inputs["Value"])
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs["Facing"], inv.inputs[1])
    tex = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.noise_dimensions = "4D"
    nz.inputs["Scale"].default_value = 2.6
    nz.inputs["Detail"].default_value = 1.0
    nt.links.new(tex.outputs["Object"], nz.inputs["Vector"])
    nz.name = "Noise"
    # f = w_light*lam + w_face*(1-facing) + noise*(n-0.5) + heat
    a = nt.nodes.new("ShaderNodeMath"); a.operation = "MULTIPLY"; a.inputs[1].default_value = w_light
    nt.links.new(lam.outputs["Result"], a.inputs[0])
    b = nt.nodes.new("ShaderNodeMath"); b.operation = "MULTIPLY"; b.inputs[1].default_value = w_face
    nt.links.new(inv.outputs["Value"], b.inputs[0])
    c = nt.nodes.new("ShaderNodeMath"); c.operation = "MULTIPLY_ADD"
    c.inputs[1].default_value = noise
    c.inputs[2].default_value = -0.5 * noise
    nt.links.new(nz.outputs["Fac"], c.inputs[0])
    s1 = nt.nodes.new("ShaderNodeMath"); s1.operation = "ADD"
    nt.links.new(a.outputs["Value"], s1.inputs[0]); nt.links.new(b.outputs["Value"], s1.inputs[1])
    s2 = nt.nodes.new("ShaderNodeMath"); s2.operation = "ADD"
    nt.links.new(s1.outputs["Value"], s2.inputs[0]); nt.links.new(c.outputs["Value"], s2.inputs[1])
    heat = nt.nodes.new("ShaderNodeValue"); heat.name = "Heat"; heat.outputs[0].default_value = 0.0
    s3 = nt.nodes.new("ShaderNodeMath"); s3.operation = "ADD"; s3.use_clamp = True
    nt.links.new(s2.outputs["Value"], s3.inputs[0]); nt.links.new(heat.outputs[0], s3.inputs[1])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    cr.color_ramp.interpolation = "CONSTANT"
    els = cr.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position = ramp[0][0]
    els[0].color = srgb(ramp[0][1])
    for pos, col in ramp[1:]:
        e = els.new(pos)
        e.color = srgb(col)
    nt.links.new(s3.outputs["Value"], cr.inputs["Fac"])
    nt.links.new(cr.outputs["Color"], em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def line_material(name, col):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = srgb(col)
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    m.use_backface_culling = True
    return m


def set_heat(mat, h, w):
    mat.node_tree.nodes["Heat"].outputs[0].default_value = h
    mat.node_tree.nodes["Noise"].inputs["W"].default_value = w


def camera(sc, elev_deg, look_at, ortho, res):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(cam)
    e = math.radians(elev_deg)
    cam.location = Vector(look_at) + Vector((0.0, -math.cos(e), math.sin(e))) * 20.0
    d = Vector(look_at) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    return cam


def mesh_obj(sc, name, mat):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def fill_from_meta(sc, meta_ob, fill_ob, hull_ob, width):
    """Malha da metaball avaliada -> objeto de preenchimento + casco invertido (contorno)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(meta_ob.evaluated_get(dg))
    set_mesh(fill_ob, me)
    set_hull(hull_ob, me, width)


def set_mesh(ob, me):
    old = ob.data
    mats = list(old.materials)
    ob.data = me.copy() if me.users else me
    ob.data.materials.clear()
    for m in mats:
        ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    if old.users == 0:
        bpy.data.meshes.remove(old)


def set_hull(ob, me, width):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * width
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    hm = bpy.data.meshes.new(ob.name + "_m")
    bm.to_mesh(hm)
    bm.free()
    set_mesh(ob, hm)


def render(sc, path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def pivot_px(sc, cam, world_pt):
    co = world_to_camera_view(sc, cam, Vector(world_pt))
    return [round(co.x * sc.render.resolution_x, 2), round((1.0 - co.y) * sc.render.resolution_y, 2)]


def ease_out(x):
    x = min(max(x, 0.0), 1.0)
    return 1.0 - (1.0 - x) ** 3


def smooth(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------------------------- explosao

def blast():
    sc = reset()
    rnd = random.Random(7)
    cam = camera(sc, BLAST_ELEV_DEG, (0.0, 0.0, 0.95), BLAST_WORLD, (BLAST_PX, BLAST_PX))
    fire_mat = toon_material("Fire", FIRE_RAMP, w_light=0.5, w_face=0.5, noise=0.12)
    smoke_mat = toon_material("Smoke", SMOKE_RAMP, w_light=0.62, w_face=0.38, noise=0.06)
    spike_mat = toon_material("Spike", SPIKE_RAMP, w_light=0.3, w_face=0.7, noise=0.0)
    fire_line = line_material("FireLine", FIRE_LINE)
    smoke_line = line_material("SmokeLine", SMOKE_LINE)

    fmb = bpy.data.metaballs.new("FireMB")
    fmb.resolution = fmb.render_resolution = 0.035
    fmb.threshold = 0.6
    fire_meta = bpy.data.objects.new("FireMeta", fmb)
    sc.collection.objects.link(fire_meta)
    fire_meta.hide_render = True
    smb = bpy.data.metaballs.new("SmokeMB")
    smb.resolution = smb.render_resolution = 0.03
    smb.threshold = 0.6
    smoke_meta = bpy.data.objects.new("SmokeMeta", smb)
    sc.collection.objects.link(smoke_meta)
    smoke_meta.hide_render = True

    fire = mesh_obj(sc, "Fire", fire_mat)
    fire_hull = mesh_obj(sc, "FireHull", fire_line)
    smoke = mesh_obj(sc, "Smoke", smoke_mat)
    smoke_hull = mesh_obj(sc, "SmokeHull", smoke_line)

    # bolhas da bola: centro + anel + topo + base (direcoes unitarias e raio relativo)
    puffs = [(Vector((0, 0, 0)), 0.62, 0.0)]
    for i in range(9):
        a = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        puffs.append((Vector((math.cos(a), math.sin(a), rnd.uniform(-0.15, 0.2))).normalized(),
                      rnd.uniform(0.40, 0.50), rnd.uniform(0.0, 0.25)))
    for i in range(6):
        a = i / 6 * math.tau + 0.4
        puffs.append((Vector((0.55 * math.cos(a), 0.55 * math.sin(a), 0.85)).normalized(),
                      rnd.uniform(0.36, 0.44), rnd.uniform(0.05, 0.3)))
    puffs.append((Vector((0, 0, 1)), 0.46, 0.15))
    for i in range(5):
        a = i / 5 * math.tau + 0.2
        puffs.append((Vector((math.cos(a), math.sin(a), -0.75)).normalized(), rnd.uniform(0.30, 0.36),
                      rnd.uniform(0.0, 0.2)))
    fire_els = []
    for _ in puffs:
        el = fmb.elements.new()
        el.stiffness = 2.2
        fire_els.append(el)
    flash = fmb.elements.new()
    flash.stiffness = 2.0
    # fumaca: bolinhas no chao em volta
    smoke_puffs = []
    for i in range(9):
        a = i / 9 * math.tau + rnd.uniform(-0.12, 0.12)
        far = rnd.uniform(0.85, 1.1)
        late = rnd.uniform(0.0, 0.12)
        for j, (da, r) in enumerate(((0.0, rnd.uniform(0.24, 0.3)), (0.16, rnd.uniform(0.16, 0.21)),
                                      (-0.15, rnd.uniform(0.14, 0.19)))):
            smoke_puffs.append((a + da, r, late + 0.03 * j, far * (1.0 + 0.1 * j), 0.08 * j))
    smoke_els = []
    for _ in smoke_puffs:
        el = smb.elements.new()
        el.stiffness = 2.0
        smoke_els.append(el)
    # espinhos: cones no plano da camera, atras da bola
    view_right = Vector((1, 0, 0))
    e = math.radians(BLAST_ELEV_DEG)
    view_up = Vector((0, math.sin(e), math.cos(e)))
    view_back = Vector((0, math.cos(e), -math.sin(e)))
    spikes = []
    for i in range(11):
        a = i / 11 * math.tau + rnd.uniform(-0.18, 0.18)
        if math.sin(a) < -0.75:
            a += 0.9
        ln = rnd.uniform(0.55, 0.95)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.15, radius2=0.0, depth=1.0)
        ob = bpy.context.active_object
        ob.data.materials.append(spike_mat)
        for p in ob.data.polygons:
            p.use_smooth = True
        hull = mesh_obj(sc, "SpikeHull%d" % i, fire_line)
        set_hull(hull, ob.data, OUTLINE_FIRE)
        d = (view_right * math.cos(a) + view_up * math.sin(a)).normalized()
        spikes.append((ob, hull, d, ln, rnd.uniform(-0.04, 0.04)))

    center0 = Vector((0.0, 0.0, 0.62))
    os.makedirs(os.path.join(OUT, "blast"), exist_ok=True)
    for f in range(BLAST_FRAMES):
        u = f / (BLAST_FRAMES - 1)
        grow = ease_out(f / 5.0)                    # bola cheia no quadro 5
        rise = 0.32 * smooth(0.2, 1.0, u)           # cogumelo sobe
        c = center0 + Vector((0, 0, rise))
        shrink = 1.0 - smooth(0.58, 1.0, u)        # a bola inteira encolhe junta (nao vira bolinhas)
        R = (0.52 * grow + 0.06 * smooth(0.25, 0.6, u)) * (0.35 + 0.65 * shrink)
        boil = f * 0.9
        for i, (d, r, late) in enumerate(puffs):
            k_out = shrink * (1.0 - 0.5 * smooth(0.55 + late, 0.9 + late * 0.3, u))   # encolhe e esfria
            jit = Vector((math.sin(boil + i * 1.7), math.cos(boil * 1.3 + i), math.sin(boil * 0.7 + i * 2.3))) * 0.025
            spread = 1.0 + 0.12 * smooth(0.5, 1.0, u)
            pos = c + d * R * spread + jit
            if d.z < -0.5:   # base: fica perto do chao (haste do cogumelo afina)
                pos.z = max(0.2, pos.z - 0.1) - rise * 0.6
            el = fire_els[i]
            el.co = pos
            el.radius = max(0.001, r * grow * k_out * (1.0 + 0.04 * math.sin(boil * 1.9 + i)))
        # clarao do estouro (quadros 0-2) e calor
        flash.co = c
        flash.radius = 0.001 if f > 2 else 0.35 + 0.18 * f
        heat = 0.10 * (1.0 - smooth(0.0, 0.35, u)) - 0.32 * smooth(0.40, 1.0, u)
        if f <= 1:
            heat = 1.0
        elif f == 2:
            heat = 0.4
        set_heat(fire_mat, heat, f * 0.13)
        # fumaca: nasce no quadro 3, sai pelo chao, sobe e some
        for i, (a, r, late, far, up) in enumerate(smoke_puffs):
            v = smooth(0.10 + late, 0.28 + late, u) * (1.0 - smooth(0.62 + late, 0.9, u) ** 0.6)
            dist = (0.6 + 0.5 * ease_out(max(0.0, u - 0.1) * 1.6)) * far
            pos = Vector((math.cos(a) * dist, math.sin(a) * dist * 0.8,
                          0.14 + up + 0.75 * smooth(0.25, 1.0, u) * (0.6 + 0.4 * far)))
            smoke_els[i].co = pos
            smoke_els[i].radius = max(0.001, r * v * (1.0 + 0.4 * smooth(0.3, 1.0, u)))
        set_heat(smoke_mat, -0.25 * smooth(0.5, 1.0, u), f * 0.1)
        bpy.context.view_layer.update()
        fill_from_meta(sc, fire_meta, fire, fire_hull, OUTLINE_FIRE)
        fill_from_meta(sc, smoke_meta, smoke, smoke_hull, OUTLINE_SMOKE)
        # espinhos: saem no estouro e recolhem
        sk = smooth(0.0, 0.14, u) * (1.0 - smooth(0.30, 0.55, u))
        for ob, hull, d, ln, wob in spikes:
            L = max(0.001, ln * sk)
            base = c + d * (0.30 + 0.25 * grow) + view_back * 0.25
            mid = base + d * (L * 0.5)
            for o in (ob, hull):
                o.location = mid
                o.rotation_euler = (d + view_up * wob).to_track_quat("Z", "Y").to_euler()
                o.scale = (1.0, 1.0, L)
                o.hide_render = sk < 0.02
        render(sc, os.path.join(OUT, "blast", "%04d.png" % f))
    meta = {"frames": BLAST_FRAMES, "size": [BLAST_PX, BLAST_PX], "pivot": pivot_px(sc, cam, (0, 0, 0)),
            "texel": BLAST_WORLD / BLAST_PX}
    with open(os.path.join(OUT, "blast", "meta.json"), "w") as fh:
        json.dump(meta, fh)


# ------------------------------------------------------------------------------------------- lanca

def lance():
    sc = reset()
    rnd = random.Random(11)
    L = 2.55
    cam = camera(sc, LANCE_ELEV_DEG, (0.0, 0.0, L * 0.5 + 0.05), LANCE_WORLD, LANCE_PX)
    mat = toon_material("Lance", LANCE_RAMP, w_light=0.25, w_face=0.75, noise=0.12)
    line = line_material("LanceLine", LANCE_LINE)
    body = mesh_obj(sc, "Lance", mat)
    hull = mesh_obj(sc, "LanceHull", line)
    licks = [(0.06 + i / 14 * 0.8 + rnd.uniform(-0.02, 0.02), 1 if i % 2 else -1, rnd.uniform(0.36, 0.5))
             for i in range(14)]
    os.makedirs(os.path.join(OUT, "lance"), exist_ok=True)
    for f in range(LANCE_FRAMES):
        ph = f / LANCE_FRAMES * math.tau
        bm = bmesh.new()
        rings, seg = 56, 14
        prof = []
        for j in range(rings + 1):
            z = j / rings
            # ponta embaixo (z=0), barriga em z~0.18, afina ate um fio em cima
            r = 0.16 * math.sin(min(z / 0.18, 1.0) * math.pi / 2) ** 0.8 * (1.0 - 0.85 * smooth(0.18, 1.0, z))
            r *= 1.0 + 0.07 * math.sin(z * 17 + ph * 2) * smooth(0.1, 0.3, z)
            prof.append(max(r, 0.004))
        verts = []
        for j, r in enumerate(prof):
            z = j / rings * L
            sway = 0.035 * math.sin(z * 3.1 + ph) * smooth(0.0, 0.6, z / L)
            ring = []
            for s in range(seg):
                a = s / seg * math.tau
                ring.append(bm.verts.new((sway + r * math.cos(a), r * math.sin(a) * 0.7, z)))
            verts.append(ring)
        for j in range(rings):
            for s in range(seg):
                a, b = verts[j][s], verts[j][(s + 1) % seg]
                c, d = verts[j + 1][(s + 1) % seg], verts[j + 1][s]
                bm.faces.new((a, b, c, d))
        # labaredas: cones curvos saindo dos lados, apontando para cima
        for (zf, side, ln) in licks:
            z0 = zf * L * 0.85 + 0.12
            k = 0.6 + 0.4 * math.sin(ph + zf * 9)
            base_r = 0.085 * (1.0 - 0.5 * zf)
            ln2 = ln * k * (1.0 - 0.5 * zf)
            pts = []
            n = 6
            for t in range(n + 1):
                tt = t / n
                x = side * (0.07 * (1.0 - zf) + ln2 * 0.5 * tt ** 1.4)
                pts.append(Vector((x, 0.0, z0 + ln2 * tt)))
            prev = None
            for t, p in enumerate(pts):
                rr = base_r * (1.0 - t / n) + 0.003
                ring = [bm.verts.new(p + Vector((rr * math.cos(a), rr * math.sin(a) * 0.7, 0)))
                        for a in [s / 8 * math.tau for s in range(8)]]
                if prev:
                    for s in range(8):
                        bm.faces.new((prev[s], prev[(s + 1) % 8], ring[(s + 1) % 8], ring[s]))
                prev = ring
        me = bpy.data.meshes.new("L")
        bm.to_mesh(me)
        bm.free()
        me.update()
        set_mesh(body, me)
        set_hull(hull, body.data, 0.022)
        set_heat(mat, -0.16 + 0.04 * math.sin(ph), f * 0.4)
        render(sc, os.path.join(OUT, "lance", "%04d.png" % f))
    meta = {"frames": LANCE_FRAMES, "size": list(LANCE_PX), "pivot": pivot_px(sc, cam, (0, 0, 0)),
            "texel": LANCE_WORLD / LANCE_PX[1]}
    with open(os.path.join(OUT, "lance", "meta.json"), "w") as fh:
        json.dump(meta, fh)


if ONLY is None or "blast" in ONLY:
    blast()
if ONLY is None or "lance" in ONLY:
    lance()
print("ANIME_FX_DONE", OUT)
