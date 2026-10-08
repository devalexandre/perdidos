# Registro dos NPCs, da animação sentar e das aparências do Viajante (GDD §17.0.4 e §17.5)

- **Data:** 27/09/2026. **Ferramenta:** Bria.ai FIBO (`/v2/image/generate` e `/v2/image/edit`) + RMBG-2.0 (`/v2/image/edit/remove_background`), licença comercial.
- **Estilo:** mesmo bloco de estilo do Viajante v2 (`tools/art/character_pipeline/p_c1m.txt`), com a descrição do personagem trocada
  por completo (`tools/art/character_pipeline/npc/style_block.txt` + `npc/npcs.json`) e o mesmo prompt negativo (`neg.txt`).
- **Pipeline:** `tools/art/character_pipeline/npc_pipeline.py` (gen → dirs → walk → sit → rmbg) e `build_npc.py` (folhas 96x96,
  linhas S, SE, L, NE, N; paleta própria de 48 cores por personagem, como o Viajante). Conferência de direção:
  `heads_board.py` (cabeças ampliadas; toda linha SE/L/NE olha para a DIREITA da tela) e `picks_board.py`.

## NPCs

| NPC (id) | Nome provisório | Frente escolhida | Seed | Pasta |
|---|---|---|---|---|
| `merchant` | Mercador Anselmo | `f_6.png` | 43415 | `merchant/` |
| `master_brisa` | Mestra Brisa Ferrenha | `f_3.png` | 24293 | `master_brisa/` |
| `master_orvalho` | Mestre Orvalho | `f_3.png` | 57054 | `master_orvalho/` |
| `boatman` | Barqueiro Benedito | `f_1.png` | 32818 | `boatman/` |
| `fruit_vendor` | Dona Jandira | `f_2.png` | 38361 | `fruit_vendor/` |
| `gate_guard` | Guarda Tomé | `f_1.png` | 58484 | `gate_guard/` |
| `fisherman` | Pescador Lindolfo | `f_0.png` | 64945 | `fisherman/` |
| `curious_child` | Tico | `f_3.png` | 63122 | `curious_child/` |

Cada pasta tem `prompt.txt` (prompt + negativo exatos), `picks.json` (imagens escolhidas por direção, espelhamentos
`flip`, quadros espelhados com prefixo `!`, correção de cor de cabelo `hair_fix`) e a frente escolhida reduzida.
Direções e passos são edições da frente escolhida (seeds `seed_of(id)+100..`, `+200..` reforçada, `+300..` passos,
`+700..` passos reforçados, `+500..`/`+900..` sentar). Pranchas: `prancha_lineup_idle.png` (Viajante + 8 NPCs) e
`prancha_lineup_wl.png`.

Notas:
- A IA de edição às vezes vira o personagem para a esquerda da tela quando se pede "para a direita"; as linhas foram
  conferidas por cabeça ampliada e espelhadas quando preciso (`flip` no picks).
- Vistas de costas difíceis (Orvalho, pescador) foram obtidas editando a partir de uma vista de 3/4 de costas.
- Brisa: a edição de costas escureceu o cabelo; `hair_fix` recolore para a rampa cinza-aço da vista de frente.
- Pendente (como no Viajante): limpeza manual no Aseprite; a frente (S) de alguns NPCs é um pouco mais larga que as
  outras direções.

## Viajante: sentar e aparências (ADENDO 1 do contrato)

- `chr_traveler_<body>_sit.png`: edição das fontes aprovadas (`base_*`) para "sentado no chão de pernas cruzadas";
  escolhas em `$NPC_WORK/traveler_<body>/picks.json` (campo `sit`), paleta do idle do Viajante.
- Camadas e roupa: `tools/art/character_pipeline/build_equipment.py`. Cada uma das 20 imagens-fonte (idle, 2 passos e
  sentado por direção) é editada ("put a straw hat...", "holds a short steel machete..."), alinhada à original pelas
  pernas, passa pela MESMA transformação do `build_sheets.py` (recorte, BOX, posição — conferido: alfa idêntico) e o
  item sai por diferença de cor com vizinhança de 2 px + crescimento de região. O lado da mão da arma é conferido por
  linha e as exceções refeitas com lado explícito (`fixsides`).
- Instruções exatas: dicionário `VISUALS` em `build_equipment.py`; seed 4242 (lado corrigido: 5151).

## Mestre do arco e anciãos da Terra de Pindorama (30/09/2026, TITULOS-E-SKILLS.md v0.4 §3.1–3.2)

