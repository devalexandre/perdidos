#!/usr/bin/env python3
"""Build and register Brazilian fauna & flora monsters for Nação Pindorama:
- 8 new species across native fauna & flora:
  1. spider_goliath (Aranha-Caranguejeira-Golias) - Boss Aranha
  2. river_anaconda (Sucuri dos Remansos / Cobra-Grande) - Boss Serpente
  3. giant_anteater (Tamanduá-Bandeira)
  4. maned_wolf (Lobo-Guará)
  5. black_caiman (Jacaré-Açu)
  6. harpy_eagle (Harpia / Gavião-Real)
  7. strangler_vine (Cipó-Matador)
  8. mandacaru_guardian (Mandacaru Guardião)
- 4 stages each: Common (s1), Veteran (s2), Boss (s3), Atroz (s4).
- Native materials and drops.
- Boss Crendice amulets: teia_matriarca_golias and olho_cobra_grande.
- Localizations across CSV files.
"""

from pathlib import Path
import csv
import io
import os
import re
from PIL import Image
import numpy as np

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

GAME_DIR = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------------------
# Items to register
# ---------------------------------------------------------------------------
NEW_ITEMS = [
    ("tarantula_bristle", "ITEM_TARANTULA_BRISTLE_NAME", "ITEM_TARANTULA_BRISTLE_DESC", "icon_item_pequi_root.png", 18),
    ("anaconda_scale", "ITEM_ANACONDA_SCALE_NAME", "ITEM_ANACONDA_SCALE_DESC", "icon_item_ancient_shell_shard.png", 20),
    ("anteater_claw", "ITEM_ANTEATER_CLAW_NAME", "ITEM_ANTEATER_CLAW_DESC", "icon_item_ancient_shell_shard.png", 16),
    ("guara_pelt", "ITEM_GUARA_PELT_NAME", "ITEM_GUARA_PELT_DESC", "icon_item_leather_jerkin.png", 22),
    ("caiman_plate", "ITEM_CAIMAN_PLATE_NAME", "ITEM_CAIMAN_PLATE_DESC", "icon_item_armadillo_shell.png", 24),
    ("harpy_feather", "ITEM_HARPY_FEATHER_NAME", "ITEM_HARPY_FEATHER_DESC", "icon_item_spinning_leaf.png", 19),
    ("strangler_root", "ITEM_STRANGLER_ROOT_NAME", "ITEM_STRANGLER_ROOT_DESC", "icon_item_pequi_root.png", 15),
    ("mandacaru_thorn", "ITEM_MANDACARU_THORN_NAME", "ITEM_MANDACARU_THORN_DESC", "icon_item_thorn_arrow.png", 14),
    ("teia_matriarca_golias", "ITEM_TEIA_MATRIARCA_NAME", "ITEM_TEIA_MATRIARCA_DESC", "icon_item_ribbon_bracelet.png", 0, 9, "teia_matriarca_golias"),
    ("olho_cobra_grande", "ITEM_OLHO_COBRA_GRANDE_NAME", "ITEM_OLHO_COBRA_GRANDE_DESC", "icon_item_seed_necklace.png", 0, 9, "olho_cobra_grande"),
]

