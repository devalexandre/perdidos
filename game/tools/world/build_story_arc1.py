#!/usr/bin/env python3
"""
build_story_arc1.py — Arco 1 da história (ARCO-1-TERRA-DE-PINDORAMA.md, seções 2.1 e 10).

1. Variantes de monstros para os mapas novos (recolor dos existentes, base_species = a original):
   jacarés, sucuris e serpentes do Abismo do Sumidouro; serpentes-fagulha e mulas de brasa do andar 5 da Caverna;
   fogo-fátuo do Boitatá (invocação da fase 2 da luta).
2. Mapas novos (protótipos jogáveis, mesmo motor dos andares da Terra Oca):
   - sumidouro_abyss        Abismo do Sumidouro (sai do Arraial do Sumidouro), covil da Boiúna;
   - cave_reino_encoberto_5 Câmara da Fogueira que Respira (sai do covil do andar 4, só com o final liberado),
                            covil do Boitatá;
   - hollow_earth_cauldron  Gruta do Caldeirão (sai do andar 5 da Terra Oca), covil da Cuca.
3. Remendo dos mapas que já existem (o gerador dono deles roda antes, no build_all): covis StoryLairs/, marcadores
   das quests, NPCs novos, portais para os mapas novos e a meta day_only do covil do andar 4. Os nós que este
   gerador possui são tirados e postos de novo a cada execução (idempotente).
Chefe com `art_pending = true` no .tres NÃO ganha covil (Iara e Boitatá, enquanto a arte não chega): quando a arte
for instalada e o `art_pending` sair, rodar o build_all põe o covil sozinho.
Rodar de game/: ../.tools/pyvenv/bin/python3 tools/world/build_story_arc1.py [--check]
"""

import re
from pathlib import Path

from PIL import Image

import worldgen as wg
import build_hollow_earth_expansion as he

he.LEGACY_ROUTES = False
GAME_DIR = wg.GAME_DIR

# ---------------------------------------------------------------------------------------------------- monstros
# id, base (sprites/drops), nomes s1/s2, níveis, tinta (rgb, fator), comportamentos, drop principal
VARIANTS = [
    ("abyss_black_caiman", "black_caiman", ["Jacaré do Abismo", "Jacaré-Açu do Abismo"], [50, 54],
     ((20, 40, 60), 0.45), [], "caiman_plate"),
    ("abyss_river_anaconda", "river_anaconda", ["Sucuri do Abismo", "Sucuri da Tempestade"], [51, 55],
     ((25, 20, 55), 0.45), [], "anaconda_scale"),
    ("abyss_water_serpent", "fountain_serpent", ["Serpente das Águas Negras", "Serpente do Redemoinho Negro"],
     [49, 53], ((10, 30, 45), 0.5), ["ranged"], "anaconda_scale"),
    ("deep_cinder_serpent", "cinder_serpent", ["Serpente-Fagulha Profunda", "Serpente de Brasa Negra"], [55, 58],
     ((40, 10, 30), 0.45), [], "potion_hp_medium"),
    ("deep_ember_mule", "ember_mule", ["Mula de Brasa Profunda", "Mula da Fogueira Negra"], [56, 59],
     ((35, 8, 20), 0.45), ["roll_charge"], "potion_hp_medium"),
]
ANIMS = ["idle", "walk", "attack", "hit", "death"]


def tint(src: Path, dst: Path, rgb, factor):
    img = Image.open(src).convert("RGBA")
    r, g, b, a = img.split()
    out = Image.blend(img.convert("RGB"), Image.new("RGB", img.size, rgb), factor)
    tr, tg, tb = out.split()
    wg.save_image(Image.merge("RGBA", (tr, tg, tb, a)), dst)


def base_sprite(base: str, st: int) -> Path | None:
    for cand in (st, 1):
        p = GAME_DIR / f"assets/monsters/{base}/mon_{base}_s{cand}_idle.png"
        if p.exists():
            return GAME_DIR / f"assets/monsters/{base}/mon_{base}_s{cand}"
    return None


