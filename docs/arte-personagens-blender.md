# Arte dos personagens no Blender (pipeline 3D → pixel art)

GDD §17.0.B (novo padrão de personagem e roupa por título), §17.0.C, §6.1, §8.5, §14.3, §17.3, §17.4; contrato
`docs/contracts-city-walk.md` ADENDO 1–2. Referência de desenho: `game/assets/_reference/wardrobe/title-evolution-v1.png`.
Fontes: `game/tools/art/blender/characters/`. Trabalho e prévias: `.work/c3/`. Licenças: `game/assets/characters/LICENSES.md`.

## Resumo

- **Base pronta (CC0, Quaternius):** corpo masculino/feminino com esqueleto humanoide de 65 ossos, roupas modulares
  (Peasant, Ranger) e duas bibliotecas de animação (UAL1/UAL2) no mesmo esqueleto. Pedido do dono: "o que der para
  pegar pronto, pega e modifica".
- **Modificações nossas:** proporção do jogo (estilo atarracado calibrado pelo Samsara Saga, ver "Proporção"), roupas por título montadas com peças modulares **recoloridas por região** (cor da textura
  em cada face) + peças procedurais (capuz, zíper, bolsa, faixa, abas, casacos longos bordados, cachecol, gola, broche),
  cabelos anime procedurais, rosto e olhos em pixel art, poses corrigidas (idle relaxado, braços do andar, sentar no
  chão, morte deitando atravessada na tela).
- **Pixel art:** o Blender não pinta; cada peça sai com um **id** (pid) + profundidade + normal (material de passes).
  O pós (`chr_post.py`, mesmo método do pipeline de monstros do B3) faz cel shading em rampas de 4 tons, linha interna
  seletiva, contorno externo colorido, máscaras de personalização e separa as camadas pelo dono de cada pixel.
- **Quadro 96×96**, ~84 px de altura, 5 linhas (S, SE, L, NE, N); o motor espelha O/SO/NO.
- **Câmera de render:** ortográfica, **inclinação 35°** (parâmetro `--pitch`). Ver "Inclinação" abaixo.

## Proporção e correção facial (28/09/2026)

A referência enviada pelo usuário é o casal do Samsara Saga: silhueta compacta, cabeça expressiva, rosto curto e humano, mãos e calçados legíveis. A versão anterior foi **rejeitada pelo usuário** por parecer um alienígena: olhos laterais, nariz/queixo compridos, ombros e coxas exagerados. `preview-personagens-samsara-20260928.png` registra essa versão rejeitada, não um padrão aprovado. Não basta aumentar a cabeça de um corpo adulto nem atingir uma razão numérica de cabeças.

A revisão usa as mesmas malhas Quaternius, pesos e esqueleto. `reshape_head()` em `chr_qbody.py` esculpe a cabeça **antes** das escalas de pose, medição e adaptação das roupas/cabelos:

1. Seleciona vértices com peso de `Head > 0.5`, medidos em coordenadas de mundo da pose de repouso. Aplica a deformação ponderada pelo peso original, preservando topologia e rig.
2. Normaliza a altura do queixo ao topo (`t` de 0 a 1). Remapeia Z por interpolação linear dos pares `(0, .20), (.35, .47), (.65, .71), (1, 1)`: levanta o queixo, encurta o rosto e mantém o topo estável.
3. Multiplica X pelos fatores `(0, 1.24), (.35, 1.18), (.65, 1.06), (1, 1)`: amplia suavemente mandíbula e bochechas.
4. Define um plano facial a 14% da profundidade medida desde a frente. Conserva apenas 18% da projeção dos vértices à frente desse plano, reduzindo o nariz pontudo importado.
5. Recalcula as âncoras a partir do **queixo real** e do topo: olhos a 46%, sobrancelhas a 60%, nariz a 31%, boca a 20% da altura facial. Distância horizontal de cada olho ao centro: `0.145 * q_head["w"]`, antes `0.19`. Os olhos continuam desenhados no pós-processamento, com máscara de íris personalizável.

Os fatores atuais de pose são `(largura, comprimento, profundidade)` no espaço de cada osso, sem propagar a escala aos filhos:

