# Cenário vivo (08/10/2026)

Objetivo: o mundo inteiro se mexendo (referência Samsara Saga) — plantas balançando, sombras de nuvem passando no chão,
pontinhos de luz/pólen no ar, vaga-lumes à noite, água e chão reagindo ao clima. Regra: tudo **genérico por bioma/mapa**,
nada só no Campo de Treino. Só cliente (nada no servidor, nada no headless).

Peça central: `game/scripts/client/env/scenery_life.gd` (nó `SceneryLife`, criado em todo mapa por `Map._ready`).

## 1. Auditoria (antes desta frente)

Levantada carregando cada cena de `game/scenes/maps/` em headless e listando o shader de cada superfície de malha.
"Folha c/ vento" = superfície `env_foliage` (vento por `COLOR.a`); "tronco" = `env_painted` (parado).

| Mapa(s) | Plantas | Folha c/ vento | Tronco/copa inteira | Água | Partículas | Chão molha | Observação |
|---|---|---|---|---|---|---|---|
| training_field | muitas (pk_*, palmeiras, buriti, ipês) | sim | **parado** | animada (`env_water`) | fogueira, fumaça, borboleta, vaga-lume, pétalas, neve (só aqui) | sim | único mapa com vida própria |
| city_awakening | ipês/canteiros (geo_*) | sim | **parado** | animada | pétalas de ipê, brilho do cristal | sim (`env_terrain`) | |
| fields_pindorama, _buriti, _crossroads | pequi, ipê, buriti (MultiMesh), capim | sim | **parado** | animada (oásis/vereda) | — | sim (`env_terrain`) | trilha `woodland_trail` não molhava |
| split_sky_plateau (+ridges, summit) | árvores secas, ipê, capim dourado | sim | **parado** (árvore seca toda parada) | — | brasas (summit) | sim (`env_terrain_world`) | |
| enchanted_forest (+glade, heart, roots) | árvore de mata, palmeira, bambu, samambaia | sim | **parado** | — | — | **não** (`forest_floor`, trilha) | |
| jungle_z_*, jungle_ratanaba_* | **nenhuma** (graybox: caixas + pedras) | — | — | — | — | não (`env_painted`) | sem sol (fundo escuro + luz ambiente) |
| fog_moor_* | nenhuma (graybox) | — | — | — | — | **não** (`forest_floor`) | tem sol |
| hollow_mountain_* | nenhuma (graybox) | — | — | — | — | não | tem sol |
| city_serra_dourada, city_sumidouro | nenhuma | — | — | — | — | não | |
| city_of_z_*, ruins_ratanaba_* | nenhuma | — | — | — | — | — | ruínas escuras, cristais (StandardMaterial3D) |
| cave_reino_encoberto_*, hollow_earth_*, hoer_verde_*, sumidouro_abyss | samambaia/cogumelo (poucos) | parcial | — | — | **nenhuma** | — | cristais com emissão parada |
| elder_trial_arena | nenhuma | — | — | — | — | — | arena |

Achados: (a) as folhas já tinham vento, mas troncos, galhos e coroas de palmeira (`env_painted`) ficavam parados e o
vento de folha era curto (3–10 cm) — de longe a árvore parecia estática; (b) nenhuma sombra de nuvem em lugar nenhum;
(c) partículas de ar só no Campo de Treino; (d) caverna sem vida nenhuma; (e) chão de mata (`forest_floor`) e trilha
(`woodland_trail`) não liam `env_wetness`; (f) selva/brejo/serra são graybox sem plantas nem água — ganharam partículas
e nuvem, mas balanço/água dependem de vestir esses mapas (fora desta frente).

## 2. O que mudou

| Arquivo | Mudança |
|---|---|
| `assets/shaders/env_wind.gdshaderinc` | guarda de include + `environment_plant_bend()`: balanço da planta inteira (peso = (altura/altura da planta)², média zero, rajada que atravessa o mapa, mais forte com chuva) |
| `assets/shaders/env_foliage.gdshader` | `instance uniform veg_bend/veg_height` (0 = como antes) somando o balanço inteiro ao vento de folha; sombra de nuvem |
| `assets/shaders/env_painted.gdshaderinc` | mesmo balanço por nó (tronco/galho/coroa acompanham a copa); topo de pedra/piso/telhado escurece com `env_wetness`; sombra de nuvem. Construção e pedra nunca recebem `veg_bend` (é por nó, padrão 0) |
| `assets/shaders/env_weather.gdshaderinc` | global `env_clouds` (vec4: força, cobertura, deriva XZ), `env_value_noise`, `env_cloud_shade()` |
| `assets/shaders/env_terrain.gdshaderinc`, `env_terrain_world.gdshader` | sombra de nuvem no chão |
| `assets/shaders/forest_floor.gdshader` | molha (escurece, brilho, poças no folhiço, anéis de pingo) + sombra de nuvem |
| `assets/shaders/woodland_trail.gdshader` | trilha molha (poças no miolo) + sombra de nuvem; seco = igual |
| `assets/shaders/env_ambient_particle.gdshader` | tipos novos: 4 pontinho de luz/pólen/poeira, 5 folha caindo, 6 gota, 7 morcego; `billboard=false` para névoa deitada |
| `assets/shaders/env_crystal_pulse.gdshader` (novo) | camada aditiva de pulso para cristal de caverna (`material_overlay`) |
| `scripts/client/env/scenery_life.gd` (novo) | bioma por prefixo; vento por nó nas plantas; publica `env_clouds`; partículas de ar seguindo a câmera; caverna (gotas, poeira nas luzes, morcegos, cristais) |
| `scripts/shared/map.gd` | cria `SceneryLife` em todo mapa (fora do headless/servidor) |
| `project.godot` | `[shader_globals]` `env_clouds` |
| `tests/client/test_living_environment.gd` | checagens novas (abaixo) |
| `tests/client/scenery_capture.gd`, `run_scenery_capture.sh` (novos) | captura no cliente real (porta 8289) |