def build_variants():
    names = []
    for mid, base, nm, levels, (rgb, factor), behaviors, drop in VARIANTS:
        stages = []
        for i, st in enumerate((1, 2)):
            src = base_sprite(base, st)
            if src is None:
                raise wg.WorldGenError(f"{mid}: no sprites for {base}")
            for anim in ANIMS:
                s = Path(f"{src}_{anim}.png")
                if s.exists():
                    tint(s, GAME_DIR / f"assets/monsters/{mid}/mon_{mid}_s{st}_{anim}.png", rgb, factor)
            key = f"MON_{mid.upper()}_S{st}_NAME"
            names.append((key, nm[i]))
            lvl = levels[i]
            hp = int((1500 + lvl * 85) * (1.0 if st == 1 else 1.4))
            atk = int(58 + lvl * 3.1)
            beh = ", ".join(f'&"{b}"' for b in behaviors)
            stages.append(f'''[sub_resource type="Resource" id="drop_{st}"]
script = ExtResource("drop")
item_id = &"{drop}"
chance = 0.35
min_qty = 1
max_qty = 2

[sub_resource type="Resource" id="potion_{st}"]
script = ExtResource("drop")
item_id = &"potion_hp_medium"
chance = 0.08

[sub_resource type="Resource" id="stage{st}"]
script = ExtResource("stage")
stage = {st}
name_key = "{key}"
sprite_base = "res://assets/monsters/{mid}/mon_{mid}_s{st}"
baked_life = true
visual_scale = {1.1 if st == 1 else 1.3}
level = {lvl}
max_hp = {hp}
atk = {atk}
matk = {atk if "ranged" in behaviors else 0}
def = {int(28 + lvl * 1.5)}
mdef = {int(24 + lvl * 1.6)}
walk_ms_per_cell = {500 if st == 1 else 470}
attack_range_cells = {4.5 if "ranged" in behaviors else 1.6}
attack_interval_ms = {1350 if st == 1 else 1200}
aggressive = true
aggro_range_cells = {5 if st == 1 else 6}
leash_cells = 12
xp_reward = {lvl * 20 * st}
stars_min = {lvl // 2}
stars_max = {lvl + 10}
behaviors = Array[StringName]([{beh}])
drops = Array[ExtResource("drop")]([SubResource("drop_{st}"), SubResource("potion_{st}")])
''')
        text = f'''[gd_resource type="Resource" script_class="MonsterDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="mdef"]
[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]
[ext_resource type="Script" path="res://scripts/shared/data/drop_entry.gd" id="drop"]

{chr(10).join(stages)}
[resource]
script = ExtResource("mdef")
id = &"{mid}"
region_id = &"brasil"
stages = Array[ExtResource("stage")]([SubResource("stage1"), SubResource("stage2")])
respawn_sec = 45.0
base_species = &"{base}"
'''
        wg.write_text(GAME_DIR / f"data/monsters/{mid}.tres", text)
    # Fogo-fátuo do Boitatá: invocação da fase 2 (não nasce em Spawns/; persegue e deixa rastro de fogo).
    names.append(("MON_BOITATA_WISP_NAME", "Fogo-Fátuo do Boitatá"))
    wg.write_text(GAME_DIR / "data/monsters/boitata_wisp.tres", '''[gd_resource type="Resource" script_class="MonsterDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="mdef"]
[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="stage"]

[sub_resource type="Resource" id="stage1"]
script = ExtResource("stage")
stage = 1
name_key = "MON_BOITATA_WISP_NAME"
sprite_base = "res://assets/monsters/enchanted_firefly/mon_enchanted_firefly_s2"
baked_life = true
visual_scale = 1.2
level = 58
max_hp = 3800
atk = 160
matk = 160
def = 60
mdef = 90
walk_ms_per_cell = 330
attack_range_cells = 1.5
attack_interval_ms = 1100
aggressive = true
aggro_range_cells = 14
leash_cells = 30
xp_reward = 0
behaviors = Array[StringName]([&"fly_pattern"])

[resource]
script = ExtResource("mdef")
id = &"boitata_wisp"
region_id = &"brasil"
stages = Array[ExtResource("stage")]([SubResource("stage1")])
respawn_sec = 0.0
can_be_rare = false
''')
    wg.csv_add("localization/monsters.csv", names)


