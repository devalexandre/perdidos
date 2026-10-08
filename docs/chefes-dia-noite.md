# Chefes, dia e noite, forma atroz e itens raros

Pedido do dono (30/09/2026): *"Os monstros atrozes são a versão do chefe, mas à noite: mais fortes e mais agressivos.
Ambos devem ter desenhos únicos e detalhados."*

Regras de origem:

- TITULOS-E-SKILLS.md §3.0 item 5 e §3.3;
- GDD §10.6 (estágios, sem evolução), §10.6.1 (chefes fixos nos covis) e §10.7 (dia e noite).

**Decisão do dono (30/09/2026):** *"vamos remover a evolução e deixar só o chefe fixo e as outras formas."* O chefe por
contagem de 500 abates e a evolução (absorver a XP de quem o monstro mata) foram removidos.

Este documento diz o que foi feito, as decisões tomadas e como testar.

---

## 1. Chefes fixos nos covis (GDD §10.6.1)

- **Regra.** Cada chefe (estágio 3) mora num **covil fixo**: um `Marker3D` dentro de `BossLairs/` na cena do mapa, um
  por chefe. Ele nasce ali com o bando fixo, 4 normais e 2 médios da espécie em volta.
- **Metas do marcador:**
  - `monster_id` (obrigatória): quem mora ali;
  - `radius_cells`: o raio da patrulha;
  - `respawn_sec`: o tempo de renascimento. O padrão é `Balance.cfg.boss_respawn_sec` = **600 s (10 min)**.
- **Derrotado:** o chefe renasce no covil depois do tempo. O bando que sobrou volta a segui-lo, e só nascem os que
  faltam. A instância recebe o aviso `SYS_BOSS_LAIR_APPEARED` ("O chefe voltou ao covil").
- **Os covis são independentes.** Vários chefes podem estar vivos no mesmo mapa.
- **Só em zonas com chefe:** `bosses_allowed` e teto de estágio 3. Nunca no Campo de Treino.
  - Os pontos comuns (`Spawns/`) nunca nascem chefe; o marcador comum fica no máximo no estágio médio.
  - O teste de dados reprova `Spawns/` que pede chefe.
- **Sem evolução.** Monstro que mata jogador não absorve XP nem muda de estágio.
- **Sem contagem de abates.** Não existe mais o `boss_kills.json`.
- **Código:** `MonsterSpawner._install_lairs`, `_lair_escort_for`, `lairs_of`, `respawn_lair_now` e
  `zone_allows_bosses`, em `scripts/server/monsters/monster_spawner.gd`.
- **Covis atuais** (gerados por `game/tools/world/build_hunt_areas.py`):

  | Mapa | Covil (marcador) | Chefe |
  |---|---|---|
  | `split_sky_plateau` (Subida Vermelha) | `highland_prank_whirlwind` (−22, −28) | Ventania do Gorro Vermelho |
  | `split_sky_plateau` | `highland_enchanted_firefly` (−1, −28) | Rainha-Lume do Brejo |
  | `split_sky_plateau` | `highland_stone_armadillo` (20, −28) | Tatu-Montanha |
  | `split_sky_plateau_ridges` (Cristas do Vento) | `highland_buriti_boar` (20, −28) | chefe da Queixada |
  | `split_sky_plateau_summit` (Alto das Brasas) | `highland_cinder_serpent` (20, −28) e `highland_ember_mule` (−22, −28) | chefes da Serpente-Fagulha e da Mula de Brasa |

  As variantes `highland_*` contam nas quests como a espécie original (`MonsterDef.base_species`). Por isso os três
  primeiros servem às quests dos anciãos:
  - Rainha-Lume do Seu Zé;
  - "um chefe" da Vó Aninha;
  - "2 chefes de espécies diferentes" e o Tatu-Pedra atroz do Velho Tião.

## 2. Dia e noite (GDD §10.7)

- **Relógio autoritativo no servidor.** O autoload `DayNight` (`scripts/shared/day_night.gd`) guarda o relógio. As
  contas puras ficam em `WorldClock` (`scripts/shared/world_clock.gd`).
