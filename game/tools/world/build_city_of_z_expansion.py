#!/usr/bin/env python3
"""Build the full Cidade Perdida de Z ecosystem expansion:
1. Dossel de Z Approach Region (3 maps, ~45s Ragnarok traversal):
   - jungle_z_trail (Picada dos Bandeirantes)
   - jungle_z_river (Rio das Sombras)
   - jungle_z_gate (Portal dos Murais)
2. A Cidade Perdida de Z Dungeon (4 floors, open-air sun-temple & deep canopy):
   - city_of_z_1 (Ruínas do Mirante de Z)
   - city_of_z_2 (Alameda das Onças das Sombras)
   - city_of_z_3 (Terraço dos Murais Solares)
   - city_of_z_4 (Santuário Dourado de Kuarahy)
3. Thematic monsters for Z (4 stages each):
   - shadow_jaguar (Onça das Sombras)
   - camo_hunter (Caçador Camuflado de Z)
   - kuarahy_soberano (Kuarahy, o Soberano de Z - Boss)
4. Exclusive drop equipment (exclusive_drop_zone = &"city_of_z", buy_price = 0):
   - diadema_solar_de_z (Head)
   - couraca_de_placas_douradas (Body)
   - bracadeiras_do_rastreador (Gloves)
   - sandalias_de_cipo_dourado (Feet)
   - escudo_radiante_kuarahy (Offhand/Shield)
   - colar_do_disco_solar (Accessory)
   - lanca_solar_de_z (Weapon)
   - arco_do_dossel_profundo (Weapon)
   - cajado_solar_kuarahy (Weapon)
   - nectar_solar_da_mata (Consumable)
   - Materials: ouro_antigo_de_z, fragmento_mural_solar, garra_onca_sombra, matriz_solar_kuarahy
   - Crendice: mascara_ritual_kuarahy
5. Connect city_serra_dourada to jungle_z_trail.
6. Localizations across items.csv, monsters.csv, zones.csv, and world.csv.
"""

from pathlib import Path
import csv
import io
import math
import os
import random
import zlib
import re

import worldgen as wg
from PIL import Image
import numpy as np

GAME_DIR = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------------------
# Distance to segment
# ---------------------------------------------------------------------------
def dist_segment(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dz * dz
    if denom == 0:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / denom))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)


# ---------------------------------------------------------------------------
# Sprite sheet generator & tinting
# ---------------------------------------------------------------------------
def patch_import_file(path: Path):
    imp = Path(str(path) + ".import")
    params = {
        "compress/mode": "0",
        "mipmaps/generate": "false",
        "detect_3d/compress_to": "0",
        "process/fix_alpha_border": "false",
    }
    if imp.exists():
        txt = imp.read_text(encoding="utf-8")
        for k, v in params.items():
            pat = re.compile(r"^" + re.escape(k) + r"=.*$", re.M)
            if pat.search(txt):
                txt = pat.sub(f"{k}={v}", txt)
            else:
                txt = txt.replace("[params]\n", f"[params]\n\n{k}={v}\n", 1)
    else:
        txt = (
            '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
            + "".join(f"{k}={v}\n" for k, v in params.items())
        )
    wg.write_text(imp, txt)


