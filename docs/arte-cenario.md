# Arte de cenário — kit pintado e renderização (GDD §17.0.A, §9.5, §17.2)

Direção aprovada em 27/09/2026: **cenário 3D estilizado com texturas pintadas à mão**, luz quente e suave,
vegetação cheia; **personagens, NPCs e monstros continuam em pixel art** (sprites). Este documento é o guia
para vestir qualquer mapa (Agente W e mapas futuros).

Comparações (antes × depois, e lookdev × referência 1) em `docs/arte-cenario/`:
`forest_vs_ref1_*.jpg`, `city_before_after_*.jpg`, `city_street_before_after_*.jpg`,
`field_before_vs_lookdev_*.jpg`, `forest_clearing_*.jpg`, `city_preview_*.jpg` (1920×1080 e 1280×720).

---

## 1. Renderização (ClientView)

- **Mundo na resolução nativa** e **ocupando a janela inteira** (sem faixas cinzas; GDD §9.5). A SubViewport
  do `ClientView` agora tem o tamanho da janela (`Balance.cfg.world_render_mode = "native"`, padrão).
  O modo antigo (`"internal"`: 960×540 ampliado por inteiro) continua disponível só para comparação/depuração.
- **Interface por cima**: a HUD/janelas/minimapa são desenhados sobre a imagem do mundo (nada mudou na UI).
- **Sprites nítidos**: continuam com filtro *nearest*. O FOV da câmera é escolhido para que, no ponto focado
  e com zoom 1,0, **1 texel de sprite = k pixels inteiros** na tela:
  `k = round(altura_janela × character_screen_fraction / character_body_px)` (mínimo 1).

  | Janela | k (px/texel) | Viajante na tela (zoom 1,0) | zoom mínimo 0,8 |
  |---|---|---|---|
  | 1280×720 | 1 | 86 px = 11,9% | 9,5% |
  | 1920×1080 | 2 | 171 px = 15,9% | 12,7% |
  | 2560×1440 | 2 | 171 px = 11,9% | 9,5% |
  | 3840×2160 | 3 | 257 px = 11,9% | 9,5% |

  (Medido pelo `tests/client/test_render`. Referências: ~12–15%. Em 1080p o inteiro mais próximo dá 15,9%;
  sair do inteiro deixaria os pixels desiguais.) **Zoom limitado a 0,8–1,0** (`camera_zoom_max` era 1,3, o que
  deixava o personagem enorme). O "esticão" vertical 1/cos(45°) do sprite só compensa o achatamento da câmera
  inclinada — na tela o sprite fica ~1:1.
- **Clique/picking** inalterados (raycast na SubViewport; `window_to_internal` agora é identidade no modo
  nativo; `get_view_scale()` = 1 e `get_view_offset()` = 0, então testes/autotestes antigos seguem válidos).
- **Pós-processo**:
  - no `Environment` de cada mapa (`EnvLook`): sol quente com sombra PCF macia (`light_angular_distance`,
    `shadow_blur`), SSAO, *glow* suave (softlight), névoa de distância quente, tonemap *filmic* com contraste
    e brilho levemente ajustados, céu procedural quente;
  - na tela (`assets/shaders/env_screen_post.gdshader`, no `GameView` do ClientView, vale para todo mapa):
    **tilt-shift** (desfoque só nas faixas de cima e, mais fraco, de baixo — a faixa central do jogador é
    amostrada sem filtro, 100% nítida) e **vinheta** quente. Sem FXAA/TAA (borrariam os sprites); MSAA 3D.

### Presets de qualidade (`scripts/client/env/env_quality.gd`)

`EnvQuality.current = EnvQuality.Preset.MEDIA` e depois `client_view.apply_env_quality()` (tela de opções,
futuro). O preset só **desliga custo**; o *look* é do mapa.

| | Alta | Média | Baixa |
|---|---|---|---|
| MSAA 3D | 4× | 2× | — |
| SSAO / glow | sim / sim | sim / sim | não / não |
| Névoa | sim | sim | sim |
| Sombra (atlas / filtro / alcance) | 4096 / PCF macio alto / 60 m | 2048 / PCF macio baixo / 45 m | 1024 / dura / 30 m |
| Tilt-shift / vinheta | sim / sim | sim / sim | não / sim |
| Densidade de capim/flores (MultiMesh) | 100% | 60% | 30% |
| Distância de corte da folhagem | 60 m | 45 m | 30 m |

