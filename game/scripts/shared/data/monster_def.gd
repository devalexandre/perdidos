class_name MonsterDef
extends Resource
## Espécie de monstro com 3 estágios (GDD §10.3, §10.6). data/monsters/<id>.tres
## Estágios 1 (normal), 2 (médio) e 3 (chefe do covil); stage 4 = forma atroz (ver atroz_stat_multiplier).
const EVOLUTION_MAX_STAGE: int = 3
const ATROZ_STAGE: int = 4

const CREATURE_DEFAULT: StringName = &""
const CREATURE_WEREWOLF: StringName = &"werewolf"
const CREATURE_UNDEAD: StringName = &"undead"
const CREATURE_BEAST: StringName = &"beast"

@export var id: StringName = &""
@export var region_id: StringName = &"brasil"
## Categoria ou tipo de criatura (ex.: &"werewolf", &"undead", &"beast").
@export var creature_type: StringName = &""
@export var stages: Array[MonsterStage] = []
## Respawn após morrer (s): comuns 30 (GDD §10.3).
@export var respawn_sec: float = 30.0

## --- Variante rara (Agente R, GDD §10.2, 27/09/2026). Tudo opcional: vazio/0 = padrão do Balance.
## false = esta espécie nunca surge rara (ex.: bonecos de provação).
@export var can_be_rare: bool = true
## Multiplica a chance de raro (Balance.cfg.rare_base_chance) só desta espécie.
@export var rare_chance_multiplier: float = 1.0
## Nome próprio da variante rara (chave de tradução). Vazio = prefixo "Raro" + nome do estágio.
@export var rare_name_key: String = ""
## Multiplicador dos atributos da variante rara. 0 = Balance.cfg.rare_stat_multiplier.
@export var rare_stat_multiplier: float = 0.0
## Drops a mais que só a variante rara rola (além da tabela do estágio, que já vem melhorada).
@export var rare_extra_drops: Array[DropEntry] = []
## Cor do brilho da variante rara. Alfa 0 = dourado padrão.
@export var rare_tint: Color = Color(0, 0, 0, 0)

## --- Forma atroz (TITULOS-E-SKILLS §3.0 item 5, GDD §10.7). É o MonsterStage com stage = 4 em `stages`
## (MonsterEvolution.STAGE_ATROZ): nome, folhas (_s4), nível, agressividade (aggro/leash/intervalo do golpe/
## passo), XP, Estrelas e drops. Vida/ATQ/ATQM/DEF/DEFM NÃO vêm dele: são os do chefe (estágio 3) × este
## multiplicador. 0 = Balance.cfg.atroz_stat_multiplier (+100%).
@export var atroz_stat_multiplier: float = 0.0

## --- Variante regional (beta, 30/09/2026): espécie original desta variante (ex.: highland_stone_armadillo →
## stone_armadillo). Vazio = a própria espécie. Quests (lições e anciãos) contam a variante como a espécie original.
@export var base_species: StringName = &""


## Espécie para as quests: base_species, ou o próprio id.
func species_id() -> StringName:
	return base_species if not base_species.is_empty() else id


## Espécie para as quests de um id de monstro (variante regional → original; id desconhecido = ele mesmo).
static func species_of(monster_id: StringName) -> StringName:
	var d: MonsterDef = Content.monster(monster_id) if Content != null else null
	return d.species_id() if d != null else monster_id


## MonsterStage da forma atroz (stage 4) ou null.
func atroz_stage() -> MonsterStage:
	for st: MonsterStage in stages:
		if st.stage == ATROZ_STAGE:
			return st
	return null


## Criatura do tipo lobisomem (pelo creature_type ou espécies conhecidas).
func is_werewolf() -> bool:
	return creature_type == CREATURE_WEREWOLF \
			or id == &"werewolf" or id == &"cave_werewolf" \
			or base_species == &"werewolf" or base_species == &"cave_werewolf"


## Criatura do tipo morto-vivo (pelo creature_type ou espécies conhecidas).
func is_undead() -> bool:
	return creature_type == CREATURE_UNDEAD \
			or id == &"hopping_jiangshi" or id == &"corpo_seco" \
			or base_species == &"hopping_jiangshi" or base_species == &"corpo_seco"


## Vulnerável a armas e munições de prata no folclore (+10% de dano).
func is_vulnerable_to_silver() -> bool:
	return is_werewolf() or is_undead()


## Vulnerável a magias de luz e sagrado no folclore (+20% de dano).
func is_vulnerable_to_holy() -> bool:
	return is_werewolf() or is_undead()
