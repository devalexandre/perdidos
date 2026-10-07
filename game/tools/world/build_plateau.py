#!/usr/bin/env python3
"""Chapada do Céu Partido (split_sky_plateau, _ridges, _summit): o acabamento dos Campos e da Mata.

build_hunt_areas.py deixa a Chapada no rascunho (chão chapado de mat_ground_red_earth, fileiras de
pedras). Este gerador refaz os três mapas no padrão de build_fields.py / build_forest.py:
- chão pintado: env_terrain_world.gdshader com mapas de mistura por mapa (terra vermelha variada,
  manchas de capim seco, cascalho, areia de arenito e terra batida nas trilhas, borda macia);
- paredões de arenito (pedras do kit esticadas) fechando a área andável e ilhas de cerrado;
- árvores tortas do cerrado, ipês amarelos e roxos, pequizeiros; no Alto das Brasas, galhos secos;
- capim dourado (cartões de grama), arbustos secos, cupinzeiros, flores e pétalas de ipê;
- navegação em grade ligada (SpawnPoint, portais, chegadas, grupos e covis de chefe).
Mantém SpawnPoint, NorthArrival, portais, grupos (Spawns/) e covis (BossLairs/) de build_hunt_areas;
build_ratanaba_expansion.py acrescenta depois o portal do cume para a Serra Dourada (z = -38).
"""
import math
import random
import re
from collections import defaultdict

import numpy as np
from PIL import Image, ImageFilter

from build_hunt_areas import AREAS, GAME, write_scene, trail_points, branch_paths, clearings

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

MESHES = 'res://assets/environment/painted/meshes'
TEXTURES = 'res://assets/environment/painted/textures'
SPLAT_DIR = 'assets/environment/painted/terrain'
# Terra batida das trilhas (terrain_trail.gd tinge tex_dirt): ocre quente, não laranja.
TRAIL_SOIL = '0.84, 0.66, 0.52'
# Lado do quadrado pintado (m) e resolução dos mapas de mistura (px).
SPLAT_SIZE = 100.0
SPLAT_PX = 256
# Pontos que precisam ficar ligados ao SpawnPoint além de portais, grupos e covis
# (o portal do cume para a Serra Dourada fica em z = -38).
EXTRA_TARGETS = [(0, -38)]

# Por trecho: árvores (peso), pedras dos paredões, pontos de interesse.
STYLE = {
    0: dict(  # Subida Vermelha: cerrado mais fechado, ipês amarelos na subida.
        trees={'pl_twisted_1': 22, 'pl_twisted_3': 14, 'pl_ipe_yellow': 18, 'pl_ipe_yellow_s': 12, 'pl_pequi': 14,
               'pl_pequi_s': 10, 'pl_ipe_purple': 4, 'pl_dead': 2},
        cliffs={'pl_rock_red': 70, 'pl_rock_sand': 18, 'pl_rock_grey': 12},
        dry=0.50, gravel=0.18, seed=1301),
    1: dict(  # Cristas do Vento: mais pedra, capim alto, ipês roxos.
        trees={'pl_twisted_2': 18, 'pl_twisted_4': 12, 'pl_ipe_purple': 16, 'pl_ipe_purple_s': 12, 'pl_pequi': 10,
               'pl_ipe_yellow': 8, 'pl_dead': 4},
        cliffs={'pl_rock_red': 60, 'pl_rock_sand': 20, 'pl_rock_grey': 20},
        dry=0.58, gravel=0.26, seed=1302),
    2: dict(  # Alto das Brasas: queimada antiga, galhos secos, brasas nos covis.
        trees={'pl_twisted_5': 16, 'pl_twisted_1': 10, 'pl_dead': 16, 'pl_dead_b': 10, 'pl_ipe_yellow': 10,
               'pl_pequi_s': 8},
        cliffs={'pl_rock_red': 78, 'pl_rock_sand': 10, 'pl_rock_grey': 12},
        dry=0.38, gravel=0.30, seed=1303),
}

