# Contratos — Marco M1 "Chegada do Viajante" (Campo de Treino)

Regras de jogo: GDD §9.3 (Campo de Treino), §9.4 (minimapa), §6 (atributos, XP), §8 (skills, barra 1–0, pontos, títulos), §10 (combate, monstros, estágios e chefes fixos §10.6), §12 (morte).
Nomes de títulos e skills: `TITULOS-E-SKILLS.md`. Roteiro do tutorial: `docs/tutorial-design.md` (adaptar ao Campo de Treino do GDD §9.3, que o substitui no que conflitar).
Continua valendo o que não for alterado em `docs/contracts-city-walk.md` (e seus adendos 1–3) e `docs/phase1-contracts.md`.
Nomes: rodar `make check-names` (GDD §4.0 regra 3, todos os idiomas).

## Já criado pelo coordenador

- **Classes de dados** em `scripts/shared/data/`: `MonsterDef` + `MonsterStage` + `DropEntry`, `SkillDef`, `TitleDef`, `QuestDef` + `QuestStep`, `ZoneDef`. Precisa de campo novo? Adicione **no fim** da classe e cite no relatório.
- **`Content`** também carrega `data/{monsters,skills,titles,quests,zones}/`: `Content.monster(id)`, `.skill(id)`, `.title(id)`, `.quest(id)`, `.zone(map_id)`.
- **Canais de RPC separados**, cada um com um dono. Todos são autoloads com o mesmo caminho no servidor e no cliente:
  - `NetCombat` (`scripts/shared/net_combat.gd`, **K**)
  - `NetProgress` (`net_progress.gd`, **Q**)
  - `NetWorld` (`net_world.gd`, **N**)

  Use `Net._accept_message`/`Net.log_invalid` (ou helpers equivalentes do `Net`) para validar e limitar a taxa. Não crie RPCs novos em `net.gd`.
- **`Balance`** tem `hotbar_slots=10`, `skill_points_per_level=1`, `attribute_points_per_level=3`, `max_skill_level=10`, as constantes da grade e as do bando do chefe (`boss_escort_*`, `boss_respawn_sec`).

## Donos

| Agente | Arquivos |
|---|---|
| **K — Combate e monstros** | `scripts/server/combat/**`, `scripts/server/monsters/**`, `scripts/shared/net_combat.gd`, `scripts/client/combat/**` (alvo, números de dano, barras de vida, VFX simples), `tests/combat/**` |
| **Q — Progressão** | `scripts/server/progression/**` (XP e nível, pontos, skills, títulos, quests), `scripts/shared/net_progress.gd`, `scripts/client/ui/{hotbar,skills_window,quest_log,attributes_window}*.gd`, `data/skills/**`, `data/titles/**`, `data/quests/**`, `localization/progression.csv`, `tests/progression/**` |
| **W — Mundo e arte** | `scenes/maps/training_field*`, `tools/art/**`, `assets/monsters/**`, `assets/npcs/**` (NPCs novos), `assets/skills/**`, `assets/vfx/**`, `data/monsters/**`, `data/npcs/**` e `data/dialogues/**` (NPCs novos), `data/zones/**`, `localization/content.csv` (só acrescentar), minimapas (`assets/minimap/**`) |
| **N — Fluxo e navegação** | `scripts/shared/net_world.gd`, `scripts/server/world/**` (troca de mapa, regras de zona, teto de XP, itens presos à zona, cidade inicial pelo título), `scripts/client/ui/minimap*.gd`, `scripts/client/ui/world_map*.gd`, `tests/world/**` |

**Arquivos compartilhados** (`server_world.gd`, `player_session.gd`, `net_entity.gd`, `main.gd`, `game_ui.gd`, `character_data.gd`, `character_stats.gd`): só **edições pequenas e ancoradas**, para registrar serviços ou chamar hooks. Leia o arquivo de novo logo antes de editar, porque outros agentes mexem em paralelo. Cada serviço fica no seu próprio arquivo.

## Entidades

- `NetEntity.kind` ganha `&"monster"`; `def_id` é o id do `MonsterDef`. **K** também replica:
  - `stage` (1–3)
  - `hp_ratio` (0–1)
  - `target_id` (quando atacando)
  - `level`
- O visual de monstro vem do `EntityVisualFactory`, com `sprite_base` do estágio. As animações usam os sufixos `_idle`, `_walk`, `_attack`, `_hit` e `_death`, no mesmo formato de folha. Nomes sobre a cabeça em cor por estágio: normal branco, médio laranja, chefe vermelho.
- Monstros usam `GridMover`, com a mesma grade dos jogadores.
- **Spawns no mapa (W):** nó `Spawns/` com `Marker3D` e metas:
  - `monster_id`
  - `count`
  - `radius_cells`
  - `respawn_sec` (opcional; senão vem do `MonsterDef`)

## Combate (K) — GDD §10.2

- **Clique em monstro:** anda até o alcance e ataca em ciclo até o alvo morrer ou chegar outra ordem (GDD §10.1). Intenção `NetCombat.send_attack(entity_id)`.
- **Fórmulas do §10.2**, com velocidade de ataque, crítico e variação de ±10%. Os atributos vêm de `CharacterStats` (A já implementou a base).
- **IA:** ocioso → patrulha → perseguição → ataque → retorno. Na volta, o monstro recupera a vida (§10.3). Comportamentos especiais pelo nome, em `MonsterStage.behaviors`.
- **Evolução (§10.6):** quem mata jogador ganha a XP total do jogador (valor que Q fornece).
  - **K** sobe o estágio pelo `MonsterDef.stage_for_xp`.
  - Chefe surge com bando: `Balance.boss_escort_*`.
  - Recompensa por derrotar = XP do estágio (sem evolução desde 30/09/2026).
  - No Campo de Treino o teto é o estágio 2 (`ZoneDef` / GDD §9.3).