---

## 2. O kit (`assets/environment/painted/`)

Tudo original (Bria + código). Prompts, seeds e tratamento: `assets/environment/painted/REGISTRO.md`.
Texturas com **filtro linear + mipmaps** (cenário não é pixel art), compressão VRAM.

### Shaders (`assets/shaders/`)
- `env_terrain.gdshader` — terreno: grama (2 escalas + variante + manchas macro quentes/frias), terra,
  calçamento, areia, rocha, misturados por **splat** em coordenadas de mundo (R terra, G calçamento, B areia,
  A rocha; fundo = grama) ou por cor de vértice; bordas "comidas" por ruído e pela luminância da camada.
- `env_foliage.gdshader` — copas e cards: textura × cor de vértice (oclusão pintada), **vento** (peso no alfa
  do vértice), normais esféricas (volume macio), **translucidez** (BACKLIGHT), variação por instância,
  base escurecida para capim/flores, desbotamento por distância.
- `env_painted.gdshader` — paredes, telhados, madeira, pedra e props: UV ou triplanar em metros,
  oclusão por vértice, musgo no topo, sujeira na base, variação macro, `detail` (<1 acalma texturas ocupadas).
- `env_screen_post.gdshader` — tilt-shift + vinheta (ClientView).

### Materiais (`materials/mat_*.tres`)
`terrain`, `plaster_warm` / `plaster_ochre` / `plaster_rose` (cal **quente**, nunca azulada), `roof_clay`
(telha canal), `paving`, `cobble_wall`, `stonewall`, `azulejo`, `wood` / `wood_dark`, `rock` / `rock_moss`,
`bark`, `metal`, `needles` / `needles_b`, `canopy_broad`, `canopy_ipe`, `card_*` (tufos de pinheiro,
ramalhete, ipê, capim, flores, cogumelos). Ruído compartilhado: `materials/tex_env_noise.tres`.
Environments prontos: `env_warm_day.tres` (campos/matas) e `env_warm_city.tres` (cidade).

### Malhas (`meshes/*.res`, geradas por `tools/art/env_kit/build_kit.gd` com `PaintedGeo`)

| Malha | Vértices | Superfícies (draw calls) |
|---|---|---|
| tree_conifer_a / b / c (pinheiros em "saias" + tufos) | 764 / 987 / 552 | 3 |
| tree_broadleaf_a | 1706 | 3 |
| tree_ipe_yellow_a / tree_ipe_yellow_giant | 1956 / 3606 | 3 |
| bush_round_a / bush_conifer_a | 296 | 2 |
| grass_tuft(_b), flowers(_b), mushrooms(_b) — cards em X para MultiMesh | 8 | 1 |
| prop_crate / prop_barrel | 336 / 316 | 2 |
| prop_fence (2 m) / prop_log / prop_stump | 96 / 34 / 56 | 1 |
| rock_moss_a / b / c | 536 | 1 |

Faltam (próximos): buriti e palmeira volumétricos, ipê roxo, cupinzeiro, água pintada, pontes/docas.

### Scripts (`scripts/client/env/`)
- `PaintedGeo` — primitivas (cilindro, saia de pinheiro, blob de copa, card, tufo, caixa, torno, pedra).
- `PaintedTerrain` — malha de terreno por função de altura, colisão `HeightMapShape3D` (camada 1),
  pintura do splat, material com splat.
- `FoliageScatter` — espalha MultiMesh por pedaços de 16 m, embaralhado; aplica densidade/distância do preset.
  (Os dados das instâncias ficam em metadado do MultiMesh porque o `--headless` não guarda o buffer.)
- `EnvLook` — Environment e sol quentes. `EnvQuality` — presets. `LookdevActors` — sprites do jogo nas cenas
  de lookdev.

---

## 3. Como vestir um mapa (roteiro para W e mapas futuros)

Exemplo completo e comentado: `tools/art/env_kit/build_forest_clearing.gd` (gera
`scenes/lookdev/forest_clearing.tscn`). Prévia da cidade: `tools/art/env_kit/build_city_preview.gd`.