# ---------------------------------------------------------------------------------------------------- covis da história
# mapa -> (nó, chefe, posição, bando, estágio do bando)
STORY_LAIRS = {
    "fields_pindorama_crossroads": ("saci", "story_saci", (8, 0, 16), {"prank_whirlwind": 12}, 1),
    "enchanted_forest_heart": ("curupira", "story_curupira", (0, 0, -6),
                               {"enchanted_firefly": 4, "pindorama_jaguar": 3, "buriti_boar": 3}, 2),
    "cave_reino_encoberto_4": ("lobisomem", "story_lobisomem", (0, 0, -24), {"cave_werewolf": 4, "cave_bat": 6}, 2),
    "hoer_verde_4": ("pisadeira", "story_pisadeira", (-14, 0, -20), {"despair_possessed": 5, "whispering_shade": 5}, 2),
    "split_sky_plateau_summit": ("mula", "story_mula", (0, 0, 0),
                                 {"highland_ember_mule": 6, "highland_cinder_serpent": 4}, 1),
    "ruins_ratanaba_4": ("mapinguari", "story_mapinguari", (-12, 0, -24),
                         {"ratanaba_sentinel": 6, "crystal_serpent": 4}, 2),
    "jungle_z_river": ("iara", "story_iara", (-8, 0, 2), {"river_anaconda": 5, "black_caiman": 5}, 2),
    "hollow_earth_cauldron": ("cuca", "story_cuca", (0, 0, -12), {"shadow_weaver": 6, "living_crystal": 4}, 2),
    "sumidouro_abyss": ("boiuna", "story_boiuna", (0, 0, -10),
                        {"abyss_black_caiman": 4, "abyss_river_anaconda": 4, "abyss_water_serpent": 4}, 1),
    "cave_reino_encoberto_5": ("boitata", "story_boitata", (0, 0, -16),
                               {"deep_cinder_serpent": 5, "deep_ember_mule": 5}, 1),
}
# mapa -> {marcador na raiz: posição}
MARKERS = {
    "city_awakening": {"EleonorCrystal": (0.3, 0, 1.9)},
    "enchanted_forest_heart": {"BackwardTracks": (-6, 0, 10)},
    "cave_reino_encoberto_4": {"DeepPassage": (0, 0, -28), "DeepPassageReturn": (0, 0, -26)},
    "hoer_verde_4": {"StoryInn": (-14, 0, -20)},
    "split_sky_plateau_summit": {"BrasasCrossroads": (0, 0, 0)},
    "jungle_z_river": {"BoatmanHat": (-16, 0, 14), "BoatmanOar": (0, 0, -10), "BoatmanNet": (22, 0, 2)},
    "city_sumidouro": {"AbyssReturn": (10, 0, 26)},
    "hollow_earth_5": {"CauldronReturn": (-22, 0, 0)},
    "hollow_earth_cauldron": {"CauldronChamber": (0, 0, -8)},
}
NPC_POINTS = {
    "city_awakening": {"dona_jacinta": (-14, 0, 4), "dona_celeste": (9, 0, -12)},
    "hoer_verde_4": {"firmino_insone": (4, 0, 19)},
}
# mapa -> [portal]; "requires_quest": só passa quem tem a quest disponível, ativa ou feita (MapTransfer).
PORTALS = {
    "city_sumidouro": [{"name": "GateAbyss", "pos": (14, 1, 28), "target_map": "sumidouro_abyss",
                        "target_spawn": "SpawnPoint", "label": "↓ Abismo do Sumidouro"}],
    "hollow_earth_5": [{"name": "CauldronPassage", "pos": (-28, 1, 0), "target_map": "hollow_earth_cauldron",
                        "target_spawn": "SpawnPoint", "label": "Gruta do Caldeirão ←"}],
    "cave_reino_encoberto_4": [{"name": "DeepPassagePortal", "pos": (0, 1, -30), "target_map": "cave_reino_encoberto_5",
                                "target_spawn": "SpawnPoint", "label": "Passagem atrás da cachoeira ⇓",
                                "requires_quest": "arc1_final_boitata", "hidden_waterfall_passage": True}],
}
ZONE_LINKS = {
    "city_sumidouro": ["sumidouro_abyss"],
    "hollow_earth_5": ["hollow_earth_cauldron"],
    "cave_reino_encoberto_4": ["cave_reino_encoberto_5"],
}
# Covil de espécie que cede a noite ao chefe da história do mesmo lugar.
DAY_ONLY_LAIRS = {"cave_reino_encoberto_4": "werewolf"}
OWNED_MARKERS = {n for m in MARKERS.values() for n in m}
OWNED_NPCS = {n for m in NPC_POINTS.values() for n in m}
OWNED_PORTALS = {p["name"] for ps in PORTALS.values() for p in ps}
PORTAL_SHAPE = "story_portal_shape"