- **Números no `balance_config`:**

  | Campo | Padrão | O que faz |
  |---|---|---|
  | `day_night_day_sec` | 2400 | 40 min de dia (sugestão do dono) |
  | `day_night_night_sec` | 1200 | 20 min de noite (sugestão do dono) |
  | `day_night_start_sec` | 60 | o servidor liga logo depois do amanhecer |
  | `day_night_transition_sec` | 150 | rampa da luz em cada virada |
  | `day_night_training_always_day` | `true` | Campo de Treino sempre de dia |
  | `day_night_sync_interval_sec` | 30 | intervalo de reenvio aos clientes |

- **Replicado ao cliente.** O servidor manda o estado em três momentos:
  - quando o jogador entra numa instância;
  - a cada 30 s;
  - em toda virada ou comando de teste.

  Entre as mensagens, o cliente anda o relógio sozinho. Na virada, quem está num mapa que segue o relógio recebe
  "A noite caiu…" (`SYS_NIGHT_FALLS`) ou "Amanheceu…" (`SYS_DAY_BREAKS`).
- **Luz do cliente.** Fica em `scripts/client/env/day_night_light.gd`, criado pelo `DayNight` no cliente. A luz mistura
  o "dia" da própria cena com a noite, numa rampa suave (smoothstep de 150 s centrada no anoitecer e no amanhecer):
  - o sol vira luar azul e fica mais fraco (42%), com sombra mais leve, na mesma direção;
  - ambiente, névoa e céu pintado passam para azuis de noite;
  - o brilho cai só 6% e a saturação 18%, com o contraste mantido;
  - fogueira, cristal e lampiões ficam 25% mais fortes (mais que isso avermelhava os sprites perto do fogo), respeitando a `FlickerLight`.

  O `Environment` do mapa é duplicado; o recurso em disco não muda. Os sprites seguem a luz da cena (shader
  `char_palette_swap_3d`) e continuam legíveis.
- **Campo de Treino sempre de dia**, como o dono prefere. O comando de teste que força a noite vale também ali, só para
  testes.
- **Pendência de regra do GDD §10.7:** espécies noturnas e o bônus de 30–50% dos monstros comuns à noite ainda não
  foram feitos. Só o chefe muda à noite.

## 3. Forma atroz

É o **mesmo chefe à noite**. Nos dados, é o `MonsterStage` com `stage = 4` em `MonsterDef.stages`
(`MonsterDef.atroz_stage()`).

- **Atributos +100%.** Vida, ATQ, ATQM, DEF e DEFM são os do chefe multiplicados por `Balance.cfg.atroz_stat_multiplier`
  (2,0). Cada espécie pode trocar o multiplicador em `MonsterDef.atroz_stat_multiplier`. O estágio 4 **não** guarda
  esses números.
- **O que o estágio 4 guarda:**
  - nome (`MON_<ID>_S4_NAME`);
  - folhas `_s4`;
  - nível (+6);
  - XP (×2,5) e Estrelas (×2);
  - drops melhores;
  - agressividade.
- **Mais agressiva:**
  - persegue mais longe (coleira +10 células) e enxerga mais longe (aggro +4);
  - ataca 35% mais rápido e anda 20% mais rápido;
  - **chama o bando** ao entrar em luta (`atroz_call_escort_radius_cells` = 16);
  - **prefere o jogador mais fraco:** quem tem menos vida, e no empate o de menor nível. Revê o alvo a cada
    `atroz_retarget_interval_sec` (2 s).
- **Quando vira atroz.** O chefe que surge à noite já nasce atroz. O chefe que já está vivo quando anoitece vira atroz na
  hora, mesmo em luta. A proporção da vida é mantida e a instância recebe `SYS_MONSTER_BECAME_ATROZ`.
- **Amanheceu (decisão deste agente).** Fora de combate (parada, patrulhando ou voltando para casa), a forma atroz
  **volta a ser o chefe normal** na hora. Em combate, **continua atroz até a luta acabar**, para quem começou a luta à
  noite poder terminá-la. Ela **nunca some**: o chefe é o morador fixo do covil.
