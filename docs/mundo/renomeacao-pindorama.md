# Renomeação da nação: Sabiá → Pindorama (08/10/2026)

Decisão do dono: o nome da nação brasileira "Sabiá" sai do jogo inteiro e vira **Pindorama**.
A troca vale para textos, ids internos, nomes de arquivo, site, launcher e docs, **com migração** de saves e
do estado do painel, porque o servidor público tem jogadores reais.

> Este arquivo guarda os nomes antigos de propósito, porque é o registro da troca. Ele fica fora do grep de controle.

## 1. Regras de texto

| Antes | Depois |
|---|---|
| Terra do Sabiá | Terra de Pindorama |
| Campos do Sabiá | Campos de Pindorama |
| "do Sabiá" (qualquer: caminho, Lâmina Longa, Mestre da Terra…) | "de Pindorama" |
| "no Sabiá" ("Aqui no Sabiá…") | "em Pindorama" |
| Nação Sabiá / (Sabiá) / Sabiá sozinho | Nação Pindorama / (Pindorama) / Pindorama |
| A TERRA DO SABIÁ (selo do launcher) | A TERRA DE PINDORAMA |
| en: the Land of the Sabiá | the Land of Pindorama |
| es: la Tierra del Sabiá | la Tierra de Pindorama |
| fr: au Pays du Sabiá | au Pays de Pindorama |
| de: im Land des Sabiá | im Land von Pindorama |
| ja: サビアの地 | ピンドラマの地 |

"Pindorama" é nome próprio e não se traduz.

## 2. Tabela de/para dos ids

Fonte única no código: `game/scripts/shared/legacy_ids.gd` (`LegacyIds.RENAMED`). O painel em Go replica o que lê
em `launcher/server/legacy_ids.go`.

| Tipo | Antes | Depois |
|---|---|---|
| Nação/região (`region_id`, `nationality`) | `sabia` | `pindorama` |
| Mapas/zonas | `fields_sabia` | `fields_pindorama` |
| | `fields_sabia_buriti` | `fields_pindorama_buriti` |
| | `fields_sabia_crossroads` | `fields_pindorama_crossroads` |
| Títulos (16) | `sabia_blade_machete`, `sabia_blade_aroeira`, `sabia_blade_jaguar` | `pindorama_blade_*` |
| | `sabia_arcane_firefly`, `sabia_arcane_crystal`, `sabia_arcane_boitata` | `pindorama_arcane_*` |
| | `sabia_bow_cerrado`, `sabia_bow_brejo`, `sabia_bow_gaviao` | `pindorama_bow_*` |
| | `sabia_support_root`, `sabia_support_buriti`, `sabia_support_matinta` | `pindorama_support_*` |
| | `sabia_tank_jabuti`, `sabia_tank_anta`, `sabia_tank_mapinguari` | `pindorama_tank_*` |
| | `sabia_hybrid_ember` | `pindorama_hybrid_ember` |
| Quests de título (10) | `sabia_<árvore>_<ramo>_title` (aroeira, jaguar, crystal, boitata, brejo, gaviao, buriti, matinta, anta, mapinguari) | `pindorama_<árvore>_<ramo>_title` |
| Companheiros | `sabia_companion_guara`, `sabia_companion_harpy`, `sabia_companion_lume` | `pindorama_companion_*` |
| Montaria | `sabia_mount_donkey` | `pindorama_mount_donkey` |
| Item | `sabia_long_blade` | `pindorama_long_blade` |
| Monstro | `sabia_jaguar` | `pindorama_jaguar` |
| Grupos de spawn (nós dos mapas) | `sabia_firefly_1/2/med`, `sabia_whirlwind_1/2/med`, `sabia_armadillo_1/2/med` | `pindorama_*` |
| Cosmético de evento (painel) | `cosmetic_broche_sabia` | `cosmetic_broche_pindorama` |
| Perfil de clima do Campo (`weather_regions.gd`) | `"sabia"` | `"pindorama"` |
| Ponto do `real_tour.gd` | `sabia` | `pindorama` |
| Recurso interno do atlas (`ext_resource id`) | `r_sabia` | `r_pindorama` |
| Material | `mat_ground_sabia_forest`, `mat_ground_fields_sabia*` | `mat_ground_pindorama_forest`, `mat_ground_fields_pindorama*` |
| Ids citados só nos docs de pets (ainda não existem em dados) | `sabia_companion_thrush/owl/jaguar/ember`, `sabia_mount_tapir` | `pindorama_*` |