Mesmo pipeline e estilo dos NPCs acima (`npc_pipeline.py gen` → `dirs`/`dirs2` → `rmbg` → `build_masters.py`: folha
idle de 5 direções e walk de reserva feita do idle, como os Mestres). Descrições em `npc/npcs.json`. Os anciãos têm
rosto, postura e cabelo de idoso na descrição (rugas, cabelo/barba brancos, costas curvadas, bengala ou cajado).
`picks.json` usa `head_colors: 12` (cores reservadas para a cabeça, senão o cabelo do Taquari saía esverdeado).
Pasta de trabalho: `.work/npcs_new/<id>`.

| NPC (id) | Nome | Frente escolhida | Seed | Direções (espelhadas) |
|---|---|---|---|---|
| `master_taquari` | Mestre Taquari (arco de taquara) | `f_7.png` | 52415 | se `d_se_0`↔, e `d_e_1`↔, ne `d_ne_1`↔, n `d_n_1` |
| `elder_ze_ferreiro` | Seu Zé Ferreiro | `f_1.png` | 25562 | se `d_se_1`, e `d_e_1`, ne `d_ne_0`, n `d_n_1` |
| `elder_aninha` | Vó Aninha, a raizeira | `f_1.png` | 58779 | se `d_se_1`↔, e `d_e_1`↔, ne `d_ne_0`↔, n `d_n_0` |
| `elder_tiao` | Velho Tião do Casco | `f_1.png` | 37530 | se `d_se_1`, e `d_e_2` (reforçada), ne `d_ne_4` (reforçada), n `d_n_1` |

Notas: a vista de costas do Zé tinha sombra no chão; os pixels claros e pouco saturados das 4 últimas linhas da
linha N foram apagados. O arco do Taquari passa um pouco acima da cabeça, então a figura sai um pouco menor que
84 px (a altura inclui o arco).

## Dona Ana, a guardiã dos caminhos (06/10/2026)

- `npc_dona_ana_idle.png` / `npc_dona_ana_walk.png`: derivadas das folhas da Vó Aninha (`elder_aninha`, acima; Bria.ai,
  licença comercial), só recoloridas por `tools/art/recolor_dona_ana.py` (saia verde → vinho, lenço laranja → azul anil;
  rosto, cesto e xale iguais). Nenhuma arte nova gerada. Usadas pelas três NpcDef `dona_ana_*` (uma por cidade); a
  reserva (`fallback_sprite_base`) é a própria Vó Aninha.

## NPCs do Arco 1 (07/10/2026)

Mesmo pipeline e estilo dos NPCs do Porto (Bria.ai FIBO + RMBG-2.0, licença comercial): `npc_pipeline.py gen` →
`dirs`/`dirs2` → `rmbg` → folha idle de 5 direções + walk de reserva feita do idle (como `build_masters.py`; os quatro
ficam parados, rotina IDLE). Descrições em `tools/art/character_pipeline/npc/npcs.json`. Pasta de trabalho:
`.work/arc1-npcs/ai/<id>` (`prompt.txt`, `picks.json`, fontes e `rb_*`); prancha de comparação `.work/arc1-npcs/npcs.png`.
Alfa binarizado depois do `build` (borda do redimensionamento BOX). Nenhuma direção espelhada.

| NPC (id) | Nome | Frente escolhida | Seed | Direções (se, e, ne, n) | Opções do picks |
|---|---|---|---|---|---|
| `dona_jacinta` | Dona Jacinta, a rendeira | `f_3.png` | 37502 | `d_se_0`, `d_e_1`, `d_ne_3` (reforçada), `d_n_0` | `head_colors 12`, `accent_colors 8` |
| `firmino_insone` | Firmino, o insone | `f_4.png` | 41414 | `d_se_1`, `d_e_1`, `d_ne_3` (reforçada), `d_n_2` (reforçada) | + `hair_fix` (SE/E escureceram o cabelo) |
| `dona_celeste` | Dona Celeste, mãe do Tico | `f_6.png` | 31337 | `d_se_0`, `d_e_0`, `d_ne_1`, `d_n_3` (reforçada) | `accent_colors 4`, `shadow_fix` (sombra de chão da IA) |
| `curupira` | Curupira de dia (menino) | `f_1.png` | 36113 | `d_se_1`, `d_e_1`, `d_ne_3` (reforçada), `d_n_0` | `head_colors 12`, `accent_colors 8` |