- **Onde fica no código:**
  - no `MonsterBrain`: `atroz: bool`, `update_atroz()`, `set_atroz()`, `stat_stage()`, `evolution_stage()` e
    `is_boss()`;
  - nos estágios: `MonsterEvolution.STAGE_ATROZ` e `atroz_multiplier()` (o nome da classe ficou, mas não há mais
    evolução).
- **Aparência replicada:** `NetEntity.appearance["atroz"] = true` e `NetEntity.stage = 4`. O cliente já troca folha, nome
  e escala sozinho pelo estágio (`CombatVisuals.refresh_monster`), sem mexer em `scripts/client/combat/`.
- **Pendências do cliente de efeitos:** a cor da placa de nome do estágio 4 hoje é branca (`CombatVisuals.STAGE_COLORS`
  só tem 1 a 3). Uma aura noturna própria também é pendência de quem cuida de `scripts/client/combat/` e `assets/fx`.

### Espécies com forma atroz

| Espécie | Chefe (dia) | Forma atroz (noite) |
|---|---|---|
| `stone_armadillo` | Tatu-Montanha | Tatu-Montanha Atroz |
| `enchanted_firefly` | Rainha-Lume do Brejo | Rainha-Lume Atroz |
| `prank_whirlwind` | Ventania do Gorro Vermelho | Ventania Atroz do Gorro Rubro |

A arte (`mon_<id>_s4_*.png`) está descrita em `docs/arte-monstros-blender.md`, seção "Forma atroz".

As outras 18 espécies do mundo **ainda não têm chefe** (só estágios 1 e 2, `STAGES = (1, 2)`). Por isso também não têm
forma atroz. Estão pendentes as duas coisas: estágio 3 e estágio 4.

Para dar forma atroz a uma espécie nova:

1. Rode `python3 game/tools/art/content/add_atroz_stage.py <id> <item_raro>`. Ele acrescenta o estágio 4 e o item raro
   com as regras acima.
2. Renderize as folhas `_s4` pelo pipeline Blender.

## 4. Itens raros das quests de combinação (TITULOS §3.3)

| Item | Nome | Cai de | Chance: raro · chefe · atroz |
|---|---|---|---|
| `eternal_ember` | Brasa Eterna | Vaga-lume Encantado | 12% · 35% · 85% (1–2) |
| `pequi_root` | Raiz de Pequi | Redemoinho Arteiro | 12% · 35% · 85% (1–2) |
| `ancient_shell_shard` | Caco de Casco Antigo | Tatu-Pedra | 12% · 35% · 85% (1–2) |

- **Só de monstro raro, chefe ou atroz.** Os estágios 1 e 2 comuns não deixam esses itens; o teste confere.
- **Na variante rara** o item entra em `MonsterDef.rare_extra_drops`. A regra de raro da §10.2 também vale: chance ×2 e
  +1 rolagem.
- **Dados:** `data/items/<id>.tres` (raridade *Raro*, material, pilha de 99) e ícones 32×32 em `assets/items/icons/`.
  Os nomes e descrições ficam em `localization/content.csv`.

## 5. Evento de abate (para o QuestService)

As assinaturas de antes não mudaram. O `CombatService` (e o `CombatEvents.bus()`) agora também emite
`monster_killed_info(killer_peer, monster_id, info: Dictionary)`, logo depois de `monster_killed`.

Quem já liga o `monster_killed` de 4 argumentos pode ler `world.combat.last_kill` (ou `CombatEvents.bus().last_kill`)
durante a emissão.

Chaves do `info` (`CombatService.kill_info`):

| Chave | O que é |
|---|---|
| `stage` | 1 a 3; **a forma atroz conta como chefe = 3** |
| `form_stage` | 1 a 4 |
| `boss` | é o chefe |
| `atroz` | estava na forma atroz |
| `rare` | era a variante rara |
| `escort` | era do bando de um chefe |
| `entity_id`, `instance_id`, `map_id` | identificação e lugar do abate |
| `level`, `xp` | nível e XP dada |
| `killer_peer` | quem derrubou |

O `stage` do `monster_killed` antigo também passa a ser 3 para a forma atroz.

Com isso, as etapas de quest fazem assim:

