#!/usr/bin/env python3
"""Build the full Ratanabá ecosystem expansion:
1. City 2: Serra Dourada, a Serra Resplandecente (city_serra_dourada)
2. Selva de Ratanabá Approach Region (3 maps):
   - jungle_ratanaba_trail (Trilha das Pirâmides)
   - jungle_ratanaba_waterfall (Igarapé dos Glifos)
   - jungle_ratanaba_gate (Escadaria Submersa / Portal das Ruínas)
3. Ruínas de Ratanabá Dungeon (4 floors):
   - ruins_ratanaba_1 (Vestíbulo dos Glifos)
   - ruins_ratanaba_2 (Salão dos Sentinelas)
   - ruins_ratanaba_3 (Câmara das Serpentes de Cristal)
   - ruins_ratanaba_4 (Sanctum do Arquiteto)
4. Exclusive drop equipment (drop-only, buy_price = 0, exclusive_drop_zone = &"ruins_ratanaba"):
   - diadema_de_glifos (Head)
   - couraca_de_placas_runicas (Body)
   - manoplas_do_construtor (Gloves)
   - sandalias_de_pedra_pomes (Feet)
   - egide_prismatica (Shield/Offhand)
   - anel_do_circuito_antigo (Accessory)
   - oleo_runico (Consumable)
5. Update drop tables for Ratanabá monsters to include exclusive gear and update existing weapons/crendices.
6. Connect split_sky_plateau_summit to city_serra_dourada.
7. Localizations across items.csv, zones.csv, and world.csv.
"""

from pathlib import Path
import math
import random
import zlib
import re

import worldgen as wg

GAME_DIR = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------------------
# Helper: Distance to segment for corridor path generation
# ---------------------------------------------------------------------------
def dist_segment(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dz * dz
    if denom == 0:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / denom))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)


