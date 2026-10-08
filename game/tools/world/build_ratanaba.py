#!/usr/bin/env python3
"""Build Ruínas de Ratanabá:
- Map: res://scenes/maps/ruins_ratanaba.tscn
- Zone: res://data/zones/ruins_ratanaba.tres
- Monsters: ratanaba_sentinel, crystal_serpent, ratanaba_architect (with sprite sheets & MonsterDefs)
- Weapons & Items: obsidian_machete, crystal_recurve_bow, ratanaba_energy_wand, biomechanic_mace,
                   obsidian_shard, runic_core, crystal_scale, architect_matrix,
                   figa_de_obsidiana, prisma_da_serpente
- Localization entries across CSV files.
"""
from pathlib import Path
import csv
import io
import math
import os
import random
import re
from PIL import Image
import numpy as np

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

GAME_DIR = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------------------
# Sprite generator & Tinting helper
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
    imp.write_text(txt, encoding="utf-8")


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
    out_img.save(dest_path, "PNG")
    patch_import_file(dest_path)


# ---------------------------------------------------------------------------
# Icon Generator
# ---------------------------------------------------------------------------
def generate_icon(dest_path: Path, base_color: tuple, accent_color: tuple, icon_type: str = "item"):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    arr = np.array(img)
    # Draw simple pixel art icon
    for y in range(4, 28):
        for x in range(4, 28):
            dx = abs(x - 15.5)
            dy = abs(y - 15.5)
            dist = math.hypot(dx, dy)
            if icon_type == "blade":
                # Diagonal sword shape
                if abs(x - y) <= 2 and dist <= 12:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                elif abs(x - y) <= 4 and dist <= 13:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 230]
            elif icon_type == "bow":
                # Curved bow shape
                if 8 <= dist <= 11 and x <= 16:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                elif abs(x - 16) <= 1 and 6 <= y <= 26:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 180]
            elif icon_type == "wand":
                # Staff with glowing orb
                if abs(x - y) <= 1 and dist <= 11:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                elif dist <= 5 and x >= 18 and y <= 14:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 255]
            elif icon_type == "crystal":
                # Diamond / crystal shape
                if (dx + dy) <= 10:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                if (dx + dy) <= 5:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 255]
            elif icon_type == "amulet":
                # Amulet / figa / round pendant
                if 5 <= dist <= 10:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                elif dist < 5:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 255]
            else:
                # Shard / matrix
                if (dx * 1.2 + dy) <= 9:
                    arr[y, x] = [base_color[0], base_color[1], base_color[2], 255]
                if (dx + dy) <= 4:
                    arr[y, x] = [accent_color[0], accent_color[1], accent_color[2], 255]

    out_img = Image.fromarray(arr)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    out_img.save(dest_path, "PNG")
    patch_import_file(dest_path)


# ---------------------------------------------------------------------------
# 1. Generate Sprites
# ---------------------------------------------------------------------------
MONSTERS_CONFIG = [
    (
        "ratanaba_sentinel",
        "moss_troll",
        [
            ((40, 48, 56), 0.82),    # S1 Obsidian stone
            ((30, 40, 52), 0.86),    # S2 Runic dark
            ((20, 32, 48), 0.90),    # S3 Ancient Guardian
            ((15, 22, 38), 0.93),    # S4 Atroz
        ],
    ),
    (
        "crystal_serpent",
        "cinder_serpent",
        [
            ((70, 210, 240), 0.80),  # S1 Crystal
            ((45, 190, 230), 0.85),  # S2 Quartz
            ((25, 230, 255), 0.88),  # S3 Prism Viper
            ((10, 245, 255), 0.92),  # S4 Atroz
        ],
    ),
    (
        "ratanaba_architect",
        "walking_hut",
        [
            ((190, 140, 55), 0.75),  # S1 Prototype
            ((175, 125, 45), 0.80),  # S2 Engineer
            ((215, 165, 40), 0.85),  # S3 The Architect
            ((235, 105, 30), 0.90),  # S4 Biomechanic Atroz
        ],
    ),
]