- **Morte do jogador:** **K** emite o evento. **N** aplica a regra da zona: no treino, renasce no acampamento, sem Marca da Alma. Nas outras zonas, a Marca da Alma fica para a F3; por enquanto renasce no `respawn_marker`.
- **Drops:** itens no chão por 60 s, de dono do grupo (§10.5). Pegar pelo `Interactable` já existente (`req_interact` com `target_id "d:<drop_id>"`) ou por uma intenção própria de **K**.
- **Eventos para Q:**
  - `monster_killed(killer_peer, monster_id, stage, xp)`
  - `player_killed(victim_peer, killer_entity)`

  Q usa esses eventos para dar XP e contar objetivos de quest.
- **Cliente:** alvo selecionado (anel no chão), números de dano, barra de vida acima do monstro atacado, barras de vida e mana do jogador no HUD, animação de ataque e de dano.

## Progressão (Q)

- **XP e nível** (§6.3): a curva `floor(100 * nivel^1.6)` e a XP de grupo ficam para a F2. Cada nível dá `attribute_points_per_level` e `skill_points_per_level`.
  - **Teto por zona:** `ZoneDef.xp_level_cap`, com o valor fornecido por N via `ZoneRules.xp_allowed(peer)`.
  - **XP total acumulada:** `Progression.total_xp(peer)`.
- **Distribuir pontos:** janela de atributos (FOR, DES, VIT, INT, ESP; §6.2) com intenção `NetProgress.send_allocate_stats(dict)`. Janela de skills para gastar pontos em skills conhecidas: `send_skill_level_up(skill_id)`.
- **Skills:**
  - Barra de **10 espaços, teclas 1 a 0** (`send_hotbar_set(slot, skill_id)`, só fora de combate).
  - Lançar com `send_cast(skill_id, target_entity_id | ground_pos)`.
  - Validação: skill conhecida e na barra, mana, recarga, alcance, arma de corpo a corpo quando exigida.
  - O dano sai pelo pipeline de dano de **K** (`CombatService.apply_damage(...)`). **K** e **Q** combinam essa interface no início: **K** publica a função, e **Q** chama.
  - Tipos de alvo do `SkillDef`, com prévia da área no chão.
- **Títulos (`TITULOS-E-SKILLS.md`):** recalculados ao aprender uma skill. O jogador escolhe o título exibido. O `appearance`/nome replica o título exibido (`NetEntity.title_id`).
- **Quests (§9):**
  - Objetivos de matar, coletar, explorar, falar e provação. A provação pode ser simplificada neste marco (enfrentar um boneco do Mestre).
  - Diário de quests e mensagens de progresso.
  - **Nenhuma quest exige nível.**
  - No Campo de Treino, só **uma** quest de título pode ser concluída (`QuestDef.training_title_quest`).
- **MVP de conteúdo (Q):**
  - Skills L1–L5 e A1–A5 do GDD (tabelas §8.2/§8.3) + as 2 exclusivas iniciais (Roçada e Fogo-Fátuo, de `TITULOS-E-SKILLS.md`).
  - Títulos do MVP.
  - Quests de título do Campo de Treino para os 2 Mestres da Terra de Pindorama (Lâmina → título inicial "Facão Firme"; Arcano → "Luz de Vaga-lume"), cada uma ensinando a skill 1 da escola.
  - O título inicial define `TitleDef.start_map_id` = `city_awakening`.

## Mundo (W)

- **`scenes/maps/training_field.tscn`** (`map_id` = `training_field`): grande (~200×200 un.), acampamento central, portal de saída e uma **zona por nação** do GDD §4.0, cada uma com o clima da região: arquitetura, vegetação, paleta e um Mestre.
  - **MVP:** a zona da **Terra de Pindorama** completa e bonita. As outras 9 zonas com caracterização visual simples (props e paleta), cada uma com o seu Mestre (NPC com diálogo "a travessia para a nossa terra ainda não está aberta") e **2 monstros iniciais da região** (1 estágio visual basta nelas).
  - Navmesh assado, chão na camada 1, clicáveis na camada 2, `NpcPoints/`, `Spawns/`, `Interactables/` (portal de saída), `AudioZones/`.
- **Monstros da Terra de Pindorama para o treino**, com os 3 estágios (nome e arte próprios por estágio, §10.6):
  - Redemoinho Arteiro
  - Vaga-lume Encantado
  - Tatu-Pedra (Âncora 3)

  Animações idle, walk, attack, hit e death, nas 5 direções, no pipeline aprovado.
- **Mestres:**
  - Terra de Pindorama: dois novos para o Campo (ou os mesmos Brisa e Orvalho, a critério de W, desde que não conflitem com a cidade).
  - Um Mestre de cada outra nação: idle nas 5 direções.
- **`data/zones/training_field.tres`:** `kind` TRAINING, `xp_level_cap` = 10, `items_bound_to_zone` = true, `grave_on_death` = false, textura do minimapa. Também **`data/zones/city_awakening.tres`** (CITY, sem combate).
- **Minimapas:** imagem vista de cima de cada mapa (render ortográfico, estilizado em pixel art), com o `minimap_world_rect` correto.

## Fluxo e navegação (N)

- **Personagem novo:** depois da abertura, entra no `training_field`, não na cidade. Personagem que já saiu do treino entra na cidade do seu título.
- **Portal de saída do Campo:** só com o título inicial. Ao sair:
  - **remove todos os itens marcados como do treino** (inventário e equipamento);
  - leva o jogador ao `start_map_id` do título;
  - grava `left_training = true` no save.