# ---------------------------------------------------------------------------
# Map Generator Engine
# ---------------------------------------------------------------------------
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
    ground_mat: str = "res://assets/environment/painted/materials/mat_ground_paving.tres",
    theme: str = "ruins",
    env_light_color: str = "Color(0.2, 0.65, 0.85, 1)",
    env_light_energy: float = 0.8,
    extra_markers: dict = None,
):
    boss_lairs = boss_lairs or []
    npc_points = npc_points or []
    extra_markers = extra_markers or {}

    # Deep copy routes and connect all key locations to nearest room
    routes = [list(r) for r in routes]
    nearest_spawn_rm = min(rooms, key=lambda r: math.hypot(spawn_pos[0] - r[0], spawn_pos[1] - r[1]))
    routes.append([(nearest_spawn_rm[0], nearest_spawn_rm[1]), (spawn_pos[0], spawn_pos[1])])

    for p in portals:
        pos = (p["pos"][0], p["pos"][1])
        nearest_p_rm = min(rooms, key=lambda r: math.hypot(pos[0] - r[0], pos[1] - r[1]))
        routes.append([(nearest_p_rm[0], nearest_p_rm[1]), pos])

    for mpos in extra_markers.values():
        nearest_m_rm = min(rooms, key=lambda r: math.hypot(mpos[0] - r[0], mpos[1] - r[1]))
        routes.append([(nearest_m_rm[0], nearest_m_rm[1]), (mpos[0], mpos[1])])

    for bl in boss_lairs:
        blpos = (bl["pos"][0], bl["pos"][1])
        nearest_bl_rm = min(rooms, key=lambda r: math.hypot(blpos[0] - r[0], blpos[1] - r[1]))
        routes.append([(nearest_bl_rm[0], nearest_bl_rm[1]), blpos])

    # Calculate discrete 2m grid walkable cells
    cells = set()
    for x in range(-56, 56, 2):
        for z in range(-56, 56, 2):
            p = (x + 1, z + 1)
            in_room = any(math.hypot(p[0] - cx, p[1] - cz) < r for cx, cz, r in rooms)
            in_corridor = any(dist_segment(p, a, b) < width for route in routes for a, b in zip(route, route[1:]))
            if in_room or in_corridor:
                cells.add((x, z))

    # Remove pillars
    cells = {p for p in cells if all(math.hypot(p[0] + 1 - px, p[1] + 1 - pz) > 3.2 for px, pz in pillars)}

    # Rules shared by every generator (worldgen / validate_world): fail loudly here.
    wg.require_res(ground_mat, f"{map_id}: ground material")
    for sp in spawns:
        if sp.get("stage", 1) >= 3:
            raise wg.WorldGenError(f"{map_id} {sp['name']}: stage {sp['stage']} only in boss_lairs")
    for p in portals:
        if p.get("gate") and not boss_lairs:
            raise wg.WorldGenError(f"{map_id} {p['name']}: one-way escape needs a boss lair on the map")

    def blocked(c):
        return any(math.hypot(c[0] + 1 - px, c[1] + 1 - pz) <= 3.2 for px, pz in pillars)

    targets = [tuple(p["pos"]) for p in portals] + [tuple(v) for v in extra_markers.values()]
    targets += [tuple(b["pos"]) for b in boss_lairs] + [tuple(n["pos"]) for n in npc_points]
    if altar_pos is not None:
        targets.append((altar_pos[0], altar_pos[1] + 2.5))
    wg.ensure_connected(cells, spawn_pos, targets, blocked=blocked, label=map_id)
    reach = wg.component(cells, wg.cell_of(*spawn_pos))

    resources = []
    nodes = []

    def res(kind, key, body):
        resources.append(f'[sub_resource type="{kind}" id="{key}"]\n{body}\n')

    def node(name, kind, parent=".", body=""):
        p_attr = f' parent="{parent}"' if parent else ""
        nodes.append(f'[node name="{name}" type="{kind}"{p_attr}]\n{body}\n')

    def marker(name, pos, parent=".", meta=""):
        meta_str = f"\n{meta}" if meta else ""
        node(name, "Marker3D", parent, f"position = Vector3({pos[0]}, 0, {pos[1]}){meta_str}")

    # Root
    node(map_id, "Node3D", "", f'script = ExtResource("map")\nmap_id = &"{map_id}"')

    # Environment
    res(
        "Environment",
        "env",
        f"""background_mode = 1
background_color = Color(0.01, 0.02, 0.03, 1)
ambient_light_source = 2
ambient_light_color = {env_light_color}
ambient_light_energy = {env_light_energy}
fog_enabled = true
fog_light_color = Color(0.02, 0.05, 0.07, 1)
fog_density = 0.0015""",
    )
    node("WorldEnvironment", "WorldEnvironment", ".", body='environment = SubResource("env")')

    node("Floor", "Node3D", ".")
    node("Decor", "Node3D", ".")
    node("Interactables", "Node3D", ".")
    node("Spawns", "Node3D", ".")
    node("NpcPoints", "Node3D", ".")

    # Floor geometry & static bodies
    row_id = 0
    for z in sorted({z for x, z in cells}):
        xs = sorted(x for x, zz in cells if zz == z)
        runs = []
        for x in xs:
            if runs and runs[-1][-1] + 2 == x:
                runs[-1].append(x)
            else:
                runs.append([x])
        for run in runs:
            key = f"floor_{row_id}"
            length = len(run) * 2
            res("BoxMesh", key, f"size = Vector3({length}, 3, 2)")
            res("BoxShape3D", key + "_shape", f"size = Vector3({length}, 3, 2)")
            node(
                key,
                "StaticBody3D",
                "Floor",
                f"position = Vector3({run[0] + length / 2}, -1.5, {z + 1})\ncollision_layer = 1\ncollision_mask = 0",
            )
            node("Surface", "MeshInstance3D", "Floor/" + key, f'mesh = SubResource("{key}")\nmaterial_override = ExtResource("ground_mat")')
            node("Collision", "CollisionShape3D", "Floor/" + key, f'shape = SubResource("{key}_shape")')
            row_id += 1

    # Navigation mesh
    res("NavigationMesh", "nav", wg.navmesh_body(cells))
    node("NavigationRegion3D", "NavigationRegion3D", ".", body='navigation_mesh = SubResource("nav")')

    # Spawn marker
    marker("SpawnPoint", spawn_pos, ".")
    for mname, mpos in extra_markers.items():
        marker(mname, mpos, ".")

    # Viewpoint
    node("Viewpoint1", "Marker3D", ".", body=f"position = Vector3({spawn_pos[0]}, 55, {spawn_pos[1] + 24})\nrotation_degrees = Vector3(-52, 0, 0)")

    # Decor: boundary rocks & scenery
    rng = random.Random(zlib.crc32(map_id.encode()))  # stable between runs (hash() is salted)
    boundary = sorted({(x + dx, z + dz) for x, z in cells for dx, dz in [(2, 0), (-2, 0), (0, 2), (0, -2)] if (x + dx, z + dz) not in cells})
    for i, (x, z) in enumerate(boundary):
        if i % 3:
            continue
        sy = rng.uniform(5.5, 9.5)
        node(
            f"WallRock{i}",
            "MeshInstance3D",
            "Decor",
            f'position = Vector3({x + 1}, -0.3, {z + 1})\nscale = Vector3(2.5, {sy}, 2.5)\nrotation_degrees = Vector3(0, {rng.randrange(360)}, 0)\nmesh = ExtResource("rock")\nmaterial_override = ExtResource("rock_mat")',
        )

    # Pillars
    for i, (px, pz) in enumerate(pillars):
        node(
            f"Pillar{i}",
            "MeshInstance3D",
            "Decor",
            f'position = Vector3({px}, -0.5, {pz})\nscale = Vector3(3.0, 8.5, 3.0)\nmesh = ExtResource("rock")\nmaterial_override = ExtResource("rock_mat")',
        )

    # Crystals & lights for rooms
    res(
        "StandardMaterial3D",
        "crystal_mat",
        "albedo_color = Color(0.18, 0.85, 0.92, 1)\nemission_enabled = true\nemission = Color(0.1, 0.55, 0.75, 1)\nemission_energy_multiplier = 1.6",
    )
    for i, (rx, rz, r) in enumerate(rooms):
        node(
            f"CrystalCluster{i}",
            "MeshInstance3D",
            "Decor",
            f'position = Vector3({rx + r - 3}, 0, {rz})\nmesh = ExtResource("crystal")\nmaterial_override = SubResource("crystal_mat")',
        )
        node(
            f"GlowLight{i}",
            "OmniLight3D",
            "Decor",
            f"position = Vector3({rx}, 4.5, {rz})\nlight_color = Color(0.2, 0.75, 0.95, 1)\nlight_energy = 1.5\nomni_range = {r + 8}",
        )

    # Custom altar if provided
    if altar_pos is not None:
        res("CylinderShape3D", "altar_shape", "radius = 2.0\nheight = 1.5")
        res("CylinderMesh", "altar_mesh", "top_radius = 2.0\nbottom_radius = 2.5\nheight = 1.2")
        node(
            "altar_crendice",
            "Area3D",
            "Interactables",
            f"""position = Vector3({altar_pos[0]}, 0.6, {altar_pos[1]})
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"altar_crendice"
metadata/target_id = "m:altar_crendice"
metadata/interact_type = &"altar_crendice"
metadata/approach_position = Vector3({altar_pos[0]}, 0, {altar_pos[1] + 2.5})""",
        )
        node("Shape", "CollisionShape3D", "Interactables/altar_crendice", 'shape = SubResource("altar_shape")')
        node("Mesh", "MeshInstance3D", "Interactables/altar_crendice", 'mesh = SubResource("altar_mesh")\nmaterial_override = ExtResource("rock_mat")')
        node("Name", "Label3D", "Interactables/altar_crendice", 'position = Vector3(0, 1.8, 0)\nbillboard = 1\nfont_size = 40\npixel_size = 0.015\ntext = "Altar de Crendice"')

    # Portals
    res("BoxShape3D", "portal_shape", "size = Vector3(4, 4, 3)")
    for p in portals:
        name = p["name"]
        p_id = p["id"]
        pos = p["pos"]
        dest = p["dest"]
        target_spawn = p.get("spawn", "SpawnPoint")
        label = p.get("label", dest)
        gate = p.get("gate", False)
        req_boss = p.get("requires_boss", False) or gate  # one-way exits are boss escapes

        node(
            name,
            "Area3D",
            "Interactables",
            f"""position = Vector3({pos[0]}, 1, {pos[1]})
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"{p_id}"
metadata/target_id = "m:{p_id}"
metadata/interact_type = &"portal"
metadata/target_map = &"{dest}"
metadata/target_spawn = &"{target_spawn}"
metadata/approach_position = Vector3({pos[0]}, 0, {pos[1]})
metadata/one_way = {'true' if gate else 'false'}
metadata/requires_boss_victory = {'true' if req_boss else 'false'}""",
        )
        node("Shape", "CollisionShape3D", "Interactables/" + name, 'shape = SubResource("portal_shape")')
        node("Name", "Label3D", "Interactables/" + name, f'position = Vector3(0, 3, 0)\nbillboard = 1\nfont_size = 42\npixel_size = 0.015\ntext = "{label}"')

    # Spawns
    for sp in spawns:
        sname = sp["name"]
        raw_pos = sp["pos"]
        # Centre of the nearest cell the SpawnPoint reaches, with walkable cells around it (pack radius).
        c = wg.cell_of(*raw_pos)
        if c in reach and wg.is_interior(reach, c):
            spos = wg.cell_center(c)
        else:
            spos = wg.snap_to_walkable(reach, raw_pos[0], raw_pos[1], label=f"{map_id} {sname}")
        spos = (int(spos[0]) if spos[0] == int(spos[0]) else spos[0], int(spos[1]) if spos[1] == int(spos[1]) else spos[1])

        mid = sp["monster_id"]
        stage = sp.get("stage", 1)
        count = sp.get("count", 3)
        radius = sp.get("radius", 3)
        respawn = sp.get("respawn", 120.0)
        marker(
            sname,
            spos,
            "Spawns",
            f'metadata/monster_id = &"{mid}"\nmetadata/stage = {stage}\nmetadata/count = {count}\nmetadata/radius_cells = {radius}\nmetadata/respawn_sec = {respawn}',
        )

    # Boss Lairs
    if boss_lairs:
        node("BossLairs", "Node3D", ".")
        for bl in boss_lairs:
            bname = bl["name"]
            bpos = bl["pos"]
            mid = bl["monster_id"]
            radius = bl.get("radius", 8)
            respawn = bl.get("respawn", 600.0)
            marker(
                bname,
                bpos,
                "BossLairs",
                f'metadata/monster_id = &"{mid}"\nmetadata/radius_cells = {radius}\nmetadata/respawn_sec = {respawn}',
            )

    # NPC Points
    for npc in npc_points:
        nname = npc["name"]
        npos = npc["pos"]
        yaw = npc.get("yaw", 0.0)
        extra = "".join(f"\n{line}" for line in npc.get("meta", []))
        marker(nname, npos, "NpcPoints", f"metadata/facing_yaw = {yaw}{extra}")

    ext = f"""[ext_resource type="Script" path="res://scripts/shared/map.gd" id="map"]
[ext_resource type="Material" path="{ground_mat}" id="ground_mat"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock.tres" id="rock_mat"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_moss_a.res" id="rock"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/crystal_cluster.res" id="crystal"]
"""
    dest_path = GAME_DIR / "scenes/maps" / f"{map_id}.tscn"
    wg.write_text(
        dest_path,
        f"[gd_scene load_steps={len(resources) + 6} format=3]\n\n" + ext + "\n" + "\n".join(resources + nodes),
    )
    print(f"Scene {map_id}.tscn written with {len(cells)} walkable tiles, {row_id} floor runs.")
    return len(cells)