Chaves de tradução: toda família `*_SABIA_*` virou `*_PINDORAMA_*`: `TITLE_PINDORAMA_*` (16 × NAME/DESC),
`QUEST_PINDORAMA_*` (10 × NAME/DESC/OFFER/OPTION/PROGRESS/COMPLETE/STEP_*),
`MON_PINDORAMA_JAGUAR_S1/S2_NAME`, `ITEM_PINDORAMA_LONG_BLADE_NAME/DESC`, `WA_R_PINDORAMA(_HOOK)`,
`WA_P_CAMPOS_PINDORAMA(_HOOK)`, `RULES_TT_BLADE/ARCANE_PINDORAMA_STYLE`. A lista de exceções culturais
(`game/data/cultural/sensitive_exceptions.txt`) não citava nenhuma dessas chaves.

## 3. Arquivos renomeados (196)

| Área | Qtde | Exemplos |
|---|---|---|
| `game/data` (titles 16, quests 10, zones 3, companions 3, items, monsters, mounts, world/regions) | 36 | `data/world/regions/pindorama.tres`, `data/titles/pindorama_bow_gaviao.tres` |
| `game/scenes/maps` | 3 | `fields_pindorama.tscn`, `fields_pindorama_buriti.tscn`, `fields_pindorama_crossroads.tscn` |
| `game/assets` (splats do terreno + `.import`, materiais, minimapa + `.import`, pasta da montaria, fonte do atlas) | 30 | `assets/minimap/fields_pindorama.svg(.import)`, `assets/mounts/pindorama_mount_donkey/` |
| `game/tests/progression` (com `.uid`) | 6 | `test_pindorama_trees.tscn/.gd/.gd.uid`, `pindorama_capture.gd(.uid)`, `run_pindorama_capture.sh` |
| `game/tools` | 8 | `world/build_pindorama_monsters.py`, `world/export_pindorama_monsters.sh`, `content/gen_pindorama_trees.py`, `content/pindorama_trees_data.py`, `art/fx/fxpindorama.py`, `art/blender/monsters/pindorama_donkey.py`, `blend/pindorama_donkey_s1.blend`, `reserve/pindorama.jpg` |
| `site/img` | 101 | `titles/pindorama_*_{m,f}.{png,gif}` (96), `chars/pindorama_{m,f}_{s,se}.png` (4), `shots/campos_pindorama.webp` |
| `docs` | 11 | `ARCO-1-TERRA-DE-PINDORAMA.md`, `docs/debug-pindorama.md`, `docs/kit-chatgpt-student-pindorama.md`, `docs/guias/student_pindorama/`, `docs/arte-cenario/*/tf_pindorama_*.jpg`, `*/03_pindorama.jpg`, `mapas/campo_pindorama_*.jpg` |

Os `.import` foram renomeados junto (o `uid` dentro deles ficou igual, então as referências por uid seguem
valendo); o `godot --import` regerou o cache com o caminho novo. Os `.pyc` antigos em `__pycache__` foram
apagados. As cenas dos Campos **não** foram regeradas: só renomeadas e com os ids trocados por dentro (nós postos à
mão, como GuaraTrack, `bond_monsters_0` e o covil do Saci, continuam lá).

## 4. Contagem do que foi trocado (conteúdo)

