class_name QuestStep
extends Resource
## Etapa de quest (GDD §9.1).
enum StepType { KILL, COLLECT, EXPLORE, TALK, TRIAL, WAIT, NAME_COMPANION }
@export var type: StepType = StepType.KILL
@export var target_id: StringName = &""        # monster id / item id / marker name / npc id / trial id
@export var count: int = 1
@export var required_stage: int = 0
@export var requires_night: bool = false
@export var requires_day: bool = false
@export var requires_hidden: bool = false
@export var wait_sec: float = 10.0
@export var allow_purchased: bool = false
@export var text_key: String = ""
## KILL/COLLECT: dificuldade de quests de título aumenta com os títulos já conquistados.
@export var scale_with_titles: bool = true
## Etapa de veterano (quests de título): só entra quando o personagem já tem pelo menos N títulos
## (fora o de chegada). 0 = sempre. Ex.: 1 = relíquias, 2 = chefe do covil, 3 = forma atroz.
@export var min_prior_titles: int = 0
## TALK de sub-história: o NPC ganha a opção lore_option_key (vazio = QUEST_OPT_HEAR_LORE) que conta
## lore_text_key; a etapa só conclui ao ouvir. Vazio = conclui só de puxar conversa.
@export var lore_text_key: String = ""
@export var lore_option_key: String = ""
## --- Campos acrescentados por Q ---
## EXPLORE: raio (células) em volta do marcador/ponto que conta como "chegou".
@export var radius_cells: float = 3.0
## EXPLORE: só conta quando o mapa está em noite de lua cheia.
@export var requires_full_moon: bool = false
## TRIAL: segundos para vencer a provação (0 = sem limite).
@export var time_limit_sec: float = 0.0
## TRIAL: destino reservado à provação; vazio mantém a prova no mapa atual.
@export var trial_map_id: StringName = &""
## TRIAL: estágio do monstro da provação (padrão 1).
@export var trial_stage: int = 1
## TRIAL: só pode começar numa noite de lua cheia no mapa de destino.
@export var trial_requires_full_moon: bool = false

## --- Terra do Sabiá v0.4 (quests de combinação, TITULOS-E-SKILLS.md §3.3) ---
## KILL: variante exigida do monstro. &"any" (padrão), &"rare" (variante rara), &"boss" (estágio 3,
## CombatRules.STAGE_BOSS) ou &"atroz" (chefe na forma atroz da noite: MonsterBrain.atroz).
## target_id vazio = qualquer espécie.
@export var variant: StringName = &"any"
## KILL: só conta espécies ainda não contadas nesta etapa ("2 chefes de espécies diferentes").
@export var distinct_species: bool = false
## KILL: só conta se quem derrotou não caiu desde o primeiro golpe nesse monstro.
@export var no_death: bool = false
## TRIAL: &"kill" (padrão: derrubar o alvo no tempo), &"protect" (ver abaixo) ou &"survive" (aguentar vivo até o fim do
## tempo contra trial_spawn_count monstros target_id, em ondas a cada trial_wave_sec; 0 = uma onda).
@export var trial_mode: StringName = &"kill"
@export var trial_spawn_count: int = 1
@export var trial_wave_sec: float = 0.0
## TRIAL &"protect" (Vó Aninha, TITULOS-E-SKILLS.md §3.3): nascem protect_count protegidos protect_target
## (MonsterDef, ex. &"pequi_seedling") perto do jogador; as ondas de target_id atacam eles de preferência.
## Sucesso: pelo menos protect_min_alive vivos no fim do tempo. Falha: menos que isso vivos.
@export var protect_target: StringName = &""
@export var protect_count: int = 3
@export var protect_min_alive: int = 1