# ---------------------------------------------------------------------------
# Helper: Write ZoneDef .tres file
# ---------------------------------------------------------------------------
def write_zone_def(
    map_id: str,
    name_key: str,
    kind: int,
    region_id: str,
    lvl_min: int,
    lvl_max: int,
    connected_maps: list,
    combat_allowed: bool = True,
    grave_on_death: bool = True,
    bosses_allowed: bool = False,
    stage_cap: int = 3,
):
    conn_str = ", ".join(f'&"{m}"' for m in connected_maps)
    content = f"""[gd_resource type="Resource" script_class="ZoneDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/zone_def.gd" id="zone"]

[resource]
script = ExtResource("zone")
map_id = &"{map_id}"
kind = {kind}
name_key = "{name_key}"
region_id = &"{region_id}"
recommended_level_min = {lvl_min}
recommended_level_max = {lvl_max}
combat_allowed = {'true' if combat_allowed else 'false'}
grave_on_death = {'true' if grave_on_death else 'false'}
monster_stage_cap = {min(3, max(1, stage_cap))}
bosses_allowed = {'true' if bosses_allowed else 'false'}
connected_maps = Array[StringName]([{conn_str}])
"""
    dest_path = GAME_DIR / "data/zones" / f"{map_id}.tres"
    wg.write_text(dest_path, content)
    print(f"ZoneDef {map_id}.tres written.")


# ---------------------------------------------------------------------------
# 1. Build Exclusive Items
# ---------------------------------------------------------------------------
def build_exclusive_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)

    items = [
        {
            "id": "diadema_de_glifos",
            "name_key": "ITEM_DIADEMA_GLIFOS_NAME",
            "desc_key": "ITEM_DIADEMA_GLIFOS_DESC",
            "icon": "res://assets/items/icons/icon_item_ipe_flower_crown.png",
            "type": 3,  # HEAD
            "rarity": 2,  # RARE
            "sell_price": 260,
            "stats": {"def": 12, "mdef": 18, "int": 5},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "couraca_de_placas_runicas",
            "name_key": "ITEM_COURACA_PLACAS_RUNICAS_NAME",
            "desc_key": "ITEM_COURACA_PLACAS_RUNICAS_DESC",
            "icon": "res://assets/items/icons/icon_item_leather_jerkin.png",
            "type": 4,  # BODY
            "rarity": 2,  # RARE
            "sell_price": 390,
            "stats": {"def": 32, "mdef": 14, "vit": 4, "str": 3},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "manoplas_do_construtor",
            "name_key": "ITEM_MANOPLAS_CONSTRUTOR_NAME",
            "desc_key": "ITEM_MANOPLAS_CONSTRUTOR_DESC",
            "icon": "res://assets/items/icons/icon_item_ribbon_bracelet.png",
            "type": 8,  # GLOVES
            "rarity": 2,  # RARE
            "sell_price": 220,
            "stats": {"def": 10, "atk": 8, "str": 3},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "sandalias_de_pedra_pomes",
            "name_key": "ITEM_SANDALIAS_PEDRA_POMES_NAME",
            "desc_key": "ITEM_SANDALIAS_PEDRA_POMES_DESC",
            "icon": "res://assets/items/icons/icon_item_walking_boots.png",
            "type": 5,  # FEET
            "rarity": 2,  # RARE
            "sell_price": 200,
            "stats": {"def": 8, "mdef": 10, "dex": 4},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "egide_prismatica",
            "name_key": "ITEM_EGIDE_PRISMATICA_NAME",
            "desc_key": "ITEM_EGIDE_PRISMATICA_DESC",
            "icon": "res://assets/items/icons/icon_item_leather_shield.png",
            "type": 2,  # OFFHAND
            "rarity": 2,  # RARE
            "sell_price": 330,
            "stats": {"def": 24, "mdef": 20},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "anel_do_circuito_antigo",
            "name_key": "ITEM_ANEL_CIRCUITO_ANTIGO_NAME",
            "desc_key": "ITEM_ANEL_CIRCUITO_ANTIGO_DESC",
            "icon": "res://assets/items/icons/icon_item_seed_necklace.png",
            "type": 6,  # ACCESSORY
            "rarity": 2,  # RARE
            "sell_price": 290,
            "stats": {"matk": 16, "int": 4, "spi": 3},
            "exclusive": "ruins_ratanaba",
        },
        {
            "id": "oleo_runico",
            "name_key": "ITEM_OLEO_RUNICO_NAME",
            "desc_key": "ITEM_OLEO_RUNICO_DESC",
            "icon": "res://assets/items/icons/icon_item_potion_hp_medium.png",
            "type": 0,  # CONSUMABLE
            "rarity": 1,  # UNCOMMON
            "stackable": True,
            "max_stack": 99,
            "sell_price": 60,
            "use_effect": {"heal_hp": 350, "heal_mp": 120},
            "exclusive": "ruins_ratanaba",
        },
    ]

    for item in items:
        iid = item["id"]
        stats_str = ""
        if "stats" in item:
            stat_entries = [f'&"{k}": {v}' for k, v in item["stats"].items()]
            stats_str = f"stats = Dictionary[StringName, int]({{\n" + ",\n".join(stat_entries) + "\n})\n"
        use_str = ""
        if "use_effect" in item:
            eff_entries = [f'&"{k}": {v}' for k, v in item["use_effect"].items()]
            use_str = f"use_effect = Dictionary[StringName, Variant]({{\n" + ",\n".join(eff_entries) + "\n})\n"

        content = f"""[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Texture2D" path="{item['icon']}" id="icon"]
[ext_resource type="Script" path="res://scripts/shared/data/item_def.gd" id="item"]

[resource]
script = ExtResource("item")
id = &"{iid}"
name_key = "{item['name_key']}"
desc_key = "{item['desc_key']}"
icon = ExtResource("icon")
type = {item['type']}
rarity = {item['rarity']}
stackable = {'true' if item.get('stackable', False) else 'false'}
max_stack = {item.get('max_stack', 1)}
buy_price = 0
sell_price = {item['sell_price']}
tradeable = true
exclusive_drop_zone = &"{item['exclusive']}"
{stats_str}{use_str}"""
        wg.write_text((items_dir / f"{iid}.tres"), content)
        print(f"Item {iid}.tres created.")

    # Update existing weapons & crendices to have exclusive_drop_zone = &"ruins_ratanaba" and buy_price = 0
    existing_exclusives = [
        "obsidian_machete.tres",
        "crystal_recurve_bow.tres",
        "ratanaba_energy_wand.tres",
        "biomechanic_mace.tres",
        "figa_de_obsidiana.tres",
        "prisma_da_serpente.tres",
        "coracao_obsidiana_arquiteto.tres",
    ]
    for filename in existing_exclusives:
        p = items_dir / filename
        if p.exists():
            txt = p.read_text(encoding="utf-8")
            if "exclusive_drop_zone" not in txt:
                txt = txt.replace(
                    'tradeable = true\n',
                    'tradeable = true\nbuy_price = 0\nexclusive_drop_zone = &"ruins_ratanaba"\n',
                )
                wg.write_text(p, txt)
                print(f"Updated {filename} with exclusive drop zone.")


