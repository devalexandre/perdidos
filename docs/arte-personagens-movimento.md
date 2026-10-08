# Movimento do personagem: auditoria e plano (08/10/2026)

Referência do dono: Samsara Saga, "Player trading". Lá o personagem também é um sprite 2D num mundo 3D. A fluidez
vem de quatro coisas:

1. virar passando pelas direções do meio;
2. deslocamento e câmera suaves a 60 fps;
3. sombra real do sprite;
4. mundo sempre se mexendo.

O estilo continua o mesmo, pixel art chibi de Ragnarok. O que muda são os quadros e as transições.

## Auditoria das folhas

Para cada folha, "Distintos" conta os desenhos realmente diferentes por linha (quadros idênticos não contam). A conta
foi feita no corpo-base masculino; as outras folhas estão indicadas.

| Animação | Quadros (distintos) | Duração | Onde salta | O que mais ajuda |
|---|---|---|---|---|
| **walk** (Viajante, corpo-base, roupas) | 8 (**4**: cada pose repete 2×); composto 4–6 | ciclo = 2 células = 400 ms, ou seja, 4 poses × 100 ms (10 fps nas pernas) | **virada** (pulava direto, 180° num quadro); **começar** (saía do idle direto para o quadro 0, passada aberta, com o balanço subindo 1 px de uma vez); **parar** (corte seco para o idle); **novo clique** logo depois de chegar (o ciclo recomeçava do 0) | código (feito, abaixo); arte: desenhar os 4 intermediários das pernas (plano abaixo) |
| idle | 12 (7) | 1,4 s | nenhum grave; ao sair do golpe ou do cast volta ao quadro 0 do idle | ok |
| cast | 16 (14–15) | 0,9 s, ou a carga da skill | cast→idle corta (a liberação estica e recua, o que já ajuda) | ok; no futuro, 2 quadros de "baixar os braços" |
| golpes | 12 (7–8) | 0,42 s (arco 0,48 s); impacto em 140 ms | golpe→idle corta no último quadro (o avanço e o recuo do lunge disfarçam) | ok; no futuro, 2 quadros de recuperação desenhados |
| death | 6 (3) | 6 × 150 ms, segura o último | 3 desenhos: a queda "pisca" | 2–3 intermediários na queda (baixo custo, uma folha por corpo e camada) |
| hit | sem folha (Viajante) | tranco procedural de 0,24 s + flash | ok | — |
| sit | 1 | — | sentar e levantar trocam a pose na hora | 3 quadros de transição (agachar) seriam o próximo passo de arte |
| NPCs (28) | idle 4, walk 8 (**2–4 distintos**) | igual ao Viajante | NPC que anda "patina" com 2 poses | só para NPCs que andam: redesenhar o andar, ou ao menos 4 poses |
| monstros (Blender, 222 folhas) | idle 8, walk 8 (5–8), attack 8, hit 4, death 8 | ANIM_FRAME_MS / REF | a virada pulava (agora suave, pelo mesmo código) | ok |
| pets 2D | idle 16, walk 8–10, vida 12–28 | PET_FRAME_MS | ok | ok |

### Top 5 em ganho por custo

1. **Virada pelos setores do meio** (código, custo baixo, vale para tudo, de Viajante a monstros). **Feito.**
2. **Começar e parar de andar** (código): a partida no quadro de passagem com o balanço entrando suave, o
   assentar ao parar, e o ciclo que continua entre cliques. **Feito.**
3. **Tranco de rede e relógio** (código): quando um caminho novo chega atrasado, a posição pulava até 0,33 m (medido
   na inversão de 180°). O relógio também pulava ao trocar a amostra de ping. **Feito**: o visual absorve a
   diferença e o offset do relógio desliza.
4. **Andar com 8 desenhos distintos em vez de 4** (arte, custo médio): é onde quadros novos realmente aparecem, nas
   pernas. Ver o plano abaixo.
5. **Sentar e levantar com 3 quadros, e a morte com 2–3 intermediários** (arte, custo baixo a médio). As folhas
   são poucas por camada.

A câmera já seguia de forma suave e contínua (`ClientView._update_camera`, exponencial de 12/s, render nativo) e não
precisou de mudança: o atraso é constante, ~0,08 s, e não há passo discreto.

## O que foi implementado (código)