def tint_image(src_path: Path, dest_path: Path, target_rgb: tuple, factor: float):
    img = Image.open(src_path)
    arr = np.array(img, dtype=np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    tr, tg, tb = float(target_rgb[0]), float(target_rgb[1]), float(target_rgb[2])

    new_r = r * (1.0 - factor) + (lum / 255.0 * tr) * factor
    new_g = g * (1.0 - factor) + (lum / 255.0 * tg) * factor
    new_b = b * (1.0 - factor) + (lum / 255.0 * tb) * factor

    out_arr = np.stack([new_r, new_g, new_b, a], axis=2).clip(0, 255).astype(np.uint8)
    out_img = Image.fromarray(out_arr)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    wg.save_image(out_img, dest_path)
    patch_import_file(dest_path)


Z_SPECIES_DATA = [
    (
        "shadow_jaguar",
        ["Onça das Sombras", "Onça Predadora da Noite", "Sombra-Feroz do Dossel", "Onça das Sombras Atroz"],
        "garra_onca_sombra",
        [30, 35, 41, 46],
        "roll_charge",
        "jaguar_cub",
        [((50, 45, 60), 0.8), ((40, 35, 50), 0.85), ((30, 25, 40), 0.9), ((20, 15, 30), 0.95)],
        [1.15, 1.35, 1.65, 1.95],
    ),
    (
        "camo_hunter",
        ["Batedor Camuflado", "Rastreador de Z", "Mestre-Caçador da Selva", "Caçador Ancestral Atroz"],
        "fragmento_mural_solar",
        [31, 36, 42, 47],
        "ranged",
        "obsidian_iguana",
        [((65, 110, 55), 0.75), ((55, 95, 45), 0.8), ((45, 80, 35), 0.85), ((35, 65, 25), 0.9)],
        [1.1, 1.3, 1.6, 1.9],
    ),
    (
        "kuarahy_soberano",
        ["Guardião do Disco Solar", "Sacerdote Dourado", "Kuarahy, o Soberano de Z", "Kuarahy Solar Atroz"],
        "matriz_solar_kuarahy",
        [33, 38, 44, 50],
        "boss",
        "ratanaba_architect",
        [((255, 205, 50), 0.8), ((245, 185, 40), 0.85), ((235, 165, 30), 0.9), ((255, 140, 20), 0.95)],
        [1.25, 1.5, 1.85, 2.25],
    ),
]


def build_z_monsters():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"
    monsters_dir = GAME_DIR / "data/monsters"
    monsters_dir.mkdir(parents=True, exist_ok=True)
    translations = []

    for index, (mid, names, primary_drop, levels, behavior, src_mid, tints, scales) in enumerate(Z_SPECIES_DATA):
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
                tint_image(src_file, dest_file, tint_color, tint_factor)

        # MonsterDef
        parts = [
            '[gd_resource type="Resource" script_class="MonsterDef" format=3]',
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="monster"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/drop_entry.gd" id="drop"]',
        ]

        for st in range(1, 5):
            level = levels[st - 1]
            key = f"MON_{mid.upper()}_S{st}_NAME"
            translations.append([key, names[st - 1]])
            boss = st >= 3

            if boss:
                hp = 9500 + index * 400 + (4500 if st == 4 else 0)
                atk = 68 + index * 3 + (18 if st == 4 else 0)
                defense = 32 + index * 2 + (10 if st == 4 else 0)
                mdef = 24 + index * 2 + (8 if st == 4 else 0)
            else:
                hp = round((100 + level * 20) * (1.65 if st == 2 else 1.0))
                atk = 14 + level * 2
                defense = max(4, level // 2)
                mdef = max(3, level // 3)

            walk_ms = 300 if st == 4 else 380 if boss else 340
            atk_interval = 1200 if st == 4 else 1550 if boss else 1450

            st_behaviors = []
            if behavior == "roll_charge":
                st_behaviors.append('&"roll_charge"')
            elif behavior == "ranged":
                st_behaviors.append('&"ranged"')
            if boss:
                st_behaviors.append('&"boss"')

            behaviors_str = f"Array[StringName]([{', '.join(st_behaviors)}])" if st_behaviors else "Array[StringName]([])"

            drop_subresources = [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]\nscript = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {1.0 if boss else 0.45}\nmin_qty = {2 if boss else 1}\nmax_qty = {5 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_gold_{st}"]\nscript = ExtResource("drop")\nitem_id = &"ouro_antigo_de_z"\nchance = {0.8 if boss else 0.25}\nmin_qty = 1\nmax_qty = 3',
                f'[sub_resource type="Resource" id="drop_nectar_{st}"]\nscript = ExtResource("drop")\nitem_id = &"nectar_solar_da_mata"\nchance = {0.7 if boss else 0.15}\nmin_qty = 1\nmax_qty = 2',
            ]
            drops_list = [f'SubResource("drop_mat_{st}")', f'SubResource("drop_gold_{st}")', f'SubResource("drop_nectar_{st}")']

            if mid == "kuarahy_soberano" and boss:
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_mask_{st}"]\nscript = ExtResource("drop")\nitem_id = &"mascara_ritual_kuarahy"\nchance = {0.05 if st == 3 else 0.12}\nmin_qty = 1\nmax_qty = 1'
                )
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_weapon_{st}"]\nscript = ExtResource("drop")\nitem_id = &"lanca_solar_de_z"\nchance = {0.20 if st == 3 else 0.35}\nmin_qty = 1\nmax_qty = 1'
                )
                drops_list.append(f'SubResource("drop_mask_{st}")')
                drops_list.append(f'SubResource("drop_weapon_{st}")')

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
xp_reward = {(1800 + index * 150) * (2 if st == 4 else 1) if boss else level * 16}
stars_min = {160 if st == 4 else 80 if boss else max(2, level // 2)}
stars_max = {320 if st == 4 else 160 if boss else level + 6}
behaviors = {behaviors_str}
drops = Array[ExtResource("drop")]([{", ".join(drops_list)}])"""
            )

        parts += [
            "[resource]",
            f"""script = ExtResource("monster")
id = &"{mid}"
region_id = &"pindorama"
creature_type = &"beast"
stages = Array[ExtResource("stage")]([SubResource("stage1"), SubResource("stage2"), SubResource("stage3"), SubResource("stage4")])""",
        ]
        wg.write_text((monsters_dir / f"{mid}.tres"), "\n\n".join(parts) + "\n")

    # Localizations
    wg.csv_add("localization/monsters.csv", translations)
    print("Z monsters successfully built.")


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
    env_light_color: str = "Color(0.85, 0.75, 0.45, 1)",
    env_light_energy: float = 0.95,
    extra_markers: dict = None,
):
    boss_lairs = boss_lairs or []
    npc_points = npc_points or []
    extra_markers = extra_markers or {}

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

    cells = set()
    for x in range(-56, 56, 2):
        for z in range(-56, 56, 2):
            p = (x + 1, z + 1)
            in_room = any(math.hypot(p[0] - cx, p[1] - cz) < r for cx, cz, r in rooms)
            in_corridor = any(dist_segment(p, a, b) < width for route in routes for a, b in zip(route, route[1:]))
            if in_room or in_corridor:
                cells.add((x, z))

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

    node(map_id, "Node3D", "", f'script = ExtResource("map")\nmap_id = &"{map_id}"')

    res(
        "Environment",
        "env",
        f"""background_mode = 1
background_color = Color(0.015, 0.02, 0.01, 1)
ambient_light_source = 2
ambient_light_color = {env_light_color}
ambient_light_energy = {env_light_energy}
fog_enabled = true
fog_light_color = Color(0.03, 0.05, 0.04, 1)
fog_density = 0.0015""",
    )
    node("WorldEnvironment", "WorldEnvironment", ".", body='environment = SubResource("env")')

    node("Floor", "Node3D", ".")
    node("Decor", "Node3D", ".")
    node("Interactables", "Node3D", ".")
    node("Spawns", "Node3D", ".")
    node("NpcPoints", "Node3D", ".")

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

    res("NavigationMesh", "nav", wg.navmesh_body(cells))
    node("NavigationRegion3D", "NavigationRegion3D", ".", body='navigation_mesh = SubResource("nav")')

    marker("SpawnPoint", spawn_pos, ".")
    for mname, mpos in extra_markers.items():
        marker(mname, mpos, ".")

    node("Viewpoint1", "Marker3D", ".", body=f"position = Vector3({spawn_pos[0]}, 55, {spawn_pos[1] + 24})\nrotation_degrees = Vector3(-52, 0, 0)")

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

    for i, (px, pz) in enumerate(pillars):
        node(
            f"Pillar{i}",
            "MeshInstance3D",
            "Decor",
            f'position = Vector3({px}, -0.5, {pz})\nscale = Vector3(3.0, 8.5, 3.0)\nmesh = ExtResource("rock")\nmaterial_override = ExtResource("rock_mat")',
        )

    res(
        "StandardMaterial3D",
        "sun_mat",
        "albedo_color = Color(0.9, 0.75, 0.2, 1)\nemission_enabled = true\nemission = Color(0.8, 0.55, 0.1, 1)\nemission_energy_multiplier = 1.7",
    )
    for i, (rx, rz, r) in enumerate(rooms):
        node(
            f"SunCrystal{i}",
            "MeshInstance3D",
            "Decor",
            f'position = Vector3({rx + r - 3}, 0, {rz})\nmesh = ExtResource("crystal")\nmaterial_override = SubResource("sun_mat")',
        )
        node(
            f"GlowLight{i}",
            "OmniLight3D",
            "Decor",
            f"position = Vector3({rx}, 5.0, {rz})\nlight_color = Color(0.95, 0.8, 0.35, 1)\nlight_energy = 1.6\nomni_range = {r + 8}",
        )

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
        node("Name", "Label3D", "Interactables/altar_crendice", 'position = Vector3(0, 1.8, 0)\nbillboard = 1\nfont_size = 40\npixel_size = 0.015\ntext = "Altar Solar de Crendice"')

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

    for npc in npc_points:
        nname = npc["name"]
        npos = npc["pos"]
        yaw = npc.get("yaw", 0.0)
        marker(nname, npos, "NpcPoints", f"metadata/facing_yaw = {yaw}")

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
    print(f"Scene {map_id}.tscn generated with {len(cells)} walkable tiles, {row_id} floor runs.")
    return len(cells)


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
# Exclusive Items
# ---------------------------------------------------------------------------
Z_EXCLUSIVE_ITEMS = [
    {
        "id": "diadema_solar_de_z",
        "name_key": "ITEM_DIADEMA_SOLAR_Z_NAME",
        "desc_key": "ITEM_DIADEMA_SOLAR_Z_DESC",
        "icon": "res://assets/items/icons/icon_item_ipe_flower_crown.png",
        "type": 3,  # HEAD
        "rarity": 2,  # RARE
        "sell_price": 320,
        "stats": {"def": 14, "mdef": 16, "str": 4, "int": 4},
        "exclusive": "city_of_z",
    },
    {
        "id": "couraca_de_placas_douradas",
        "name_key": "ITEM_COURACA_PLACAS_DOURADAS_NAME",
        "desc_key": "ITEM_COURACA_PLACAS_DOURADAS_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_jerkin.png",
        "type": 4,  # BODY
        "rarity": 2,  # RARE
        "sell_price": 440,
        "stats": {"def": 36, "mdef": 16, "vit": 5},
        "exclusive": "city_of_z",
    },
    {
        "id": "bracadeiras_do_rastreador",
        "name_key": "ITEM_BRACADEIRAS_RASTREADOR_NAME",
        "desc_key": "ITEM_BRACADEIRAS_RASTREADOR_DESC",
        "icon": "res://assets/items/icons/icon_item_ribbon_bracelet.png",
        "type": 8,  # GLOVES
        "rarity": 2,  # RARE
        "sell_price": 270,
        "stats": {"def": 12, "atk": 10, "dex": 5},
        "exclusive": "city_of_z",
    },
    {
        "id": "sandalias_de_cipo_dourado",
        "name_key": "ITEM_SANDALIAS_CIPO_DOURADO_NAME",
        "desc_key": "ITEM_SANDALIAS_CIPO_DOURADO_DESC",
        "icon": "res://assets/items/icons/icon_item_walking_boots.png",
        "type": 5,  # FEET
        "rarity": 2,  # RARE
        "sell_price": 250,
        "stats": {"def": 9, "mdef": 12, "dex": 4},
        "exclusive": "city_of_z",
    },
    {
        "id": "escudo_radiante_kuarahy",
        "name_key": "ITEM_ESCUDO_RADIANTE_KUARAHY_NAME",
        "desc_key": "ITEM_ESCUDO_RADIANTE_KUARAHY_DESC",
        "icon": "res://assets/items/icons/icon_item_leather_shield.png",
        "type": 2,  # OFFHAND
        "rarity": 2,  # RARE
        "sell_price": 380,
        "stats": {"def": 28, "mdef": 22},
        "exclusive": "city_of_z",
    },
    {
        "id": "colar_do_disco_solar",
        "name_key": "ITEM_COLAR_DISCO_SOLAR_NAME",
        "desc_key": "ITEM_COLAR_DISCO_SOLAR_DESC",
        "icon": "res://assets/items/icons/icon_item_seed_necklace.png",
        "type": 6,  # ACCESSORY
        "rarity": 2,  # RARE
        "sell_price": 340,
        "stats": {"atk": 12, "matk": 18, "spi": 4},
        "exclusive": "city_of_z",
    },
    {
        "id": "lanca_solar_de_z",
        "name_key": "ITEM_LANCA_SOLAR_Z_NAME",
        "desc_key": "ITEM_LANCA_SOLAR_Z_DESC",
        "icon": "res://assets/items/icons/icon_item_short_sword.png",
        "type": 1,  # WEAPON
        "weapon_kind": 1,  # BLADE
        "scaling": "str",
        "two_handed": False,
        "rarity": 2,  # RARE
        "sell_price": 420,
        "stats": {"atk": 46, "str": 5},
        "exclusive": "city_of_z",
    },
    {
        "id": "arco_do_dossel_profundo",
        "name_key": "ITEM_ARCO_DOSSEL_PROFUNDO_NAME",
        "desc_key": "ITEM_ARCO_DOSSEL_PROFUNDO_DESC",
        "icon": "res://assets/items/icons/icon_item_simple_bow.png",
        "type": 1,  # WEAPON
        "weapon_kind": 3,  # BOW
        "scaling": "dex",
        "two_handed": True,
        "rarity": 2,  # RARE
        "sell_price": 420,
        "stats": {"atk": 42, "dex": 6},
        "exclusive": "city_of_z",
    },
    {
        "id": "cajado_solar_kuarahy",
        "name_key": "ITEM_CAJADO_SOLAR_KUARAHY_NAME",
        "desc_key": "ITEM_CAJADO_SOLAR_KUARAHY_DESC",
        "icon": "res://assets/items/icons/icon_item_wooden_staff.png",
        "type": 1,  # WEAPON
        "weapon_kind": 2,  # ARCANE
        "scaling": "int",
        "two_handed": False,
        "rarity": 2,  # RARE
        "sell_price": 420,
        "stats": {"matk": 44, "int": 6},
        "exclusive": "city_of_z",
    },
    {
        "id": "nectar_solar_da_mata",
        "name_key": "ITEM_NECTAR_SOLAR_NAME",
        "desc_key": "ITEM_NECTAR_SOLAR_DESC",
        "icon": "res://assets/items/icons/icon_item_potion_hp_medium.png",
        "type": 0,  # CONSUMABLE
        "rarity": 1,  # UNCOMMON
        "stackable": True,
        "max_stack": 99,
        "sell_price": 75,
        "use_effect": {"heal_hp": 450, "heal_mp": 180},
        "exclusive": "city_of_z",
    },
    {
        "id": "ouro_antigo_de_z",
        "name_key": "ITEM_OURO_ANTIGO_Z_NAME",
        "desc_key": "ITEM_OURO_ANTIGO_Z_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,  # MATERIAL
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 35,
        "exclusive": "city_of_z",
    },
    {
        "id": "fragmento_mural_solar",
        "name_key": "ITEM_FRAGMENTO_MURAL_NAME",
        "desc_key": "ITEM_FRAGMENTO_MURAL_DESC",
        "icon": "res://assets/items/icons/icon_item_pequi_root.png",
        "type": 7,
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 40,
        "exclusive": "city_of_z",
    },
    {
        "id": "garra_onca_sombra",
        "name_key": "ITEM_GARRA_ONCA_SOMBRA_NAME",
        "desc_key": "ITEM_GARRA_ONCA_SOMBRA_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,
        "rarity": 1,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 45,
        "exclusive": "city_of_z",
    },
    {
        "id": "matriz_solar_kuarahy",
        "name_key": "ITEM_MATRIZ_SOLAR_NAME",
        "desc_key": "ITEM_MATRIZ_SOLAR_DESC",
        "icon": "res://assets/items/icons/icon_item_ancient_shell_shard.png",
        "type": 7,
        "rarity": 2,
        "stackable": True,
        "max_stack": 99,
        "sell_price": 90,
        "exclusive": "city_of_z",
    },
]


def build_exclusive_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)

    for item in Z_EXCLUSIVE_ITEMS:
        iid = item["id"]
        stats_str = ""
        if "stats" in item:
            stat_entries = [f'&"{k}": {v}' for k, v in item["stats"].items()]
            stats_str = f"stats = Dictionary[StringName, int]({{\n" + ",\n".join(stat_entries) + "\n})\n"
        use_str = ""
        if "use_effect" in item:
            eff_entries = [f'&"{k}": {v}' for k, v in item["use_effect"].items()]
            use_str = f"use_effect = Dictionary[StringName, Variant]({{\n" + ",\n".join(eff_entries) + "\n})\n"

        weapon_extra = ""
        if item.get("type") == 1:
            weapon_extra = f"""weapon_kind = {item.get('weapon_kind', 1)}
scaling_attribute = &"{item.get('scaling', 'str')}"
two_handed = {'true' if item.get('two_handed', False) else 'false'}
"""

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
{weapon_extra}{stats_str}{use_str}"""
        wg.write_text((items_dir / f"{iid}.tres"), content)
        print(f"Exclusive item {iid}.tres written.")

    # Ensure mascara_ritual_kuarahy has exclusive_drop_zone = &"city_of_z"
    mask_file = items_dir / "mascara_ritual_kuarahy.tres"
    if mask_file.exists():
        txt = mask_file.read_text(encoding="utf-8")
        if "exclusive_drop_zone" not in txt:
            txt = txt.replace('tradeable = true\n', 'tradeable = true\nbuy_price = 0\nexclusive_drop_zone = &"city_of_z"\n')
            wg.write_text(mask_file, txt)
            print("Updated mascara_ritual_kuarahy.tres with exclusive drop zone.")


# ---------------------------------------------------------------------------
# Dossel de Z (Approach Region: 3 maps)
# ---------------------------------------------------------------------------
Z_MAPS = ["jungle_z_trail", "jungle_z_river", "jungle_z_gate", "city_of_z_1", "city_of_z_2", "city_of_z_3", "city_of_z_4"]


def build_dossel_de_z():
    # Map 1: jungle_z_trail (Picada dos Bandeirantes) - Lvl 30-34
    rooms_1 = [
        (0, 36, 8.5),     # South entrance from Serra Dourada
        (0, 0, 12.0),     # Main Jungle Clearing
        (38, -20, 8.5),   # East route to River
        (-38, -20, 8.5),  # West route to Gate
        (36, 14, 7.5),    # Shortcut to Ratanabá Selva
    ]
    routes_1 = [
        [(0, 36), (0, 0)],
        [(0, 0), (38, -20)],
        [(0, 0), (-38, -20)],
        [(0, 0), (36, 14)],
        [(38, -20), (36, 14)],
    ]
    portals_1 = [
        {"name": "ToCity", "id": "z_trail_to_city", "pos": (0, 38), "dest": "city_serra_dourada", "spawn": "ZReturn", "label": "Serra Dourada ↑"},
        {"name": "ToRiver", "id": "z_trail_to_river", "pos": (40, -20), "dest": "jungle_z_river", "spawn": "SpawnPoint", "label": "Rio das Sombras →"},
        {"name": "ToGate", "id": "z_trail_to_gate", "pos": (-40, -20), "dest": "jungle_z_gate", "spawn": "FromTrail", "label": "Portal dos Murais ←"},
        {"name": "ToRatanabaShortcut", "id": "z_trail_to_ratanaba", "pos": (38, 14), "dest": "jungle_ratanaba_trail", "spawn": "ZShortcutLanding", "label": "Picada das Pirâmides ↗"},
    ]
    spawns_1 = [
        {"name": "Pack1", "pos": (-14, 16), "monster_id": "shadow_jaguar", "stage": 1, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 16), "monster_id": "camo_hunter", "stage": 1, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-18, -10), "monster_id": "shadow_jaguar", "stage": 2, "count": 2, "radius": 4, "respawn": 90.0},
        {"name": "Pack4", "pos": (18, -10), "monster_id": "camo_hunter", "stage": 2, "count": 2, "radius": 4, "respawn": 90.0},
        {"name": "Pack5", "pos": (0, -18), "monster_id": "river_anaconda", "stage": 2, "count": 2, "radius": 3, "respawn": 120.0},
    ]
    generate_map_scene(
        map_id="jungle_z_trail",
        rooms=rooms_1,
        routes=routes_1,
        width=3.8,
        pillars=[(-10, 10), (10, -10)],
        spawn_pos=(0, 32),
        portals=portals_1,
        spawns=spawns_1,
        extra_markers={"RatanabaShortcutLanding": (34, 10)},
        ground_mat="res://assets/environment/painted/materials/mat_ground_dirt.tres",
        env_light_color="Color(0.25, 0.7, 0.45, 1)",
        env_light_energy=0.9,
    )
    write_zone_def(
        map_id="jungle_z_trail",
        name_key="ZONE_JUNGLE_Z_TRAIL_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=30,
        lvl_max=34,
        connected_maps=["city_serra_dourada", "jungle_z_river", "jungle_z_gate", "jungle_ratanaba_trail"],
        stage_cap=2,
    )

    # Map 2: jungle_z_river (Rio das Sombras) - Lvl 32-36
    rooms_2 = [
        (-32, 32, 8.5),   # Southwest entrance from Trail
        (0, 0, 13.0),     # Sandbar / Stepping Stones Basin
        (0, -38, 8.5),    # North route to Gate
        (36, 0, 8.0),     # Waterfall Grotto
    ]
    routes_2 = [
        [(-32, 32), (0, 0)],
        [(0, 0), (0, -38)],
        [(0, 0), (36, 0)],
        [(36, 0), (20, -22), (0, -38)],
    ]
    portals_2 = [
        {"name": "ToTrail", "id": "z_river_to_trail", "pos": (-34, 34), "dest": "jungle_z_trail", "spawn": "SpawnPoint", "label": "Picada dos Bandeirantes ←"},
        {"name": "ToGate", "id": "z_river_to_gate", "pos": (0, -40), "dest": "jungle_z_gate", "spawn": "FromRiver", "label": "Portal dos Murais ↑"},
        {"name": "ToGrottoLoop", "id": "z_river_grotto", "pos": (38, 0), "dest": "jungle_z_trail", "spawn": "SpawnPoint", "label": "Vau das Onças"},
    ]
    spawns_2 = [
        {"name": "Pack1", "pos": (-14, 14), "monster_id": "river_anaconda", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 14), "monster_id": "black_caiman", "stage": 2, "count": 2, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "shadow_jaguar", "stage": 2, "count": 2, "radius": 4, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "camo_hunter", "stage": 2, "count": 2, "radius": 4, "respawn": 100.0},
        {"name": "Pack5", "pos": (24, 0), "monster_id": "spider_goliath", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
    ]
    generate_map_scene(
        map_id="jungle_z_river",
        rooms=rooms_2,
        routes=routes_2,
        width=3.8,
        pillars=[(-14, 0), (14, 0)],
        spawn_pos=(-28, 28),
        portals=portals_2,
        spawns=spawns_2,
        ground_mat="res://assets/environment/painted/materials/mat_ground_dirt.tres",
        env_light_color="Color(0.2, 0.65, 0.55, 1)",
        env_light_energy=0.9,
    )
    write_zone_def(
        map_id="jungle_z_river",
        name_key="ZONE_JUNGLE_Z_RIVER_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=32,
        lvl_max=36,
        connected_maps=["jungle_z_trail", "jungle_z_gate"],
        stage_cap=2,
    )

    # Map 3: jungle_z_gate (Portal dos Murais) - Lvl 34-38
    rooms_3 = [
        (-30, 32, 8.5),   # Southwest from Trail
        (30, 32, 8.5),    # Southeast from River
        (0, 0, 14.0),     # Grand Plaza of Murals
        (0, -32, 10.0),   # Great Sun Gate to Dungeon
        (-38, 0, 8.0),    # Canopy Terrace
    ]
    routes_3 = [
        [(-30, 32), (0, 0)],
        [(30, 32), (0, 0)],
        [(0, 0), (0, -32)],
        [(0, 0), (-38, 0)],
        [(-38, 0), (-20, -22), (0, -32)],
    ]
    portals_3 = [
        {"name": "ToTrail", "id": "z_gate_to_trail", "pos": (-32, 34), "dest": "jungle_z_trail", "spawn": "SpawnPoint", "label": "Picada dos Bandeirantes ↓"},
        {"name": "ToRiver", "id": "z_gate_to_river", "pos": (32, 34), "dest": "jungle_z_river", "spawn": "SpawnPoint", "label": "Rio das Sombras ↘"},
        {"name": "ToDungeon", "id": "z_gate_to_dungeon", "pos": (0, -34), "dest": "city_of_z_1", "spawn": "SpawnPoint", "label": "Cidade Perdida de Z [F1] ⇓"},
        {"name": "ToCanopyLoop", "id": "z_gate_canopy_loop", "pos": (-40, 0), "dest": "jungle_z_trail", "spawn": "SpawnPoint", "label": "Atalho das Árvores"},
    ]
    spawns_3 = [
        {"name": "Pack1", "pos": (-14, 16), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 16), "monster_id": "camo_hunter", "stage": 2, "count": 3, "radius": 4, "respawn": 90.0},
        {"name": "Pack3", "pos": (-16, -10), "monster_id": "river_anaconda", "stage": 2, "count": 2, "radius": 4, "respawn": 90.0},
        {"name": "Pack4", "pos": (16, -10), "monster_id": "kuarahy_soberano", "stage": 1, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 14), "monster_id": "shadow_jaguar", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack6", "pos": (0, -14), "monster_id": "camo_hunter", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
    ]
    extra_markers_3 = {
        "FromTrail": (-28, 28),
        "FromRiver": (28, 28),
        "CityOfZReturn": (0, -26),  # Boss escape arrival from F4!
    }
    generate_map_scene(
        map_id="jungle_z_gate",
        rooms=rooms_3,
        routes=routes_3,
        width=3.8,
        pillars=[(-8, -8), (8, -8)],
        spawn_pos=(0, 24),
        portals=portals_3,
        spawns=spawns_3,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.85, 0.75, 0.4, 1)",
        env_light_energy=1.0,
        extra_markers=extra_markers_3,
    )
    write_zone_def(
        map_id="jungle_z_gate",
        name_key="ZONE_JUNGLE_Z_GATE_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=34,
        lvl_max=38,
        connected_maps=["jungle_z_trail", "jungle_z_river", "city_of_z_1"],
        stage_cap=2,
    )