- **Regras de zona** (`scripts/server/world/zone_rules.gd`):
  - teto de XP;
  - marcar os itens obtidos na zona (flag no `ItemStack`, combinado com o dono do inventário);
  - morte e renascimento conforme o `ZoneDef`;
  - combate permitido ou não.
- **Minimapa (GDD §9.4)**, no canto superior direito:
  - a textura do `ZoneDef` com a posição e direção do jogador;
  - membros do grupo (futuro);
  - ícones de Mestres, loja e portais (dos `NpcPoints`/`Interactables`);
  - Marca da Alma (futuro);
  - zoom em 2 níveis e mapa grande em tela cheia (tecla M);
  - norte fixo ou girando com a câmera (opção nas configurações).
- **Integração da personalização** (Agente P, quando o relatório dele existir):
  - a aparência escolhida na criação vai para o servidor (handshake/criação), com validação pelo `options.tres`;
  - fica salva no personagem;
  - é replicada no `appearance` (adendo 2);
  - aparece nas camadas do `EntityVisual`.

## Testes obrigatórios

- **Obrigatório para todos os mapas:** estilo de cenário do GDD §17.0.A. Mapa no estilo antigo não é entregue.

- **K:**
  - autoteste de combate (matar monstro, drop, XP, IA de retorno, monstro que mata jogador não evolui);
  - cliente vendo números de dano;
  - negativos (atacar de outra instância, alvo morto, fora de alcance).
- **Q:**
  - subir do 1 ao 10 no treino e parar de ganhar XP;
  - gastar pontos;
  - aprender skill por quest;
  - conquistar título;
  - lançar skills de cada tipo de alvo;
  - barra 1–0;
  - só uma quest de título no treino.
- **W:**
  - verificador de conteúdo (referências, navmesh, spawns alcançáveis);
  - validador de arte;
  - capturas de cada zona e prancha dos monstros por estágio.
- **N:**
  - fluxo completo novo personagem → treino → nível 10 → título → portal → cidade, com os itens do treino removidos;
  - minimapa em captura;
  - personagem antigo entra direto na cidade.
- **Todos:**
  - `tools/run_autotest.sh` (antigos continuam passando);
  - `make check-names`;
  - import limpo;
  - matar só os próprios processos: nunca `pkill` por padrão, e cada um usa portas próprias (K 79xx, Q 80xx, N 81xx, W 82xx).

## Apêndice Q — Progressão (Agente Q, só acrescentar)

**Serviço no servidor:** `world.progression` (`Progression`, `scripts/server/progression/progression.gd`), criado no `ServerWorld._ready()`.
- `Progression.total_xp(peer_id) -> int` (estático; XP total acumulada).
- `world.progression.grant_xp(peer_id, amount, reason)` — aplica o teto da zona (`ZoneRules.xp_allowed(peer)` de N se existir em `world.zone_rules`; senão `ZoneDef.xp_level_cap` do mapa).
- `world.progression.on_item_obtained(peer_id, item_id, qty)` — quem der item ao jogador (drop de K, diálogo, loja) pode chamar; Q também observa o inventário, então é opcional.
- `world.progression.statuses` (`StatusEffects`): **Q é dono dos efeitos de status** (escudo, reforço de DEF, lentidão, atordoamento, dano contínuo). Consultas para K:
  - `statuses.absorb_damage(target: NetEntity, amount: int) -> int` (devolve o dano que sobra depois do escudo);
  - `statuses.def_multiplier(entity) -> float` (1.0 sem efeito; Postura de Ferro = 1.4);
  - `statuses.is_stunned(entity) -> bool` (monstro atordoado não anda nem ataca);
  - `statuses.move_speed_multiplier(entity) -> float` (lentidão; o `GridMover` do monstro usa `ms_per_cell / mult`).
  Q já aplica stun/lentidão nos **jogadores** (para o mover dele); nos monstros, K consulta.

**O que Q espera de K (Interface K→Q; K confirma no apêndice dele):**
- `world.combat` com sinais `monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int)` e `player_killed(victim_peer: int, killer_entity: int)`. Q liga os sinais sozinho quando `world.combat` existir. **Q dá a XP** do `monster_killed` (K não chama `grant_xp`).
- `world.combat.apply_damage(attacker: NetEntity, target: NetEntity, kind: StringName, multiplier: float, source_id: StringName) -> int` com `kind` = `&"physical"` ou `&"magic"`; K aplica fórmula §10.2, crítico, variação, aggro, morte e números de dano. Devolve o dano causado (0 = não acertou/inválido).
- `world.combat.is_in_combat(peer_id) -> bool` (regra dos 6 s do §6.4) — a barra só muda fora de combate.
- `world.combat.can_attack(attacker: NetEntity, target: NetEntity) -> bool` (mesma instância, vivo, hostil).
- Enquanto `world.combat` não existir, Q usa um substituto local (`CombatBridge`) com as fórmulas do §10.2 só para os testes.

**Dados:** skills em `data/skills/` com os ids de `TITULOS-E-SKILLS.md` §6.1 (`blade_firm_strike`, …, `arcane_star_fall`) + `blade_clearing_sweep` (Roçada) e `arcane_will_o_wisp` (Fogo-Fátuo). Títulos em `data/titles/`. Quests em `data/quests/`.

