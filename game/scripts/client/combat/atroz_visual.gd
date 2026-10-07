class_name AtrozVisual
extends RareVisual
## Forma atroz (chefe à noite, TITULOS-E-SKILLS.md §3.0 regra 5): aura noturna vermelho-escura pulsando
## atrás do monstro e brasas escuras subindo. Não tinge o sprite (a forma atroz tem desenho próprio).
## Lê NetEntity.appearance["atroz"] (MonsterSpawner.APPEARANCE_ATROZ). Criado por CombatVisuals.

const ATROZ_NODE_NAME: StringName = &"AtrozFx"
const ATROZ_TINT: Color = Color(0.62, 0.06, 0.12, 1.0)
## O vento precisa de luz fria para continuar distinguível perto das fogueiras.
const WIND_TINT: Color = Color(0.35, 0.85, 1.0, 1.0)
const ATROZ_AURA_ALPHA: float = 0.4
const ATROZ_PULSE_SEC: float = 2.2


static func apply_atroz(v: DirectionalSprite3D) -> AtrozVisual:
	var fx: AtrozVisual = v.get_node_or_null(NodePath(String(ATROZ_NODE_NAME))) as AtrozVisual
	if fx == null:
		fx = AtrozVisual.new()
		fx.name = ATROZ_NODE_NAME
		fx.visual = v
		v.add_child(fx)
	fx.tint = ATROZ_TINT
	var entity := v.get_parent() as NetEntity
	if entity != null and MonsterDef.species_of(entity.def_id) == &"prank_whirlwind":
		fx.tint = WIND_TINT
	fx._rebuild()
	var mat: ShaderMaterial = fx._aura.material_override as ShaderMaterial
	mat.set_shader_parameter(&"alpha", ATROZ_AURA_ALPHA)
	mat.set_shader_parameter(&"pulse_sec", ATROZ_PULSE_SEC)
	return fx


static func remove_atroz(v: Node) -> void:
	var fx: Node = v.get_node_or_null(NodePath(String(ATROZ_NODE_NAME)))
	if fx != null:
		fx.queue_free()


## Só aura e brasas: a tinta do sprite fica com quem já cuida dela (hover, raro, morte).
func _process(delta: float) -> void:
	if visual == null:
		return
	_time += delta
	_layout()
	var entity: Node = visual.get_parent()
	var alive: bool = entity == null or not (&"hp_ratio" in entity) or float(entity.get(&"hp_ratio")) > 0.0
	_aura.visible = alive
	_sparkles.emitting = alive
