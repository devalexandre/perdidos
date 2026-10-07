"""Register the three new Sabia species after exporting their native Blender sprites.
Stage 2 is a veteran using the normal model; bosses and atrocious forms have their own art.
"""
from pathlib import Path
import csv
import io

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

GAME = Path(__file__).resolve().parents[2]
## Boss gear (stage 3/4 of the base species; 10/03 balance pass).
BOSS_GEAR = {'buriti_boar': 'moss_crown', 'cinder_serpent': 'cinder_ring', 'ember_mule': 'ember_machete'}
SPECIES = [
    ('buriti_boar', ['Queixada de Buriti', 'Queixada Veterana', 'Queixada do Veredão', 'Queixada das Raízes Negras'], 'thick_leather', [3, 8, 22, 28], 'roll_charge'),
    ('cinder_serpent', ['Serpente-Fagulha', 'Serpente-Fagulha Veterana', 'Serpente do Fogo Errante', 'Serpente da Cinza Viva'], 'firefly_light', [4, 9, 23, 29], 'ranged'),
    ('ember_mule', ['Mula de Brasa', 'Mula de Brasa Veterana', 'Mula da Queimada', 'Mula da Noite Ardente'], 'thick_leather', [6, 11, 24, 30], 'roll_charge'),
]


def build():
    translations = []
    for index, (mid, names, drop, levels, behavior) in enumerate(SPECIES):
        for advanced in (False, True):
            monster_id = ('highland_' if advanced else '') + mid
            parts = ['[gd_resource type="Resource" script_class="MonsterDef" format=3]',
                     '[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="monster"]',
                     '[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]',
                     '[ext_resource type="Script" path="res://scripts/shared/data/drop_entry.gd" id="drop"]']
            for st in range(1, 5):
                level = (12 + index * 2 + (4 if st == 2 else 0)) if advanced and st <= 2 else levels[st-1]
                key = f'MON_{monster_id.upper()}_S{st}_NAME'
                name = names[st-1] + (' da Chapada' if advanced and st <= 2 else '')
                translations.append([key, name])
                boss = st >= 3
                hp = (5500 + index*600) if boss else round((65 + level*15) * (1.65 if st == 2 else 1))
                atk = (65 + index*8) if boss else 5 + level*2
                parts += [f'[sub_resource type="Resource" id="drop{st}"]', f'script = ExtResource("drop")\nitem_id = &"{drop}"\nchance = {1.0 if boss else 0.3}\nmin_qty = {3 if boss else 1}\nmax_qty = {8 if boss else 2}',
                          f'[sub_resource type="Resource" id="potion{st}"]', f'script = ExtResource("drop")\nitem_id = &"potion_hp_{"medium" if st > 1 else "small"}"\nchance = {0.5 if boss else 0.08}',
                          ]
                gear = BOSS_GEAR.get(mid) if boss and not advanced else None
                if gear and st == 3:
                    parts.append(f'[sub_resource type="Resource" id="gear_boss"]\nscript = ExtResource("drop")\nitem_id = &"{gear}"\nchance = 0.08')
                parts += [f'[sub_resource type="Resource" id="stage{st}"]',
                          f'''script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{1 if st == 2 else st}"
baked_life = true
visual_scale = {1.15 if st == 2 else 1.0}
level = {level}
max_hp = {hp}
atk = {atk}
matk = {atk if behavior == 'ranged' else 0}
def = {35 if boss else max(2, level // 2)}
mdef = {20 if boss else max(2, level // 3)}
walk_ms_per_cell = {380 if st == 4 else 440 if boss else 380}
attack_range_cells = {5.0 if behavior == 'ranged' else 2.0 if boss else 1.5}
attack_interval_ms = {1400 if st == 4 else 1800}
aggressive = {str(st > 1 or advanced).lower()}
aggro_range_cells = {9 if st == 4 else 7 if boss else 5}
leash_cells = {20 if st == 4 else 16 if boss else 12}
xp_reward = {(1600 + index*150) * (2 if st == 4 else 1) if boss else level*10}
stars_min = {140 if st == 4 else 70 if boss else level//2}
stars_max = {280 if st == 4 else 140 if boss else level+3}
behaviors = Array[StringName]([&"{behavior}"{', &"boss"' if boss else ''}])
drops = Array[ExtResource("drop")]([SubResource("drop{st}"), SubResource("potion{st}"){', SubResource("gear_boss")' if gear else ''}])''']
            parts += ['[resource]', f'script = ExtResource("monster")\nid = &"{monster_id}"\nregion_id = &"brasil"\n' + (f'base_species = &"{mid}"\n' if advanced else '') + 'stages = Array[ExtResource("stage")]([SubResource("stage1"), SubResource("stage2"), SubResource("stage3"), SubResource("stage4")])']
            (GAME/'data/monsters'/f'{monster_id}.tres').write_text('\n\n'.join(parts)+'\n')
    wg.csv_set('localization/monsters.csv', translations)  # in place: keeps the file order


if __name__ == '__main__':
    build()
    wg.finish(None, 'sabia_monsters')
