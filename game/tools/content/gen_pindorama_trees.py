#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera o conteúdo da Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3) a partir de pindorama_trees_data.py.
Reexecutável: sobrescreve só o que ele mesmo gera e atualiza as linhas dele nos CSV.

  python3 game/tools/content/gen_pindorama_trees.py            # gera tudo
  python3 game/tools/content/gen_pindorama_trees.py --check    # só confere (sai 1 se algo mudaria)

Gera/atualiza:
  data/skills/<id>.tres        68 skills novas; nas 12 existentes só os campos da árvore
  data/titles/<id>.tres        9 títulos novos; nos existentes master_npc (e quest_only na Brasa)
  data/quests/lesson_<skill>.tres  uma lição por skill (escondida até cumprir título e pré-requisitos)
  data/quests/elder_*.tres     3 quests de combinação dos anciãos
  data/npcs/, data/dialogues/  Mestre Taquari e os 3 anciãos
  data/monsters/trial_twin_shield_puppet.tres  fantoche da provação do Seu Zé
  localization/progression.csv e content.csv (chaves geradas)
Depois de gerar: importar (make import) para recompilar as traduções.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import pindorama_trees_data as D  # noqa: E402

CHECK = "--check" in sys.argv
changed = []


def write(rel, text):
    path = os.path.join(GAME, rel)
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
    if old == text:
        return
    changed.append(rel)
    if not CHECK:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)


def fnum(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    r = repr(float(v))
    return r


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fnum(v)
    return '"%s"' % v


def sn_array(items):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % i for i in items)


def dict_block(typ, d, int_values=False):
    if not d:
        return "%s({})" % typ
    lines = []
    for k in sorted(d):
        v = d[k]
        lines.append('&"%s": %s' % (k, str(int(v)) if int_values else gd_value(v)))
    return "%s({\n%s\n})" % (typ, ",\n".join(lines))


def key_of(sid):
    return sid.upper()


# ------------------------------------------------------------------ localização
LOC = {"progression": {}, "content": {}}


def loc(file, key, text):
    LOC[file][key] = text


def csv_line(key, text):
    if any(c in text for c in [",", '"', "\n"]):
        text = '"%s"' % text.replace('"', '""')
    return "%s,%s" % (key, text)


## Prefixos que só este gerador escreve: chave velha com eles (texto apagado da tabela) sai do CSV.
OWNED_PREFIXES = ("DLG_MASTER_TAQUARI_", "DLG_ELDER_", "QUEST_LESSON_", "QUEST_ELDER_")


def upsert_csv(rel, rows):
    path = os.path.join(GAME, rel)
    lines = open(path, encoding="utf-8").read().split("\n")
    trailing = lines and lines[-1] == ""
    if trailing:
        lines = lines[:-1]
    seen = set()
    out = []
    for ln in lines:
        k = ln.split(",", 1)[0]
        if k not in rows and k.startswith(OWNED_PREFIXES):
            continue
        if k in rows:
            if k in seen:
                continue
            out.append(csv_line(k, rows[k]))
            seen.add(k)
        else:
            out.append(ln)
    for k in rows:
        if k not in seen:
            out.append(csv_line(k, rows[k]))
    write(rel, "\n".join(out) + "\n")


# ------------------------------------------------------------------ skills
SKILL_HEADER = '''[gd_resource type="Resource" script_class="SkillDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/skill_def.gd" id="1_skill"]

[resource]
script = ExtResource("1_skill")
'''