# ---------------------------------------------------------------------------
# 2. Update Monster Defs Drop Tables
# ---------------------------------------------------------------------------
def update_monster_drops():
    mon_dir = GAME_DIR / "data/monsters"

    # ratanaba_sentinel
    sentinel_file = mon_dir / "ratanaba_sentinel.tres"
    if sentinel_file.exists():
        txt = sentinel_file.read_text(encoding="utf-8")
        # Ensure exclusive drops in drops array for stage 2 and 3
        if "manoplas_do_construtor" not in txt:
            txt = txt.replace(
                '&"figa_de_obsidiana": 0.025',
                '&"figa_de_obsidiana": 0.025,\n&"manoplas_do_construtor": 0.04,\n&"couraca_de_placas_runicas": 0.02,\n&"oleo_runico": 0.08',
            )
            wg.write_text(sentinel_file, txt)
            print("Updated ratanaba_sentinel drops.")

    # crystal_serpent
    serpent_file = mon_dir / "crystal_serpent.tres"
    if serpent_file.exists():
        txt = serpent_file.read_text(encoding="utf-8")
        if "sandalias_de_pedra_pomes" not in txt:
            txt = txt.replace(
                '&"prisma_da_serpente": 0.02',
                '&"prisma_da_serpente": 0.02,\n&"sandalias_de_pedra_pomes": 0.04,\n&"egide_prismatica": 0.03,\n&"oleo_runico": 0.08',
            )
            wg.write_text(serpent_file, txt)
            print("Updated crystal_serpent drops.")

    # ratanaba_architect
    architect_file = mon_dir / "ratanaba_architect.tres"
    if architect_file.exists():
        txt = architect_file.read_text(encoding="utf-8")
        if "diadema_de_glifos" not in txt:
            txt = txt.replace(
                '&"coracao_obsidiana_arquiteto": 0.0001',
                '&"coracao_obsidiana_arquiteto": 0.0001,\n&"diadema_de_glifos": 0.20,\n&"anel_do_circuito_antigo": 0.20',
            )
            wg.write_text(architect_file, txt)
            print("Updated ratanaba_architect drops.")


# ---------------------------------------------------------------------------
# 3. Build City 2: city_serra_dourada
# ---------------------------------------------------------------------------
RATANABA_MAPS = ["city_serra_dourada", "jungle_ratanaba_trail", "jungle_ratanaba_waterfall", "jungle_ratanaba_gate",
                 "ruins_ratanaba_1", "ruins_ratanaba_2", "ruins_ratanaba_3", "ruins_ratanaba_4",
                 "split_sky_plateau_summit"]


def build_city_serra_dourada():
    rooms = [
        (0, 0, 16.0),     # Central Plaza
        (0, 36, 9.0),     # South Terraced Gate (towards Chapada)
        (38, -20, 9.0),   # North-East Gate (towards Ratanabá)
        (-38, -20, 9.0),  # North-West Gate (towards Cidade de Z)
        (0, -38, 8.5),    # North Gate (towards Arraial do Sumidouro)
    ]
    routes = [
        [(0, 36), (0, 0)],
        [(0, 0), (38, -20)],
        [(0, 0), (-38, -20)],
        [(0, 0), (0, -38)],
        [(-38, -20), (0, -38), (38, -20)],  # Upper perimeter promenade
    ]
    width = 4.2
    pillars = [(-10, 10), (10, 10), (-10, -10), (10, -10)]
    spawn_pos = (0, 0)

    portals = [
        {
            "name": "GateChapada",
            "id": "serra_dourada_gate_chapada",
            "pos": (0, 38),
            "dest": "split_sky_plateau_summit",
            "spawn": "NorthArrival",
            "label": "Chapada do Céu Partido ↓",
        },
        {
            "name": "GateRatanaba",
            "id": "serra_dourada_gate_ratanaba",
            "pos": (40, -20),
            "dest": "jungle_ratanaba_trail",
            "spawn": "SpawnPoint",
            "label": "Selva de Ratanabá →",
        },
        {
            "name": "GateSumidouro",
            "id": "city_to_sumidouro",
            "pos": (0, -40),
            "dest": "city_sumidouro",
            "spawn": "SerraDouradaReturn",
            "label": "Estrada do Sumidouro ↑",
        },
        {
            "name": "GateZ",
            "id": "serra_dourada_gate_z",
            "pos": (-40, -20),
            "dest": "jungle_z_trail",
            "spawn": "SpawnPoint",
            "label": "Trilha do Sertão ←",
        },
    ]

    npc_points = [
        {"name": "curandeira_joana", "pos": (6, 5), "yaw": -1.2},
        {"name": "mercador_serra_dourada", "pos": (8, -5), "yaw": 1.2},
        {"name": "artesao_goncalo", "pos": (-8, -5), "yaw": -0.8},
        {"name": "guarda_da_serra", "pos": (0, 30), "yaw": 3.14},
        # Dona Ana (WaystoneService): no centro da praça, olhando para o SpawnPoint; chegada em WaystoneArrival.
        {"name": "dona_ana", "pos": (0, -7), "yaw": 3.14, "meta": ['metadata/minimap_icon = &"shop"']},
    ]

    altar_pos = (-5, 4)

    extra_markers = {
        "SummitReturn": (0, 32),
        "RatanabaReturn": (34, -18),
        "SumidouroReturn": (0, -34),
        "ZReturn": (-34, -18),
        "WaystoneArrival": (0, -4),
    }

    generate_map_scene(
        map_id="city_serra_dourada",
        rooms=rooms,
        routes=routes,
        width=width,
        pillars=pillars,
        spawn_pos=spawn_pos,
        portals=portals,
        spawns=[],
        boss_lairs=[],
        npc_points=npc_points,
        altar_pos=altar_pos,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="city",
        env_light_color="Color(0.9, 0.8, 0.5, 1)",
        env_light_energy=1.1,
        extra_markers=extra_markers,
    )

    write_zone_def(
        map_id="city_serra_dourada",
        name_key="ZONE_SERRA_DOURADA_NAME",
        kind=0,  # CITY
        region_id="sabia",
        lvl_min=0,
        lvl_max=0,
        connected_maps=["split_sky_plateau_summit", "jungle_ratanaba_trail", "jungle_z_trail", "city_sumidouro"],
        combat_allowed=False,
        grave_on_death=False,
        bosses_allowed=False,
    )