**NPCs dos Mestres do Campo (W):** Q usa os ids `training_master_blade` (Lâmina, Terra de Pindorama) e `training_master_arcane` (Arcano, Terra de Pindorama) em `QuestDef.giver_npc`. **W, por favor, use esses ids nos `NpcDef`** (ou escreva aqui os ids escolhidos e Q troca). As opções de quest entram **sozinhas** no primeiro nó do diálogo de qualquer NPC que dê/receba quest — W não precisa escrever opção de quest no diálogo. Opcionalmente, o diálogo pode usar as ações `accept_quest` / `turn_in_quest` (`action_args {"quest_id": ...}`) e as condições `quest_available`, `quest_active`, `quest_ready`, `quest_done`, `has_title`, `knows_skill` (valor = id).

**Rede (NetProgress, Q):** intenções `send_allocate_stats(dict)`, `send_skill_level_up(skill_id)`, `send_hotbar_set(slot, skill_id)`, `send_cast(skill_id, target_entity_id, ground_pos)`, `send_set_title(title_id)`, `send_quest_abandon(quest_id)`. Eventos para o dono: `progress_changed(dict)`; para a instância: `skill_cast(entity_id, skill_id, target_entity_id, pos)`.

**Entidade:** `NetEntity.title_id` (StringName, replicado; `&""` = nenhum) — título exibido sob o nome.

## Apêndice N — Fluxo e navegação (Agente N, só acrescentar)

**Serviços no servidor** (criados no `ServerWorld._ready()`):
- `world.zone_rules` (`ZoneRules`, `scripts/server/world/zone_rules.gd`):
  - `xp_allowed(peer_id) -> bool` — false quando o nível do personagem já chegou ao `ZoneDef.xp_level_cap` do mapa em que ele está (0 = sem teto). **Q chama antes de dar XP.**
  - `combat_allowed(instance_id: StringName) -> bool` — `ZoneDef.combat_allowed` (sem `ZoneDef` = permitido; W cria `city_awakening.tres` com `combat_allowed = false`). **K consulta antes de aceitar ataque/skill.**
  - `zone_for_instance(instance_id) -> ZoneDef` (pode ser null).
  - Morte: N liga sozinho `world.combat.player_killed(victim_peer, killer_entity)` quando `world.combat` existir e aplica a regra da zona (treino: renasce no `respawn_marker` do `ZoneDef` — acampamento —, 50% de vida e mana, sem Marca da Alma, depois de `ZoneRules.RESPAWN_DELAY_SEC`). K só emite o sinal e deixa a entidade em `anim = &"death"`/parada; N põe `anim = &"idle"` ao renascer. Se K quiser saber quando renasceu: sinal `world.zone_rules.player_respawned(peer_id)`.
- `world.map_transfer` (`MapTransfer`, `scripts/server/world/map_transfer.gd`): escolhe o mapa de entrada (personagem novo → `training_field`; `left_training` → `home_map`), troca de mapa (`transfer(session, map_id)`) e o portal de saída.
- **Instância do Campo de Treino:** ~~`training_field:solo_<hash do nome>`~~ — **substituído em 30/09/2026** (decisão do dono, GDD §5): todo mapa tem uma instância só, `instance_id = map_id` (`MapTransfer.instance_id_for`). Provações continuam individuais: o monstro da provação tem dono (`MonsterBrain.owner_peer`) e só luta com ele e o grupo dele. Ver `docs/contracts-city-walk.md`, ADENDO 6.

**Itens presos à zona:** `ItemStack.bound_zone` (StringName, `&""` = livre; salvo como `"bound_zone"`). `Inventory.bind_zone` é ajustado por N ao entrar num mapa com `items_bound_to_zone`: **tudo o que entrar por `Inventory.add()`** (drop de K, recompensa de Q, loja, diálogo) sai marcado — ninguém precisa passar nada. Pilhas marcadas e livres não se juntam. Ao sair pelo portal, N remove todas as pilhas marcadas do inventário e do equipamento.

**O que N espera de Q:** `world.progression.initial_title(peer_id) -> StringName` (id do título inicial conquistado, `&""` = nenhum). Enquanto não existir, N aceita também `get_titles(peer_id)`/`titles(peer_id) -> Array` e procura um `TitleDef` com `start_map_id`. A cidade de destino é `Content.title(id).start_map_id`.

**O que N espera de W:** no `training_field.tscn`, o portal de saída é um nó em `Interactables/` com `interact_type = &"portal"` (qualquer `interact_id`); dentro de um mapa `ZoneDef.Kind.TRAINING` todo portal é tratado como saída (o `target_map` é ignorado: o destino vem do título). Marcador de renascimento = `ZoneDef.respawn_marker` (nome de um nó do mapa, procurado em qualquer profundidade). Ícones do minimapa: NPCs em `NpcPoints/` (via `NpcDef.spawn_marker`), portais em `Interactables/`; meta opcional `minimap_icon` (`&"master"`, `&"shop"`, `&"portal"`, `&"none"`) em qualquer um desses nós sobrepõe o ícone automático.

**Personagem:** `CharacterData.left_training` (bool), `home_map` (StringName) e `custom_appearance` (Dictionary, chaves do ADENDO 2). Saves antigos sem `left_training` = já saíram do treino (vão direto para a cidade).

**Rede (NetWorld, N):** `send_appearance(dict)` (cliente, logo depois de conectar; o servidor valida com `options.tres` na criação do personagem e ignora depois).

**Adendo Q-1 (Q, depois de ler os dados de W, K e N):**
- Mestres do Campo da Terra de Pindorama: Q passou a usar os ids que W criou — **`master_jatoba`** (Lâmina) e **`master_candeia`** (Arcano) — no lugar de `training_master_*`.
- Monstros usados nas quests do Campo: `prank_whirlwind`, `enchanted_firefly`, `stone_armadillo`; itens: `firefly_light`. A provação usa `world.combat.spawn_monster` de K (o Mestre solta um bicho só para o jogador).
- Para N: `world.progression.initial_title(peer_id) -> StringName` existe (e `start_map_for(peer_id)`).
- K: as consultas de status já batem com `CombatBridges` (absorb_damage, def_multiplier, is_stunned, move_speed_multiplier).

