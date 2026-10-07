#!/usr/bin/env python3
"""Build and register cave monsters: cave_skeleton, cave_zombie, cave_bat.
Each monster has 4 stages: Stage 1 (normal), Stage 2 (veterano), Stage 3 (boss), Stage 4 (atroz).
Skeletons and zombies have creature_type = &"undead" (vulnerable to silver & holy).
Bats have creature_type = &"beast" and &"fly_pattern".
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

CAVE_SPECIES = [
    (
        "cave_skeleton",
        ["Esqueleto Errante", "Esqueleto Guerreiro", "Senhor das Ossadas", "Esqueleto Atroz"],
        "ancient_shell_shard",
        [14, 20, 26, 32],
        "boss",
        "hopping_jiangshi",
        "undead",
        [((225, 218, 205), 0.8), ((205, 198, 185), 0.85), ((185, 178, 165), 0.85), ((160, 150, 140), 0.9)],
        [1.0, 1.15, 1.4, 1.7],
    ),
    (
        "cave_zombie",
        ["Carniçal das Sombras", "Morto-vivo Fétido", "Abominação Cadavérica", "Morto-vivo Atroz"],
        "thick_leather",
        [15, 21, 27, 33],
        "boss",
        "moss_troll",
        "undead",
        [((95, 120, 90), 0.7), ((75, 100, 70), 0.75), ((60, 80, 55), 0.8), ((45, 60, 40), 0.85)],
        [1.0, 1.2, 1.5, 1.8],
    ),
    (
        "cave_bat",
        ["Morcego Cavernoso", "Morcego Vampiro", "Quiróptero Ancião", "Morcego Sanguinário Atroz"],
        "firefly_light",
        [12, 18, 25, 31],
        "fly_pattern",
        "enchanted_firefly",
        "beast",
        [((65, 45, 75), 0.8), ((50, 30, 60), 0.85), ((38, 20, 48), 0.85), ((25, 12, 35), 0.9)],
        [0.85, 1.05, 1.35, 1.6],
    ),
]


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


def generate_cave_sprites():
    anims = ["idle", "walk", "attack", "hit", "death"]
    mon_assets_dir = GAME_DIR / "assets/monsters"

    for mid, names, drop, levels, behavior, src_mid, ctype, tints, scales in CAVE_SPECIES:
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

    print("Cave monster sprites generated.")


def build_cave_monster_defs():
    monsters_dir = GAME_DIR / "data/monsters"
    monsters_dir.mkdir(parents=True, exist_ok=True)
    translations = []

    for index, (mid, names, primary_drop, levels, behavior, src_mid, ctype, tints, scales) in enumerate(CAVE_SPECIES):
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
                hp = 7800 + index * 900 + (1000 if st == 4 else 0)
                atk = 90 + index * 6
                defense = 36 + index * 6
                mdef = 25 + index * 4
            else:
                hp = round((110 + level * 28) * (1.65 if st == 2 else 1.0))
                atk = 18 + level * 2
                defense = max(6, level // 2)
                mdef = max(4, level // 3)

            walk_ms = 310 if st == 4 else 420 if boss else 380
            if mid == "cave_zombie":
                walk_ms += 50
            elif mid == "cave_bat":
                walk_ms -= 50

            atk_interval = 1200 if st == 4 else 1650 if boss else 1500
            if mid == "cave_zombie":
                atk_interval += 150
            elif mid == "cave_bat":
                atk_interval -= 150

            st_behaviors = []
            if behavior == "fly_pattern":
                st_behaviors.append('&"fly_pattern"')
            if boss:
                st_behaviors.append('&"boss"')

            behaviors_str = f"Array[StringName]([{', '.join(st_behaviors)}])" if st_behaviors else "Array[StringName]([])"

            parts += [
                f'[sub_resource type="Resource" id="drop_mat_{st}"]',
                f'script = ExtResource("drop")\nitem_id = &"{primary_drop}"\nchance = {1.0 if boss else 0.4}\nmin_qty = {2 if boss else 1}\nmax_qty = {6 if boss else 2}',
                f'[sub_resource type="Resource" id="drop_pot_{st}"]',
                f'script = ExtResource("drop")\nitem_id = &"potion_hp_{"medium" if st > 1 else "small"}"\nchance = {0.6 if boss else 0.15}',
                f'[sub_resource type="Resource" id="stage{st}"]',
                f"""script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {scales[st - 1]}
level = {level}
max_hp = {hp}
atk = {atk}
matk = 0
def = {defense}
mdef = {mdef}
walk_ms_per_cell = {walk_ms}
attack_range_cells = {2.0 if boss else 1.5}
attack_interval_ms = {atk_interval}
aggressive = true
aggro_range_cells = {9 if st == 4 else 7 if boss else 6}
leash_cells = {20 if st == 4 else 16 if boss else 14}
xp_reward = {(2200 + index * 300) * (2 if st == 4 else 1) if boss else level * 14}
stars_min = {150 if st == 4 else 75 if boss else max(2, level // 2)}
stars_max = {300 if st == 4 else 150 if boss else level + 6}
behaviors = {behaviors_str}
drops = Array[ExtResource("drop")]([SubResource("drop_mat_{st}"), SubResource("drop_pot_{st}")])""",
            ]

        parts += [
            "[resource]",
            f"""script = ExtResource("monster")
id = &"{mid}"
region_id = &"brasil"
creature_type = &"{ctype}"
stages = Array[ExtResource("stage")]([SubResource("stage1"), SubResource("stage2"), SubResource("stage3"), SubResource("stage4")])""",
        ]

        (monsters_dir / f"{mid}.tres").write_text("\n\n".join(parts) + "\n", encoding="utf-8")

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

    print("Cave monster definitions built.")


def main():
    generate_cave_sprites()
    build_cave_monster_defs()
    wg.finish(None, 'cave_monsters')


if __name__ == "__main__":
    main()
