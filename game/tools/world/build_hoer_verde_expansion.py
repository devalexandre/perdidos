#!/usr/bin/env python3
"""
build_hoer_verde_expansion.py
Expands Nação Sabiá with:
1. City 3: Arraial do Sumidouro (city_sumidouro)
2. Approach Region: Charneca da Névoa (3 maps: fog_moor_trail, fog_moor_swamp, fog_moor_gate)
3. Dungeon 5: Vilarejo de Hoer Verde (4 floors: hoer_verde_1 .. hoer_verde_4)
4. Thematic Monsters (4 stages each):
   - whispering_shade (Vultos Sussurrantes)
   - despair_possessed (Possuídos pela Desesperança)
   - silence_crier (O Pregoeiro do Silêncio - Boss)
5. Exclusive Gear & Drops (exclusive_drop_zone = &"hoer_verde", buy_price = 0)
"""

import csv
import io
import math
from pathlib import Path
from PIL import Image

import worldgen as wg

## Keeps the published floor plans: corridors to portals/markers/lairs were aimed at (x, y) instead
## of (x, z). New maps should use False (corridors to the real position).
LEGACY_ROUTES = True

PROJECT_DIR = Path(__file__).resolve().parents[3]
GAME_DIR = PROJECT_DIR / "game"

# ---------------------------------------------------------------------------
# Visual Sprite Helper (tint and save)
# ---------------------------------------------------------------------------
def tint_and_save(src_path: Path, dst_path: Path, tint_rgb: tuple, factor: float):
    if not src_path.exists():
        return
    img = Image.open(src_path).convert("RGBA")
    r, g, b, a = img.split()
    overlay = Image.new("RGB", img.size, tint_rgb)
    tinted_rgb = Image.blend(img.convert("RGB"), overlay, factor)
    tr, tg, tb = tinted_rgb.split()
    final_img = Image.merge("RGBA", (tr, tg, tb, a))
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    wg.save_image(final_img, dst_path)


# ---------------------------------------------------------------------------
# Monster Definitions
# ---------------------------------------------------------------------------
HOER_SPECIES_DATA = [
    (
        "whispering_shade",
        ["Vulto Sussurrante", "Espectro da Bruma", "Alma Penada dos Campos", "Vulto Sussurrante Atroz"],
        "residuo_espectral",
        [36, 41, 47, 52],
        "ranged",
        "cave_skeleton",
        [((90, 110, 140), 0.75), ((70, 90, 130), 0.8), ((50, 70, 120), 0.85), ((40, 50, 100), 0.9)],
        [1.0, 1.25, 1.55, 1.85],
    ),
    (
        "despair_possessed",
        ["Errante da Desesperança", "Possuído da Charneca", "Fanático das Névoas", "Possuído Atroz"],
        "cinzas_do_desespero",
        [37, 42, 48, 53],
        "melee",
        "cave_zombie",
        [((75, 95, 80), 0.75), ((65, 85, 70), 0.8), ((50, 75, 60), 0.85), ((35, 60, 45), 0.9)],
        [1.05, 1.3, 1.6, 1.9],
    ),
    (
        "silence_crier",
        ["Coveiro do Silêncio", "Vigia da Névoa", "O Pregoeiro do Silêncio", "Pregoeiro Atroz do Sino"],
        "badalo_de_ferro_funebre",
        [40, 46, 52, 58],
        "boss",
        "werewolf",
        [((40, 45, 60), 0.8), ((30, 35, 50), 0.85), ((25, 25, 40), 0.9), ((15, 15, 30), 0.95)],
        [1.3, 1.6, 1.95, 2.35],
    ),
]


def build_hoer_monsters():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"
    monsters_dir = GAME_DIR / "data/monsters"
    monsters_dir.mkdir(parents=True, exist_ok=True)
    translations = []

    for index, (mid, names, primary_drop, levels, behavior, src_mid, tints, scales) in enumerate(HOER_SPECIES_DATA):
        dest_dir = mon_assets_dir / mid
        dest_dir.mkdir(parents=True, exist_ok=True)
        src_dir = mon_assets_dir / src_mid

        # Sprites
        for st in range(1, 5):
            tint_color, tint_factor = tints[st - 1]
            for anim in anims:
                src_candidates = [
                    src_dir / f"mon_{src_mid}_s{st}_{anim}.png",
                    src_dir / f"mon_{src_mid}_s{min(st, 2)}_{anim}.png",
                    src_dir / f"mon_{src_mid}_s1_{anim}.png",
                ]
                src_file = None
                for c in src_candidates:
                    if c.exists():
                        src_file = c
                        break
                if src_file is None:
                    continue
                dest_file = dest_dir / f"mon_{mid}_s{st}_{anim}.png"
                tint_and_save(src_file, dest_file, tint_color, tint_factor)

        # Resource .tres
        parts = [
            '[gd_resource type="Resource" script_class="MonsterDef" format=3]',
            "",
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="mdef"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/drop_entry.gd" id="drop"]',
        ]

        stage_subresource_refs = []
        for st in range(1, 5):
            stage_subresource_refs.append(f'SubResource("stage{st}")')
            name = names[st - 1]
            key = f"MON_{mid.upper()}_S{st}_NAME"
            translations.append((key, name))

            level = levels[st - 1]
            hp = int(1200 + level * 75 + (index * 200)) * (8 if st == 3 else 14 if st == 4 else 1)
            atk = int(52 + level * 2.8) * (2 if st >= 3 else 1)
            defense = int(24 + level * 1.3)
            mdef = int(22 + level * 1.5)
            walk_ms = 460 if st == 4 else 500 if st == 3 else 560
            atk_interval = 1000 if st == 4 else 1200 if st == 3 else 1400
            boss = st >= 3

            st_behaviors = []
            if behavior == "ranged":
                st_behaviors.append('&"ranged"')
            if boss:
                st_behaviors.append('&"boss"')

            behaviors_str = f"Array[StringName]([{', '.join(st_behaviors)}])" if st_behaviors else "Array[StringName]([])"

            drop_subresources = [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]\nscript = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {1.0 if boss else 0.45}\nmin_qty = {2 if boss else 1}\nmax_qty = {5 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_cloth_{st}"]\nscript = ExtResource("drop")\nitem_id = &"tecido_fantasmagorico"\nchance = {0.8 if boss else 0.3}\nmin_qty = 1\nmax_qty = 3',
                f'[sub_resource type="Resource" id="drop_mist_{st}"]\nscript = ExtResource("drop")\nitem_id = &"essencia_da_nevoa_densa"\nchance = {0.7 if boss else 0.2}\nmin_qty = 1\nmax_qty = 2',
            ]
            drops_list = [f'SubResource("drop_mat_{st}")', f'SubResource("drop_cloth_{st}")', f'SubResource("drop_mist_{st}")']

            if mid == "silence_crier" and boss:
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_lenco_{st}"]\nscript = ExtResource("drop")\nitem_id = &"lenco_do_pregoeiro"\nchance = {0.06 if st == 3 else 0.14}\nmin_qty = 1\nmax_qty = 1'
                )
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_scythe_{st}"]\nscript = ExtResource("drop")\nitem_id = &"foice_da_colheita_sombria"\nchance = {0.22 if st == 3 else 0.38}\nmin_qty = 1\nmax_qty = 1'
                )
                drops_list.append(f'SubResource("drop_lenco_{st}")')
                drops_list.append(f'SubResource("drop_scythe_{st}")')

            parts.extend(drop_subresources)
            parts.append(
                f"""[sub_resource type="Resource" id="stage{st}"]
script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {scales[st - 1]}
level = {level}
max_hp = {hp}
atk = {atk}
matk = {atk if behavior == "ranged" else 0}
def = {defense}
mdef = {mdef}
walk_ms_per_cell = {walk_ms}
attack_range_cells = {4.5 if behavior == "ranged" else 2.2 if boss else 1.5}
attack_interval_ms = {atk_interval}
aggressive = {str(st > 1).lower()}
aggro_range_cells = {9 if st == 4 else 7 if boss else 5}
leash_cells = {20 if st == 4 else 16 if boss else 12}
xp_reward = {(2200 + index * 180) * (2 if st == 4 else 1) if boss else level * 18}
stars_min = {180 if st == 4 else 90 if boss else max(2, level // 2)}
stars_max = {360 if st == 4 else 180 if boss else level + 8}
behaviors = {behaviors_str}
drops = Array[ExtResource("drop")]([{", ".join(drops_list)}])"""
            )

        parts.append(
            f"""[resource]
script = ExtResource("mdef")
id = &"{mid}"
name_key = "{translations[0][0]}"
stages = Array[ExtResource("stage")]([{", ".join(stage_subresource_refs)}])
"""
        )

        res_path = monsters_dir / f"{mid}.tres"
        wg.write_text(res_path, "\n".join(parts))

    # Update monsters.csv
    wg.csv_add("localization/monsters.csv", translations)
    print("Hoer Verde monsters successfully built.")


