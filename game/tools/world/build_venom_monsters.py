#!/usr/bin/env python3
"""Build and register 10 dangerous/venomous monsters inspired by Brazilian fauna.
Creates items, localizations, sprite sheets with palette tinting, and monster definitions
with 4 stages each: Stage 1 (normal), Stage 2 (veterano), Stage 3 (boss), Stage 4 (atroz).
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

ITEMS = [
    ("venom_gland", "ITEM_VENOM_GLAND_NAME", "ITEM_VENOM_GLAND_DESC", "icon_item_firefly_light.png", 12),
    ("scorpion_stinger", "ITEM_SCORPION_STINGER_NAME", "ITEM_SCORPION_STINGER_DESC", "icon_item_ancient_shell_shard.png", 15),
    ("spider_silk", "ITEM_SPIDER_SILK_NAME", "ITEM_SPIDER_SILK_DESC", "icon_item_ribbon_bracelet.png", 14),
    ("serpent_fang", "ITEM_SERPENT_FANG_NAME", "ITEM_SERPENT_FANG_DESC", "icon_item_ancient_shell_shard.png", 16),
    ("urticating_spine", "ITEM_URTICATING_SPINE_NAME", "ITEM_URTICATING_SPINE_DESC", "icon_item_pequi_root.png", 14),
    ("wild_honeycomb", "ITEM_WILD_HONEYCOMB_NAME", "ITEM_WILD_HONEYCOMB_DESC", "icon_item_spinning_leaf.png", 18),
    ("chitin_shard", "ITEM_CHITIN_SHARD_NAME", "ITEM_CHITIN_SHARD_DESC", "icon_item_armadillo_shell.png", 10),
]

ITEM_LOCALIZATIONS = [
    ("ITEM_VENOM_GLAND_NAME", "Bolsa de Peçonha"),
    ("ITEM_VENOM_GLAND_DESC", "Bolsa de peçonha concentrada extraída de criaturas perigosas da fauna brasileira. Muito cobiçada por boticários para poções e antídotos."),
    ("ITEM_SCORPION_STINGER_NAME", "Ferrão de Escorpião"),
    ("ITEM_SCORPION_STINGER_DESC", "Ferrão quitinoso curvado e rígido. Usado em flechas e pontas perfurantes."),
    ("ITEM_SPIDER_SILK_NAME", "Seda de Aranha"),
    ("ITEM_SPIDER_SILK_DESC", "Fios de seda ultra-resistentes colhidos de aranhas peçonhentas. Flexível e de altíssima tração."),
    ("ITEM_SERPENT_FANG_NAME", "Presa de Serpente"),
    ("ITEM_SERPENT_FANG_DESC", "Presa pontiaguda e oca usada para inocular toxinas letais. Excelente matéria-prima artesanal."),
    ("ITEM_URTICATING_SPINE_NAME", "Cerdas Urticantes"),
    ("ITEM_URTICATING_SPINE_DESC", "Espinhos finos e ramificados de taturana que provocam ardência e inflamação severa."),
    ("ITEM_WILD_HONEYCOMB_NAME", "Favo Selvagem"),
    ("ITEM_WILD_HONEYCOMB_DESC", "Favo repleto de mel silvestre puro colhido de colmeias agressivas. Rico em energia e vigor."),
    ("ITEM_CHITIN_SHARD_NAME", "Fragmento de Quitina"),
    ("ITEM_CHITIN_SHARD_DESC", "Placa endurecida do exoesqueleto de artrópodes. Usada no reforço de armaduras leves."),
]

# Configurações das 10 espécies:
# (id, pt_names[4], primary_drop, levels[4], behavior, src_species, tints[4], scales[4])
# Tints: RGB tuple + blend factor (0.0 to 1.0)
# src_species = BLENDER: folhas próprias feitas no pipeline de monstros do Blender (docs/arte-monstros-blender.md;
# tools/art/blender/monsters/<id>.py + build_all.sh <id>), sem recolor — os tints dessas espécies não são usados.
# Chefe (3) e atroz (4) dessas espécies têm arte única em quadro 240 (como os chefes aprovados): visual_scale 1,0.
BLENDER = None
SPECIES_DATA = [
    (
        "yellow_scorpion",
        ["Escorpião-Amarelo", "Escorpião-Amarelo Veterano", "Ferrão-Dourado do Entulho", "Escorpião-Amarelo Atroz"],
        "scorpion_stinger",
        [4, 9, 23, 29],
        "roll_charge",
        "dune_scorpion",
        [((255, 215, 30), 0.75), ((245, 195, 20), 0.8), ((255, 180, 10), 0.85), ((230, 150, 0), 0.9)],
        [0.95, 1.15, 1.4, 1.7],
    ),
    (
        "wandering_spider",
        ["Aranha-Armadeira", "Aranha-Armadeira Veterana", "Armadeira Rainha dos Desvãos", "Aranha-Armadeira Atroz"],
        "spider_silk",
        [5, 10, 24, 30],
        "roll_charge",
        BLENDER,  # aranha-armadeira: wandering_spider.py (antes: iguana de obsidiana recolorida)
        [((130, 65, 30), 0.7), ((115, 45, 20), 0.75), ((95, 30, 15), 0.8), ((75, 18, 10), 0.85)],
        [1.0, 1.2, 1.45, 1.75],
    ),
    (
        "brown_recluse",
        ["Aranha-Marrom", "Aranha-Marrom Tecedeira", "Tecedeira da Necrose", "Aranha-Marrom Atroz"],
        "spider_silk",
        [4, 8, 22, 28],
        "boss",  # behavior
        BLENDER,  # aranha-marrom: brown_recluse.py (antes: iguana de obsidiana recolorida)
        [((160, 125, 90), 0.65), ((135, 95, 60), 0.7), ((105, 75, 45), 0.75), ((80, 55, 30), 0.8)],
        [0.85, 1.05, 1.3, 1.55],
    ),
    (
        "jararaca_serpent",
        ["Jararaca da Mata", "Jararaca Veloz", "Bote-Fulminante da Taboa", "Jararaca Atroz"],
        "serpent_fang",
        [5, 10, 24, 30],
        "ranged",
        "cinder_serpent",
        [((110, 115, 60), 0.65), ((90, 95, 45), 0.7), ((70, 75, 35), 0.75), ((55, 60, 25), 0.8)],
        [1.0, 1.2, 1.45, 1.75],
    ),
    (
        "rattlesnake",
        ["Cascavel dos Pastos", "Cascavel Sonante", "Cascavel do Guizo Sombrio", "Cascavel Atroz"],
        "serpent_fang",
        [6, 11, 25, 31],
        "ranged",
        "cinder_serpent",
        [((180, 145, 80), 0.7), ((160, 125, 65), 0.75), ((135, 100, 50), 0.8), ((110, 80, 35), 0.85)],
        [1.05, 1.25, 1.5, 1.8],
    ),
    (
        "surucucu_serpent",
        ["Surucucu Pico-de-Jaca", "Surucucu Imponente", "Soberana Pico-de-Jaca", "Surucucu Atroz"],
        "serpent_fang",
        [7, 13, 27, 33],
        "ranged",
        "cinder_serpent",
        [((205, 105, 30), 0.75), ((180, 85, 20), 0.8), ((155, 65, 10), 0.85), ((130, 45, 5), 0.9)],
        [1.2, 1.4, 1.7, 2.05],
    ),
    (
        "coral_snake",
        ["Coral-Verdadeira", "Coral de Anéis Mortais", "Rainha dos Anéis Escarlates", "Coral-Verdadeira Atroz"],
        "serpent_fang",
        [6, 11, 25, 31],
        "roll_charge",
        "fountain_serpent",
        [((230, 40, 25), 0.75), ((200, 30, 15), 0.8), ((170, 20, 10), 0.85), ((140, 10, 5), 0.9)],
        [1.0, 1.2, 1.45, 1.75],
    ),
    (
        "lonomia_caterpillar",
        ["Taturana Lonomia", "Taturana Espinhosa", "Lonomia Matriarca das Urtigas", "Taturana Lonomia Atroz"],
        "urticating_spine",
        [4, 9, 23, 29],
        "boss",
        BLENDER,  # taturana: lonomia_caterpillar.py (antes: tatu-pedra recolorido)
        [((100, 135, 60), 0.7), ((80, 110, 45), 0.75), ((65, 90, 35), 0.8), ((50, 70, 25), 0.85)],
        [0.9, 1.1, 1.35, 1.65],
    ),
    (
        "killer_bee",
        ["Enxame de Abelhas-Ferozes", "Enxame Zumbidor", "Rainha do Cortiço Bravo", "Abelha Assassina Atroz"],
        "wild_honeycomb",
        [4, 9, 23, 29],
        "fly_pattern",
        "enchanted_firefly",
        [((235, 180, 25), 0.75), ((210, 150, 15), 0.8), ((185, 125, 10), 0.85), ((160, 100, 5), 0.9)],
        [0.9, 1.1, 1.35, 1.65],
    ),
    (
        "aedes_mosquito",
        ["Mosquito Aedes", "Aedes Vetor Pestilento", "Zumbidor da Febre Negra", "Aedes Aegypti Atroz"],
        "chitin_shard",
        [3, 8, 22, 28],
        "fly_pattern",
        "enchanted_firefly",
        [((115, 125, 135), 0.7), ((90, 100, 110), 0.75), ((65, 75, 85), 0.8), ((45, 55, 65), 0.85)],
        [0.8, 1.0, 1.25, 1.5],
    ),
]


# Chance de drop nos estágios comuns (1 e 2). Chefe (3) e atroz (4): material 100% e peçonha 80%.
VENOM_DROP_CHANCE = 0.4
PRIMARY_DROP_CHANCE = {"killer_bee": 0.5}  # Favo Selvagem: só a abelha solta


def write_items():
    items_dir = GAME_DIR / "data/items"
    items_dir.mkdir(parents=True, exist_ok=True)
    for item_id, name_key, desc_key, icon_file, sell_price in ITEMS:
        content = f"""[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Texture2D" path="res://assets/items/icons/{icon_file}" id="1_icon"]
[ext_resource type="Script" path="res://scripts/shared/data/item_def.gd" id="2_script"]

[resource]
script = ExtResource("2_script")
id = &"{item_id}"
name_key = "{name_key}"
desc_key = "{desc_key}"
icon = ExtResource("1_icon")
stackable = true
max_stack = 99
sell_price = {sell_price}
"""
        (items_dir / f"{item_id}.tres").write_text(content, encoding="utf-8")
    print(f"Created {len(ITEMS)} items in data/items/")


def update_content_localization():
    p = GAME_DIR / "localization/content.csv"
    existing_keys = set()
    rows = []
    if p.exists():
        for r in csv.reader(io.StringIO(p.read_text(encoding="utf-8"))):
            if r:
                rows.append(r)
                existing_keys.add(r[0])
    additions = []
    for k, v in ITEM_LOCALIZATIONS:
        if k not in existing_keys:
            additions.append([k, v])
            existing_keys.add(k)
    if additions:
        buf = io.StringIO()
        csv.writer(buf, lineterminator="\n").writerows(rows + additions)
        p.write_text(buf.getvalue(), encoding="utf-8")
        print(f"Added {len(additions)} items to content.csv")


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
        dest_dir = mon_assets_dir / mid
        if src_mid is BLENDER:
            # folhas instaladas pelo post.py do pipeline do Blender: so confere que estao todas la
            for st in range(1, 5):
                for anim in anims:
                    if not (dest_dir / f"mon_{mid}_s{st}_{anim}.png").exists():
                        print(f"Warning: missing Blender sheet mon_{mid}_s{st}_{anim}.png (build_all.sh {mid})")
            continue
        dest_dir.mkdir(parents=True, exist_ok=True)
        src_dir = mon_assets_dir / src_mid

        for st in range(1, 5):
            tint_color, tint_factor = tints[st - 1]
            for anim in anims:
                # Find best source sheet for this stage
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
                    print(f"Warning: could not find source anim {anim} for {src_mid}")
                    continue

                dest_file = dest_dir / f"mon_{mid}_s{st}_{anim}.png"
                if not dest_file.exists():
                    tint_image(src_file, dest_file, tint_color, tint_factor)

    print("Sprite generation and imports completed.")


def build_monster_defs():
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

            # Stats computation
            if boss:
                hp = 5000 + index * 200 + (600 if st == 4 else 0)
                atk = 62 + index * 2
                defense = 30 + (index % 5) * 2
                mdef = 18 + (index % 4) * 2
            else:
                hp = round((70 + level * 16) * (1.6 if st == 2 else 1.0))
                atk = 8 + level * 2
                defense = max(2, level // 2)
                mdef = max(2, level // 3)

            walk_ms = 330 if st == 4 else 420 if boss else 380
            atk_interval = 1300 if st == 4 else 1700 if boss else 1600

            # Behaviors list
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

            # Drops comuns (estágios 1 e 2): estes monstros são a única fonte de Bolsa de Peçonha e (a abelha) de
            # Favo Selvagem, que as quests de título pedem em 4–8 unidades e os ofícios gastam. ~10 abates por 4.
            mat_chance = 1.0 if boss else PRIMARY_DROP_CHANCE.get(mid, 0.35)
            venom_chance = 0.8 if boss else VENOM_DROP_CHANCE

            parts += [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]',
                f'script = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {mat_chance}\nmin_qty = {2 if boss else 1}\nmax_qty = {6 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_venom_{st}"]',
                f'script = ExtResource("drop")\nitem_id = &"venom_gland"\nchance = {venom_chance}\nmin_qty = {1}\nmax_qty = {3 if boss else 1}',
                f'[sub_resource type="Resource" id="drop_pot_{st}"]',
                f'script = ExtResource("drop")\nitem_id = &"potion_hp_{"medium" if st > 1 else "small"}"\nchance = {0.6 if boss else 0.12}',
                f'[sub_resource type="Resource" id="stage{st}"]',
                f"""script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {1.0 if (src_mid is BLENDER and boss) else scales[st - 1]}
level = {level}
max_hp = {hp}
atk = {atk}
matk = {atk if behavior == "ranged" else 0}
def = {defense}
mdef = {mdef}
walk_ms_per_cell = {walk_ms}
attack_range_cells = {4.5 if behavior == "ranged" else 2.0 if boss else 1.5}
attack_interval_ms = {atk_interval}
aggressive = {str(st > 1).lower()}
aggro_range_cells = {9 if st == 4 else 7 if boss else 5}
leash_cells = {20 if st == 4 else 16 if boss else 12}
xp_reward = {(1500 + index * 120) * (2 if st == 4 else 1) if boss else level * 12}
stars_min = {120 if st == 4 else 60 if boss else max(1, level // 2)}
stars_max = {240 if st == 4 else 120 if boss else level + 4}
behaviors = {behaviors_str}
drops = Array[ExtResource("drop")]([SubResource("drop_mat_{st}"), SubResource("drop_venom_{st}"), SubResource("drop_pot_{st}")])""",
            ]

        parts += [
            "[resource]",
            f"""script = ExtResource("monster")
id = &"{mid}"
region_id = &"brasil"
creature_type = &"beast"
stages = Array[ExtResource("stage")]([SubResource("stage1"), SubResource("stage2"), SubResource("stage3"), SubResource("stage4")])""",
        ]

        (monsters_dir / f"{mid}.tres").write_text("\n\n".join(parts) + "\n", encoding="utf-8")

    # Update monsters.csv
    p = GAME_DIR / "localization/monsters.csv"
    existing_keys = {row[0] for row in csv.reader(io.StringIO(p.read_text(encoding="utf-8")))} if p.exists() else set()
    new_translations = [t for t in translations if t[0] not in existing_keys]
    if new_translations:
        orig = p.read_text(encoding="utf-8") if p.exists() else "keys,pt_BR\n"
        buf = io.StringIO()
        writer = csv.writer(buf, lineterminator="\n")
        writer.writerows(new_translations)
        p.write_text(orig.rstrip() + "\n" + buf.getvalue(), encoding="utf-8")
        print(f"Added {len(new_translations)} keys to monsters.csv")

    print(f"Generated {len(SPECIES_DATA)} MonsterDef resources.")


def main():
    print("Building items...")
    write_items()
    print("Updating content localization...")
    update_content_localization()
    print("Generating monster sprites...")
    generate_sprites()
    print("Building monster definitions...")
    build_monster_defs()
    wg.finish(None, "venom_monsters")
    print("Done!")


if __name__ == "__main__":
    main()
