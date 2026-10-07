#!/usr/bin/env python3
"""Build the three Sabiá field hunting maps matching the Ragnarok-style reference:
- Relief & canyon cliffs framing paths, plateaus, and chasms
- Stone bridges crossing ravines and wetlands
- Frontier outpost camp in fields_sabia (canvas tents, fences, campfire, wagon, crates)
- Natural oasis pond in fields_sabia and wetland stream in fields_sabia_buriti (water, reeds, giant mushrooms)
- Savanna cerrado details: termite mounds, golden grass tufts, pequi trees, buriti palms, flowering ipês
- Unified seamless NavigationMesh and full compatibility with test_hunt_areas.
"""
from pathlib import Path
import math
import random
import re
from collections import defaultdict
from build_hunt_areas import AREAS, GAME, write_scene, trail_points, branch_paths, clearings

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

# Altar de Crendice of the Passo dos Ipês (added to the scene by hand on 10/03; kept by the generator).
CROSSROADS_ALTAR_SUB = '[sub_resource type="StandardMaterial3D" id="altar_mat"]\nalbedo_color = Color(0.42, 0.38, 0.3, 1)\nroughness = 0.9\nemission_enabled = true\nemission = Color(0.7, 0.5, 0.15, 1)\nemission_energy_multiplier = 0.4\n\n[sub_resource type="CylinderMesh" id="altar_mesh"]\ntop_radius = 0.9\nbottom_radius = 1.1\nheight = 0.9\nradial_segments = 12\n\n[sub_resource type="CylinderShape3D" id="altar_shape"]\nheight = 1.5\nradius = 1.4\n\n'
CROSSROADS_ALTAR_NODES = '[node name="altar_crendice" type="Area3D" parent="Interactables"]\nposition = Vector3(6, 0.5, 3)\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\nmetadata/interact_id = &"altar_crendice"\nmetadata/target_id = "m:altar_crendice"\nmetadata/interact_type = &"altar_crendice"\nmetadata/approach_position = Vector3(6, 0, 4.5)\n\n[node name="Shape" type="CollisionShape3D" parent="Interactables/altar_crendice"]\nshape = SubResource("altar_shape")\n\n[node name="Mesh" type="MeshInstance3D" parent="Interactables/altar_crendice"]\nmesh = SubResource("altar_mesh")\nmaterial_override = SubResource("altar_mat")\n\n[node name="Name" type="Label3D" parent="Interactables/altar_crendice"]\nposition = Vector3(0, 1.6, 0)\nbillboard = 1\nfont_size = 40\npixel_size = 0.015\ntext = "Altar de Crendice"\nmodulate = Color(1, 0.88, 0.45, 1)\n\n'


