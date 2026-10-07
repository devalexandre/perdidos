class_name CombatVisuals
extends RefCounted
## Visuais das entidades do combate (contrato arrival, K), chamados pelo EntityVisualFactory:
##  - monstro: EntityVisual com as folhas do estágio (MonsterStage.sprite_base; _idle, _walk,
##    _attack, _hit, _death), escala do estágio e nome na cor do estágio (normal branco, médio
##    laranja, chefe vermelho). Área de clique na camada 2 como qualquer entidade.
##  - item no chão: DropVisual (ícone do item + quantidade).

const KIND_MONSTER: StringName = &"monster"
const KIND_DROP: StringName = &"drop"
const META_STAGE: StringName = &"combat_stage"
const STAGE_COLORS: Dictionary[int, Color] = {
	1: Color8(252, 250, 245),
	2: Color8(245, 160, 60),
	3: Color8(230, 60, 50),
	# Forma atroz (chefe à noite, MonsterDef.atroz_stage = 4): vermelho-escuro.
	4: Color8(150, 20, 34),
}
const ATROZ_STAGE: int = 4
const META_ATROZ: StringName = &"combat_atroz"
const DEFAULT_STAGE_COLOR: Color = Color8(252, 250, 245)
## Agente R: "%s Raro" (localization/rules.csv).
const RARE_NAME_FORMAT: String = "MON_RARE_NAME_FORMAT"


static func handles(entity: Node) -> bool:
	if entity == null:
		return false
	var kind: Variant = entity.get(&"kind") if &"kind" in entity else entity.get_meta(&"kind", &"")
	return StringName(str(kind)) in [KIND_MONSTER, KIND_DROP]


static func create(entity: Node) -> Node3D:
	var kind := StringName(str(entity.get(&"kind")))
	if kind == KIND_DROP:
		var d := DropVisual.new()
		d.name = EntityVisualFactory.VISUAL_NODE_NAME
		d.setup(entity)
		return d
	var v := EntityVisual.new()
	v.name = EntityVisualFactory.VISUAL_NODE_NAME
	refresh_monster(v, entity)
	return v


## Estágio do monstro na folha/escala/nome (nascer e evoluir).
static func refresh_monster(v: EntityVisual, entity: Node) -> void:
	var def_id := StringName(str(entity.get(&"def_id")))
	var stage_number: int = int(entity.get(&"stage"))
	var def: MonsterDef = Content.monster(def_id)
	var stage: MonsterStage = null
	if def != null:
		for st: MonsterStage in def.stages:
			if st.stage == stage_number or (stage == null and st.stage == 1):
				stage = st
	var shown_name: String = String(entity.get(&"display_name"))
	if stage != null:
		v.setup_sheets(stage.sprite_base)
		shown_name = TranslationServer.translate(stage.name_key)
		v.visual_scale = stage.visual_scale
		v.life = life_profile(stage)
	else:
		push_warning("CombatVisuals: MonsterDef '%s' stage %d not found." % [def_id, stage_number])
		v.setup_sheets("")
	# Agente R (GDD §10.2): variante rara = prefixo "Raro" (ou nome próprio), brilho e faíscas.
	var rare: bool = is_rare(entity)
	if rare:
		shown_name = rare_name(def, shown_name)
	v.setup_entity(EntityVisualFactory.entity_target_id(int(entity.get(&"entity_id"))),
			shown_name, false, false)
	if rare:
		RareVisual.apply(v, def.rare_tint if def != null else Color(0, 0, 0, 0))
	var atroz: bool = is_atroz(entity) or stage_number == ATROZ_STAGE
	v.get_nameplate().modulate = STAGE_COLORS[ATROZ_STAGE] if atroz else STAGE_COLORS.get(stage_number,
			DEFAULT_STAGE_COLOR)
	if atroz:
		AtrozVisual.apply_atroz(v)
	else:
		AtrozVisual.remove_atroz(v)
	v.set_meta(META_STAGE, stage_number)
	v.set_meta(META_ATROZ, atroz)


## Forma atroz? (NetEntity.appearance["atroz"], replicado pelo MonsterSpawner enquanto dura.)
static func is_atroz(entity: Node) -> bool:
	var app: Variant = entity.get(&"appearance") if &"appearance" in entity else {}
	return app is Dictionary and bool((app as Dictionary).get(MonsterSpawner.APPEARANCE_ATROZ, false))


## Vida procedural do monstro (GDD §17.0.C): quem pula (&"hop" ou &"hop_teleport") quica e achata ao aterrissar,
## voadores (&"fly_pattern") flutuam, os demais balançam no passo e respiram com mais elasticidade que humanos.
static func life_profile(stage: MonsterStage) -> int:
	if stage == null:
		return DirectionalSprite3D.Life.MONSTER
	if stage.baked_life:
		return DirectionalSprite3D.Life.BAKED
	if &"hop" in stage.behaviors or &"hop_teleport" in stage.behaviors:
		return DirectionalSprite3D.Life.HOPPER
	if &"fly_pattern" in stage.behaviors:
		return DirectionalSprite3D.Life.FLYER
	return DirectionalSprite3D.Life.MONSTER


## Agente R: o monstro é a variante rara? (NetEntity.appearance["rare"], definido no nascimento).
static func is_rare(entity: Node) -> bool:
	var app: Variant = entity.get(&"appearance") if &"appearance" in entity else {}
	return app is Dictionary and bool((app as Dictionary).get(MonsterSpawner.APPEARANCE_RARE, false))


## Nome mostrado da variante rara: MonsterDef.rare_name_key ou "Raro" + nome do estágio.
static func rare_name(def: MonsterDef, stage_name: String) -> String:
	if def != null and not def.rare_name_key.is_empty():
		return TranslationServer.translate(def.rare_name_key)
	return TranslationServer.translate(RARE_NAME_FORMAT) % stage_name