# ---------------------------------------------------------------------------
# Map Generator Engine (Matches Ratanabá / Z generator)
# ---------------------------------------------------------------------------
def dist_segment(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx = bx - ax
    dy = by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    proj_x = ax + t * dx
    proj_y = ay + t * dy
    return math.hypot(px - proj_x, py - proj_y)


def generate_map_scene(
    map_id: str,
    rooms: list,
    routes: list,
    width: float,
    pillars: list,
    spawn_pos: tuple,
    portals: list,
    spawns: list,
    boss_lairs: list = None,
    npc_points: list = None,
    altar_pos: tuple = None,
    ground_mat: str = "res://assets/environment/painted/materials/mat_ground_gravel.tres",
    env_light_color: str = "Color(0.65, 0.70, 0.85, 1)",
    env_light_energy: float = 0.85,
    extra_markers: dict = None,
):
    boss_lairs = boss_lairs or []
    npc_points = npc_points or []
    extra_markers = extra_markers or {}

    routes = [list(r) for r in routes]
    wg.require_res(ground_mat, f"{map_id}: ground material")
    # Positions are (x, y, z); the floor plan is (x, z). The published maps were built with the
    # corridors aimed at (x, y) (LEGACY_ROUTES); every target is then joined by ensure_connected().
    rz = 1 if LEGACY_ROUTES else 2
    nearest_spawn_rm = min(rooms, key=lambda r: math.hypot(spawn_pos[0] - r[0], spawn_pos[rz] - r[1]))
    routes.append([(nearest_spawn_rm[0], nearest_spawn_rm[1]), (spawn_pos[0], spawn_pos[rz])])

    for p in portals:
        pos = (p["pos"][0], p["pos"][rz])
        nearest_p_rm = min(rooms, key=lambda r: math.hypot(pos[0] - r[0], pos[1] - r[1]))
        routes.append([(nearest_p_rm[0], nearest_p_rm[1]), pos])

    for mpos in extra_markers.values():
        nearest_m_rm = min(rooms, key=lambda r: math.hypot(mpos[0] - r[0], mpos[rz] - r[1]))
        routes.append([(nearest_m_rm[0], nearest_m_rm[1]), (mpos[0], mpos[rz])])

    for bl in boss_lairs:
        blpos = (bl["pos"][0], bl["pos"][rz])
        nearest_bl_rm = min(rooms, key=lambda r: math.hypot(blpos[0] - r[0], blpos[1] - r[1]))
        routes.append([(nearest_bl_rm[0], nearest_bl_rm[1]), blpos])

    cells = set()
    for x in range(-56, 56, 2):
        for z in range(-56, 56, 2):
            p = (x + 1, z + 1)
            in_room = any(math.hypot(p[0] - cx, p[1] - cz) < r for cx, cz, r in rooms)
            in_corridor = any(dist_segment(p, a, b) < width for route in routes for a, b in zip(route, route[1:]))
            if in_room or in_corridor:
                cells.add((x, z))

    cells = {p for p in cells if all(math.hypot(p[0] + 1 - px, p[1] + 1 - pz) > 3.2 for px, pz in pillars)}

    def blocked(c):
        return any(math.hypot(c[0] + 1 - px, c[1] + 1 - pz) <= 3.2 for px, pz in pillars)

    for sp in spawns:
        if sp.get("stage", 1) >= 3:
            raise wg.WorldGenError(f"{map_id} {sp.get('name')}: stage {sp['stage']} only in boss_lairs")
    for p in portals:
        if p.get("is_escape") and not boss_lairs:
            raise wg.WorldGenError(f"{map_id} {p['name']}: escape portal needs a boss lair on the map")
    targets = [(p["pos"][0], p["pos"][2]) for p in portals]
    targets += [(v[0], v[2]) for v in extra_markers.values()]
    targets += [(b["pos"][0], b["pos"][2]) for b in boss_lairs]
    targets += [(n["pos"][0], n["pos"][2]) for n in npc_points]
    if altar_pos:
        targets.append((altar_pos[0], altar_pos[2] + 2.0))
    wg.ensure_connected(cells, (spawn_pos[0], spawn_pos[2]), targets, blocked=blocked, label=map_id)
    # Packs go to the nearest walkable spot (with room around it) that the SpawnPoint reaches.
    reach = wg.component(cells, wg.cell_of(spawn_pos[0], spawn_pos[2]))
    snapped = []
    for sidx, sp in enumerate(spawns):
        x, z = wg.snap_to_walkable(reach, sp["pos"][0], sp["pos"][2], label=f"{map_id} {sp.get('name', sidx)}")
        snapped.append(dict(sp, pos=(x, sp["pos"][1], z)))
    spawns = snapped

    resources = []
    nodes = []

    def res(kind, key, body):
        resources.append(f'[sub_resource type="{kind}" id="{key}"]\n{body}\n')

    def node(name, kind, parent=".", body=""):
        p_attr = f' parent="{parent}"' if parent else ""
        nodes.append(f'[node name="{name}" type="{kind}"{p_attr}]\n{body}\n')

    # Environment
    res(
        "ProceduralSkyMaterial",
        "sky_mat",
        """sky_top_color = Color(0.12, 0.16, 0.22, 1)
sky_horizon_color = Color(0.24, 0.28, 0.35, 1)
ground_bottom_color = Color(0.08, 0.10, 0.14, 1)
ground_horizon_color = Color(0.24, 0.28, 0.35, 1)""",
    )
    res(
        "Sky",
        "sky",
        """sky_material = SubResource("sky_mat")""",
    )
    res(
        "Environment",
        "env",
        f"""background_mode = 2
sky = SubResource("sky")
ambient_light_source = 2
ambient_light_color = {env_light_color}
ambient_light_energy = {env_light_energy}
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.35, 0.40, 0.48, 1)
fog_density = 0.015""",
    )

    res(
        "NavigationMesh",
        "navmesh",
        wg.navmesh_body(cells, "agent_height = 1.8\nagent_radius = 0.5"),
    )

    res("BoxShape3D", "portal_shape", "size = Vector3(4, 3, 4)")
    res("CylinderMesh", "pillar_mesh", "top_radius = 1.8\nbottom_radius = 2.0\nheight = 7.0")
    res("CylinderShape3D", "pillar_col", "height = 7.0\nradius = 2.0")

    # Floor run generation
    runs = []
    for z in sorted(list({c[1] for c in cells})):
        xs = sorted([c[0] for c in cells if c[1] == z])
        if not xs:
            continue
        start_x = xs[0]
        prev_x = xs[0]
        for cur_x in xs[1:]:
            if cur_x == prev_x + 2:
                prev_x = cur_x
            else:
                length = (prev_x - start_x) + 2
                mid_x = start_x + length / 2.0
                runs.append((mid_x, z + 1.0, length, 2.0))
                start_x = cur_x
                prev_x = cur_x
        length = (prev_x - start_x) + 2
        mid_x = start_x + length / 2.0
        runs.append((mid_x, z + 1.0, length, 2.0))

    for idx, (mx, mz, lx, lz) in enumerate(runs):
        res("BoxMesh", f"floor_{idx}", f"size = Vector3({lx:.1f}, 3.0, {lz:.1f})")
        res("BoxShape3D", f"floor_col_{idx}", f"size = Vector3({lx:.1f}, 3.0, {lz:.1f})")

    node(map_id, "Node3D", parent="", body=f'script = ExtResource("map")\nmap_id = &"{map_id}"')
    node("WorldEnvironment", "WorldEnvironment", body='environment = SubResource("env")')
    node(
        "DirectionalLight3D",
        "DirectionalLight3D",
        body=f"""transform = Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 20, 0)
light_color = {env_light_color}
light_energy = {env_light_energy}
shadow_enabled = true""",
    )
    node("NavigationRegion3D", "NavigationRegion3D", body='navigation_mesh = SubResource("navmesh")')
    node("Floor", "Node3D")
    node("Interactables", "Node3D")
    node("Spawns", "Node3D")
    node("NpcPoints", "Node3D")
    if boss_lairs:
        node("BossLairs", "Node3D")

    node("SpawnPoint", "Marker3D", body=f"position = Vector3({spawn_pos[0]}, {spawn_pos[1]}, {spawn_pos[2]})")

    for mname, mpos in extra_markers.items():
        node(mname, "Marker3D", body=f"position = Vector3({mpos[0]}, {mpos[1]}, {mpos[2]})")

    # Floor nodes
    for idx, (mx, mz, lx, lz) in enumerate(runs):
        node(f"floor_{idx}", "StaticBody3D", parent="Floor", body=f"position = Vector3({mx:.1f}, -1.5, {mz:.1f})\ncollision_layer = 1\ncollision_mask = 0")
        node(
            "Surface",
            "MeshInstance3D",
            parent=f"Floor/floor_{idx}",
            body=f'mesh = SubResource("floor_{idx}")\nsurface_material_override/0 = ExtResource("ground_mat")',
        )
        node("Col", "CollisionShape3D", parent=f"Floor/floor_{idx}", body=f'shape = SubResource("floor_col_{idx}")')

    # Pillars
    for pidx, (px, pz) in enumerate(pillars):
        node(f"pillar_{pidx}", "StaticBody3D", body=f"position = Vector3({px}, 2.0, {pz})\ncollision_layer = 1\ncollision_mask = 0")
        node("Mesh", "MeshInstance3D", parent=f"pillar_{pidx}", body='mesh = SubResource("pillar_mesh")')
        node("Col", "CollisionShape3D", parent=f"pillar_{pidx}", body='shape = SubResource("pillar_col")')

    # Portals
    for p in portals:
        pname = p["name"]
        pos = p["pos"]
        target_map = p["target_map"]
        target_spawn = p.get("target_spawn", "SpawnPoint")
        label = p.get("label", target_map)
        is_escape = p.get("is_escape", False)
        requires_boss = p.get("requires_boss", False) or is_escape
        iid = p.get("interact_id") or wg.portal_id(map_id, pname)

        body = f"""position = Vector3({pos[0]}, {pos[1]}, {pos[2]})
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"{iid}"
metadata/target_id = "m:{iid}"
metadata/interact_type = &"portal"
metadata/target_map = &"{target_map}"
metadata/target_spawn = &"{target_spawn}"
metadata/approach_position = Vector3({pos[0]}, {pos[1] - 1.0 if pos[1] > 0 else 0.0}, {pos[2]})
metadata/one_way = {str(is_escape).lower()}
metadata/requires_boss_victory = {str(requires_boss).lower()}"""
        node(pname, "Area3D", parent="Interactables", body=body)
        node("Shape", "CollisionShape3D", parent=f"Interactables/{pname}", body='shape = SubResource("portal_shape")')
        node("Name", "Label3D", parent=f"Interactables/{pname}", body=f'position = Vector3(0, 3, 0)\nbillboard = 1\nfont_size = 42\npixel_size = 0.015\ntext = "{label}"')

    # Spawns
    for sidx, sp in enumerate(spawns):
        sname = sp.get("name", f"Pack{sidx + 1}")
        pos = sp["pos"]
        body = f"""position = Vector3({pos[0]}, {pos[1]}, {pos[2]})
metadata/monster_id = &"{sp['mid']}"
metadata/stage = {sp.get('stage', 1)}
metadata/count = {sp.get('count', 3)}
metadata/radius_cells = {sp.get('radius_cells', 4)}
metadata/respawn_sec = {sp.get('respawn_sec', 90.0)}"""
        node(sname, "Marker3D", parent="Spawns", body=body)

    # Boss Lairs
    for bl in boss_lairs:
        bname = bl["name"]
        pos = bl["pos"]
        body = f"""position = Vector3({pos[0]}, {pos[1]}, {pos[2]})
metadata/monster_id = &"{bl['mid']}"
metadata/radius_cells = {bl.get('radius_cells', 8)}
metadata/respawn_sec = {bl.get('respawn_sec', 600.0)}"""
        node(bname, "Marker3D", parent="BossLairs", body=body)

    # NPCs
    for npc in npc_points:
        nname = npc["id"]
        pos = npc["pos"]
        body = f"""position = Vector3({pos[0]}, {pos[1]}, {pos[2]})
metadata/npc_id = &"{nname}"
metadata/interact_id = &"npc:{nname}"
metadata/interact_type = &"npc"
metadata/dialogue_id = &"dlg_{nname}"
metadata/facing_angle = {npc.get('facing', 0.0)}"""
        body += "".join(f"\n{line}" for line in npc.get("meta", []))
        node(nname, "Marker3D", parent="NpcPoints", body=body)

    # Altar
    if altar_pos:
        node(
            "altar_crendice",
            "Marker3D",
            parent="Interactables",
            body=f"""position = Vector3({altar_pos[0]}, {altar_pos[1]}, {altar_pos[2]})
metadata/interact_id = &"altar_crendice"
metadata/target_id = "m:altar_crendice"
metadata/interact_type = &"altar"
metadata/crendice_action = &"consecrate"
metadata/approach_position = Vector3({altar_pos[0]}, 0, {altar_pos[2] + 2.0})""",
        )

    ext_res_lines = [
        f'[ext_resource type="Material" path="{ground_mat}" id="ground_mat"]',
        f'[ext_resource type="Script" path="{wg.MAP_SCRIPT}" id="map"]',
    ]

    header = f"""[gd_scene load_steps={len(resources) + len(ext_res_lines) + 1} format=3]

{chr(10).join(ext_res_lines)}

{chr(10).join(resources)}
"""
    full_tscn = header + "\n" + "\n".join(nodes)

    out_path = GAME_DIR / f"scenes/maps/{map_id}.tscn"
    wg.write_text(out_path, full_tscn)
    print(f"Scene {map_id}.tscn generated with {len(cells)} walkable tiles, {len(runs)} floor runs.")


def write_zone_def(map_id: str, name_key: str, min_lvl: int, max_lvl: int, connected_maps: list, kind: int = 2, combat: bool = True, boss_allowed: bool = False, stage_cap: int = 2):
    conn_str = ", ".join([f'&"{m}"' for m in connected_maps])
    content = f"""[gd_resource type="Resource" script_class="ZoneDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/zone_def.gd" id="zone"]

[resource]
script = ExtResource("zone")
map_id = &"{map_id}"
kind = {kind}
name_key = "{name_key}"
region_id = &"sabia"
recommended_level_min = {min_lvl}
recommended_level_max = {max_lvl}
combat_allowed = {str(combat).lower()}
grave_on_death = {str(combat).lower()}
monster_stage_cap = {stage_cap}
bosses_allowed = {str(boss_allowed).lower()}
connected_maps = Array[StringName]([{conn_str}])
"""
    p = GAME_DIR / f"data/zones/{map_id}.tres"
    wg.write_text(p, content)
    print(f"ZoneDef {map_id}.tres written.")


# ---------------------------------------------------------------------------
# Exclusive Items
# ---------------------------------------------------------------------------
HOER_EXCLUSIVE_ITEMS = [
    {
        "id": "capuz_da_bruma_espectral",
        "name_key": "ITEM_CAPUZ_BRUMA_ESPECTRAL_NAME",
        "desc_key": "ITEM_CAPUZ_BRUMA_ESPECTRAL_DESC",
        "icon": "res://assets/items/icons/icon_item_straw_hat.png",
        "type": 3,  # HEAD
        "rarity": 2,  # RARE
        "sell_price": 380,
        "stats": {"def": 16, "mdef": 22, "spi": 6},
        "exclusive": "hoer_verde",
    },
    {
        "id": "manto_dos_desesperados",
        "name_key": "ITEM_MANTO_DESESPERADOS_NAME",
        "desc_key": "ITEM_MANTO_DESESPERADOS_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_jerkin.png",
        "type": 4,  # BODY
        "rarity": 2,  # RARE
        "sell_price": 520,
        "stats": {"def": 38, "mdef": 28, "vit": 6, "spi": 4},
        "exclusive": "hoer_verde",
    },
    {
        "id": "luvas_do_toque_gelido",
        "name_key": "ITEM_LUVAS_TOQUE_GELIDO_NAME",
        "desc_key": "ITEM_LUVAS_TOQUE_GELIDO_DESC",
        "icon": "res://assets/items/icons/icon_item_ribbon_bracelet.png",
        "type": 8,  # GLOVES
        "rarity": 2,  # RARE
        "sell_price": 320,
        "stats": {"def": 14, "matk": 18, "int": 5},
        "exclusive": "hoer_verde",
    },
    {
        "id": "botas_do_passo_silencioso",
        "name_key": "ITEM_BOTAS_PASSO_SILENCIOSO_NAME",
        "desc_key": "ITEM_BOTAS_PASSO_SILENCIOSO_DESC",
        "icon": "res://assets/items/icons/icon_item_walking_boots.png",
        "type": 5,  # FEET
        "rarity": 2,  # RARE
        "sell_price": 300,
        "stats": {"def": 12, "mdef": 16, "agi": 6},
        "exclusive": "hoer_verde",
    },
    {
        "id": "escudo_do_lamento_eterno",
        "name_key": "ITEM_ESCUDO_LAMENTO_ETERNO_NAME",
        "desc_key": "ITEM_ESCUDO_LAMENTO_ETERNO_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_shield.png",
        "type": 2,  # OFFHAND
        "rarity": 2,  # RARE
        "sell_price": 450,
        "stats": {"def": 32, "mdef": 28, "spi": 5},
        "exclusive": "hoer_verde",
    },
    {
        "id": "pingente_do_sino_funebre",
        "name_key": "ITEM_PINGENTE_SINO_FUNEBRE_NAME",
        "desc_key": "ITEM_PINGENTE_SINO_FUNEBRE_DESC",
        "icon": "res://assets/items/icons/icon_item_seed_necklace.png",
        "type": 6,  # ACCESSORY
        "rarity": 2,  # RARE
        "sell_price": 400,
        "stats": {"matk": 22, "mdef": 16, "spi": 6},
        "exclusive": "hoer_verde",
    },
    {
        "id": "foice_da_colheita_sombria",
        "name_key": "ITEM_FOICE_COLHEITA_SOMBRIA_NAME",
        "desc_key": "ITEM_FOICE_COLHEITA_SOMBRIA_DESC",
        "icon": "res://assets/items/icons/icon_item_machete.png",
        "type": 1,  # WEAPON
        "weapon_kind": 1,  # BLADE
        "scaling": "str",
        "two_handed": True,
        "rarity": 2,  # RARE
        "sell_price": 550,
        "stats": {"atk": 56, "str": 7},
        "exclusive": "hoer_verde",
    },
    {
        "id": "arco_do_sussurro_noturno",
        "name_key": "ITEM_ARCO_SUSSURRO_NOTURNO_NAME",
        "desc_key": "ITEM_ARCO_SUSSURRO_NOTURNO_DESC",
        "icon": "res://assets/items/icons/icon_item_simple_bow.png",
        "type": 1,  # WEAPON
        "weapon_kind": 3,  # BOW
        "scaling": "dex",
        "two_handed": True,
        "rarity": 2,  # RARE
        "sell_price": 520,
        "stats": {"atk": 50, "dex": 7},
        "exclusive": "hoer_verde",
    },
    {
        "id": "cajado_das_almas_perdidas",
        "name_key": "ITEM_CAJADO_ALMAS_PERDIDAS_NAME",
        "desc_key": "ITEM_CAJADO_ALMAS_PERDIDAS_DESC",
        "icon": "res://assets/items/icons/icon_item_wooden_staff.png",
        "type": 1,  # WEAPON
        "weapon_kind": 2,  # ARCANE
        "scaling": "int",
        "two_handed": False,
        "rarity": 2,  # RARE
        "sell_price": 520,
        "stats": {"matk": 52, "int": 7},
        "exclusive": "hoer_verde",
    },
    {
        "id": "essencia_da_nevoa_densa",
        "name_key": "ITEM_ESSENCIA_NEVOA_NAME",
        "desc_key": "ITEM_ESSENCIA_NEVOA_DESC",
        "icon": "res://assets/items/icons/icon_item_potion_mp_medium.png",
        "type": 0,  # CONSUMABLE
        "rarity": 1,  # UNCOMMON
        "stackable": True,
        "max_stack": 99,
        "sell_price": 90,
        "use_effect": {"heal_hp": 550, "heal_mp": 220},
        "exclusive": "hoer_verde",
    },
    {
        "id": "tecido_fantasmagorico",
        "name_key": "ITEM_TECIDO_FANTASMAGORICO_NAME",
        "desc_key": "ITEM_TECIDO_FANTASMAGORICO_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 45,
        "exclusive": "hoer_verde",
    },
    {
        "id": "cinzas_do_desespero",
        "name_key": "ITEM_CINZAS_DESESPERO_NAME",
        "desc_key": "ITEM_CINZAS_DESESPERO_DESC",
        "icon": "res://assets/items/icons/icon_item_eternal_ember.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 50,
        "exclusive": "hoer_verde",
    },
    {
        "id": "residuo_espectral",
        "name_key": "ITEM_RESIDUO_ESPECTRAL_NAME",
        "desc_key": "ITEM_RESIDUO_ESPECTRAL_DESC",
        "icon": "res://assets/items/icons/icon_item_pequi_root.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 55,
        "exclusive": "hoer_verde",
    },
    {
        "id": "badalo_de_ferro_funebre",
        "name_key": "ITEM_BADALO_FERRO_FUNEBRE_NAME",
        "desc_key": "ITEM_BADALO_FERRO_FUNEBRE_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,  # MATERIAL
        "rarity": 2,  # RARE
        "stackable": True,
        "max_stack": 99,
        "sell_price": 120,
        "exclusive": "hoer_verde",
    },
]


def build_exclusive_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)
    translations = [
        ("ITEM_CAPUZ_BRUMA_ESPECTRAL_NAME", "Capuz da Bruma Espectral"),
        ("ITEM_CAPUZ_BRUMA_ESPECTRAL_DESC", "Capuz tecido com farrapos recolhidos nas vielas do Vilarejo de Hoer Verde. Oferece alta proteção contra feitiços."),
        ("ITEM_MANTO_DESESPERADOS_NAME", "Manto dos Desesperados"),
        ("ITEM_MANTO_DESESPERADOS_DESC", "Veste pesada impregnada com a bruma gélida da charneca. Protege o portador contra calafrios e maleitas espirituais."),
        ("ITEM_LUVAS_TOQUE_GELIDO_NAME", "Luvas do Toque Gélido"),
        ("ITEM_LUVAS_TOQUE_GELIDO_DESC", "Luvas que conservam a friagem espectral dos vultos sussurrantes, canalizando energia etérea nas magias."),
        ("ITEM_BOTAS_PASSO_SILENCIOSO_NAME", "Botas do Passo Silencioso"),
        ("ITEM_BOTAS_PASSO_SILENCIOSO_DESC", "Calçados leves que amortecem cada pisada sobre o lodo enevoado, aumentando a agilidade e a discrição."),
        ("ITEM_ESCUDO_LAMENTO_ETERNO_NAME", "Escudo do Lamento Eterno"),
        ("ITEM_ESCUDO_LAMENTO_ETERNO_DESC", "Broquel forjado com aço cinzento de sino fúnebre. Repele tanto pancadas físicas quanto lamentos místicos."),
        ("ITEM_PINGENTE_SINO_FUNEBRE_NAME", "Pingente do Sino Fúnebre"),
        ("ITEM_PINGENTE_SINO_FUNEBRE_DESC", "Pequeno adorno metálico que ressoa em harmonia com as almas errantes da charneca."),
        ("ITEM_FOICE_COLHEITA_SOMBRIA_NAME", "Foice da Colheita Sombria"),
        ("ITEM_FOICE_COLHEITA_SOMBRIA_DESC", "Lâmina curva cerimonial usada para ceifar a palha maldita das ruínas enevoadas."),
        ("ITEM_ARCO_SUSSURRO_NOTURNO_NAME", "Arco do Sussurro Noturno"),
        ("ITEM_ARCO_SUSSURRO_NOTURNO_DESC", "Arco curvado na madeira negra de árvores mortas pelo nevoeiro, lançando flechas silenciosas."),
        ("ITEM_CAJADO_ALMAS_PERDIDAS_NAME", "Cajado das Almas Perdidas"),
        ("ITEM_CAJADO_ALMAS_PERDIDAS_DESC", "Báculo entalhado que serve de guia para espíritos aflitos, intensificando o poder do arcano."),
        ("ITEM_ESSENCIA_NEVOA_NAME", "Essência da Névoa Densa"),
        ("ITEM_ESSENCIA_NEVOA_DESC", "Destilado condensado das brumas de Hoer Verde. Revigora o fôlego e restaura as forças místicas."),
        ("ITEM_TECIDO_FANTASMAGORICO_NAME", "Tecido Fantasmagórico"),
        ("ITEM_TECIDO_FANTASMAGORICO_DESC", "Pedaço de pano etéreo que parece se desmanchar em vapor quando exposto ao calor."),
        ("ITEM_CINZAS_DESESPERO_NAME", "Cinzas do Desespero"),
        ("ITEM_CINZAS_DESESPERO_DESC", "Pó fino e gélido deixado pelos possuídos após encontrarem repouso."),
        ("ITEM_RESIDUO_ESPECTRAL_NAME", "Resíduo Espectral"),
        ("ITEM_RESIDUO_ESPECTRAL_DESC", "Cristalização vaporosa de energias retidas na bruma eterna da charneca."),
        ("ITEM_BADALO_FERRO_FUNEBRE_NAME", "Badalo de Ferro Fúnebre"),
        ("ITEM_BADALO_FERRO_FUNEBRE_DESC", "Peça pesada do sino do Pregoeiro do Silêncio. Vibra com ecos lúgubres da desolação."),
    ]

    for item in HOER_EXCLUSIVE_ITEMS:
        item_id = item["id"]
        stats_lines = []
        if "stats" in item:
            stat_entries = [f'&"{k}": {v}' for k, v in item["stats"].items()]
            stats_lines.append("stats = Dictionary[StringName, int]({")
            stats_lines.append(",\n".join([f"  {se}" for se in stat_entries]))
            stats_lines.append("})")

        stats_block = "\n".join(stats_lines) if stats_lines else "stats = Dictionary[StringName, int]({})"

        weapon_kind_str = f"weapon_kind = {item['weapon_kind']}\n" if "weapon_kind" in item else ""
        scaling_str = f'scaling_stat = &"{item["scaling"]}"\n' if "scaling" in item else ""
        two_h_str = f"two_handed = {str(item.get('two_handed', False)).lower()}\n" if "two_handed" in item else ""
        use_effect_str = ""
        if "use_effect" in item:
            eff = item["use_effect"]
            use_effect_str = f"""use_effect = Dictionary[StringName, int]({{
  &"heal_hp": {eff.get("heal_hp", 0)},
  &"heal_mp": {eff.get("heal_mp", 0)}
}})
"""

        exclusive_str = f'exclusive_drop_zone = &"{item["exclusive"]}"\n' if "exclusive" in item else ""

        tres_content = f"""[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Texture2D" path="{item['icon']}" id="icon"]
[ext_resource type="Script" path="res://scripts/shared/data/item_def.gd" id="item"]

[resource]
script = ExtResource("item")
id = &"{item_id}"
name_key = "{item['name_key']}"
desc_key = "{item['desc_key']}"
icon = ExtResource("icon")
type = {item['type']}
rarity = {item['rarity']}
stackable = {str(item.get('stackable', False)).lower()}
max_stack = {item.get('max_stack', 1)}
buy_price = 0
sell_price = {item['sell_price']}
tradeable = true
crendice_id = &""
crendice_sockets = 0
{exclusive_str}{weapon_kind_str}{scaling_str}{two_h_str}{use_effect_str}{stats_block}
"""
        wg.write_text(items_dir / f"{item_id}.tres", tres_content)
        print(f"Exclusive item {item_id}.tres written.")

    # Update lenco_do_pregoeiro.tres with exclusive_drop_zone = &"hoer_verde"
    lenco_path = items_dir / "lenco_do_pregoeiro.tres"
    if lenco_path.exists():
        lenco_txt = lenco_path.read_text(encoding="utf-8")
        if "exclusive_drop_zone" not in lenco_txt:
            lenco_txt = lenco_txt.replace('crendice_sockets = 0\n', 'crendice_sockets = 0\nexclusive_drop_zone = &"hoer_verde"\n')
            wg.write_text(lenco_path, lenco_txt)
            print("Updated lenco_do_pregoeiro.tres with exclusive drop zone.")

    # Append translations to content.csv
    wg.csv_add("localization/content.csv", translations)


