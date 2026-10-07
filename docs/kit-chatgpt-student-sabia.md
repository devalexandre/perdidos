# Kit ChatGPT — roupa `student_sabia` (uniforme escolar da Terra do Sabiá)

28/09/2026. Este kit substitui a folha do Novice do Ragnarok. **Use só as nossas pranchas-guia**: elas vêm do nosso manequim no Blender (GDD §0 regra 5; `docs/briefing-sprites-personagem.md` §0).

## O que tem no kit

| O quê | Onde |
|---|---|
| Pranchas-guia: 4 partes por corpo | `docs/guias/student_sabia/<corpo>_<parte>.png` |
| Origem das pranchas | `docs/guias/student_sabia/ORIGEM.md` |
| Importador (imagem devolvida → folhas do jogo) | `game/tools/art/import_ai_sheet.py` |
| Grade e silhuetas que o importador usa | `game/tools/art/ai_guides/<corpo>_layout.json`, `<corpo>_masks.npz` |

As partes (as mesmas para `male` e `female`):

| Parte | Arquivo | Conteúdo | Tamanho |
|---|---|---|---|
| 1 | `<corpo>_p1_parado.png` | parado (4) + sentar (1) | 1536 × 1024 (deitada) |
| 2 | `<corpo>_p2_andar.png` | andar (8) | 1536 × 1024 (deitada) |
| 3 | `<corpo>_p3_combate.png` | ataque (6) em cima, conjurar (6) embaixo | 1024 × 1536 (em pé) |
| 4 | `<corpo>_p4_dano.png` | dano (3) + caído (5) | 1536 × 1024 (deitada) |

Em cada bloco, as linhas são as direções, de cima para baixo: **S** (frente), **SE**, **L** (perfil, olhando para a direita), **NE**, **N** (costas). As colunas são os quadros da animação.

Os corpos não têm cabeça. A cruz vermelha marca o pescoço, onde a cabeça do jogo encaixa. Cinza claro é o braço ou a perna do lado de perto; cinza escuro é o lado de longe. As linhas escuras dentro da silhueta são os ossos: ajudam a IA a ver a pose.

Foram 4 partes, e não 2 ou 3, para cada figura ter uma célula grande (cerca de 170 × 190 px). Com 12 colunas numa só imagem, cada figura ficaria com uns 80 px, e a IA perde a pose.

## Passo a passo

1. Abra uma conversa **nova** no ChatGPT (com geração de imagem). Use uma conversa por corpo, porque assim as roupas saem iguais nas 4 partes.
2. Anexe a prancha `docs/guias/student_sabia/male_p1_parado.png`.
3. Cole o **prompt do corpo** (abaixo, masculino ou feminino), sem mudar nada.
4. Peça no mesmo tamanho da prancha:
   - partes 1, 2 e 4: deitada, 1536 × 1024;
   - parte 3: em pé, 1024 × 1536.

   Se o ChatGPT perguntar, responda "same size and layout as the attached sheet".
5. Confira a imagem antes de salvar:
   - mesma grade, com 5 linhas e o mesmo número de colunas;
   - uma figura em cada célula;
   - **nenhuma cabeça**;
   - as figuras viradas como no guia (a linha L de perfil, a N de costas);
   - as mesmas cores em todos os quadros.

   Se algo falhar, use o **prompt de correção** na mesma conversa. Se falhar de novo, comece de novo.
6. Salve com o nome certo: `game/downloads/sprits/student_sabia/<corpo>_<parte>.png`, por exemplo `game/downloads/sprits/student_sabia/male_p1_parado.png`. A pasta `game/downloads/` fica fora do jogo, do git e do Docker.
7. Na **mesma conversa**, anexe a próxima parte (`male_p2_andar.png`) e cole o mesmo prompt. Faça isso até a parte 4. Depois repita tudo para `female`, numa conversa nova.
8. Confira cada parte assim que salvar. Na pasta `game/`:

   ```
   python3 tools/art/import_ai_sheet.py male student_sabia downloads/sprits/student_sabia/male_p2_andar.png --check
   ```

   O comando imprime o encaixe com a guia (IoU; bom a partir de ~0,75). Ele também grava os quadros já reduzidos para 96 × 96 em `.work/import_student_sabia/check_male_p2_andar.png`, na raiz do projeto. Se recusar, siga a mensagem.