| Região / ossos | Fator |
|---|---:|
| spine_01 | (1.10, 0.78, 1.08) |
| spine_02 | (1.12, 0.78, 1.10) |
| spine_03 | (1.02, 0.80, 1.04) |
| pelvis | (1.10, 0.83, 1.06) |
| neck_01 | (1.10, 0.70, 1.10) |
| clavicle_l/r | (1.04, 0.98, 1.04) |
| upperarm_l/r | (1.28, 0.56, 1.26) |
| lowerarm_l/r | (1.26, 0.55, 1.24) |
| thigh_l/r | (1.24, 0.60, 1.20) |
| calf_l/r | (1.20, 0.62, 1.18) |
| Head | (2.40, 2.40, 2.40), após esculpir |
| hand_l/r | (1.38, 1.38, 1.38) |
| foot_l/r; ball_l/r | (1.42, 1.42, 1.42); (1.30, 1.30, 1.30) |

O cotovelo em idle usa rotação de 0.18 rad no perfil chunky, antes 0.40. `TOP_TARGET` mantém topo sem cabelo em 1,78 m / 1,72 m e `HEIGHT_MUL=1.05`. `_warp_head()` ajusta a largura do cabelo a `1.04 * sz` e profundidade a `0.96 * sz`, com alturas acompanhando queixo, olhos e sobrancelhas esculpidos. A roupa Viajante mantém moletom turquesa, jeans, tênis e bolsa; Aprendiz e demais títulos conservam suas peças próprias.

### Reprodução e revisão visual

Render ortográfico a **35°** (também o padrão de `render_chr.py`), quadros **96×96**, supersampling 4×, cinco direções e pós em `chr_post.py`. Inspecionar primeiro os dois corpos vestidos em idle e caminhada, com Viajante e Aprendiz, em frente, três quartos e perfil. Ver o rosto em escala nativa e ampliado por nearest-neighbor. Não validar estética apenas por teste automático ou contagem de cabeças.

```sh
# Prévia isolada: não sobrescreve .blend nem instala sprites.
.tools/blender/blender -b --python game/tools/art/blender/characters/render_chr.py -- male --sets outfit:traveler,hair:spiky,outfit:apprentice --anims idle:8,walk:8 --pitch 35 --work .work/c3-face-review --no-blend
.tools/pyvenv/bin/python game/tools/art/blender/characters/chr_post.py male --sets outfit:traveler,hair:spiky,outfit:apprentice --work .work/c3-face-review --no-install
# Repetir com female e hair:ponytail.
# Exportação completa: salva os .blend e instala todas as camadas/animações.
bash game/tools/art/blender/characters/render_all.sh 35 "male female"
.tools/godot-4.7.2 --headless --path game --import
```

Prancha desta revisão: [rosto corrigido](preview-personagens-rosto-corrigido-20260928.png). A prancha é uma proposta implementada para avaliação, não aprovação do usuário. Histórico local anterior à alteração em `.work/c3-face-review/before/`; gerador anterior em `source-backup/chr_qbody.py` no mesmo diretório. Malhas Blender finais em `game/tools/art/blender/characters/blend/chr_male.blend` e `chr_female.blend`.

Para NPCs (N2), `props.q` continua multiplicando o estilo. A exportação desta revisão cobre personagens jogáveis; NPCs precisam de exportação própria se forem atualizados. Cosméticos e roupas por título continuam com suas camadas separadas.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `chr_lib.py` | Lado Blender: material de passes (pid por objeto **e por face**, atributo `fpid`), `Rig` (pivôs, peças, grupos de camada, âncoras 2D por quadro), primitivas (loft, cápsula, mecha, fita, caixa), redução por voto da maioria (ids uint16). Reaproveita `monsters/mon_rig.py` (B3). |
| `chr_qbase.py` | Base Quaternius: importa corpo e ações, toca ação por fase, prende pivôs aos ossos, importa peças modulares, classifica a cor da textura por face. |
| `chr_qbody.py` | Personagem sobre a base: proporção, medidas do corpo deformado, **entortamento** (warp) das peças procedurais para o corpo importado, roupas por título com peças modulares, poses por quadro. |
| `chr_body.py` | Construtores procedurais (cabelos, chapéus, brincos, armas, cascas de roupa, saias/casacos) e o corpo procedural antigo (`--base proc`). |
| `chr_anim.py` | Animações FK do corpo procedural + trava dos pés no chão. |
| `chr_npc.py` + `npcs/<id>.json` | NPCs como **configuração** (ver abaixo). |
| `render_chr.py` | Blender: renderiza animações × direções × conjuntos de camadas → `.work/c3/npz/<corpo>/<conjunto>.npz`. |
| `chr_post.py` | Pós (venv): pixel art, camadas, máscaras, rosto/olhos, folhas no formato do jogo, prévias (pranchas + GIFs), instalação. |
| `render_all.sh` | Tudo de uma vez (os dois corpos): `game/tools/art/blender/characters/render_all.sh [pitch] ["male female"] [--no-install]` |
| `face_designs.json` | Desenhos dos olhos (frente, 3/4 longe, perfil, piscar), sobrancelha e boca. |