- **`game/scripts/client/directional_sprite_3d.gd`**
  - **Virada suave.** O setor alvo vem de `compute_sector`. Se a diferença for de 1 setor (incluindo a câmera
    girando), muda na hora. Acima disso, o sprite anda um setor por vez, `turn_step_ms` cada (padrão
    `TURN_STEP_MS = 55`; 0 desliga), pelo lado mais curto. No empate de 180°, passa pelo lado que mostra mais a frente
    (E → SE → S → SW → W). Durante golpe ou cast a virada anda 2× mais rápido. No primeiro quadro, e ao voltar à
    tela, o sprite entra direto na direção certa.
  - **Só visual:** `facing_yaw`, a rede e a lógica não mudam. `get_sector()` devolve o setor exibido;
    `get_target_sector()` e `is_turning()` são novos.
  - **Começar a andar:** o ciclo começa em `WALK_START_PHASE = 0,25`, o quadro de passagem com as pernas juntas, o
    mais parecido com o idle. O balanço e o achatamento do passo entram em `WALK_EASE_IN_SEC = 0,12 s`.
  - **Novo clique:** voltar a andar até `WALK_RESUME_SEC = 0,35 s` depois de parar continua o ciclo de onde parou,
    sem voltar ao quadro 0. Andando sem parar, o ciclo já não reiniciava.
  - **Parar:** assenta em `STOP_SETTLE_SEC = 0,16 s`, achatando um pouco e voltando com amplitude
    `step_squash × 1,6`. Fica de fora em quem não tem passo (perfis BAKED, HOPPER e FLYER).
  - **Velocidade:** o andar continua com `walk_cycle_ms` para o ciclo inteiro, dividido pelos quadros da folha. Uma
    folha de 12 ou 16 quadros toca a mesma passada sem mudar nada.
- **`game/scripts/shared/entities/net_entity.gd`**
  - **Correção visual.** Quando chega um caminho novo cuja posição no instante atual não bate com a que estava na
    tela, o nó `Visual` (sprite, nome, sombra) fica deslocado pela diferença e a desfaz exponencialmente em ~60 ms
    (`VISUAL_CORRECTION_SHARPNESS = 16`). Isso acontece quando o caminho chegou depois do instante de início (lag) ou
    quando a inversão chegou depois do passo em andamento.
  - **O que não muda:** a posição lógica, a câmera e o clique seguem o caminho exato, sem atraso de controle.
  - **Teleporte:** acima de 1,25 célula (teleporte, banco, renascer) salta direto.
- **`game/scripts/shared/grid/net_clock.gd`**
  - **Offset do relógio deslizando.** Uma amostra de ping melhor muda o offset; antes ele saltava alguns ms, o que
    dava um tranco de alguns px em tudo que anda. Agora o offset em uso desliza até o novo a 5% (50 ms por segundo) e
    o tempo nunca volta. O primeiro sync, ou diferenças acima de 250 ms, entram na hora.
- **Testes**
  - `tests/client/test_direction.gd`: `_test_smooth_turn` e `_test_walk_continuity`.
  - `tests/grid/test_grid.gd`: o offset desliza.
  - `tests/client/test_ui.gd`: a checagem da ordem das camadas desliga a virada suave (ela testa a ordem por setor,
    não a virada).

## Arte do andar: plano original (o piloto da seção seguinte substitui o passo 1 nos corpos-base)

O pipeline de deformação por partes (`game/tools/art/character_pipeline/rollout.py`, `docs/animacao-quadros-viajante.md`)
deforma **um** desenho por vez, mexendo em respiração, cabelo, barra e braços. Ele **não cria pose nova de perna**. O
andar atual tem 4 desenhos, cada um repetido 2×. Gerar 12 quadros por deformação daria 4 poses seguradas 3× com o
cabelo balançando: as pernas, que são o que se vê no andar, continuariam a 10 fps. Por isso **não gerei**. O pipeline
Blender (C3) renderiza andar com quantos quadros quiser, mas é outro estilo, que o dono não aprovou para o Viajante.

**Passo a passo recomendado:** 8 desenhos distintos no mesmo ciclo de 400 ms.

1. **Desenhar 4 intermediários de perna por direção** (S, SE, E, NE, N), no corpo-base masculino e no feminino.
   - Entram entre passada e passagem (contato → **descida** → passagem → **subida** → contato).
   - No 3/4 e no lado: o pé de trás sai do chão, o joelho da frente dobra e a perna de trás estica.
   - Na frente e nas costas: o joelho sobe e o ombro desce do lado do apoio.
   - Use os quadros atuais como chave e desenhe à mão ou com IA guiada (img2img com a pose de perna como guia), com a
     mesma paleta e o mesmo contorno. Os quadros pares atuais ficam como estão.
   - Custo: 5 direções × 4 quadros × 2 corpos = **40 desenhos de perna**.
2. **Recortar a máscara** (`_mask`) de cada quadro novo pelo mesmo processo das folhas base (canal B, cabelo
   raspado). É mecânico, a partir do desenho.
3. **Rodar as camadas que dependem da perna.** Calças e saias das 40 folhas de roupa de título (80 com as máscaras)
   pedem os mesmos 4 intermediários por roupa: é a maior parte do custo. Roupas que são só tronco ou capa podem
   copiar o quadro vizinho e passar pela deformação de barra (`L_HEMX`) do `rollout.py`.