# ---------------------------------------------------------------------------
# 4. Build Approach Region: Selva de Ratanabá (3 Maps)
# ---------------------------------------------------------------------------
def build_selva_ratanaba():
    # Map 1: jungle_ratanaba_trail (Trilha das Pirâmides) - Lvl 20-25
    rooms_1 = [
        (0, 36, 8.5),     # South entrance from Serra Dourada
        (0, 0, 11.0),     # Jungle Clearing
        (38, -20, 8.5),   # East clearing to Waterfall
        (-38, -20, 8.5),  # West clearing to Gate
        (36, 12, 7.5),    # River overlook
    ]
    routes_1 = [
        [(0, 36), (0, 0)],
        [(0, 0), (38, -20)],
        [(0, 0), (-38, -20)],
        [(0, 0), (36, 12)],
        [(36, 12), (38, -20)],  # Loop connecting riverbank to waterfall trail
    ]
    portals_1 = [
        {"name": "ToSabarabucu", "id": "jungle_trail_to_city", "pos": (0, 38), "dest": "city_serra_dourada", "spawn": "RatanabaReturn", "label": "Serra Dourada ↑"},
        {"name": "ToWaterfall", "id": "jungle_trail_to_waterfall", "pos": (40, -20), "dest": "jungle_ratanaba_waterfall", "spawn": "SpawnPoint", "label": "Igarapé dos Glifos →"},
        {"name": "ToGate", "id": "jungle_trail_to_gate", "pos": (-40, -20), "dest": "jungle_ratanaba_gate", "spawn": "FromTrail", "label": "Escadaria Submersa ←"},
        {"name": "ToRiverLoop", "id": "jungle_trail_river_shortcut", "pos": (38, 12), "dest": "jungle_ratanaba_waterfall", "spawn": "FromRiver", "label": "Vau do Rio"},
        {"name": "ToZShortcut", "id": "jungle_trail_to_z_shortcut", "pos": (40, -12), "dest": "jungle_z_trail", "spawn": "RatanabaShortcutLanding", "label": "Picada dos Bandeirantes ↗"},
    ]
    spawns_1 = [
        {"name": "Pack1", "pos": (-14, 16), "monster_id": "crystal_serpent", "stage": 1, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 16), "monster_id": "giant_anteater", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-18, -10), "monster_id": "spider_goliath", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack4", "pos": (18, -10), "monster_id": "crystal_serpent", "stage": 1, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack5", "pos": (0, -18), "monster_id": "maned_wolf", "stage": 2, "count": 2, "radius": 3, "respawn": 120.0},
    ]
    generate_map_scene(
        map_id="jungle_ratanaba_trail",
        rooms=rooms_1,
        routes=routes_1,
        width=3.8,
        pillars=[(-8, 8), (8, -8)],
        spawn_pos=(0, 32),
        portals=portals_1,
        spawns=spawns_1,
        extra_markers={"ZShortcutLanding": (37, -5)},
        ground_mat="res://assets/environment/painted/materials/mat_ground_dirt.tres",
        theme="jungle",
        env_light_color="Color(0.2, 0.7, 0.4, 1)",
        env_light_energy=0.9,
    )
    write_zone_def(
        map_id="jungle_ratanaba_trail",
        name_key="ZONE_JUNGLE_RATANABA_TRAIL_NAME",
        kind=2,  # HUNT
        region_id="sabia",
        lvl_min=20,
        lvl_max=25,
        connected_maps=["city_serra_dourada", "jungle_ratanaba_waterfall", "jungle_ratanaba_gate", "jungle_z_trail"],
        stage_cap=2,
    )

    # Map 2: jungle_ratanaba_waterfall (Igarapé dos Glifos) - Lvl 23-28
    rooms_2 = [
        (-32, 32, 8.5),   # Southwest entrance from Trail
        (0, 0, 13.0),     # Waterfall Basin Clearing
        (0, -38, 8.5),    # North route to Gate
        (36, 0, 8.0),     # East Grotto
    ]
    routes_2 = [
        [(-32, 32), (0, 0)],
        [(0, 0), (0, -38)],
        [(0, 0), (36, 0)],
        [(-32, 32), (-18, 12), (0, 0)],
        [(36, 0), (20, -22), (0, -38)],  # East grotto bypass to north gate
    ]
    portals_2 = [
        {"name": "ToTrail", "id": "jungle_waterfall_to_trail", "pos": (-34, 34), "dest": "jungle_ratanaba_trail", "spawn": "SpawnPoint", "label": "Trilha das Pirâmides ←"},
        {"name": "ToGate", "id": "jungle_waterfall_to_gate", "pos": (0, -40), "dest": "jungle_ratanaba_gate", "spawn": "FromWaterfall", "label": "Escadaria Submersa ↑"},
        {"name": "ToEastGrotto", "id": "jungle_waterfall_to_trail_alt", "pos": (38, 0), "dest": "jungle_ratanaba_trail", "spawn": "SpawnPoint", "label": "Trilha do Igarapé"},
    ]
    spawns_2 = [
        {"name": "Pack1", "pos": (-14, 14), "monster_id": "river_anaconda", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 14), "monster_id": "spider_goliath", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "harpy_eagle", "stage": 2, "count": 2, "radius": 4, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "spider_goliath", "stage": 2, "count": 2, "radius": 4, "respawn": 100.0},
        {"name": "Pack5", "pos": (24, 0), "monster_id": "black_caiman", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
    ]
    extra_markers_2 = {"FromRiver": (-10, 8)}
    generate_map_scene(
        map_id="jungle_ratanaba_waterfall",
        rooms=rooms_2,
        routes=routes_2,
        width=3.8,
        pillars=[(0, 0), (18, 0)],
        spawn_pos=(-28, 28),
        portals=portals_2,
        spawns=spawns_2,
        ground_mat="res://assets/environment/painted/materials/mat_ground_dirt.tres",
        theme="jungle",
        env_light_color="Color(0.15, 0.65, 0.55, 1)",
        env_light_energy=0.9,
        extra_markers=extra_markers_2,
    )
    write_zone_def(
        map_id="jungle_ratanaba_waterfall",
        name_key="ZONE_JUNGLE_RATANABA_WATERFALL_NAME",
        kind=2,  # HUNT
        region_id="sabia",
        lvl_min=23,
        lvl_max=28,
        connected_maps=["jungle_ratanaba_trail", "jungle_ratanaba_gate"],
        stage_cap=2,
    )

    # Map 3: jungle_ratanaba_gate (Escadaria Submersa / Portal das Ruínas) - Lvl 25-30
    rooms_3 = [
        (-30, 32, 8.5),   # Southwest arrival from Trail
        (30, 32, 8.5),    # Southeast arrival from Waterfall
        (0, 0, 13.0),     # Sunken Plaza before Dungeon
        (0, -32, 9.5),    # Great Arch Entrance to Ratanabá Dungeon
        (-38, 0, 7.5),    # West Canopy Lookout
    ]
    routes_3 = [
        [(-30, 32), (0, 0)],
        [(30, 32), (0, 0)],
        [(0, 0), (0, -32)],
        [(0, 0), (-38, 0)],
        [(-38, 0), (-20, -22), (0, -32)],  # Canopy shortcut to dungeon arch
    ]
    portals_3 = [
        {"name": "ToTrail", "id": "jungle_gate_to_trail", "pos": (-32, 34), "dest": "jungle_ratanaba_trail", "spawn": "SpawnPoint", "label": "Trilha das Pirâmides ↓"},
        {"name": "ToWaterfall", "id": "jungle_gate_to_waterfall", "pos": (32, 34), "dest": "jungle_ratanaba_waterfall", "spawn": "SpawnPoint", "label": "Igarapé dos Glifos ↘"},
        {"name": "ToDungeon", "id": "jungle_gate_to_dungeon", "pos": (0, -34), "dest": "ruins_ratanaba_1", "spawn": "SpawnPoint", "label": "Ruínas de Ratanabá [F1] ⇓"},
        {"name": "ToCanopyLoop", "id": "jungle_gate_canopy", "pos": (-40, 0), "dest": "jungle_ratanaba_trail", "spawn": "SpawnPoint", "label": "Atalho do Dossel"},
    ]
    spawns_3 = [
        {"name": "Pack1", "pos": (-14, 16), "monster_id": "shadow_jaguar", "stage": 1, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 16), "monster_id": "spider_goliath", "stage": 2, "count": 2, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-16, -10), "monster_id": "crystal_serpent", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack4", "pos": (16, -10), "monster_id": "ratanaba_sentinel", "stage": 1, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 14), "monster_id": "crystal_serpent", "stage": 1, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack6", "pos": (0, -14), "monster_id": "ratanaba_sentinel", "stage": 1, "count": 2, "radius": 3, "respawn": 100.0},
    ]
    extra_markers_3 = {
        "FromTrail": (-28, 28),
        "FromWaterfall": (28, 28),
        "RatanabaReturn": (0, -26),  # Boss escape arrival from F4!
    }
    generate_map_scene(
        map_id="jungle_ratanaba_gate",
        rooms=rooms_3,
        routes=routes_3,
        width=3.8,
        pillars=[(-8, -8), (8, -8)],
        spawn_pos=(0, 24),
        portals=portals_3,
        spawns=spawns_3,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="jungle",
        env_light_color="Color(0.18, 0.65, 0.6, 1)",
        env_light_energy=0.95,
        extra_markers=extra_markers_3,
    )
    write_zone_def(
        map_id="jungle_ratanaba_gate",
        name_key="ZONE_JUNGLE_RATANABA_GATE_NAME",
        kind=2,  # HUNT
        region_id="sabia",
        lvl_min=25,
        lvl_max=30,
        connected_maps=["jungle_ratanaba_trail", "jungle_ratanaba_waterfall", "ruins_ratanaba_1"],
        stage_cap=2,
    )