PROPS = {
    'pl_rock_red': 'pk_rock_red', 'pl_rock_sand': 'pk_rock_sand', 'pl_rock_grey': 'pk_rock_2',
    'pl_rock_small': 'pk_rock_red',
    'pl_twisted_1': 'pk_twisted_1', 'pl_twisted_2': 'pk_twisted_2', 'pl_twisted_3': 'pk_twisted_3',
    'pl_twisted_4': 'pk_twisted_4', 'pl_twisted_5': 'pk_twisted_5',
    'pl_ipe_yellow': 'tree_ipe_yellow_a', 'pl_ipe_yellow_s': 'pk_ipe_yellow_1',
    'pl_ipe_purple': 'tree_ipe_purple_a', 'pl_ipe_purple_s': 'pk_ipe_purple_1',
    'pl_pequi': 'tree_pequi_a', 'pl_pequi_s': 'pk_pequi_1',
    'pl_dead': 'pk_deadtree_1', 'pl_dead_b': 'pk_deadtree_2',
    'pl_grass_golden': 'grass_golden', 'pl_grass_golden_tall': 'pk_grass_golden', 'pl_grass_wispy': 'pk_grass_wispy',
    'pl_grass_tuft': 'grass_tuft', 'pl_bush_dry': 'bush_dry_a', 'pl_bush_dry_s': 'pk_bush_dry',
    'pl_termite': 'termite_mound_a', 'pl_flowers': 'pk_flowers_purple', 'pl_flowers_b': 'flowers_purple',
    'pl_pebble': 'pk_pebble_round_1', 'pl_petals': 'pk_petals_1',
}
# Escala de cada malha (as do pacote vêm em tamanhos muito diferentes).
TREE_SCALE = {'pl_twisted_1': (.34, .46), 'pl_twisted_2': (.40, .52), 'pl_twisted_3': (.34, .46),
              'pl_twisted_4': (.36, .48), 'pl_twisted_5': (.38, .50), 'pl_ipe_yellow': (.75, 1.0),
              'pl_ipe_yellow_s': (1.0, 1.3), 'pl_ipe_purple': (.75, 1.0), 'pl_ipe_purple_s': (1.0, 1.3),
              'pl_pequi': (.8, 1.05), 'pl_pequi_s': (1.0, 1.3), 'pl_dead': (.8, 1.1), 'pl_dead_b': (.8, 1.1)}
IPE = {'pl_ipe_yellow', 'pl_ipe_yellow_s', 'pl_ipe_purple', 'pl_ipe_purple_s'}


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _noise(rng, blur_px):
    """Ruído suave em [0, 1] (ruído branco borrado), SPLAT_PX x SPLAT_PX."""
    white = Image.fromarray((rng.random((SPLAT_PX, SPLAT_PX)) * 255).astype(np.uint8), 'L')
    arr = np.asarray(white.filter(ImageFilter.GaussianBlur(blur_px)), dtype=np.float32)
    lo, hi = np.percentile(arr, 2), np.percentile(arr, 98)
    return np.clip((arr - lo) / max(hi - lo, 1e-3), 0.0, 1.0)