ITEM_LOCALIZATIONS = [
    ("ITEM_TARANTULA_BRISTLE_NAME", "Cerdas de Caranguejeira"),
    ("ITEM_TARANTULA_BRISTLE_DESC", "Cerdas urticantes espessas colhidas da caranguejeira-golias. Causam extrema ardência e servem para fortificar tecidos."),
    ("ITEM_ANACONDA_SCALE_NAME", "Escama de Sucuri"),
    ("ITEM_ANACONDA_SCALE_DESC", "Escama flexível e impermeável da grande serpente dos rios. Protege contra umidade e ataques de perfuração."),
    ("ITEM_ANTEATER_CLAW_NAME", "Garra de Tamanduá"),
    ("ITEM_ANTEATER_CLAW_DESC", "Garra curvada maciça capaz de romper cupinzeiros de pedra e repelir predadores de grande porte."),
    ("ITEM_GUARA_PELT_NAME", "Pelagem de Lobo-Guará"),
    ("ITEM_GUARA_PELT_DESC", "Pelagem avermelhada e densa com crina negra, isolante térmica e resistente ao vento forte dos campos."),
    ("ITEM_CAIMAN_PLATE_NAME", "Placa de Jacaré-Açu"),
    ("ITEM_CAIMAN_PLATE_DESC", "Placa óssea dérmica de altíssima dureza colhida do dorso do grande jacaré dos rios profundos."),
    ("ITEM_HARPY_FEATHER_NAME", "Pena de Harpia"),
    ("ITEM_HARPY_FEATHER_DESC", "Rêmige primária majestosa do gavião-real, símbolo de soberania nos céus e equilíbrio aerodinâmico."),
    ("ITEM_STRANGLER_ROOT_NAME", "Raiz de Cipó-Matador"),
    ("ITEM_STRANGLER_ROOT_DESC", "Fibras vegetais resistentes e pegajosas de trepadeira carnívora da mata tropical."),
    ("ITEM_MANDACARU_THORN_NAME", "Espinho de Mandacaru"),
    ("ITEM_MANDACARU_THORN_DESC", "Espinho vegetal rígido como ponta de ferro, colhido do cacto sentinela das áreas secas."),
    ("ITEM_TEIA_MATRIARCA_NAME", "Teia da Matriarca Golias"),
    ("ITEM_TEIA_MATRIARCA_DESC", "Amuleto folclórico tecido com a seda da aranha rainha dos buracos. Concede esquiva e imunidade a lentidão."),
    ("ITEM_OLHO_COBRA_GRANDE_NAME", "Olho da Cobra-Grande"),
    ("ITEM_OLHO_COBRA_GRANDE_DESC", "Amuleto mítico preservando o brilho hipnótico da grande serpente dos remansos. Concede visão e poder físico."),
]

# ---------------------------------------------------------------------------
# 8 Species Data:
# (id, pt_names[4], primary_drop, levels[4], behavior, src_species, tints[4], scales[4])
# ---------------------------------------------------------------------------
SPECIES_DATA = [
    (
        "spider_goliath",
        ["Caranguejeira dos Buracos", "Caranguejeira Anciã", "Golias, a Matriarca dos Buracos", "Caranguejeira-Golias Atroz"],
        "tarantula_bristle",
        [16, 24, 35, 42],
        "roll_charge",
        "wandering_spider",
        [((90, 50, 25), 0.75), ((70, 35, 15), 0.8), ((50, 20, 10), 0.85), ((35, 12, 5), 0.9)],
        [1.15, 1.35, 1.75, 2.1],
    ),
    (
        "river_anaconda",
        ["Sucuri dos Banhados", "Sucuri Constritora", "Cobra-Grande dos Remansos", "Cobra-Grande Titânica Atroz"],
        "anaconda_scale",
        [18, 26, 36, 44],
        "ranged",
        "surucucu_serpent",
        [((60, 95, 55), 0.75), ((45, 80, 40), 0.8), ((30, 65, 30), 0.85), ((20, 50, 25), 0.9)],
        [1.15, 1.35, 1.75, 2.1],
    ),
    (
        "giant_anteater",
        ["Tamanduá do Cerrado", "Tamanduá Couraçado", "Garra-de-Foice do Cupinzeiro", "Tamanduá-Bandeira Atroz"],
        "anteater_claw",
        [15, 22, 32, 38],
        "roll_charge",
        "stone_armadillo",
        [((120, 110, 95), 0.7), ((100, 90, 75), 0.75), ((80, 70, 55), 0.8), ((60, 50, 40), 0.85)],
        [1.05, 1.25, 1.55, 1.85],
    ),
    (
        "maned_wolf",
        ["Lobo-Guará das Veredas", "Guará da Alta Mata", "Passo-Longo das Quebradas", "Lobo-Guará Atroz"],
        "guara_pelt",
        [17, 25, 34, 40],
        "roll_charge",
        "jaguar_cub",
        [((225, 115, 45), 0.8), ((205, 95, 35), 0.85), ((185, 75, 25), 0.85), ((165, 55, 15), 0.9)],
        [1.1, 1.3, 1.6, 1.9],
    ),
    (
        "black_caiman",
        ["Jacaré do Pantanal", "Jacaré Blindado", "Couro-Negro dos Remansos", "Jacaré-Açu Atroz"],
        "caiman_plate",
        [20, 28, 37, 45],
        "roll_charge",
        "obsidian_iguana",
        [((55, 65, 60), 0.8), ((40, 50, 45), 0.85), ((25, 35, 30), 0.9), ((15, 20, 20), 0.95)],
        [1.2, 1.4, 1.75, 2.15],
    ),
    (
        "harpy_eagle",
        ["Harpia Jovem", "Harpia Caçadora", "Soberana das Alturas", "Harpia-Real Atroz"],
        "harpy_feather",
        [19, 27, 36, 43],
        "fly_pattern",
        "griffin_chick",
        [((110, 115, 125), 0.75), ((90, 95, 105), 0.8), ((70, 75, 85), 0.85), ((50, 55, 65), 0.9)],
        [1.1, 1.3, 1.65, 1.95],
    ),
    (
        "strangler_vine",
        ["Broto de Cipó-Matador", "Cipó Estrangulador", "Raiz-Flagelo do Dossel", "Cipó-Matador Atroz"],
        "strangler_root",
        [14, 21, 30, 36],
        "boss",
        "moss_troll",
        [((75, 130, 50), 0.75), ((60, 110, 40), 0.8), ((45, 90, 30), 0.85), ((30, 70, 20), 0.9)],
        [0.95, 1.15, 1.45, 1.75],
    ),
    (
        "mandacaru_guardian",
        ["Mandacaru dos Espinhos", "Mandacaru Couraçado", "Sentinela das Secas", "Mandacaru Atroz"],
        "mandacaru_thorn",
        [15, 23, 31, 37],
        "ranged",
        "moss_troll",
        [((90, 150, 70), 0.75), ((75, 130, 55), 0.8), ((60, 110, 45), 0.85), ((45, 90, 35), 0.9)],
        [1.0, 1.2, 1.5, 1.8],
    ),
]


