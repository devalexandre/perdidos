"""Build the first connected hunting route; run from any directory with Python 3.
Includes the new Pindorama wildlife exported by the native Blender pipeline.
"""
from pathlib import Path
import math, re, csv, io

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)
ROOT=Path(__file__).resolve().parents[3]
GAME=ROOT/'game'
CAVE_MAP_ID='cave_reino_encoberto'
AREAS=[
 dict(id='fields_pindorama',key='WA_P_CAMPOS_PINDORAMA',levels=(1,10),cap=1,boss=False,ground='dry_grass',color='0.57, 0.55, 0.29',previous='city_awakening',next='enchanted_forest',spawns=[('prank_whirlwind',1,6,-18,17),('enchanted_firefly',1,5,18,1),('stone_armadillo',1,4,-18,-20)]),
 dict(id='enchanted_forest',key='WA_P_MATA_ENCANTADA',levels=(6,12),cap=2,boss=False,ground='jungle_floor',color='0.19, 0.38, 0.23',previous='fields_pindorama',next='split_sky_plateau',spawns=[('prank_whirlwind',2,6,-18,16),('enchanted_firefly',2,6,18,0),('stone_armadillo',2,5,-18,-20)]),
 dict(id='split_sky_plateau',key='WA_P_CHAPADA_CEU_PARTIDO',levels=(12,25),cap=3,boss=True,ground='red_earth',color='0.59, 0.31, 0.19',previous='enchanted_forest',next=None,spawns=[('highland_prank_whirlwind',1,5,-18,16),('highland_enchanted_firefly',1,5,18,0),('highland_stone_armadillo',1,4,-18,-12)])]

# One named forest, four independently loaded hunting maps.
FOREST = [
 ('enchanted_forest', 'ENTRANCE', 'Entrada da Mata', [0, -3, -9, -5, 7, 4, 0]),
 ('enchanted_forest_glade', 'GLADE', 'Clareira dos Vaga-lumes', [0, 5, 13, 6, -9, -5, 0]),
 ('enchanted_forest_roots', 'ROOTS', 'Bosque das Raízes', [0, -6, -15, -8, 12, 6, 0]),
 ('enchanted_forest_heart', 'HEART', 'Coração da Mata', [0, 7, 15, 4, -13, -6, 0]),
]
base = AREAS[1]
forest = []
for i, (mid, key, title, bends) in enumerate(FOREST):
 a = dict(base, id=mid, key='WA_FOREST_'+key, bends=bends, variant=i)
 a['previous'] = 'fields_pindorama' if i == 0 else FOREST[i-1][0]
 a['next'] = 'split_sky_plateau' if i == 3 else FOREST[i+1][0]
 # Distinct hunting clearings, with the same regional difficulty.
 a['spawns'] = [(m, st, count+(i+j)%3, x, z) for j,(m,st,count,x,z) in enumerate(base['spawns'])]
 forest.append(a)
AREAS = [AREAS[0]] + forest + [dict(AREAS[2], previous=FOREST[-1][0])]


FIELDS = [
 ('fields_pindorama', 'WA_FIELDS_ENTRANCE', 'Campos de Pindorama · Estrada dos Viajantes', [0, 3, 8, 0, -8, -3, 0]),
 ('fields_pindorama_buriti', 'WA_FIELDS_BURITI', 'Campos de Pindorama · Veredas do Buriti', [0, -3, -12, -5, 10, 4, 0]),
 ('fields_pindorama_crossroads', 'WA_FIELDS_CROSSROADS', 'Campos de Pindorama · Passo dos Ipês', [0, 5, 14, 3, -10, -4, 0]),
]
HIGHLANDS = [
 ('split_sky_plateau', 'WA_HIGHLANDS_ASCENT', 'Chapada do Céu Partido · Subida Vermelha', [0, -5, -12, -4, 9, 3, 0]),
 ('split_sky_plateau_ridges', 'WA_HIGHLANDS_RIDGES', 'Chapada do Céu Partido · Cristas do Vento', [0, 4, 14, 7, -12, -4, 0]),
 ('split_sky_plateau_summit', 'WA_HIGHLANDS_SUMMIT', 'Chapada do Céu Partido · Alto das Brasas', [0, -4, -10, 7, 15, 5, 0]),
]
fields = [dict(AREAS[0], id=mid, key=key, bends=bends, scenery='fields', variant=i) for i,(mid,key,title,bends) in enumerate(FIELDS)]
highlands = [dict(AREAS[-1], id=mid, key=key, bends=bends, scenery='highlands', variant=i) for i,(mid,key,title,bends) in enumerate(HIGHLANDS)]
AREAS = fields + [dict(a, scenery='forest') for a in forest] + highlands
# Fauna peçonhenta (docs/fauna-peconhenta-e-monstros.md): única fonte de Bolsa de Peçonha (venom_gland) e
# Favo Selvagem (wild_honeycomb, só a abelha), pedidos pelas quests de título e pelos ofícios. Ficam entre as
# clareiras antigas e as espécies regionais, para não mudar o primeiro e o último destino (circuito lateral).
# Cada grupo ganha clareira e ramal próprios (clearings/branch_paths). Nível: o menor nível de cada setor
# não pode cair ao longo da rota (tests/world/test_hunt_areas), por isso nível < 6 só na Entrada da Mata.
VENOM_PACKS = {
 # Veredas do Buriti: abelhas nos buritis, mosquito na água parada do brejo, jararaca na folhagem.
 'fields_pindorama_buriti': [('killer_bee',1,5,22,22), ('aedes_mosquito',1,4,-28,-6), ('jararaca_serpent',1,3,26,-26)],
 # Passo dos Ipês: escorpião no entulho das pedras, taturana nos troncos de ipê.
 'fields_pindorama_crossroads': [('yellow_scorpion',1,4,26,16), ('lonomia_caterpillar',1,3,-26,-6)],
 # Mata Encantada: aranhas nos arbustos e nos ocos, serpentes da mata fechada e das clareiras.
 'enchanted_forest': [('wandering_spider',1,3,26,14), ('brown_recluse',1,3,-28,-6)],
 'enchanted_forest_glade': [('coral_snake',1,3,26,14), ('rattlesnake',1,3,-28,-6)],
 'enchanted_forest_roots': [('brown_recluse',2,3,26,14), ('wandering_spider',2,3,-28,-6)],
 'enchanted_forest_heart': [('surucucu_serpent',1,3,26,14), ('coral_snake',2,3,-28,-6)],
}
for i,a in enumerate(AREAS):
 a['previous'] = AREAS[i-1]['id'] if i else 'city_awakening'
 a['next'] = AREAS[i+1]['id'] if i+1 < len(AREAS) else None
 advanced = a['scenery'] == 'highlands'
 # Quest species stay available; new regional wildlife fills additional clearings.
 new_species = ['buriti_boar', 'cinder_serpent', 'ember_mule']
 a['spawns'] = list(a['spawns']) + VENOM_PACKS.get(a['id'], []) + [(('highland_' if advanced else '') + mid, 2 if a['scenery']=='forest' else 1, 4 if j==a['variant']%3 else 2, x,z) for j,(mid,(x,z)) in enumerate(zip(new_species,[(-12,8),(12,-10),(-12,-27)]))]
 # Chefes fixos (decisão do dono, 30/09/2026: sem evolução e sem chefe por contagem de abates). Cada covil
 # (BossLairs/) é a casa de UM chefe, com bando fixo; renasce em Balance.boss_respawn_sec. Subida Vermelha: os 3
 # chefes de Pindorama pedidos pelos anciãos; Cristas: Queixada; Alto das Brasas: Serpente-Fagulha e Mula de Brasa.
 a['lairs'] = {0: [('highland_prank_whirlwind',-22,-28),('highland_enchanted_firefly',-1,-28),('highland_stone_armadillo',20,-28)],
               1: [('highland_buriti_boar',20,-28)],
               2: [('highland_cinder_serpent',20,-28),('highland_ember_mule',-22,-28)]}[a['variant']] if advanced else []