4. **Camadas acima da cintura** (cabelo, olhos, brincos, chapéus, armas): entram no quadro novo pelo mesmo plano de
   deformação do quadro vizinho (`rollout.py --phase=body` e `--phase=equip`). O `rollout.py` precisa de um modo
   `walk8`, que copia o quadro par e aplica a fase de cabelo e barra do quadro ímpar (~1 h de código).
5. **Instalar e testar** com `.work/char-frames-pilot/phase_test.sh` e capturar com o roteiro desta tarefa.
   - O cliente não muda nada: a contagem da folha continua 8, agora com 8 desenhos distintos, e `walk_cycle_ms`
     mantém a passada.
   - Para ir a 12 quadros (6 desenhos por passo), também não muda nada: `get_frame_sec` divide `walk_cycle_ms`
     pelos quadros. Só as folhas e o `_test_sprite_feet_at_origin` (que hoje espera 8) acompanham.

**Custo estimado:**

- corpo-base e máscaras: 40 desenhos + revisão, 1–2 dias com IA guiada;
- roupas de título: 4 intermediários × 5 direções × ~20 roupas com perna própria, de 2 a 4 dias, ou em lotes por
  título;
- camadas de cima: automático depois do modo `walk8` (meio dia).

Comece pelo Viajante (corpo-base mais a roupa `traveler`) e confira no cliente real antes de passar às roupas.

## Andar com 8 desenhos (corpos-base e roupas de título, 08/10/2026)

**Estado:** piloto nos corpos-base aprovado pelo dono em 08/10. Estendido no mesmo dia às 32 roupas de título
(16 títulos × 2 corpos) e às máscaras. As 4 roupas de equipamento (`apprentice`, `branch_coat`, `leather_jerkin`,
`master_armor`) já tinham 8 quadros próprios e ficaram de fora.

**Folhas:** `game/assets/characters/base/chr_{male,female}_base_walk.png` e `chr_*_base_mask_walk.png`. Continuam
com 8 colunas × 5 linhas e 400 ms de ciclo (`walk_cycle_ms`), mas agora são 8 desenhos distintos por linha em vez
de 4. O cliente e os testes não mudaram.

**Gerador (versionado):** `game/tools/art/character_pipeline/walk8_legs.py`.

- **Linha de comando:** `walk8_legs.py [--out DIR] [--force] [--debug DIR] <folha_walk.png> ...`. A máscara é achada
  pelo nome (`_mask_walk`). Sem `--out`, sobrescreve no lugar.
- **Proteção:** a folha gerada leva o texto PNG `walk8=1`. Folhas já marcadas, ou que não seguem o padrão
  A A B C D D B C, são puladas, a menos que se passe `--force`.
- **No `rollout.py`:** as fases `body` e `outfits` chamam `walk8_legs.process_arrays` logo depois de gerar o walk de
  4 poses (movimento secundário). O rollout não grava mais o andar de 4 poses. Conferido: o rollout gera exatamente
  as mesmas folhas instaladas.

### Ordem das colunas

| Coluna | Antes | Agora |
|---|---|---|
| 0 | A (passada) | A, contato |
| 1 | A | corpo de A; pernas de A fechando ~½ rumo à passagem; calcanhar de trás sai 1 px (no lado e nas costas) |
| 2 | B (passagem alta) | B |
| 3 | C | corpo de C; pernas de D abrindo ~½; pé da frente no ar (2 px) |
| 4 | D (passada) | D, contato |
| 5 | D | corpo de D; pernas de D fechando ~½ |
| 6 | B | corpo de B; pernas de C esticadas 1 px até o quadril de B (outra passagem) |
| 7 | C | corpo de C; pernas de A abrindo ~½; pé da frente no ar |

- `WALK_START_PHASE = 0,25` continua caindo na coluna 2 (passagem).
- O balanço que já estava desenhado (A e D embaixo, B em cima, C no meio) foi mantido.

### Por que o corpo de cima é o da própria coluna

Cabelo, olhos, brincos, chapéus, armas e o balanço do cabelo do `rollout.py` seguem a coluna. Com o mesmo tronco em
cada coluna, todas essas camadas continuam alinhadas sem mexer em nenhuma outra folha. Medido: nenhum pixel muda
acima da cintura (y ≥ 64–79, conforme a linha).

Um bob extra de 1 px nas colunas 1 e 5 obrigaria a deslocar as mesmas colunas em todas as camadas de cima e também
nas roupas de título, porque o cabelo fica por cima delas. Por isso ficou de fora do piloto.

### Técnica (deformação por partes)

- **Zona das pernas:** tudo abaixo do quadril (3 px acima da forquilha da passagem B, levado às outras poses pelo
  encaixe do tronco) que chega ao chão. As mãos ficam de fora pela largura das coxas.
