# Personalização do personagem — pipeline e integração

GDD §6.1, §17.4; contrato `docs/contracts-city-walk.md` ADENDO 2.

## O que existe

| O quê | Onde |
|---|---|
| Corpo-base (Viajante com cabelo raspado; roupa, rosto e posição idênticos às folhas `chr_traveler_*`) | `assets/characters/base/chr_<body>_base_{idle,walk,sit}.png` |
| Máscaras do corpo-base (R = pele, G = olhos, B = cabelo raspado; valor = tom) | `assets/characters/base/chr_<body>_base_mask_{idle,walk,sit}.png` |
| Cabelos (rampa de cinza, 5 tons) | `assets/characters/hair/<style>/<body>_{idle,walk,sit}.png` |
| Brincos | `assets/characters/face/{hoop,seed,feather}/<body>_{idle,walk,sit}.png` |
| **Olhos** (camada própria, Agente E) | `assets/characters/eyes/<body>_<anim>.png` (+ `<body>_idle_blink.png`) — `eyes.py`, `eyes_anchors.json`, `eyes_designs.json` |
| Shader 2D / 3D | `assets/shaders/char_palette_swap.gdshader`, `char_palette_swap_3d.gdshader` |
| Paletas e opções | `data/customization/palettes.tres`, `data/customization/options.tres` |
| Classes | `CustomizationPalettes`, `CustomizationOptions` (scripts/shared/data), `CharacterLayers`, `LayeredCharacterPreview` (scripts/client/customization) |

Estilos: masculino `spiky` (atual), `neat`, `ponytail`, `curly`, `buzz`; feminino `ponytail` (atual), `bob`, `waves`, `braid`, `buzz`.
`buzz` (raspado) não tem folha: é o próprio corpo-base, com o cabelo curtinho recolorido pela máscara B.

Todas as folhas têm o formato das folhas do Viajante: quadro 96x96, linhas S/SE/L/NE/N, idle 4 colunas, walk 8, sit 1.
Os mesmos quadros e o mesmo espelhamento (SO/O/NO = SE/L/NE espelhados) valem para todas as camadas.

Codificação dos tons (shader, `CharacterLayers.bake_image` e `compose.py`): tom `i` (0 = mais escuro) = valor 8 bits `i*40+20`.

## Pipeline (reexecutável; cada etapa pula o que já existe)

Fontes: as imagens-chave aprovadas do Viajante (mesmas escolhas do `build_sheets.py`, incluindo os idles `idle2` e as fontes do sit). Elas ficam em `$TRAVELER_WORK/traveler_<body>/` com o `picks.json`. Trabalho: `$CUSTOM_WORK/<body>/<variante>/`. Os padrões estão em `common.py`. Python: numpy, scipy, pillow.

1. `edits.py all` (Bria; `export BK=...`) — edita as imagens-chave:
   - raspado e estilo atual (só recolorido): 20 fontes;
   - outros estilos: idle + sit;
   - feminino N: também os passos.

   O cabelo é sempre pedido **verde vivo**. Nada no Viajante é verde, então o cabelo sai por cor. Depois roda a remoção de fundo.
   Para refazer uma fonte ruim, liste em `redo.json` e rode `edits.py redo` (usa outra semente e reforça "de costas").
2. `build.py all` — alinha cada edição à imagem original, pela cabeça e pelo tronco (concordância de cor). Aplica a **mesma** transformação do `build_sheets.py`: alfa binário, recorte, escala BOX para 84/83/62 px e posição pelo centro de massa. Depois:
   - **corpo-base** = quadro original; só a região do cabelo original vem da edição "raspado". A região sai da máscara exata da edição "recolorir de verde".
   - **máscaras**: a pele é separada por tom e por peça, com tom claro obrigatório para excluir mochila e luvas. Os olhos são os tons de íris cercados de pele. O raspado é o verde.
   - **cabelo**:
     - estilo atual: pixels originais, quadro a quadro;
     - outros estilos: idle e sit da própria edição. Nos passos, o cabelo do idle segue o deslocamento da cabeça medido no corpo-base, então não pisca.
     - Tudo vira rampa de cinza de 5 tons (k-means no brilho).
   - Montagem idêntica ao `build_sheets.py`: respiração no idle e `[wl, wl, bob, i, wr, wr, bob, i]` no andar.
   - As rampas medidas (padrão = Viajante atual) vão para `measured.json`.
3. `earrings.py all` — brincos desenhados em pixel art. Eles pendem da âncora do lóbulo em `anchors.json`. Essas âncoras foram tiradas olhando a máscara em ASCII (`python mask_ascii.py <body>`). Nos passos, a âncora segue a cabeça. `walk_override` cobre os passos em outro ângulo.
3b. `eyes.py` — **camada de olhos** (anime, íris de 4 tons + reflexo + cílio). Genérico: roda sobre TODA folha
   `chr_<body>_base_<anim>.png` que existir (idle, walk, sit, golpes, cast, morte...). Âncora por quadro: a de
   `tools/art/combat_anims/head_anchors.json` (A) quando houver; senão rastreia a cabeça da referência (idle,
   quadro 0; `sit` tem referência própria) pelos rótulos da máscara, direto e espelhado. Cobre o olho antigo do
   corpo-base com pele (codificada), sem tocar nas folhas do corpo. S/SE/L com olhos; NE/N sem. Últimos 2 quadros
   da morte com o olho fechado. **Rodar de novo sempre que o corpo-base mudar** (`python eyes.py --report` mostra
   a âncora e o score de cada quadro). Codificação: `(v,0,0)` = pele, `(0,v,0)` = íris, resto literal; shader
   `layer_mode 3` (`CharacterLayers.MODE_EYES`). Piscar: o cliente troca o idle por `_idle_blink` por 0,12 s a
   cada 2,5–5,5 s (`EntityVisual`, `LayeredCharacterPreview`).