# ---------------------------------------------------------------------------
# 5. Build Ruínas de Ratanabá Dungeon (4 Floors)
# ---------------------------------------------------------------------------
def build_ruins_ratanaba_floors():
    # FLOOR 1: ruins_ratanaba_1 (Vestíbulo dos Glifos) - Lvl 24-28
    rooms_1 = [
        (0, 32, 9.0),      # Surface portal lobby
        (0, 0, 13.0),      # Grand Hypostyle Hall
        (-24, -28, 8.5),   # West Descent Chamber
        (24, -28, 8.5),    # East Descent Chamber
        (0, -18, 7.5),     # Central Pillar Room
    ]
    routes_1 = [
        [(0, 32), (0, 0)],
        [(0, 0), (-24, -28)],
        [(0, 0), (24, -28)],
        [(0, 0), (0, -18)],
        [(-24, -28), (0, -18), (24, -28)],  # Transverse connecting gallery
    ]
    portals_1 = [
        {"name": "SurfaceReturn", "id": "ratanaba_1_surface", "pos": (0, 34), "dest": "jungle_ratanaba_gate", "spawn": "RatanabaReturn", "label": "Superfície ↑"},
        {"name": "WestDescent", "id": "ratanaba_1_descent_west", "pos": (-24, -30), "dest": "ruins_ratanaba_2", "spawn": "WestAscent", "label": "↓ F2 · Galeria Oeste"},
        {"name": "EastDescent", "id": "ratanaba_1_descent_east", "pos": (24, -30), "dest": "ruins_ratanaba_2", "spawn": "EastAscent", "label": "↓ F2 · Galeria Leste"},
    ]
    spawns_1 = [
        {"name": "Pack1", "pos": (-14, 12), "monster_id": "ratanaba_sentinel", "stage": 1, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack2", "pos": (14, 12), "monster_id": "crystal_serpent", "stage": 1, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack3", "pos": (-16, -12), "monster_id": "ratanaba_sentinel", "stage": 1, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -12), "monster_id": "crystal_serpent", "stage": 1, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "ratanaba_sentinel", "stage": 1, "count": 2, "radius": 2, "respawn": 100.0},
        {"name": "Pack6", "pos": (0, -10), "monster_id": "crystal_serpent", "stage": 1, "count": 2, "radius": 2, "respawn": 100.0},
    ]
    extra_markers_1 = {
        "WestEntry": (-22, -24),
        "EastEntry": (22, -24),
    }
    generate_map_scene(
        map_id="ruins_ratanaba_1",
        rooms=rooms_1,
        routes=routes_1,
        width=3.6,
        pillars=[(-10, 10), (10, 10)],
        spawn_pos=(0, 30),
        portals=portals_1,
        spawns=spawns_1,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="ruins",
        env_light_color="Color(0.2, 0.7, 0.85, 1)",
        env_light_energy=0.85,
        extra_markers=extra_markers_1,
    )
    write_zone_def(
        map_id="ruins_ratanaba_1",
        name_key="ZONE_RUINS_RATANABA_F1_NAME",
        kind=2,
        region_id="sabia",
        lvl_min=24,
        lvl_max=28,
        connected_maps=["jungle_ratanaba_gate", "ruins_ratanaba_2"],
        stage_cap=2,
    )

    # FLOOR 2: ruins_ratanaba_2 (Salão dos Sentinelas) - Lvl 28-32
    rooms_2 = [
        (-24, 32, 8.5),   # West Ascent
        (24, 32, 8.5),    # East Ascent
        (0, 0, 14.0),     # Great Sentinel Colonnade
        (0, -34, 9.0),    # Main Descent to F3
        (32, 0, 8.0),     # Eastern Aqueduct Gallery
    ]
    routes_2 = [
        [(-24, 32), (0, 0)],
        [(24, 32), (0, 0)],
        [(0, 0), (0, -34)],
        [(0, 0), (32, 0)],
        [(32, 0), (20, -22), (0, -34)],  # Aqueduct bypass to descent
    ]
    portals_2 = [
        {"name": "WestAscent", "id": "ratanaba_2_ascent_west", "pos": (-24, 34), "dest": "ruins_ratanaba_1", "spawn": "WestEntry", "label": "↑ F1 · Galeria Oeste"},
        {"name": "EastAscent", "id": "ratanaba_2_ascent_east", "pos": (24, 34), "dest": "ruins_ratanaba_1", "spawn": "EastEntry", "label": "↑ F1 · Galeria Leste"},
        {"name": "MainDescent", "id": "ratanaba_2_descent_main", "pos": (0, -36), "dest": "ruins_ratanaba_3", "spawn": "MainAscent", "label": "↓ F3 · Câmara Prisma"},
        {"name": "SideDescent", "id": "ratanaba_2_descent_side", "pos": (34, 0), "dest": "ruins_ratanaba_3", "spawn": "SideAscent", "label": "↓ F3 · Aqueduto"},
    ]
    spawns_2 = [
        {"name": "Pack1", "pos": (-14, 12), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack2", "pos": (14, 12), "monster_id": "crystal_serpent", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "crystal_serpent", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 2, "radius": 2, "respawn": 100.0},
        {"name": "Pack6", "pos": (22, 0), "monster_id": "crystal_serpent", "stage": 2, "count": 2, "radius": 2, "respawn": 100.0},
    ]
    extra_markers_2 = {
        "WestAscent": (-22, 28),
        "EastAscent": (22, 28),
        "CentralEntry": (0, -28),
    }
    generate_map_scene(
        map_id="ruins_ratanaba_2",
        rooms=rooms_2,
        routes=routes_2,
        width=3.6,
        pillars=[(-10, 0), (10, 0)],
        spawn_pos=(0, 20),
        portals=portals_2,
        spawns=spawns_2,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="ruins",
        env_light_color="Color(0.25, 0.75, 0.85, 1)",
        env_light_energy=0.8,
        extra_markers=extra_markers_2,
    )
    write_zone_def(
        map_id="ruins_ratanaba_2",
        name_key="ZONE_RUINS_RATANABA_F2_NAME",
        kind=2,
        region_id="sabia",
        lvl_min=28,
        lvl_max=32,
        connected_maps=["ruins_ratanaba_1", "ruins_ratanaba_3"],
        stage_cap=2,
    )

    # FLOOR 3: ruins_ratanaba_3 (Câmara das Serpentes de Cristal) - Lvl 32-35
    rooms_3 = [
        (0, 32, 9.0),      # Main Ascent from F2
        (30, 20, 8.0),     # Side Ascent (Aqueduct)
        (0, 0, 15.0),      # Great Crystal Serpents Octagon
        (-24, -32, 8.5),   # Sanctum Grand Stairway Descent
        (24, -32, 8.5),    # Waterway Conduit Descent
    ]
    routes_3 = [
        [(0, 32), (0, 0)],
        [(30, 20), (0, 0)],
        [(0, 0), (-24, -32)],
        [(0, 0), (24, -32)],
        [(-24, -32), (0, -20), (24, -32)],  # Inner loop
    ]
    portals_3 = [
        {"name": "MainAscent", "id": "ratanaba_3_ascent_main", "pos": (0, 34), "dest": "ruins_ratanaba_2", "spawn": "CentralEntry", "label": "↑ F2 · Salão Principal"},
        {"name": "SideAscent", "id": "ratanaba_3_ascent_side", "pos": (32, 20), "dest": "ruins_ratanaba_2", "spawn": "CentralEntry", "label": "↑ F2 · Aqueduto"},
        {"name": "SanctumDescent", "id": "ratanaba_3_descent_sanctum", "pos": (-24, -34), "dest": "ruins_ratanaba_4", "spawn": "SanctumAscent", "label": "⇓ F4 · Sanctum do Arquiteto"},
        {"name": "WaterwayDescent", "id": "ratanaba_3_descent_waterway", "pos": (24, -34), "dest": "ruins_ratanaba_4", "spawn": "WaterwayAscent", "label": "⇓ F4 · Conduto de Energia"},
    ]
    spawns_3 = [
        {"name": "Pack1", "pos": (-14, 14), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 3, "radius": 3, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 14), "monster_id": "crystal_serpent", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "crystal_serpent", "stage": 2, "count": 3, "radius": 3, "respawn": 90.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 2, "radius": 2, "respawn": 90.0},
        {"name": "Pack6", "pos": (0, -12), "monster_id": "crystal_serpent", "stage": 2, "count": 2, "radius": 2, "respawn": 90.0},
    ]
    extra_markers_3 = {
        "MainAscent": (0, 28),
        "SideAscent": (26, 16),
        "DescentLanding": (0, -26),
    }
    generate_map_scene(
        map_id="ruins_ratanaba_3",
        rooms=rooms_3,
        routes=routes_3,
        width=3.6,
        pillars=[(-14, 0), (14, -8)],
        spawn_pos=(0, 24),
        portals=portals_3,
        spawns=spawns_3,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="ruins",
        env_light_color="Color(0.3, 0.8, 0.9, 1)",
        env_light_energy=0.75,
        extra_markers=extra_markers_3,
    )
    write_zone_def(
        map_id="ruins_ratanaba_3",
        name_key="ZONE_RUINS_RATANABA_F3_NAME",
        kind=2,
        region_id="sabia",
        lvl_min=32,
        lvl_max=35,
        connected_maps=["ruins_ratanaba_2", "ruins_ratanaba_4"],
        stage_cap=3,
        bosses_allowed=True,
    )

    # FLOOR 4: ruins_ratanaba_4 (Sanctum do Arquiteto) - Lvl 35-38 (BOSS FLOOR)
    rooms_4 = [
        (-20, 32, 8.5),   # Sanctum Ascent
        (20, 32, 8.5),    # Waterway Ascent
        (0, 0, 12.0),     # Grand Antechamber
        (0, -24, 16.0),   # Architect's Throne & Pyramid Sanctum
    ]
    routes_4 = [
        [(-20, 32), (0, 0)],
        [(20, 32), (0, 0)],
        [(0, 0), (0, -24)],
        [(-20, 32), (-14, 16), (0, 0)],
        [(20, 32), (14, 16), (0, 0)],
    ]
    portals_4 = [
        {"name": "SanctumAscent", "id": "ratanaba_4_ascent_sanctum", "pos": (-20, 34), "dest": "ruins_ratanaba_3", "spawn": "DescentLanding", "label": "↑ F3 · Escadaria"},
        {"name": "WaterwayAscent", "id": "ratanaba_4_ascent_waterway", "pos": (20, 34), "dest": "ruins_ratanaba_3", "spawn": "DescentLanding", "label": "↑ F3 · Conduto"},
        {
            "name": "SurfaceEscapePortal",
            "id": "ratanaba_4_escape",
            "pos": (0, -42),
            "dest": "jungle_ratanaba_gate",
            "spawn": "RatanabaReturn",
            "label": "Saída Rápida de Ratanabá · Superfície",
            "gate": True,
            "requires_boss": True,
        },
    ]
    boss_lairs_4 = [
        {"name": "architect", "pos": (0, -24), "monster_id": "ratanaba_architect", "radius": 8, "respawn": 600.0}
    ]
    spawns_4 = [
        {"name": "Pack1", "pos": (-16, 10), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 3, "radius": 3, "respawn": 120.0},
        {"name": "Pack2", "pos": (16, 10), "monster_id": "crystal_serpent", "stage": 2, "count": 3, "radius": 3, "respawn": 120.0},
        {"name": "Pack3", "pos": (-14, -14), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 1, "radius": 3, "respawn": 150.0},
        {"name": "Pack4", "pos": (14, -14), "monster_id": "crystal_serpent", "stage": 2, "count": 1, "radius": 3, "respawn": 150.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "ratanaba_sentinel", "stage": 2, "count": 2, "radius": 2, "respawn": 120.0},
        {"name": "Pack6", "pos": (0, -8), "monster_id": "crystal_serpent", "stage": 2, "count": 2, "radius": 2, "respawn": 120.0},
    ]
    extra_markers_4 = {
        "SanctumAscent": (-18, 28),
        "WaterwayAscent": (18, 28),
    }
    generate_map_scene(
        map_id="ruins_ratanaba_4",
        rooms=rooms_4,
        routes=routes_4,
        width=3.8,
        pillars=[(-14, -20), (14, -20)],
        spawn_pos=(0, 20),
        portals=portals_4,
        spawns=spawns_4,
        boss_lairs=boss_lairs_4,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        theme="ruins",
        env_light_color="Color(0.2, 0.85, 0.95, 1)",
        env_light_energy=0.9,
        extra_markers=extra_markers_4,
    )
    write_zone_def(
        map_id="ruins_ratanaba_4",
        name_key="ZONE_RUINS_RATANABA_F4_NAME",
        kind=2,
        region_id="sabia",
        lvl_min=35,
        lvl_max=38,
        connected_maps=["ruins_ratanaba_3", "jungle_ratanaba_gate"],
        stage_cap=3,
        bosses_allowed=True,
    )
    # The legacy single-map ruins_ratanaba (build_ratanaba.py) was replaced by these 4 floors.