## Como rodar

```
# jogador (render ~10 min por corpo em 12 núcleos + pós ~1 min)
game/tools/art/blender/characters/render_all.sh 35 "male female"
# um conjunto só, sem instalar (prévias em .work/c3/preview/)
.tools/blender/blender -b --python game/tools/art/blender/characters/render_chr.py -- male --sets outfit:traveler,hair:spiky --anims idle:8,walk:8 --pitch 35 --work .work/c3-preview --no-blend
.tools/pyvenv/bin/python game/tools/art/blender/characters/chr_post.py male --work .work/c3-preview --no-install
# NPC
.tools/blender/blender -b --python game/tools/art/blender/characters/render_chr.py -- npc:master_jatoba
.tools/pyvenv/bin/python game/tools/art/blender/characters/chr_post.py npc:master_jatoba
```
Depois: `.tools/godot-4.7.2 --headless --path game --import`. O pós faz backup das folhas substituídas em
`.work/c3/backup/` (uma vez).

## Conjuntos de render → camadas do jogo

Cada conjunto é uma renderização por quadro; o pós guarda só os pixels cujo **dono** é do grupo do conjunto (linhas e
contorno incluídos: a linha da franja sobre a testa é do cabelo, em tom 0 da rampa do cabelo).

| Conjunto | Grupos visíveis | Saída |
|---|---|---|
| `outfit:<id>` | corpo (cabeça/pescoço) + roupa | `traveler` → `characters/base/chr_<corpo>_base_<anim>.png` + `_mask_`; outras → `characters/outfits/chr_<corpo>_<id>_<anim>.png` + `_mask_` |
| `hair:<estilo>` | corpo + Viajante + cabelo | `characters/hair/<estilo>/<corpo>_<anim>.png` (rampa de cinza, tom i = i·40+20) |
| `ear:<id>` | corpo + brinco | `characters/face/<id>/<corpo>_<anim>.png` |
| `head:<id>` | corpo + chapéu | `equipment/head/<id>/<corpo>_<anim>.png` |
| `weapon:<id>` | corpo + Viajante + arma | `equipment/weapon/<id>/<corpo>_<anim>.png` (só idle, walk, golpe do tipo, cast, hit; oclusão pelo corpo já aplicada — a mesma folha serve de `_back`) |
| (âncoras) | — | `characters/eyes/<corpo>_<anim>.png` + `<corpo>_idle_blink.png` (olhos 2D nas âncoras projetadas; íris codificada, `MODE_EYES`) |
| (composto) | — | `characters/chr_traveler_<corpo>_<anim>.png` (corpo + olhos + cabelo padrão, cores padrão) |

**Máscara** (`_mask_`): R = tom da pele (inclui linha/contorno da pele → tom 0), B = cabelo raspado e sobrancelhas. Um quadro pode ser totalmente transparente quando aquela pose não expõe pele/cabelo; os sprites visíveis continuam sujeitos à validação de quadro não vazio.
Boca e nariz vão na folha do corpo (pele codificada); sobrancelhas no canal B (cor do cabelo).
**Roupas de título viram corpo recolorível:** `CharacterLayers.outfit_has_body()` (máscara presente) → a folha da roupa
é o corpo-base da aparência, e olhos/cabelo/brinco vão por cima iguais ao Viajante (C3 mudou `CharacterLayers.layer_specs`
e `EntityVisual.set_appearance`).

## Animações (GDD §17.3, contagem nova)