- **Separação das pernas:** k-linhas (2 retas, x = a + b·y). O pé que passa por baixo da outra perna, na vista de
  frente, volta para a perna certa.
- **Cada perna é um osso com rampa:** deslocamento (dx, dy) do quadril até o tornozelo. O pé fica rígido nas 12
  linhas de baixo no lado e 3/4, e nas 9 de baixo na frente e nas costas.
- **Mapeamento inverso por vizinho mais próximo, linha a linha:** cada linha anda um número inteiro de pixels. Por
  isso não entra cor nova nem alfa parcial, e o contorno se mantém.
- **Desenho:** a perna escura (a de longe) é desenhada antes.
- **Máscara:** recebe o mesmo mapa.
- **Retoque:** pixel sem vizinho é apagado (deu 0 em todos os quadros).
- **Acessório do quadril:** o facão e o arco verde das roupas de título (cores `ACCESSORY_CORE` mais o contorno
  escuro vizinho) ficam com o quadril, não andam com a perna, e são redesenhados por cima. O que o acessório tampava
  dentro da perna é preenchido pelo pixel de perna mais próximo na linha.
- **Emenda:** a fresta de 1 px entre a barra da roupa e o topo das pernas enxertadas volta a ter o pixel da própria
  coluna.
- **Perna esticada:** quando a perna estica, a linha mais próxima se repete, sem abrir fresta.
- **Pedaço solto perto do chão:** sola ou sombra que ficou para trás quando o pé andou, de até 15 px, é apagado.
- **Checagens por quadro, com reserva automática:** o quadril desloca mais de 3 px na vertical (ou 4 na horizontal),
  algo fica abaixo do chão, ou a parte de baixo ganha ou perde mais de 20% de pixels. Nesses casos o quadro cai no
  modo `lift`: a própria coluna com o pé de um lado levantado 1–2 px.
- **Modos por folha e linha (`MODES`):**
  - `legs`: o padrão.
  - `hem`: para mantos até o chão. É a própria coluna com a barra balançando ±1 px, como o `L_HEMX` do rollout; as
    pernas não são separadas.
  - `hold`: copia a coluna antiga.
- **Ajuste manual por quadro (`MANUAL`, `_LIFT_REVIEW`):**
  - a feminina de costas, coluna 7, usa as pernas de D;
  - os quadros que ficaram feios na revisão das pranchas vão para `lift`.

### Verificado

- **Corpos-base:**
  - 0 cores novas e alfa binário;
  - a máscara cobre exatamente os mesmos pixels da cor;
  - nenhum pedaço solto de até 4 px;
  - os 8 quadros de cada linha são distintos: no mínimo 95 px de diferença entre quaisquer dois.
- **Roupas:**
  - 0 cores novas;
  - a máscara não ganhou pixel fora da cor (as máscaras originais já deixam alguns pixels da cor sem máscara, de
    propósito);
  - 8 quadros distintos em todas as linhas (no mínimo 33 px de diferença).

### Roupas de título

Todas têm máscara, então **substituem** o corpo-base em vez de ficar por cima dele: cada roupa é processada a partir
da própria folha.

- **Lote 1 (calça e legging, modo `legs`):** anta, aroeira, cerrado, gaviao, jabuti, jaguar, machete e mapinguari, nos
  2 corpos.
- **Lote 2 (saia, avental, casaco e manto):**
  - brejo, buriti e matinta: modo `legs` (as pernas aparecem por baixo da barra);
  - root: `legs` no lado e no 3/4, `hem` de frente e de costas;
  - boitata, crystal, ember e firefly: mantos até o chão, `hem` em todas as linhas.

Pranchas de revisão e a lista de retoques: `scratchpad/walk_pilot/outfits/` desta sessão.

**Backup** das folhas de 4 poses das roupas: `scratchpad/walk_pilot/outfits/backup_walk4/` (64 folhas, cor e
máscara). Elas também estão em `.work/char-frames-pilot/backup_originals/` como fonte do rollout.

## Validação no cliente real

As capturas estão em `scratchpad/movement/` (servidor de captura na porta 8247, Xvfb a 640x360, ~27 fps por causa
do render por software). O roteiro é `tools/run_capture.sh` mais `tools/movement_capture.gd` (autoload temporário via
`override.cfg`, removido no fim).

- `antes_virada_E_para_W.png` e `antes.gif`: virada na hora, com `turn_step_ms = 0`. Os pedaços de partida e
  assentar já estavam ativos.
- `depois_virada_E_para_W.png`: lado → 3/4 frente → frente → 3/4 → lado (~55 ms por setor).
- `depois_virada_N_para_S.png`: costas → NW → W → SW → frente, andando, com novo clique no meio. O ciclo não
  reiniciou.
- `depois.gif`: sequência completa.