1. **Separar jogabilidade de decoração.** Chão caminhável/colisão (camada 1), navmesh, Interactables e
   pontos continuam como hoje. Tudo que é enfeite vai sob `Decor/` (Trees, Props, Foliage).
2. **Terreno**: uma função de altura suave (relevo nas bordas esconde o horizonte) →
   `PaintedTerrain.build_mesh` + `build_collision`; pinte o splat com funções de distância (trilhas por
   polilinha com borda ondulada, clareiras, areia de margem). 4 px/m basta. `PaintedTerrain.material(...)`.
   Ajuste `grass_tint`/`dirt_tint` por mapa (cerrado = grama mais amarela, mata = mais escura).
3. **Luz**: `EnvLook.make_sun()` + `WorldEnvironment` com `env_warm_day.tres` (ou uma cópia ajustada).
   Nada de ambiente azul/frio forte; sombras macias.
4. **Árvores de composição à mão** emoldurando caminhos e clareiras a 6–12 m do caminho principal (a câmera
   vê ~±17 m na horizontal e de −12 a +8 m na vertical em volta do jogador); depois um **anel de floresta**
   de fundo automático. Árvores de primeiro plano (embaixo da tela) só parcialmente visíveis.
5. **Props** em grupos com história (acampamento: caixotes + barris; cerca na beira da trilha; tronco caído,
   toco, pedras com musgo). Registre obstáculos para o espalhamento não cair em cima.
6. **Folhagem** com `FoliageScatter.add_layer`: capim ~2/m² fora da terra, capim alto nas bordas da trilha,
   manchas de flores (ruído), cogumelos só perto de árvores/pedras. Nunca capim em cima de trilha/calçamento.
7. **Sprites**: não mexer. Sombra dos sprites: só a sombra redonda própria (ver pendência abaixo).
8. **Conferir** com a câmera real: `scenes/lookdev/lookdev_capture.tscn` (ver comandos no topo do script),
   em 1920×1080 e 1280×720, girando o yaw; e o orçamento com `--stats` / `--bench=6`.

### Orçamento de desempenho (por quadro, na câmera do jogo)

| Item | Orçamento | Clareira (medido, Alta) | Prévia da cidade |
|---|---|---|---|
| Draw calls | ≤ 150 | 66–83 | ~70 |
| Primitivas | ≤ 150 mil | 46–62 mil | ~73 mil |
| Instâncias de MultiMesh no mapa | ≤ 25 mil (≤ 3 mil por pedaço de 16 m) | 4,7 mil em 105 pedaços | 1,3 mil |
| Árvores como MeshInstance individuais | ≤ 200 por mapa (acima disso: MultiMesh por espécie com `FoliageScatter`, cast_shadow ligado) | 170 | 1 |
| Texturas do kit | 1024² (terreno/paredes), 512² (cards grandes), 256² (cards pequenos) | — | — |

Tempo de quadro medido em 1920×1026, RTX 2060, câmera girando:
**Alta 4,7 ms (~213 fps), Média 3,35 ms (~298 fps), Baixa 1,54 ms (~650 fps)**; prévia da cidade em Alta
5,25 ms; cidade antiga (960×540) 1,46 ms. VRAM total do processo: ~390 MB Alta / ~290 MB Média / ~160 MB Baixa.

---

## 4. Mapas reais já vestidos com o kit (27/09/2026)

Os dois mapas do MVP **já usam o kit** (o estilo pintado é obrigatório; nenhum mapa conta como pronto no estilo antigo).
Capturas 1920×1080 em `docs/arte-cenario/mapas/` (`city_plaza|docks|market|street_*.jpg`, `campo_<zona>_*.jpg`,
`campo_zonas_antes.jpg` × `campo_zonas_depois.jpg`, `minimapas.png`).

- **Porto do Despertar** — `tools/art/build_city.gd` → `scenes/maps/city_awakening.tscn`.
- **Campo de Treino** — `tools/art/build_training_field.gd` (herda de build_city) → `scenes/maps/training_field.tscn`.

Como foi feito (e como manter):
- **Jogabilidade intocada**: chão (camada 1, meta `surface`), NavigationRegion3D (navmesh **idêntico** ao anterior,
  conferido byte a byte), NpcPoints, Interactables (camada 2), AudioZones, SpawnPoint, PointsOfInterest, Spawns.
