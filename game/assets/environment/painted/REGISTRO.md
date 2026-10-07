# Registro — kit de cenário pintado (GDD §17.0.A)

Todas as imagens são **originais**, geradas com Bria (API v2 `image/generate`, 1024×1024, proporção 1:1)
por `tools/art/character_pipeline/gen.py` (seed da imagem = `SEED` + índice) e recorte de fundo por
`rmbg.py` (Bria `remove_background`). Nenhum asset de outro jogo foi usado; as referências em
`assets/_reference/style_anchor/env_refs/` serviram só de sensação e nunca foram enviadas à IA.

- Brutos: `_bria_src/` (JPG/WebP, com `.gdignore` — a Godot não importa).
- Prompts exatos: `_bria_src/prompts/<nome>.txt`; negativos: `neg_env.txt` (texturas) e `neg_card.txt` (cards).
- Tratamento (cor, calmaria do detalhe, emenda tileável, recorte, sangria de alfa, `.import`):
  `python tools/art/env_kit/process_textures.py` → `textures/tex_*.png` e `cards/card_*.png`.
- Materiais, malhas e Environments: `godot --headless --path game --script res://tools/art/env_kit/build_kit.gd`.

## Texturas tileáveis (`textures/`)

| Arquivo final | Bruto (prompt) | SEED base | Imagem | Uso |
|---|---|---|---|---|
| tex_grass.png | grass3_1 (grass3.txt) | 5200 | 5201 | grama base do terreno |
| tex_grass_lush.png | grass_0 (grass.txt) | 5100 | 5100 | 2ª grama (variação), copa de arbustos, musgo das pedras |
| tex_dirt.png | dirt_1 (dirt.txt) | 5100 | 5101 | trilhas / terra batida |
| tex_cobble.png | cobble_0 (cobble.txt) | 5100 | 5100 | pedra miúda (muros de pedra redonda) |
| tex_paving.png | cobble2_1 (cobble2.txt) | 5400 | 5401 | calçamento de praça/rua |
| tex_sand.png | sand_1 (sand.txt) | 5100 | 5101 | areia / praia |
| tex_rock.png | rock2_1 (rock2.txt) | 5200 | 5201 | rocha, pedras com musgo |
| tex_plaster.png | plaster_1 (plaster.txt) | 5100 | 5101 | paredes caiadas (cal quente / ocre / rosa) |
| tex_roof.png | roof_0 (roof.txt) | 5100 | 5100 | telha antiga (reserva) |
| tex_roof_canal.png | roof2_1 (roof2.txt) | 5400 | 5401 | telha colonial (canal) — padrão |
| tex_wood.png | wood_1 (wood.txt) | 5100 | 5101 | madeira clara/escura, caixotes, barris, cercas |
| tex_azulejo.png | azulejo_0 (azulejo.txt) | 5100 | 5100 | faixas de azulejo |
| tex_bark.png | bark_0 (bark.txt) | 5100 | 5100 | troncos, toco, tronco caído |
| tex_stonewall.png | stonewall_1 (stonewall.txt) | 5100 | 5101 | alvenaria de pedra, cantarias |
| tex_needles.png / _b | canopy_conifer_0 / _1 (canopy_conifer.txt) | 5300 | 5300 / 5301 | saias dos pinheiros |
| tex_ipe_bloom.png | canopy_ipe_0 (canopy_ipe.txt) | 5300 | 5300 | copa do ipê amarelo |

## Cards com alfa (`cards/`)

| Arquivo final | Bruto (prompt) | SEED base | Imagem |
|---|---|---|---|
| card_conifer_tuft / _b | leaf_conifer_1 / _0 (leaf_conifer.txt) | 5200 | 5201 / 5200 |
| card_broad_clump | leaf_broad_1 (leaf_broad.txt) | 5200 | 5201 |
| card_ipe_clump / _b | leaf_ipe_0 / _1 (leaf_ipe.txt) | 5200 | 5200 / 5201 |
| card_flowers / _b | flowers_0 / _1 (flowers.txt) | 5200 | 5200 / 5201 |
| card_grass_tuft / _b | grassblades_0 / _1 (grassblades.txt) | 5200 | 5200 / 5201 |
| card_mushrooms / _b | mushrooms_0 / _1 (mushrooms.txt) | 5200 | 5200 / 5201 |

Gerados e descartados (não usados): grass2, moss, moss2, rock (cubos em perspectiva), canopy_broad,
roof2_0/_2, cobble2_0/_2, leaf_broad_0.

## Revisão 3 — cards de palmeira e juncos (SEED base 5600, `neg_card.txt`)

| Arquivo final | Bruto (prompt) | Imagem |
|---|---|---|
| card_palm_fan.png | fanleaf_1 (fanleaf.txt) | 5601 |
| card_palm_frond.png | frond_1 (frond.txt) | 5601 |
| card_reeds.png | reeds_1 (reeds.txt) | 5601 |

Texturas da revisão 2 (SEED 5500, `neg_env.txt`): tex_snow (snow_1), tex_red_earth (red_earth_1), tex_thatch (thatch_0),
tex_gravel (gravel_1), tex_ice (ice_1), tex_dry_grass (dry_grass_1), tex_jungle_floor (jungle_floor_0); tex_roof_canal
(roof2_1) e tex_paving (cobble2_1) com SEED 5400.