Notas: Firmino teve uma 1ª rodada descartada (pele cinza, lia como zumbi; `v1/`); Dona Celeste teve duas rodadas
descartadas (pareciam crianças; `v1/`, `v2/`). `build_npc.py` ganhou `accent_colors` (cores reservadas aos pixels
muito saturados — a chama do lampião sumia — com refinamento k-means a partir da mediana, que devolveu o lilás da
blusa) e `shadow_fix`. O Curupira também tem versão 3D (`tools/art/blender/npcs/configs/curupira.json`, corpo de
criança), mantida só como comparação: o estilo da IA casa com o Tico e os demais NPCs do Porto.

## Pet Harpia (companheira do título Gavião-Real) — 2D, 08/10/2026 (aguardando aprovação; ainda não instalada)

- **Ferramenta:** Bria.ai (`/v2/image/generate` + `/v2/image/edit`), licença comercial. Referências do dono
  (`.work/harpy/ref/`) usadas só como direção de pose/clima; nenhuma arte copiada.
- **Base escolhida pelo dono:** `.work/harpy/pet_h/ai/s_5.png` (harpia humanoide chibi cinza/branca, tiara dourada,
  couraça de penas com V dourado, asas ardósia com pontas brancas, pernas de ave). Prompt em `p_slate.txt`, negativo em
  `neg.txt` (inclui "nude, cleavage, bikini, sexy..." — sem sensualização), seed 34005.
- **Direções e poses-chave:** edições da base (`jobs1.json`, `jobs2.json`; seeds 34500+, 34700+, 34800+): SE `d_se_0`,
  E `d_e_1`, NE `d_ne_2` espelhada, N `d_n_2`; garras `k_claw_*`; magia `k_cast_*`.
- **Quadros:** `.work/harpy/pet_h/build/build_pet.py` — asas giradas no ombro + quique (pairar 16, andar 8, planar 8),
  olhar em volta 12 (vistas vizinhas), ataque 10 (pose de garras), magia 8 (+ brilho). Redução: paleta única de 20 cores
  (k-means nas 5 vistas + dourado/âmbar fixos), mediana, voto por bloco, limpeza de pixel solto e contorno de 1 px.
- Descartes (paleta vermelha e outros candidatos, versão ave): `.work/harpy/pet_descartes/`, `.work/harpy/pet_ave_old/`.

## Pets 2D: Guará e Lume (08/10/2026) — AGUARDANDO APROVAÇÃO (não instalados)

Companheiros de título com folhas 2D próprias (regra do dono: pet sempre 2D, muitos quadros, vida com o dono parado),
no lugar das folhas de monstro do Blender (`maned_wolf` s1, `enchanted_firefly` s1). Poses-chave: **Bria.ai** (FIBO
`/v2/image/generate` + `/v2/image/edit`, licença comercial, mesmo uso dos NPCs acima). Quadros intermediários: rig 2D por
partes em alta resolução (`.work/pets2d/tools/rig2d.py`), redução por bloco com paleta fixa por bicho (14–15 cores,
alfa binário, contorno de 1 px colorido, pixels soltos limpos). Pasta: `.work/pets2d/` (prancha `pets.png`, GIFs em
`guara/` e `lume/`).

| Pet | Prompt / negativo | Seeds | Chaves escolhidas | Folhas (stage) |
|---|---|---|---|---|
| Guará (`pindorama_companion_guara`) | `.work/pets2d/guara/ai/prompt2.txt` / `neg.txt` | 8201 (base `g_6`) | `guara/build/rig.json` (direções por edição `jobs_dirs`, `jobs_r`, `jobs_q`; poses `jobs_k`, `jobs_b`) | `guara/build/out/pet_guara_{idle 16, walk 10, attack 12, cast 12, life_sit 24, life_lie 28, life_scratch 22, life_sniff 16, life_wag 12}.png` |
| Lume (`pindorama_companion_lume`) | `.work/pets2d/lume/ai/prompt.txt` / `neg.txt` | 9101 (base `f_1`) | `lume/build/rig.json` (direções por edição `jobs_d`) | `lume/build/out/pet_lume_{idle 16, walk 10, attack 12, cast 12, life_spiral 16, life_split 16, life_pulse 16, life_orbit 20}.png` |

O enxame da Lume (6 vaga-lumes de 6×5 px) é desenhado à mão em px finais pelo `build_lume.py` (sem IA). NE das poses
sentar/deitar/coçar do Guará usa a chave de costas (N); o golpe e o uivo em NE saem do rig da chave em pé.