# ---------------------------------------------------------------------------
# 6. Connect split_sky_plateau_summit to city_serra_dourada
# ---------------------------------------------------------------------------
def connect_summit_to_serra_dourada():
    zone_path = GAME_DIR / "data/zones/split_sky_plateau_summit.tres"
    if zone_path.exists():
        txt = zone_path.read_text(encoding="utf-8")
        if "city_serra_dourada" not in txt:
            txt = txt.replace(
                'connected_maps = Array[StringName]([&"split_sky_plateau_ridges"])',
                'connected_maps = Array[StringName]([&"split_sky_plateau_ridges", &"city_serra_dourada"])',
            )
            wg.write_text(zone_path, txt)
            print("Connected split_sky_plateau_summit.tres to city_serra_dourada.")

    map_path = GAME_DIR / "scenes/maps/split_sky_plateau_summit.tscn"
    if map_path.exists():
        txt = map_path.read_text(encoding="utf-8")
        if "to_serra_dourada" not in txt:
            portal_snippet = """
[node name="to_serra_dourada" type="Area3D" parent="Interactables"]
position = Vector3(0, 2, -38)
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"to_serra_dourada"
metadata/target_id = "m:to_serra_dourada"
metadata/interact_type = &"portal"
metadata/target_map = &"city_serra_dourada"
metadata/target_spawn = &"SummitReturn"
metadata/recommended_level = "Cidade"
metadata/approach_position = Vector3(0, 0, -38)

[node name="Shape" type="CollisionShape3D" parent="Interactables/to_serra_dourada"]
shape = SubResource("portal_shape")

[node name="Gate" type="MeshInstance3D" parent="Interactables/to_serra_dourada"]
rotation_degrees = Vector3(90, 0, 0)
mesh = SubResource("portal")
material_override = SubResource("portalmat")

[node name="Name" type="Label3D" parent="Interactables/to_serra_dourada"]
position = Vector3(0, 3.0, 0)
billboard = 1
font_size = 48
pixel_size = 0.015
text = "Serra Dourada ↑"
"""
            txt = txt.replace('[node name="Spawns" type="Node3D" parent="."]', portal_snippet + '\n[node name="Spawns" type="Node3D" parent="."]')
            wg.write_text(map_path, txt)
            print("Added portal to_serra_dourada in split_sky_plateau_summit.tscn.")


