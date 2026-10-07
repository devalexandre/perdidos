class_name ItemStack
extends RefCounted
## Uma pilha de itens num espaço (inventário, equipamento, e depois armazém/túmulo/drop).
## item_id aponta para um ItemDef (Content.item). "protected" é a infraestrutura do GDD §12.4
## (nenhuma proteção ativa no MVP).

const KEY_ITEM: String = "item"
const KEY_QTY: String = "qty"
const KEY_PROTECTED: String = "protected"
## Mapa onde o item foi obtido quando esse mapa prende itens (Campo de Treino, GDD §9.3); some ao sair.
const KEY_BOUND_ZONE: String = "bound_zone"
const KEY_CRENDICES: String = "crendices"
const KEY_DORMANT: String = "dormant"

var item_id: StringName = &""
var qty: int = 0
var protected: bool = false
## map_id do mapa que prende este item (&"" = livre). Ver ZoneRules (Agente N).
var bound_zone: StringName = &""
## Sistema de Crendices: lista de IDs dos amuletos inseridos nos encaixes.
var crendices: Array[StringName] = []
## Lista de booleanos indicando se o amuleto correspondente está adormecido.
var dormant_crendices: Array[bool] = []


static func create(p_item_id: StringName, p_qty: int) -> ItemStack:
	var s := ItemStack.new()
	s.item_id = p_item_id
	s.qty = p_qty
	return s


func get_def() -> ItemDef:
	return Content.item(item_id)


## Quantidade de Encaixes de Crendice máximos deste item.
func get_max_sockets() -> int:
	var def: ItemDef = get_def()
	return def.get_crendice_sockets() if def != null else 0


## Máximo por pilha deste item (1 se não empilha).
func get_max_stack() -> int:
	return ItemStack.max_stack_of(item_id)


static func max_stack_of(p_item_id: StringName) -> int:
	var def: ItemDef = Content.item(p_item_id)
	if def == null or not def.stackable:
		return 1
	return maxi(def.max_stack, 1)


## Formato do contrato para o cliente: {"item": StringName, "qty": int, ...}.
func to_client() -> Dictionary:
	var d: Dictionary = {KEY_ITEM: item_id, KEY_QTY: qty}
	var max_s: int = get_max_sockets()
	if max_s > 0:
		d["max_sockets"] = max_s
	if not crendices.is_empty():
		d[KEY_CRENDICES] = crendices
	if not dormant_crendices.is_empty():
		d[KEY_DORMANT] = dormant_crendices
	return d


func to_save() -> Dictionary:
	var d: Dictionary = {KEY_ITEM: String(item_id), KEY_QTY: qty, KEY_PROTECTED: protected}
	if not bound_zone.is_empty():
		d[KEY_BOUND_ZONE] = String(bound_zone)
	if not crendices.is_empty():
		var arr: Array = []
		for c: StringName in crendices:
			arr.append(String(c))
		d[KEY_CRENDICES] = arr
	if not dormant_crendices.is_empty():
		d[KEY_DORMANT] = dormant_crendices.duplicate()
	return d


## Nova pilha do mesmo item e com as mesmas marcas (proteção, zona, crendices), com outra quantidade.
func copy_with_qty(p_qty: int) -> ItemStack:
	var s := ItemStack.create(item_id, p_qty)
	s.protected = protected
	s.bound_zone = bound_zone
	s.crendices = crendices.duplicate()
	s.dormant_crendices = dormant_crendices.duplicate()
	return s


static func from_save(d: Dictionary) -> ItemStack:
	if typeof(d.get(KEY_ITEM)) != TYPE_STRING or not (d.get(KEY_QTY) is float or d.get(KEY_QTY) is int):
		return null
	var s := ItemStack.create(StringName(d[KEY_ITEM]), int(d[KEY_QTY]))
	s.protected = bool(d.get(KEY_PROTECTED, false))
	s.bound_zone = StringName(str(d.get(KEY_BOUND_ZONE, "")))
	if d.has(KEY_CRENDICES) and d[KEY_CRENDICES] is Array:
		for c in d[KEY_CRENDICES]:
			s.crendices.append(StringName(str(c)))
	if d.has(KEY_DORMANT) and d[KEY_DORMANT] is Array:
		for b in d[KEY_DORMANT]:
			s.dormant_crendices.append(bool(b))
	return s if s.qty > 0 else null

