#!/usr/bin/env python3
"""
build_hollow_earth_expansion.py
Expands Nação Sabiá with:
1. Approach Region: Serra do Sumidouro (3 maps: hollow_mountain_trail, hollow_mountain_gorge, hollow_mountain_gate)
2. Dungeon 6: Túneis da Terra Oca (5 floors: hollow_earth_1 .. hollow_earth_5)
3. Thematic Monsters (4 stages each):
   - living_crystal (Cristais Viventes)
   - shadow_weaver (Aranhas Tecelãs de Sombra)
   - deep_titan (O Titã das Profundezas - Boss)
4. Exclusive Gear & Drops (exclusive_drop_zone = &"hollow_earth", buy_price = 0)
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

# A Aranha-Armadeira (fonte do recolor) ganhou chefe/atroz unicos em quadro 240 (antes 144, recolor da iguana):
# para o recolor derivado manter o tamanho na tela de antes, o visual_scale do s3/s4 encolhe na mesma proporcao.
SRC_BOSS_240 = {"wandering_spider"}


def stage_visual_scale(src_mid, st, scale):
    if src_mid in SRC_BOSS_240 and st >= 3:
        return round(scale * 144 / 240, 3)
    return scale

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
HOLLOW_SPECIES_DATA = [
    (
        "living_crystal",
        ["Fragmento de Cristal Vivente", "Guardião de Quartzo", "Monólito Cristalino Ancião", "Cristal Vivente Atroz"],
        "cascalho_de_cristal_vivente",
        [42, 47, 53, 59],
        "ranged",
        "ratanaba_sentinel",
        [((80, 180, 220), 0.75), ((60, 160, 210), 0.8), ((40, 140, 200), 0.85), ((20, 120, 220), 0.9)],
        [1.1, 1.35, 1.65, 2.0],
    ),
    (
        "shadow_weaver",
        ["Tecelã da Sombra Jovem", "Aranha Tecelã Profunda", "Matriarca Tecelã do Abismo", "Tecelã Sombria Atroz"],
        "seda_sombria_profunda",
        [43, 48, 54, 60],
        "melee",
        "wandering_spider",
        [((50, 30, 70), 0.75), ((40, 20, 60), 0.8), ((30, 15, 50), 0.85), ((20, 10, 40), 0.9)],
        [1.15, 1.4, 1.7, 2.1],
    ),
    (
        "deep_titan",
        ["Golem da Terra Profunda", "Guardião Tectônico", "O Titã das Profundezas", "Titã Tectônico Atroz"],
        "estilha_primordial_do_tita",
        [46, 52, 58, 65],
        "boss",
        "moss_troll",
        [((70, 45, 30), 0.8), ((80, 40, 25), 0.85), ((90, 35, 20), 0.9), ((110, 30, 15), 0.95)],
        [1.4, 1.75, 2.15, 2.6],
    ),
]


def build_hollow_monsters():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"
    monsters_dir = GAME_DIR / "data/monsters"
    monsters_dir.mkdir(parents=True, exist_ok=True)
    translations = []

    for index, (mid, names, primary_drop, levels, behavior, src_mid, tints, scales) in enumerate(HOLLOW_SPECIES_DATA):
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
            hp = int(1500 + level * 85 + (index * 240)) * (9 if st == 3 else 16 if st == 4 else 1)
            atk = int(58 + level * 3.1) * (2 if st >= 3 else 1)
            defense = int(28 + level * 1.5)
            mdef = int(24 + level * 1.6)
            walk_ms = 440 if st == 4 else 480 if st == 3 else 540
            atk_interval = 950 if st == 4 else 1150 if st == 3 else 1350
            boss = st >= 3

            st_behaviors = []
            if behavior == "ranged":
                st_behaviors.append('&"ranged"')
            if boss:
                st_behaviors.append('&"boss"')

            behaviors_str = f"Array[StringName]([{', '.join(st_behaviors)}])" if st_behaviors else "Array[StringName]([])"

            drop_subresources = [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]\nscript = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {1.0 if boss else 0.45}\nmin_qty = {2 if boss else 1}\nmax_qty = {5 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_cryst_{st}"]\nscript = ExtResource("drop")\nitem_id = &"cascalho_de_cristal_vivente"\nchance = {0.8 if boss else 0.3}\nmin_qty = 1\nmax_qty = 3',
                f'[sub_resource type="Resource" id="drop_elix_{st}"]\nscript = ExtResource("drop")\nitem_id = &"elixir_mineral_das_profundezas"\nchance = {0.75 if boss else 0.2}\nmin_qty = 1\nmax_qty = 2',
            ]
            drops_list = [f'SubResource("drop_mat_{st}")', f'SubResource("drop_cryst_{st}")', f'SubResource("drop_elix_{st}")']

            if mid == "deep_titan" and boss:
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_eye_{st}"]\nscript = ExtResource("drop")\nitem_id = &"olho_do_tita"\nchance = {0.07 if st == 3 else 0.15}\nmin_qty = 1\nmax_qty = 1'
                )
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_hammer_{st}"]\nscript = ExtResource("drop")\nitem_id = &"martelo_do_abismo_profundo"\nchance = {0.25 if st == 3 else 0.40}\nmin_qty = 1\nmax_qty = 1'
                )
                drops_list.append(f'SubResource("drop_eye_{st}")')
                drops_list.append(f'SubResource("drop_hammer_{st}")')

            parts.extend(drop_subresources)
            parts.append(
                f"""[sub_resource type="Resource" id="stage{st}"]