- **Materiais**: `_paint_materials()` (cidade) e `_paint_field_materials()` (campo) trocam os materiais pixel art por
  cópias tingidas do kit (salvas como `assets/environment/materials/mat_city_*.tres` / `mat_field_*.tres`). Chãos de
  grama usam o shader de terreno (com variação macro); cada nação mantém sua identidade (cerrado dourado, neve,
  areia do deserto, calçamento, cascalho com musgo, chão de mata, prados).
- **Peças trocadas pelo kit** (ipê gigante, árvores, arbustos dos jardins, pétalas quadradas, "cristais" roxos de
  urze, sombras falsas) são **silenciadas** com `mute_geo` — a geometria vai para o lixo, mas o RNG e as obstruções
  continuam iguais (por isso o navmesh não muda). A malha do kit entra em `kit_items`.
- **Decor/Kit** (FoliageScatter): tudo do kit em MultiMesh por malha, em pedaços de 24 m, sombras ligadas para
  árvores/arbustos/pedras/props. No campo, cada antigo sprite `fld_*` vira uma malha do kit pela tabela
  `SPRITE_KIT` (mesma posição, escala convertida). Os MultiMesh ficam em `scenes/maps/<mapa>/mm_*.res`.
- **Luz**: `EnvLook.make_sun()` + `env_warm_city.tres` (cidade) / `env_warm_day.tres` (campo).
- Minimapas regenerados (`render_minimap.gd` + `minimap_pixel.py`).
- Números: cidade 208 MultiMesh / 11,9 mil instâncias; campo 386 MultiMesh / 18,7 mil instâncias; na câmera do
  jogo ~70–80 draw calls, 55–80 mil primitivas.

Ainda do visual antigo (próximo passe): toldos listrados e frutas low-poly da feira, janelas/molduras chapadas,
palmeiras em vaso low-poly, cascos dos barcos, prédios de marco das nações (torres, templo, pirâmide, casa longa)
com texturas pintadas mas formas de bloco, lagos como discos planos.

---

## 4b. Revisão 2 (27/09/2026, noite): pacotes CC0 + Blender

O dono reprovou o "brócolis" procedural. Agora:
- **Modelos-base de pacotes CC0** (licenças conferidas: `game/assets/environment/LICENSES.md`): Quaternius Stylized
  Nature MegaKit (árvores, pinheiros, arbustos, capim, flores, cogumelos, pedras), Medieval Village MegaKit (paredes de
  reboco, telha canal, janelas, portas, venezianas, cunhais, chaminés), Fantasy Props MegaKit (bancas, carroça,
  barris, caixotes, vasos), Kenney Pirate Kit (barcos, píer). Originais em `game/assets/environment/packs/`.
- **Conversão** `tools/art/env_kit/build_pack_kit.gd` → `assets/environment/painted/meshes/pk_*.res` / `pkv_*.res`:
  junta as partes (1 superfície por material), LODs automáticos, base no chão, materiais trocados pelos do kit
  (folhagem recolorida por gradiente da oclusão → copas grandes e macias na paleta quente; ipê amarelo/roxo, sakura,
  oliveira, bétula, mata, pequi e pinheiro com neve feitos por recolor; paredes com cor por instância).
- **Modelos originais em Blender** (`tools/art/blender/*.py`, reexecutáveis, `--preview` renderiza PNG):
  buriti (folhas em leque), cristal de renascimento (+ `env_crystal.gdshader` emissivo + faíscas), marcos das 9 nações
  (torre caiada com azulejo e fonte; colunata grega; obeliscos e casa de adobe; torre redonda e cabana de sapê;
  casa longa com teto de turfa; cabana sobre pés e isbá; portal da lua, pavilhão e lanternas; ponte arqueada e casa
  japonesa; plataforma em degraus com mato) e o acampamento (tendas, fogueira). Saída em `assets/environment/blender/`.
- **Catálogo** `scripts/client/env/kit_catalog.gd`: nome lógico ("tree_conifer_a") → variantes reais + escala.
- **Casas coloniais** `scripts/client/env/colonial_house.gd`: montagem modular (paredes de reboco caiado com cor por
  casa, telhado de telha canal, janelas/portas com venezianas coloridas, barrado de azulejo, cunhais de pedra).