def write_ground(map_id, samples, rooms, style):
    """Mapas de mistura (splat_a/b/c de env_terrain_world) e o material do chão deste mapa."""
    rng = np.random.default_rng(style['seed'])
    step = SPLAT_SIZE / SPLAT_PX
    coords = -SPLAT_SIZE / 2 + (np.arange(SPLAT_PX) + 0.5) * step
    gx, gz = np.meshgrid(coords, coords)  # linha = z, coluna = x (v da textura = z)
    # Distância até a trilha (amostras das rotas) e até as clareiras.
    pts = np.array(samples, dtype=np.float32)
    d_path = np.full(gx.shape, 1e9, dtype=np.float32)
    for i in range(0, len(pts), 64):
        chunk = pts[i:i + 64]
        d = np.sqrt((gx[..., None] - chunk[:, 0]) ** 2 + (gz[..., None] - chunk[:, 1]) ** 2).min(-1)
        d_path = np.minimum(d_path, d)
    d_room = np.full(gx.shape, 1e9, dtype=np.float32)
    for x, z, r in rooms:
        d_room = np.minimum(d_room, np.sqrt((gx - x) ** 2 + (gz - z) ** 2) - r)
    # Distância (com sinal) até a área andável: < 0 dentro da trilha/clareira.
    d_walk = np.minimum(d_path - 4.4, d_room - 1.6)
    n_big, n_mid, n_small = _noise(rng, 22), _noise(rng, 9), _noise(rng, 3.5)
    wobble = (n_mid - 0.5) * 7 + (n_small - 0.5) * 3  # borda pintada, nunca reta

    # Capim seco cobre o chão (o cerrado); pequenas manchas de grama verde onde ele rareia.
    dry = np.clip(0.62 + 0.5 * (n_big - 0.5) + (style['dry'] - 0.5), 0, 1)
    # Cascalho de arenito em manchas soltas entre o capim, perto dos paredões.
    gravel = _smooth(0.5, 4.0, d_walk) * _smooth(0.62, 0.8, n_small) * style['gravel'] * 2.2
    # Rocha só embaixo dos paredões (longe da trilha).
    rock = _smooth(7.0, 11.0, d_walk + (n_small - 0.5) * 4) * 0.8
    # Terra vermelha: domina a área andável e invade o capim em línguas irregulares; dentro dela, ilhas
    # de capim (o cerrado rebrota entre as trilhas) e peso médio, para a textura misturar com o capim.
    n_patch = _noise(rng, 5.5)
    red_reach = 1.0 - _smooth(-2.0, 5.0, d_walk + wobble)
    grass_islands = _smooth(0.52, 0.74, n_patch) * _smooth(1.8, 3.6, d_path)
    red = np.clip((0.5 + 0.38 * n_big) * red_reach * (1 - 0.85 * grass_islands)
                  + 0.25 * _smooth(3.0, 0.8, d_path), 0, 1)
    sand = np.zeros(gx.shape, dtype=np.float32)
    # Terra batida: só manchas no miolo das clareiras (a trilha tem malha própria, terrain_trail.gd).
    dirt = _smooth(0.0, -3.5, d_room) * _smooth(0.55, 0.8, n_mid) * 0.5

    def channel(a):
        return (np.clip(a, 0, 1) * 255).astype(np.uint8)

    zero = np.zeros(gx.shape, dtype=np.float32)
    one = np.full(gx.shape, 1.0, dtype=np.float32)
    # Alfa nunca 0: o import do Godot (fix_alpha_border) mexeria no RGB dos pixels transparentes.
    alpha_floor = 1.5 / 255
    layers = {
        'a': (dirt, zero, sand, np.maximum(rock, alpha_floor)),     # R terra  G calçamento  B areia  A rocha
        'b': (zero, dry, zero, np.maximum(gravel, alpha_floor)),    # R neve   G capim seco  B mata  A cascalho
        'c': (red, zero, zero, one),                                # R terra vermelha  G grama viçosa  B urze
    }
    paths = {}
    for key, chans in layers.items():
        img = Image.fromarray(np.dstack([channel(c) for c in chans]), 'RGBA')
        rel = f'{SPLAT_DIR}/{map_id}_splat_{key}.png'
        img.save(GAME / rel)
        paths[key] = 'res://' + rel
    tex = {'grass': 'tex_dry_grass', 'lush': 'tex_grass', 'dirt': 'tex_dirt', 'paving': 'tex_paving',
           'sand': 'tex_sand', 'rock': 'tex_rock', 'snow': 'tex_snow', 'dry': 'tex_dry_grass',
           'jungle': 'tex_jungle_floor', 'gravel': 'tex_gravel', 'red': 'tex_red_earth'}
    ext = ['[ext_resource type="Shader" path="res://assets/shaders/env_terrain_world.gdshader" id="shader"]',
           '[ext_resource type="Texture2D" path="res://assets/environment/painted/materials/tex_env_noise.tres" id="noise"]']
    params = ['shader = ExtResource("shader")']
    for name, file in tex.items():
        ext.append(f'[ext_resource type="Texture2D" path="{wg.require_res(f"{TEXTURES}/{file}.png")}" id="t_{name}"]')
        params.append(f'shader_parameter/tex_{name} = ExtResource("t_{name}")')
    for key, res in paths.items():
        ext.append(f'[ext_resource type="Texture2D" path="{res}" id="splat_{key}"]')
        params.append(f'shader_parameter/splat_{key} = ExtResource("splat_{key}")')
    params += ['shader_parameter/tex_noise = ExtResource("noise")',
               f'shader_parameter/splat_origin = Vector2({-SPLAT_SIZE / 2:g}, {-SPLAT_SIZE / 2:g})',
               f'shader_parameter/splat_size = Vector2({SPLAT_SIZE:g}, {SPLAT_SIZE:g})',
               'shader_parameter/tile_m = 6.0',
               'shader_parameter/blend_softness = 0.22',
               'shader_parameter/edge_noise = 0.34',
               # Manchas quentes/frias do capim e pinceladas um pouco mais marcadas (cenário pintado).
               'shader_parameter/macro_warm = Color(1.08, 0.98, 0.78, 1)',
               'shader_parameter/macro_cool = Color(0.86, 0.9, 0.78, 1)',
               'shader_parameter/brush_strength = 0.1']
    material = (f'[gd_resource type="ShaderMaterial" load_steps={len(ext) + 1} format=3]\n\n' + '\n'.join(ext)
                + '\n\n[resource]\n' + '\n'.join(params) + '\n')
    rel = f'assets/environment/painted/materials/mat_ground_{map_id}.tres'
    (GAME / rel).write_text(material)
    return 'res://' + rel