## Apêndice W — ids do Campo de Treino (só acrescentar)

Fonte única: `game/tools/art/content/training_src.json` → `build_training.py` (chaves em `localization/content.csv`, só acrescenta) e `build_training.gd` (`.tres`). Mapa: `tools/art/build_training_field.gd` → `scenes/maps/training_field.tscn`. Verificador: `tools/art/verify_training_field.gd`.

**Zonas** (`data/zones/`): `training_field` (TRAINING, teto 10, itens presos, sem túmulo, `respawn_marker = CampRespawn`, minimapa `Rect2(-100,-100,200,200)`), `city_awakening` (CITY, sem combate, `Rect2(-80,-80,160,160)`). Chave do nome: `ZONE_<MAP_ID>_NAME`.

**Mestres** (`data/npcs/<id>.tres`, `map_id = training_field`, `spawn_marker` = id, marcador em `NpcPoints/<id>` com metas `facing_yaw` e `minimap_icon = &"master"`):

| id | Nome | Região (`region_id`) |
|---|---|---|
| `master_jatoba` | Mestre Jatobá — **Lâmina** (quest de título "Facão Firme") | `brasil` |
| `master_candeia` | Mestra Candeia — **Arcano** (quest de título "Luz de Vaga-lume") | `brasil` |
| `master_guiomar` | Mestra Guiomar (alabarda) | `portugal` |
| `master_tsubaki` | Mestra Tsubaki (naginata) | `japao` |
| `master_solveig` | Mestra Solveig (escudo) | `nordico` |
| `master_nicandro` | Mestre Nicandro (lança e escudo) | `grecia` |
| `master_seneb` | Mestre Seneb (escriba, khopesh) | `egito` |
| `master_ewan` | Mestre Ewan (espada longa, harpa) | `celta` |
| `master_zlata` | Mestra Zlata (arco, machado) | `eslavo` |
| `master_xiaoyu` | Mestra Xiaoyu (jian) | `china` |
| `master_citlali` | Mestra Citlali (obsidiana) | `mexico` |

Diálogos em `data/dialogues/<id>.tres` (nós `start` + `about`/`tip` nos da Terra de Pindorama; `start` com "a travessia ainda não está aberta" + `lore` nos outros). **Q** liga as quests por `QuestDef.giver_npc` (não precisa editar o diálogo). Brisa e Orvalho continuam só na cidade.

**Monstros** (`data/monsters/<id>.tres`; nome `MON_<ID>_S<n>_NAME`; folhas `assets/monsters/<id>/mon_<id>_s<n>_{idle,walk,attack,hit,death}.png`, linhas S,SE,L,NE,N, colunas idle 4 / walk 6 / attack 6 / hit 2 / death 6, quadro quadrado = altura/5):

| id | Estágio 1 → 2 → 3 | Quadro (px) | Nível |
|---|---|---|---|
| `prank_whirlwind` | Redemoinho Arteiro → Rodamoinho Traquinas → Ventania do Gorro Vermelho | 64 / 96 / 240 | 2 / 6 / 20 |
| `enchanted_firefly` | Vaga-lume Encantado → Vaga-lume Candeeiro → Rainha-Lume do Brejo | 64 / 96 / 240 | 4 / 8 / 21 |
| `stone_armadillo` | Tatu-Pedra → Tatu-Rochedo → Tatu-Montanha | 96 / 144 / 240 | 7 / 10 / 22 |

Outras nações (2 estágios em dados; o estágio 2 reusa a arte do 1 com `visual_scale = 1.4`; quadro 64): `fountain_serpent`, `trasgo_imp` (portugal); `kasa_obake`, `trickster_tanuki` (japao); `moss_troll`, `lindworm_hatchling` (nordico); `griffin_chick`, `little_chimera` (grecia); `dune_scorpion`, `sphinx_cub` (egito); `puca_trickster`, `lake_kelpie` (celta); `zmey_hatchling`, `walking_hut` (eslavo); `hopping_jiangshi`, `spirit_fox_cub` (china); `obsidian_iguana`, `jaguar_cub` (mexico).

Comportamentos usados em `MonsterStage.behaviors`: `hop_teleport`, `fly_pattern`, `ranged`, `roll_charge`, `boss` (estágio 3).

**Itens de drop novos** (`data/items/`): `firefly_light` (Luz de Vaga-lume), `armadillo_shell` (Casco de Tatu-Pedra), `red_cap` (Gorrinho Vermelho, raro), `thick_leather` (Couro Grosso). Também caem `spinning_leaf` e poções existentes.