def build_monster_sprites():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"

    for mid, src_mid, tints in MONSTERS_CONFIG:
        dest_dir = mon_assets_dir / mid
        dest_dir.mkdir(parents=True, exist_ok=True)
        src_dir = mon_assets_dir / src_mid

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
                if not dest_file.exists():
                    tint_image(src_file, dest_file, tint_color, tint_factor)

    print("Ratanabá monster sprites generated.")


# ---------------------------------------------------------------------------
# 2. Generate Items and Weapons
# ---------------------------------------------------------------------------
NEW_ITEMS = [
    # Materials
    ("obsidian_shard", 7, 0, 1, 24, False, "icon_item_ancient_shell_shard.png"),
    ("runic_core", 7, 0, 2, 80, False, "icon_item_eternal_ember.png"),
    ("crystal_scale", 7, 0, 1, 28, False, "icon_item_ancient_shell_shard.png"),
    ("architect_matrix", 7, 0, 3, 250, False, "icon_item_eternal_ember.png"),
    # Weapons
    # (id, type, weapon_kind, rarity, sell_price, two_handed, icon_name, scaling, stats)
    ("obsidian_machete", 1, 1, 2, 220, False, "icon_item_machete.png", "str", {"atk": 38, "str": 4, "def": 2}),
    ("crystal_recurve_bow", 1, 3, 2, 230, True, "icon_item_simple_bow.png", "dex", {"atk": 35, "dex": 5, "matk": 10}),
    ("ratanaba_energy_wand", 1, 2, 3, 310, False, "icon_item_ipe_wand.png", "int", {"matk": 44, "int": 5, "mdef": 6}),
    ("biomechanic_mace", 1, 1, 3, 340, False, "icon_item_short_sword.png", "str", {"atk": 45, "str": 6, "def": 8}),
    # Crendices
    ("figa_de_obsidiana", 9, 0, 2, 450, False, "icon_item_seed_necklace.png", "", {"def": 18, "mdef": 14}),
    ("prisma_da_serpente", 9, 0, 2, 450, False, "icon_item_ribbon_bracelet.png", "", {"mdef": 16, "matk": 8}),
]

def build_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)

    for item_data in NEW_ITEMS:
        item_id = item_data[0]
        item_type = item_data[1]
        weapon_kind = item_data[2]
        rarity = item_data[3]
        sell_price = item_data[4]
        two_handed = item_data[5]
        icon_name = item_data[6]
        scaling = item_data[7] if len(item_data) > 7 else ""
        stats = item_data[8] if len(item_data) > 8 else {}

        tres_path = items_dir / f"{item_id}.tres"
        lines = [
            '[gd_resource type="Resource" script_class="ItemDef" format=3]',
            '',
            f'[ext_resource type="Texture2D" path="res://assets/items/icons/{icon_name}" id="icon"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/item_def.gd" id="item"]',
            '',
            '[resource]',
            'script = ExtResource("item")',
            f'id = &"{item_id}"',
            f'name_key = "ITEM_{item_id.upper()}_NAME"',
            f'desc_key = "ITEM_{item_id.upper()}_DESC"',
            'icon = ExtResource("icon")',
            f'type = {item_type}',
        ]
        if weapon_kind > 0:
            lines.append(f'weapon_kind = {weapon_kind}')
        if scaling:
            lines.append(f'scaling_attribute = &"{scaling}"')
        if two_handed:
            lines.append('two_handed = true')
        lines.append(f'rarity = {rarity}')
        lines.append(f'sell_price = {sell_price}')
        lines.append('tradeable = true')

        if item_type == 9: # Crendice
            lines.append(f'crendice_id = &"{item_id}"')
            lines.append('buy_price = 0')

        if stats:
            lines.append('stats = Dictionary[StringName, int]({')
            stat_entries = [f'&"{k}": {v}' for k, v in stats.items()]
            lines.append(",\n".join(stat_entries))
            lines.append('})')

        lines.append('')
        tres_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"Generated {len(NEW_ITEMS)} items and weapons.")