# ---------------------------------------------------------------------------
# Sprite generator helper
# ---------------------------------------------------------------------------

# A Aranha-Armadeira (fonte do recolor) ganhou chefe/atroz unicos em quadro 240 (antes 144, recolor da iguana):
# para o recolor derivado manter o tamanho na tela de antes, o visual_scale do s3/s4 encolhe na mesma proporcao.
SRC_BOSS_240 = {"wandering_spider"}

# Espécies com arte própria do Blender (game/tools/art/blender/monsters/<id>.py): o gerador não recolore as folhas
# delas e usa visual_scale 1,0 (o tamanho já vem do modelo). Harpia refeita em 08/10/2026 (harpia mitológica).
BLENDER_SPECIES = {"harpy_eagle"}


def stage_visual_scale(src_mid, st, scale, mid=""):
    if mid in BLENDER_SPECIES:
        return 1.0
    if src_mid in SRC_BOSS_240 and st >= 3:
        return round(scale * 144 / 240, 3)
    return scale

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


def generate_sprites():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"

    for mid, names, drop, levels, behavior, src_mid, tints, scales in SPECIES_DATA:
        if mid in BLENDER_SPECIES:
            continue
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
                tint_image(src_file, dest_file, tint_color, tint_factor)
        print(f"Generated sprites for {mid}.")


# ---------------------------------------------------------------------------
# Write items
# ---------------------------------------------------------------------------
def write_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)

    for item in NEW_ITEMS:
        item_id = item[0]
        name_key = item[1]
        desc_key = item[2]
        icon_file = item[3]
        sell_price = item[4]
        item_type = item[5] if len(item) > 5 else 7  # MATERIAL
        crendice_id = item[6] if len(item) > 6 else ""

        crendice_str = ""
        if crendice_id:
            crendice_str = f'crendice_id = &"{crendice_id}"\n'

        content = f"""[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Texture2D" path="res://assets/items/icons/{icon_file}" id="1_icon"]
[ext_resource type="Script" path="res://scripts/shared/data/item_def.gd" id="2_script"]

[resource]
script = ExtResource("2_script")
id = &"{item_id}"
name_key = "{name_key}"
desc_key = "{desc_key}"
icon = ExtResource("1_icon")
type = {item_type}
stackable = {'true' if item_type == 7 else 'false'}
max_stack = {99 if item_type == 7 else 1}
buy_price = 0
sell_price = {sell_price}
tradeable = true
{crendice_str}"""
        (items_dir / f"{item_id}.tres").write_text(content, encoding="utf-8")
    print(f"Created {len(NEW_ITEMS)} items in data/items/.")