def skill_tres(s):
    L = ['id = &"%s"' % s["id"], 'name_key = "SKILL_%s_NAME"' % key_of(s["id"]),
         'desc_key = "SKILL_%s_DESC"' % key_of(s["id"]), 'school = &"%s"' % s["school"],
         'region_id = &"brasil"']
    if s["target_type"] != 0:
        L.append("target_type = %d" % s["target_type"])
    if s["effect"] != 0:
        L.append("effect = %d" % s["effect"])
    L += ["mana_cost = %d" % s["mana"], "cooldown_sec = %s" % fnum(float(s["cd"]))]
    if s["cast"]:
        L.append("cast_time_sec = %s" % fnum(float(s["cast"])))
    L.append("range_cells = %s" % fnum(float(s["range"])))
    for k, f in (("radius", "radius_cells"), ("cone", "cone_deg"), ("line_len", "line_length_cells"),
                 ("line_w", "line_width_cells")):
        if s[k]:
            L.append("%s = %s" % (f, fnum(float(s[k]))))
    L.append("base_multiplier = %s" % fnum(float(s["mult"])))
    L.append("multiplier_per_level = %s" % fnum(float(s["per"])))
    if s["dur"]:
        L.append("duration_sec = %s" % fnum(float(s["dur"])))
    if s["extra"]:
        L.append("extra = " + dict_block("Dictionary[StringName, Variant]", s["extra"]))
    if s["melee"]:
        L.append("requires_melee_weapon = true")
    if s["bow"]:
        L.append("requires_bow = true")
    L.append('vfx = &"%s"' % s["vfx"])
    if s["learn"]:
        L.append('exclusive_to_title = &"%s"' % s["learn"])
    L.append('icon_text = "%s"' % s["icon"])
    L.append('tree_title = &"%s"' % s["tree"])
    L.append("tree_order = %d" % s["order"])
    if s["prereq"]:
        L.append("required_skill_levels = " + dict_block("Dictionary[StringName, int]", s["prereq"], True))
    return SKILL_HEADER + "\n".join(L) + "\n"


def set_resource_fields(text, fields):
    """Troca/insere campos 'chave = valor' na seção [resource] (o valor pode ter várias linhas)."""
    head, sep, body = text.partition("[resource]\n")
    assert sep, "sem [resource]"
    entries = []  # (key, raw)
    cur = None
    for ln in body.rstrip("\n").split("\n"):
        m = re.match(r"^([a-z_]+) = ", ln)
        if m:
            cur = [m.group(1), ln]
            entries.append(cur)
        elif cur is not None:
            cur[1] += "\n" + ln
    keys = [e[0] for e in entries]
    for k, raw in fields.items():
        if raw is None:
            entries = [e for e in entries if e[0] != k]
            keys = [e[0] for e in entries]
            continue
        line = "%s = %s" % (k, raw)
        if k in keys:
            entries[keys.index(k)][1] = line
        else:
            entries.append([k, line])
            keys.append(k)
    return head + sep + "\n".join(e[1] for e in entries) + "\n"


def gen_skills():
    for s in D.NEW_SKILLS:
        write("data/skills/%s.tres" % s["id"], skill_tres(s))
        loc("progression", "SKILL_%s_NAME" % key_of(s["id"]), s["name"])
        loc("progression", "SKILL_%s_DESC" % key_of(s["id"]), s["desc"])
    for sid, (tree, order, learn, prereq) in D.EXISTING_SKILLS.items():
        rel = "data/skills/%s.tres" % sid
        text = open(os.path.join(GAME, rel), encoding="utf-8").read()
        fields = {"tree_title": '&"%s"' % tree, "tree_order": str(order),
                  "exclusive_to_title": ('&"%s"' % learn) if learn else None,
                  "required_skill_levels": dict_block("Dictionary[StringName, int]", prereq, True) if prereq else None}
        write(rel, set_resource_fields(text, fields))


# ------------------------------------------------------------------ títulos
TITLE_HEADER = '''[gd_resource type="Resource" script_class="TitleDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/title_def.gd" id="1_title"]

[resource]
script = ExtResource("1_title")
'''


def color(c):
    return "Color(%s, %s, %s, 1)" % tuple(fnum(float(x)) for x in c)


