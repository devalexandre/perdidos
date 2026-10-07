# Ajustes de personagens — lista de problemas e passada pós-Agente A

Agente E, 27/09/2026. Pranchas em `docs/ajustes-personagens/`. Ferramentas citadas:
- `game/tools/art/customization/eyes.py`: camada de olhos;
- `game/tools/art/cleanup_sheets.py`: alfa binário, órfãos, ilhas e espelhar linha.

## Feito agora (arquivos fora das folhas do A)

| # | O quê | Onde |
|---|---|---|
| 1 | **Olhos em camada própria** (GDD §17.4 camada 7). Olho anime com cílio de 2 px, branco, íris de 4 tons e reflexo, legível a 1x. S/SE/L e todas as animações do corpo-base (idle, walk, sit, 3 golpes, cast, morte). Na morte, os últimos 2 quadros ficam de olho fechado. O olho antigo do corpo-base é coberto com pele, sem editar o corpo. | `assets/characters/eyes/`, `tools/art/customization/eyes*.{py,json}` |
| 2 | **Paleta dos olhos**: 4 tons por cor, mais vivos. Castanho, preto-ardósia, âmbar, verde, azul e cinza agora se distinguem a 1x. | `tools/art/customization/palettes.json` → `data/customization/palettes.tres` |
| 3 | **Shader** `layer_mode 3` (MODE_EYES) em 2D e 3D, com recolor na CPU igual (`bake_image`). A camada entra em `CharacterLayers.layer_specs`, `EntityVisual` (ordem 1; cabelo passa a 2, brinco 3, cabeça 4, armas 5/6) e na prévia da tela de título. | shaders, `character_layers.gd`, `entity_visual.gd`, `layered_character_preview.gd` |
| 4 | **Piscar** no idle: 0,12 s a cada 2,5–5,5 s, com tempo aleatório por personagem. Usa a folha `<body>_idle_blink.png`. | idem |
| 5 | **NPCs** (19 personagens, idle/walk/sit) e **chapéus** (`straw_hat`, `ipe_flower_crown`, todas as animações): alfa binário no corte 0,5 do jogo. Tinham 6–23 mil px semitransparentes por folha nos NPCs e centenas a milhares nos chapéus (halo de antialiasing, contra §17.1/§17.10), mais os pixels órfãos e ilhas de 1–2 px da coroa de ipê. No 3D o resultado é idêntico; nas prévias 2D o halo some. | `assets/npcs/`, `assets/equipment/head/` |
| 6 | Teste novo `tests/client/test_eyes.tscn`, rodado no mundo com ClientView e EntityVisual reais. Verifica: ordem corpo < olhos < cabelo, a rampa certa por personagem, olhos presentes em walk/golpe/cast/idle, o piscar, e que de costas os olhos somem. Captura `eyes_world_*.png`. | `tests/client/` |

Pranchas: `olhos_antes_depois.png` (antes: só um olho do masculino trocava de cor), `olhos_cores.png` (6 cores × 2 corpos × S/SE/L, 1x e 4x, + piscar), `olhos_mundo_3x.png` (no jogo, zoom 1,3).

## Para a passada depois do A (NÃO editado agora: base / cabelo / roupa / brincos / armas)

Depois de qualquer mudança no corpo-base, rodar de novo:
- `python tools/art/customization/eyes.py --report`
- `python tools/art/customization/compose.py anims <png>` (olhar a prancha)

