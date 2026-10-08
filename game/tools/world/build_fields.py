#!/usr/bin/env python3
"""Campos de Pindorama (fields_pindorama, _buriti, _crossroads): o acabamento dos mapas de build_hunt_areas.py.

- chão de CAMPO (08/10/2026): grama verde viva pintada (env_terrain_world + mapas de mistura por mapa), com manchas
  de capim seco do cerrado e de grama viçosa; terra batida só na Estrada dos Viajantes e nas trilhas, com borda
  macia entrando na grama; lama na beira da água; rocha e cascalho embaixo dos afloramentos;
- vida: capim baixo e touceiras de capim alto balançando, flores do campo (amarelas, brancas, roxas), arbustos,
  cupinzeiros, troncos; árvores do cerrado (pequizeiro, ipês, árvores tortas; buritis na vereda do Buriti);
- pontos de interesse: acampamento do Coronel Tobias e lagoa (fields_pindorama), buritizal alagado (buriti), pedras
  em pé e altar de crendice na encruzilhada; pontes de pedra;
- navegação em grade ligada; só aparência muda (portais, grupos, NPCs e marcadores vêm de build_hunt_areas).
"""
from pathlib import Path
import math
import random
import re
from collections import defaultdict

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

from build_hunt_areas import AREAS, GAME, write_scene, trail_points, branch_paths, clearings

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

# ---------------------------------------------------------------------------
# Campo de grama (08/10/2026): chão pintado + capim, flores e cerrado vivos.
# O dono achou os Campos "bem ruins e sem vida" (terra batida marrom, arbustos e pedras). Agora o chão é
# env_terrain_world (como a Chapada e o Campo de Treino) com mapas de mistura por mapa: grama verde viva com
# manchas de capim seco (cerrado) e de grama mais viçosa, terra batida só na Estrada dos Viajantes e nas
# trilhas (borda macia entrando na grama), rocha embaixo dos afloramentos, lama na beira da água.
# Folhagem pequena (capim em tufos, flores do campo, arbustos baixos, pedrinhas) em pedaços de MultiMesh sob um
# FoliageScatter (EnvQuality: densidade e distância); árvores do cerrado, cupinzeiros e pedras em MultiMesh
# próprios (balanço de planta inteira pelo SceneryLife; cupinzeiro/pedra/tronco servem de pouso aos pássaros).
# Só aparência: colisão, navegação, portais, grupos e NPCs continuam os de build_hunt_areas.
# ---------------------------------------------------------------------------
MESHES = 'res://assets/environment/painted/meshes'
TEXTURES = 'res://assets/environment/painted/textures'
SPLAT_DIR = 'assets/environment/painted/terrain'
FOLIAGE_SCRIPT = 'res://scripts/client/env/foliage_scatter.gd'
# Lado do quadrado pintado (m) e resolução dos mapas de mistura (px): ~0,39 m por pixel.
SPLAT_SIZE = 100.0
SPLAT_PX = 256
# Pedaço (m) de cada MultiMesh de folhagem pequena (culling e corte por distância por pedaço).
FOLIAGE_CHUNK = 24.0
# Até onde espalhar (m do centro); o chão vai até 50.
SCATTER_LIMIT = 47.0
# Estrada dos Viajantes (trilha principal) mais larga que as trilhas laterais. A cor da faixa (terrain_trail.gd)
# casa com a terra batida pintada no chão (env_terrain_world), só um pouco mais escura e quente no miolo.
ROAD_HALF_WIDTH = 1.8
BRANCH_HALF_WIDTH = 0.95
TRAIL_SOIL = '0.84, 0.79, 0.70'
# Raio (m) livre de mato alto, arbusto e cupinzeiro em volta de chegada, portal, NPC, altar e marcadores.
KEEPOUT_R = 3.2
# Centro dos grupos de monstros: sem mato alto nem arbusto (o bicho não some no capim).
PACK_CLEAR_R = 4.5

# Por mapa: semente, viés de capim seco/grama viçosa, árvores (malha: peso, escala mín., escala máx.),
# lagoas (x, z, raio) e pontos de terra batida (x, z, raio: acampamento, praça da encruzilhada).
FIELD_STYLE = {
    'fields_pindorama': dict(  # Estrada dos Viajantes: campo verde com manchas de cerrado, pequizeiros e ipês amarelos.
        seed=2101, dry=0.0, lush=0.05,
        trees={'tree_pequi_a': (30, 0.8, 1.1), 'pk_pequi_1': (22, 0.95, 1.25), 'tree_ipe_yellow_a': (18, 0.75, 1.0),
               'pk_ipe_yellow_1': (10, 0.9, 1.15), 'pk_twisted_1': (8, 0.3, 0.4)},
        ponds=[(18, -14, 5.2)], worn=[(14, 9, 6.5)]),
    'fields_pindorama_buriti': dict(  # Vereda do Buriti: mais verde e úmido, buritizais na água e na borda.
        seed=2102, dry=-0.12, lush=0.06,
        trees={'buriti_soft_a': (22, 0.75, 0.95), 'buriti_soft_b': (16, 0.7, 0.9), 'palm_buriti_a': (10, 0.9, 1.15),
               'tree_pequi_a': (14, 0.8, 1.05), 'tree_ipe_yellow_a': (10, 0.75, 1.0), 'pk_ipe_yellow_2': (6, 0.9, 1.1)},
        ponds=[(-16, 2, 6.2)], worn=[(3, 2, 3.0)]),
    'fields_pindorama_crossroads': dict(  # Passo dos Ipês: cerrado mais seco, ipês amarelos e roxos, árvores tortas.
        seed=2103, dry=0.12, lush=-0.05,
        trees={'tree_ipe_yellow_a': (20, 0.75, 1.0), 'tree_ipe_purple_a': (16, 0.75, 1.0), 'pk_ipe_yellow_2': (8, 0.9, 1.15),
               'pk_ipe_purple_1': (8, 0.9, 1.15), 'tree_pequi_a': (16, 0.8, 1.05), 'pk_twisted_3': (10, 0.3, 0.4),
               'pk_twisted_1': (6, 0.3, 0.4)},
        ponds=[], worn=[(0, 0, 5.0)]),
}
# Folhagem pequena: malha -> (escala mín., escala máx.). Capim verde baixo (não esconde item no chão),
# capim seco/dourado, capim alto em touceiras (só na borda das áreas de caça), flores e arbustos.
# Capim: malha -> (peso, escala mín., escala máx.). O cartão grass_tuft vira estrela escura vista de cima: pouco.
GRASS_GREEN = {'pk_grass_wispy': (5, 0.55, 0.85), 'pk_grass_short': (3, 0.5, 0.75), 'grass_tuft': (1, 0.9, 1.3)}
GRASS_DRY = {'pk_grass_golden': (4, 0.42, 0.62), 'grass_golden': (1, 0.9, 1.3)}
GRASS_TALL = {'pk_grass_wispy_tall': (0.95, 1.3), 'pk_grass_tall': (1.0, 1.35), 'pk_grass_golden': (0.95, 1.3),
              'grass_tuft_b': (1.2, 1.6)}