def gen_titles():
    for tid, t in D.NEW_TITLES.items():
        (name, desc, arch, tier, parent, branch, req_s, req_t, quest_only, master, col, sort, outfit, cloth) = t
        L = ['id = &"%s"' % tid, 'name_key = "TITLE_%s_NAME"' % key_of(tid), 'archetype = &"%s"' % arch,
             "tier = %d" % tier]
        if parent:
            L.append('parent_title = &"%s"' % parent)
        if branch:
            L.append('branch = &"%s"' % branch)
        if req_s:
            L.append("required_skills = " + sn_array(req_s))
        if req_t:
            L.append("required_titles = " + sn_array(req_t))
        L.append("color = " + color(col))
        L.append('desc_key = "TITLE_%s_DESC"' % key_of(tid))
        L.append("sort_order = %d" % sort)
        L.append('outfit_id = &"%s"' % outfit)
        L.append("cloth_colors = PackedColorArray(%s)" % ", ".join(
            "%s, %s, %s, 1" % tuple(fnum(float(x)) for x in c) for c in cloth))
        if quest_only:
            L.append("quest_only = true")
        L.append('master_npc = &"%s"' % master)
        write("data/titles/%s.tres" % tid, TITLE_HEADER + "\n".join(L) + "\n")
        loc("progression", "TITLE_%s_NAME" % key_of(tid), name)
        loc("progression", "TITLE_%s_DESC" % key_of(tid), desc)
    for tid, f in D.EXISTING_TITLES.items():
        rel = "data/titles/%s.tres" % tid
        text = open(os.path.join(GAME, rel), encoding="utf-8").read()
        fields = {"master_npc": '&"%s"' % f["master_npc"]}
        if f.get("quest_only"):
            fields["quest_only"] = "true"
        write(rel, set_resource_fields(text, fields))


# ------------------------------------------------------------------ quests
QUEST_HEADER = '''[gd_resource type="Resource" script_class="QuestDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/quest_def.gd" id="1_quest"]
[ext_resource type="Script" path="res://scripts/shared/data/quest_step.gd" id="2_step"]

'''
STEP_TYPES = {"KILL": 0, "COLLECT": 1, "EXPLORE": 2, "TALK": 3, "TRIAL": 4}


def quest_tres(qid, key, giver, steps, reward_skill, reward_title, xp, req_titles, req_levels):
    subs = []
    refs = []
    for i, st in enumerate(steps):
        rid = "step_%d" % (i + 1)
        L = ['[sub_resource type="Resource" id="%s"]' % rid, 'script = ExtResource("2_step")']
        if STEP_TYPES[st["type"]]:
            L.append("type = %d" % STEP_TYPES[st["type"]])
        if st["type"] == "TRIAL" and qid.startswith("elder_"):
            L.append('trial_map_id = &"elder_trial_arena"')
        L.append('target_id = &"%s"' % st["target"])
        if st.get("count", 1) != 1:
            L.append("count = %d" % st["count"])
        L.append('text_key = "QUEST_%s_STEP%d"' % (key, i + 1))
        if st.get("time"):
            L.append("time_limit_sec = %s" % fnum(float(st["time"])))
        if st.get("variant", "any") != "any":
            L.append('variant = &"%s"' % st["variant"])
        if st.get("distinct"):
            L.append("distinct_species = true")
        if st.get("no_death"):
            L.append("no_death = true")
        if st.get("mode", "kill") != "kill":
            L.append('trial_mode = &"%s"' % st["mode"])
            if st.get("protect"):
                L.append('protect_target = &"%s"' % st["protect"])
                L.append("protect_count = %d" % st.get("protect_count", 3))
                L.append("protect_min_alive = %d" % st.get("protect_min", 1))
            L.append("trial_spawn_count = %d" % st.get("spawn", 1))
            if st.get("wave"):
                L.append("trial_wave_sec = %s" % fnum(float(st["wave"])))
        subs.append("\n".join(L))
        refs.append('SubResource("%s")' % rid)
    R = ["[resource]", 'script = ExtResource("1_quest")', 'id = &"%s"' % qid,
         'name_key = "QUEST_%s_NAME"' % key, 'giver_npc = &"%s"' % giver, 'region_id = &"brasil"',
         'steps = Array[ExtResource("2_step")]([%s])' % ", ".join(refs)]
    if req_titles:
        R.append("required_titles = " + sn_array(req_titles))
    if reward_skill:
        R.append('reward_skill = &"%s"' % reward_skill)
    R.append("reward_xp = %d" % xp)
    if reward_title:
        R.append('reward_title = &"%s"' % reward_title)
    for f, suffix in (("offer_text_key", "OFFER"), ("progress_text_key", "PROGRESS"),
                      ("complete_text_key", "COMPLETE"), ("option_text_key", "OPTION"), ("desc_key", "DESC")):
        R.append('%s = "QUEST_%s_%s"' % (f, key, suffix))
    if req_levels:
        R.append("required_skill_levels = " + dict_block("Dictionary[StringName, int]", req_levels, True))
    return QUEST_HEADER + "\n\n".join(subs) + "\n\n" + "\n".join(R) + "\n"