### Crítico
1. **SE vira a cabeça a cada 2 quadros** (`se_vira_a_cabeca.png`). Medido pelo deslocamento do rosto e pela silhueta:
   - idle SE e os quadros "parados" do walk SE (colunas 2, 3, 6, 7) olham para a **esquerda** da tela;
   - os passos do walk SE (colunas 0, 1, 4, 5), o sit SE e todas as folhas de combate SE (A: `mirror_idle`) olham para a **direita**.

   Pela regra do `DirectionalSprite3D.compute_sector`, SE = frente + direita da tela (igual ao L). Então **o idle SE está espelhado**. Afeta masculino e feminino.

   Correção: espelhar a linha 1 do idle e as colunas 2, 3, 6, 7 da linha 1 do walk, em **todas** as camadas:
   - `chr_traveler_*`;
   - `base` e máscara;
   - `hair/*`;
   - `outfits/*`;
   - `face/*`;
   - `equipment/head/*`;
   - `equipment/weapon/*` (idle/walk e `_back`).

   Para a linha inteira do idle: `python tools/art/cleanup_sheets.py --flip-row <png> 1`.
   No walk é por coluna: refazer pelo `build.py` do P com `flip_each` do SE idle trocado em `picks.json`, que é o caminho limpo.

   Depois:
   - em `eyes_anchors.json`, SE idle: x' = 96 − x − largura, e inverter `mirror`;
   - rodar `eyes.py`;
   - avisar o A: o `mirror_idle` do SE vira `false`.
2. **Feminino N: idle de 3/4 × passos de costas** (`feminino_n_idle_vs_walk.png`). O idle N (e as colunas 2, 3, 6, 7 do walk N) mostram a cabeça virada para a esquerda. Os passos (colunas 0, 1, 4, 5) estão de costas retas. O cabelo "pula" ao andar para N, em todos os estilos (o rabo de cavalo troca de lado). Refazer a fonte do idle N feminino "de costas" (`edits.py redo`) e remontar.

### Médio
3. **Franja do `ponytail` feminino cobre o olho esquerdo em S** (e parte do L): a cor do olho quase não aparece desse lado (`olhos_cores.png`, linhas f). Abrir 1–2 px na mecha sobre o olho, nas folhas `hair/ponytail/female_*`.
4. **Pixels soltos nas folhas de combate** (`combate_pixels_soltos.png`: pontinhos acima da mão em attack_blade S c0/c1):
   - `base/chr_*_base_attack_{blade,staff}`: 12–18 órfãos por folha;
   - `chr_traveler_*_attack_*`: idem;
   - `outfits/*_attack_*`: 15–21;
   - `hair/curly|spiky|waves`, walk: ilhas de 1–3 px.

   Rodar `python tools/art/cleanup_sheets.py --islands 2 <arquivos>`. **Não** rodar nas máscaras nem nos brincos: nos brincos, use `--islands 0`.
5. **Halo semitransparente** (antialiasing contra o fundo) em:
   - `chr_traveler_*_{idle,walk,sit}`;
   - `outfits/*_{idle,walk,sit}`;
   - `equipment/weapon/*`.

   São milhares de px por folha. Rodar `cleanup_sheets.py` nelas: o jogo 3D não muda (corte 0,5), mas a prévia 2D fica limpa.
6. **Máscara G (olhos) do corpo-base incompleta**: no masculino S o olho esquerdo não era marcado. Não importa mais, porque a camada de olhos cobre, mas `build.py` pode ignorar a máscara G daqui em diante.

### Para conferir (NPCs — direção incerta; não espelhei nada)
7. Direção de NPCs (`npc_direcoes_S_SE_L_NE_N.png`, colunas S, SE, L, NE, N). Pela silhueta e olhando:
   - `npc_fruit_vendor`: SE olha para a esquerda; L e NE olham para a direita;
   - `npc_master_citlali`: SE e NE parecem olhar para a esquerda; L olha para a direita;
   - `npc_curious_child`, `npc_merchant`, `npc_master_zlata`: ambíguos.

   Se confirmado: `cleanup_sheets.py --flip-row npcs/<npc>_{idle,walk}.png <linha>`.
8. 11 mestres (`npc_master_*_walk`, todos menos brisa e orvalho) têm só 2 poses alternadas, sem passo. Tudo bem se ficam parados; se andarem, falta o ciclo.
9. `npc_fisherman`: a pele sai esverdeada sob o chapéu em todas as direções. Conferir se é intencional.

