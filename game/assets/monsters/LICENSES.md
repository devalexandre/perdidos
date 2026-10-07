# Origem e licença das folhas de monstros

Regra do dono (28/09/2026): "o que der para pegar pronto, pega e modifica". Todo modelo de terceiros usado como
base precisa ser **CC0** (conferido na página oficial do pack), ser **reformado e repintado com a paleta mestra**
e passar pelo pipeline de pixel art (`game/tools/art/blender/monsters/`, ver `docs/arte-monstros-blender.md`).
Nunca publicar a silhueta do pack sem mudança, nem nada que lembre monstro de outro jogo (GDD §17.0.2).
Downloads ficam em `.work/b3/packs/<pack>/` (fora do jogo); aqui fica só o registro.

## Monstros com modelo próprio (Blender, feitos do zero por script — sem pack)

| Monstro (estágios) | Fonte | Autor | Licença |
|---|---|---|---|
| Lobisomem Jovem / Lobisomem da Mata / A Fera da Mata / A Fera da Mata Atroz (`werewolf`) | `game/tools/art/blender/monsters/werewolf.py` | Projeto (2026-10-02) | do projeto |
| Tatu-Pedra / Tatu-Rochedo / Tatu-Montanha (`stone_armadillo`) | `game/tools/art/blender/monsters/stone_armadillo.py` | Projeto (Agente B3, 28/09/2026) | do projeto |
| Redemoinho Arteiro / Rodamoinho Traquinas / Ventania do Gorro Vermelho (`prank_whirlwind`) | `.../prank_whirlwind.py` | Projeto (Agente B3) | do projeto |
| Vaga-lume Encantado / Vaga-lume Candeeiro / Rainha-Lume do Brejo (`enchanted_firefly`) | `.../enchanted_firefly.py` | Projeto (Agente B3) | do projeto |

| Tatu-Montanha Atroz (`stone_armadillo`, estágio 4 — forma atroz, noite) | `.../stone_armadillo.py` (`build(4)`, `_atroz_*`) | Projeto (agente de arte, 30/09/2026) | do projeto |
| Ventania Atroz (`prank_whirlwind`, estágio 4 — forma atroz, noite) | `.../prank_whirlwind.py` (`build(4)`, `_atroz_*`) | Projeto (agente de arte, 30/09/2026) | do projeto |
| Rainha-Lume Atroz (`enchanted_firefly`, estágio 4 — forma atroz, noite) | `.../enchanted_firefly.py` (`build(4)`, `_atroz_*`) | Projeto (agente de arte, 30/09/2026) | do projeto |

As formas atrozes são o modelo do chefe (s3) com peças novas feitas por script (nenhuma peça de pack) e as rampas
noturnas de `post.py`. Ícones dos drops noturnos (`assets/items/icons/icon_item_eternal_ember.png`,
`icon_item_pequi_root.png`, `icon_item_ancient_shell_shard.png`): desenhados por código
(`game/tools/art/icons/draw_icons.py`), do projeto.

Folhas antigas desses três (geradas por IA, Agente W) guardadas em `.work/b3/backup/`.

## Monstros das outras nacoes (Campo de Treino) — feitos a partir de packs CC0 (28/09/2026, Agente B3)

Cada um: esqueleto/corpo/animacoes do pack + reforma e pecas nossas (cabeca de filhote no padrao do projeto,
corpo, acessorios), repintura so com a paleta mestra e o pos-processamento de pixel art. Fontes em
`game/tools/art/blender/monsters/<id>.py`.

