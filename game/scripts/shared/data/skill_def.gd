class_name SkillDef
extends Resource
## Skill em dados (GDD §8). data/skills/<id>.tres. Aprendida só por quest; sobe com pontos de skill.
enum TargetType { SINGLE, GROUND_AREA, SELF_AREA, CONE, LINE, SELF, ALLY_OR_SELF }
## Efeitos. Os 7 primeiros são do MVP (valores fixos nos .tres existentes: só acrescentar no fim).
## Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3.5): efeitos genéricos, parâmetros em `extra`
## (ver SkillCaster, constantes X_*). Todo efeito de dano aceita "riders" em extra (stun_sec,
## root_sec, knockback_cells, pull_cells, dash, dot_mult/dot_sec, crit_bonus, def_ignore...).
enum Effect { PHYSICAL_DAMAGE, MAGIC_DAMAGE, DAMAGE_OVER_TIME, SHIELD, BUFF_DEF, DASH_STUN, SLOW,
		HEAL, HOT, BUFF, DEBUFF, TAUNT, ROOT, STUN, MULTI_HIT, KNOCKBACK, PULL, BACKSTEP, BLINK,
		COUNTER, STEALTH, CLEANSE, MP_RESTORE, CRAFT, STEAL }
@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var icon: Texture2D
@export var school: StringName = &""          # &"blade", &"arcane", ...
## Elemento mágico / dano elemental (ex.: &"light", &"holy", &"fire").
@export var element: StringName = &""
@export var region_id: StringName = &"brasil"
@export var target_type: TargetType = TargetType.SINGLE
@export var effect: Effect = Effect.PHYSICAL_DAMAGE
@export var mana_cost: int = 10
@export var cooldown_sec: float = 5.0
@export var cast_time_sec: float = 0.0
@export var range_cells: float = 1.5
@export var radius_cells: float = 0.0          # áreas
@export var cone_deg: float = 0.0
@export var line_length_cells: float = 0.0
@export var line_width_cells: float = 0.0
@export var base_multiplier: float = 1.0       # 1.5 = 150% ATK/MATK
@export var multiplier_per_level: float = 0.1
@export var duration_sec: float = 0.0          # buffs, lentidão, DoT, escudo
@export var extra: Dictionary[StringName, Variant] = {}   # parâmetros específicos (stun_sec, slow_pct, def_pct…)
@export var requires_melee_weapon: bool = false
## Precisa de arco equipado (escola &"bow", ItemDef.WeaponKind.BOW).
@export var requires_bow: bool = false
@export var max_level: int = 10
@export var vfx: StringName = &""
@export var sfx: StringName = &""
## --- Campos acrescentados por Q (marco "Chegada do Viajante") ---
## Exclusiva de título (TITULOS-E-SKILLS.md §6.1): a quest só aparece/é aceita com este título.
@export var exclusive_to_title: StringName = &""
## Texto curto do ícone enquanto não houver arte (assets/skills/). Vazio = começo do nome.
@export var icon_text: String = ""
## Aviso visual no chão antes do impacto (s), além do tempo de conjuração (Queda Estelar).
@export var ground_warning_sec: float = 0.0
## Não conta para conquistar títulos (exclusivas do MVP, TITULOS-E-SKILLS.md §3.2).
@export var counts_for_titles: bool = true
## --- Árvores por título (TITULOS-E-SKILLS.md §3.0 e §3.4, v0.4) ---
## Título cuja árvore mostra esta skill (pode diferir de exclusive_to_title: a skill-porta de um ramo
## é aprendida com o título pai e aparece na árvore do ramo).
@export var tree_title: StringName = &""
## Posição na árvore (1..5).
@export var tree_order: int = 0
## Pré-requisitos na árvore: skill_id -> nível mínimo. Conferidos ao aprender, na quest e ao gastar pontos.
@export var required_skill_levels: Dictionary[StringName, int] = {}
@export var passive: bool = false
@export var companion_id: StringName = &""


## Pré-requisitos que faltam para quem tem estes níveis de skill: [[skill_id, nível pedido], ...].
func missing_prerequisites(levels: Dictionary) -> Array:
	var out: Array = []
	for s: StringName in required_skill_levels:
		var have: int = int(levels.get(s, levels.get(String(s), 0)))
		if have < required_skill_levels[s]:
			out.append([s, required_skill_levels[s]])
	return out


## Verifica se a skill pertence ao elemento luz ou sagrado (folclore contra lobisomens e mortos-vivos).
func is_holy_or_light() -> bool:
	if element in [&"light", &"holy", &"luz", &"sagrado"]:
		return true
	var extra_elem: Variant = extra.get(&"element", &"")
	if extra_elem is StringName or extra_elem is String:
		if StringName(extra_elem) in [&"light", &"holy", &"luz", &"sagrado"]:
			return true
	if school in [&"holy", &"light"]:
		return true
	if id in [&"holy_light", &"arcane_star_fall", &"arcane_crystal_glow"]:
		return true
	return false
