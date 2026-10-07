"""Gera localization/content.csv a partir de content_src.json (fonte unica de textos de conteudo).
Chaves: ITEM_<ID>_NAME/_DESC, NPC_<ID>_NAME, DLG_<NPC>_<NODE>, DLG_<NPC>_<NODE>_OPT<i>.
Rodar da raiz do projeto Godot:  python3 tools/art/content/build_content.py
Depois: build_content.gd (gera os .tres) e godot --headless --import (reimporta o CSV)."""
import csv, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
src = json.load(open(os.path.join(HERE, 'content_src.json'), encoding='utf-8'))
rows = []
for it in src['items']:
    k = it['id'].upper()
    rows += [(f'ITEM_{k}_NAME', it['name']), (f'ITEM_{k}_DESC', it['desc'])]
for n in src['npcs']:
    rows.append((f"NPC_{n['id'].upper()}_NAME", n['name']))
for npc, nodes in src['dialogues'].items():
    for nid, node in nodes.items():
        base = f'DLG_{npc.upper()}_{nid.upper()}'
        rows.append((base, node['text']))
        for i, opt in enumerate(node['options']):
            rows.append((f'{base}_OPT{i}', opt[0]))
keys = [r[0] for r in rows]
assert len(keys) == len(set(keys)), 'chave duplicada'
with open(os.path.join(ROOT, 'localization', 'content.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['keys', 'pt_BR'])
    w.writerows(rows)
print(len(rows), 'chaves em localization/content.csv')