# ---------------------------------------------------------------------------
# Build Maps: City 3, 3 Approach Fields, 4 Dungeon Floors
# ---------------------------------------------------------------------------
HOER_MAPS = ["city_sumidouro", "fog_moor_trail", "fog_moor_swamp", "fog_moor_gate",
             "hoer_verde_1", "hoer_verde_2", "hoer_verde_3", "hoer_verde_4"]


def build_hoer_verde_maps():
    # 1. City 3: Arraial do Sumidouro
    generate_map_scene(
        map_id="city_sumidouro",
        rooms=[(0, 0, 22), (-22, -18, 14), (24, -18, 14), (0, 26, 16)],
        routes=[
            [(0, 0), (-22, -18)],
            [(0, 0), (24, -18)],
            [(0, 0), (0, 26)],
        ],
        width=5.5,
        pillars=[(-6, -6), (6, -6), (-6, 6), (6, 6), (-22, -18), (24, -18)],
        spawn_pos=(0, 0, 0),
        portals=[
            {"name": "GateSerraDourada", "pos": (-26, 1, -22), "target_map": "city_serra_dourada", "target_spawn": "SumidouroReturn", "label": "← Estrada de Serra Dourada"},
            {"name": "GateFogMoor", "pos": (28, 1, -22), "target_map": "fog_moor_trail", "target_spawn": "SpawnPoint", "label": "Charneca da Névoa →"},
            {"name": "GateHollowEarth", "pos": (0, 1, 32), "target_map": "hollow_mountain_trail", "target_spawn": "SpawnPoint", "label": "↓ Serra do Sumidouro"},
        ],
        spawns=[],
        npc_points=[
            {"id": "curandeiro_sumidouro", "pos": (-8, 0, -10), "facing": 0.0},
            {"id": "mercador_sumidouro", "pos": (8, 0, -10), "facing": 3.14},
            {"id": "artesao_sumidouro", "pos": (0, 0, 18), "facing": 1.57},
            # Dona Ana (WaystoneService): no centro do arraial, olhando para o SpawnPoint.
            {"id": "dona_ana", "pos": (0, 0, -9), "facing": 3.14,
             "meta": ["metadata/facing_yaw = 3.14", 'metadata/minimap_icon = &"shop"']},
        ],
        altar_pos=(0, 0, -16),
        extra_markers={
            "SerraDouradaReturn": (-22, 0, -14),
            "FogMoorReturn": (24, 0, -14),
            "HollowEarthReturn": (0, 0, 26),
            "WaystoneArrival": (0, 0, -6),
        },
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.70, 0.72, 0.80, 1)",
        env_light_energy=0.9,
    )
    write_zone_def("city_sumidouro", "ZONE_SUMIDOURO_NAME", 0, 0, ["city_serra_dourada", "fog_moor_trail", "hollow_mountain_trail"], kind=0, combat=False, boss_allowed=False, stage_cap=3)

    # 2. Approach Region 1: fog_moor_trail (Charneca da Névoa - Trilha dos Lamentos)
    generate_map_scene(
        map_id="fog_moor_trail",
        rooms=[(0, 0, 16), (-24, 22, 14), (28, -20, 15), (-26, -24, 14)],
        routes=[
            [(0, 0), (-24, 22)],
            [(0, 0), (28, -20)],
            [(0, 0), (-26, -24)],
            [(-24, 22), (-26, -24)],
        ],
        width=5.0,
        pillars=[(-10, 8), (12, -8), (-18, -12)],
        spawn_pos=(0, 0, 0),
        portals=[
            {"name": "ToCity", "pos": (-28, 1, 26), "target_map": "city_sumidouro", "target_spawn": "FogMoorReturn", "label": "Arraial do Sumidouro ←"},
            {"name": "ToSwamp", "pos": (32, 1, -24), "target_map": "fog_moor_swamp", "target_spawn": "SpawnPoint", "label": "Pântano das Brumas →"},
            {"name": "ToGateDirect", "pos": (-30, 1, -28), "target_map": "fog_moor_gate", "target_spawn": "FromTrail", "label": "Atalho do Vilarejo ↑"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 12), "mid": "whispering_shade", "stage": 1, "count": 3},
            {"name": "Pack2", "pos": (14, 0, -10), "mid": "despair_possessed", "stage": 1, "count": 3},
            {"name": "Pack3", "pos": (-14, 0, -14), "mid": "maned_wolf", "stage": 2, "count": 2},
            {"name": "Pack4", "pos": (8, 0, 8), "mid": "whispering_shade", "stage": 1, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_sabia_forest.tres",
        env_light_color="Color(0.60, 0.65, 0.75, 1)",
        env_light_energy=0.8,
    )
    write_zone_def("fog_moor_trail", "ZONE_FOG_MOOR_TRAIL_NAME", 34, 38, ["city_sumidouro", "fog_moor_swamp", "fog_moor_gate"], kind=2, combat=True, stage_cap=2)

    # 3. Approach Region 2: fog_moor_swamp (Pântano das Brumas)
    generate_map_scene(
        map_id="fog_moor_swamp",
        rooms=[(0, 0, 18), (-26, -20, 15), (26, 22, 15), (0, -32, 12)],
        routes=[
            [(0, 0), (-26, -20)],
            [(0, 0), (26, 22)],
            [(0, 0), (0, -32)],
            [(-26, -20), (0, -32)],
        ],
        width=5.2,
        pillars=[(-12, -10), (12, 10), (0, -18)],
        spawn_pos=(0, 0, 0),
        portals=[
            {"name": "ToTrail", "pos": (-30, 1, -24), "target_map": "fog_moor_trail", "target_spawn": "SpawnPoint", "label": "Trilha dos Lamentos ←"},
            {"name": "ToGate", "pos": (30, 1, 26), "target_map": "fog_moor_gate", "target_spawn": "FromSwamp", "label": "Portal do Vilarejo ↑"},
            {"name": "ToMistyCove", "pos": (0, 1, -36), "target_map": "fog_moor_trail", "target_spawn": "SpawnPoint", "label": "Vau da Neblina"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, -12), "mid": "black_caiman", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (14, 0, 12), "mid": "despair_possessed", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -20), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (6, 0, 6), "mid": "river_anaconda", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_sabia_forest.tres",
        env_light_color="Color(0.55, 0.60, 0.70, 1)",
        env_light_energy=0.75,
    )
    write_zone_def("fog_moor_swamp", "ZONE_FOG_MOOR_SWAMP_NAME", 36, 40, ["fog_moor_trail", "fog_moor_gate"], kind=2, combat=True, stage_cap=2)

    # 4. Approach Region 3: fog_moor_gate (Portal do Vilarejo Esquecido)
    generate_map_scene(
        map_id="fog_moor_gate",
        rooms=[(0, 0, 20), (-26, 22, 14), (26, 22, 14), (0, -28, 16)],
        routes=[
            [(0, 0), (-26, 22)],
            [(0, 0), (26, 22)],
            [(0, 0), (0, -28)],
        ],
        width=5.5,
        pillars=[(-10, 10), (10, 10), (0, -14)],
        spawn_pos=(0, 0, 10),
        portals=[
            {"name": "ToTrail", "pos": (-30, 1, 26), "target_map": "fog_moor_trail", "target_spawn": "SpawnPoint", "label": "Trilha dos Lamentos ←"},
            {"name": "ToSwamp", "pos": (30, 1, 26), "target_map": "fog_moor_swamp", "target_spawn": "SpawnPoint", "label": "Pântano das Brumas →"},
            {"name": "ToDungeon", "pos": (0, 1, -34), "target_map": "hoer_verde_1", "target_spawn": "SpawnPoint", "label": "Entrada de Hoer Verde ⇓"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 10), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 10), "mid": "despair_possessed", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -16), "mid": "whispering_shade", "stage": 2, "count": 3},
        ],
        extra_markers={
            "FromTrail": (-24, 0, 18),
            "FromSwamp": (24, 0, 18),
            "HoerReturn": (0, 0, -22),
        },
        ground_mat="res://assets/environment/painted/materials/mat_ground_sabia_forest.tres",
        env_light_color="Color(0.50, 0.55, 0.65, 1)",
        env_light_energy=0.75,
    )
    write_zone_def("fog_moor_gate", "ZONE_FOG_MOOR_GATE_NAME", 37, 42, ["fog_moor_trail", "fog_moor_swamp", "hoer_verde_1"], kind=2, combat=True, stage_cap=2)

    # 5. Dungeon Floor 1: hoer_verde_1 (Casas em Ruínas e Portão Encoberto)
    generate_map_scene(
        map_id="hoer_verde_1",
        rooms=[(0, 20, 16), (0, -15, 18), (-22, 0, 14), (22, 0, 14)],
        routes=[
            [(0, 20), (0, -15)],
            [(0, 20), (-22, 0)],
            [(0, 20), (22, 0)],
            [(-22, 0), (0, -15)],
            [(22, 0), (0, -15)],
        ],
        width=4.8,
        pillars=[(-10, 10), (10, 10), (-10, -8), (10, -8)],
        spawn_pos=(0, 0, 24),
        portals=[
            {"name": "ExitToSurface", "pos": (0, 1, 28), "target_map": "fog_moor_gate", "target_spawn": "HoerReturn", "label": "Superfície ⇑"},
            {"name": "ToFloor2", "pos": (0, 1, -24), "target_map": "hoer_verde_2", "target_spawn": "SpawnPoint", "label": "Descer Vielas (F2) ⇓"},
            {"name": "ToCellarOld", "pos": (-26, 1, 0), "target_map": "hoer_verde_2", "target_spawn": "SpawnPoint", "label": "Alçapão Antigo ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -18)},
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 0), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 0), "mid": "despair_possessed", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -8), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (0, 0, 10), "mid": "despair_possessed", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.45, 0.48, 0.58, 1)",
        env_light_energy=0.7,
    )
    write_zone_def("hoer_verde_1", "ZONE_HOER_VERDE_1_NAME", 38, 43, ["fog_moor_gate", "hoer_verde_2"], kind=2, combat=True, stage_cap=2)

    # 6. Dungeon Floor 2: hoer_verde_2 (Vielas dos Sussurros)
    generate_map_scene(
        map_id="hoer_verde_2",
        rooms=[(0, 24, 15), (-24, 0, 15), (24, 0, 15), (0, -24, 16), (0, 0, 14)],
        routes=[
            [(0, 24), (-24, 0)],
            [(0, 24), (24, 0)],
            [(-24, 0), (0, -24)],
            [(24, 0), (0, -24)],
            [(0, 24), (0, 0)],
            [(0, 0), (0, -24)],
        ],
        width=4.6,
        pillars=[(-12, 12), (12, 12), (-12, -12), (12, -12)],
        spawn_pos=(0, 0, 26),
        portals=[
            {"name": "ToFloor1", "pos": (0, 1, 30), "target_map": "hoer_verde_1", "target_spawn": "DescentLanding", "label": "Subir Ruínas (F1) ⇑"},
            {"name": "ToFloor3", "pos": (0, 1, -30), "target_map": "hoer_verde_3", "target_spawn": "SpawnPoint", "label": "Descer Claustro (F3) ⇓"},
            {"name": "SideAlley", "pos": (28, 1, 0), "target_map": "hoer_verde_3", "target_spawn": "SpawnPoint", "label": "Passagem Furtiva ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -24)},
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, 0), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (14, 0, 0), "mid": "despair_possessed", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, 12), "mid": "whispering_shade", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (0, 0, -12), "mid": "despair_possessed", "stage": 2, "count": 1},
            {"name": "Pack5", "pos": (0, 0, 0), "mid": "whispering_shade", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.40, 0.42, 0.52, 1)",
        env_light_energy=0.65,
    )
    write_zone_def("hoer_verde_2", "ZONE_HOER_VERDE_2_NAME", 40, 45, ["hoer_verde_1", "hoer_verde_3"], kind=2, combat=True, stage_cap=3)

    # 7. Dungeon Floor 3: hoer_verde_3 (Claustro dos Desesperados)
    generate_map_scene(
        map_id="hoer_verde_3",
        rooms=[(0, 24, 16), (-26, -10, 15), (26, -10, 15), (0, -26, 17)],
        routes=[
            [(0, 24), (-26, -10)],
            [(0, 24), (26, -10)],
            [(-26, -10), (0, -26)],
            [(26, -10), (0, -26)],
            [(-26, -10), (26, -10)],
        ],
        width=4.8,
        pillars=[(-14, 6), (14, 6), (0, -14)],
        spawn_pos=(0, 0, 26),
        portals=[
            {"name": "ToFloor2", "pos": (0, 1, 30), "target_map": "hoer_verde_2", "target_spawn": "DescentLanding", "label": "Subir Vielas (F2) ⇑"},
            {"name": "ToFloor4", "pos": (0, 1, -32), "target_map": "hoer_verde_4", "target_spawn": "SpawnPoint", "label": "Praça do Silêncio (F4) ⇓"},
            {"name": "ChamberSide", "pos": (-30, 1, -12), "target_map": "hoer_verde_4", "target_spawn": "SpawnPoint", "label": "Galeria das Sombras ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -26)},
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, -4), "mid": "despair_possessed", "stage": 2, "count": 2},
            {"name": "Pack2", "pos": (14, 0, -4), "mid": "whispering_shade", "stage": 2, "count": 2},
            {"name": "Pack3", "pos": (0, 0, 10), "mid": "despair_possessed", "stage": 2, "count": 4},
            {"name": "Pack4", "pos": (0, 0, -18), "mid": "whispering_shade", "stage": 2, "count": 4},
            {"name": "Pack5", "pos": (-12, 0, 16), "mid": "despair_possessed", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.35, 0.38, 0.48, 1)",
        env_light_energy=0.6,
    )
    write_zone_def("hoer_verde_3", "ZONE_HOER_VERDE_3_NAME", 43, 48, ["hoer_verde_2", "hoer_verde_4"], kind=2, combat=True, stage_cap=3)

    # 8. Dungeon Floor 4: hoer_verde_4 (Praça do Silêncio - Boss Floor)
    generate_map_scene(
        map_id="hoer_verde_4",
        rooms=[(0, 20, 16), (0, -18, 22), (-24, 0, 14), (24, 0, 14)],
        routes=[
            [(0, 20), (0, -18)],
            [(0, 20), (-24, 0)],
            [(0, 20), (24, 0)],
            [(-24, 0), (0, -18)],
            [(24, 0), (0, -18)],
        ],
        width=5.2,
        pillars=[(-10, 4), (10, 4), (-10, -14), (10, -14)],
        spawn_pos=(0, 0, 22),
        portals=[
            {"name": "ToFloor3", "pos": (0, 1, 26), "target_map": "hoer_verde_3", "target_spawn": "DescentLanding", "label": "Subir Claustro (F3) ⇑"},
            {"name": "SurfaceEscapePortal", "pos": (0, 1, -34), "target_map": "fog_moor_gate", "target_spawn": "HoerReturn", "label": "Fuga para a Superfície ⇑", "is_escape": True, "interact_id": "hoer_verde_4_escape"},
            {"name": "SideGallery", "pos": (28, 1, 0), "target_map": "hoer_verde_3", "target_spawn": "DescentLanding", "label": "Retorno ao Claustro ⇑"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 0), "mid": "whispering_shade", "stage": 2, "count": 2},
            {"name": "Pack2", "pos": (12, 0, 0), "mid": "despair_possessed", "stage": 2, "count": 2},
            {"name": "Pack3", "pos": (0, 0, 8), "mid": "whispering_shade", "stage": 2, "count": 4},
            {"name": "Pack4", "pos": (-12, 0, -12), "mid": "despair_possessed", "stage": 2, "count": 3},
            {"name": "Pack5", "pos": (12, 0, -12), "mid": "silence_crier", "stage": 2, "count": 1},
        ],
        boss_lairs=[
            {"name": "silence_crier_lair", "pos": (0, 0, -22), "mid": "silence_crier", "radius_cells": 9, "respawn_sec": 600.0}
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.30, 0.32, 0.42, 1)",
        env_light_energy=0.55,
    )
    write_zone_def("hoer_verde_4", "ZONE_HOER_VERDE_4_NAME", 46, 52, ["hoer_verde_3", "fog_moor_gate"], kind=2, combat=True, boss_allowed=True, stage_cap=3)

    # 9. Serra Dourada (hub city) is generated by build_ratanaba_expansion.py with the Sumidouro gate
    #    (GateSumidouro -> SerraDouradaReturn, arrival SumidouroReturn); validate_world checks both sides.
    # 10. Update world.csv translations
    world_tr = [
        ("ZONE_SUMIDOURO_NAME", "Arraial do Sumidouro"),
        ("ZONE_FOG_MOOR_TRAIL_NAME", "Charneca da Névoa - Trilha dos Lamentos"),
        ("ZONE_FOG_MOOR_SWAMP_NAME", "Pântano das Brumas"),
        ("ZONE_FOG_MOOR_GATE_NAME", "Portal do Vilarejo Esquecido"),
        ("ZONE_HOER_VERDE_1_NAME", "Vilarejo de Hoer Verde - Casas em Ruínas (F1)"),
        ("ZONE_HOER_VERDE_2_NAME", "Vilarejo de Hoer Verde - Vielas dos Sussurros (F2)"),
        ("ZONE_HOER_VERDE_3_NAME", "Vilarejo de Hoer Verde - Claustro dos Desesperados (F3)"),
        ("ZONE_HOER_VERDE_4_NAME", "Vilarejo de Hoer Verde - Praça do Silêncio (F4)"),
    ]
    wg.csv_add("localization/world.csv", world_tr)


if __name__ == "__main__":
    print("=== Building O Vilarejo de Hoer Verde & Arraial do Sumidouro ===")
    build_hoer_monsters()
    build_exclusive_items()
    build_hoer_verde_maps()
    wg.finish(HOER_MAPS, "hoer_verde")
    print("=== O Vilarejo de Hoer Verde Successfully Built ===")