# Flores do campo: amarelas, brancas e roxas (cartões mat_card_flowers*) e flores do kit.
FLOWERS = {'yellow': ['flowers', 'pk_flowers_a'], 'white': ['flowers_b', 'pk_flowers_b'],
           'purple': ['flowers_purple', 'pk_flowers_purple']}
BUSHES = {'bush_low_c': (0.55, 0.85), 'pk_bush': (0.5, 0.8), 'pk_bush_flowers': (0.5, 0.8), 'bush_low_a': (0.45, 0.7)}
BUSHES_DRY = {'pk_bush_dry': (0.55, 0.85), 'bush_dry_a': (0.45, 0.7)}
ROCKS = {'pk_rock_sand': (0.9, 1.6), 'pk_rock_1': (0.9, 1.5), 'pk_rock_moss_1': (0.8, 1.3), 'rock_red_a': (2.0, 3.4)}


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _noise(rng, blur_px):
    """Ruído suave em [0, 1] (ruído branco borrado), SPLAT_PX x SPLAT_PX."""
    white = Image.fromarray((rng.random((SPLAT_PX, SPLAT_PX)) * 255).astype(np.uint8), 'L')
    arr = np.asarray(white.filter(ImageFilter.GaussianBlur(blur_px)), dtype=np.float32)
    lo, hi = np.percentile(arr, 2), np.percentile(arr, 98)
    return np.clip((arr - lo) / max(hi - lo, 1e-3), 0.0, 1.0)


def _trail_polylines(source):
    """Pontos (x, z) das trilhas da cena (Trail = Estrada; TrailBranch*), já com a malha de terrain_trail.gd."""
    out = {'road': [], 'branch': []}
    for m in re.finditer(r'\[node name="(Trail|TrailBranch\d+)"[^\n]*\]\n+script = ExtResource\("trail_script"\)\n'
                         r'points = PackedVector3Array\(([^)]*)\)', source):
        vals = [float(v) for v in m.group(2).split(',')]
        pts = [(vals[i], vals[i + 2]) for i in range(0, len(vals) - 2, 3)]
        out['road' if m.group(1) == 'Trail' else 'branch'].append(pts)
    return out


def _node_positions(source):
    """[(nome, tipo, pai, (x, z))] de todo nó da cena que tem position."""
    out = []
    for block in source.split('\n[node ')[1:]:
        head = re.match(r'name="([^"]+)" type="([^"]+)"(?: parent="([^"]*)")?\]', block)
        pos = re.search(r'^position = Vector3\(([^)]*)\)', block, flags=re.M)
        if head and pos:
            x, _y, z = (float(v) for v in pos.group(1).split(','))
            out.append((head.group(1), head.group(2), head.group(3) or '', (x, z)))
    return out


def _keepouts(source):
    """Chegadas, portais, NPCs, interações e marcadores (x, z): nada alto em volta."""
    return [p for name, kind, parent, p in _node_positions(source)
            if kind in ('Marker3D', 'Area3D') and parent != 'Spawns' and not name.startswith('Viewpoint')]


def _packs(source):
    """Centros dos grupos de monstros (x, z)."""
    return [p for _n, kind, parent, p in _node_positions(source) if kind == 'Marker3D' and parent == 'Spawns']