9. Com as 4 partes do corpo prontas, importe primeiro numa pasta de teste e veja as prévias:

   ```
   python3 tools/art/import_ai_sheet.py male student_sabia downloads/sprits/student_sabia/male_p*.png \
       --out ../.work/student_sabia_try --work ../.work/student_sabia_try/work --preview
   ```

   Abra `../.work/student_sabia_try/work/contact_male.png` e os `preview_male_*.gif`.
10. Se as prévias estiverem boas, peça a um agente para instalar. Ver "Instalar no jogo", abaixo.
11. Preencha o `ORIGEM.md` da entrega: ChatGPT, data, o prompt deste kit e, como imagens de entrada, só as pranchas desta pasta.

## Prompt do corpo — masculino (colar exatamente)

```
The attached image is OUR OWN pose-guide sheet for a 2D game sprite sheet: a grid of cells, 5 rows (directions: front, front-right, right profile, back-right, back) and several columns (animation frames). Each cell has one grey HEADLESS mannequin.

Redraw EVERY cell as a finished pixel-art character body wearing the outfit below. Keep EXACTLY: the same image size, the same grid, the same number of rows and columns, the same cell positions, and in each cell the same pose, limb positions, facing direction, position and size as the mannequin. One figure per cell. Do not add, remove, merge, mirror or reorder frames. Do not draw a head.

Body: chunky chibi anime BOY, about 3 heads tall in total, broad shoulders, short thick limbs, big rounded hands, chunky sneakers. The body is drawn WITHOUT HEAD: it ends at the neck/collar where the red cross is. Nothing above the collar: no head, no face, no hair, no hat. Light grey limbs are the near side, dark grey limbs the far side.

Outfit "student_sabia" (Brazilian-inspired school uniform): white short-sleeve t-shirt with a green collar trim and yellow trim on the sleeve hems; navy-blue knee-length shorts; white sneakers with green details; bare arms and lower legs with warm light skin; a small green school backpack on the back with yellow straps (seen behind the shoulders from the front, whole backpack from the back). No logos, no text, no flags, no symbols.

Style: hand-placed 2D pixel art RPG sprite, crisp square pixels, no anti-aliasing, no gradients, no blur, 3-4 flat tones per material, dark COLORED outline (dark navy, dark green, dark brown — never pure black), light from the top-left. Same colors, same proportions and same outfit details in every frame, so it animates without flicker.

Remove all guide marks: the red crosses, the grey bone lines, the text labels and the cell borders. Background: plain flat white everywhere, including the gaps between cells.
```

## Prompt do corpo — feminino (colar exatamente)

```
The attached image is OUR OWN pose-guide sheet for a 2D game sprite sheet: a grid of cells, 5 rows (directions: front, front-right, right profile, back-right, back) and several columns (animation frames). Each cell has one grey HEADLESS mannequin.

Redraw EVERY cell as a finished pixel-art character body wearing the outfit below. Keep EXACTLY: the same image size, the same grid, the same number of rows and columns, the same cell positions, and in each cell the same pose, limb positions, facing direction, position and size as the mannequin. One figure per cell. Do not add, remove, merge, mirror or reorder frames. Do not draw a head.

Body: chunky chibi anime GIRL, about 3 heads tall in total, short thick limbs, big rounded hands, chunky sneakers. The body is drawn WITHOUT HEAD: it ends at the neck/collar where the red cross is. Nothing above the collar: no head, no face, no hair, no hat. Light grey limbs are the near side, dark grey limbs the far side.

Outfit "student_sabia" (Brazilian-inspired school uniform): white short-sleeve t-shirt with a green collar trim and yellow trim on the sleeve hems; navy-blue knee-length shorts; white sneakers with green details; bare arms and lower legs with warm light skin; a small green school backpack on the back with yellow straps (seen behind the shoulders from the front, whole backpack from the back). No logos, no text, no flags, no symbols.

Style: hand-placed 2D pixel art RPG sprite, crisp square pixels, no anti-aliasing, no gradients, no blur, 3-4 flat tones per material, dark COLORED outline (dark navy, dark green, dark brown — never pure black), light from the top-left. Same colors, same proportions and same outfit details in every frame, so it animates without flicker.

Remove all guide marks: the red crosses, the grey bone lines, the text labels and the cell borders. Background: plain flat white everywhere, including the gaps between cells.
```

