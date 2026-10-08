# Registro de arte — mapa-múndi (agente G, 27/09/2026)

Ferramenta: **Bria** (`/v2/image/generate`, `/v2/image/edit/remove_background`) via
`game/tools/art/character_pipeline/gen.py` e `rmbg.py`. Pós-processamento com Pillow (script abaixo).
A pasta `source/` tem `.gdignore` (não entra no jogo): originais, prompts, pranchas e capturas de tela.

## Mapa (`world_map.png`, 1920x1080)

- Gerações: 3 prompts × 4 seeds (16:9, 1024x576) + 1 prompt refinado × 8 seeds = **20 variações**.
  Pranchas: `source/contact_map_abc.png`, `source/contact_map_d.png`.
- Prompts: `source/p_map_a.txt`, `p_map_b.txt`, `p_map_c.txt`, `p_map_d.txt`; negativo: `source/neg_map.txt`
  (sem texto, letras, rótulos, bandeiras, grade).
- Seeds: a = 7100–7103, b = 7200–7203, c = 7300–7303, d = 7400–7407 (`SEED + i`).
- **Escolhida: `b_2` (prompt B, seed 7202)** — `source/world_map_b2_original.png`. Motivos: climas bem
  distintos e legíveis (ilhas de névoa, geleiras, terraços, ilhas vulcânicas, dunas, chapadas vermelhas
  com rio, selva com vulcão, mar interno com ilhotas), forma original (não parece a Terra, ao contrário
  das variações A), moldura e rosa dos ventos, desenhos de monstros fofos e ameaçadores. Nenhum texto.
- Tratamento: reduzida para **960x540** (Lanczos, mesma grade de pixel da tela de título
  `assets/ui/title/title_bg.png`), nitidez leve (unsharp r=1,2, 60%), saturação +5% →
  `source/world_map_base_960.png`; ampliada ×2 em vizinho mais próximo → `world_map.png` (1920x1080, pixel nítido).
  Importação com mipmaps (fica suave quando o mapa aparece menor que 1:1 e nítido no zoom).

Prompt escolhido (B):
```
beautiful hand painted pixel art fantasy world map, old parchment paper with ornate golden decorative border,
bird's eye view of a big continent with varied climates: frozen white lands and glaciers at the top, green misty
islands top left, pine forests and fjords top center, grasslands and birch forest top right, jade green terraced
mountains right, a scattered island chain far right, a sunny inner sea with many small islands in the center,
a large green river delta and red table mountains lower left, a steamy rainforest with smoking volcanoes bottom
left, sand dunes and a desert river bottom right, turquoise seas with painted waves, cute doodles of sea monsters,
a giant sea serpent, a whale and a ship, compass rose in a corner, warm golden light, soft pastel palette,
crisp pixels, no text, no writing, no labels
```

## Ícones (`icons/wm_icon_*.png`, 48x48, fundo transparente)

- Mesmo estilo para todos (sufixo comum em cada `source/p_<id>.txt`): *"pixel art fantasy world map icon, a single
  small object centered, seen from a 3/4 top-down view, bold readable silhouette, warm soft slightly pastel
  colors, 1px dark brown outline, 3-tone soft shading, light from top-left, plain flat white background, crisp
  pixels, no text, no letters"*. Negativo: `source/neg_icon.txt`. 4 seeds por ícone, 1:1. Prancha: `source/contact_icons.png`.
- Tratamento: remoção de fundo (Bria), recorte pelo alfa, quadrado, Lanczos para 48x48, alfa binário (≥110).

| Arquivo | Uso | Seed escolhida | Original |
|---|---|---|---|
| `wm_icon_city.png` | capital | 8102 | `source/icon_city_city_2.png` |
| `wm_icon_town.png` | vila | 8112 | `source/icon_town_town_2.png` |
| `wm_icon_field.png` | campo de caça, área inicial, arena | 8121 | `source/icon_field_field_1.png` |
| `wm_icon_dungeon.png` | masmorra de folclore (e "não alcançada" na legenda) | 8131 | `source/icon_dungeon_dungeon_1.png` |
| `wm_icon_mystery.png` | masmorra de mistério (Viajante perdido) | 8142 | `source/icon_mystery_mystery_2.png` |
| `wm_icon_boss.png` | chefe | 8501 (prompt `p_boss2.txt`) | `source/icon_boss_boss2_1.png` |
| `wm_icon_landmark.png` | marco | 8161 | `source/icon_landmark_landmark_1.png` |
| `wm_icon_port.png` | porto | 8181 | `source/icon_port_port_1.png` |
| `wm_icon_here.png` | "você está aqui" (pétala dourada da Florada) | 8171 | `source/icon_here_here_1.png` |

- O primeiro prompt de chefe (seeds 8150–8153) gerou uma cara vermelha de chifres que lembra iconografia
  religiosa (demônio); foi **descartado** e trocado por um emblema de serpente-dragão num escudo (`p_boss2.txt`).

## Capturas de tela

`source/atlas_1080_fit.png`, `source/atlas_720_fit.png`, `source/atlas_1080_zoom_pindorama.png`
(geradas por `scripts/client/ui/world_atlas_test.gd`).

## Checklist (GDD §17.10, resumido)

- Sem texto na arte (nomes pela engine) ✔ · sem nada de Ragnarok ou de outro jogo ✔ · sem símbolo religioso ✔
- Paleta quente e pastel coerente com a tela de título ✔ · pixel nítido ✔
- Pendente: aprovação do dono; quantizar para a paleta mestra se a direção de arte pedir.