def all_skills():
    """[(id, nome, escola, árvore, ordem, título para aprender, pré-requisitos)] das 80 skills."""
    out = []
    for s in D.NEW_SKILLS:
        out.append((s["id"], s["name"], s["school"], s["tree"], s["order"], s["learn"], s["prereq"]))
    existing_names = {}
    for ln in open(os.path.join(GAME, "localization/progression.csv"), encoding="utf-8"):
        k, _, v = ln.rstrip("\n").partition(",")
        existing_names[k] = v.strip('"')
    for sid, (tree, order, learn, prereq) in D.EXISTING_SKILLS.items():
        school = "blade" if sid.startswith("blade") else "arcane"
        out.append((sid, existing_names.get("SKILL_%s_NAME" % key_of(sid), sid), school, tree, order, learn, prereq))
    return out


def gen_lessons():
    for sid, name, school, tree, order, learn, prereq in all_skills():
        if sid in D.TAUGHT_ELSEWHERE:
            continue
        master = D.TREE_MASTER[tree]
        tier = D.NEW_TITLES[tree][3] if tree in D.NEW_TITLES else (2 if tree in (
            "pindorama_blade_aroeira", "pindorama_blade_jaguar", "pindorama_arcane_crystal", "pindorama_arcane_boitata") else 1)
        prey, item = D.SCHOOL_PREY[school]
        n = (6 if order <= 2 else (8 if order == 3 else 10)) + (2 if tier >= 2 else 0)
        steps = [dict(type="KILL", target=prey, count=n)]
        collect = ""
        if order >= 4:
            steps.append(dict(type="COLLECT", target=item, count=3))
            collect = " e traga 3 %s" % D.ITEM_PLURAL[item]
        qid = "lesson_%s" % sid
        key = "LESSON_%s" % key_of(sid)
        # City initiation grants the base title as well: subsequent lessons require it.
        initiation = sid in ("blade_firm_strike", "arcane_spark", "bow_low_shot")
        text = quest_tres(qid, key, master, steps, sid, tree if initiation else "", 60 + 20 * order, [], {})
        write("data/quests/%s.tres" % qid, text)
        offer, progress, complete = D.MASTER_VOICE[master]
        loc("progression", "QUEST_%s_NAME" % key, "Lição: %s" % name)
        loc("progression", "QUEST_%s_DESC" % key, "%s ensina %s a quem provar que está pronto." % (
            D.MASTER_NAMES[master], name))
        loc("progression", "QUEST_%s_OPTION" % key, "[Lição] Quero aprender %s." % name)
        loc("progression", "QUEST_%s_OFFER" % key, offer.format(skill=name, n=n, mon=D.PREY_PLURAL[prey],
                                                               collect=collect))
        loc("progression", "QUEST_%s_PROGRESS" % key, progress.format(skill=name))
        loc("progression", "QUEST_%s_COMPLETE" % key, complete.format(skill=name) + (" Você conquistou um novo caminho de Pindorama; agora pode continuar as lições comigo." if initiation else ""))
        loc("progression", "QUEST_%s_STEP1" % key, "Derrote %s" % D.PREY_PLURAL[prey])
        if order >= 4:
            loc("progression", "QUEST_%s_STEP2" % key, "Colete %s" % D.ITEM_PLURAL[item])


