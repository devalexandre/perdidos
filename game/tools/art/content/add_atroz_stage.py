#!/usr/bin/env python3
"""Acrescenta a forma atroz (MonsterStage stage = 4) e o item raro de combinacao a um data/monsters/<id>.tres
(TITULOS-E-SKILLS 3.0 item 5 e 3.3; docs/chefes-dia-noite.md). Reexecutavel: nao duplica o que ja existe.
  python3 game/tools/art/content/add_atroz_stage.py stone_armadillo ancient_shell_shard
  python3 game/tools/art/content/add_atroz_stage.py --all        (as 3 especies da Terra do Sabia)
Regras aplicadas (numeros aqui, faceis de ajustar):
  - estagio 4: nome MON_<ID>_S4_NAME, folhas _s4 (se nao existirem, usa as _s3), nivel do chefe + 6, passo 20% mais
    rapido, golpe 35% mais rapido, aggro +4 e coleira +10 celulas, XP x2,5, Estrelas x2, drops do chefe com chance
    x1,5 (max 1) e quantidade x1,5, mais o item raro (chance ATROZ_RARE_CHANCE, 1-2);
    vida/ATQ/DEF NAO vao no .tres: o servidor usa os do chefe x atroz_stat_multiplier (Balance, +100%).
  - chefe (estagio 3): ganha o item raro com chance BOSS_RARE_CHANCE.
  - variante rara: MonsterDef.rare_extra_drops ganha o item raro com chance RARE_CHANCE."""
import os, re, sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SABIA = {"stone_armadillo": "ancient_shell_shard", "enchanted_firefly": "eternal_ember",
         "prank_whirlwind": "pequi_root"}
RARE_CHANCE = 0.12
BOSS_RARE_CHANCE = 0.35
ATROZ_RARE_CHANCE = 0.85
ATROZ_LEVEL_BONUS = 6
WALK_FACTOR = 0.8
ATTACK_INTERVAL_FACTOR = 0.65
AGGRO_BONUS = 4
LEASH_BONUS = 10
XP_FACTOR = 2.5
STARS_FACTOR = 2.0
DROP_CHANCE_FACTOR = 1.5
DROP_QTY_FACTOR = 1.5


def block(text, sid):
    m = re.search(r'\[sub_resource type="Resource" id="%s"\]\n(.*?)(?=\n\[)' % re.escape(sid), text, re.S)
    return m


def fields(body):
    out = {}
    for line in body.splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            out[k.strip()] = v.strip()
    return out


def ext_id(text, script):
    m = re.search(r'\[ext_resource type="Script" path="res://scripts/shared/data/%s" id="([^"]+)"\]' % script, text)
    return m.group(1)


def drop_res(sid, drop_ext, item, chance, mn=1, mx=1):
    s = f'[sub_resource type="Resource" id="{sid}"]\nscript = ExtResource("{drop_ext}")\nitem_id = &"{item}"\n'
    if chance != 1.0:
        s += f"chance = {round(chance, 3)}\n"
    else:
        s += "chance = 1.0\n"
    if mn != 1:
        s += f"min_qty = {mn}\n"
    if mx != 1:
        s += f"max_qty = {mx}\n"
    return s + "\n"