| Monstro | Base do pack | O que e nosso |
|---|---|---|
| `spirit_fox_cub` | Ultimate Animated Animals — Fox.gltf (patas, rabo, animacoes) | cabeca, corpo, caudas extras com chamas azuis, cores |
| `jaguar_cub` | Ultimate Animated Animals — ShibaInu.gltf | cabeca, corpo, rosetas, rabo, cores |
| `trickster_tanuki` | Ultimate Animated Animals — ShibaInu.gltf | cabeca com mascara e folha, corpo barrigudo, rabo listrado |
| `lake_kelpie` | Ultimate Animated Animals — Horse.gltf | cabeca de potro, corpo de agua, crina de algas, gotas |
| `puca_trickster` | Ultimate Animated Animals — Alpaca.gltf | cabeca de bode com chifres curvos, corpo e tufos, cores |
| `little_chimera` | Ultimate Animated Animals — ShibaInu.gltf | cabeca com juba, cabecinha de cabra, rabo de cobra |
| `sphinx_cub` | Ultimate Animated Animals — Fox.gltf | cabeca com lenco listrado, asas dobradas, rabo |
| `griffin_chick` | Ultimate Animated Animals — ShibaInu.gltf | cabeca de aguia com bico e topete, asinhas, rabo |
| `obsidian_iguana` | Ultimate Animated Animals — Fox.gltf | cabeca de lagarto, corpo, espinhos turquesa, rabo |
| `dune_scorpion` | Cute Animated Monsters — Crab.gltf | cauda com ferrao, repintura areia/vermelho |
| `lindworm_hatchling` | Ultimate Monsters — Flying/Dragon.gltf (sem asas) | espinhos de gelo, repintura |
| `zmey_hatchling` | Ultimate Monsters — Flying/Dragon_Evolved.gltf | cabecas extras, asas menores, repintura |
| `moss_troll` | Ultimate Monsters — Big/Yeti.gltf | nariz, musgo, cogumelos, repintura de pedra |
| `trasgo_imp` | Ultimate Monsters — Big/Monkroose.gltf | barrete vermelho, remendo, repintura |
| `hopping_jiangshi` | Ultimate Monsters — Big/Yeti.gltf | chapeu, faixa lisa de pano, mangas, bracos esticados, pulos |
| `kasa_obake`, `walking_hut`, `fountain_serpent` | — (nenhum pack serve) | modelo proprio por script |

Folhas antigas dessas especies (IA, Agente W) guardadas em `.work/b3/backup/`.

## Demais monstros

Nenhum: todas as 21 especies do Campo de Treino agora saem do pipeline do Blender.

## Packs CC0 usados (downloads em `.work/b3/packs/`, zips em `game/downloads/`)

| Pack | Pagina oficial | Licenca |
|---|---|---|
| Quaternius — Ultimate Monsters | https://quaternius.com/packs/ultimatemonsters.html | CC0 1.0 (License.txt dentro do pack) |
| Quaternius — Cute Animated Monsters | https://quaternius.com/packs/cutemonsters.html | CC0 (pagina oficial; o zip nao traz arquivo de licenca) |
| Quaternius — Ultimate Animated Animals | https://quaternius.com/packs/ultimateanimatedanimals.html | CC0 (pagina oficial) |


## Expansão regional preparada — 30 espécies / 90 modelos (30/09/2026)

Modelos procedurais novos, criados para este projeto com `mon_rig`, sem novas malhas ou texturas de terceiros. Normal, Boss e Atroz em `tools/art/blender/monsters/blend/`; catálogo e procedência cultural em `tools/art/blender/monsters/reserve/catalog.json`. Os arquivos estão junto dos modelos nativos, mas não foram instalados sprites nem ativados spawns. Ver `docs/novos-monstros-regionais.md` na raiz do repositório.

## Fauna peçonhenta redesenhada no Blender (07/10/2026)

Antes: recolor (tint por `tools/world/build_venom_monsters.py`) da iguana de obsidiana (aranhas) e do tatu-pedra (taturana).
Agora: modelos próprios por script no pipeline do Blender, 4 estágios (s1 quadro 96; s2 quadro 144; chefe s3 e atroz s4
quadro 240, cada um com modelo e silhueta próprios). Os packs CC0 extraídos (`.work/b3/packs/`) não têm aranha nem lagarta; as primitivas
(`mon_rig`) e o desenho dos olhos/sobrancelha/bochecha vêm do `stone_armadillo.py` (projeto). Sem malha ou textura de terceiros.

| Espécie | Fonte | Autor | Licença |
|---|---|---|---|
| Aranha-Armadeira (`wandering_spider`, s1–s4) | `game/tools/art/blender/monsters/wandering_spider.py` + `venom_common.py` + `wandering_spider_mats.json` | Projeto (agente de arte, 07/10/2026) | do projeto |
| Aranha-Marrom (`brown_recluse`, s1–s4) | `.../brown_recluse.py` + `venom_common.py` + `brown_recluse_mats.json` | Projeto (agente de arte, 07/10/2026) | do projeto |
| Taturana Lonomia (`lonomia_caterpillar`, s1–s4) | `.../lonomia_caterpillar.py` + `venom_common.py` + `lonomia_caterpillar_mats.json` | Projeto (agente de arte, 07/10/2026) | do projeto |