**Mapa `training_field`** (X = leste, Z = sul; acampamento na origem; área andável = disco de raio 92):
- `SpawnPoint` (0,0,4) e `CampRespawn` (-2.5,0,3) no acampamento.
- `Spawns/<nome>` (Marker3D, metas `monster_id`, `count`, `radius_cells`): 6 na Terra de Pindorama (`pindorama_whirlwind_1/2`, `pindorama_firefly_1/2`, `pindorama_armadillo_1/2`) + 2 por nação (`<regiao>_<monster_id>`).
- `Interactables/training_exit`: portal (arco de pedra ao norte do acampamento), metas `interact_type = portal`, `target_map = city_awakening` (N troca pelo `start_map_id` do título), `training_exit = true`, `minimap_icon = &"portal"`, `approach_position`. Mais 3 bancos `sit` (`bench_vereda`, `bench_ipe`, `bench_rancho`).
- `PointsOfInterest/`: `CampFire`, `ExitPortal`, `Rancho`, `TrainingDummies`, `StoneMark1..3` (marcos de pedra para quests de explorar), `Area_<regiao>` (centro de cada zona).
- `AudioZones/`: `default`, `camp`, e uma por região (`brasil`, `portugal`, …) com metas `zone_id`, `audio_zone_def = training_field_<zone>` e `name_key` (nome da área, útil para o minimapa/aviso de área).
- Terra de Pindorama ao sul (centro (0,0,52), rancho dos Mestres em (0,0,36)); as outras nações em volta, a 62 un. do centro, nos ângulos (atan2(z,x), 90 = sul): portugal 145, grecia 177, egito 208, celta 239, nordico 270 (norte), eslavo 301, china 332, japao 3, mexico 34.

## Apêndice K — Combate e monstros (Agente K, só acrescentar)

### Interface K→Q / K→N (servidor) — `world.combat` (`CombatService`, `scripts/server/combat/combat_service.gd`)
Criado no `ServerWorld._ready()` logo depois do `ChatService` (antes do `connect_combat` diferido de N).
- **Sinais** (os mesmos também saem em `CombatEvents.bus()`, `scripts/server/combat/combat_events.gd`, para quem não tem `world`):
  - `monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int)` — `xp` = `MonsterStage.xp_reward` + `evolved_kill_xp_share` × XP absorvida (§10.6). `killer_peer` = quem deu o último golpe (grupo: F2). **Q dá a XP.**
  - `player_killed(victim_peer: int, killer_entity: int)` — K já deixou `hp = 0`, `anim = &"death"`, parado, sem alvo; intenções de mover/interagir/atacar/usar item são recusadas (`action_while_dead`). **N renasce**; K detecta o renascimento sozinho quando `character.hp > 0` (ou N chama `revive`).
  - `player_revived(peer)`, `monster_evolved(entity_id, monster_id, stage, instance_id)`; no bus também `damage_applied(source_id, target_id, amount, crit, damage_type)` e `drop_picked(peer, item_id, qty, instance_id)`.
- `apply_damage(attacker: NetEntity, target: NetEntity, kind: StringName = &"physical", multiplier: float = 1.0, source_id: StringName = &"basic_attack") -> int` — `kind`: `&"physical"` | `&"magic"` | `&"true"` (verdadeiro: `multiplier` = dano fixo, sem fórmula). Fórmula §10.2 (defesa, ±10%, crítico só físico), `statuses.def_multiplier`/`absorb_damage` de Q, aggro, morte, drops, números de dano e evento. Devolve o dano (0 = inválido). `deal_damage(...)` igual, devolvendo `{ok, reason, amount, crit, killed}`.
- `can_attack(attacker, target) -> bool` (mesma instância, os dois vivos, jogador×monstro — sem PVP neste marco —, `zone_rules.combat_allowed(instance_id)`); `attack_block_reason(...) -> String` dá o motivo.
- `is_in_combat(peer_id) -> bool` (`Balance.cfg.out_of_combat_sec`, causar ou receber dano); `mark_combat(peer_id)`.
- `heal(target, amount) -> int`; `revive(peer_id, position = Vector3.INF, hp_fraction = 1.0)`; `is_dead(peer_id)`; `is_entity_dead(entity)`.
- `monsters_in_radius(instance_id, center: Vector3, radius_m: float) -> Array[NetEntity]` (skills de área); `get_combat_stats(entity) -> {atk, matk, def, mdef, dex, level}`; `get_brain(entity) -> MonsterBrain`.
- `spawn_monster(instance_id, monster_id, pos, owner_peer = 0) -> NetEntity` (estágio 1, não renasce; provação de Q). Desde 30/09/2026 `owner_peer != 0` vira `MonsterBrain.owner_peer`: o monstro só ataca e só pode ser atacado pelo dono e pelo grupo dele (`attack_block_reason` = `attack_not_owner`, mensagem `SYS_TRIAL_NOT_YOURS`).
- Status de Q nos monstros: K consulta `world.progression.statuses.is_stunned` (não anda nem ataca) e `move_speed_multiplier` (divide `ms_per_cell`) a cada tick.
- Pontes (padrões se o serviço do outro agente faltar): `scripts/server/combat/combat_bridges.gd` — `Progression.total_xp(peer)` (Q) → senão soma da curva §6.3 até o nível; `zone_rules.zone_for_instance` / `combat_allowed(instance_id)` (N) → senão `Content.zone`; teto de estágio = 2 em `ZoneDef.Kind.TRAINING`, senão 3; sem `zone_rules.on_player_killed`, K renasce no SpawnPoint em 5 s.