3c. `fix_orientation.py` (Agente F) — corrige nas folhas prontas o idle SE, que olhava para a esquerda enquanto os passos olhavam para a direita, e os passos N femininos, que passam a usar a cabeça do idle. Detecta o lado sozinho e é idempotente. Rodar **antes** de `eyes.py`. Depois de `eyes.py`, rodar `open_bangs.py`, que abre a franja do rabo de cavalo feminino sobre o olho. Ver `docs/ajustes-personagens.md`.
4. `make_data.py` — gera `palettes.tres` (de `palettes.json`) e `options.tres`.
5. `compose.py contact|walk|compare|eyes|anims <png>` — pranchas de conferência (`eyes`: 6 cores × corpos × S/SE/L a 1x e 4x + piscar; `anims`: todas as animações com olhos). Usam a mesma regra do shader, em Python.

## Ligar no renderizador do mundo (DirectionalSprite3D / EntityVisual — dono: M)

Ordem ADENDO 2 / GDD §17.4: sombra → offhand_back → weapon_back → **corpo-base** → roupa → **olhos** → **cabelo** → **brinco** → cabeça → weapon_front → offhand_front.
Já ligado: `CharacterLayers.layer_specs` devolve `Base, [Outfit], Eyes, [Hair], [FaceAccessory]`; `EntityVisual` põe os olhos com `ORDER_EYES = 1` (cabelo 2, brinco 3, cabeça 4, armas 5/6), também sobre folhas de roupa (pele de cobertura = a do Viajante).

1. `var specs := CharacterLayers.layer_specs(appearance)` devolve, em ordem, `{name, mode, sheets{anim: path}, masks{anim: path}}`: `Base` (MODE_BASE), `Outfit` opcional, `Hair` (MODE_HAIR) e `FaceAccessory` (MODE_PLAIN).
2. **Corpo:** `setup_sheets("res://assets/characters/base/chr_<body>_base")` no lugar de `chr_traveler_<body>`.
   **Cabelo e brinco:** `add_overlay(&"Hair", specs[i].sheets, CharacterLayers.ORDER_HAIR)` e `add_overlay(&"FaceAccessory", …, CharacterLayers.ORDER_FACE)`. Chapéus do ADENDO 1 ficam acima (order maior).
3. Cor — escolha uma das opções:
   - **(a) shader:** `sprite.material_override = CharacterLayers.make_material_3d(mode, appearance)`. Sempre que o Sprite3D trocar de folha (idle/walk/sit), chame `CharacterLayers.set_sheet_3d(mat, sprite.texture, mask_da_anim)`, porque o shader lê a folha por uniform. O billboard eixo Y e o corte de alfa ficam no shader. Validado em `tests/client/test_customization.tscn` (captura `custom_3d_*.png`): as cores saem exatas.
   - **(b) CPU:** `CharacterLayers.bake_sheet(path, mode, appearance, mask_path)` devolve uma `ImageTexture` já colorida, com cache por aparência. O Sprite3D segue com o material padrão. Para isso, `add_overlay`/`setup_sheets` precisam aceitar `Texture2D` além de caminho.
4. Quando `appearance` replicada mudar: `clear_overlays()` e montar de novo. Se só a cor mudar, `CharacterLayers.update_material(mat, mode, appearance)` basta.
5. Sem personalização (NPCs), nada muda: eles continuam com as folhas inteiras.

## Servidor (dono: A/M) e cliente (main.gd)

- `TitleScreen.get_appearance()` → `{body, skin, hair_style, hair_color, eye_color, earrings}` (sanitizado).
  `play_requested(name, body, host, port)` não mudou.
- O servidor valida com `CustomizationOptions.get_default().is_valid(a)`. `sanitize(a)` corrige para o padrão. O servidor grava junto do personagem e replica em `NetEntity.appearance`, junto das chaves do ADENDO 1.

## Roupa por nacionalidade (recolor provisório)

Enquanto a região não tem folha de roupa própria (`nationality_outfits` em `data/customization/options.tres`),
a roupa do Viajante é recolorida pelas cores da região (`nationality_colors`: [tecido, detalhe]). O tecido azul vira
"tecido" e o vermelho/marrom vira "detalhe", mantendo o sombreado. Terra do Sabiá fica com as cores originais.

- Regra única em três lugares: `CharacterLayers.recolor_cloth` (CPU), `char_palette_swap.gdshader` (prévia 2D) e
  `char_palette_swap_3d.gdshader` (mundo).
- Só vale onde a máscara do corpo-base tem alfa 255. `cloth_zone.py` põe alfa 128 na zona da cabeça (rosto e mechas
  pintadas no corpo-base), exceto no tecido azul da gola. **Rodar `python3 tools/art/customization/cloth_zone.py`
  depois de qualquer etapa que regenere as máscaras.**
- Some sozinho quando o personagem usa roupa de título ou a folha da região (`outfit` diferente de `traveler`).