O prompt está em inglês porque o gerador de imagem segue melhor as instruções de grade e de pose em inglês. A tradução está abaixo, só para conferência.

> A imagem anexa é a NOSSA prancha-guia de pose: 5 linhas (frente, frente-direita, perfil direito, costas-direita, costas) e colunas de quadros, com um manequim cinza sem cabeça em cada célula. Redesenhe todas as células como corpo em pixel art com a roupa abaixo, mantendo exatamente o tamanho, a grade, as posições, a pose, a direção e o tamanho de cada manequim. Uma figura por célula, sem cabeça (o corpo acaba na gola, na cruz vermelha). Roupa: camiseta branca de manga curta com gola verde e barra amarela na manga, bermuda azul-marinho até o joelho, tênis branco com detalhes verdes e mochila verde pequena com alças amarelas. Nada de logos, texto, bandeiras ou símbolos. Estilo: pixel art de pixels quadrados, sem suavização, 3–4 tons por material, contorno escuro colorido (nunca preto puro) e luz de cima-esquerda. Mesmas cores em todos os quadros. Tire as marcas da guia. Fundo branco liso.

## Prompt de correção (mesma conversa, se a primeira saída falhar)

```
Not usable yet. Redo it on the SAME attached guide sheet: keep exactly 5 rows and the same number of columns, one figure per cell at the mannequin's position and size, with the mannequin's exact pose and facing direction (row 3 is a right-side profile, row 5 is seen from the back). NO head at all — stop at the collar. Same outfit and colors in every cell. Plain white background, no guide marks.
```

## O que o importador faz

`game/tools/art/import_ai_sheet.py <corpo> <outfit_id> <imagens...>`

1. **Fundo.** Se a imagem tiver transparência, usa o alfa. Se não, pega a cor da borda da prancha e remove, a partir das bordas de cada célula, tudo o que estiver ligado a ela. O branco da camiseta, cercado de contorno, fica.
2. **Fatia pela grade** da prancha-guia, aceitando outra resolução (a imagem é redimensionada para a da guia) e um deslocamento global de até ±48 px. Cada célula ainda tolera a figura passar um pouco da borda. Rótulos e rabiscos soltos são descartados.
3. **Reduz cada quadro para 96 × 96.** Usa uma escala só por prancha, para o tamanho não "ferver" entre quadros. Depois vem uma paleta única por corpo e roupa (32 cores, sem pontilhado) e um contorno colorido de 1 px.
4. **Alinha os pés.**
   - Em pé (parado, andar, ataque, conjurar, dano): a base da figura vai para a linha do chão (y = 94), sempre a mesma. O x vem do melhor encaixe com a silhueta da guia.
   - Sentar e caído: seguem a guia.
5. **Pescoço.** Procura o topo da gola perto do pescoço da guia. Se um braço erguido ou o corpo deitado cobrir o pescoço, usa o da guia, porque a figura já está encaixada nela. O resultado vai para `chr_<outfit>_anchors.json` no formato do jogo, o mesmo de `tools/art/combat_anims/head_anchors.json`: `[corpo][anim][linha S,SE,E,NE,N][coluna] = {dx, dy, mirror_idle, key, fit}`, com (dx, dy) relativo ao quadro 0 do idle da mesma linha. `_neck_idle0[corpo][linha]` guarda esse ponto absoluto.
6. **Escreve** `assets/characters/outfits/chr_<corpo>_<outfit>_<anim>.png`, com as linhas S, SE, E, NE, N e quadros de 96 × 96.
7. **Recusa com mensagem clara.** Os casos são: parte faltando; quadro vazio ou faltando (ex.: `p2_andar: quadro walk SE 4 vazio ou faltando`); figuras que não seguem a guia (IoU mediano < 0,65); cabeça desenhada. Quando recusa, **nada** é escrito e a saída tem código 2.