class FieldLayout:
    """Campos em grade (linha = z, coluna = x) para pintar o chão e decidir onde nasce cada planta."""

    def __init__(self, cells, trails, rooms, style):
        self.step = SPLAT_SIZE / SPLAT_PX
        coords = -SPLAT_SIZE / 2 + (np.arange(SPLAT_PX) + 0.5) * self.step
        self.gx, self.gz = np.meshgrid(coords, coords)
        walk = np.zeros(self.gx.shape, dtype=bool)
        for (cx, cz) in cells:
            i0, i1 = self.index(cx, cz), self.index(cx + 2, cz + 2)
            walk[i0[0]:i1[0], i0[1]:i1[1]] = True
        # distância com sinal até a área andável (m): < 0 dentro
        self.d_walk = (ndimage.distance_transform_edt(~walk) - ndimage.distance_transform_edt(walk)) * self.step
        self.d_road = self._dist_to(trails['road'])
        self.d_branch = self._dist_to(trails['branch'])
        # distância até a beira da faixa de terra (< 0 = em cima da trilha)
        self.d_trail = np.minimum(self.d_road - ROAD_HALF_WIDTH, self.d_branch - BRANCH_HALF_WIDTH)
        self.d_room = np.full(self.gx.shape, 1e9, dtype=np.float32)
        for x, z, r in rooms:
            self.d_room = np.minimum(self.d_room, np.sqrt((self.gx - x) ** 2 + (self.gz - z) ** 2) - r)
        rng = np.random.default_rng(style['seed'])
        self.n_big, self.n_mid, self.n_small = _noise(rng, 22), _noise(rng, 9), _noise(rng, 3.5)
        self.n_lush, self.n_red, self.n_flower = _noise(rng, 14), _noise(rng, 6), _noise(rng, 10)
        # Capim seco (0..1): manchas grandes de cerrado, mais seco fora da área andável e pisado perto da trilha.
        self.dry = np.clip(_smooth(0.46, 0.78, self.n_big + (self.n_mid - 0.5) * 0.35 + style['dry']) * 0.82
                           + 0.6 * _smooth(1.0, 9.0, self.d_walk)
                           + 0.25 * (1 - _smooth(0.4, 2.6, self.d_trail)), 0, 1)
        # Grama viçosa (textura densa e escura): só em manchas fracas, mais forte na beira da água.
        self.lush = np.clip(_smooth(0.55, 0.8, self.n_lush + style['lush']) * (1 - self.dry) * 0.62, 0, 1)
        # Campo claro (canal "urze" com heather_tint verde-amarelado): grama ensolarada em manchas grandes, para o
        # verde não ficar chapado (mais verde / mais amarelo).
        self.meadow = np.clip(_smooth(0.35, 0.65, self.n_flower * 0.6 + self.n_mid * 0.4) * (1 - self.dry * 0.7), 0, 1)
        self.ponds = style['ponds']
        self.worn = style['worn']

    def index(self, x, z):
        i = int(np.clip((z + SPLAT_SIZE / 2) / self.step, 0, SPLAT_PX - 1))
        j = int(np.clip((x + SPLAT_SIZE / 2) / self.step, 0, SPLAT_PX - 1))
        return i, j

    def at(self, field, x, z):
        return float(field[self.index(x, z)])

    def _dist_to(self, polylines):
        mask = np.zeros(self.gx.shape, dtype=bool)
        for pts in polylines:
            for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
                n = max(1, int(math.hypot(x1 - x0, z1 - z0) / (self.step * 0.5)))
                for k in range(n + 1):
                    mask[self.index(x0 + (x1 - x0) * k / n, z0 + (z1 - z0) * k / n)] = True
        if not mask.any():
            return np.full(self.gx.shape, 1e9, dtype=np.float32)
        return ndimage.distance_transform_edt(~mask) * self.step

    def write_ground(self, map_id, rock_spots, termite_spots):
        """Mapas de mistura (splat_a/b/c de env_terrain_world) e o material do chão deste mapa."""
        gx, gz = self.gx, self.gz
        wob = (self.n_mid - 0.5) * 0.9 + (self.n_small - 0.5) * 0.7  # borda pintada, nunca reta
        # Terra batida: a Estrada (ombro largo, lê como estrada) e as trilhas (ombro estreito) entrando na grama.
        road = 1 - _smooth(ROAD_HALF_WIDTH - 0.2, ROAD_HALF_WIDTH + 1.1, self.d_road + wob)
        branch = 1 - _smooth(BRANCH_HALF_WIDTH - 0.1, BRANCH_HALF_WIDTH + 0.6, self.d_branch + wob * 0.6)
        dirt = np.maximum(road * 0.95, branch * 0.85)
        for x, z, r in self.worn:  # chão gasto do acampamento e da praça
            d = np.sqrt((gx - x) ** 2 + (gz - z) ** 2) - r + wob * 1.5
            dirt = np.maximum(dirt, (1 - _smooth(-1.5, 1.5, d)) * 0.8)
        # Rocha e cascalho embaixo dos afloramentos; terra vermelha do cerrado aparecendo fora da área andável.
        rock = np.zeros(gx.shape, dtype=np.float32)
        gravel = _smooth(0.7, 0.86, self.n_small) * _smooth(2.0, 6.0, self.d_walk) * 0.7
        for x, z, r in rock_spots:
            d = np.sqrt((gx - x) ** 2 + (gz - z) ** 2)
            rock = np.maximum(rock, (1 - _smooth(r * 0.55, r * 1.05, d + wob)) * 0.9)
            gravel = np.maximum(gravel, (1 - _smooth(r * 0.9, r * 1.7, d + wob)) * 0.75)
        red = _smooth(0.7, 0.85, self.n_red) * _smooth(2.0, 7.0, self.d_walk) * 0.62
        for x, z, r in termite_spots:
            d = np.sqrt((gx - x) ** 2 + (gz - z) ** 2)
            red = np.maximum(red, (1 - _smooth(r * 0.3, r * 0.9, d + wob * 0.4)) * 0.62)
        dry, lush, meadow = self.dry.copy(), self.lush.copy(), self.meadow.copy()
        mud = np.zeros(gx.shape, dtype=np.float32)
        for x, z, r in self.ponds:  # beira da água: lama escura e grama viçosa em volta
            d = np.sqrt((gx - x) ** 2 + (gz - z) ** 2) - r
            mud = np.maximum(mud, (1 - _smooth(0.2, 2.2, d + wob)) * 0.85)
            lush = np.maximum(lush, (1 - _smooth(1.5, 7.0, d + wob * 2)) * 0.85)
            dry = dry * _smooth(1.0, 8.0, d)
        dirt = dirt * (1 - mud)

        def channel(a):
            return (np.clip(a, 0, 1) * 255).astype(np.uint8)

        zero = np.zeros(gx.shape, dtype=np.float32)
        one = np.full(gx.shape, 1.0, dtype=np.float32)
        # Alfa nunca 0: o import do Godot (fix_alpha_border) mexeria no RGB dos pixels transparentes.
        alpha_floor = 1.5 / 255
        layers = {
            'a': (dirt, zero, zero, np.maximum(rock, alpha_floor)),     # R terra  G calçamento  B areia  A rocha
            'b': (zero, dry, mud, np.maximum(gravel, alpha_floor)),     # R neve   G capim seco  B mata/lama  A cascalho
            'c': (red, lush, meadow, one),                              # R terra vermelha  G grama viçosa  B campo claro
        }
        paths = {}
        for key, chans in layers.items():
            img = Image.fromarray(np.dstack([channel(c) for c in chans]), 'RGBA')
            rel = f'{SPLAT_DIR}/{map_id}_splat_{key}.png'
            img.save(GAME / rel)
            paths[key] = 'res://' + rel
        # Base = grama verde (tex_grass); capim seco, grama viçosa e lama por cima, como no Campo de Treino.
        tex = {'grass': 'tex_grass', 'lush': 'tex_grass_lush', 'dirt': 'tex_dirt', 'paving': 'tex_paving',
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
                   'shader_parameter/tile_m = 5.0',
                   'shader_parameter/blend_softness = 0.24',
                   'shader_parameter/edge_noise = 0.36',
                   # Manchas quentes (amareladas) e frias (verde-azuladas) na grama: campo pintado, nunca chapado.
                   'shader_parameter/macro_warm = Color(1.14, 1.06, 0.76, 1)',
                   'shader_parameter/macro_cool = Color(0.9, 1.04, 0.86, 1)',
                   'shader_parameter/macro_strength = 0.32',
                   # "urze" usado como campo claro: a grama da base sem o verde escuro que o shader mistura
                   'shader_parameter/heather_tint = Color(1.04, 1.1, 0.84, 1)',
                   'shader_parameter/brush_strength = 0.09']
        material = (f'[gd_resource type="ShaderMaterial" load_steps={len(ext) + 1} format=3]\n\n' + '\n'.join(ext)
                    + '\n\n[resource]\n' + '\n'.join(params) + '\n')
        rel = f'assets/environment/painted/materials/mat_ground_{map_id}.tres'
        (GAME / rel).write_text(material)
        return 'res://' + rel