def apply(mid, rare_item):
    path = os.path.join(GAME, "data", "monsters", f"{mid}.tres")
    text = open(path, encoding="utf-8").read()
    if "stage = 4" in text:
        print(mid, "ja tem estagio 4")
        return
    drop_ext = ext_id(text, "drop_entry.gd")
    stage_ext = ext_id(text, "monster_stage.gd")
    res = text[text.index("[resource]"):]
    stage_ids = re.findall(r'SubResource\("([^"]+)"\)', re.search(r"stages = .*", res).group(0))
    s3 = None
    for sid in stage_ids:
        if "stage = 3" in block(text, sid).group(1):
            s3 = sid
    if s3 is None:
        print(mid, "sem estagio 3 (chefe): nada a fazer")
        return
    f3 = fields(block(text, s3).group(1))
    s3_drops = re.findall(r'SubResource\("([^"]+)"\)', f3.get("drops", ""))
    new = ""
    # item raro no chefe e na variante rara
    boss_rare = f"Resource_{mid[:6]}_boss_rare"
    rare_rare = f"Resource_{mid[:6]}_rare_rare"
    new += drop_res(boss_rare, drop_ext, rare_item, BOSS_RARE_CHANCE)
    new += drop_res(rare_rare, drop_ext, rare_item, RARE_CHANCE)
    # drops da forma atroz: os do chefe melhorados + o item raro
    atroz_drops = []
    for i, did in enumerate(s3_drops):
        fd = fields(block(text, did).group(1))
        chance = min(1.0, float(fd.get("chance", "1.0")) * DROP_CHANCE_FACTOR)
        mn = int(fd.get("min_qty", "1"))
        mx = int(fd.get("max_qty", "1"))
        sid = f"Resource_{mid[:6]}_atroz_d{i}"
        new += drop_res(sid, drop_ext, fd["item_id"].strip('&"'), chance, max(1, round(mn * DROP_QTY_FACTOR)),
                        max(1, round(max(mn, mx) * DROP_QTY_FACTOR)))
        atroz_drops.append(sid)
    ar = f"Resource_{mid[:6]}_atroz_rare"
    new += drop_res(ar, drop_ext, rare_item, ATROZ_RARE_CHANCE, 1, 2)
    atroz_drops.append(ar)
    s4_sheet = f"res://assets/monsters/{mid}/mon_{mid}_s4"
    if not os.path.exists(os.path.join(GAME, s4_sheet[6:] + "_idle.png")):
        print(mid, "sem folhas _s4 ainda: usando as _s3")
        s4_sheet = f3["sprite_base"].strip('"')
    g = lambda k, d: f3.get(k, d)
    st = f'[sub_resource type="Resource" id="Resource_{mid[:6]}_atroz"]\nscript = ExtResource("{stage_ext}")\n'
    st += "stage = 4\n"
    st += f'name_key = "MON_{mid.upper()}_S4_NAME"\n'
    st += f'sprite_base = "{s4_sheet}"\n'
    if "visual_scale" in f3:
        st += f"visual_scale = {f3['visual_scale']}\n"
    st += "baked_life = true\n"
    st += f"level = {int(g('level', '1')) + ATROZ_LEVEL_BONUS}\n"
    st += f"walk_ms_per_cell = {round(int(g('walk_ms_per_cell', '400')) * WALK_FACTOR)}\n"
    st += f"attack_range_cells = {g('attack_range_cells', '1.5')}\n"
    st += f"attack_interval_ms = {round(int(g('attack_interval_ms', '1500')) * ATTACK_INTERVAL_FACTOR)}\n"
    st += "aggressive = true\n"
    st += f"aggro_range_cells = {int(g('aggro_range_cells', '6')) + AGGRO_BONUS}\n"
    st += f"leash_cells = {int(g('leash_cells', '14')) + LEASH_BONUS}\n"
    st += f"xp_reward = {round(int(g('xp_reward', '10')) * XP_FACTOR)}\n"
    st += f"stars_min = {round(int(g('stars_min', '0')) * STARS_FACTOR)}\n"
    st += f"stars_max = {round(int(g('stars_max', '0')) * STARS_FACTOR)}\n"
    st += 'drops = Array[ExtResource("%s")]([%s])\n' % (drop_ext, ", ".join(f'SubResource("{d}")' for d in atroz_drops))
    if "behaviors" in f3:
        st += f"behaviors = {f3['behaviors']}\n"
    if "dex" in f3:
        st += f"dex = {f3['dex']}\n"
    # chefe: + item raro
    b3 = block(text, s3)
    body3 = b3.group(1)
    if "drops = " in body3:
        body3 = re.sub(r"(drops = Array\[ExtResource\(\"[^\"]+\"\)\]\(\[)(.*?)(\]\))",
                       lambda m: f'{m.group(1)}{m.group(2)}, SubResource("{boss_rare}"){m.group(3)}', body3)
    else:
        body3 += f'\ndrops = Array[ExtResource("{drop_ext}")]([SubResource("{boss_rare}")])'
    text = text[:b3.start(1)] + body3 + text[b3.end(1):]
    # drops novos antes do bloco do chefe (o .tres exige definir antes de usar); o estagio 4 antes do [resource]
    i = text.index('[sub_resource type="Resource" id="%s"]' % s3)
    text = text[:i] + new + text[i:]
    i = text.index("[resource]")
    text = text[:i] + st + "\n" + text[i:]
    # stages e rare_extra_drops no [resource]
    res_start = text.index("[resource]")
    res = text[res_start:]
    res = re.sub(r"(stages = Array\[ExtResource\(\"[^\"]+\"\)\]\(\[)(.*?)(\]\))",
                 lambda m: f'{m.group(1)}{m.group(2)}, SubResource("Resource_{mid[:6]}_atroz"){m.group(3)}', res)
    if "rare_extra_drops = " in res:
        res = re.sub(r"(rare_extra_drops = Array\[ExtResource\(\"[^\"]+\"\)\]\(\[)(.*?)(\]\))",
                     lambda m: f'{m.group(1)}{m.group(2)}, SubResource("{rare_rare}"){m.group(3)}', res)
    else:
        res = res.rstrip("\n") + f'\nrare_extra_drops = Array[ExtResource("{drop_ext}")]([SubResource("{rare_rare}")])\n'
    text = text[:res_start] + res
    open(path, "w", encoding="utf-8").write(text)
    print(mid, "ok: estagio 4 + item raro", rare_item, "| folhas:", s4_sheet)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--all"]:
        for k, v in SABIA.items():
            apply(k, v)
    elif len(args) == 2:
        apply(args[0], args[1])
    else:
        print(__doc__)
        sys.exit(1)