def gen_elder_quests():
    for q in D.ELDER_QUESTS:
        key = key_of(q["id"])
        write("data/quests/%s.tres" % q["id"], quest_tres(q["id"], key, q["giver"], q["steps"], q["reward_skill"],
                                                          q["reward_title"], q["xp"], q["titles"], {}))
        loc("progression", "QUEST_%s_NAME" % key, q["name"])
        loc("progression", "QUEST_%s_DESC" % key, q["desc"])
        loc("progression", "QUEST_%s_OPTION" % key, q["option"])
        loc("progression", "QUEST_%s_OFFER" % key, q["offer"])
        loc("progression", "QUEST_%s_PROGRESS" % key, q["progress"])
        loc("progression", "QUEST_%s_COMPLETE" % key, q["complete"])
        for i, st in enumerate(q["steps"]):
            loc("progression", "QUEST_%s_STEP%d" % (key, i + 1), st["text"])


# ------------------------------------------------------------------ NPCs e diálogos
def gen_npcs():
    for nid, n in D.NPCS.items():
        up = key_of(nid)
        # Diálogo: start + nós; as opções de quest entram sozinhas no start (QuestService).
        subs = []
        node_refs = []
        sub_i = [0]

        def opt(text_key, nxt, extra=None):
            extra = extra or {}
            sub_i[0] += 1
            rid = "opt_%d" % sub_i[0]
            L = ['[sub_resource type="Resource" id="%s"]' % rid, 'script = ExtResource("1_opt")',
                 'text_key = "%s"' % text_key]
            if nxt:
                L.append('next_node = &"%s"' % nxt)
            if extra.get("action"):
                L.append('action = &"%s"' % extra["action"])
            elif not nxt:
                L.append('action = &"close"')
            if extra.get("cond"):
                L.append("conditions = " + dict_block("Dictionary[StringName, Variant]", extra["cond"]))
            if extra.get("args"):
                L.append("action_args = " + dict_block("Dictionary[StringName, Variant]", extra["args"]))
            subs.append("\n".join(L))
            return 'SubResource("%s")' % rid

        def node(node_id, text_key, opts):
            refs = [opt("%s_OPT%d" % (text_key, i), o[1], o[2] if len(o) > 2 else None) for i, o in enumerate(opts)]
            rid = "node_%s" % node_id
            subs.append("\n".join(['[sub_resource type="Resource" id="%s"]' % rid, 'script = ExtResource("2_node")',
                                   'id = &"%s"' % node_id, 'text_key = "%s"' % text_key,
                                   'options = Array[ExtResource("1_opt")]([%s])' % ", ".join(refs)]))
            node_refs.append('SubResource("%s")' % rid)
            loc("content", text_key, "")
            for i, o in enumerate(opts):
                loc("content", "%s_OPT%d" % (text_key, i), o[0])

        start_key = "DLG_%s_START" % up
        node("start", start_key, n["opts"])
        loc("content", start_key, n["start"])
        for node_id, (text, opts) in n["nodes"].items():
            k = "DLG_%s_%s" % (up, node_id.upper())
            node(node_id, k, opts)
            loc("content", k, text)
        dlg = ('[gd_resource type="Resource" script_class="DialogueDef" format=3]\n\n'
               '[ext_resource type="Script" path="res://scripts/shared/data/dialogue_option.gd" id="1_opt"]\n'
               '[ext_resource type="Script" path="res://scripts/shared/data/dialogue_node.gd" id="2_node"]\n'
               '[ext_resource type="Script" path="res://scripts/shared/data/dialogue_def.gd" id="3_dlg"]\n\n'
               + "\n\n".join(subs) + "\n\n[resource]\nscript = ExtResource(\"3_dlg\")\n"
               + 'id = &"%s"\nnodes = Array[ExtResource("2_node")]([%s])\n' % (nid, ", ".join(node_refs)))
        write("data/dialogues/%s.tres" % nid, dlg)
        npc = ('[gd_resource type="Resource" script_class="NpcDef" format=3]\n\n'
               '[ext_resource type="Resource" path="res://data/dialogues/%s.tres" id="1_dlg"]\n'
               '[ext_resource type="Script" path="res://scripts/shared/data/npc_def.gd" id="2_npc"]\n\n'
               '[resource]\nscript = ExtResource("2_npc")\nid = &"%s"\nname_key = "NPC_%s_NAME"\n'
               'sprite_base = "res://assets/npcs/npc_%s"\nmap_id = &"city_awakening"\nspawn_marker = &"%s"\n'
               'move_speed = %s\ndialogue = ExtResource("1_dlg")\nfallback_sprite_base = "%s"\n') % (
            nid, nid, up, nid, nid, fnum(n["speed"]), n["fallback"])
        write("data/npcs/%s.tres" % nid, npc)
        loc("content", "NPC_%s_NAME" % up, n["name"])