# ---------------------------------------------------------------------------
# 7. Update Localizations
# ---------------------------------------------------------------------------
NEW_LOCALIZATIONS = {
    "items.csv": [
        ("ITEM_DIADEMA_GLIFOS_NAME", "Diadema de Glifos"),
        ("ITEM_DIADEMA_GLIFOS_DESC", "Coroa ritualística esculpida em pedra reluzente de Ratanabá com glifos pulsantes. Aumenta inteligência e resistência mística."),
        ("ITEM_COURACA_PLACAS_RUNICAS_NAME", "Couraça de Placas Rúnicas"),
        ("ITEM_COURACA_PLACAS_RUNICAS_DESC", "Armadura peitoral pesada combinando placas vulcânicas de obsidiana e ligas antigas. Máxima solidez física e vitalidade."),
        ("ITEM_MANOPLAS_CONSTRUTOR_NAME", "Manoplas do Construtor"),
        ("ITEM_MANOPLAS_CONSTRUTOR_DESC", "Luvas pesadas reforçadas com juntas biomecânicas. Amplificam o impacto físico dos golpes."),
        ("ITEM_SANDALIAS_PEDRA_POMES_NAME", "Sandálias de Pedra-Pomes"),
        ("ITEM_SANDALIAS_PEDRA_POMES_DESC", "Calçado leve trabalhado a partir de rochas minerais porosas de Ratanabá. Concede passos firmes e agilidade."),
        ("ITEM_EGIDE_PRISMATICA_NAME", "Égide Prismática"),
        ("ITEM_EGIDE_PRISMATICA_DESC", "Escudo forjado com camadas de quartzo translúcido que refratam forças hostis e dissipam feitiços."),
        ("ITEM_ANEL_CIRCUITO_ANTIGO_NAME", "Anel do Circuito Antigo"),
        ("ITEM_ANEL_CIRCUITO_ANTIGO_DESC", "Aro de metal milenar com filamentos condutores que fluem a energia mágica do portador."),
        ("ITEM_OLEO_RUNICO_NAME", "Óleo Rúnico"),
        ("ITEM_OLEO_RUNICO_DESC", "Extrato alquímico refinado a partir de seiva da mata e pó rúnico de Ratanabá. Recupera HP e MP."),
    ],
    "zones.csv": [
        ("ZONE_SERRA_DOURADA_NAME", "Serra Dourada, a Serra Resplandecente"),
        ("ZONE_JUNGLE_RATANABA_TRAIL_NAME", "Selva de Ratanabá · Trilha das Pirâmides"),
        ("ZONE_JUNGLE_RATANABA_WATERFALL_NAME", "Selva de Ratanabá · Igarapé dos Glifos"),
        ("ZONE_JUNGLE_RATANABA_GATE_NAME", "Selva de Ratanabá · Escadaria Submersa"),
        ("ZONE_RUINS_RATANABA_F1_NAME", "Ruínas de Ratanabá · Vestíbulo dos Glifos [F1]"),
        ("ZONE_RUINS_RATANABA_F2_NAME", "Ruínas de Ratanabá · Salão dos Sentinelas [F2]"),
        ("ZONE_RUINS_RATANABA_F3_NAME", "Ruínas de Ratanabá · Câmara das Serpentes [F3]"),
        ("ZONE_RUINS_RATANABA_F4_NAME", "Ruínas de Ratanabá · Sanctum do Arquiteto [F4]"),
    ],
    "world.csv": [
        ("WA_SERRA_DOURADA", "Serra Dourada, a Serra Resplandecente"),
        ("WA_JUNGLE_RATANABA_TRAIL", "Trilha das Pirâmides"),
        ("WA_JUNGLE_RATANABA_WATERFALL", "Igarapé dos Glifos"),
        ("WA_JUNGLE_RATANABA_GATE", "Escadaria Submersa"),
        ("WA_RUINS_RATANABA_1", "Ruínas de Ratanabá F1"),
        ("WA_RUINS_RATANABA_2", "Ruínas de Ratanabá F2"),
        ("WA_RUINS_RATANABA_3", "Ruínas de Ratanabá F3"),
        ("WA_RUINS_RATANABA_4", "Ruínas de Ratanabá F4"),
    ],
}

## The dictionary keys are content groups; they go to the CSVs the project loads
## (project.godot: localization/*.pt_BR.translation). "items.csv"/"zones.csv" never existed.
LOCALIZATION_FILES = {
    "items.csv": "localization/content.csv",
    "zones.csv": "localization/world.csv",
    "world.csv": "localization/world.csv",
}


def update_localizations():
    for group, entries in NEW_LOCALIZATIONS.items():
        wg.csv_add(LOCALIZATION_FILES[group], entries)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("=== Building Ratanabá Ecosystem Expansion ===")
    build_exclusive_items()
    update_monster_drops()
    build_city_serra_dourada()
    build_selva_ratanaba()
    build_ruins_ratanaba_floors()
    connect_summit_to_serra_dourada()
    update_localizations()
    wg.finish(RATANABA_MAPS, "ratanaba")
    print("=== Ecosystem Expansion Successfully Built ===")