| Animação | Quadros | Fonte |
|---|---|---|
| idle | 8 | pose relaxada nossa sobre o T (as idles prontas são em base de luta) + respiração |
| walk | 8 | `Walk_Loop` (UAL1), braços refeitos (soltos, balanço pela fase das coxas) |
| attack_unarmed | 8 | `Punch_Cross` |
| attack_blade | 8 | `Sword_Regular_A` (UAL2) |
| attack_staff | 8 | `Sword_Regular_B` (UAL2) |
| cast | 8 | `Spell_Simple_Shoot` |
| hit | 4 | `Hit_Chest` |
| death | 8 | `Death01` + giro progressivo para deitar atravessado na tela (fica no último quadro; olhos fechados nos 3 últimos) |
| sit | 1 | `Sitting_Idle_Loop` adaptado para o chão (pernas esticadas) |

Duração por quadro: `DirectionalSprite3D.ANIM_FRAME_MS` / `ANIM_REF_FRAMES` (P2). Golpes com 8 quadros × 70 ms.

## Roupa por título (GDD §17.0.B, §8.5)

`TitleDef.outfit_id` (dados em `data/titles/*.tres`): sem título → `traveler`; 1º título (Facão Firme, Luz de Vaga-lume)
→ `apprentice`; ramos (Tronco de Aroeira, Garra da Onça, Guarda do Cristal, Olho do Boitatá) e o híbrido (Brasa no Facão)
→ `branch_coat`; ápice (pós-MVP) → `master_armor`. Item `leather_jerkin` (gibão) refeito no mesmo esqueleto.
Regra do servidor (já existente, mantida): cosmético de corpo > título exibido conquistado > equipamento de corpo > Viajante.

| Roupa | Peças prontas (recoloridas) | Procedurais |
|---|---|---|
| `traveler` | Peasant tronco/braços (moletom), pés (tênis, cano cortado); jeans = pernas do próprio corpo infladas | capuz, gola, zíper, cordões, bolsa carteiro + alça |
| `apprentice` | Ranger tronco (colete), braços (manga branca até o cotovelo, antebraço à mostra), braçadeiras, ombreira, calça, botas | faixa vermelha com ponta, aba branca |
| `branch_coat` | Peasant camisa/braços (mangas azuis, punho dourado), calça; botas Ranger | casaco longo aberto com bordas e bordados dourados, gola alta, cinto com borlas, broche verde |
| `master_armor` | Ranger tronco (placas), cinto, braços, braçadeiras, ombreiras (espelhada no masculino), calça, botas | casaco carmim com bordados, painéis verdes, joia âmbar, cachecol branco, luvas |
| `leather_jerkin` | Peasant camisa/braços (camiseta), tênis; jeans do corpo | gibão de couro com tiras |

Cores: famílias de 4 tons + contorno em `chr_post.py` (`TEAL`, `DENIM`, `LEATHER`, `OLIVE`, `RED`, `NAVY`, `GOLDF`, `IRON`,
`CRIM`, `JADE`...), tiradas da referência. Linha interna = tom 0 da própria rampa → cada folha fica ≤ 48 cores
(`validate_art.py`).

## Personalização (GDD §6.1)

- Pele: 6 rampas (máscara R). Cabelo: estilos masculinos `spiky`, `neat`, `ponytail`, `curly`, `buzz`; femininos
  `ponytail`, `bob`, `waves`, `braid`, `buzz` — 10 cores pelo shader (rampa de cinza). Olhos: 6 cores (íris codificada).
  Brincos `hoop`, `seed`, `feather`. Chapéus `straw_hat`, `ipe_flower_crown`. Armas `blade`, `staff`.
- Os cabelos são procedurais (mechas achatadas agrupadas em "tufos": sem linha interna dentro do tufo, a silhueta e as
  pontas desenham), construídos no espaço da cabeça procedural e **entortados** para a cabeça importada com o nível dos
  olhos casado (`chr_qbody._warp_head`). Os cabelos prontos da Quaternius (Buzzed, Long, Buns, SimpleParted, Beard)
  são realistas; ficaram para NPCs.

## NPCs = configuração

`npcs/<id>.json`: `body`, `props.q` (altura, escala da cabeça, espessura por osso — ex.: barriga do Orvalho),
`pose` (postura somada a qualquer animação: curvado, peito estufado), `parts` (biblioteca: `q` = peça modular
recolorida, `skin` = parte do corpo como pele ou roupa justa, `shirt`, `vest`, `coat`, `skirt`, `apron`, `sash`, `belt`,
`boots`, `shawl`, `neckerchief`, `pauldrons`, `bracers`, `hat_wide`, `glasses`, `beard`, `hair`, `weapon_hip`,
`staff`, `lights`, `pockets`), `colors` (rampas de pele, cabelo, olhos + famílias novas) e `anims`.
Sai uma folha inteira por animação em `assets/npcs/npc_<id>_<anim>.png` (sem camadas).