# ---------------------------------------------------------------------------
# Generate MonsterDef .tres files
# ---------------------------------------------------------------------------
def generate_monster_defs():
    monsters_dir = GAME_DIR / "data/monsters"
    monsters_dir.mkdir(parents=True, exist_ok=True)
    translations = []

    for index, (mid, names, primary_drop, levels, behavior, src_mid, tints, scales) in enumerate(SPECIES_DATA):
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
                hp = 7000 + index * 300 + (3500 if st == 4 else 0)
                atk = 55 + index * 2 + (15 if st == 4 else 0)
                defense = 26 + (index % 4) * 2 + (8 if st == 4 else 0)
                mdef = 20 + (index % 3) * 2 + (6 if st == 4 else 0)
            else:
                hp = round((80 + level * 18) * (1.6 if st == 2 else 1.0))
                atk = 10 + level * 2
                defense = max(3, level // 2)
                mdef = max(3, level // 3)

            walk_ms = 320 if st == 4 else 400 if boss else 360
            atk_interval = 1250 if st == 4 else 1600 if boss else 1500

            st_behaviors = []
            if behavior == "fly_pattern":
                st_behaviors.append('&"fly_pattern"')
            elif behavior == "roll_charge":
                st_behaviors.append('&"roll_charge"')
            elif behavior == "ranged":
                st_behaviors.append('&"ranged"')

            if boss:
                st_behaviors.append('&"boss"')

            behaviors_str = f"Array[StringName]([{', '.join(st_behaviors)}])" if st_behaviors else "Array[StringName]([])"

            # Drop entries
            drop_subresources = [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]\nscript = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {1.0 if boss else 0.40}\nmin_qty = {2 if boss else 1}\nmax_qty = {5 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_pot_{st}"]\nscript = ExtResource("drop")\nitem_id = &"potion_hp_{"medium" if st > 1 else "small"}"\nchance = {0.6 if boss else 0.15}\nmin_qty = 1\nmax_qty = 2',
            ]

            drops_list = [f'SubResource("drop_mat_{st}")', f'SubResource("drop_pot_{st}")']

            # Boss Crendice drop for spider and serpent boss stages
            if mid == "spider_goliath" and boss:
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_crendice_{st}"]\nscript = ExtResource("drop")\nitem_id = &"teia_matriarca_golias"\nchance = {0.05 if st == 3 else 0.12}\nmin_qty = 1\nmax_qty = 1'
                )
                drops_list.append(f'SubResource("drop_crendice_{st}")')
            elif mid == "river_anaconda" and boss:
                drop_subresources.append(
                    f'[sub_resource type="Resource" id="drop_crendice_{st}"]\nscript = ExtResource("drop")\nitem_id = &"olho_cobra_grande"\nchance = {0.05 if st == 3 else 0.12}\nmin_qty = 1\nmax_qty = 1'
                )
                drops_list.append(f'SubResource("drop_crendice_{st}")')

            parts.extend(drop_subresources)

            parts.append(
                f"""[sub_resource type="Resource" id="stage{st}"]
script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {stage_visual_scale(src_mid, st, scales[st - 1], mid)}
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
xp_reward = {(1600 + index * 140) * (2 if st == 4 else 1) if boss else level * 14}
stars_min = {140 if st == 4 else 70 if boss else max(1, level // 2)}
stars_max = {280 if st == 4 else 140 if boss else level + 5}
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

        (monsters_dir / f"{mid}.tres").write_text("\n\n".join(parts) + "\n", encoding="utf-8")

    # Update localization
    p = GAME_DIR / "localization/monsters.csv"
    existing_keys = set()
    if p.exists():
        for r in csv.reader(io.StringIO(p.read_text(encoding="utf-8"))):
            if r:
                existing_keys.add(r[0])
    new_tr = [t for t in translations if t[0] not in existing_keys]
    if new_tr:
        orig = p.read_text(encoding="utf-8") if p.exists() else "keys,pt_BR\n"
        buf = io.StringIO()
        csv.writer(buf, lineterminator="\n").writerows(new_tr)
        p.write_text(orig.rstrip() + "\n" + buf.getvalue(), encoding="utf-8")
        print(f"Added {len(new_tr)} entries to monsters.csv.")
    print(f"Generated {len(SPECIES_DATA)} MonsterDef resources.")


# ---------------------------------------------------------------------------
# Update Crendice Database
# ---------------------------------------------------------------------------
def update_crendice_database():
    crendice_file = GAME_DIR / "scripts/shared/crendice/crendice_database.gd"
    txt = crendice_file.read_text(encoding="utf-8")

    if "teia_matriarca_golias" not in txt:
        insertion = """
	# 23. Teia da Matriarca Golias (Boss Aranha)
	var teia := CrendiceDef.new()
	teia.id = &"teia_matriarca_golias"
	teia.name_key = "CRENDICE_TEIA_MATRIARCA_NAME"
	teia.desc_key = "CRENDICE_TEIA_MATRIARCA_DESC"
	teia.lore_key = "CRENDICE_TEIA_MATRIARCA_LORE"
	teia.superstition_desc_key = "CRENDICE_TEIA_MATRIARCA_SUP"
	teia.valid_slots = [&"offhand", &"accessory_1", &"accessory_2", &"accessory"]
	teia.stats = {&"flee": 15, &"def": 8}
	teia.special_effects = {
		"immune_slow": true,
		"evasion_pct": 15,
		"ambush_bonus": true
	}
	teia.superstition_rule = &"standing_still_double"
	teia.drop_rules = {
		"monster_ids": [&"spider_goliath"],
		"chance": 0.08,
		"boss_only": true
	}
	teia.synergy_group = &"espirito_da_caca"
	_cache[teia.id] = teia

	# 24. Olho da Cobra-Grande (Boss Serpente)
	var olho := CrendiceDef.new()
	olho.id = &"olho_cobra_grande"
	olho.name_key = "CRENDICE_OLHO_COBRA_GRANDE_NAME"
	olho.desc_key = "CRENDICE_OLHO_COBRA_GRANDE_DESC"
	olho.lore_key = "CRENDICE_OLHO_COBRA_GRANDE_LORE"
	olho.superstition_desc_key = "CRENDICE_OLHO_COBRA_GRANDE_SUP"
	olho.valid_slots = [&"head", &"accessory_1", &"accessory_2", &"accessory"]
	olho.stats = {&"atk": 16, &"matk": 12}
	olho.special_effects = {
		"night_vision": true,
		"phys_dmg_pct": 12,
		"water_combat_bonus": true
	}
	olho.superstition_rule = &"water_or_rain_active"
	olho.drop_rules = {
		"monster_ids": [&"river_anaconda"],
		"chance": 0.08,
		"boss_only": true
	}
	olho.synergy_group = &"ancestralidade_mistica"
	_cache[olho.id] = olho
"""
        txt = txt.replace("	_init_synergies()", insertion + "\n	_init_synergies()")

        # Add to synergy lists
        txt = txt.replace(
            '&"casulo_lonomia_urticante"]',
            '&"casulo_lonomia_urticante", &"teia_matriarca_golias"]',
        )
        txt = txt.replace(
            '&"prisma_da_serpente"]',
            '&"prisma_da_serpente", &"olho_cobra_grande"]',
        )
        crendice_file.write_text(txt, encoding="utf-8")
        print("Updated crendice_database.gd with spider and serpent boss crendices.")


# ---------------------------------------------------------------------------
# Update CSV localizations
# ---------------------------------------------------------------------------
CRENDICE_LOCALIZATIONS = [
    ("CRENDICE_TEIA_MATRIARCA_NAME", "Teia da Matriarca Golias"),
    ("CRENDICE_TEIA_MATRIARCA_DESC", "+15% de Esquiva e imunidade total a Lentidão (Slow)."),
    ("CRENDICE_TEIA_MATRIARCA_LORE", "Tecida nos labirintos subterrâneos da maior predadora de oito patas da floresta. Fios de seda grossa que amortecem passos e aprisionam o perigo."),
    ("CRENDICE_TEIA_MATRIARCA_SUP", "A esquiva dobra quando o combatente permanece parado em emboscada por 3 segundos."),
    ("CRENDICE_OLHO_COBRA_GRANDE_NAME", "Olho da Cobra-Grande"),
    ("CRENDICE_OLHO_COBRA_GRANDE_DESC", "+12% de Dano Físico e +12 Dano Mágico."),
    ("CRENDICE_OLHO_COBRA_GRANDE_LORE", "Preserva o olhar magnético e soberano da colossal serpente dos rios profundos, reverenciada nas narrativas ribeirinhas."),
    ("CRENDICE_OLHO_COBRA_GRANDE_SUP", "O poder pleno desperta apenas em proximidade com cursos d'água ou sob precipitação de chuva."),
]


def update_localizations():
    # Items and crendices live in content.csv (items.csv / crendice.csv never existed in the project).
    wg.csv_add("localization/content.csv", ITEM_LOCALIZATIONS)
    wg.csv_add("localization/content.csv", CRENDICE_LOCALIZATIONS)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("=== Building Brazilian Fauna & Flora Monsters for Nação Pindorama ===")
    generate_sprites()
    write_items()
    generate_monster_defs()
    update_crendice_database()
    update_localizations()
    wg.finish(None, "folklore_native_monsters")
    print("=== Successfully Built All Brazilian Fauna & Flora Monsters ===")