# Altar de Crendice of the Passo dos Ipês (added to the scene by hand on 10/03; kept by the generator).
CROSSROADS_ALTAR_SUB = '[sub_resource type="StandardMaterial3D" id="altar_mat"]\nalbedo_color = Color(0.42, 0.38, 0.3, 1)\nroughness = 0.9\nemission_enabled = true\nemission = Color(0.7, 0.5, 0.15, 1)\nemission_energy_multiplier = 0.4\n\n[sub_resource type="CylinderMesh" id="altar_mesh"]\ntop_radius = 0.9\nbottom_radius = 1.1\nheight = 0.9\nradial_segments = 12\n\n[sub_resource type="CylinderShape3D" id="altar_shape"]\nheight = 1.5\nradius = 1.4\n\n'
CROSSROADS_ALTAR_NODES = '[node name="altar_crendice" type="Area3D" parent="Interactables"]\nposition = Vector3(6, 0.5, 3)\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\nmetadata/interact_id = &"altar_crendice"\nmetadata/target_id = "m:altar_crendice"\nmetadata/interact_type = &"altar_crendice"\nmetadata/approach_position = Vector3(6, 0, 4.5)\n\n[node name="Shape" type="CollisionShape3D" parent="Interactables/altar_crendice"]\nshape = SubResource("altar_shape")\n\n[node name="Mesh" type="MeshInstance3D" parent="Interactables/altar_crendice"]\nmesh = SubResource("altar_mesh")\nmaterial_override = SubResource("altar_mat")\n\n[node name="Name" type="Label3D" parent="Interactables/altar_crendice"]\nposition = Vector3(0, 1.6, 0)\nbillboard = 1\nfont_size = 40\npixel_size = 0.015\ntext = "Altar de Crendice"\nmodulate = Color(1, 0.88, 0.45, 1)\n\n'


# Marcadores e grupo da quest de vínculo do Guará (tools/content/gen_followers_phase1.py; postos à mão na cena
# em 10/2026): o gerador os mantém.
CROSSROADS_GUARA_NODES = '[node name="GuaraTrack1" type="Marker3D" parent="."]\nposition = Vector3(-10, 0, 8)\n\n[node name="GuaraTrack2" type="Marker3D" parent="."]\nposition = Vector3(-12, 0, 3)\n\n[node name="GuaraTrack3" type="Marker3D" parent="."]\nposition = Vector3(-8, 0, -4)\n\n[node name="GuaraBondRest" type="Marker3D" parent="."]\nposition = Vector3(-8, 0, -4)\n\n[node name="bond_monsters_0" type="Marker3D" parent="Spawns"]\nposition = Vector3(-10, 0, -8)\nmetadata/monster_id = &"maned_wolf"\nmetadata/stage = 2\nmetadata/count = 4\nmetadata/radius_cells = 5\nmetadata/respawn_sec = 35\n\n'
# Pontos que entram depois deste gerador (Guará acima; covil do Saci em build_story_arc1.py): também sem mato alto.
EXTRA_KEEPOUTS = {'fields_pindorama_crossroads': [(-10, 8), (-12, 3), (-8, -4), (8, 16)]}
EXTRA_PACKS = {'fields_pindorama_crossroads': [(-10, -8), (8, 16)]}
# Mistura de cores das manchas de flor por mapa (amarela, branca, roxa).
FLOWER_MIX = {
    'fields_pindorama': {'yellow': 5, 'white': 3, 'purple': 2},
    'fields_pindorama_buriti': {'yellow': 3, 'white': 4, 'purple': 3},
    'fields_pindorama_crossroads': {'yellow': 4, 'white': 2, 'purple': 4},
}


def add_crossroads_altar(source: str) -> str:
    if 'id="altar_mat"' in source:
        return source
    env = '[sub_resource type="Environment" id="env"]'
    spawns = '[node name="Spawns" type="Node3D" parent="."]'
    assert env in source and spawns in source, "fields_pindorama_crossroads layout changed: place the altar again"
    source = source.replace(env, CROSSROADS_ALTAR_SUB + env, 1)
    return source.replace(spawns, CROSSROADS_ALTAR_NODES + spawns, 1)