**Corpo de criança (07/10/2026):** `kind: "child"` (`blender/npcs/configs/_bodies.json`: altura 0.70, cabeça 1.08)
funciona. A causa do defeito (roupas soltas, braços em T, cabeça sumindo) era `chr_qbase.import_parts` copiar a
posição no MUNDO das peças modulares ao religá-las ao esqueleto já escalado (`arm.scale = g`); com `g` longe de 1 a
peça ficava no espaço errado do modificador Armature. Agora a relação LOCAL com o esqueleto é mantida (adultos saem
idênticos, conferido pixel a pixel no Jatobá). `chr_post.process_npc` usa os olhos pequenos (`front`/`far`/`side`)
para criança (`big_eyes` na config sobrepõe). Cabeça acima de ~1.1 deforma o rosto nas vistas de lado (olho fora da
cabeça): não aumentar.

Feitos: `master_jatoba`, `master_candeia` (Campo de Treino), `master_brisa`, `master_orvalho`, `merchant` (Anselmo).
**Fila** (mesmo formato): `boatman`, `curious_child`, `fisherman` (+ `sit`), `fruit_vendor`, `gate_guard`,
`master_citlali`, `master_ewan`, `master_guiomar`, `master_nicandro`, `master_seneb`, `master_solveig`,
`master_tsubaki`, `master_xiaoyu`, `master_zlata`.

## Inclinação da câmera de render

A câmera do jogo está a ~57° (P2). Renderizado a 55°, o rosto some sob o cabelo e o corpo encolhe (prova em
`.work/c3/pitch_cmp.png`): não dá para bater com a referência (vista quase frontal) nem com rostos anime. O sprite é
billboard com compensação de inclinação no motor, então o que importa é a leitura. Escolha: **35°** (o GDD §17.1 já
dizia "três quartos de cima, cerca de 35°"). Ajustável: `render_all.sh <pitch>`.

## Mudanças fora das pastas de arte (âncoras pequenas)

- `scripts/client/directional_sprite_3d.gd`: retirada a correção antiga de espelhamento do Viajante
  (`traveler_frame_mirrored` agora só espelha SO/O/NO) — as folhas novas saem com a mesma orientação em todos os quadros.
- `scripts/client/entity_visual.gd`: `ANIM_HIT` em `LAYER_ANIMS`; roupa com máscara vira o corpo recolorível;
  roupa 3D sem personalização monta com a aparência padrão.
- `scripts/client/customization/character_layers.gd`: `hit` nas animações; `outfit_mask_path`/`outfit_has_body`;
  `layer_specs` usa a roupa como corpo-base quando tem máscara.
- `tools/art/validate_art.py`: aceita idle 8, golpes/cast/morte 8, hit 4 (NPCs antigos continuam 4/6).
- Render final (28/09/2026): 200 folhas instaladas por corpo; 96×96 px por quadro; cinco linhas de direção; todas as animações/roupas/acessórios regenerados.
- Validação final: import Godot concluído; validate_art.py sem problemas; test_customization PASS; test_direction 132 checks PASS; test_render PASS em 1280×720 e 1920×1080 (enquadramento, altura, cinco yaws, nitidez, filtro linear vs. pixel AA, interação, grade e hover). Para a arte final detalhada, a nitidez exige mínimo de 65% de cores em blocos; os stubs simples mantêm o limite de 93%.
- Testes: `test_direction` (sem correção de espelho; golpe = quadros da folha × 70 ms), `test_customization`
  (hframes pela folha; íris ≥ 12 px), `test_render` (controle do filtro linear 1,3×), `world_flow_test`
  (roupa de título como corpo), `progression_client_test` (Facão Firme → roupa `apprentice` replicada e desenhada),
  stubs de camadas regenerados (`tests/client/make_stub_overlays.py`).

## Pendências conhecidas

- 8 linhas reais (O/SO/NO sem espelho) exigem mudar `DirectionalSprite3D` (quadro = altura/5). O render já aceita
  `--dirs8`; a bolsa e a ombreira trocam de lado no espelho.
- Idle: `ANIM_REF_FRAMES` (P2) toca os 8 quadros no ciclo de 0,8 s do idle antigo; para respiração lenta, idle 8 × 200 ms.