def art_pending(monster_id: str) -> bool:
    t = wg.read_text(GAME_DIR / f"data/monsters/{monster_id}.tres")
    return re.search(r"^art_pending = true", t, re.M) is not None


def _node(name, kind, parent, body):
    return f'[node name="{name}" type="{kind}" parent="{parent}"]\n{body}\n'


def _vec(p):
    return "Vector3(%s, %s, %s)" % tuple(p)


def patch_scene(map_id: str, extra_markers: dict | None = None):
    path = GAME_DIR / f"scenes/maps/{map_id}.tscn"
    text = wg.read_text(path)
    # Tira os blocos deste gerador (com a linha em branco que vem junto) e mantém o resto do arquivo intacto.
    blocks = re.split(r"(?m)^(?=\[)", text)
    keep = []
    for b in blocks:
        h = re.match(r'\[node name="([^"]+)" type="[^"]+"(?: parent="([^"]+)")?', b)
        if h:
            name, parent = h.group(1), h.group(2) or ""
            if (name == "StoryLairs" and parent == ".") or parent == "StoryLairs" \
                    or (parent == "." and name in OWNED_MARKERS) \
                    or (parent == "NpcPoints" and name in OWNED_NPCS) \
                    or (parent == "Interactables" and name in OWNED_PORTALS) \
                    or any(parent == f"Interactables/{p}" for p in OWNED_PORTALS):
                continue
        if re.match(rf'\[sub_resource type="BoxShape3D" id="{PORTAL_SHAPE}"\]', b):
            continue
        keep.append(b)
    out = "".join(keep).rstrip("\n") + "\n"
    # day_only no covil de espécie
    lair = DAY_ONLY_LAIRS.get(map_id)
    if lair:
        pat = re.compile(rf'(\[node name="{lair}" type="Marker3D" parent="BossLairs"\]\n(?:(?!\[).*\n)*?)(?=\n|\[|$)')
        m = pat.search(out)
        if m is None:
            raise wg.WorldGenError(f"{map_id}: BossLairs/{lair} not found")
        if "metadata/day_only = true" not in m.group(1):
            out = out[:m.end(1)] + "metadata/day_only = true\n" + out[m.end(1):]
    add = []
    portals = PORTALS.get(map_id, [])
    if portals:
        first = out.index("\n[node ")
        out = out[:first + 1] + f'[sub_resource type="BoxShape3D" id="{PORTAL_SHAPE}"]\nsize = Vector3(4, 3, 4)\n\n' \
            + out[first + 1:]
    markers = dict(MARKERS.get(map_id, {}))
    markers.update(extra_markers or {})
    for name, pos in markers.items():
        add.append(_node(name, "Marker3D", ".", f"position = {_vec(pos)}"))
    for name, pos in NPC_POINTS.get(map_id, {}).items():
        add.append(_node(name, "Marker3D", "NpcPoints", f"position = {_vec(pos)}"))
    for p in portals:
        iid = wg.portal_id(map_id, p["name"])
        pos = p["pos"]
        body = f'''position = {_vec(pos)}
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"{iid}"
metadata/target_id = "m:{iid}"
metadata/interact_type = &"portal"
metadata/target_map = &"{p["target_map"]}"
metadata/target_spawn = &"{p["target_spawn"]}"
metadata/approach_position = Vector3({pos[0]}, 0.0, {pos[2]})
metadata/one_way = false
metadata/requires_boss_victory = false'''
        if p.get("requires_quest"):
            body += f'\nmetadata/requires_quest = &"{p["requires_quest"]}"'
        if p.get("hidden_waterfall_passage"):
            body += '\nmetadata/hidden_waterfall_passage = true\nmetadata/minimap_icon = &"none"'
        add.append(_node(p["name"], "Area3D", "Interactables", body))
        add.append(_node("Shape", "CollisionShape3D", f"Interactables/{p['name']}", f'shape = SubResource("{PORTAL_SHAPE}")'))
        add.append(_node("Name", "Label3D", f"Interactables/{p['name']}",
                         f'position = Vector3(0, 3, 0)\nbillboard = 1\nfont_size = 42\npixel_size = 0.015\ntext = "{p["label"]}"' + ("\nvisible = false" if p.get("hidden_waterfall_passage") else "")))
    lair = STORY_LAIRS.get(map_id)
    if lair and not art_pending(lair[1]):
        name, mid, pos, escort, stage = lair
        esc = "{" + ", ".join(f'"{k}": {v}' for k, v in escort.items()) + "}"
        add.append('[node name="StoryLairs" type="Node3D" parent="."]\n')
        add.append(_node(name, "Marker3D", "StoryLairs", f'''position = {_vec(pos)}
metadata/monster_id = &"{mid}"
metadata/radius_cells = 6
metadata/escort = {esc}
metadata/escort_stage = {stage}'''))
    if add:
        out = out + "\n" + "\n".join(add)
    wg.write_text(path, out)


