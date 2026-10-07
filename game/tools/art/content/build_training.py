"""Acrescenta/atualiza em localization/content.csv as chaves do Campo de Treino (training_src.json).
Nao apaga nem reordena as linhas existentes (contrato: content.csv "so acrescentar"); uma chave ja
presente tem so o valor pt_BR atualizado. Chaves:
  ITEM_<ID>_NAME/_DESC, NPC_<ID>_NAME, DLG_<NPC>_<NODE>[_OPT<i>], MON_<ID>_S<n>_NAME,
  ZONE_<MAP_ID>_NAME, REGION_<ID>_NAME, AREA_<ID>_NAME.
Rodar da raiz do projeto Godot:  python3 tools/art/content/build_training.py
Depois: build_training.gd (gera os .tres) e godot --headless --import (reimporta o CSV)."""
import csv, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
CSV = os.path.join(ROOT, 'localization', 'content.csv')
src = json.load(open(os.path.join(HERE, 'training_src.json'), encoding='utf-8'))


def rows_of(src):
    rows = []
    for rid, name in src['regions'].items():
        rows.append((f'REGION_{rid.upper()}_NAME', name))
    for aid, name in src['areas'].items():
        rows.append((f'AREA_{aid.upper()}_NAME', name))
    for z in src['zones']:
        rows.append((f"ZONE_{z['map_id'].upper()}_NAME", z['name']))
    for it in src['items']:
        k = it['id'].upper()
        rows += [(f'ITEM_{k}_NAME', it['name']), (f'ITEM_{k}_DESC', it['desc'])]
    for m in src['monsters']:
        for i, st in enumerate(m['stages']):
            rows.append((f"MON_{m['id'].upper()}_S{i + 1}_NAME", st['name']))
    for n in src['npcs']:
        rows.append((f"NPC_{n['id'].upper()}_NAME", n['name']))
    for npc, nodes in src['dialogues'].items():
        for nid, node in nodes.items():
            base = f'DLG_{npc.upper()}_{nid.upper()}'
            rows.append((base, node['text']))
            for i, opt in enumerate(node['options']):
                rows.append((f'{base}_OPT{i}', opt[0]))
    return rows


mine = rows_of(src)
keys = [r[0] for r in mine]
assert len(keys) == len(set(keys)), 'chave duplicada'
with open(CSV, encoding='utf-8', newline='') as f:
    table = list(csv.reader(f))
header, body = table[0], table[1:]
idx = {r[0]: i for i, r in enumerate(body)}
added = updated = 0
for k, v in mine:
    if k in idx:
        row = body[idx[k]]
        if row[1] != v:
            row[1] = v; updated += 1
    else:
        body.append([k, v] + [''] * (len(header) - 2)); idx[k] = len(body) - 1; added += 1
with open(CSV, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(header); w.writerows(body)
print(f'content.csv: {added} chaves novas, {updated} atualizadas ({len(mine)} do Campo de Treino)')
