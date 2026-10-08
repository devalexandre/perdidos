class_name EntityVisualFactory
extends RefCounted
## Cria o visual (EntityVisual) de qualquer entidade de rede a partir das propriedades replicadas
## do contrato (entity_id, kind, display_name, def_id). Lê as propriedades com get() para não
## depender da classe concreta (NetEntity de A ou o PlayerEntity antigo).

const KIND_PLAYER: StringName = &"player"
const KIND_NPC: StringName = &"npc"
const TARGET_ENTITY_PREFIX: String = "e:"
const TARGET_MAP_PREFIX: String = "m:"
const VISUAL_NODE_NAME: StringName = &"Visual"
const DEFAULT_BODY: StringName = &"male"
## Gestos ocasionais de todo NPC (só visual, 08/10/2026).
const NPC_GESTURES: Script = preload("res://scripts/client/npc_gestures.gd")

## Fornecedor de NpcDef (testes trocam por dados falsos). Vazio = autoload Content.
static var npc_provider: Callable = Callable()


## Visual pronto (ainda sem pai). O chamador adiciona como filho da entidade.
static func create(entity: Node) -> Node3D:
	# Monstros e itens no chão (contrato arrival, K): visual em scripts/client/combat/.
	if CombatVisuals.handles(entity):
		return CombatVisuals.create(entity)
	var v := EntityVisual.new()
	v.name = VISUAL_NODE_NAME
	var kind: StringName = StringName(_prop(entity, &"kind", KIND_PLAYER))
	var def_id: StringName = StringName(_prop(entity, &"def_id", _prop(entity, &"body_type", DEFAULT_BODY)))
	var entity_id: int = int(_prop(entity, &"entity_id", _prop(entity, &"peer_id", 0)))
	var shown_name: String = String(_prop(entity, &"display_name", ""))
	var is_npc: bool = kind == KIND_NPC
	if is_npc:
		var def: NpcDef = _npc_def(def_id)
		if def != null:
			v.setup_sheets(def.resolved_sprite_base())
			if not def.name_key.is_empty():
				shown_name = TranslationServer.translate(def.name_key)
		else:
			push_warning("EntityVisualFactory: NpcDef '%s' não encontrado." % def_id)
			v.setup(DEFAULT_BODY)
	else:
		var body: StringName = def_id if not def_id.is_empty() else DEFAULT_BODY
		v.body_type = body
		var appearance: Variant = _prop(entity, &"appearance", {})
		var app: Dictionary = (appearance as Dictionary).duplicate() if appearance is Dictionary else {}
		if not app.has(EntityVisual.APPEARANCE_BODY) or StringName(app[EntityVisual.APPEARANCE_BODY]).is_empty():
			app[EntityVisual.APPEARANCE_BODY] = body
		v.set_appearance(app)
	var local: bool = false
	if entity != null and entity.has_method(&"is_local_player"):
		local = bool(entity.call(&"is_local_player"))
	v.setup_entity(entity_target_id(entity_id), shown_name, is_npc, local)
	if is_npc:
		v.set_presence_def(_npc_def(def_id))
		v.add_child(NPC_GESTURES.new())
	return v


## Cria o visual a partir de dados soltos (testes, tela de título).
static func create_from(kind: StringName, def_id: StringName, entity_id: int, shown_name: String,
		local: bool = false) -> EntityVisual:
	var fake := Node.new()
	fake.set_meta(&"kind", kind)
	fake.set_meta(&"def_id", def_id)
	fake.set_meta(&"entity_id", entity_id)
	fake.set_meta(&"display_name", shown_name)
	var v: EntityVisual = create(fake) as EntityVisual
	fake.free()
	if local:
		v.setup_entity(v.target_id, v.display_name, v.is_npc, true)
	return v


static func entity_target_id(entity_id: int) -> String:
	return TARGET_ENTITY_PREFIX + str(entity_id)


static func map_target_id(interact_id: String) -> String:
	return TARGET_MAP_PREFIX + interact_id


## Extrai o entity_id de um target_id "e:<n>" (-1 se não for entidade).
static func parse_entity_id(target_id: String) -> int:
	if not target_id.begins_with(TARGET_ENTITY_PREFIX):
		return -1
	var rest: String = target_id.trim_prefix(TARGET_ENTITY_PREFIX)
	return rest.to_int() if rest.is_valid_int() else -1


static func _prop(entity: Node, prop: StringName, fallback: Variant) -> Variant:
	if entity == null:
		return fallback
	if prop in entity:
		var value: Variant = entity.get(prop)
		if value != null:
			return value
	if entity.has_meta(prop):
		return entity.get_meta(prop)
	return fallback


static func _npc_def(id: StringName) -> NpcDef:
	if npc_provider.is_valid():
		return npc_provider.call(id) as NpcDef
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var content: Node = tree.root.get_node_or_null(^"/root/Content") if tree != null else null
	if content == null:
		return null
	return content.call(&"npc", id) as NpcDef