def build(a):
    map_id = a['id']
    variant = a['variant']
    # Ensure baseline scene is generated
    write_scene(a)
    path = GAME / 'scenes/maps' / f'{map_id}.tscn'
    source = path.read_text(encoding='utf-8')

    paths = [trail_points(a)] + branch_paths(a)
    rooms = clearings(a) + [(0, 33, 6.0), (0, -34, 6.0)]

    # Add map-specific path corridors and clearings
    if map_id == 'fields_pindorama':
        # Outpost camp around Coronel Tobias (14, 9)
        paths.append([(0, 14), (6, 12), (14, 9)])
        rooms.append((14, 9, 8.5))
        # Oasis pond clearing on east
        rooms.append((18, -14, 7.5))
        paths.append([(0, -10), (10, -12), (18, -14)])
        # Bridge path connecting western clearing (-18, 17) to center (0, 16)
        paths.append([(-18, 17), (-8, 16), (0, 16)])
    elif map_id == 'fields_pindorama_buriti':
        # Buriti wetland basin on west
        rooms.append((-16, 2, 8.5))
        paths.append([(0, 2), (-8, 2), (-16, 2)])
        # Bridge crossing over the wetland stream
        paths.append([(-6, 4), (-2, 4), (4, 4)])
        # Eastern plateau clearing
        rooms.append((18, 8, 7.0))
        paths.append([(0, 8), (10, 8), (18, 8)])
    elif map_id == 'fields_pindorama_crossroads':
        # Central crossroads plaza
        rooms.append((0, 0, 8.5))
        # Eastern canyon overlook path
        paths.append([(0, -8), (8, -8), (16, -8)])
        rooms.append((16, -8, 7.0))
        # Western overlook path
        paths.append([(0, 12), (-8, 12), (-16, 12)])
        rooms.append((-16, 12, 7.0))

    samples = [p for route in paths for p in route]

    def walk(x, z):
        # Generous walkable radius along paths and clearings
        if any((x - px)**2 + (z - pz)**2 < 4.6**2 for px, pz in samples):
            return True
        if any((x - px)**2 + (z - pz)**2 < (r + 1.8)**2 for px, pz, r in rooms):
            return True
        return False

    cells = {(x, z) for x in range(-44, 44, 2) for z in range(-44, 44, 2) if walk(x + 1, z + 1)}

    # Build connected navigation mesh
    verts, indexes, polys = [], {}, []
    for x, z in sorted(cells):
        face = []
        for p in [(x, z), (x, z + 2), (x + 2, z + 2), (x + 2, z)]:
            if p not in indexes:
                indexes[p] = len(indexes)
                verts.extend([p[0], 0, p[1]])
            face.append(indexes[p])
        polys.append('PackedInt32Array(' + ', '.join(map(str, face)) + ')')

    nav = '[sub_resource type="NavigationMesh" id="nav"]\ncell_size = 0.2\ncell_height = 0.2\nvertices = PackedVector3Array(' + ', '.join(map(str, verts)) + ')\npolygons = Array[PackedInt32Array]([' + ', '.join(polys) + '])\n\n'
    source = re.sub(r'\[sub_resource type="NavigationMesh" id="nav"\].*?(?=\[node)', nav, source, flags=re.S)

    # Strip out the old sparse rows of decor
    source = re.sub(r'\[node [^\n]*parent="Decor"\].*?(?=\[node|\Z)', '', source, flags=re.S)

    resources = []
    nodes = []

    def res(kind, ident, props):
        resources.append(f'[sub_resource type="{kind}" id="{ident}"]\n{props}')

    def ext_res(path_str, ident):
        resources.append(f'[ext_resource type="ArrayMesh" path="{path_str}" id="{ident}"]')

    def node(name, kind, props, parent='Decor'):
        nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\n{props}\n')

    # Malhas dos pontos de interesse de cada mapa (acampamento, lagoa, pontes, encruzilhada).
    palette_meshes = [
        ('fld_reeds', f'{MESHES}/reeds.res'),
        ('fld_mushroom', f'{MESHES}/pk_mushroom.res'),
        ('fld_bridge', f'{MESHES}/vg_stone_bridge.res'),
    ]
    if map_id == 'fields_pindorama':
        palette_meshes += [
            ('fld_tent_a', f'{MESHES}/camp_tent_v2_a.res'),
            ('fld_tent_b', f'{MESHES}/lm_camp_tent_a.res'),
            ('fld_fire', f'{MESHES}/camp_fire_v2.res'),
            ('fld_well', f'{MESHES}/camp_well.res'),
            ('fld_fence', f'{MESHES}/prop_fence.res'),
            ('fld_wagon', f'{MESHES}/pkv_prop_wagon.res'),
            ('fld_crate', f'{MESHES}/prop_crate.res'),
            ('fld_barrel', f'{MESHES}/pk_barrel.res'),
            ('fld_flagstone', f'{MESHES}/pk_rockpath_square_wide.res'),
        ]
    elif map_id == 'fields_pindorama_buriti':
        palette_meshes += [
            ('fld_palm_buriti', f'{MESHES}/palm_buriti_a.res'),
            ('fld_crate', f'{MESHES}/prop_crate.res'),
            ('fld_barrel', f'{MESHES}/pk_barrel.res'),
            ('fld_signpost', f'{MESHES}/camp_signpost.res'),
        ]
    elif map_id == 'fields_pindorama_crossroads':
        palette_meshes += [
            ('fld_standing_stones', f'{MESHES}/vg_standing_stones.res'),
            ('fld_petals', f'{MESHES}/pk_petals_1.res'),
            ('fld_signpost', f'{MESHES}/camp_signpost.res'),
        ]

    for ident, mpath in palette_meshes:
        ext_res(wg.require_res(mpath), ident)

    # Water material & mesh for ponds/wetlands
    resources.append('[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_water.tres" id="fld_water_mat"]')

    # --- Campo de grama: chão pintado e vegetação (ver FIELD_STYLE) ---
    style = FIELD_STYLE[map_id]
    # Estrada dos Viajantes mais larga e terra batida mais clara (só a malha cosmética da trilha).
    source = re.sub(r'(\[node name="Trail" [^\n]*\]\n+script = ExtResource\("trail_script"\)\n'
                    r'points = PackedVector3Array\([^)]*\)\nphase = [^\n]*\n)', rf'\1half_width = {ROAD_HALF_WIDTH}\n', source)
    source = source.replace('soil_tint = Color(0.67, 0.54, 0.34, 1)', f'soil_tint = Color({TRAIL_SOIL}, 1)')
    trails = _trail_polylines(source)
    assert trails['road'] and trails['branch'], f'{map_id}: trilhas (Trail/TrailBranch*) não achadas na cena'
    layout = FieldLayout(cells, trails, rooms, style)
    keep = _keepouts(source) + [k for k in EXTRA_KEEPOUTS.get(map_id, [])]
    packs = _packs(source) + [p for p in EXTRA_PACKS.get(map_id, [])]
    rng = random.Random(901 + variant)
    small = defaultdict(list)  # folhagem pequena -> pedaços sob o FoliageScatter (densidade/distância do preset)
    big = defaultdict(list)    # árvores, pedras, cupinzeiros, troncos: um MultiMesh por malha, sem corte

    def near(points, x, z, r):
        return any((x - px) ** 2 + (z - pz) ** 2 < r * r for px, pz in points)

    def wet(x, z, margin=0.4):
        return any((x - px) ** 2 + (z - pz) ** 2 < (r + margin) ** 2 for px, pz, r in layout.ponds)

    def put(store, mesh, x, z, smin, smax, y=0.0, stretch=(0.88, 1.12)):
        store[mesh].append((x, y, z, rng.uniform(0, math.tau), rng.uniform(smin, smax), rng.uniform(*stretch),
                            rng.random()))

    def pick(weights):
        return rng.choices(list(weights), weights=list(weights.values()))[0]

    def scatter(density, x0=-SCATTER_LIMIT, x1=SCATTER_LIMIT):
        for _ in range(int((x1 - x0) ** 2 * density)):
            yield rng.uniform(x0, x1), rng.uniform(x0, x1)

    # 1. Afloramentos de pedra fora da área andável (bem menos que os paredões antigos): pouso e rocha no chão.
    rock_spots = []
    for gx in range(-46, 47, 10):
        for gz in range(-46, 47, 10):
            x, z = gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)
            if layout.at(layout.d_walk, x, z) < 3.5 or rng.random() > 0.45 or wet(x, z, 2):
                continue
            for _ in range(rng.randint(1, 3)):
                rx, rz = x + rng.uniform(-1.6, 1.6), z + rng.uniform(-1.6, 1.6)
                mesh = pick({'pk_rock_sand': 3, 'pk_rock_1': 3, 'pk_rock_moss_1': 2, 'rock_red_a': 2})
                lo, hi = ROCKS[mesh]
                put(big, mesh, rx, rz, lo, hi, y=-0.1, stretch=(0.7, 1.0))
                size = {'pk_rock_sand': 1.4, 'pk_rock_1': 1.1, 'pk_rock_moss_1': 1.1, 'rock_red_a': 0.37}[mesh]
                rock_spots.append((rx, rz, size * big[mesh][-1][4] + 0.4))

    # 2. Árvores do cerrado emoldurando o campo (fora da área andável) e ipês/pequizeiros solitários na beira das
    #    clareiras, longe dos grupos de monstros. No buritizal, buritis acompanhando a água (vereda).
    for gx in range(-46, 47, 6):
        for gz in range(-46, 47, 6):
            x, z = gx + rng.uniform(-2.2, 2.2), gz + rng.uniform(-2.2, 2.2)
            d = layout.at(layout.d_walk, x, z)
            if d < 1.4 or rng.random() > 0.78 or wet(x, z, 1.5) or near([(a, b) for a, b, _r in rock_spots], x, z, 2.6):
                continue
            mesh = pick({k: v[0] for k, v in style['trees'].items()})
            put(big, mesh, x, z, style['trees'][mesh][1], style['trees'][mesh][2], stretch=(0.92, 1.08))
    for gx in range(-40, 41, 13):
        for gz in range(-40, 41, 13):
            x, z = gx + rng.uniform(-4, 4), gz + rng.uniform(-4, 4)
            d = layout.at(layout.d_walk, x, z)
            if not (-2.5 < d < 1.4) or rng.random() > 0.45 or layout.at(layout.d_trail, x, z) < 3.0 \
                    or near(packs, x, z, 7.5) or near(keep, x, z, 6.0) or wet(x, z, 2):
                continue
            mesh = pick({k: v[0] for k, v in style['trees'].items() if 'twisted' not in k})
            put(big, mesh, x, z, style['trees'][mesh][1] * 0.9, style['trees'][mesh][2] * 0.95, stretch=(0.92, 1.08))
    for px, pz, r in layout.ponds if map_id == 'fields_pindorama_buriti' else []:
        for i in range(9):
            ang = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
            x, z = px + math.cos(ang) * (r + rng.uniform(2.8, 5.0)), pz + math.sin(ang) * (r + rng.uniform(2.8, 5.0))
            if layout.at(layout.d_trail, x, z) > 2.0 and not near(packs, x, z, 6.0) and not near(keep, x, z, 4.0):
                put(big, rng.choice(['buriti_soft_a', 'buriti_soft_b']), x, z, 0.7, 0.9, stretch=(0.92, 1.08))

    # 3. Cupinzeiros: alguns no campo (longe de trilha, grupos e chegadas) e mais no cerrado em volta.
    termite_spots = []
    tries = 0
    while len(termite_spots) < 18 and tries < 4000:
        tries += 1
        x, z = rng.uniform(-44, 44), rng.uniform(-44, 44)
        d = layout.at(layout.d_walk, x, z)
        inside = len(termite_spots) < 7
        if (inside and d > -1.0) or (not inside and not (0.0 < d < 7.0)):
            continue
        if layout.at(layout.d_trail, x, z) < 1.8 or near(packs, x, z, PACK_CLEAR_R) or near(keep, x, z, KEEPOUT_R + 1) \
                or wet(x, z, 1.5) or near([(a, b) for a, b, _r in termite_spots], x, z, 7.0):
            continue
        put(big, 'termite_mound_a', x, z, 0.55, 0.8 if inside else 1.05, stretch=(0.85, 1.1))
        termite_spots.append((x, z, 0.95 * big['termite_mound_a'][-1][4]))

    # 4. Troncos caídos e tocos na borda (pouso dos pássaros).
    placed = 0
    for x, z in scatter(0.01):
        if placed >= 8:
            break
        if 0.5 < layout.at(layout.d_walk, x, z) < 4.0 and not wet(x, z, 1) and not near(keep, x, z, KEEPOUT_R):
            put(big, rng.choice(['prop_log', 'prop_stump']), x, z, 0.9, 1.2, stretch=(1.0, 1.0))
            placed += 1

    # 5. Arbustos: faixa fechada na beira da área andável (a borda vira mato, não muro), poucos e baixos no campo.
    for x, z in scatter(0.11):
        d = layout.at(layout.d_walk, x, z)
        if d < -0.8 or wet(x, z, 0.8) or layout.at(layout.d_trail, x, z) < 1.0:
            continue
        if d > 5.0 and rng.random() > 0.45:
            continue
        if near(keep, x, z, KEEPOUT_R) or near(packs, x, z, PACK_CLEAR_R):
            continue
        table = BUSHES_DRY if layout.at(layout.dry, x, z) > 0.6 else BUSHES
        mesh = pick({k: 1 for k in table})
        put(small, mesh, x, z, *table[mesh], stretch=(0.8, 1.0))
    for x, z in scatter(0.012):
        if layout.at(layout.d_walk, x, z) > -0.8 or layout.at(layout.d_trail, x, z) < 1.5 or wet(x, z, 1) \
                or near(keep, x, z, KEEPOUT_R) or near(packs, x, z, PACK_CLEAR_R + 1):
            continue
        mesh = pick({'bush_low_c': 2, 'pk_bush_flowers': 2, 'pk_bush': 1})
        lo, hi = BUSHES[mesh]
        put(small, mesh, x, z, lo * 0.8, hi * 0.8, stretch=(0.7, 0.9))

    # 6. Capim baixo cobrindo o campo: verde onde a grama é viçosa, dourado nas manchas secas. Rareia no ombro da
    #    estrada e some na faixa de terra; nada em cima de portal e chegada.
    for x, z in scatter(0.62):
        dt = layout.at(layout.d_trail, x, z)
        if rng.random() > _smooth(-0.1, 1.1, np.float32(dt)) or wet(x, z, 0.2) or near(keep, x, z, 1.4):
            continue
        dry = layout.at(layout.dry, x, z) + rng.uniform(-0.15, 0.15)
        table = GRASS_DRY if dry > 0.55 else GRASS_GREEN
        mesh = pick({k: v[0] for k, v in table.items()})
        put(small, mesh, x, z, table[mesh][1], table[mesh][2])

    # 7. Capim alto em touceiras: na borda das áreas de caça e no cerrado em volta (nunca no miolo da caça).
    for cx, cz in scatter(0.032):
        if layout.at(layout.d_walk, cx, cz) < -5.0 or layout.at(layout.d_trail, cx, cz) < 1.2 or wet(cx, cz, 1) \
                or near(packs, cx, cz, PACK_CLEAR_R) or near(keep, cx, cz, KEEPOUT_R):
            continue
        dry = layout.at(layout.dry, cx, cz) > 0.5
        for _ in range(rng.randint(4, 8)):
            x, z = cx + rng.gauss(0, 0.55), cz + rng.gauss(0, 0.55)
            mesh = 'pk_grass_golden' if dry and rng.random() < 0.7 else pick(
                {'pk_grass_wispy_tall': 3, 'pk_grass_tall': 2, 'grass_tuft_b': 2})
            put(small, mesh, x, z, *GRASS_TALL[mesh])

    # 8. Flores do campo em manchas (amarelas, brancas e roxas) e algumas soltas.
    colors = FLOWER_MIX[map_id]
    for cx, cz in scatter(0.025):
        if layout.at(layout.n_flower, cx, cz) < 0.4 or layout.at(layout.d_trail, cx, cz) < 0.6 or wet(cx, cz, 0.6) \
                or near(keep, cx, cz, 1.6):
            continue
        color = pick(colors)
        for _ in range(rng.randint(4, 9)):
            x, z = cx + rng.gauss(0, 0.7), cz + rng.gauss(0, 0.7)
            put(small, rng.choice(FLOWERS[color]), x, z, 0.85, 1.25)
    for x, z in scatter(0.014):
        if layout.at(layout.d_trail, x, z) > 0.4 and not wet(x, z) and not near(keep, x, z, 1.4):
            put(small, 'pk_flower_single', x, z, 1.1, 1.6)

    # 9. Pedrinhas no ombro da estrada e das trilhas.
    for x, z in scatter(0.035):
        if 0.0 < layout.at(layout.d_trail, x, z) < 1.4 and not near(keep, x, z, 1.4):
            put(small, rng.choice(['pk_pebble_round_1', 'pk_pebble_round_3', 'pk_pebble_square_2']), x, z, 0.9, 1.6,
                stretch=(1.0, 1.0))

    # Chão pintado (precisa das pedras e cupinzeiros já no lugar).
    ground = layout.write_ground(map_id, rock_spots, termite_spots)
    source = source.replace('res://assets/environment/painted/materials/mat_ground_dry_grass.tres', ground)

    def fmt(v):
        t = f'{v:.3f}'.rstrip('0').rstrip('.')
        return '0' if t in ('-0', '') else t

    def rows(items, custom):
        out = []
        for x, y, z, ang, s, sy, seed in items:
            c, sn = math.cos(ang) * s, math.sin(ang) * s
            vals = [c, 0, sn, x, 0, s * sy, 0, y, -sn, 0, c, z]
            if custom:
                vals += [seed, 1, 1, 1]
            out.append(', '.join(fmt(v) for v in vals))
        return ', '.join(out)

    for mesh in sorted(set(big) | set(small)):
        ext_res(wg.require_res(f'{MESHES}/{mesh}.res'), f'fm_{mesh}')
    # Árvores, pedras, cupinzeiros e troncos: nomes com "fld_" (o AmbientScan acha pouso pelo nome da malha/nó).
    for mesh in sorted(big):
        ident = f'mm_fld_{mesh}'
        res('MultiMesh', ident, f'transform_format = 1\nmesh = ExtResource("fm_{mesh}")\n'
            f'instance_count = {len(big[mesh])}\nbuffer = PackedFloat32Array({rows(big[mesh], False)})')
        node(f'Multi_fld_{mesh}', 'MultiMeshInstance3D', f'multimesh = SubResource("{ident}")')
    # Folhagem pequena em pedaços de FOLIAGE_CHUNK m, embaralhada (o preset reduz a densidade por igual).
    resources.append(f'[ext_resource type="Script" path="{wg.require_res(FOLIAGE_SCRIPT)}" id="foliage_script"]')
    node('FieldFoliage', 'Node3D', f'script = ExtResource("foliage_script")\nchunk_size = {FOLIAGE_CHUNK:g}')
    for mesh in sorted(small):
        chunks = defaultdict(list)
        for it in small[mesh]:
            chunks[(math.floor(it[0] / FOLIAGE_CHUNK + 0.5), math.floor(it[2] / FOLIAGE_CHUNK + 0.5))].append(it)
        for (kx, kz) in sorted(chunks):
            items = chunks[(kx, kz)]
            rng.shuffle(items)
            ident = f'mm_{mesh}_{kx}_{kz}'.replace('-', 'm')
            res('MultiMesh', ident, f'transform_format = 1\nuse_custom_data = true\nmesh = ExtResource("fm_{mesh}")\n'
                f'instance_count = {len(items)}\nbuffer = PackedFloat32Array({rows(items, True)})')
            node(f'{mesh}_{kx}_{kz}', 'MultiMeshInstance3D', f'multimesh = SubResource("{ident}")\ncast_shadow = 0',
                 parent='Decor/FieldFoliage')
    count_small = sum(len(v) for v in small.values())
    count_big = sum(len(v) for v in big.values())

    # Specific Map Features
    if map_id == 'fields_pindorama':
        # Stone Bridge connecting west clearing to center across a gully
        node('StoneBridge', 'MeshInstance3D', 'position = Vector3(-8.5, 0.05, 16.5)\nscale = Vector3(1.2, 1.1, 1.4)\nrotation_degrees = Vector3(0, 90, 0)\nmesh = ExtResource("fld_bridge")')

        # Natural Oasis Pond at (18, -14) (Image 1 & Image 5)
        res('CylinderMesh', 'oasis_water_mesh', 'top_radius = 5.2\nbottom_radius = 5.2\nheight = 0.08\nradial_segments = 24')
        node('OasisWater', 'MeshInstance3D', 'position = Vector3(18, 0.03, -14)\nmesh = SubResource("oasis_water_mesh")\nmaterial_override = ExtResource("fld_water_mat")')
        # Reeds, water lilies, giant mushrooms around pond
        for i in range(12):
            ang = (i / 12.0) * math.tau
            rx = 18 + math.cos(ang) * 5.2
            rz = -14 + math.sin(ang) * 5.2
            node(f'OasisReeds{i}', 'MeshInstance3D', f'position = Vector3({rx:.2f}, 0.04, {rz:.2f})\nscale = Vector3(1.3, 1.5, 1.3)\nmesh = ExtResource("fld_reeds")')
            if i % 3 == 0:
                node(f'OasisMushroom{i}', 'MeshInstance3D', f'position = Vector3({rx*0.98:.2f}, 0.05, {rz*0.98:.2f})\nscale = Vector3(1.4, 1.4, 1.4)\nmesh = ExtResource("fld_mushroom")')

        # Frontier Outpost Camp (Coronel Tobias) around (14, 0, 9) (Image 2 & 3)
        node('CampTent1', 'MeshInstance3D', 'position = Vector3(18.5, 0, 11.5)\nrotation_degrees = Vector3(0, -35, 0)\nscale = Vector3(1.3, 1.3, 1.3)\nmesh = ExtResource("fld_tent_a")')
        node('CampTent2', 'MeshInstance3D', 'position = Vector3(11.0, 0, 13.5)\nrotation_degrees = Vector3(0, 45, 0)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_tent_b")')
        node('CampFire', 'MeshInstance3D', 'position = Vector3(14.5, 0, 6.8)\nscale = Vector3(1.3, 1.3, 1.3)\nmesh = ExtResource("fld_fire")')
        node('CampFireLight', 'OmniLight3D', 'position = Vector3(14.5, 1.2, 6.8)\nlight_color = Color(1.0, 0.65, 0.25, 1)\nlight_energy = 1.8\nomni_range = 8.5')
        node('CampWell', 'MeshInstance3D', 'position = Vector3(9.5, 0, 7.2)\nrotation_degrees = Vector3(0, 20, 0)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_well")')
        node('CampWagon', 'MeshInstance3D', 'position = Vector3(19.2, 0, 6.5)\nrotation_degrees = Vector3(0, -65, 0)\nscale = Vector3(1.1, 1.1, 1.1)\nmesh = ExtResource("fld_wagon")')
        node('CampBarrel1', 'MeshInstance3D', 'position = Vector3(17.5, 0, 8.2)\nscale = Vector3(1.1, 1.1, 1.1)\nmesh = ExtResource("fld_barrel")')
        node('CampCrate1', 'MeshInstance3D', 'position = Vector3(18.2, 0, 8.5)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_crate")')
        node('CampFence1', 'MeshInstance3D', 'position = Vector3(15.0, 0, 14.5)\nrotation_degrees = Vector3(0, 0, 0)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_fence")')
        node('CampFence2', 'MeshInstance3D', 'position = Vector3(8.0, 0, 10.5)\nrotation_degrees = Vector3(0, 90, 0)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_fence")')
        node('FlagstonePath', 'MeshInstance3D', 'position = Vector3(14.0, 0.02, 8.5)\nscale = Vector3(1.4, 1.0, 1.4)\nmesh = ExtResource("fld_flagstone")')

    elif map_id == 'fields_pindorama_buriti':
        # Stone bridge crossing the central wetland oasis stream
        node('WetlandBridge', 'MeshInstance3D', 'position = Vector3(-1.0, 0.08, 4.0)\nscale = Vector3(1.3, 1.15, 1.5)\nrotation_degrees = Vector3(0, 90, 0)\nmesh = ExtResource("fld_bridge")')

        # Buriti wetland basin at (-16, 2)
        res('CylinderMesh', 'buriti_water_mesh', 'top_radius = 6.2\nbottom_radius = 6.2\nheight = 0.08\nradial_segments = 24')
        node('BuritiWater', 'MeshInstance3D', 'position = Vector3(-16, 0.03, 2)\nmesh = SubResource("buriti_water_mesh")\nmaterial_override = ExtResource("fld_water_mat")')
        for i in range(14):
            ang = (i / 14.0) * math.tau
            rx = -16 + math.cos(ang) * 6.2
            rz = 2 + math.sin(ang) * 6.2
            node(f'BuritiReeds{i}', 'MeshInstance3D', f'position = Vector3({rx:.2f}, 0.04, {rz:.2f})\nscale = Vector3(1.4, 1.6, 1.4)\nmesh = ExtResource("fld_reeds")')
            if i % 2 == 0:
                node(f'WaterPalm{i}', 'MeshInstance3D', f'position = Vector3({rx*1.08:.2f}, 0.0, {rz*1.08:.2f})\nscale = Vector3(1.1, 1.3, 1.1)\nmesh = ExtResource("fld_palm_buriti")')

        node('BuritiSignpost', 'MeshInstance3D', 'position = Vector3(2.5, 0, 2.5)\nrotation_degrees = Vector3(0, -45, 0)\nscale = Vector3(1.2, 1.2, 1.2)\nmesh = ExtResource("fld_signpost")')
        node('BuritiCrate', 'MeshInstance3D', 'position = Vector3(3.2, 0, 1.8)\nscale = Vector3(1.1, 1.1, 1.1)\nmesh = ExtResource("fld_crate")')
        node('BuritiBarrel', 'MeshInstance3D', 'position = Vector3(3.8, 0, 2.2)\nscale = Vector3(1.0, 1.0, 1.0)\nmesh = ExtResource("fld_barrel")')

    elif map_id == 'fields_pindorama_crossroads':
        # Overlook stone bridge crossing canyon drop
        node('CrossroadsBridge', 'MeshInstance3D', 'position = Vector3(8.0, 0.08, -8.0)\nscale = Vector3(1.25, 1.1, 1.4)\nrotation_degrees = Vector3(0, 90, 0)\nmesh = ExtResource("fld_bridge")')

        # Standing stones landmark at the crossroads
        node('StandingStones', 'MeshInstance3D', 'position = Vector3(0, 0, 0)\nscale = Vector3(1.5, 1.5, 1.5)\nmesh = ExtResource("fld_standing_stones")')
        node('CrossroadSignpost', 'MeshInstance3D', 'position = Vector3(2.5, 0, -2.5)\nrotation_degrees = Vector3(0, 30, 0)\nscale = Vector3(1.3, 1.3, 1.3)\nmesh = ExtResource("fld_signpost")')

        # Fallen Ipê petals around the crossroads
        for i in range(8):
            ang = (i / 8.0) * math.tau
            px = math.cos(ang) * 5.0
            pz = math.sin(ang) * 5.0
            node(f'Petals{i}', 'MeshInstance3D', f'position = Vector3({px:.2f}, 0.02, {pz:.2f})\nscale = Vector3(1.5, 1.0, 1.5)\nrotation_degrees = Vector3(0, {i*45}, 0)\nmesh = ExtResource("fld_petals")')

    # Merge ext_resource and sub_resource blocks cleanly
    ext = [r for r in resources if r.startswith('[ext')]
    sub = [r for r in resources if r.startswith('[sub')]
    source = source.replace('[sub_resource', '\n\n'.join(ext) + '\n\n[sub_resource', 1)
    source = source.replace('[node', '\n\n'.join(sub) + '\n\n[node', 1)
    source += '\n' + '\n'.join(nodes)
    if map_id == 'fields_pindorama_crossroads':
        source = add_crossroads_altar(source)
        if 'name="GuaraTrack1"' not in source:
            source += '\n' + CROSSROADS_GUARA_NODES.rstrip('\n') + '\n'

    source = re.sub(r'load_steps=\d+', f'load_steps={1 + source.count("[ext_resource") + source.count("[sub_resource")}', source, count=1)
    path.write_text(source, encoding='utf-8')

    # Update zone file
    zone = GAME / 'data/zones' / f'{map_id}.tres'
    if zone.exists():
        text = zone.read_text(encoding='utf-8')
        text = re.sub(r'^.*(?:id="minimap"|minimap_texture =|minimap_world_rect =).*\n', '', text, flags=re.M)
        zone.write_text(text, encoding='utf-8')

    print(f"{map_id}: {len(cells)} walk cells, {count_big} trees/rocks/mounds, {count_small} small foliage instances.")


def main():
    for area in AREAS:
        if area.get('scenery') == 'fields':
            build(area)
    print("All Pindorama Fields reformed successfully.")
    wg.finish([a['id'] for a in AREAS if a.get('scenery') == 'fields'], 'fields')


if __name__ == '__main__':
    main()