def add_crossroads_altar(source: str) -> str:
    if 'id="altar_mat"' in source:
        return source
    env = '[sub_resource type="Environment" id="env"]'
    spawns = '[node name="Spawns" type="Node3D" parent="."]'
    assert env in source and spawns in source, "fields_sabia_crossroads layout changed: place the altar again"
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
    if map_id == 'fields_sabia':
        # Outpost camp around Coronel Tobias (14, 9)
        paths.append([(0, 14), (6, 12), (14, 9)])
        rooms.append((14, 9, 8.5))
        # Oasis pond clearing on east
        rooms.append((18, -14, 7.5))
        paths.append([(0, -10), (10, -12), (18, -14)])
        # Bridge path connecting western clearing (-18, 17) to center (0, 16)
        paths.append([(-18, 17), (-8, 16), (0, 16)])
    elif map_id == 'fields_sabia_buriti':
        # Buriti wetland basin on west
        rooms.append((-16, 2, 8.5))
        paths.append([(0, 2), (-8, 2), (-16, 2)])
        # Bridge crossing over the wetland stream
        paths.append([(-6, 4), (-2, 4), (4, 4)])
        # Eastern plateau clearing
        rooms.append((18, 8, 7.0))
        paths.append([(0, 8), (10, 8), (18, 8)])
    elif map_id == 'fields_sabia_crossroads':
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

    # Common painted meshes
    palette_meshes = [
        ('fld_rock_red', 'res://assets/environment/painted/meshes/rock_red_a.res'),
        ('fld_rock_moss', 'res://assets/environment/painted/meshes/rock_moss_a.res'),
        ('fld_rock_sand', 'res://assets/environment/painted/meshes/pk_rock_sand.res'),
        ('fld_rock_1', 'res://assets/environment/painted/meshes/pk_rock_1.res'),
        ('fld_grass_gold', 'res://assets/environment/painted/meshes/grass_golden.res'),
        ('fld_grass_tuft', 'res://assets/environment/painted/meshes/grass_tuft.res'),
        ('fld_termite', 'res://assets/environment/painted/meshes/termite_mound_a.res'),
        ('fld_bush_dry', 'res://assets/environment/painted/meshes/bush_dry_a.res'),
        ('fld_bush_low', 'res://assets/environment/painted/meshes/bush_low_b.res'),
        ('fld_reeds', 'res://assets/environment/painted/meshes/reeds.res'),
        ('fld_mushroom', 'res://assets/environment/painted/meshes/pk_mushroom.res'),
        ('fld_log', 'res://assets/environment/painted/meshes/prop_log.res'),
        ('fld_stump', 'res://assets/environment/painted/meshes/prop_stump.res'),
        ('fld_bridge', 'res://assets/environment/painted/meshes/vg_stone_bridge.res'),
    ]

    # Map-specific trees
    if map_id == 'fields_sabia':
        palette_meshes += [
            ('fld_tree_pequi', 'res://assets/environment/painted/meshes/tree_pequi_a.res'),
            ('fld_tree_ipe_y', 'res://assets/environment/painted/meshes/tree_ipe_yellow_a.res'),
            ('fld_tent_a', 'res://assets/environment/painted/meshes/camp_tent_v2_a.res'),
            ('fld_tent_b', 'res://assets/environment/painted/meshes/lm_camp_tent_a.res'),
            ('fld_fire', 'res://assets/environment/painted/meshes/camp_fire_v2.res'),
            ('fld_well', 'res://assets/environment/painted/meshes/camp_well.res'),
            ('fld_fence', 'res://assets/environment/painted/meshes/prop_fence.res'),
            ('fld_fence_single', 'res://assets/environment/painted/meshes/pkv_prop_woodenfence_single.res'),
            ('fld_wagon', 'res://assets/environment/painted/meshes/pkv_prop_wagon.res'),
            ('fld_crate', 'res://assets/environment/painted/meshes/prop_crate.res'),
            ('fld_barrel', 'res://assets/environment/painted/meshes/pk_barrel.res'),
            ('fld_flagstone', 'res://assets/environment/painted/meshes/pk_rockpath_square_wide.res'),
        ]
    elif map_id == 'fields_sabia_buriti':
        palette_meshes += [
            ('fld_palm_buriti', 'res://assets/environment/painted/meshes/palm_buriti_a.res'),
            ('fld_buriti_soft', 'res://assets/environment/painted/meshes/buriti_soft_a.res'),
            ('fld_tree_ipe_y', 'res://assets/environment/painted/meshes/tree_ipe_yellow_a.res'),
            ('fld_crate', 'res://assets/environment/painted/meshes/prop_crate.res'),
            ('fld_barrel', 'res://assets/environment/painted/meshes/pk_barrel.res'),
            ('fld_signpost', 'res://assets/environment/painted/meshes/camp_signpost.res'),
        ]
    elif map_id == 'fields_sabia_crossroads':
        palette_meshes += [
            ('fld_tree_ipe_y', 'res://assets/environment/painted/meshes/tree_ipe_yellow_a.res'),
            ('fld_tree_ipe_p', 'res://assets/environment/painted/meshes/tree_ipe_purple_a.res'),
            ('fld_tree_pequi', 'res://assets/environment/painted/meshes/tree_pequi_a.res'),
            ('fld_standing_stones', 'res://assets/environment/painted/meshes/vg_standing_stones.res'),
            ('fld_petals', 'res://assets/environment/painted/meshes/pk_petals_1.res'),
            ('fld_signpost', 'res://assets/environment/painted/meshes/camp_signpost.res'),
        ]

    for ident, mpath in palette_meshes:
        ext_res(mpath, ident)

    # Water material & mesh for ponds/wetlands
    resources.append('[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_water.tres" id="fld_water_mat"]')

    rng = random.Random(901 + variant)
    groups = defaultdict(list)

    def place_mm(ident, x, z, scale, y=0.0):
        angle = rng.uniform(0, math.tau)
        c = math.cos(angle) * scale
        s = math.sin(angle) * scale
        groups[ident].extend([c, 0, s, x, 0, scale * rng.uniform(0.92, 1.12), 0, y, -s, 0, c, z])

    def in_nav(x, z, margin=0.0):
        return any((math.floor((x + dx) / 2) * 2, math.floor((z + dz) / 2) * 2) in cells
                   for dx, dz in [(0, 0), (margin, 0), (-margin, 0), (0, margin), (0, -margin)])

    # 1. Canyon boundary cliffs (Image 1) - create actual 3D relief walls along unnavigable borders
    for x in range(-48, 49, 4):
        for z in range(-48, 49, 4):
            px = x + rng.uniform(-1.2, 1.2)
            pz = z + rng.uniform(-1.2, 1.2)
            # Boundary walls around perimeter and internal divides
            if not in_nav(px, pz, 2.2):
                rock_mesh = rng.choice(['fld_rock_red', 'fld_rock_sand', 'fld_rock_1'])
                rscale = rng.uniform(2.2, 3.8)
                ry = rng.uniform(-0.5, 0.2)
                place_mm(rock_mesh, px, pz, rscale, ry)

    # 2. Savanna trees outside paths
    tree_choices = ['fld_tree_pequi', 'fld_tree_ipe_y'] if map_id == 'fields_sabia' else (
        ['fld_palm_buriti', 'fld_buriti_soft'] if map_id == 'fields_sabia_buriti' else
        ['fld_tree_ipe_y', 'fld_tree_ipe_p', 'fld_tree_pequi']
    )
    for x in range(-44, 45, 6):
        for z in range(-44, 45, 6):
            px = x + rng.uniform(-1.8, 1.8)
            pz = z + rng.uniform(-1.8, 1.8)
            if not in_nav(px, pz, 2.0):
                tmesh = rng.choice(tree_choices)
                place_mm(tmesh, px, pz, rng.uniform(0.9, 1.35))

    # 3. Termite mounds in clearings (Image 4)
    termite_locs = [
        (12, 18), (-14, -18), (-20, 4), (18, -22), (4, -18)
    ]
    for tx, tz in termite_locs:
        if in_nav(tx, tz):
            place_mm('fld_termite', tx + rng.uniform(-1, 1), tz + rng.uniform(-1, 1), rng.uniform(1.0, 1.4))

    # 4. Dense golden grass, low dry shrubs along trail edges (Image 4)
    for _ in range(1800):
        x, z = rng.uniform(-44, 44), rng.uniform(-44, 44)
        dist = min((x - px)**2 + (z - pz)**2 for px, pz in samples)
        if dist < 2.0**2:
            continue  # Keep path center clear for comfortable walking
        if in_nav(x, z, 0.8):
            # Edge of paths and clearings
            gmesh = rng.choice(['fld_grass_gold', 'fld_grass_tuft', 'fld_bush_low'])
            place_mm(gmesh, x, z, rng.uniform(0.7, 1.3))
        else:
            # Rocky slopes
            rmesh = rng.choice(['fld_bush_dry', 'fld_rock_moss', 'fld_log', 'fld_stump'])
            place_mm(rmesh, x, z, rng.uniform(0.8, 1.4))

    # Add MultiMesh nodes
    for ident, buffer in groups.items():
        res('MultiMesh', f'mm_{ident}', f'transform_format = 1\nmesh = ExtResource("{ident}")\ninstance_count = {len(buffer)//12}\nbuffer = PackedFloat32Array(' + ', '.join(f'{v:.4f}' for v in buffer) + ')')
        node(f'Multi_{ident}', 'MultiMeshInstance3D', f'multimesh = SubResource("mm_{ident}")')

    # Specific Map Features
    if map_id == 'fields_sabia':
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

    elif map_id == 'fields_sabia_buriti':
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

    elif map_id == 'fields_sabia_crossroads':
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
    if map_id == 'fields_sabia_crossroads':
        source = add_crossroads_altar(source)
    source = re.sub(r'load_steps=\d+', f'load_steps={1 + source.count("[ext_resource") + source.count("[sub_resource")}', source, count=1)
    path.write_text(source, encoding='utf-8')

    # Update zone file
    zone = GAME / 'data/zones' / f'{map_id}.tres'
    if zone.exists():
        text = zone.read_text(encoding='utf-8')
        text = re.sub(r'^.*(?:id="minimap"|minimap_texture =|minimap_world_rect =).*\n', '', text, flags=re.M)
        zone.write_text(text, encoding='utf-8')

    print(f"{map_id}: {len(cells)} walk cells, {sum(len(v)//12 for v in groups.values())} MultiMesh instances placed.")


def main():
    for area in AREAS:
        if area.get('scenery') == 'fields':
            build(area)
    print("All Sabiá Fields reformed successfully.")
    wg.finish([a['id'] for a in AREAS if a.get('scenery') == 'fields'], 'fields')


if __name__ == '__main__':
    main()