# ---------------------------------------------------------------------------
# A Cidade Perdida de Z (Dungeon: 4 Floors)
# ---------------------------------------------------------------------------
def build_city_of_z_floors():
    # FLOOR 1: city_of_z_1 (Ruínas do Mirante de Z) - Lvl 35-38
    rooms_1 = [
        (0, 32, 9.0),      # Surface entrance lobby
        (0, 0, 14.0),      # Grand Sunken Court
        (-24, -28, 8.5),   # West Descent
        (24, -28, 8.5),    # East Descent
        (0, -18, 7.5),     # Solar Obelisk Center
    ]
    routes_1 = [
        [(0, 32), (0, 0)],
        [(0, 0), (-24, -28)],
        [(0, 0), (24, -28)],
        [(0, 0), (0, -18)],
        [(-24, -28), (0, -18), (24, -28)],
    ]
    portals_1 = [
        {"name": "SurfaceReturn", "id": "z_1_surface", "pos": (0, 34), "dest": "jungle_z_gate", "spawn": "CityOfZReturn", "label": "Superfície ↑"},
        {"name": "WestDescent", "id": "z_1_descent_west", "pos": (-24, -30), "dest": "city_of_z_2", "spawn": "WestAscent", "label": "↓ F2 · Alameda Oeste"},
        {"name": "EastDescent", "id": "z_1_descent_east", "pos": (24, -30), "dest": "city_of_z_2", "spawn": "EastAscent", "label": "↓ F2 · Alameda Leste"},
    ]
    spawns_1 = [
        {"name": "Pack1", "pos": (-14, 12), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack2", "pos": (14, 12), "monster_id": "camo_hunter", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack3", "pos": (-16, -12), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -12), "monster_id": "camo_hunter", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "kuarahy_soberano", "stage": 1, "count": 2, "radius": 2, "respawn": 100.0},
        {"name": "Pack6", "pos": (0, -10), "monster_id": "shadow_jaguar", "stage": 2, "count": 2, "radius": 2, "respawn": 100.0},
    ]
    extra_markers_1 = {"WestEntry": (-22, -24), "EastEntry": (22, -24)}
    generate_map_scene(
        map_id="city_of_z_1",
        rooms=rooms_1,
        routes=routes_1,
        width=3.6,
        pillars=[(-10, 10), (10, 10)],
        spawn_pos=(0, 30),
        portals=portals_1,
        spawns=spawns_1,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.85, 0.75, 0.35, 1)",
        env_light_energy=0.9,
        extra_markers=extra_markers_1,
    )
    write_zone_def(
        map_id="city_of_z_1",
        name_key="ZONE_CITY_OF_Z_F1_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=35,
        lvl_max=38,
        connected_maps=["jungle_z_gate", "city_of_z_2"],
        stage_cap=2,
    )

    # FLOOR 2: city_of_z_2 (Alameda das Onças das Sombras) - Lvl 37-40
    rooms_2 = [
        (-24, 32, 8.5),   # West Ascent
        (24, 32, 8.5),    # East Ascent
        (0, 0, 15.0),     # Great Jaguar Colonnade
        (0, -34, 9.0),    # Central Descent
        (32, 0, 8.5),     # Jade Gallery
    ]
    routes_2 = [
        [(-24, 32), (0, 0)],
        [(24, 32), (0, 0)],
        [(0, 0), (0, -34)],
        [(0, 0), (32, 0)],
        [(32, 0), (20, -22), (0, -34)],
    ]
    portals_2 = [
        {"name": "WestAscent", "id": "z_2_ascent_west", "pos": (-24, 34), "dest": "city_of_z_1", "spawn": "WestEntry", "label": "↑ F1 · Alameda Oeste"},
        {"name": "EastAscent", "id": "z_2_ascent_east", "pos": (24, 34), "dest": "city_of_z_1", "spawn": "EastEntry", "label": "↑ F1 · Alameda Leste"},
        {"name": "MainDescent", "id": "z_2_descent_main", "pos": (0, -36), "dest": "city_of_z_3", "spawn": "MainAscent", "label": "↓ F3 · Terraço Solar"},
        {"name": "JadeDescent", "id": "z_2_descent_jade", "pos": (34, 0), "dest": "city_of_z_3", "spawn": "JadeAscent", "label": "↓ F3 · Galeria de Jade"},
    ]
    spawns_2 = [
        {"name": "Pack1", "pos": (-14, 12), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack2", "pos": (14, 12), "monster_id": "camo_hunter", "stage": 2, "count": 3, "radius": 3, "respawn": 100.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "shadow_jaguar", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "camo_hunter", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "kuarahy_soberano", "stage": 2, "count": 2, "radius": 2, "respawn": 100.0},
        {"name": "Pack6", "pos": (22, 0), "monster_id": "shadow_jaguar", "stage": 2, "count": 2, "radius": 2, "respawn": 100.0},
    ]
    extra_markers_2 = {"WestAscent": (-22, 28), "EastAscent": (22, 28), "CentralEntry": (0, -28)}
    generate_map_scene(
        map_id="city_of_z_2",
        rooms=rooms_2,
        routes=routes_2,
        width=3.6,
        pillars=[(-10, 0), (10, 0)],
        spawn_pos=(0, 20),
        portals=portals_2,
        spawns=spawns_2,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.88, 0.76, 0.3, 1)",
        env_light_energy=0.85,
        extra_markers=extra_markers_2,
    )
    write_zone_def(
        map_id="city_of_z_2",
        name_key="ZONE_CITY_OF_Z_F2_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=37,
        lvl_max=40,
        connected_maps=["city_of_z_1", "city_of_z_3"],
        stage_cap=3,
        bosses_allowed=True,
    )

    # FLOOR 3: city_of_z_3 (Terraço dos Murais Solares) - Lvl 39-42
    rooms_3 = [
        (0, 32, 9.0),      # Main Ascent from F2
        (30, 20, 8.0),     # Jade Ascent
        (0, 0, 16.0),      # Grand Sun Mural Plaza
        (-24, -32, 8.5),   # Sanctum Descent
        (24, -32, 8.5),    # Golden Aqueduct Descent
    ]
    routes_3 = [
        [(0, 32), (0, 0)],
        [(30, 20), (0, 0)],
        [(0, 0), (-24, -32)],
        [(0, 0), (24, -32)],
        [(-24, -32), (0, -20), (24, -32)],
    ]
    portals_3 = [
        {"name": "MainAscent", "id": "z_3_ascent_main", "pos": (0, 34), "dest": "city_of_z_2", "spawn": "CentralEntry", "label": "↑ F2 · Alameda Principal"},
        {"name": "JadeAscent", "id": "z_3_ascent_jade", "pos": (32, 20), "dest": "city_of_z_2", "spawn": "CentralEntry", "label": "↑ F2 · Galeria de Jade"},
        {"name": "SanctumDescent", "id": "z_3_descent_sanctum", "pos": (-24, -34), "dest": "city_of_z_4", "spawn": "SanctumAscent", "label": "⇓ F4 · Santuário de Kuarahy"},
        {"name": "AqueductDescent", "id": "z_3_descent_aqueduct", "pos": (24, -34), "dest": "city_of_z_4", "spawn": "AqueductAscent", "label": "⇓ F4 · Conduto Dourado"},
    ]
    spawns_3 = [
        {"name": "Pack1", "pos": (-14, 14), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 3, "respawn": 90.0},
        {"name": "Pack2", "pos": (14, 14), "monster_id": "camo_hunter", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack3", "pos": (-16, -14), "monster_id": "kuarahy_soberano", "stage": 2, "count": 2, "radius": 3, "respawn": 100.0},
        {"name": "Pack4", "pos": (16, -14), "monster_id": "shadow_jaguar", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "camo_hunter", "stage": 2, "count": 2, "radius": 2, "respawn": 90.0},
        {"name": "Pack6", "pos": (0, -12), "monster_id": "kuarahy_soberano", "stage": 2, "count": 2, "radius": 2, "respawn": 90.0},
    ]
    extra_markers_3 = {"MainAscent": (0, 28), "JadeAscent": (26, 16), "DescentLanding": (0, -26)}
    generate_map_scene(
        map_id="city_of_z_3",
        rooms=rooms_3,
        routes=routes_3,
        width=3.6,
        pillars=[(-14, 0), (14, -8)],
        spawn_pos=(0, 24),
        portals=portals_3,
        spawns=spawns_3,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.9, 0.8, 0.25, 1)",
        env_light_energy=0.8,
        extra_markers=extra_markers_3,
    )
    write_zone_def(
        map_id="city_of_z_3",
        name_key="ZONE_CITY_OF_Z_F3_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=39,
        lvl_max=42,
        connected_maps=["city_of_z_2", "city_of_z_4"],
        stage_cap=3,
        bosses_allowed=True,
    )

    # FLOOR 4: city_of_z_4 (Santuário Dourado de Kuarahy) - Lvl 41-44 (BOSS FLOOR)
    rooms_4 = [
        (-20, 32, 8.5),   # Sanctum Ascent
        (20, 32, 8.5),    # Aqueduct Ascent
        (0, 0, 13.0),     # Golden Court
        (0, -24, 18.0),   # Sun Sovereign Altar & Throne
    ]
    routes_4 = [
        [(-20, 32), (0, 0)],
        [(20, 32), (0, 0)],
        [(0, 0), (0, -24)],
        [(-20, 32), (-14, 16), (0, 0)],
        [(20, 32), (14, 16), (0, 0)],
    ]
    portals_4 = [
        {"name": "SanctumAscent", "id": "z_4_ascent_sanctum", "pos": (-20, 34), "dest": "city_of_z_3", "spawn": "DescentLanding", "label": "↑ F3 · Escadaria"},
        {"name": "AqueductAscent", "id": "z_4_ascent_aqueduct", "pos": (20, 34), "dest": "city_of_z_3", "spawn": "DescentLanding", "label": "↑ F3 · Conduto"},
        {
            "name": "SurfaceEscapePortal",
            "id": "z_4_escape",
            "pos": (0, -42),
            "dest": "jungle_z_gate",
            "spawn": "CityOfZReturn",
            "label": "Saída Rápida de Z · Superfície",
            "gate": True,
            "requires_boss": True,
        },
    ]
    boss_lairs_4 = [
        {"name": "kuarahy", "pos": (0, -24), "monster_id": "kuarahy_soberano", "radius": 8, "respawn": 600.0}
    ]
    spawns_4 = [
        {"name": "Pack1", "pos": (-16, 10), "monster_id": "shadow_jaguar", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack2", "pos": (16, 10), "monster_id": "camo_hunter", "stage": 2, "count": 1, "radius": 3, "respawn": 120.0},
        {"name": "Pack3", "pos": (-14, -14), "monster_id": "shadow_jaguar", "stage": 2, "count": 3, "radius": 3, "respawn": 120.0},
        {"name": "Pack4", "pos": (14, -14), "monster_id": "camo_hunter", "stage": 2, "count": 3, "radius": 3, "respawn": 120.0},
        {"name": "Pack5", "pos": (0, 16), "monster_id": "kuarahy_soberano", "stage": 2, "count": 2, "radius": 2, "respawn": 120.0},
        {"name": "Pack6", "pos": (0, -8), "monster_id": "shadow_jaguar", "stage": 2, "count": 1, "radius": 2, "respawn": 120.0},
    ]
    extra_markers_4 = {"SanctumAscent": (-18, 28), "AqueductAscent": (18, 28)}
    generate_map_scene(
        map_id="city_of_z_4",
        rooms=rooms_4,
        routes=routes_4,
        width=3.8,
        pillars=[(-14, -20), (14, -20)],
        spawn_pos=(0, 20),
        portals=portals_4,
        spawns=spawns_4,
        boss_lairs=boss_lairs_4,
        ground_mat="res://assets/environment/painted/materials/mat_ground_paving.tres",
        env_light_color="Color(0.95, 0.85, 0.3, 1)",
        env_light_energy=0.95,
        extra_markers=extra_markers_4,
    )
    write_zone_def(
        map_id="city_of_z_4",
        name_key="ZONE_CITY_OF_Z_F4_NAME",
        kind=2,
        region_id="pindorama",
        lvl_min=41,
        lvl_max=44,
        connected_maps=["city_of_z_3", "jungle_z_gate"],
        stage_cap=3,
        bosses_allowed=True,
    )


# ---------------------------------------------------------------------------
# Connect Serra Dourada to jungle_z_trail
# ---------------------------------------------------------------------------
def connect_city_to_z():
    """Serra Dourada (hub) is generated by build_ratanaba_expansion.py with GateZ -> jungle_z_trail
    and the ZReturn arrival; validate_world (wg.finish) checks both sides of the link."""
    zone = wg.read_text(GAME_DIR / "data/zones/city_serra_dourada.tres")
    if '&"jungle_z_trail"' not in zone:
        raise wg.WorldGenError("city_serra_dourada does not list jungle_z_trail: run build_ratanaba_expansion.py")


# ---------------------------------------------------------------------------
# Localizations
# ---------------------------------------------------------------------------
Z_LOCALIZATIONS = {
    "items.csv": [
        ("ITEM_DIADEMA_SOLAR_Z_NAME", "Diadema Solar de Z"),
        ("ITEM_DIADEMA_SOLAR_Z_DESC", "Coroa de ouro martelado com incrustações de topázio e símbolos do sol de Kuarahy."),
        ("ITEM_COURACA_PLACAS_DOURADAS_NAME", "Couraça de Placas Douradas"),
        ("ITEM_COURACA_PLACAS_DOURADAS_DESC", "Peitoral ancestral forjado em liga de ouro denso e escamas vegetais do dossel de Z."),
        ("ITEM_BRACADEIRAS_RASTREADOR_NAME", "Braçadeiras do Rastreador"),
        ("ITEM_BRACADEIRAS_RASTREADOR_DESC", "Proteção de antebraço confeccionada em couro sombrio e guarnições de ouro flexível."),
        ("ITEM_SANDALIAS_CIPO_DOURADO_NAME", "Sandálias de Cipó Dourado"),
        ("ITEM_SANDALIAS_CIPO_DOURADO_DESC", "Calçado leve trançado com fibras solares de cipó místico que não afundam no lodo da selva."),
        ("ITEM_ESCUDO_RADIANTE_KUARAHY_NAME", "Escudo Radiante de Kuarahy"),
        ("ITEM_ESCUDO_RADIANTE_KUARAHY_DESC", "Escudo redondo representando a face radiante do soberano solar. Reflete investidas com faíscas de luz."),
        ("ITEM_COLAR_DISCO_SOLAR_NAME", "Colar do Disco Solar"),
        ("ITEM_COLAR_DISCO_SOLAR_DESC", "Pendente cerimonial com o disco do sol de Z que harmoniza poder marcial e conjuração."),
        ("ITEM_LANCA_SOLAR_Z_NAME", "Lança Solar de Z"),
        ("ITEM_LANCA_SOLAR_Z_DESC", "Arma pontiaguda de haste nobre com lâmina dourada que desfere golpes velozes e perfurantes."),
        ("ITEM_ARCO_DOSSEL_PROFUNDO_NAME", "Arco do Dossel Profundo"),
        ("ITEM_ARCO_DOSSEL_PROFUNDO_DESC", "Arco composto talhado na madeira envergada das árvores milenares da Cidade Perdida."),
        ("ITEM_CAJADO_SOLAR_KUARAHY_NAME", "Cajado Solar de Kuarahy"),
        ("ITEM_CAJADO_SOLAR_KUARAHY_DESC", "Foco arcano com orbe de ouro fundido que canaliza a energia incandescente do sol da selva."),
        ("ITEM_NECTAR_SOLAR_NAME", "Néctar Solar da Mata"),
        ("ITEM_NECTAR_SOLAR_DESC", "Elixir fermentado a partir de seivas douradas e orquídeas raras de Z. Restaura vitalidade e mana."),
        ("ITEM_OURO_ANTIGO_Z_NAME", "Ouro Antigo de Z"),
        ("ITEM_OURO_ANTIGO_Z_DESC", "Lingote de ouro primitivo puro cunhado pelos artesãos solares da civilização perdida."),
        ("ITEM_FRAGMENTO_MURAL_NAME", "Fragmento de Mural Solar"),
        ("ITEM_FRAGMENTO_MURAL_DESC", "Lasca de arenito entalhada com relevos dos caçadores ancestrais de Z."),
        ("ITEM_GARRA_ONCA_SOMBRA_NAME", "Garra da Onça das Sombras"),
        ("ITEM_GARRA_ONCA_SOMBRA_DESC", "Garra curva e escura impregnada com a essência furtiva das feras do dossel."),
        ("ITEM_MATRIZ_SOLAR_NAME", "Matriz Solar de Kuarahy"),
        ("ITEM_MATRIZ_SOLAR_DESC", "Artefato divino esculpido em ouro puro pulsando com o calor preservado de mil sóis."),
    ],
    "zones.csv": [
        ("ZONE_JUNGLE_Z_TRAIL_NAME", "Dossel de Z · Picada dos Bandeirantes"),
        ("ZONE_JUNGLE_Z_RIVER_NAME", "Dossel de Z · Rio das Sombras"),
        ("ZONE_JUNGLE_Z_GATE_NAME", "Dossel de Z · Portal dos Murais"),
        ("ZONE_CITY_OF_Z_F1_NAME", "Cidade Perdida de Z · Mirante Ancestral [F1]"),
        ("ZONE_CITY_OF_Z_F2_NAME", "Cidade Perdida de Z · Alameda das Onças [F2]"),
        ("ZONE_CITY_OF_Z_F3_NAME", "Cidade Perdida de Z · Terraço dos Murais [F3]"),
        ("ZONE_CITY_OF_Z_F4_NAME", "Cidade Perdida de Z · Santuário de Kuarahy [F4]"),
    ],
    "world.csv": [
        ("WA_JUNGLE_Z_TRAIL", "Picada dos Bandeirantes"),
        ("WA_JUNGLE_Z_RIVER", "Rio das Sombras"),
        ("WA_JUNGLE_Z_GATE", "Portal dos Murais"),
        ("WA_CITY_OF_Z_1", "Cidade Perdida de Z F1"),
        ("WA_CITY_OF_Z_2", "Cidade Perdida de Z F2"),
        ("WA_CITY_OF_Z_3", "Cidade Perdida de Z F3"),
        ("WA_CITY_OF_Z_4", "Cidade Perdida de Z F4"),
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
    for group, entries in Z_LOCALIZATIONS.items():
        wg.csv_add(LOCALIZATION_FILES[group], entries)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("=== Building A Cidade Perdida de Z Ecosystem ===")
    build_z_monsters()
    build_exclusive_items()
    build_dossel_de_z()
    build_city_of_z_floors()
    connect_city_to_z()
    update_localizations()
    wg.finish(Z_MAPS, "city_of_z")
    print("=== A Cidade Perdida de Z Successfully Built ===")