# ---------------------------------------------------------------------------
# 3. Generate MonsterDefs
# ---------------------------------------------------------------------------
MONSTERS_DATA = [
    (
        "ratanaba_sentinel",
        ["Sentinela de Obsidiana", "Sentinela Rúnica", "Guardião Rúnico Ancestral", "Sentinela de Obsidiana Atroz"],
        [22, 27, 34, 40],
        [726, 1430, 9200, 11500], # HP
        [62, 72, 110, 130],        # ATK
        [0, 0, 45, 60],            # MATK
        [22, 28, 44, 52],          # DEF
        [12, 16, 26, 32],          # MDEF
        "construct",
        "earth",
        [
            ("obsidian_shard", 0.6, 1, 2),
            ("runic_core", 0.15, 1, 1),
            ("lasca_cristal_ratanaba", 0.05, 1, 1),
            ("figa_de_obsidiana", 0.04, 1, 1),
        ],
        [1.1, 1.3, 1.6, 1.9],
    ),
    (
        "crystal_serpent",
        ["Serpente de Cristal", "Serpente de Quartzo", "Víbora Prisma Ancestral", "Serpente de Cristal Atroz"],
        [21, 26, 33, 39],
        [698, 1382, 8800, 10800], # HP
        [48, 56, 75, 90],          # ATK
        [64, 78, 125, 145],        # MATK
        [12, 16, 26, 32],          # DEF
        [26, 34, 52, 60],          # MDEF
        "beast",
        "arcane",
        [
            ("crystal_scale", 0.6, 1, 2),
            ("serpent_fang", 0.4, 1, 2),
            ("lasca_cristal_ratanaba", 0.05, 1, 1),
            ("prisma_da_serpente", 0.04, 1, 1),
        ],
        [1.0, 1.25, 1.55, 1.85],
    ),
    (
        "ratanaba_architect",
        ["Autômato de Inspeção", "Engenheiro Ancestral", "O Arquiteto de Ratanabá", "O Arquiteto Biomecânico Atroz"],
        [24, 30, 38, 46],
        [782, 1560, 18500, 24000],# HP
        [66, 78, 145, 180],        # ATK
        [40, 55, 130, 160],        # MATK
        [24, 32, 58, 70],          # DEF
        [18, 24, 42, 54],          # MDEF
        "construct",
        "earth",
        [
            ("architect_matrix", 1.0, 1, 3),
            ("runic_core", 1.0, 2, 4),
            ("obsidian_shard", 1.0, 3, 6),
            ("coracao_obsidiana_arquiteto", 0.25, 1, 1),
        ],
        [1.3, 1.5, 1.8, 2.2],
    ),
]

def build_monster_defs():
    mon_dir = GAME_DIR / "data/monsters"
    mon_dir.mkdir(parents=True, exist_ok=True)

    for mid, names, levels, hps, atks, matks, defs, mdefs, ctype, elem, drops_cfg, scales in MONSTERS_DATA:
        parts = [
            '[gd_resource type="Resource" script_class="MonsterDef" format=3]',
            '',
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="monster"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]',
            '[ext_resource type="Script" path="res://scripts/shared/data/drop_entry.gd" id="drop"]',
            '',
        ]

        for st in range(1, 5):
            for d_idx, (d_item, d_chance, d_min, d_max) in enumerate(drops_cfg):
                chance = min(1.0, d_chance * (2.0 if st >= 3 else 1.0))
                min_q = d_min if st < 3 else d_min + 1
                max_q = d_max if st < 3 else d_max + 2
                parts += [
                    f'[sub_resource type="Resource" id="drop_{st}_{d_idx}"]',
                    'script = ExtResource("drop")',
                    f'item_id = &"{d_item}"',
                    f'chance = {chance}',
                    f'min_qty = {min_q}',
                    f'max_qty = {max_q}',
                    '',
                ]

        for st in range(1, 5):
            boss = (st >= 3)
            beh_list = []
            if mid == "crystal_serpent":
                beh_list.append('&"ranged"')
            if mid == "ratanaba_sentinel":
                beh_list.append('&"roll_charge"')
            if boss:
                beh_list.append('&"boss"')

            beh_str = f"Array[StringName]([{', '.join(beh_list)}])" if beh_list else "Array[StringName]([])"
            drop_refs = ", ".join([f'SubResource("drop_{st}_{d_idx}")' for d_idx in range(len(drops_cfg))])

            walk_ms = 300 if st == 4 else (380 if boss else 350)
            atk_int = 1300 if st == 4 else (1600 if boss else 1450)

            parts += [
                f'[sub_resource type="Resource" id="stage{st}"]',
                'script = ExtResource("stage")',
                f'stage = {st}',
                f'name_key = "MON_{mid.upper()}_S{st}_NAME"',
                f'sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"',
                'baked_life = true',
                f'visual_scale = {scales[st - 1]}',
                f'level = {levels[st - 1]}',
                f'max_hp = {hps[st - 1]}',
                f'atk = {atks[st - 1]}',
                f'matk = {matks[st - 1]}',
                f'def = {defs[st - 1]}',
                f'mdef = {mdefs[st - 1]}',
                f'walk_ms_per_cell = {walk_ms}',
                'attack_range_cells = 1.5' if mid != "crystal_serpent" else 'attack_range_cells = 4.5',
                f'attack_interval_ms = {atk_int}',
                'aggressive = true',
                f'aggro_range_cells = {9 if boss else 7}',
                f'leash_cells = {18 if boss else 14}',
                f'xp_reward = {hps[st - 1] // 3}',
                f'stars_min = {15 if boss else 5}',
                f'stars_max = {50 if boss else 18}',
                f'behaviors = {beh_str}',
                f'drops = Array[ExtResource("drop")]([{drop_refs}])',
                '',
            ]

        stages_refs = ", ".join([f'SubResource("stage{st}")' for st in range(1, 5)])
        parts += [
            '[resource]',
            'script = ExtResource("monster")',
            f'id = &"{mid}"',
            f'creature_type = &"{ctype}"',
            f'primary_element = &"{elem}"',
            f'stages = Array[ExtResource("stage")]([{stages_refs}])',
            '',
        ]

        file_path = mon_dir / f"{mid}.tres"
        file_path.write_text("\n".join(parts), encoding="utf-8")

    print(f"Generated {len(MONSTERS_DATA)} MonsterDef resources.")


