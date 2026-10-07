class_name CombatRules
extends RefCounted
## Constantes [PROVISÓRIO] do combate (GDD §6.4, §10.2, §10.3, §10.5, §10.6, §12). Candidatas a
## migrar para o Balance (relatório de K). Nenhum número mágico no código de combate: tudo daqui.

enum DamageType { PHYSICAL, MAGIC, TRUE }

# ---------------------------------------------------------------- GDD §10.2 (fórmulas)
## Divisor da redução por defesa: dano × 100 / (100 + DEF).
const DEFENSE_CONSTANT: float = 100.0
## Variação aleatória ±10%.
const DAMAGE_VARIANCE: float = 0.10
## Crítico (só físico): chance vem da Sorte (Balance.cfg.crit_base_chance/crit_chance_per_luk,
## GDD §10.2 rev. 27/09/2026); dano ×1,5. Acerto/esquiva por DES: Balance.cfg.hit_*.
const CRIT_MULTIPLIER: float = 1.5
## Velocidade do ataque básico: 1,0 + DES × 0,01 ataques/s, máximo 2,5.
const ATTACK_SPEED_BASE: float = 1.0
const ATTACK_SPEED_PER_DEX: float = 0.01
const ATTACK_SPEED_MAX: float = 2.5
## Todo golpe que acerta tira pelo menos isto.
const MIN_DAMAGE: int = 1
const MSEC_PER_SEC: float = 1000.0

# ---------------------------------------------------------------- Folclore do 1º Arco
## Bônus de prata contra criaturas vulneráveis (lobisomem e morto-vivo: +10%).
const SILVER_DAMAGE_BONUS: float = 0.10
const SILVER_BONUS_MULTIPLIER: float = 1.10
## Bônus de magias de luz e sagrado contra criaturas vulneráveis (lobisomem e morto-vivo: +20%).
const HOLY_LIGHT_DAMAGE_BONUS: float = 0.20
const HOLY_LIGHT_BONUS_MULTIPLIER: float = 1.20

# ---------------------------------------------------------------- GDD §6.4 (vida e mana)
## "Fora de combate" = Balance.cfg.out_of_combat_sec (6 s) sem causar nem receber dano.
## Regeneração por período de 5 s: vida 2 + VIT × 0,5 (só fora de combate); mana 1 + ESP × 0,6.
const REGEN_PERIOD_SEC: float = 5.0
const HP_REGEN_BASE: float = 2.0
const HP_REGEN_PER_VIT: float = 0.5
const MP_REGEN_BASE: float = 1.0
const MP_REGEN_PER_SPI: float = 0.6

# ---------------------------------------------------------------- ataque básico (GDD §10.1)
## Alcance do ataque básico sem arma ou com arma de lâmina (células; 1,5 cobre a diagonal).
const BASIC_MELEE_RANGE_CELLS: float = 1.5
## Arma do Arcano: ataque básico mágico à distância [PROVISÓRIO — decisão de K, GDD não define].
const BASIC_RANGED_RANGE_CELLS: float = 5.0
## Arco (Terra do Sabiá v0.4, TITULOS-E-SKILLS.md §3.4 "Flecha do Cerrado"): ataque básico físico à distância.
const BASIC_BOW_RANGE_CELLS: float = 8.0
## Clique em alvo mais longe do que isto (células) é recusado ("fora de alcance").
const ATTACK_MAX_ENGAGE_CELLS: float = 20.0
## Folga (células) antes de voltar a perseguir quem saiu do alcance (evita "pisca" na borda).
const RANGE_SLACK_CELLS: float = 0.25
## Sem caminho até um alvo a até (alcance + isto) células: ele está no meio de um passo; espera
## o próximo recálculo em vez de desistir.
const CHASE_WAIT_CELLS: float = 1.5
## Intervalo mínimo entre recálculos de caminho atrás de um alvo que anda (ms).
const REPATH_INTERVAL_MSEC: int = 300

# ---------------------------------------------------------------- monstros (GDD §10.3, §10.6)
## entity_id: monstro = MONSTER_ID_BASE + n; item no chão = DROP_ID_BASE + n (NPC = 1 000 000 + n).
const MONSTER_ID_BASE: int = 2000000
const DROP_ID_BASE: int = 3000000
## O corpo fica na tela para a animação de morte antes de sumir (s).
const MONSTER_DEATH_LINGER_SEC: float = 1.5
## Chance de crítico dos monstros (não têm SOR).
const MONSTER_CRIT_CHANCE: float = 0.05
## Estágios: 1 normal, 2 médio, 3 chefe. Campo de Treino: teto no médio (GDD §9.3).
const STAGE_NORMAL: int = 1
const STAGE_MEDIUM: int = 2
const STAGE_BOSS: int = 3
const TRAINING_MONSTER_STAGE_CAP: int = 2
## Bando do chefe nasce num anel com este raio (células) em volta dele.
const ESCORT_RING_CELLS: float = 2.5
## Patrulha: pausa entre passeios (s) e tentativas de sortear um ponto andável.
const PATROL_PAUSE_MIN_SEC: float = 2.0
const PATROL_PAUSE_MAX_SEC: float = 5.0
const PATROL_PICK_ATTEMPTS: int = 6
## Raio de patrulha padrão (células) quando o marcador não define radius_cells.
const DEFAULT_ROAM_CELLS: float = 4.0
## Distância (células) da origem em que o retorno é considerado concluído.
const HOME_EPSILON_CELLS: float = 1.5
## Busca de célula andável ao nascer (células).
const SPAWN_SNAP_CELLS: int = 6

# ---------------------------------------------------------------- drops (GDD §10.5)
## Itens no chão somem depois de 60 s.
const DROP_LIFETIME_SEC: float = 60.0
## Espalha os itens em volta do corpo (células).
const DROP_SCATTER_CELLS: int = 1

# ---------------------------------------------------------------- morte do jogador (GDD §12)
## Sem regra de zona registrada (N), K faz o renascimento padrão depois disto (s).
const FALLBACK_RESPAWN_DELAY_SEC: float = 5.0