# ------------------------------------------------------------------ fantoche da provação do Seu Zé
PUPPET = '''[gd_resource type="Resource" script_class="MonsterDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="1_mdef"]
[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="2_mstage"]

[sub_resource type="Resource" id="stage_1"]
script = ExtResource("2_mstage")
name_key = "MON_TRIAL_TWIN_SHIELD_PUPPET_NAME"
sprite_base = "res://assets/monsters/stone_armadillo/mon_stone_armadillo_s2"
baked_life = true
level = 15
max_hp = 1800
atk = 18
def = 45
mdef = 45
walk_ms_per_cell = 100000000
attack_interval_ms = 2000
aggro_range_cells = 0
leash_cells = 1
xp_reward = 0

[resource]
script = ExtResource("1_mdef")
id = &"trial_twin_shield_puppet"
stages = Array[ExtResource("2_mstage")]([SubResource("stage_1")])
respawn_sec = 0.0
can_be_rare = false
'''


# ------------------------------------------------------------------ muda de pequizeiro (provação da Vó Aninha)
SEEDLING = '''[gd_resource type="Resource" script_class="MonsterDef" format=3]

[ext_resource type="Script" path="res://scripts/shared/data/monster_def.gd" id="1_mdef"]
[ext_resource type="Script" path="res://scripts/shared/data/monster_stage.gd" id="2_mstage"]

[sub_resource type="Resource" id="stage_1"]
script = ExtResource("2_mstage")
name_key = "MON_PEQUI_SEEDLING_NAME"
sprite_base = "res://assets/quest_props/pequi_seedling/prop_pequi_seedling"
baked_life = true
level = 5
max_hp = 220
atk = 0
def = 6
mdef = 6
walk_ms_per_cell = 100000000
attack_interval_ms = 100000
aggro_range_cells = 0
leash_cells = 1
xp_reward = 0

[resource]
script = ExtResource("1_mdef")
id = &"pequi_seedling"
stages = Array[ExtResource("2_mstage")]([SubResource("stage_1")])
respawn_sec = 0.0
can_be_rare = false
'''


def main():
    gen_skills()
    gen_titles()
    gen_lessons()
    gen_elder_quests()
    gen_npcs()
    write("data/monsters/trial_twin_shield_puppet.tres", PUPPET)
    loc("content", "MON_TRIAL_TWIN_SHIELD_PUPPET_NAME", "Fantoche de Dois Escudos")
    write("data/monsters/pequi_seedling.tres", SEEDLING)
    loc("content", "MON_PEQUI_SEEDLING_NAME", "Muda de Pequizeiro")
    for f, rows in D.STATIC_LOC.items():
        for k, v in rows.items():
            loc(f, k, v)
    upsert_csv("localization/progression.csv", LOC["progression"])
    upsert_csv("localization/content.csv", LOC["content"])
    print("%s: %d arquivo(s)%s" % ("mudariam" if CHECK else "gerados/atualizados", len(changed),
                                   "" if not changed else "\n  " + "\n  ".join(changed[:12])
                                   + ("\n  ..." if len(changed) > 12 else "")))
    return 1 if CHECK and changed else 0


if __name__ == "__main__":
    sys.exit(main())