- **Bordas macias**: manchas de chão (clareiras das nações, trilhas, areia, jardins) ganharam franja com alfa por
  vértice + ruído (`env_terrain_decal`/`env_painted_decal`); rio como faixa contínua (`ribbon`) e água com margem
  clara, espuma macia e borda que se funde (`env_water.gdshader`).
- Sprites não projetam mais a sombra "risco" (`directional_sprite_3d.gd`, cast_shadow OFF; só a sombra redonda).

Capturas (1920×1080, com a referência 1 ao lado): `docs/arte-cenario/v2/*_ref_antes_depois.jpg` (clareira, praça,
docas, feira, acampamento, Terra de Pindorama, Japão, Grécia) e `v2/*_1920x1080.jpg`.

Desempenho (RTX 2060, 1920×1026, câmera girando): praça da cidade Alta 10,5 ms (~95 fps) / Baixa 3,9 ms;
campo de treino Alta 9,9 ms / Baixa 3,0 ms; clareira Alta 9,6 ms / Baixa 2,9 ms. Draw calls na câmera: cidade ~190–215
(acima do orçamento de 150 — próximo passo: atlas/merge das peças das casas), campo ~60–80, clareira ~60–75.

---

## 4c. Revisão 3 — Campo de Treino (27/09/2026)

- **Palmeiras macias**: `tools/art/blender/palms_soft.py` gera buriti (leques) e coqueiro/tamareira (folhas-pena)
  com folhas em *cards* pintados com alfa (Bria: `cards/card_palm_fan.png`, `card_palm_frond.png`), sem facetas.
  O catálogo (`palm_buriti_a`, `palm_date_a`) aponta para elas.
- **Bordas macias de verdade**: os shaders `*_decal` agora têm `cull_disabled` (antes a franja de parte das trilhas
  era descartada pelo sentido dos triângulos e a borda ficava dura).
- **`_dress()` em `build_training_field.gd`** (só enfeites baixos/atravessáveis ou encostados em obstruções que já
  existem — navmesh idêntico): seixos e capim alto nas bordas das trilhas; juncos (`reeds_card`, card da Bria),
  pedras com musgo e seixos nas margens do riacho; Terra de Pindorama densa (capim dourado, flores do cerrado,
  arbustinhos secos, seixos, pedrinhas com musgo e cogumelos ao pé de árvores/cupinzeiros); acampamento com bancos,
  sacos, barris, caixote, toras, bonecos de treino e capim na borda; Japão com trevos, pedras de passagem e
  samambaias sobre gramado com cascalho; México com chão de mata verde (samambaias, plantas, flores, cogumelos);
  Egito com dunas baixas e ruínas caídas (obelisco quebrado, blocos); Grécia com colunas tombadas e degraus quebrados.
- Marcos com pedra de facetas grandes (`tex_rock`) em vez do padrão de "calçada".

Capturas (1920×1080, referência 1 | antes | depois): `docs/arte-cenario/v3/tf_{camp,pindorama,japao,mexico,egito,grecia}_ref_antes_depois.jpg`.
Desempenho na Terra de Pindorama: Alta 12,1 ms (103 draw calls) / Baixa 3,7 ms (70).

---

## 4d. Revisão 4 — Acampamento (nascimento), validado no CLIENTE REAL (28/09/2026)

**Regra nova: visual só vale com captura do jogo real** (servidor + cliente, save novo → nasce no acampamento,
janela 1920×1080). Ferramenta: `scenes/lookdev/real_tour.tscn` (herda `main.tscn`; o personagem anda de verdade até
cada entrada de zona pedindo movimento ao servidor e salva a tela com a interface). Script de apoio em
`.work/v/tour.sh`. Capturas em `docs/arte-cenario/v4/` (`00_spawn.jpg` primeiro; `spawn_ref_antes_depois.jpg`).

- Fogueira nova (`tools/art/blender/camp.py`: anel de pedras, lenha, brasas emissivas) + chama pintada
  `assets/shaders/env_fire.gdshader` (billboard só em Y, puxada para a câmera — antes a chama afundava no chão e
  virava uma "bolha") + luz tremulando (`scripts/client/env/flicker_light.gd`).