script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {stage_visual_scale(src_mid, st, scales[st - 1])}
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
xp_reward = {(2600 + index * 200) * (2 if st == 4 else 1) if boss else level * 20}
stars_min = {200 if st == 4 else 100 if boss else max(2, level // 2)}
stars_max = {400 if st == 4 else 200 if boss else level + 10}
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
    print("Hollow Earth monsters successfully built.")


# ---------------------------------------------------------------------------
# Map Generator Engine
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
    env_light_color: str = "Color(0.55, 0.65, 0.85, 1)",
    env_light_energy: float = 0.8,
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

    # Environment: procedural sky material defined first!
    res(
        "ProceduralSkyMaterial",
        "sky_mat",
        """sky_top_color = Color(0.08, 0.12, 0.18, 1)
sky_horizon_color = Color(0.18, 0.22, 0.30, 1)
ground_bottom_color = Color(0.05, 0.07, 0.10, 1)
ground_horizon_color = Color(0.18, 0.22, 0.30, 1)""",
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
fog_light_color = Color(0.28, 0.35, 0.45, 1)
fog_density = 0.012""",
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
HOLLOW_EXCLUSIVE_ITEMS = [
    {
        "id": "elmo_de_cristal_ressonante",
        "name_key": "ITEM_ELMO_CRISTAL_RESSONANTE_NAME",
        "desc_key": "ITEM_ELMO_CRISTAL_RESSONANTE_DESC",
        "icon": "res://assets/items/icons/icon_item_ipe_flower_crown.png",
        "type": 3,  # HEAD
        "rarity": 2,  # RARE
        "sell_price": 420,
        "stats": {"def": 18, "mdef": 24, "vit": 5, "spi": 5},
        "exclusive": "hollow_earth",
    },
    {
        "id": "armadura_do_tita_profundo",
        "name_key": "ITEM_ARMADURA_TITA_PROFUNDO_NAME",
        "desc_key": "ITEM_ARMADURA_TITA_PROFUNDO_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_jerkin.png",
        "type": 4,  # BODY
        "rarity": 2,  # RARE
        "sell_price": 580,
        "stats": {"def": 44, "mdef": 26, "vit": 8},
        "exclusive": "hollow_earth",
    },
    {
        "id": "manoplas_de_quartzo_puro",
        "name_key": "ITEM_MANOPLAS_QUARTZO_PURO_NAME",
        "desc_key": "ITEM_MANOPLAS_QUARTZO_PURO_DESC",
        "icon": "res://assets/items/icons/icon_item_ribbon_bracelet.png",
        "type": 8,  # GLOVES
        "rarity": 2,  # RARE
        "sell_price": 360,
        "stats": {"def": 16, "atk": 14, "str": 6},
        "exclusive": "hollow_earth",
    },
    {
        "id": "grevas_do_abismo_oco",
        "name_key": "ITEM_GREVAS_ABISMO_OCO_NAME",
        "desc_key": "ITEM_GREVAS_ABISMO_OCO_DESC",
        "icon": "res://assets/items/icons/icon_item_walking_boots.png",
        "type": 5,  # FEET
        "rarity": 2,  # RARE
        "sell_price": 340,
        "stats": {"def": 14, "mdef": 18, "vit": 5},
        "exclusive": "hollow_earth",
    },
    {
        "id": "escudo_bastiao_tectonico",
        "name_key": "ITEM_ESCUDO_BASTIAO_TECTONICO_NAME",
        "desc_key": "ITEM_ESCUDO_BASTIAO_TECTONICO_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_shield.png",
        "type": 2,  # OFFHAND
        "rarity": 2,  # RARE
        "sell_price": 490,
        "stats": {"def": 36, "mdef": 26, "vit": 6},
        "exclusive": "hollow_earth",
    },
    {
        "id": "amuleto_do_nucleo_cristalino",
        "name_key": "ITEM_AMULETO_NUCLEO_CRISTALINO_NAME",
        "desc_key": "ITEM_AMULETO_NUCLEO_CRISTALINO_DESC",
        "icon": "res://assets/items/icons/icon_item_seed_necklace.png",
        "type": 6,  # ACCESSORY
        "rarity": 2,  # RARE
        "sell_price": 440,
        "stats": {"matk": 20, "mdef": 20, "int": 5, "spi": 5},
        "exclusive": "hollow_earth",
    },
    {
        "id": "martelo_do_abismo_profundo",
        "name_key": "ITEM_MARTELO_ABISMO_PROFUNDO_NAME",
        "desc_key": "ITEM_MARTELO_ABISMO_PROFUNDO_DESC",
        "icon": "res://assets/items/icons/icon_item_machete.png",
        "type": 1,  # WEAPON
        "weapon_kind": 1,  # BLADE / HEAVY
        "scaling": "str",
        "two_handed": True,
        "rarity": 2,  # RARE
        "sell_price": 600,
        "stats": {"atk": 62, "str": 8, "vit": 4},
        "exclusive": "hollow_earth",
    },
    {
        "id": "arco_de_estilha_ressonante",
        "name_key": "ITEM_ARCO_ESTILHA_RESSONANTE_NAME",
        "desc_key": "ITEM_ARCO_ESTILHA_RESSONANTE_DESC",
        "icon": "res://assets/items/icons/icon_item_simple_bow.png",
        "type": 1,  # WEAPON
        "weapon_kind": 3,  # BOW
        "scaling": "dex",
        "two_handed": True,
        "rarity": 2,  # RARE
        "sell_price": 580,
        "stats": {"atk": 56, "dex": 8},
        "exclusive": "hollow_earth",
    },
    {
        "id": "cetro_do_coracao_da_terra",
        "name_key": "ITEM_CETRO_CORACAO_TERRA_NAME",
        "desc_key": "ITEM_CETRO_CORACAO_TERRA_DESC",
        "icon": "res://assets/items/icons/icon_item_wooden_staff.png",
        "type": 1,  # WEAPON
        "weapon_kind": 2,  # ARCANE
        "scaling": "int",
        "two_handed": False,
        "rarity": 2,  # RARE
        "sell_price": 580,
        "stats": {"matk": 58, "int": 8},
        "exclusive": "hollow_earth",
    },
    {
        "id": "elixir_mineral_das_profundezas",
        "name_key": "ITEM_ELIXIR_MINERAL_NAME",
        "desc_key": "ITEM_ELIXIR_MINERAL_DESC",
        "icon": "res://assets/items/icons/icon_item_potion_hp_medium.png",
        "type": 0,  # CONSUMABLE
        "rarity": 1,  # UNCOMMON
        "stackable": True,
        "max_stack": 99,
        "sell_price": 100,
        "use_effect": {"heal_hp": 650, "heal_mp": 260},
        "exclusive": "hollow_earth",
    },
    {
        "id": "cascalho_de_cristal_vivente",
        "name_key": "ITEM_CASCALHO_CRISTAL_NAME",
        "desc_key": "ITEM_CASCALHO_CRISTAL_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 50,
        "exclusive": "hollow_earth",
    },
    {
        "id": "seda_sombria_profunda",
        "name_key": "ITEM_SEDA_SOMBRIA_NAME",
        "desc_key": "ITEM_SEDA_SOMBRIA_DESC",
        "icon": "res://assets/items/icons/icon_item_pequi_root.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 55,
        "exclusive": "hollow_earth",
    },
    {
        "id": "estilha_primordial_do_tita",
        "name_key": "ITEM_ESTILHA_PRIMORDIAL_NAME",
        "desc_key": "ITEM_ESTILHA_PRIMORDIAL_DESC",
        "icon": "res://assets/items/icons/icon_item_eternal_ember.png",
        "type": 7,  # MATERIAL
        "rarity": 2,  # RARE
        "stackable": True,
        "max_stack": 99,
        "sell_price": 140,
        "exclusive": "hollow_earth",
    },
]


def build_exclusive_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)
    translations = [
        ("ITEM_ELMO_CRISTAL_RESSONANTE_NAME", "Elmo de Cristal Ressonante"),
        ("ITEM_ELMO_CRISTAL_RESSONANTE_DESC", "Elmo entalhado em quartzo translúcido dos Túneis da Terra Oca. Repele energias dissonantes e vibra em harmonia com o solo."),
        ("ITEM_ARMADURA_TITA_PROFUNDO_NAME", "Armadura do Titã Profundo"),
        ("ITEM_ARMADURA_TITA_PROFUNDO_DESC", "Pesada couraça de placas minerais forjadas no calor das profundezas tectônicas. Fornece robustez incomparável."),
        ("ITEM_MANOPLAS_QUARTZO_PURO_NAME", "Manoplas de Quartzo Puro"),
        ("ITEM_MANOPLAS_QUARTZO_PURO_DESC", "Protetores de punho com pontas de cristal afiado, aumentando o impacto de golpes e cortes."),
        ("ITEM_GREVAS_ABISMO_OCO_NAME", "Grevas do Abismo Oco"),
        ("ITEM_GREVAS_ABISMO_OCO_DESC", "Grevas robustas esculpidas em rocha subterrânea compacta, conferindo passadas firmes mesmo sobre fendas sísmicas."),
        ("ITEM_ESCUDO_BASTIAO_TECTONICO_NAME", "Escudo Bastião Tectônico"),
        ("ITEM_ESCUDO_BASTIAO_TECTONICO_DESC", "Paredão de pedra basáltica reforçado por veios de cristal vivente. Suporta impactos esmagadores."),
        ("ITEM_AMULETO_NUCLEO_CRISTALINO_NAME", "Amuleto do Núcleo Cristalino"),
        ("ITEM_AMULETO_NUCLEO_CRISTALINO_DESC", "Pingente que abriga um geodo vivo, irradiando calor mineral e foco para o espírito."),
        ("ITEM_MARTELO_ABISMO_PROFUNDO_NAME", "Martelo do Abismo Profundo"),
        ("ITEM_MARTELO_ABISMO_PROFUNDO_DESC", "Arma colossal de duas mãos com cabeça de rocha ígnea, capaz de rachar carapaças minerais e muralhas."),
        ("ITEM_ARCO_ESTILHA_RESSONANTE_NAME", "Arco de Estilha Ressonante"),
        ("ITEM_ARCO_ESTILHA_RESSONANTE_DESC", "Arco esculpido a partir de um filão de cristal elástico das cavernas mais fundas."),
        ("ITEM_CETRO_CORACAO_TERRA_NAME", "Cetro do Coração da Terra"),
        ("ITEM_CETRO_CORACAO_TERRA_DESC", "Cetro que pulsa com o batimento telúrico do planeta, potencializando magias arcanas primordiais."),
        ("ITEM_ELIXIR_MINERAL_NAME", "Elixir Mineral das Profundezas"),
        ("ITEM_ELIXIR_MINERAL_DESC", "Bebida espessa enriquecida com minerais raros dissolvidos em águas termais das cavernas. Revigora a saúde e a mente."),
        ("ITEM_CASCALHO_CRISTAL_NAME", "Cascalho de Cristal Vivente"),
        ("ITEM_CASCALHO_CRISTAL_DESC", "Fragmentos polidos de cristais móveis que ainda emitem tênue pulsação azulada."),
        ("ITEM_SEDA_SOMBRIA_NAME", "Seda Sombria Profunda"),
        ("ITEM_SEDA_SOMBRIA_DESC", "Fio resistente e espantosamente leve tecido pelas aranhas das fendas abissais."),
        ("ITEM_ESTILHA_PRIMORDIAL_NAME", "Estilha Primordial do Titã"),
        ("ITEM_ESTILHA_PRIMORDIAL_DESC", "Fragmento do núcleo rochoso do Titã das Profundezas. Retém o calor da formação do mundo."),
    ]

    for item in HOLLOW_EXCLUSIVE_ITEMS:
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

    # Update olho_do_tita.tres with exclusive_drop_zone = &"hollow_earth"
    olho_path = items_dir / "olho_do_tita.tres"
    if olho_path.exists():
        olho_txt = olho_path.read_text(encoding="utf-8")
        if "exclusive_drop_zone" not in olho_txt:
            olho_txt = olho_txt.replace('crendice_sockets = 0\n', 'crendice_sockets = 0\nexclusive_drop_zone = &"hollow_earth"\n')
            wg.write_text(olho_path, olho_txt)
            print("Updated olho_do_tita.tres with exclusive drop zone.")

    # Append translations to content.csv
    wg.csv_add("localization/content.csv", translations)


# ---------------------------------------------------------------------------
# Build Maps: 3 Approach Fields, 5 Dungeon Floors
# ---------------------------------------------------------------------------
HOLLOW_MAPS = ["hollow_mountain_trail", "hollow_mountain_gorge", "hollow_mountain_gate",
               "hollow_earth_1", "hollow_earth_2", "hollow_earth_3", "hollow_earth_4", "hollow_earth_5"]


def build_hollow_earth_maps():
    # 1. Approach Region 1: hollow_mountain_trail (Trilha dos Cristais da Serra)
    generate_map_scene(
        map_id="hollow_mountain_trail",
        rooms=[(0, 0, 18), (-24, 22, 14), (26, -22, 15), (-26, -22, 14)],
        routes=[
            [(0, 0), (-24, 22)],
            [(0, 0), (26, -22)],
            [(0, 0), (-26, -22)],
            [(-24, 22), (-26, -22)],
        ],
        width=5.0,
        pillars=[(-10, 8), (10, -8), (-16, -10)],
        spawn_pos=(0, 0, 0),
        portals=[
            {"name": "ToCity", "pos": (-28, 1, 26), "target_map": "city_sumidouro", "target_spawn": "HollowEarthReturn", "label": "Arraial do Sumidouro ↑"},
            {"name": "ToGorge", "pos": (30, 1, -26), "target_map": "hollow_mountain_gorge", "target_spawn": "SpawnPoint", "label": "Garganta do Abismo →"},
            {"name": "ToGateDirect", "pos": (-30, 1, -26), "target_map": "hollow_mountain_gate", "target_spawn": "FromTrail", "label": "Atalho da Boca do Sumidouro ↓"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 12), "mid": "living_crystal", "stage": 1, "count": 3},
            {"name": "Pack2", "pos": (14, 0, -12), "mid": "shadow_weaver", "stage": 1, "count": 3},
            {"name": "Pack3", "pos": (-14, 0, -14), "mid": "living_crystal", "stage": 1, "count": 2},
            {"name": "Pack4", "pos": (6, 0, 6), "mid": "living_crystal", "stage": 1, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.60, 0.70, 0.85, 1)",
        env_light_energy=0.85,
    )
    write_zone_def("hollow_mountain_trail", "ZONE_HOLLOW_MOUNTAIN_TRAIL_NAME", 40, 44, ["city_sumidouro", "hollow_mountain_gorge", "hollow_mountain_gate"], kind=2, combat=True, stage_cap=2)

    # 2. Approach Region 2: hollow_mountain_gorge (Garganta do Abismo)
    generate_map_scene(
        map_id="hollow_mountain_gorge",
        rooms=[(0, 0, 20), (-26, -20, 15), (26, 22, 15), (0, -32, 14)],
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
            {"name": "ToTrail", "pos": (-30, 1, -24), "target_map": "hollow_mountain_trail", "target_spawn": "SpawnPoint", "label": "Trilha dos Cristais ←"},
            {"name": "ToGate", "pos": (30, 1, 26), "target_map": "hollow_mountain_gate", "target_spawn": "FromGorge", "label": "Boca do Sumidouro ↓"},
            {"name": "ToScenicOverlook", "pos": (0, 1, -36), "target_map": "hollow_mountain_trail", "target_spawn": "SpawnPoint", "label": "Mirante do Abismo"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, -12), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (14, 0, 12), "mid": "shadow_weaver", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -20), "mid": "shadow_weaver", "stage": 1, "count": 2},
            {"name": "Pack4", "pos": (6, 0, 6), "mid": "living_crystal", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.55, 0.65, 0.80, 1)",
        env_light_energy=0.8,
    )
    write_zone_def("hollow_mountain_gorge", "ZONE_HOLLOW_MOUNTAIN_GORGE_NAME", 42, 46, ["hollow_mountain_trail", "hollow_mountain_gate"], kind=2, combat=True, stage_cap=2)

    # 3. Approach Region 3: hollow_mountain_gate (Boca do Sumidouro)
    generate_map_scene(
        map_id="hollow_mountain_gate",
        rooms=[(0, 0, 22), (-26, 22, 15), (26, 22, 15), (0, -28, 18)],
        routes=[
            [(0, 0), (-26, 22)],
            [(0, 0), (26, 22)],
            [(0, 0), (0, -28)],
        ],
        width=5.5,
        pillars=[(-10, 10), (10, 10), (0, -14)],
        spawn_pos=(0, 0, 10),
        portals=[
            {"name": "ToTrail", "pos": (-30, 1, 26), "target_map": "hollow_mountain_trail", "target_spawn": "SpawnPoint", "label": "Trilha dos Cristais ←"},
            {"name": "ToGorge", "pos": (30, 1, 26), "target_map": "hollow_mountain_gorge", "target_spawn": "SpawnPoint", "label": "Garganta do Abismo →"},
            {"name": "ToDungeon", "pos": (0, 1, -34), "target_map": "hollow_earth_1", "target_spawn": "SpawnPoint", "label": "Entrada da Terra Oca ⇓"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 10), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 10), "mid": "shadow_weaver", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -16), "mid": "living_crystal", "stage": 2, "count": 4},
        ],
        extra_markers={
            "FromTrail": (-24, 0, 18),
            "FromGorge": (24, 0, 18),
            "HollowReturn": (0, 0, -22),
        },
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.50, 0.60, 0.75, 1)",
        env_light_energy=0.75,
    )
    write_zone_def("hollow_mountain_gate", "ZONE_HOLLOW_MOUNTAIN_GATE_NAME", 43, 48, ["hollow_mountain_trail", "hollow_mountain_gorge", "hollow_earth_1"], kind=2, combat=True, stage_cap=2)

    # 4. Dungeon Floor 1: hollow_earth_1 (Galerias de Cristal)
    generate_map_scene(
        map_id="hollow_earth_1",
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
            {"name": "ExitToSurface", "pos": (0, 1, 28), "target_map": "hollow_mountain_gate", "target_spawn": "HollowReturn", "label": "Superfície ⇑"},
            {"name": "ToFloor2", "pos": (0, 1, -24), "target_map": "hollow_earth_2", "target_spawn": "SpawnPoint", "label": "Descer Fenda dos Ecos (F2) ⇓"},
            {"name": "SideCavern", "pos": (-26, 1, 0), "target_map": "hollow_earth_2", "target_spawn": "SpawnPoint", "label": "Galerias do Quartzo ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -18)},
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 0), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 0), "mid": "shadow_weaver", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, -8), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (0, 0, 10), "mid": "shadow_weaver", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.40, 0.50, 0.65, 1)",
        env_light_energy=0.7,
    )
    write_zone_def("hollow_earth_1", "ZONE_HOLLOW_EARTH_1_NAME", 44, 49, ["hollow_mountain_gate", "hollow_earth_2"], kind=2, combat=True, stage_cap=2)

    # 5. Dungeon Floor 2: hollow_earth_2 (Fenda dos Ecos)
    generate_map_scene(
        map_id="hollow_earth_2",
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
            {"name": "ToFloor1", "pos": (0, 1, 30), "target_map": "hollow_earth_1", "target_spawn": "DescentLanding", "label": "Subir Galerias (F1) ⇑"},
            {"name": "ToFloor3", "pos": (0, 1, -30), "target_map": "hollow_earth_3", "target_spawn": "SpawnPoint", "label": "Descer Labirinto (F3) ⇓"},
            {"name": "EchoPassage", "pos": (28, 1, 0), "target_map": "hollow_earth_3", "target_spawn": "SpawnPoint", "label": "Fenda Ressonante ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -24)},
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, 0), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (14, 0, 0), "mid": "shadow_weaver", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (0, 0, 12), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (0, 0, -12), "mid": "shadow_weaver", "stage": 2, "count": 1},
            {"name": "Pack5", "pos": (0, 0, 0), "mid": "living_crystal", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.35, 0.45, 0.60, 1)",
        env_light_energy=0.65,
    )
    write_zone_def("hollow_earth_2", "ZONE_HOLLOW_EARTH_2_NAME", 46, 51, ["hollow_earth_1", "hollow_earth_3"], kind=2, combat=True, stage_cap=3)

    # 6. Dungeon Floor 3: hollow_earth_3 (Labirinto de Obsidiana)
    generate_map_scene(
        map_id="hollow_earth_3",
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
            {"name": "ToFloor2", "pos": (0, 1, 30), "target_map": "hollow_earth_2", "target_spawn": "DescentLanding", "label": "Subir Fenda (F2) ⇑"},
            {"name": "ToFloor4", "pos": (0, 1, -32), "target_map": "hollow_earth_4", "target_spawn": "SpawnPoint", "label": "Descer Ninho das Tecelãs (F4) ⇓"},
            {"name": "ObsidianChamber", "pos": (-30, 1, -12), "target_map": "hollow_earth_4", "target_spawn": "SpawnPoint", "label": "Caminho de Obsidiana ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -26)},
        spawns=[
            {"name": "Pack1", "pos": (-14, 0, -4), "mid": "shadow_weaver", "stage": 2, "count": 2},
            {"name": "Pack2", "pos": (14, 0, -4), "mid": "living_crystal", "stage": 2, "count": 2},
            {"name": "Pack3", "pos": (0, 0, 10), "mid": "shadow_weaver", "stage": 2, "count": 4},
            {"name": "Pack4", "pos": (0, 0, -18), "mid": "living_crystal", "stage": 2, "count": 4},
            {"name": "Pack5", "pos": (-12, 0, 16), "mid": "shadow_weaver", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.30, 0.40, 0.55, 1)",
        env_light_energy=0.6,
    )
    write_zone_def("hollow_earth_3", "ZONE_HOLLOW_EARTH_3_NAME", 48, 54, ["hollow_earth_2", "hollow_earth_4"], kind=2, combat=True, stage_cap=3)

    # 7. Dungeon Floor 4: hollow_earth_4 (Ninho das Tecelãs)
    generate_map_scene(
        map_id="hollow_earth_4",
        rooms=[(0, 22, 16), (0, -20, 18), (-24, 0, 15), (24, 0, 15)],
        routes=[
            [(0, 22), (0, -20)],
            [(0, 22), (-24, 0)],
            [(0, 22), (24, 0)],
            [(-24, 0), (0, -20)],
            [(24, 0), (0, -20)],
        ],
        width=5.0,
        pillars=[(-10, 8), (10, 8), (-10, -10), (10, -10)],
        spawn_pos=(0, 0, 24),
        portals=[
            {"name": "ToFloor3", "pos": (0, 1, 28), "target_map": "hollow_earth_3", "target_spawn": "DescentLanding", "label": "Subir Labirinto (F3) ⇑"},
            {"name": "ToFloor5", "pos": (0, 1, -28), "target_map": "hollow_earth_5", "target_spawn": "SpawnPoint", "label": "Descer Câmara do Titã (F5) ⇓"},
            {"name": "WebPassage", "pos": (28, 1, 0), "target_map": "hollow_earth_5", "target_spawn": "SpawnPoint", "label": "Túnel das Teias Profundas ⇓"},
        ],
        extra_markers={"DescentLanding": (0, 0, -22)},
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 0), "mid": "shadow_weaver", "stage": 2, "count": 2},
            {"name": "Pack2", "pos": (12, 0, 0), "mid": "living_crystal", "stage": 2, "count": 2},
            {"name": "Pack3", "pos": (0, 0, 8), "mid": "shadow_weaver", "stage": 2, "count": 4},
            {"name": "Pack4", "pos": (-12, 0, -12), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack5", "pos": (12, 0, -12), "mid": "shadow_weaver", "stage": 2, "count": 3},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.28, 0.35, 0.50, 1)",
        env_light_energy=0.55,
    )
    write_zone_def("hollow_earth_4", "ZONE_HOLLOW_EARTH_4_NAME", 50, 56, ["hollow_earth_3", "hollow_earth_5"], kind=2, combat=True, stage_cap=3)

    # 8. Dungeon Floor 5: hollow_earth_5 (Câmara do Titã - Boss Floor)
    generate_map_scene(
        map_id="hollow_earth_5",
        rooms=[(0, 20, 16), (0, -18, 24), (-24, 0, 14), (24, 0, 14)],
        routes=[
            [(0, 20), (0, -18)],
            [(0, 20), (-24, 0)],
            [(0, 20), (24, 0)],
            [(-24, 0), (0, -18)],
            [(24, 0), (0, -18)],
        ],
        width=5.4,
        pillars=[(-12, 4), (12, 4), (-12, -14), (12, -14)],
        spawn_pos=(0, 0, 22),
        portals=[
            {"name": "ToFloor4", "pos": (0, 1, 26), "target_map": "hollow_earth_4", "target_spawn": "DescentLanding", "label": "Subir Ninho (F4) ⇑"},
            {"name": "SurfaceEscapePortal", "pos": (0, 1, -34), "target_map": "hollow_mountain_gate", "target_spawn": "HollowReturn", "label": "Fuga para a Superfície ⇑", "is_escape": True, "interact_id": "hollow_earth_5_escape"},
            {"name": "SideGallery", "pos": (28, 1, 0), "target_map": "hollow_earth_4", "target_spawn": "DescentLanding", "label": "Retorno ao Ninho ⇑"},
        ],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 0), "mid": "living_crystal", "stage": 2, "count": 2},
            {"name": "Pack2", "pos": (12, 0, 0), "mid": "shadow_weaver", "stage": 2, "count": 2},
            {"name": "Pack3", "pos": (0, 0, 8), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack4", "pos": (-12, 0, -12), "mid": "shadow_weaver", "stage": 2, "count": 4},
            {"name": "Pack5", "pos": (12, 0, -12), "mid": "deep_titan", "stage": 2, "count": 1},
        ],
        boss_lairs=[
            {"name": "deep_titan_lair", "pos": (0, 0, -22), "mid": "deep_titan", "radius_cells": 10, "respawn_sec": 600.0}
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.25, 0.30, 0.45, 1)",
        env_light_energy=0.5,
    )
    write_zone_def("hollow_earth_5", "ZONE_HOLLOW_EARTH_5_NAME", 54, 60, ["hollow_earth_4", "hollow_mountain_gate"], kind=2, combat=True, boss_allowed=True, stage_cap=3)

    # 9. Update world.csv translations
    world_tr = [
        ("ZONE_HOLLOW_MOUNTAIN_TRAIL_NAME", "Serra do Sumidouro - Trilha dos Cristais"),
        ("ZONE_HOLLOW_MOUNTAIN_GORGE_NAME", "Garganta do Abismo"),
        ("ZONE_HOLLOW_MOUNTAIN_GATE_NAME", "Boca do Sumidouro"),
        ("ZONE_HOLLOW_EARTH_1_NAME", "Túneis da Terra Oca - Galerias de Cristal (F1)"),
        ("ZONE_HOLLOW_EARTH_2_NAME", "Túneis da Terra Oca - Fenda dos Ecos (F2)"),
        ("ZONE_HOLLOW_EARTH_3_NAME", "Túneis da Terra Oca - Labirinto de Obsidiana (F3)"),
        ("ZONE_HOLLOW_EARTH_4_NAME", "Túneis da Terra Oca - Ninho das Tecelãs (F4)"),
        ("ZONE_HOLLOW_EARTH_5_NAME", "Túneis da Terra Oca - Câmara do Titã (F5)"),
    ]
    wg.csv_add("localization/world.csv", world_tr)


if __name__ == "__main__":
    print("=== Building Os Túneis da Terra Oca Ecosystem ===")
    build_hollow_monsters()
    build_exclusive_items()
    build_hollow_earth_maps()
    wg.finish(HOLLOW_MAPS, "hollow_earth")
    print("=== Os Túneis da Terra Oca Successfully Built ===")
