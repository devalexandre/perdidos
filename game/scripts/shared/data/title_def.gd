class_name TitleDef
extends Resource
## Título regional (GDD §8.5, TITULOS-E-SKILLS.md). data/titles/<id>.tres
@export var id: StringName = &""
@export var name_key: String = ""
@export var region_id: StringName = &"brasil"
@export var archetype: StringName = &""        # &"blade", &"arcane", &"bow", ...
@export var tier: int = 1
@export var parent_title: StringName = &""
@export var branch: StringName = &""
## Conquistado automaticamente ao conhecer TODAS estas skills e ter estes títulos.
@export var required_skills: Array[StringName] = []
@export var required_titles: Array[StringName] = []
## Título inicial: cidade onde o jogador começa ao sair do Campo de Treino (GDD §9.3).
@export var start_map_id: StringName = &""
@export var color: Color = Color.WHITE
## --- Campos acrescentados por Q ---
@export var desc_key: String = ""
@export var sort_order: int = 0
@export var is_hybrid: bool = false

## Traje deste título. Vazio enquanto não houver folhas completas e alinhadas para ambos os corpos.
## Cosmético de corpo tem prioridade; estatísticas continuam vindo do equipamento real.
@export var outfit_id: StringName = &""
## Skills de ofício concedidas com o título, FORA da árvore de 5 (ex.: Fazer Flechas no título inicial do
## arco). Títulos de ramo herdam as dos ancestrais (TitleService).
@export var bonus_skills: Array[StringName] = []
## Roupa do título sobre o Viajante: [tecido, detalhe] (mesmo recolor da nacionalidade, CharacterLayers.cloth_for).
## Vale por cima da cor da nacionalidade assim que o título é exibido. Vazio = sem troca.
@export var cloth_colors: PackedColorArray = PackedColorArray()

## --- Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3.0 regras 3–5) ---
## Título de combinação: NÃO é automático. required_titles/required_skills só descrevem (pistas);
## ele vem da quest do ancião (QuestDef.reward_title).
@export var quest_only: bool = false
## Mestre ou ancião que ensina a árvore deste título (npc id; a janela de skills mostra o nome).
@export var master_npc: StringName = &""

## Arquétipos principais do jogo (GDD §8.5, TITULOS-E-SKILLS.md §3.1)
const ARCHETYPE_TANK: StringName = &"tank"
const ARCHETYPE_BLADE: StringName = &"blade"
const ARCHETYPE_BOW: StringName = &"bow"
const ARCHETYPE_ARCANE: StringName = &"arcane"
const ARCHETYPE_HYBRID: StringName = &"hybrid"
const ARCHETYPE_SUPPORT: StringName = &"support"

const GROUP_TANK: StringName = &"tank"
const GROUP_AGILE: StringName = &"agile"
const GROUP_ARCANE: StringName = &"arcane"
const GROUP_SHAMANIC: StringName = &"shamanic"


## Retorna o grupo canônico dos 4 arquétipos principais
func get_archetype_group() -> StringName:
	match archetype:
		ARCHETYPE_TANK:
			return GROUP_TANK
		ARCHETYPE_BLADE, ARCHETYPE_BOW:
			return GROUP_AGILE
		ARCHETYPE_ARCANE, ARCHETYPE_HYBRID:
			return GROUP_ARCANE
		ARCHETYPE_SUPPORT:
			return GROUP_SHAMANIC
		_:
			return &""


## Código para uniforms de shaders (1: Tanque, 2: Ágil, 3: Arcano, 4: Xamânico)
func get_archetype_code() -> int:
	match get_archetype_group():
		GROUP_TANK: return 1
		GROUP_AGILE: return 2
		GROUP_ARCANE: return 3
		GROUP_SHAMANIC: return 4
		_: return 0


## Retorna se o título é sagrado / de suporte xamânico / curandeiro.
func is_holy_or_sacred() -> bool:
	if archetype in [ARCHETYPE_SUPPORT, GROUP_SHAMANIC, &"holy", &"sacred"]:
		return true
	var sid: String = String(id).to_lower()
	if "support" in sid or "holy" in sid or "sacred" in sid or "curandeiro" in sid or "shaman" in sid:
		return true
	return false


## Helper estático para identificar se um ID de título é sagrado.
static func is_holy_title_id(title_id: StringName) -> bool:
	if title_id.is_empty():
		return false
	var t: TitleDef = Content.title(title_id)
	if t != null:
		return t.is_holy_or_sacred()
	var s: String = String(title_id).to_lower()
	return "support" in s or "holy" in s or "sacred" in s or "curandeiro" in s or "shaman" in s