### Adaptações: guia → o que o jogo lê

O jogo manda (`EntityVisual`, `DirectionalSprite3D`, `CharacterLayers.ANIMS`, `tools/art/validate_art.py`):

| Guia | Folha do jogo | Por quê |
|---|---|---|
| parado 4 | `idle` 4 | igual |
| andar 8 | `walk` 8 | igual |
| sentar 1 | `sit` 1 | igual |
| ataque 6 | `attack_unarmed` 6 | com arma, o jogo cai no `attack_unarmed` quando falta `attack_<arma>` |
| conjurar 6 | `cast` 6 | igual |
| dano 3 | `hit` **4** (quadros 1, 2, 3, 2) | o validador aceita 2 ou 4 quadros; o 4º volta suave para o parado |
| caído 5 | `death` **6** (repete o último) | o jogo usa 6 e segura o último quadro da morte |
| linha "L" | 3ª linha (`E`) | o jogo espelha SE/L/NE para SO/O/NO |

## Instalar no jogo — o que falta

Hoje o jogo desenha a cabeça **dentro** da folha do corpo: é o corpo-base com máscara. Olhos e cabelo são camadas presas à posição da cabeça do corpo-base, quadro a quadro. Ainda não existe camada de cabeça encaixada pela âncora do pescoço. Por isso, uma folha de corpo sem cabeça instalada sozinha deixaria o personagem sem rosto.

Há dois caminhos:

- **Recomendado:** ligar no `EntityVisual`/`CharacterLayers` uma camada de cabeça (rosto, olhos e cabelo) posicionada pelo `chr_<outfit>_anchors.json`. É o formato do briefing §1, e as folhas deste importador já saem prontas para ele.
- **Provisório:** `--compose-head` cola a cabeça raspada do corpo-base em cada quadro e escreve a máscara `chr_<corpo>_<outfit>_mask_<anim>.png`. Assim a roupa vira corpo recolorível (`CharacterLayers.outfit_has_body`). Mas as poses e proporções do corpo-base (arte antiga, feita por IA) não batem com as do nosso manequim. No teste, o desencontro pescoço × cabeça ficou em média de ~7 px no parado e no andar, e de 30+ px na queda, porque a morte do corpo-base termina ajoelhada. Sem folha de `hit` no corpo-base, o dano fica de fora. Esse caminho só serve para um teste visual.

Depois de instalar:

1. Preencher `nationality_outfits = {&"sabia": &"student_sabia"}` em `game/data/customization/options.tres`.
2. Rodar `game/tests/world/run_world_test.sh`, o teste de personalização e `make test`.
3. Fazer a captura no cliente real, no ponto de nascimento.

## Refazer as guias (se o manequim mudar)

Na raiz do projeto:

```
.tools/blender/blender -b --python game/tools/art/ai_guides/render_guides.py -- male   --out .work/guides_sabia/render
.tools/blender/blender -b --python game/tools/art/ai_guides/render_guides.py -- female --out .work/guides_sabia/render
cd game && python3 tools/art/ai_guides/make_ai_guides.py ../.work/guides_sabia/render ../docs/guias/student_sabia \
    --fake ../.work/guides_sabia/fake_return
python3 tools/art/ai_guides/test_import.py ../.work/guides_sabia/fake_return ../.work/guides_sabia/import_test
```

`make_ai_guides.py` regrava o `layout.json` e o `masks.npz`. Uma prancha antiga, gerada com outra grade, não deve ser importada depois disso. `test_import.py` é o teste de ponta a ponta com uma devolução falsa: as silhuetas pintadas com as cores do uniforme, deslocadas (+9, −7) e em outra resolução.