def write_names():
 entries = [[key,title] for _,key,title,_ in FIELDS+HIGHLANDS]
 entries += [['WA_FOREST_'+key, 'Mata Encantada · '+title] for _,key,title,_ in FOREST]
 entries += [['WA_CAVE_REINO_ENCOBERTO', 'Mata Encantada · Caverna do Reino Encoberto']]
 wg.csv_set('localization/world.csv', entries)  # in place: keeps the file order


def _sample_controls(controls, samples=12):
 # Catmull-Rom, with shared samples for the visible trail and minimap.
 result = []
 for i in range(len(controls)-1):
  p0,p1,p2,p3 = [controls[max(0,min(len(controls)-1,j))] for j in (i-1,i,i+1,i+2)]
  for step in range(samples):
   t=step/samples
   result.append(tuple(.5*((2*p1[k])+(-p0[k]+p2[k])*t+(2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t*t+(-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t*t*t) for k in (0,1)))
 return result+[controls[-1]]


def trail_points(a):
 base = list(zip(a.get('bends', [0, 3, 8, 0, -8, -3, 0]), [39, 26, 13, 0, -13, -26, -39]))
 amp = {'fields': 2.6, 'forest': 4.2, 'highlands': 3.4}[a['scenery']]
 phase = a.get('variant', 0) * 1.7
 controls = []
 for i,(x,z) in enumerate(base):
  if i not in (0, len(base)-1):
   x += math.sin(i * 1.37 + phase) * amp
   z += math.sin(i * 0.91 + phase) * 1.2
  controls.append((x,z))
 return _sample_controls(controls, 14)


def _nearest_path_point(points, target):
 tx,tz = target
 return min(points, key=lambda p:(p[0]-tx)*(p[0]-tx)+(p[1]-tz)*(p[1]-tz))


def branch_paths(a):
 main = trail_points(a)
 branches = []
 destinations = [(x,z) for _mid,_stage,_count,x,z in a['spawns']] + [(x,z) for _mid,x,z in a['lairs']]
 for i,(x,z) in enumerate(destinations):
  anchor = _nearest_path_point(main, (x,z))
  dx,dz = x-anchor[0], z-anchor[1]
  length = max(1.0, math.hypot(dx,dz))
  side = (-dz/length, dx/length)
  sway = (1 if (i+a.get('variant',0)) % 2 == 0 else -1) * (3.0 + (i % 3))
  controls = [anchor,
   ((anchor[0]*0.62+x*0.38)+side[0]*sway, (anchor[1]*0.62+z*0.38)+side[1]*sway),
   ((anchor[0]*0.28+x*0.72)-side[0]*sway*0.45, (anchor[1]*0.28+z*0.72)-side[1]*sway*0.45),
   (x,z)]
  branches.append(_sample_controls(controls, 8))
 # Um caminho lateral fecha um circuito de exploração entre duas clareiras.
 x1,z1=destinations[0]; x2,z2=destinations[-1]
 if abs(x1-x2) < 10:
  branches.append(_sample_controls([(x1,z1),(x1-4,(z1+z2)*.5),(x2,z2)], 10))
 return branches


def clearings(a):
 out = [(x,z,5.0 + (i % 2) * 1.4) for i,(_mid,_stage,_count,x,z) in enumerate(a['spawns'])]
 if a.get('boss'):
  out += [(x,z,6.2) for _mid,x,z in a['lairs']]
 return out


def write_minimap(a):
 main=' '.join(f'{x+44:.2f},{z+44:.2f}' for x,z in trail_points(a))
 pal = {'forest':('#385338','#17301f','#93b75f','#b9a06f'),
        'fields':('#738957','#3d5c37','#a8b86b','#c5aa78'),
        'highlands':('#906147','#5b3029','#c27a44','#b99468')}[a['scenery']]
 masses = ''.join(f'<path d="M{x+39} {z+39} l8 -1 3 5 -2 6 -9 -1z" fill="{pal[1]}" stroke="{pal[2]}" stroke-width=".6"/>'
  for x in (-30,30) for z in (-30,-10,10,30))
 # Vegetação miúda dá escala; as ilhas correspondem aos obstáculos reais da navegação.
 for i in range(260):
  x=((i*37)%86)+1; z=((i*53+i//7)%86)+1
  masses += f'<circle cx="{x}" cy="{z}" r="{.3+(i%4)*.12}" fill="{pal[2]}" opacity=".45"/>'
 branches = ''.join('<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" opacity=".92"/>'
  % (' '.join(f'{x+44:.2f},{z+44:.2f}' for x,z in pts), pal[3]) for pts in branch_paths(a))
 spots = ''.join(f'<ellipse cx="{x+44}" cy="{z+44}" rx="{r}" ry="{r*0.72}" fill="{pal[3]}" opacity=".72"/>'
  for x,z,r in clearings(a))
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="352" height="352" viewBox="0 0 88 88"><rect width="88" height="88" fill="{pal[0]}"/>{masses}{spots}<polyline points="{main}" fill="none" stroke="#4b3428" stroke-width="5.6" stroke-linecap="round" stroke-linejoin="round" opacity=".45"/><polyline points="{main}" fill="none" stroke="{pal[3]}" stroke-width="4.1" stroke-linecap="round" stroke-linejoin="round"/>{branches}</svg>'
 (GAME/'assets/minimap'/f'{a["id"]}.svg').write_text(svg)


def write_scene(a):
 parts=['[gd_scene load_steps=20 format=3]', '[ext_resource type="Script" path="res://scripts/shared/map.gd" id="map"]', f'[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_ground_{a["ground"]}.tres" id="groundmat"]', '[ext_resource type="Script" path="res://scripts/shared/terrain_trail.gd" id="trail_script"]']
 parts.append('[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/fern.res" id="fern"]')
 parts.append('[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/grass_tuft.res" id="grass"]')
 shrub = {'forest':'bush_jungle_a','fields':'bush_low_b','highlands':'bush_dry_a'}[a['scenery']]
 parts.append(f'[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/{shrub}.res" id="shrub"]')
 if 'variant' in a:
  landmark = {'forest': ['tree_jungle_a','tree_ipe_purple_a','pk_deadtree_1','tree_ipe_yellow_giant'], 'fields': ['tree_pequi_a','buriti_a','tree_ipe_yellow_a'], 'highlands': ['rock_red_a','vg_standing_stones','rock_moss_a']}[a['scenery']][a['variant']]
  parts.append(f'[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/{landmark}.res" id="landmark"]')
 if a['id']=='enchanted_forest_roots':
  for mesh_id, mesh_name in [('cave_rock_a','rock_moss_a'),('cave_rock_b','rock_moss_b'),('cave_rock_c','rock_moss_c')]:
   parts.append(f'[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/{mesh_name}.res" id="{mesh_id}"]')
 def sub(kind,id,props):parts.extend([f'[sub_resource type="{kind}" id="{id}"]',props])
 sub('BoxMesh','floor','size = Vector3(100, 0.4, 100)')
 sub('BoxShape3D','floor_shape','size = Vector3(100, 0.4, 100)')
 sub('StandardMaterial3D','stone_mat',f'albedo_color = Color({a["color"]}, 1)\nroughness = 1.0')
 sub('SphereMesh','stone','radius = 1.9\nheight = 3.0\nradial_segments = 8\nrings = 4')
 sub('StandardMaterial3D','portalmat','albedo_color = Color(0.2, 0.75, 0.9, 1)\nemission_enabled = true\nemission = Color(0.08, 0.35, 0.45, 1)')
 if a['id']=='enchanted_forest_roots':
  sub('SphereMesh','cave_mouth','radius = 1.0\nheight = 2.0\nradial_segments = 24\nrings = 12')
  sub('StandardMaterial3D','cave_mouth_mat','albedo_color = Color(0.008, 0.014, 0.018, 1)\nroughness = 1.0\ncull_mode = 2')
 sub('TorusMesh','portal','inner_radius = 1.35\nouter_radius = 1.75\nrings = 16\nring_segments = 8')
 sub('BoxShape3D','portal_shape','size = Vector3(5, 5, 3)')
 sub('Environment','env','background_mode = 1\nbackground_color = Color(0.35, 0.48, 0.58, 1)\nambient_light_source = 3\nambient_light_color = Color(0.8, 0.87, 1, 1)\nambient_light_energy = 0.65\ntonemap_mode = 0')
 # Shared vertices, counterclockwise viewed from above. Decor islands have no walk cells.
 verts=[]
 for z in range(23):
  for x in range(23):verts.extend([x*4-44,0,z*4-44])
 polys=[]
 for z in range(22):
  for x in range(22):
   cx,cz=x*4-42,z*4-42
   if abs(abs(cx)-30)<5 and any(abs(cz-island_z)<5 for island_z in (-30,-10,10,30)):continue
   k=z*23+x;polys.append(f'PackedInt32Array({k}, {k+23}, {k+24}, {k+1})')
 sub('NavigationMesh','nav','cell_size = 0.2\ncell_height = 0.2\nvertices = PackedVector3Array('+', '.join(map(str,verts))+')\npolygons = Array[PackedInt32Array](['+', '.join(polys)+'])')
 def node(name,kind,parent='.',props=''):
  parts.extend([f'[node name="{name}" type="{kind}"'+(']' if parent is None else f' parent="{parent}"]'),props])
 node(a['id'],'Node3D',None,f'script = ExtResource("map")\nmap_id = &"{a["id"]}"')
 node('WorldEnvironment','WorldEnvironment',props='environment = SubResource("env")')
 node('Sun','DirectionalLight3D',props='rotation_degrees = Vector3(-55, -30, 0)\nlight_energy = 1.0\nshadow_enabled = true\nshadow_opacity = 0.42\nlight_angular_distance = 5.0')
 node('Ground','StaticBody3D',props='position = Vector3(0, -0.2, 0)\ncollision_layer = 1\ncollision_mask = 0')
 node('Mesh','MeshInstance3D','Ground','mesh = SubResource("floor")\nmaterial_override = ExtResource("groundmat")')
 node('Collision','CollisionShape3D','Ground','shape = SubResource("floor_shape")')
 points = ', '.join(f'{x:.4f}, 0.025, {z:.4f}' for x,z in trail_points(a))
 soil = {'forest':'0.50, 0.40, 0.25','fields':'0.67, 0.54, 0.34','highlands':'0.68, 0.43, 0.28'}[a['scenery']]
 node('Trail','MeshInstance3D',props=f'script = ExtResource("trail_script")\npoints = PackedVector3Array({points})\nphase = {a.get("variant", 0)}.0\nsoil_tint = Color({soil}, 1)')
 for i,pts in enumerate(branch_paths(a)):
  bpoints = ', '.join(f'{x:.4f}, 0.027, {z:.4f}' for x,z in pts)
  node(f'TrailBranch{i}','MeshInstance3D',props=f'script = ExtResource("trail_script")\npoints = PackedVector3Array({bpoints})\nphase = {a.get("variant", 0) + i + 1}.0\nhalf_width = 0.95\nsoil_tint = Color({soil}, 1)')
 node('NavigationRegion3D','NavigationRegion3D',props='navigation_mesh = SubResource("nav")')
 node('SpawnPoint','Marker3D',props='position = Vector3(0, 0, 33)')
 node('NorthArrival','Marker3D',props='position = Vector3(0, 0, -34)')
 if a['id']=='fields_pindorama':
  node('NpcPoints','Node3D')
  node('coronel_tobias','Marker3D','NpcPoints','position = Vector3(14, 0, 9)')
 if a['id']=='fields_pindorama_crossroads':
  node('ThreeRoads','Marker3D',props='position = Vector3(0, 0, 0)')
 if a['id']=='enchanted_forest_roots':
  node('NpcPoints','Node3D')
  node('curupira','Marker3D','NpcPoints','position = Vector3(-12, 0, 4)')
  node('PactOffering','Marker3D',props='position = Vector3(12, 0, -10)')
 node('Viewpoint1','Marker3D',props='position = Vector3(28, 38, 38)\nrotation_degrees = Vector3(-45, 35, 0)')
 node('Decor','Node3D')
 if a['id']=='enchanted_forest_roots':
  node('CaveMouth','MeshInstance3D','Decor','position = Vector3(0, 2.2, 26.2)\nscale = Vector3(2.8, 1.7, 0.22)\nmesh = SubResource("cave_mouth")\nmaterial_override = SubResource("cave_mouth_mat")')
  node('CaveRockLeft','MeshInstance3D','Decor','position = Vector3(-3.1, 0.2, 24.5)\nrotation_degrees = Vector3(0, 22, -8)\nscale = Vector3(2.0, 2.2, 1.7)\nmesh = ExtResource("cave_rock_a")')
  node('CaveRockRight','MeshInstance3D','Decor','position = Vector3(3.0, 0.15, 24.8)\nrotation_degrees = Vector3(0, 192, 7)\nscale = Vector3(1.8, 2.0, 1.6)\nmesh = ExtResource("cave_rock_b")')
  node('CaveRockLintel','MeshInstance3D','Decor','position = Vector3(0.3, 3.7, 25.0)\nrotation_degrees = Vector3(0, 35, 3)\nscale = Vector3(2.7, 1.1, 1.4)\nmesh = ExtResource("cave_rock_c")')
  node('CaveThresholdRock','MeshInstance3D','Decor','position = Vector3(-4.8, 0.0, 23.4)\nrotation_degrees = Vector3(0, 73, 0)\nscale = Vector3(1.25, 1.1, 1.2)\nmesh = ExtResource("cave_rock_a")')
  node('CaveGlow','OmniLight3D',props='position = Vector3(0, 2.0, 21.5)\nlight_color = Color(0.28, 0.76, 0.82, 1)\nlight_energy = 0.32\nomni_range = 9.0\nshadow_enabled = false')
 positions=[(x,z) for x in (-47,47) for z in range(-40,45,8)]+[(x,z) for z in (-47,47) for x in range(-40,45,8)]+[(x,z) for x in (-34,-28,28,34) for z in (-30,-10,10,30)]
 for i,(x,z) in enumerate(positions):
  if 'variant' in a and abs(x) == 30 and abs(z) in (10,30):continue
  if a.get('scenery') == 'highlands':
   node(f'Rock{i}','MeshInstance3D','Decor',f'position = Vector3({x}, 0, {z})\nrotation_degrees = Vector3(0, {i*47%360}, 0)\nscale = Vector3(2.2, {2.0+(i%3)*.35}, 2.2)\nmesh = ExtResource("landmark")')
  else:
   node(f'Tree{i}', 'MeshInstance3D', 'Decor', f'position = Vector3({x}, 0, {z})\nrotation_degrees = Vector3(0, {i*37%360}, 0)\nscale = Vector3(1.15, {1.0+(i%3)*0.15}, 1.15)\nmesh = ExtResource("landmark")')
 if 'variant' in a:
  for i,(x,z) in enumerate([(x,z) for x in (-30,30) for z in (-30,-10,10,30)]):
   scale = 3.2 if a['scenery'] == 'highlands' else 1.0
   node(f'Landmark{i}', 'MeshInstance3D', 'Decor', f'position = Vector3({x}, 0, {z})\nscale = Vector3({scale}, {scale}, {scale})\nmesh = ExtResource("landmark")')
 # Low vegetation follows the trail without covering the walking surface.
 scenic_paths = [trail_points(a)] + branch_paths(a)
 trail_decor = [p for pts in scenic_paths for p in pts[3:-3:4]]
 for i,(x,z) in enumerate(trail_decor):
  for side in (-1,1):
   px = x + side*(3.2+(i%4)*0.45)
   resource = 'fern' if a['scenery']=='forest' else 'grass'
   pz = z + math.sin(i*1.91 + side) * 0.8
   node(f'Vegetation{i}_{side+1}', 'MeshInstance3D', 'Decor', f'position = Vector3({px:.3f}, 0, {pz:.3f})\nrotation_degrees = Vector3(0, {i*53%360}, 0)\nscale = Vector3(1.6, 1.6, 1.6)\nmesh = ExtResource("{resource}")')
   if i % 3 == 0:
    sx=px+side*(1.3+.2*(i%4))
    size=.65+(i%5)*.12
    node(f'Shrub{i}_{side+1}', 'MeshInstance3D', 'Decor', f'position = Vector3({sx:.3f}, 0, {pz+.5:.3f})\nrotation_degrees = Vector3(0, {i*73%360}, 0)\nscale = Vector3({size}, {size}, {size})\nmesh = ExtResource("shrub")')
 node('Interactables','Node3D')
 for name,z,dest,arrival in [('back',39,a['previous'],'SpawnPoint' if a['previous']=='city_awakening' else 'NorthArrival'),('forward',-39,a['next'],'SpawnPoint')]:
  if not dest:continue
  low,high=next((v['levels'] for v in AREAS if v['id']==dest),(0,0))
  node(name,'Area3D','Interactables',f'position = Vector3(0, 2, {z})\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\nmetadata/interact_id = &"{name}"\nmetadata/target_id = "m:{name}"\nmetadata/interact_type = &"portal"\nmetadata/target_map = &"{dest}"\nmetadata/target_spawn = &"{arrival}"\nmetadata/recommended_level = "{low}–{high}"\nmetadata/approach_position = Vector3(0, 0, {z})')
  node('Shape','CollisionShape3D','Interactables/'+name,'shape = SubResource("portal_shape")')
  node('Gate','MeshInstance3D','Interactables/'+name,'rotation_degrees = Vector3(90, 0, 0)\nmesh = SubResource("portal")\nmaterial_override = SubResource("portalmat")')
  key=next((v['key'] for v in AREAS if v['id']==dest),'ZONE_CITY_AWAKENING_NAME')
  node('Name','Label3D','Interactables/'+name,f'position = Vector3(0, 3.0, 0)\nbillboard = 1\nfont_size = 48\npixel_size = 0.015\ntext = "{key}"')
 if a['id']=='enchanted_forest_roots':
  node('cave','Area3D','Interactables','position = Vector3(0, 2, 24)\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\nmetadata/interact_id = &"cave"\nmetadata/target_id = "m:cave"\nmetadata/interact_type = &"portal"\nmetadata/target_map = &"cave_reino_encoberto"\nmetadata/target_spawn = &"SpawnPoint"\nmetadata/recommended_level = "12–25"\nmetadata/approach_position = Vector3(0, 0, 24)')
  node('Shape','CollisionShape3D','Interactables/cave','shape = SubResource("portal_shape")')
  node('Gate','MeshInstance3D','Interactables/cave','rotation_degrees = Vector3(90, 0, 0)\nmesh = SubResource("portal")\nmaterial_override = SubResource("portalmat")')
  node('Name','Label3D','Interactables/cave','position = Vector3(0, 3.0, 0)\nbillboard = 1\nfont_size = 48\npixel_size = 0.015\ntext = "WA_CAVE_REINO_ENCOBERTO"')
  node('CaveReturn','Marker3D',props='position = Vector3(0, 0, 21)')
  node('CaveFootprints','Marker3D',props='position = Vector3(-4, 0, 20)')
 node('Spawns','Node3D')
 for i,(mid,stage,count,x,z) in enumerate(a['spawns']):
  node(f'monsters_{i}','Marker3D','Spawns',f'position = Vector3({x}, 0, {z})\nmetadata/monster_id = &"{mid}"\nmetadata/stage = {stage}\nmetadata/count = {count}\nmetadata/radius_cells = 7\nmetadata/respawn_sec = 35')
 if a['boss']:
  node('BossLairs','Node3D')
  for mid,x,z in a['lairs']:
   node(mid,'Marker3D','BossLairs',f'position = Vector3({x}, 0, {z})\nmetadata/monster_id = &"{mid}"\nmetadata/radius_cells = 4')
 parts[0] = f'[gd_scene load_steps={1 + sum(p.startswith(("[ext_resource", "[sub_resource")) for p in parts)} format=3]'
 (GAME/'scenes/maps'/f'{a["id"]}.tscn').write_text('\n\n'.join(parts)+'\n')
 write_minimap(a)
 connected=[a['previous']]+([a['next']] if a['next'] else [])
 if a['id']=='enchanted_forest_roots':connected.append(CAVE_MAP_ID)
 if a['id']==CAVE_MAP_ID:connected.append(f'{CAVE_MAP_ID}_2')
 zone=f'''[gd_resource type="Resource" script_class="ZoneDef" format=3]
[ext_resource type="Script" path="res://scripts/shared/data/zone_def.gd" id="zone"]
[ext_resource type="Texture2D" path="res://assets/minimap/{a['id']}.svg" id="minimap"]
[resource]
script = ExtResource("zone")
map_id = &"{a['id']}"
kind = 2
name_key = "{a['key']}"
region_id = &"pindorama"
recommended_level_min = {a['levels'][0]}
recommended_level_max = {a['levels'][1]}
monster_stage_cap = {a['cap']}
bosses_allowed = {str(a['boss']).lower()}
connected_maps = Array[StringName]([{', '.join('&"'+d+'"' for d in connected)}])
minimap_texture = ExtResource("minimap")
minimap_world_rect = Rect2(-44, -44, 88, 88)
'''
 (GAME/'data/zones'/f'{a["id"]}.tres').write_text(zone)


def write_cave_scene():
 scene='''[gd_scene load_steps=31 format=3]

[ext_resource type="Script" path="res://scripts/shared/cave_level.gd" id="cave_level"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_ground_gravel.tres" id="gravel"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock.tres" id="rock"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock_moss.tres" id="moss_rock"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock_red.tres" id="red_rock"]
[ext_resource type="Script" path="res://scripts/shared/terrain_trail.gd" id="trail_script"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_moss_a.res" id="rock_a"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_moss_b.res" id="rock_b"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_moss_c.res" id="rock_c"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_red_a.res" id="rock_red"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/crystal_cluster.res" id="crystal_cluster"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/fern.res" id="fern"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/pk_mushroom.res" id="mushroom"]

[sub_resource type="BoxMesh" id="floor"]
size = Vector3(34, 0.4, 54)

[sub_resource type="BoxShape3D" id="floor_shape"]
size = Vector3(34, 0.4, 54)

[sub_resource type="BoxMesh" id="side_wall"]
size = Vector3(2, 8, 56)

[sub_resource type="BoxShape3D" id="side_wall_shape"]
size = Vector3(2, 8, 56)

[sub_resource type="BoxMesh" id="end_wall"]
size = Vector3(36, 8, 2)

[sub_resource type="BoxShape3D" id="end_wall_shape"]
size = Vector3(36, 8, 2)

[sub_resource type="NavigationMesh" id="nav"]
cell_size = 0.2
cell_height = 0.2
vertices = PackedVector3Array(-16, 0, -25, -16, 0, 25, 16, 0, 25, 16, 0, -25)
polygons = Array[PackedInt32Array]([PackedInt32Array(0, 1, 2, 3)])

[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.012, 0.02, 0.035, 1)
ambient_light_source = 2
ambient_light_color = Color(0.48, 0.58, 0.72, 1)
ambient_light_energy = 0.52
tonemap_mode = 2
ssao_enabled = true
ssao_radius = 1.2
ssao_intensity = 1.25
glow_enabled = false
fog_enabled = true
fog_mode = 1
fog_light_color = Color(0.18, 0.22, 0.3, 1)
fog_density = 0.07
fog_depth_begin = 10.0
fog_depth_end = 42.0
fog_depth_curve = 1.4

[sub_resource type="TorusMesh" id="portal"]
inner_radius = 1.35
outer_radius = 1.75
rings = 16
ring_segments = 8

[sub_resource type="StandardMaterial3D" id="portal_mat"]
albedo_color = Color(0.22, 0.55, 0.8, 1)
emission_enabled = true
emission = Color(0.08, 0.25, 0.5, 1)

[sub_resource type="BoxShape3D" id="portal_shape"]
size = Vector3(6, 5, 3)

[sub_resource type="SphereMesh" id="mouth_mesh"]
radius = 1.0
height = 2.0
radial_segments = 24
rings = 12

[sub_resource type="StandardMaterial3D" id="mouth_mat"]
albedo_color = Color(0.006, 0.01, 0.016, 1)
roughness = 1.0
cull_mode = 2

[sub_resource type="SphereMesh" id="crystal"]
radius = 0.42
height = 1.4
radial_segments = 6
rings = 4

[sub_resource type="StandardMaterial3D" id="crystal_mat"]
albedo_color = Color(0.23, 0.62, 0.92, 1)
emission_enabled = true
emission = Color(0.08, 0.32, 0.7, 1)
roughness = 0.28

[sub_resource type="CylinderMesh" id="stalagmite"]
top_radius = 0.0
bottom_radius = 0.7
height = 3.2
radial_segments = 7

[node name="cave_reino_encoberto" type="Node3D"]
script = ExtResource("cave_level")
map_id = &"cave_reino_encoberto"
floor_number = 1
previous_map = &"enchanted_forest_roots"
previous_spawn = &"CaveReturn"
next_map = &"cave_reino_encoberto_2"
recommended_level = "12–25"

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="CaveFill" type="OmniLight3D" parent="."]
position = Vector3(0, 5, -8)
light_color = Color(0.42, 0.52, 0.72, 1)
light_energy = 1.35
omni_range = 42.0
shadow_enabled = false

[node name="EntranceFill" type="OmniLight3D" parent="."]
position = Vector3(0, 4, 20)
light_color = Color(0.94, 0.61, 0.31, 1)
light_energy = 1.05
omni_range = 20.0
shadow_enabled = false

[node name="DeepFill" type="OmniLight3D" parent="."]
position = Vector3(0, 4, -19)
light_color = Color(0.34, 0.58, 0.95, 1)
light_energy = 1.15
omni_range = 20.0
shadow_enabled = false

[node name="Ground" type="StaticBody3D" parent="."]
position = Vector3(0, -0.2, 0)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("floor")
material_override = ExtResource("gravel")

[node name="Collision" type="CollisionShape3D" parent="Ground"]
shape = SubResource("floor_shape")

[node name="WestWall" type="StaticBody3D" parent="."]
position = Vector3(-17, 4, 0)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="WestWall"]
mesh = SubResource("side_wall")
material_override = ExtResource("rock")

[node name="Collision" type="CollisionShape3D" parent="WestWall"]
shape = SubResource("side_wall_shape")

[node name="EastWall" type="StaticBody3D" parent="."]
position = Vector3(17, 4, 0)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="EastWall"]
mesh = SubResource("side_wall")
material_override = ExtResource("rock")

[node name="Collision" type="CollisionShape3D" parent="EastWall"]
shape = SubResource("side_wall_shape")

[node name="DeepWall" type="StaticBody3D" parent="."]
position = Vector3(0, 4, -27)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="DeepWall"]
mesh = SubResource("end_wall")
material_override = ExtResource("moss_rock")

[node name="Collision" type="CollisionShape3D" parent="DeepWall"]
shape = SubResource("end_wall_shape")

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("nav")

[node name="SpawnPoint" type="Marker3D" parent="."]
position = Vector3(0, 0, 22)

[node name="CaveHowl" type="Marker3D" parent="."]
position = Vector3(0, 0, -19)

[node name="CaveReturn" type="Marker3D" parent="."]
position = Vector3(0, 0, 21)

[node name="Viewpoint1" type="Marker3D" parent="."]
position = Vector3(0, 22, 29)
rotation_degrees = Vector3(-48, 0, 0)

[node name="Decor" type="Node3D" parent="."]

[node name="Trail" type="MeshInstance3D" parent="Decor"]
script = ExtResource("trail_script")
points = PackedVector3Array(0, 0.025, 22, -1, 0.025, 16, -2, 0.025, 10, 1, 0.025, 4, 2, 0.025, -3, -1, 0.025, -10, -2, 0.025, -17, 0, 0.025, -24)
phase = 2.0
half_width = 2.2
soil_tint = Color(0.31, 0.24, 0.18, 1)

[node name="MouthShadow" type="MeshInstance3D" parent="Decor"]
position = Vector3(0, 2.2, 26.3)
scale = Vector3(3.0, 2.0, 0.24)
mesh = SubResource("mouth_mesh")
material_override = SubResource("mouth_mat")

[node name="CrystalWest" type="MeshInstance3D" parent="Decor"]
position = Vector3(-8, 0.0, -15)
scale = Vector3(1.4, 1.6, 1.4)
mesh = ExtResource("crystal_cluster")

[node name="CrystalEast" type="MeshInstance3D" parent="Decor"]
position = Vector3(8, 0.0, -17)
scale = Vector3(1.15, 1.35, 1.15)
mesh = ExtResource("crystal_cluster")

[node name="MossRockWest" type="MeshInstance3D" parent="Decor"]
position = Vector3(-13, 0.0, -7)
rotation_degrees = Vector3(0, 18, 0)
scale = Vector3(3.5, 2.6, 2.4)
mesh = ExtResource("rock_a")

[node name="MossRockEast" type="MeshInstance3D" parent="Decor"]
position = Vector3(13, 0.0, -12)
rotation_degrees = Vector3(0, 203, 0)
scale = Vector3(3.1, 2.8, 2.6)
mesh = ExtResource("rock_b")

[node name="RockAtEntryWest" type="MeshInstance3D" parent="Decor"]
position = Vector3(-10, 0.0, 17)
rotation_degrees = Vector3(0, 44, 0)
scale = Vector3(2.7, 2.1, 2.0)
mesh = ExtResource("rock_c")

[node name="RockAtEntryEast" type="MeshInstance3D" parent="Decor"]
position = Vector3(10, 0.0, 17)
rotation_degrees = Vector3(0, 152, 0)
scale = Vector3(2.6, 2.0, 2.2)
mesh = ExtResource("rock_a")

[node name="RedStone" type="MeshInstance3D" parent="Decor"]
position = Vector3(13, 0.0, 5)
rotation_degrees = Vector3(0, 118, 0)
scale = Vector3(2.1, 1.7, 1.9)
mesh = ExtResource("rock_red")
material_override = ExtResource("red_rock")

[node name="FernWest" type="MeshInstance3D" parent="Decor"]
position = Vector3(-7, 0.0, 8)
rotation_degrees = Vector3(0, 274, 0)
scale = Vector3(1.7, 1.7, 1.7)
mesh = ExtResource("fern")

[node name="FernEast" type="MeshInstance3D" parent="Decor"]
position = Vector3(7, 0.0, 11)
rotation_degrees = Vector3(0, 91, 0)
scale = Vector3(1.5, 1.5, 1.5)
mesh = ExtResource("fern")

[node name="Mushrooms" type="MeshInstance3D" parent="Decor"]
position = Vector3(-10, 0.0, -20)
rotation_degrees = Vector3(0, 36, 0)
scale = Vector3(1.8, 1.8, 1.8)
mesh = ExtResource("mushroom")

[node name="Interactables" type="Node3D" parent="."]

[node name="ReturnPortal" type="Area3D" parent="Interactables"]
position = Vector3(0, 2, 24)
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"cave_return"
metadata/target_id = "m:cave_return"
metadata/interact_type = &"portal"
metadata/target_map = &"enchanted_forest_roots"
metadata/target_spawn = &"CaveReturn"
metadata/recommended_level = "12–25"
metadata/approach_position = Vector3(0, 0, 24)

[node name="Shape" type="CollisionShape3D" parent="Interactables/ReturnPortal"]
shape = SubResource("portal_shape")

[node name="Gate" type="MeshInstance3D" parent="Interactables/ReturnPortal"]
rotation_degrees = Vector3(90, 0, 0)
mesh = SubResource("portal")
material_override = SubResource("portal_mat")

[node name="Name" type="Label3D" parent="Interactables/ReturnPortal"]
position = Vector3(0, 3, 0)
billboard = 1
font_size = 48
pixel_size = 0.015
text = "WA_FOREST_ROOTS"

[node name="Spawns" type="Node3D" parent="."]

[node name="GlowMotes" type="Marker3D" parent="Spawns"]
position = Vector3(-7, 0, 4)
metadata/monster_id = &"enchanted_firefly"
metadata/stage = 1
metadata/count = 3
metadata/radius_cells = 4
metadata/respawn_sec = 70.0
'''
 (GAME/'scenes/maps'/f'{CAVE_MAP_ID}.tscn').write_text(scene)
 zone='''[gd_resource type="Resource" script_class="ZoneDef" format=3]
[ext_resource type="Script" path="res://scripts/shared/data/zone_def.gd" id="zone"]
[resource]
script = ExtResource("zone")
map_id = &"cave_reino_encoberto"
kind = 2
name_key = "WA_CAVE_REINO_ENCOBERTO"
region_id = &"pindorama"
recommended_level_min = 12
recommended_level_max = 16
monster_stage_cap = 1
bosses_allowed = false
connected_maps = Array[StringName]([&"enchanted_forest_roots", &"cave_reino_encoberto_2"])
'''
 (GAME/'data/zones'/f'{CAVE_MAP_ID}.tres').write_text(zone)
 minimap='''<svg xmlns="http://www.w3.org/2000/svg" width="340" height="540" viewBox="0 0 34 54"><rect width="34" height="54" fill="#28313b"/><path d="M2 2h30v50H2z" fill="#35414a" stroke="#84775f" stroke-width="1.2"/><path d="M17 51V37c0-6-8-6-8-12V3M17 37c0-6 8-6 8-12V3" fill="none" stroke="#9c896b" stroke-width="2.8" stroke-linecap="round"/><circle cx="17" cy="37" r="2.3" fill="#66a9d8"/><circle cx="17" cy="11" r="2.3" fill="#d2b77b"/></svg>'''
 (GAME/'assets/minimap'/f'{CAVE_MAP_ID}.svg').write_text(minimap)

def highland_monsters():
 names=['Redemoinho da Chapada','Vaga-lume da Chapada','Tatu da Chapada']
 entries=[]
 for index,mid in enumerate(['prank_whirlwind','enchanted_firefly','stone_armadillo']):
  s=(GAME/'data/monsters'/f'{mid}.tres').read_text()
  s=s.replace(f'id = &"{mid}"',f'id = &"highland_{mid}"\nbase_species = &"{mid}"')  # quests count the variant as the original species
  blocks=re.split(r'(?=\[sub_resource|\[resource\])',s)
  for i,b in enumerate(blocks):
   if 'sprite_base = ' not in b:continue
   st=int(re.search(r'^stage = (\d+)',b,re.M)[1]) if re.search(r'^stage = (\d+)',b,re.M) else 1
   if st>2:continue
   oldlevel=int(re.search(r'^level = (\d+)',b,re.M)[1]); level=(12 if st==1 else 16)+index*2
   b=re.sub(r'^level = \d+',f'level = {level}',b,flags=re.M)
   for stat,power in [('max_hp',1.15),('atk',.7),('matk',.7),('def',.65),('mdef',.65),('xp_reward',1.1)]:
    b=re.sub(r'^'+stat+r' = (\d+)',lambda m:stat+' = '+str(round(int(m[1])*(level/oldlevel)**power)),b,flags=re.M)
   key=f'MON_HIGHLAND_{mid.upper()}_S{st}_NAME'
   b=re.sub(r'^name_key = ".*"',f'name_key = "{key}"',b,flags=re.M)
   if 'aggressive = true' not in b:b+='aggressive = true\n'
   blocks[i]=b
   entries.append([key,names[index]+(' Veterano' if st==2 else '')])
  (GAME/'data/monsters'/f'highland_{mid}.tres').write_text(''.join(blocks))
 wg.csv_set('localization/monsters.csv', entries)  # in place: keeps the file order

if __name__=='__main__':
 for a in AREAS:write_scene(a)
 write_cave_scene()
 highland_monsters()
 from build_pindorama_monsters import build
 build()
 write_names()
 print(f'Built {len(AREAS)} connected hunt maps, zones and minimaps.')
 wg.finish([a['id'] for a in AREAS] + [CAVE_MAP_ID], 'hunt_areas')