def build(a):
    map_id = a['id']
    variant = a['variant']
    style = STYLE[variant]
    path = GAME / 'scenes/maps' / f'{map_id}.tscn'
    zone = GAME / 'data/zones' / f'{map_id}.tres'
    # Rodando sozinho, o cume já tem o portal da Serra Dourada (dono: build_ratanaba_expansion.py);
    # ele é mantido. Em build_all, write_scene acabou de refazer o mapa e a ligação volta depois.
    kept_portal = ''
    if path.exists():
        m = re.search(r'\n\[node name="to_serra_dourada" type="Area3D".*?(?=\n\[node name="Spawns")',
                      path.read_text(encoding='utf-8'), flags=re.S)
        kept_portal = m.group(0) if m else ''
    write_scene(a)
    source = path.read_text(encoding='utf-8')
    if kept_portal:
        spawns = '[node name="Spawns" type="Node3D" parent="."]'
        source = source.replace(spawns, kept_portal + '\n' + spawns, 1)  # mesmo texto do dono
        text = zone.read_text(encoding='utf-8')
        zone.write_text(text.replace('([&"split_sky_plateau_ridges"])',
                                     '([&"split_sky_plateau_ridges", &"city_serra_dourada"])'), encoding='utf-8')

    paths = [trail_points(a)] + branch_paths(a)
    rooms = clearings(a) + [(0, 33, 6.0), (0, -34, 6.0)]
    # Mirantes de cada trecho (clareiras com ponto de interesse).
    feature = {0: (14, 22, 5.0), 1: (17, 14, 5.5), 2: (-4, -14, 5.0)}[variant]
    rooms.append(feature)
    paths.append([_nearest(paths[0], feature[:2]), feature[:2]])
    samples = [p for route in paths for p in route]

    def walk(x, z):
        if any((x - px) ** 2 + (z - pz) ** 2 < 4.4 ** 2 for px, pz in samples):
            return True
        return any((x - px) ** 2 + (z - pz) ** 2 < (r + 1.6) ** 2 for px, pz, r in rooms)

    cells = {(x, z) for x in range(-44, 44, 2) for z in range(-44, 44, 2) if walk(x + 1, z + 1)}
    targets = [(0, 39), (0, -39), (0, -34)] + EXTRA_TARGETS
    targets += [(x, z) for _m, _s, _c, x, z in a['spawns']] + [(x, z) for _m, x, z in a['lairs']]
    wg.ensure_connected(cells, (0, 33), targets, label=map_id)
    nav = '[sub_resource type="NavigationMesh" id="nav"]\n' + wg.navmesh_body(cells) + '\n\n'
    source = re.sub(r'\[sub_resource type="NavigationMesh" id="nav"\].*?(?=\[node)', nav, source, flags=re.S)
    # O rascunho (fileiras de pedra, capim nas bordas da trilha) sai; o cenário novo entra abaixo.
    source = re.sub(r'\[node [^\n]*parent="Decor"\].*?(?=\[node|\Z)', '', source, flags=re.S)
    ground = write_ground(map_id, samples, rooms, style)
    source = source.replace('res://assets/environment/painted/materials/mat_ground_red_earth.tres', ground)
    source = source.replace('soil_tint = Color(0.68, 0.43, 0.28, 1)', f'soil_tint = Color({TRAIL_SOIL}, 1)')

    resources, nodes = [], []

    def node(name, kind, props, parent='Decor'):
        nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\n{props}\n')

    rng = random.Random(style['seed'])
    groups = defaultdict(list)

    def place(ident, x, z, scale, y=0.0, stretch=1.0):
        angle = rng.uniform(0, math.tau)
        c, s = math.cos(angle) * scale, math.sin(angle) * scale
        # MultiMesh: transformações 3x4 por linha.
        groups[ident].extend([c, 0, s, x, 0, scale * stretch * rng.uniform(.92, 1.1), 0, y, -s, 0, c, z])

    def in_nav(x, z, margin=0.0):
        return any((math.floor((x + dx) / 2) * 2, math.floor((z + dz) / 2) * 2) in cells
                   for dx, dz in [(0, 0), (margin, 0), (-margin, 0), (0, margin), (0, -margin),
                                  (margin, margin), (-margin, -margin), (margin, -margin), (-margin, margin)])

    def nav_dist(x, z):
        return min(math.hypot(x - cx - 1, z - cz - 1) for cx, cz in cells)

    def pick(weights):
        return rng.choices(list(weights), list(weights.values()))[0]

    # 1. Paredões de arenito: blocos grandes, mais altos quanto mais longe da trilha.
    for x in range(-50, 51, 3):
        for z in range(-50, 51, 3):
            px, pz = x + rng.uniform(-1, 1), z + rng.uniform(-1, 1)
            if in_nav(px, pz, 2.6):
                continue
            d = nav_dist(px, pz)
            if d < 4.0 and rng.random() < .45:
                continue  # deixa vão para árvores e capim junto da trilha
            height = 1.0 + min(d, 12) / 12 * 1.1
            place(pick(style['cliffs']), px, pz, rng.uniform(2.0, 3.4), rng.uniform(-.6, -.1), height)
    # 2. Cerrado: árvores tortas, ipês e pequizeiros entre os paredões e a trilha.
    ipes = []
    for x in range(-46, 47, 4):
        for z in range(-46, 47, 4):
            px, pz = x + rng.uniform(-1.6, 1.6), z + rng.uniform(-1.6, 1.6)
            if in_nav(px, pz, 1.8) or nav_dist(px, pz) > 9:
                continue
            tree = pick(style['trees'])
            lo, hi = TREE_SCALE[tree]
            place(tree, px, pz, rng.uniform(lo, hi))
            if tree in IPE:
                ipes.append((px, pz))
    # 3. Capim dourado, arbustos secos, flores e cascalho (a "pele" do cerrado).
    for _ in range(2600):
        x, z = rng.uniform(-46, 46), rng.uniform(-46, 46)
        dist = min((x - px) ** 2 + (z - pz) ** 2 for px, pz in samples)
        if dist < 2.2 ** 2:
            continue  # o miolo da trilha fica limpo
        if in_nav(x, z, .6):
            kind = rng.choices(['pl_grass_golden', 'pl_grass_golden_tall', 'pl_grass_wispy', 'pl_grass_tuft',
                                'pl_flowers', 'pl_flowers_b', 'pl_pebble', 'pl_bush_dry_s'],
                               [30, 16, 14, 12, 4, 3, 8, 5])[0]
            place(kind, x, z, rng.uniform(.8, 1.4))
        elif nav_dist(x, z) < 7:
            kind = rng.choices(['pl_bush_dry', 'pl_bush_dry_s', 'pl_grass_golden_tall', 'pl_grass_wispy',
                                'pl_rock_small', 'pl_termite'], [26, 20, 26, 16, 8, 4])[0]
            scale = {'pl_rock_small': rng.uniform(.4, .8), 'pl_termite': rng.uniform(.9, 1.3)}.get(kind, rng.uniform(.8, 1.5))
            place(kind, x, z, scale)
    # Pétalas de ipê caídas em volta dos ipês.
    for tx, tz in ipes:
        for _ in range(5):
            place('pl_petals', tx + rng.uniform(-3, 3), tz + rng.uniform(-3, 3), rng.uniform(1.2, 2.0), .02)
    # Cupinzeiros nas clareiras de caça (longe do centro do bando).
    for _m, _s, _c, x, z in a['spawns']:
        ang = rng.uniform(0, math.tau)
        tx, tz = x + math.cos(ang) * 5.5, z + math.sin(ang) * 5.5
        if in_nav(tx, tz) and min((tx - px) ** 2 + (tz - pz) ** 2 for px, pz in samples) > 2.5 ** 2:
            place('pl_termite', tx, tz, rng.uniform(1.0, 1.4))

    for ident in sorted(groups):
        resources.append(f'[ext_resource type="ArrayMesh" path="{wg.require_res(f"{MESHES}/{PROPS[ident]}.res")}" id="{ident}"]')
    for ident in sorted(groups):
        buffer = groups[ident]
        resources.append(f'[sub_resource type="MultiMesh" id="mm_{ident}"]\ntransform_format = 1\nmesh = ExtResource("{ident}")\ninstance_count = {len(buffer) // 12}\nbuffer = PackedFloat32Array(' + ', '.join(f'{v:.4f}' for v in buffer) + ')')
        node(f'Chapada_{ident}', 'MultiMeshInstance3D', f'multimesh = SubResource("mm_{ident}")')

    # 4. Pontos de interesse de cada trecho.
    fx, fz, _r = feature

    def single(name, mesh, x, z, scale=1.0, rot=0, y=0.0):
        ident = 'one_' + mesh
        line = f'[ext_resource type="ArrayMesh" path="{wg.require_res(f"{MESHES}/{mesh}.res")}" id="{ident}"]'
        if line not in resources:
            resources.append(line)
        node(name, 'MeshInstance3D', f'position = Vector3({x:g}, {y:g}, {z:g})\nrotation_degrees = Vector3(0, {rot:g}, 0)\nscale = Vector3({scale:g}, {scale:g}, {scale:g})\nmesh = ExtResource("{ident}")')

    def off_trail(x, z, r):
        # Primeiro ponto fora da área andável em volta de (x, z) (árvore de mirante não fica no caminho).
        for dist in [r + k * 0.5 for k in range(24)]:
            for step in range(16):
                ang = step / 16 * math.tau
                px, pz = x + math.cos(ang) * dist, z + math.sin(ang) * dist
                if not in_nav(px, pz, 1.6):
                    return px, pz
        raise wg.WorldGenError(f'{map_id}: no room for a landmark near {(x, z)}')

    if variant == 0:
        # Ipê-amarelo grande e lajes de pedra no mirante da subida.
        single('AscentIpe', 'tree_ipe_yellow_a', *off_trail(fx, fz, 3), 1.25, 40)
        single('AscentStones', 'pk_rockpath_round_thin', fx - .5, fz + .5, 1.6, 15, .02)
    elif variant == 1:
        # Círculo de pedras no mirante das Cristas, batido pelo vento.
        single('RidgeStones', 'vg_standing_stones', fx, fz, 1.3, 20)
        single('RidgeIpe', 'tree_ipe_purple_a', *off_trail(fx, fz, 4), 1.1, 75)
    else:
        # Fogueiras de brasa junto dos covis e no mirante (Alto das Brasas).
        embers = [(fx, fz)] + [(x + 4.5, z + 3.5) for _m, x, z in a['lairs']]
        for i, (ex, ez) in enumerate(embers):
            single(f'Embers{i}', 'camp_fire_v2', ex, ez, 1.2, i * 50)
            node(f'EmbersLight{i}', 'OmniLight3D', f'position = Vector3({ex:g}, 1.2, {ez:g})\nlight_color = Color(1, 0.52, 0.2, 1)\nlight_energy = 1.4\nomni_range = 7.5\nshadow_enabled = false')
        single('SummitDeadTree', 'pk_deadtree_3', *off_trail(fx, fz, 3), 1.1, 30)

    ext = [r for r in resources if r.startswith('[ext')]
    sub = [r for r in resources if r.startswith('[sub')]
    source = source.replace('[sub_resource', '\n\n'.join(ext) + '\n\n[sub_resource', 1)
    source = source.replace('[node', '\n\n'.join(sub) + '\n\n[node', 1)
    source += '\n' + '\n'.join(nodes)
    source = re.sub(r'load_steps=\d+', f'load_steps={1 + source.count("[ext_resource") + source.count("[sub_resource")}', source, count=1)
    path.write_text(source, encoding='utf-8')

    # O minimapa passa a sair da navegação real (como nos Campos e na Mata).
    text = zone.read_text(encoding='utf-8')
    text = re.sub(r'^.*(?:id="minimap"|minimap_texture =|minimap_world_rect =).*\n', '', text, flags=re.M)
    zone.write_text(text, encoding='utf-8')
    print(f'{map_id}: {len(cells)} walk cells, {sum(len(v) // 12 for v in groups.values())} MultiMesh instances placed.')


def _nearest(points, target):
    tx, tz = target
    return min(points, key=lambda p: (p[0] - tx) ** 2 + (p[1] - tz) ** 2)


def main():
    plateau = [a for a in AREAS if a.get('scenery') == 'highlands']
    for area in plateau:
        build(area)
    wg.finish([a['id'] for a in plateau], 'plateau')


if __name__ == '__main__':
    main()