- Praça de terra batida redonda (r 6,6 m) com borda macia; trilhas estreitas para cada nação com pontas
  arredondadas; gramado com flores e arbustos entre as trilhas e na borda.
- Tendas listradas com tapete e bandeirola, placa com seta (cor da nação) em cada saída, lampiões, poço e carroça
  de suprimentos, bancos; rancho dos Mestres novo (varanda de sapê, rede, potes de barro).
- As bandeiras de brasão (`Decor/Banners`) e os novos spawns (meta `stage`) do coordenador foram mantidos.
- Poço e carroça registram obstrução própria → navmesh re-assado (2429 vértices) e verificado (`verify_training_field` OK).

---

## 4e. Revisão 5 — Campo de Treino orgânico + vinhetas das nações (28/09/2026, cliente real)

- **Terreno único com relevo** (`tools/art/env_kit/field_relief.gd`, shader `env_terrain_world.gdshader`): 11 camadas
  pintadas em 3 mapas de mistura; zonas com contorno lobado, trilhas curvas, margens de areia; encostas viram rocha
  sozinhas; pinceladas grandes de ruído. As peças de chão antigas (discos/faixas) só registram a forma.
- **Relevo só onde não se anda**: cristas de rocha e mata nas fronteiras entre as nações (obstruções), morros na borda,
  rio afundado com margens (a ponte e o vau continuam andáveis), lagoas com contorno orgânico (o contorno só encolhe,
  nunca passa da obstrução). Água única (`env_water` com margem pela profundidade). Navmesh re-assado e verificado.
- **Vinhetas** (`tools/art/blender/vignettes.py` + `_vignettes()` no construtor): casa caiada com azulejo, muros,
  beco de pedra e barquinho (Portugal); escadaria, ânforas e oliveiral (Grécia); oásis com palmeiras e barco de
  junco (Egito); círculo de pedras e urze (Celta); postes entalhados e rochas de fiorde (Nórdico); poço de grua e
  bétulas (Eslavo); lago com ponte de pedra, bambus e calçamento (China); jardim de cascalho, lanternas de pedra e
  bordos vermelhos (Japão); sumaúma e potes de barro (México). Estandartes dos Mestres agora de frente para quem chega.
- **Direção de arte da tela de título**: céu pintado com nuvens (`env_sky_painted.gdshader`), névoa de altura, AO mais
  forte, pétalas douradas no acampamento, traço fino de "pincel" nas bordas escuras (`env_screen_post`), copas
  pontilhadas quando ficam entre a câmera e o jogador.
- Pedaços de MultiMesh centrados na origem (nascimento num pedaço só). Draw calls no cliente real, preset Alta:
  79 no nascimento, 84–148 nas zonas (orçamento ≤150).
- Validação: `scenes/lookdev/real_tour.tscn` (agora com câmera virada para a vinheta de cada nação e zoom 0,8).
  Capturas: `docs/arte-cenario/v5/`.

---

## 4f. Revisão 6 — clareza de pintura e composição (28/09/2026)

Direção solicitada: campos inspirados na leitura de Ragnarok, pintura limpa, fantasia diurna e continuidade com o login aprovado. Clareira menor, vegetação agrupada, terra menos amarela, luz equilibrada e redução do desfoque. A composição também usa manchas maiores de vegetação nas regiões para abrir espaço ao combate.

A especificação detalhada, com parâmetros, arquivos, uso do Blender e reprodução está em [Campo de Treino — direção de arte](arte-cenario/campo-treino-direcao.md). Capturas de validação: `docs/arte-cenario/v6/`.

---

## 5. Pendências conhecidas
- **Sombra dos sprites**: o `Sprite3D` billboard projeta um "risco" fino na sombra do sol. Recomendado
  `cast_shadow = OFF` nas malhas do `DirectionalSprite3D` (1 linha; arquivo de outro agente — no lookdev já
  está desligado via `LookdevActors`).
- Na prévia da cidade ainda sobram peças do visual antigo (toldos listrados, frutas, janelas chapadas,
  palmeiras low-poly, pétalas quadradas, círculo mágico pixelado): entram na redecoração real.
- Pinheiros vistos muito de perto (primeiro plano) ainda mostram a "saia" esticada: evitar árvore a menos de
  ~6 m do caminho principal até existir uma variante com mais tufos.
