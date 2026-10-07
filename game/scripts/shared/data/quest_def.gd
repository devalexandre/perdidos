class_name QuestDef
extends Resource
## Quest de aprendizado (GDD §9). data/quests/<id>.tres. Nunca exige nível (GDD §8.4).
@export var id: StringName = &""
@export var name_key: String = ""
@export var giver_npc: StringName = &""
@export var turn_in_npc: StringName = &""      # vazio = o mesmo que deu
@export var region_id: StringName = &"brasil"
@export var steps: Array[QuestStep] = []
@export var required_skills: Array[StringName] = []
@export var required_titles: Array[StringName] = []
## Disponível no Campo de Treino (conta como "a" quest de título do treino).
@export var training_title_quest: bool = false
@export var reward_skill: StringName = &""
@export var reward_xp: int = 0
@export var reward_items: Dictionary[StringName, int] = {}
## História completa que concede um Causo (id único e persistente, não moeda gastável).
@export var reward_causo_id: StringName = &""
## Final narrativo do arco: &"killed", &"healed" ou &"pacted".
@export var reward_story_ending: StringName = &""
@export var hidden_until_eligible: bool = true
## --- Campos acrescentados por Q (marco "Chegada do Viajante") ---
## Título concedido ao concluir (quests de título do Campo de Treino, GDD §9.3).
@export var reward_title: StringName = &""
## Falas do Mestre (chaves de tradução): oferta, "ainda não terminou" e conclusão.
@export var offer_text_key: String = ""
@export var progress_text_key: String = ""
@export var complete_text_key: String = ""
## Texto da opção no diálogo do Mestre e descrição no diário.
@export var option_text_key: String = ""
@export var desc_key: String = ""
## Requisitos de conhecimento (nunca nível de personagem, GDD §8.4).
@export var required_quests: Array[StringName] = []
@export var required_skill_levels: Dictionary[StringName, int] = {}
## Pistas orais exigidas antes de oferecer a quest; não concedem Causos.
@export var required_story_id: StringName = &""
@export var required_story_clues: int = 0
## Rota do arco exigida pelo desfecho.
@export var required_story_route: StringName = &""
## Observações únicas em noites de lua cheia, usadas pela Rota C.
@export var required_story_observations: int = 0
## Renome mínimo (pontos de Causo) para a sub-história aparecer. Nunca nível (GDD §8.4).
@export var required_causos: int = 0
@export var requires_left_training: bool = false
@export var reward_companion: StringName = &""
@export var reward_mount: StringName = &""
@export var turn_in_stars: int = 0