## Passada do Agente F (28/09/2026) — itens 1–5, 7 e 9 feitos

**Aviso:** o computador reiniciou no meio da passada e o `/tmp` (tmpfs) foi apagado. Com ele se foram **todas as fontes da IA** (imagens-chave aprovadas do Viajante, edições de cabelo e roupa, poses de combate, pastas de NPC), os `picks.json` de trabalho e o venv. Os pipelines `build_sheets.py`, `build.py`, `earrings.py`, `build_equipment.py`, `build_combat.py` e `build_npc.py` **não rodam mais** sem gerar as fontes de novo. Por isso as correções abaixo são feitas **nas folhas prontas**, com scripts determinísticos e idempotentes que ficam no repositório. Eles podem rodar de novo depois de qualquer reconstrução. Python do sistema (`python3` com numpy, scipy e pillow) e Godot em `/usr/bin/godot` (4.7.2).

Ordem depois de refazer folhas: pipelines → `customization/fix_orientation.py` → `cleanup_sheets.py` → `customization/eyes.py --report` → `customization/open_bangs.py`.

| # | O quê | Como / onde |
|---|---|---|
| 1 | **SE espelhado** (crítico). O idle SE e as colunas 2, 3, 6 e 7 do walk SE agora olham para a **direita**, como os passos, o sit e o combate. A cabeça não vira mais a cada 2 quadros. | `tools/art/customization/fix_orientation.py`. O script detecta o lado pela parte de cima do corpo (direto × espelhado contra os passos) e só mexe na linha SE. Espelho exato do quadro em **todas** as camadas: `chr_traveler_*`, base, máscara, 6 estilos de cabelo, 3 brincos, roupa, 2 chapéus e 2 armas (60 folhas). Nos cabelos não padrão e nos brincos, os **passos** SE eram o idle deslocado. Eles foram refeitos a partir do idle novo; antes olhavam para o lado errado. A reprodução foi conferida: 0 px de diferença no método antigo. `head_anchors.json`: `mirror_idle=false` nas 30 entradas SE de cada corpo. `eyes_anchors.json` e `anchors.json` (brinco): SE idle espelhado. |
| 1b | Fonte (para quando as imagens-chave forem refeitas) | Em `character_pipeline/flips.json`: `m_se`/`f_se` com `"idle": true`. Nos `picks.json` do Viajante (`$TRAVELER_WORK`): `dirs.se.flip_each.idle = true`. `combat_anims/keys.py:src_flip` já trata isso (`mirror_idle` passa a `false` sozinho). `customization/layers.py`: o cache `_frames_*.pkl` agora invalida quando o `picks.json` muda; antes, a variante `orig` nunca invalidava. Espelhar pela fonte desloca o idle SE 1 px em relação ao espelho exato; `fix_orientation.py` detecta e não faz nada. |
| 2 | **Feminino N**. A troca de ângulo foi resolvida ao contrário do pedido: os **passos** N passam a usar a cabeça do **idle** (de costas), deslocada pela cabeça medida no Viajante, que é a regra do pipeline nas outras direções. Antes, o raspado dos passos mostrava rosto e olho, e bob, franja e trança mudavam de forma e de lado ao andar. Camadas de cabeça (cabelos, brincos, chapéus): passo = idle deslocado. Corpo inteiro (Viajante, roupa, base, máscara): linhas acima do pescoço vêm do idle. No Viajante e na roupa, o rabo de cavalo do passo sai e entra o do idle. | `fix_orientation.py` (seção N). Refazer o idle pela Bria **não foi possível**: as fontes sumiram. Cheguei a gerar um idle de costas aprovado (`base_f_n_back`), com as edições de cabelo, chapéus, roupa e armas, e um sandbox validado, mas tudo estava no `/tmp`. **Combate N feminino não mudou**: o cabelo do combate ainda vem do idle antigo, que é o mesmo idle de agora, então continua coerente. |
| 3 | **Franja do `ponytail` feminino**: o cabelo que cobria o desenho do olho (íris, branco, cílio) foi aberto, 1–3 px por linha. Folhas `hair/ponytail/female_*` (8 animações, S/SE/L, incluindo o piscar). | `tools/art/customization/open_bangs.py` (roda depois de `eyes.py`). |
| 4–5 | **Limpeza** com `cleanup_sheets.py`: base de combate (sem as máscaras), `chr_traveler_*` (todas), `outfits/*` (todas), `hair/*/*_walk`, `equipment/head/*` com `--islands 2`; `face/*` e `equipment/weapon/*` com `--islands 0`. Nas máscaras de combate só foram zerados os pixels cujo corpo-base ficou transparente (12–32 px), para as duas folhas continuarem iguais. | 50 folhas. Somem os pontinhos acima da mão no attack_blade/staff e o halo semitransparente. |
| 6 | Olhos refeitos: `eyes.py --report`, 0 quadros sem olhos, nenhum quadro SE espelhado (sem `M`). | `assets/characters/eyes/` |
| 7 | **NPCs**. `npc_master_citlali`: SE e NE olhavam para a esquerda. As linhas 1 e 3 foram espelhadas, no idle e no walk. `npc_fruit_vendor`: o SE olha para a direita (o rosto fica deslocado para a direita da cabeça), então não mexi. `curious_child`, `merchant` e `zlata` continuam ambíguos e não foram mexidos. | `cleanup_sheets.py --flip-row`. Na fonte (`w/npc/master_citlali/picks.json`, perdido): `flip: true` em `se` e `ne`. |
| 8 | Mestres com walk de 2 poses: **não mexi**, porque eles ficam parados. | — |
| 9 | **Pescador**: pele e cabelo grisalho esverdeados. Causa: a paleta única de 48 cores misturou o cinza e as sombras da pele com o oliva da camisa. Na cabeça (30% de cima do corpo), cada tom oliva virou o tom quente da própria paleta mais parecido em luminância. Nenhuma cor nova foi criada. | `tools/art/character_pipeline/fix_fisherman_skin.py`. Para reconstruções: `build_npc.py` aceita `"head_colors": 12` no `picks.json`, que reserva cores para a cabeça; foi testado no sandbox antes do reboot. |