2011 substituições em 460 arquivos de texto.

| Área | Arquivos | Substituições |
|---|---|---|
| `game/data` (.tres) | 228 | 565 |
| `game/tools` (geradores, arte, conteúdo) | 62 | 356 |
| `game/tests` | 47 | 326 |
| `site` | 5 | 192 |
| `game/localization` (.csv) | 8 | 168 |
| `docs/` | 26 | 156 |
| `*.md` da raiz | 8 | 76 |
| `game/assets` (.tres/.import/REGISTRO) | 22 | 55 |
| `game/scripts` | 31 | 50 |
| `game/scenes` | 14 | 44 |
| `launcher` (Go, frontend, tema, README) | 9 | 23 |

## 5. O que NÃO foi trocado, e por quê

| Onde | O quê | Por quê |
|---|---|---|
| `lore.md:59, 71`; `TITULOS-E-SKILLS.md:150`; `game/localization/content.csv` (DLG_ELDER_TIAO_LEGEND_1); `game/localization/story_arc1.csv` (QUEST_ARC1_CH5_COMPLETE_P2); `game/tools/content/pindorama_trees_data.py:574`; comentário em `game/scripts/client/character_slots.gd:98` | "sabia" | É o verbo saber ("não sabia voar", "nada, sabia?") |
| `game/scripts/client/env/ambient_bird_art.gd`, `ambient_life.gd`, `game/tests/client/test_living_environment.gd`, `camp_life_capture.gd` | espécie `&"sabia"` e o comentário "(sabiá, anu, pardal…)" | É o passarinho do ambiente vivo |
| `game/assets/_reference/crests/p_brasil.txt` | "a sabia songbird" | Prompt do brasão: é a ave |
| `game/data/regions/brasil.md:90` | "canto de sabiá" | A ave (trilha sonora) |
| `TITULOS-E-SKILLS.md:83` | "sabiá" na lista de palavras tupi do dia a dia | A palavra/ave |
| `PETS-E-MONTARIAS.md:139, 144, 181, 194, 353, 438` | "Sabiá-laranjeira", "herda o sabiá", companheiro **Sabiá**, "Sabiá e coruja" | O companheiro-ave proposto (id `pindorama_companion_thrush`). Ver pendência 1 |
| `antes/` (fora do git) | `antes/saves/movecap.json` com `"nationality": "sabia"` | Cópia antiga de save, não usada por nada; serve de amostra do formato antigo (a migração foi testada com ela) |
| `game/scripts/shared/legacy_ids.gd`, `launcher/server/legacy_ids.go`, `legacy_ids_test.go`, `game/tests/server/test_legacy_ids.gd` | ids antigos | É a própria tabela de migração e seus testes |
| Este arquivo | nomes antigos | Registro da troca |
| Histórico do git, `.work/`, `.godot/`, `build/` | — | Fora do alcance (histórico ou gerado) |

## 6. Migração de saves e estado (já no código)

Onde fica o estado persistente:

- **Personagem**: `user://server_saves/<nome>.json` (JsonCharacterStore). Guarda `home_map`/`last_city` (mapa de
  entrada/retorno), aparência (`nationality`, `title_look`), títulos, título exibido, quests ativas/concluídas, skills,
  barra 1–0, inventário/equipamento (inclusive `bound_zone`), companheiros (posse, ativo, apelidos, nível),
  montarias e `once_flags` (`waystone:<mapa>`, `waystone_save:<mapa>`, `causo_deed:title:<título>`).
- **Painel/eventos**: `user://server_state/active_events.json` (gravado pelo painel Go, lido pelo servidor do jogo).
- **Cliente**: `user://character_slots.cfg` (lembrança dos slots, com `title_look`) e `user://appearance.cfg`
  (`nationality`).
- **Contas (auth Go)**: `launcher/server/store.go` guarda só conta, senha e e-mail. `character_owners.json` liga nome a
  conta. Nenhum dos dois guarda id de jogo, então não precisaram de migração.