### Entidades e rede
- `NetEntity`: `KIND_MONSTER = &"monster"`, `KIND_DROP = &"drop"`; replicados só quando mudam: `stage` (0/1–3), `hp_ratio` (0–1, **jogadores também**), `target_id` (alvo atacado; jogador também), `level`. `entity_id`: monstro = 2 000 000 + n, item no chão = 3 000 000 + n. Monstro: `display_name` = `name_key` do estágio; item: `def_id` = item_id, `appearance = {"qty": n}`.
- `NetCombat` (cliente→servidor): `send_attack(entity_id)`, `send_stop_attack()`, `send_pickup(entity_id)`; `route_interact(target_id)` é ligado pelo `main.gd` ao `ClientView.interact_requested` (monstro → ataque, item → pegar, resto → `Net.send_interact`). O servidor também aceita `req_interact("e:<monstro|item>")` e `req_interact("d:<id>")`. Andar no chão cancela o ataque.
- `NetCombat` (servidor→cliente, sinais): `hit(source_id, target_id, amount, crit, damage_type, target_hp_ratio)` e `entity_died(entity_id)` para a instância; `attack_target_changed(entity_id)` só ao dono (`NetCombat.client_attack_target`).
- Recusas (log `invalid_message`): `attack_target_invalid`, `attack_other_instance`, `attack_target_dead`, `attack_out_of_range` (> 20 células), `attack_zone_no_combat`, `attack_unreachable`, `action_while_dead`, `pickup_not_owner`, `pickup_other_instance`, `pickup_out_of_range`, `pickup_inventory_full`. Chaves novas em `localization/combat.csv`: `SYS_MONSTER_BECAME_BOSS`, `SYS_NO_COMBAT_HERE`, `SYS_YOU_ARE_DEAD`, `SYS_DROP_NOT_YOURS`.

### Monstros
- `Spawns/` (W): lido quando a grade da instância fica pronta; cada vaga renasce no estágio 1 após `respawn_sec`. IA `MonsterBrain` (idle → patrulha → perseguição → ataque → retorno com vida cheia; coleira `leash_cells` da origem). Comportamentos: `hop_teleport`, `fly_pattern`, `roll_charge`, `ranged` (só o alcance do estágio), `boss` (marca). Nome desconhecido = aviso uma vez.
- Estágios (`MonsterEvolution`, decisão de 30/09/2026): **sem evolução**. Monstro que mata jogador não muda. Chefe (3) só no covil fixo (`BossLairs/`), com bando `boss_escort_normals` + `boss_escort_mediums`, renascendo em `boss_respawn_sec`; aviso `SYS_BOSS_LAIR_APPEARED`.
- Drops: `DropEntry` rolado no servidor, item no chão por 60 s, dono = quem matou (grupo: F2), `Inventory.add` (N marca itens do treino). Estrelas vão direto para quem matou.

### Cliente
- `EntityVisualFactory` → `CombatVisuals` (monstro: folhas do estágio, `visual_scale`, nome branco/laranja/vermelho; item: `DropVisual`). `DirectionalSprite3D` ganhou `_attack`, `_hit` (uma vez, `play_oneshot`) e `_death` (segura o último quadro), todos opcionais (sem a folha: idle + "tranco" / o corpo some).
- `CombatFx` (filho do autoload `NetCombat`): números de dano (crítico maior, laranja, "!"; dano no jogador local em vermelho), anel vermelho sob o alvo, barra de vida acima de monstros feridos/alvo e de outros jogadores feridos. `PlayerBars` (vida/mana) no HUD, criada pelo `GameUI`.

### Testes de K
- `tests/combat/run_combat_autotest.sh` (servidor + clientes `hero`/`victim`, dados de `tests/combat/fixtures` com `--combat-fixtures`; a cidade vira arena só em memória) e `tests/combat/test_formulas.tscn`. Captura: `tests/combat/run_combat_shot.sh` (`TRAINING=1` = Campo de Treino com os monstros de W).

**Mapa da área e atlas (N ↔ G):** o mapa grande da **área atual** (N, `WorldMap`) abre com **Shift+M** ou clique no minimapa; a tecla **M** fica para o atlas do mundo (G). Para o "você está aqui" do atlas: `NetWorld.where_am_i() -> {map_id: StringName, position: Vector3}` e o sinal `NetWorld.zone_changed(map_id)` (cliente).

**Adendo Q-2 (testes):** `game/tests/progression/run_progression_test.sh` (servidor + cliente em `--progression-autotest`, porta 8010; com janela via `xvfb-run -a` tira capturas da barra, skills, atributos, diário e mira). `--progression-autotest` no servidor liga comandos de teste (`NetProgress.send_debug`: grant_xp, kill, spawn_dummy, learn, set_mp, teleport…) — nunca usar em jogo normal.

**Adendo W-1 (tamanho relativo, GDD §10.2.1):** folhas remontadas com tamanho aparente relativo ao Viajante (82 px): estágio 1 = pequeno (~57 px) em quadro **96** para todas as espécies; `prank_whirlwind` s2 = médio (~82 px, quadro 96); `enchanted_firefly` s2 = médio em quadro **144** (asas + voo); `stone_armadillo` s2 = grande (~123 px, quadro 144); estágio 3 = chefe (~205 px, quadro 240). Estágio 2 das outras nações: mesma folha com `visual_scale = 1.4` (~80 px). O quadro continua vindo da própria folha (altura/5). Prancha na mesma escala de mundo: `tools/art/monster_pipeline/size_lineup.py`. O visual do mapa fica todo em `training_field.tscn/Decor/` (o kit de V pode trocar) e o layout em dados em `tools/art/training_field_layout.json`.

## Apêndice R — Sorte, acerto/esquiva, monstros raros, Mestres no nível 10, engrenagem (Agente R, só acrescentar)

**Atributos (GDD §6.2):** `CharacterStats.ATTRIBUTES` ganhou `&"luk"` (SOR, no fim). Começa em 5, recebe os 3 pontos por nível (`NetProgress.send_allocate_stats({&"luk": n})`), aparece na janela de atributos (sigla `STAT_LUK`, dica = `UI_ATTR_LUK_DESC`) e na de personagem. Save: `CharacterData.SAVE_FORMAT_VERSION = 2`; save antigo sem `luk` carrega com 5. `stats_changed` traz `luk`. Itens podem dar `luk` em `ItemDef.stats`.