### Biomas (`SceneryLife.BIOMES`)

| Bioma | Mapas | Dia | Noite | Sempre | Nuvem |
|---|---|---|---|---|---|
| campo (padrão) | training_field, fields_pindorama*, split_sky*, hollow_mountain*, mapa novo | pólen/luz dourada | vaga-lumes | — | sim |
| selva/mata | jungle_*, enchanted_forest* | pontinhos verde-dourados | vaga-lumes | folhas caindo (60% na chuva) | sim (se tiver sol) |
| brejo | fog_moor_* | pontinhos | vaga-lumes azulados | névoa rasteira deitada no chão | sim |
| cidade | city_* | poeira clara | poucos vaga-lumes quentes | — | sim |
| ruínas | city_of_z*, ruins_ratanaba* | — | — | poeira dourada + extras de caverna | não |
| caverna | cave_*, hollow_earth*, sumidouro_abyss, hoer_verde* | — | — | poeira, gotas, poeira nas luzes, morcegos, cristais pulsando | não |
| nenhum | elder_trial_arena, arena_*, interior_* | — | — | — | não |

Chuva forte apaga pólen e vaga-lumes; nuvem fica ~35% mais forte e cobre mais o céu. Nuvem some à noite e com neblina
forte (`weather_visual.y` ≥ 0,6) e só existe em mapa externo com `DirectionalLight3D`.

### Vento só em vegetação

Por **nó**, nunca global: `SceneryLife.apply_plant_wind()` só marca malha com superfície `env_foliage` e topo ≥ 1,6 m
(árvore, palmeira, bambu) ou árvore seca pelo nome (`deadtree`, `twisted`). Força por metro: palmeira/buriti 0,034,
bambu/junco 0,045, árvore 0,022, seca 0,012 (árvore de 7 m ≈ 15 cm no topo; palmeira de 9 m ≈ 30 cm). Capim e
arbusto continuam só com o vento de folha. O mesmo cálculo roda no tronco e na copa → andam juntos.

## 3. Custo por qualidade

| | Alta | Média | Baixa (mobile) |
|---|---|---|---|
| Partículas de ar (CPU) | 100% (campo ~30 vivas; caverna ~22 + 8 gotas + até 8×8 nas luzes) | 60% | 30% (mín. 2 por camada) |
| Corte de distância | 60 m | 45 m | 30 m |
| Sombra de nuvem | 2 ruídos por pixel (só com força > 0) | igual | **desligada** (global força 0 → retorno imediato) |
| Balanço de planta | só vértice, só nós de planta | igual | igual (barato) |
| Morcegos | 1–3 quads a cada 9–22 s | igual | **desligado** |
| Cristal pulsando | 1 passada aditiva por cristal | igual | **desligado** |
| Tique do script | 4×/s | 4×/s | 4×/s |

## 4. Testes

- `godot --headless --path game --script res://tests/client/test_living_environment.gd` → PASS (0 falhas). Novas:
  bioma por prefixo; nuvem (dia sim, noite/neblina/Baixa/caverna/sem sol não, chuva mais densa); shaders com
  `env_cloud_shade`; chão de mata e trilha molham; `veg_bend` padrão 0; vento só em vegetação em 5 mapas reais (nenhuma
  parede/casa/pedra/barraca/cerca marcada); palmeira mais solta que árvore e pedra parada; camadas de ar por bioma
  (dia/noite/chuva, Baixa reduz, partículas em coordenada de mundo); caverna real com gotas, poeira nas luzes, cristais
  com pulso, morcegos que passam e somem, Baixa sem pulso.
- `xvfb-run -a godot --path game --resolution 1280x720 res://tests/client/test_render.tscn` → PASS.
- `xvfb-run -a godot --path game --resolution 1280x720 res://tests/client/test_ui.tscn` → PASS.

## 5. Validação no cliente real

`GODOT=../.tools/godot-4.7.2 OUT=<pasta> PHASE=antes|depois [MAPS=a,b] tests/client/run_scenery_capture.sh` — servidor
próprio na porta 8289. Por mapa, 4 quadros a 0,5 s (dia); `fields_pindorama` também de noite; `enchanted_forest` também
depois de ~36 s de chuva forte.

## 6. Pendências

- Selva, brejo, serra e cidades de pedra são graybox: sem plantas nem água para balançar/animar. Ao vestir esses
  mapas com o kit (`env_foliage`/`env_water`), o balanço e a nuvem já valem sozinhos.
- Morcego é discreto sobre o vazio preto da caverna (silhueta escura); ler melhor sobre o chão.
- `build_kit.gd` não precisa mudar: o balanço é por nó em tempo de jogo.