Como funciona:

1. `LegacyIds.migrate(valor)` percorre dicionários (chaves e valores), arrays e textos e troca cada id antigo pelo novo.
   Usa a tabela `RENAMED` e, como rede de segurança, troca também o segmento `sabia` em ids minúsculos separados por
   `_`/`:` (ex.: `causo_deed:title:…`, `waystone:…`). Não mexe no que o jogador escreveu: nome do personagem
   (`name`) e apelidos dos companheiros (valores de `names`). Texto com maiúscula ou espaço não é tratado como id.
   É idempotente: id novo passa direto.
2. **Save**: `CharacterData.from_save` aplica a migração **antes** de ler, porque sem isso o inventário descartaria o
   item renomeado e os companheiros/montaria sumiriam. Se algo mudou, marca `legacy_ids_migration_pending`, e o
   `JsonCharacterStore.load_character` regrava o arquivo no formato novo na hora (o mesmo caminho do kit inicial).
3. **Rede**: `CustomizationOptions.sanitize` converte nacionalidade antiga vinda do cliente. O
   `protocol_version` subiu de 5 para 6: cliente antigo, que procuraria `fields_sabia.tscn`, é recusado com
   "atualize o jogo" em vez de quebrar dentro do mapa.
4. **Cliente**: `CharacterSlots.load_slots` e `title_screen._load_appearance` migram o cache local ao ler.
5. **Eventos**: o servidor do jogo migra as chaves de `active_cosmetics` ao ler. O painel Go
   (`launcher/server/legacy_ids.go`) regrava o `active_events.json` uma vez ao subir (região "Terra do Sabiá", o
   cosmético do broche e as chaves ativas), migra de novo a cada leitura e mostra o `home_map` novo na lista de
   jogadores enquanto o save ainda não foi regravado.

A migração **não foi rodada** sobre os dados reais do servidor. Ela acontece sozinha quando o servidor
atualizado carregar cada personagem e quando o painel subir.

Testes:

- `game/tests/server/test_legacy_ids.tscn` (no alvo `make test`): monta um save antigo completo numa pasta temporária,
  carrega pelo store e confere mapa, nação, roupa de título, títulos, quests, skills, barra, itens, arma, zona do item,
  companheiro (apelido intacto), montaria, waystones, Causos, regravação sem id antigo e idempotência.
  Com `-- --legacy-dir=<pasta com cópias>` também carrega cópias de saves.
- `launcher/server/legacy_ids_test.go` (`make launcher-test`): migração do `active_events.json`.

## 7. Pendências para o dono

1. **Companheiro-ave "Sabiá"** (`pindorama_companion_thrush`, só proposto em PETS-E-MONTARIAS.md): o doc diz
   "a ave que dá nome à região", o que deixou de ser verdade. Manter o sabiá-laranjeira como companheiro (agora só a
   ave símbolo do Brasil) ou trocar? Ficou como está.
2. **Brasão do Brasil** (`assets/ui/crests/crest_brasil.png`): o prompt do desenho (`_reference/crests/p_brasil.txt`) é um sabiá num galho de ipê. Não tem texto.
   Decidir se o símbolo da nação continua sendo a ave.
3. **Arte com texto embutido**: nenhuma arte de jogo tem "Sabiá" escrito. Capturas antigas de referência em `docs/`
   (pranchas `docs/arte-cenario/v*/`) e `game/assets/worldmap/source/atlas_1080_zoom_pindorama.png` (captura do atlas)
   são registros de época e podem mostrar o nome antigo. Só os nomes dos arquivos foram trocados.
4. **Enfeite das fogueiras** (`camp_dressing.gd`) e partículas (`scenery_life.gd`) usam o id do mapa como semente.
   Nos Campos, panelas e canecas em volta das fogueiras podem mudar de lugar (é só enfeite do cliente).