**Constantes:** grupo `Luck & accuracy` do `BalanceConfig` (`crit_*`, `hit_*`, `monster_dex_*`, `drop_chance_per_luk`, `rare_*`). `CombatRules.CRIT_BASE_CHANCE/CRIT_CHANCE_PER_DEX` saíram (crítico agora vem da SOR).

**Combate (K):** `DamageFormula.crit_chance(luk)`, `hit_chance(dex_att, dex_def)` = clamp(80% + diferença × 1%, 50%, 95%), `drop_luck_multiplier(luk)`, `rare_luck_multiplier(luk)`, `monster_dex(stage_dex, level)`. `compute()` devolve também `"miss"`; só **físico** erra (mágico/verdadeiro sempre acerta, skills físicas de Q também podem errar). `deal_damage` → `{..., "miss": true, "amount": 0}`; `apply_damage` devolve 0. Errou: sem dano, conta como combate, provoca o monstro, log `combat_miss`, e `NetCombat.hit` com `amount = NetCombat.MISS_AMOUNT (-1)` (o `CombatFx` mostra "Errou", `COMBAT_MISS`). `get_combat_stats` inclui `luk` (monstro: 0) e a `dex` do monstro (`MonsterStage.dex`, -1 = automática por nível).

**Monstros raros:** ao (re)nascer numa vaga do `Spawns/`, chance `rare_base_chance × MonsterDef.rare_chance_multiplier × (1 + maior SOR dos jogadores da instância a até rare_luck_range_cells × 0,02)`. Raro: `MonsterBrain.rare`, atributos × 1,5 (ou `MonsterDef.rare_stat_multiplier`), drops com chance × 2 e +1 rolagem por linha, mais `MonsterDef.rare_extra_drops`; aviso `SYS_RARE_MONSTER_APPEARED` na instância; log `monster_rare_spawned`, `monster_killed` com `rare`/`luk`. Replicação: `NetEntity.appearance = {"rare": true}` só no nascimento (monstro nunca repassa `appearance` ao visual). Cliente: `CombatVisuals.is_rare/rare_name` (`MON_RARE_NAME_FORMAT` "%s Raro" ou `MonsterDef.rare_name_key`) + `RareVisual` (tinta dourada pulsando, aura com shader aditivo, faíscas; cor `MonsterDef.rare_tint`). Campos novos no fim de `MonsterDef`: `can_be_rare`, `rare_chance_multiplier`, `rare_name_key`, `rare_stat_multiplier`, `rare_extra_drops`, `rare_tint`; em `MonsterStage`: `dex`. Drop comum também usa a SOR de quem derrotou.

**Chefes, dia e noite e forma atroz (30/09/2026, `docs/chefes-dia-noite.md`):**

- **Evento novo de abate.** `monster_killed_info(killer_peer, monster_id, info: Dictionary)` sai em `world.combat` e em
  `CombatEvents.bus()`, logo depois de `monster_killed`. O `info` traz `stage` (1..3; a forma atroz conta como 3),
  `form_stage` (1..4), `boss`, `atroz`, `rare`, `escort`, `entity_id`, `instance_id`, `map_id`, `level`, `xp` e
  `killer_peer`. Durante a emissão de `monster_killed`, o mesmo dicionário está em `world.combat.last_kill` e em
  `CombatEvents.bus().last_kill`. As assinaturas antigas não mudaram.
- **Forma atroz.** É o `MonsterStage` com `stage = 4`. O `NetEntity.stage` fica em 4 e `appearance["atroz"] = true`.
- **Relógio.** O autoload `DayNight` responde `is_night_on_map(map_id)`.
- **Chefes fixos (30/09/2026).** Ficam em `BossLairs/` do mapa (`MonsterSpawner._install_lairs`), cada um com bando fixo, e renascem em `Balance.boss_respawn_sec`. Não há evolução nem chefe por contagem de abates.

**Flags de teste (servidor):** `--force-rare=<id,id|all>` (vagas dessas espécies nascem raras); `--always-hit` (todo físico acerta, menos contra DES ≥ `DamageFormula.TEST_EVASIVE_DEX` — o `test_dodger` das fixtures). Os autotestes de combate e de progressão usam `--always-hit` para ficarem determinísticos.

**Mestres no nível 10 (GDD §9.3):** `data/title_talks/<npc_id>.tres` (`TitleTalkDef`; `Content.all(&"title_talks")`) para os 11 Mestres do Campo + Brisa e Orvalho. `TitleTalk` (servidor) acrescenta no primeiro nó a opção `RULES_TT_OPTION` com a condição `min_level` do DialogueRunner (escondida abaixo do 10) e gera 3 falas (título e descrição; estilo + skills de `TitleDef.required_skills`→`SkillDef.name_key`; cidade de `TitleDef.start_map_id` ou "travessia fechada" com `REGION_<ID>_NAME`). Ação de diálogo `title_talk` (`action_args {talk, page}`). Textos com argumentos vão ao cliente como `"CHAVE|arg|arg"` (arg `A,B` = lista), resolvidos por `DialogueBox.resolve_text`. Textos em `localization/rules.csv`.

**Engrenagem (GDD §9.5):** `GameUI.gear` (`GearMenu`, canto inferior direito): botão de engrenagem abre o menu vertical (ícone + nome + atalho) com Skills (K), Atributos (A), Missões (L), Inventário (I), Personagem (C), Menu (Esc); botão de carinha abre os emotes (Alt+1..6). `GameUI.add_menu_entry(key, hotkey, icon_id, callable, index)`; `hud_buttons` agora é o `VBoxContainer` das entradas. Ícones: `MenuIcons` (pixel-art em código). Esc fecha o menu antes das janelas. Sem som de interface.