Pranchas (`docs/ajustes-personagens/`), todas conferidas olhando:
- `F_se_antes_masc.png` / `F_se_depois_masc.png` e `F_se_antes_fem.png` / `F_se_depois_fem.png`: linha SE em idle, walk, sit e attack_blade, compostas (base + olhos + cabelo + brinco) e do Viajante;
- `F_fem_n_antes.png` / `F_fem_n_depois.png`: N feminino, idle e walk, nos 5 estilos + Viajante;
- `F_franja_antes.png` / `F_franja_depois.png`: rosto S/SE/L em idle, walk, golpe, cast e sit;
- `F_citlali_antes_depois.png`, `F_pescador_antes_depois.png`;
- `F_cliente_real_andar_SE.png` e `F_cliente_real_andar_SE_2.png`: **cliente real** (`run_walkshot.sh`, xvfb; walker feminino na linha de cima, masculino na de baixo) andando na diagonal para baixo-direita. Os quadros parados e os passos olham para a direita.

Testes: `validate_art.py` 0 problemas; `test_direction` (132 checks), `test_customization`, `test_eyes`, `test_title` e `test_render` PASS; `tools/run_autotest.sh` PASS (2 rodadas seguidas; uma rodada anterior falhou em `wander_dialogue_opened`, que é tempo do NPC andarilho e não tem a ver com sprites). `test_ui` falha em 2 checks ("hover no NPC → alvo", "NPC destacado no hover"). A falha é **igual com os assets originais** (testado numa cópia do projeto), então não vem desta passada; o `client_view.gd` foi mexido às 00:10 por outro agente.

Backup das folhas antes da passada: `~/.cache/perdidos_agentF_backup_orig_assets.tgz` (assets/characters, equipment, npcs e tools/art).