# ---------------------------------------------------------------------------
# 4. Generate Map: ruins_ratanaba.tscn
# ---------------------------------------------------------------------------
# The single-map dungeon ruins_ratanaba (scene, zone and the link from fields_pindorama_crossroads) was
# replaced by the 4 floors of build_ratanaba_expansion.py (ruins_ratanaba_1..4) and is no longer built.
# Its last version is in backup_removed_content/2026-10-05/ (project root).


## Localization groups -> CSVs the project loads (project.godot); items/crendice live in content.csv.
LOCALIZATION_FILES = {
    "monsters.csv": "localization/monsters.csv",
    "items.csv": "localization/content.csv",
    "crendice.csv": "localization/content.csv",
    "world.csv": "localization/world.csv",
}


LOCALIZATIONS = {
    "monsters.csv": [
        ("MON_RATANABA_SENTINEL_S1_NAME", "Sentinela de Obsidiana"),
        ("MON_RATANABA_SENTINEL_S2_NAME", "Sentinela Rúnica"),
        ("MON_RATANABA_SENTINEL_S3_NAME", "Guardião Rúnico Ancestral"),
        ("MON_RATANABA_SENTINEL_S4_NAME", "Sentinela de Obsidiana Atroz"),
        ("MON_CRYSTAL_SERPENT_S1_NAME", "Serpente de Cristal"),
        ("MON_CRYSTAL_SERPENT_S2_NAME", "Serpente de Quartzo"),
        ("MON_CRYSTAL_SERPENT_S3_NAME", "Víbora Prisma Ancestral"),
        ("MON_CRYSTAL_SERPENT_S4_NAME", "Serpente de Cristal Atroz"),
        ("MON_RATANABA_ARCHITECT_S1_NAME", "Autômato de Inspeção"),
        ("MON_RATANABA_ARCHITECT_S2_NAME", "Engenheiro Ancestral"),
        ("MON_RATANABA_ARCHITECT_S3_NAME", "O Arquiteto de Ratanabá"),
        ("MON_RATANABA_ARCHITECT_S4_NAME", "O Arquiteto Biomecânico Atroz"),
    ],
    "items.csv": [
        ("ITEM_OBSIDIAN_SHARD_NAME", "Lasca de Obsidiana"),
        ("ITEM_OBSIDIAN_SHARD_DESC", "Fragmento de rocha vulcânica escura polida com cortes precisos, oriundo dos monumentos ancestrais de Ratanabá."),
        ("ITEM_RUNIC_CORE_NAME", "Núcleo Rúnico"),
        ("ITEM_RUNIC_CORE_DESC", "Esfera ancestral inscrita com glifos que emitem uma pulsação constante de energia e mana."),
        ("ITEM_CRYSTAL_SCALE_NAME", "Escama de Cristal"),
        ("ITEM_CRYSTAL_SCALE_DESC", "Escama rígida e translúcida que decompõe a luz e dissipa magias hostis."),
        ("ITEM_ARCHITECT_MATRIX_NAME", "Matriz do Arquiteto"),
        ("ITEM_ARCHITECT_MATRIX_DESC", "Engrenagem biomecânica milenar construída em liga desconhecida. Matéria-prima primordial para forjas lendárias."),
        ("ITEM_OBSIDIAN_MACHETE_NAME", "Facão de Obsidiana Rúnica"),
        ("ITEM_OBSIDIAN_MACHETE_DESC", "Lâmina pesada e afiadíssima forjada a partir de placas vulcânicas de Ratanabá. Concede bônus massivo de corte físico."),
        ("ITEM_CRYSTAL_RECURVE_BOW_NAME", "Arco Recurvo de Quartzo"),
        ("ITEM_CRYSTAL_RECURVE_BOW_DESC", "Arco composto de fibras cristalinas e madeira nobre. Projeta disparos velozes e precisos com perfuração refinada."),
        ("ITEM_RATANABA_ENERGY_WAND_NAME", "Vara de Energia de Ratanabá"),
        ("ITEM_RATANABA_ENERGY_WAND_DESC", "Foco arcano incrustado com um núcleo rúnico puro. Amplifica a canalização de feitiços e barreiras defensivas."),
        ("ITEM_BIOMECHANIC_MACE_NAME", "Clava Biomecânica Ancestral"),
        ("ITEM_BIOMECHANIC_MACE_DESC", "Massa de combate com engrenagens de impacto projetadas para quebrar defesas e blindagens pesadas."),
        ("ITEM_FIGA_DE_OBSIDIANA_NAME", "Figa de Obsidiana"),
        ("ITEM_FIGA_DE_OBSIDIANA_DESC", "Amuleto folclórico lapidado na pedra escura de Ratanabá. Encaixável em armaduras ou acessórios."),
        ("ITEM_PRISMA_DA_SERPENTE_NAME", "Prisma da Serpente Cristalina"),
        ("ITEM_PRISMA_DA_SERPENTE_DESC", "Amuleto esculpido com escamas de quartzo refratário. Encaixável em escudo/mão secundária ou acessórios."),
    ],
    "world.csv": [
        ("WA_RUINS_RATANABA", "Ruínas de Ratanabá"),
    ],
    "crendice.csv": [
        ("CRENDICE_FIGA_OBSIDIANA_NAME", "Figa de Obsidiana de Ratanabá"),
        ("CRENDICE_FIGA_OBSIDIANA_DESC", "+18% Defesa Física e +14 Defesa Mágica."),
        ("CRENDICE_FIGA_OBSIDIANA_LORE", "Talhada na rocha vítrea das ruínas antigas para repelir forças quando cercado por construtos hostis."),
        ("CRENDICE_FIGA_OBSIDIANA_SUP", "A proteção dobra quando o combatente enfrenta múltiplos inimigos ao redor."),
        ("CRENDICE_PRISMA_SERPENTE_NAME", "Prisma da Serpente Cristalina"),
        ("CRENDICE_PRISMA_SERPENTE_DESC", "+15% de Reflexão Mágica e +16 Defesa Mágica."),
        ("CRENDICE_PRISMA_SERPENTE_LORE", "Lapidado das serpentes de quartzo para rebater feitiços de volta aos seus conjuradores."),
        ("CRENDICE_PRISMA_SERPENTE_SUP", "A reflexão exige que o combatente encare a fonte de perigo de frente."),
    ],
}


def update_localizations():
    for group, entries in LOCALIZATIONS.items():
        wg.csv_add(LOCALIZATION_FILES[group], entries)


if __name__ == "__main__":
    build_monster_sprites()
    build_items()
    build_monster_defs()
    update_localizations()
    wg.finish(None, "ratanaba_base")
    print("Ruínas de Ratanabá build complete.")