- "derrotar um chefe" filtra `stage == 3` (ou `boss`);
- "derrotar um chefe em forma atroz" filtra `atroz`;
- "coletar itens raros" continua pelo inventário.

## 6. Comandos de teste do dono

Só funcionam com o servidor em `--dev-commands`, pelo `make run-dev`, ou em `--autotest`. Nunca em jogo normal.

Digite no chat do jogo. A resposta aparece como mensagem de sistema "[teste] …".

| Comando | O que faz |
|---|---|
| `/chefe [espécie [dx dz]]` | chefe extra + bando do seu lado (ou a dx,dz células), fora do covil e sem renascer; à noite já nasce atroz; só em mapa que aceita chefe |
| `/covil` · `/covil <espécie>` | lista os covis do mapa (vivo, atroz ou "renasce em N s"); com a espécie, o chefe daquele covil renasce já |
| `/atroz [espécie [dx dz]]` | sem espécie: o chefe mais perto vira atroz e **fica** (de novo = volta ao normal); com espécie ou sem chefe perto: cria um já atroz |
| `/noite` · `/dia` | força a noite ou o dia (vale também no Campo de Treino) |
| `/hora` · `/hora normal` | mostra o relógio e quanto falta para a virada; `normal` tira a força |
| `/anoitecer` · `/amanhecer` | põe o relógio 15 s antes da virada, para ver a luz mudar |
| `/derrubar [chefe]` | derruba o monstro (ou o chefe) mais perto como se fosse golpe seu: drops, XP e quests; o chefe do covil renasce no tempo normal |
| `/limpar` | tira de cena, sem drops, os chefes e bandos a até 40 m |
| `/ajuda` | lista os comandos |

A espécie pode ser o id (`stone_armadillo`) ou o apelido (`tatu`, `vagalume`, `redemoinho`). O padrão é a espécie do
monstro mais perto.

Roteiro sugerido (`make run-dev`):

1. Vá até a Subida Vermelha, o primeiro setor da Chapada. Os três covis ficam no norte do mapa.
2. Digite `/covil` para ver os chefes. Olhe o Tatu-Montanha de dia.
3. Digite `/noite`. O céu e a luz escurecem e o chefe vira o Tatu-Montanha Atroz.
4. Digite `/derrubar chefe`. O Caco de Casco Antigo cai no chão.
5. Digite `/dia`.

## 7. Testes

- `game/tests/monsters/test_night.tscn` (unitário):
  - relógio (ciclo, viradas, rampa, força, Campo de Treino);
  - estágio 4 fora dos estágios comuns;
  - `set_atroz` e `update_atroz` (+100%, proporção da vida, luta ao amanhecer, fixo, treino);
  - regra dos covis: zona, Campo de Treino, os 3 chefes de Pindorama na Subida Vermelha e nenhum `Spawns/` de chefe;
  - dados reais das 3 espécies e dos itens raros.
- `game/tests/monsters/run_night_test.sh` (integração em rede). O servidor tem drops garantidos e um covil de teste
  (`critter_lair`, renasce em 5 s). O cliente "HeroNight" confere:
  - relógio replicado;
  - chefe no covil com bando;
  - `/covil`;
  - chefe derrubado que renasce no covil com o mesmo bando;
  - nenhum resto de evolução ou de contagem no log;
  - noite e luz no cliente;
  - atroz ao nascer e ao anoitecer;
  - aparência replicada;
  - chamado do bando;
  - abate atroz com o item raro;
  - `kill_info_event` com stage, atroz e rare;
  - atroz em luta continua de manhã.

  Com `SHOTS=1` ele grava fotos.
- O `make test` roda os dois.
- `tests/combat/test_formulas.gd`: XP do abate é a do estágio e os estágios estão em ordem.
- `tests/combat/run_combat_autotest.sh`: quem mata o jogador não evolui.
- `tests/beta/test_content_links.gd`: o chefe de cada quest de ancião tem covil fixo.
- `tests/world/test_hunt_areas.gd`: covis só na Chapada.
- `tests/beta/beta_route_client.gd`: Tatu-Montanha e Rainha-Lume nos covis fixos.
