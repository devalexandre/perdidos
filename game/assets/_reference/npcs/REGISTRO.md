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

## Mestre do arco e anciãos da Terra do Sabiá (30/09/2026, TITULOS-E-SKILLS.md v0.4 §3.1–3.2)

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