def patch_zone(map_id: str, links: list):
    path = GAME_DIR / f"data/zones/{map_id}.tres"
    text = wg.read_text(path)
    m = re.search(r"^connected_maps = Array\[StringName\]\(\[(.*)\]\)$", text, re.M)
    if m is None:
        raise wg.WorldGenError(f"{map_id}: zone without connected_maps")
    cur = re.findall(r'&"([^"]+)"', m.group(1))
    for l in links:
        if l not in cur:
            cur.append(l)
    new = "connected_maps = Array[StringName]([" + ", ".join(f'&"{c}"' for c in cur) + "])"
    wg.write_text(path, text[:m.start()] + new + text[m.end():])


# ---------------------------------------------------------------------------------------------------- mapas novos
NEW_MAPS = ["sumidouro_abyss", "cave_reino_encoberto_5", "hollow_earth_cauldron"]


def build_new_maps():
    # Abismo do Sumidouro: margens de pedra molhada descendo em funil até o poço onde a Boiúna dorme.
    he.generate_map_scene(
        map_id="sumidouro_abyss",
        rooms=[(0, 26, 12), (0, -6, 20), (-26, -10, 11), (26, -10, 11), (0, -34, 10)],
        routes=[[(0, 26), (0, -6)], [(0, -6), (-26, -10)], [(0, -6), (26, -10)], [(0, -6), (0, -34)],
                [(-26, -10), (0, -34)], [(26, -10), (0, -34)]],
        width=5.0,
        pillars=[(-12, 4), (12, 4), (-10, -20), (10, -20), (-30, 6), (30, 6)],
        spawn_pos=(0, 0, 28),
        portals=[{"name": "ToArraial", "pos": (0, 1, 32), "target_map": "city_sumidouro",
                  "target_spawn": "AbyssReturn", "label": "Arraial do Sumidouro ⇑"}],
        spawns=[
            {"name": "Pack1", "pos": (-24, 0, -10), "mid": "abyss_black_caiman", "stage": 1, "count": 3},
            {"name": "Pack2", "pos": (24, 0, -10), "mid": "abyss_river_anaconda", "stage": 1, "count": 3},
            {"name": "Pack3", "pos": (-8, 0, 10), "mid": "abyss_water_serpent", "stage": 1, "count": 3},
            {"name": "Pack4", "pos": (10, 0, 10), "mid": "abyss_black_caiman", "stage": 2, "count": 2},
            {"name": "Pack5", "pos": (0, 0, -32), "mid": "abyss_river_anaconda", "stage": 2, "count": 2},
            {"name": "Pack6", "pos": (14, 0, -22), "mid": "abyss_water_serpent", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_jungle_floor.tres",
        env_light_color="Color(0.32, 0.40, 0.62, 1)",
        env_light_energy=0.55,
    )
    he.write_zone_def("sumidouro_abyss", "ZONE_SUMIDOURO_ABYSS_NAME", 50, 56, ["city_sumidouro"], kind=2,
                      combat=True, stage_cap=2)

    # Andar 5 da Caverna: garganta estreita que abre numa câmara de pedra quente.
    he.generate_map_scene(
        map_id="cave_reino_encoberto_5",
        rooms=[(0, 26, 10), (0, 10, 7), (0, -14, 22), (-24, -24, 9), (24, -24, 9)],
        routes=[[(0, 26), (0, 10)], [(0, 10), (0, -14)], [(0, -14), (-24, -24)], [(0, -14), (24, -24)]],
        width=4.0,
        pillars=[(-14, -6), (14, -6), (-12, -26), (12, -26)],
        spawn_pos=(0, 0, 26),
        portals=[{"name": "ToFloor4", "pos": (0, 1, 31), "target_map": "cave_reino_encoberto_4",
                  "target_spawn": "DeepPassageReturn", "label": "Subir ao covil (F4) ⇑"}],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 4), "mid": "deep_cinder_serpent", "stage": 1, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 4), "mid": "deep_ember_mule", "stage": 1, "count": 2},
            {"name": "Pack3", "pos": (-22, 0, -22), "mid": "deep_cinder_serpent", "stage": 2, "count": 2},
            {"name": "Pack4", "pos": (22, 0, -22), "mid": "deep_ember_mule", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_red_earth.tres",
        env_light_color="Color(0.85, 0.42, 0.25, 1)",
        env_light_energy=0.6,
    )
    he.write_zone_def("cave_reino_encoberto_5", "ZONE_CAVE_REINO_ENCOBERTO_5_NAME", 55, 60,
                      ["cave_reino_encoberto_4"], kind=2, combat=True, stage_cap=2)

    # Gruta do Caldeirão: galeria lateral do andar 5 da Terra Oca, longe do Titã.
    he.generate_map_scene(
        map_id="hollow_earth_cauldron",
        rooms=[(0, 22, 11), (0, -8, 19), (-22, -20, 8), (22, -20, 8)],
        routes=[[(0, 22), (0, -8)], [(0, -8), (-22, -20)], [(0, -8), (22, -20)]],
        width=4.4,
        pillars=[(-12, 2), (12, 2), (-8, -20), (8, -20)],
        spawn_pos=(0, 0, 24),
        portals=[{"name": "ToFloor5", "pos": (0, 1, 29), "target_map": "hollow_earth_5",
                  "target_spawn": "CauldronReturn", "label": "Câmara do Titã (F5) →"}],
        spawns=[
            {"name": "Pack1", "pos": (-12, 0, 12), "mid": "shadow_weaver", "stage": 2, "count": 3},
            {"name": "Pack2", "pos": (12, 0, 12), "mid": "living_crystal", "stage": 2, "count": 3},
            {"name": "Pack3", "pos": (-20, 0, -18), "mid": "shadow_weaver", "stage": 2, "count": 2},
            {"name": "Pack4", "pos": (20, 0, -18), "mid": "living_crystal", "stage": 2, "count": 2},
        ],
        ground_mat="res://assets/environment/painted/materials/mat_ground_gravel.tres",
        env_light_color="Color(0.45, 0.62, 0.40, 1)",
        env_light_energy=0.55,
    )
    he.write_zone_def("hollow_earth_cauldron", "ZONE_HOLLOW_EARTH_CAULDRON_NAME", 54, 60, ["hollow_earth_5"],
                      kind=2, combat=True, stage_cap=2)
    wg.csv_add("localization/world.csv", [
        ("ZONE_SUMIDOURO_ABYSS_NAME", "Abismo do Sumidouro"),
        ("ZONE_CAVE_REINO_ENCOBERTO_5_NAME", "Caverna do Reino Encoberto - Câmara da Fogueira (F5)"),
        ("ZONE_HOLLOW_EARTH_CAULDRON_NAME", "Túneis da Terra Oca - Gruta do Caldeirão"),
    ])


PATCHED = ["city_awakening", "fields_pindorama_crossroads", "enchanted_forest_heart", "cave_reino_encoberto_4",
           "hoer_verde_4", "split_sky_plateau_summit", "ruins_ratanaba_4", "jungle_z_river", "city_sumidouro",
           "hollow_earth_5"]

if __name__ == "__main__":
    print("=== Arco 1: monstros, mapas e covis da história ===")
    build_variants()
    build_new_maps()
    for m in PATCHED + NEW_MAPS:
        patch_scene(m)
    for m, links in ZONE_LINKS.items():
        patch_zone(m, links)
    wg.finish(PATCHED + NEW_MAPS, "story_arc1")
