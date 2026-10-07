class_name Equipment
extends RefCounted
## Os espaços de equipamento + 3 espaços cosméticos (contrato city-walk, ADENDO 1).
## Não mexe no inventário: quem troca itens entre os dois é o ItemService. Cosméticos só entram
## nos espaços cosmetic_* (e só eles entram lá) e nunca dão atributos; o visual resultante
## (appearance) é calculado por get_appearance().

signal changed

const WEAPON: StringName = &"weapon"
const OFFHAND: StringName = &"offhand"
const HEAD: StringName = &"head"
const BODY: StringName = &"body"
const GLOVES: StringName = &"gloves"
const FEET: StringName = &"feet"
const ACCESSORY_1: StringName = &"accessory_1"
const ACCESSORY_2: StringName = &"accessory_2"
const COSMETIC_HEAD: StringName = &"cosmetic_head"
const COSMETIC_BODY: StringName = &"cosmetic_body"
const COSMETIC_WEAPON: StringName = &"cosmetic_weapon"
## Os espaços que dão atributos.
const GEAR_SLOTS: Array[StringName] = [WEAPON, OFFHAND, HEAD, BODY, GLOVES, FEET, ACCESSORY_1, ACCESSORY_2]
const COSMETIC_SLOTS: Array[StringName] = [COSMETIC_HEAD, COSMETIC_BODY, COSMETIC_WEAPON]
const SLOTS: Array[StringName] = [WEAPON, OFFHAND, HEAD, BODY, GLOVES, FEET, ACCESSORY_1, ACCESSORY_2,
		COSMETIC_HEAD, COSMETIC_BODY, COSMETIC_WEAPON]
## Espaço normal -> espaço cosmético correspondente (itens cosméticos de cabeça/corpo/arma).
const COSMETIC_FOR: Dictionary[StringName, StringName] = {
	HEAD: COSMETIC_HEAD, BODY: COSMETIC_BODY, WEAPON: COSMETIC_WEAPON,
}
# Aparência replicada (NetEntity.appearance): chaves e roupa padrão.
const APP_BODY: StringName = &"body"
const APP_OUTFIT: StringName = &"outfit"
const APP_HEAD: StringName = &"head"
const APP_WEAPON: StringName = &"weapon"
const APP_OFFHAND: StringName = &"offhand"
## Item real da mão principal (não o visual cosmético): cada arma tem o próprio som (GDD §10.2.1).
const APP_WEAPON_ITEM: StringName = &"weapon_item"
const DEFAULT_OUTFIT: StringName = &"traveler"
## ItemDef.get_equip_slot() devolve &"accessory" para os dois espaços de acessório.
const ACCESSORY_KIND: StringName = &"accessory"

var _slots: Dictionary[StringName, ItemStack] = {}


func _init() -> void:
	for s: StringName in SLOTS:
		_slots[s] = null


static func is_valid_slot(slot: StringName) -> bool:
	return slot in SLOTS


func get_slot(slot: StringName) -> ItemStack:
	return _slots.get(slot)


## Espaços possíveis para um item (vazio se não é equipável).
static func slots_for(def: ItemDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if def == null:
		return out
	var kind: StringName = def.get_equip_slot()
	if def.is_cosmetic:
		if COSMETIC_FOR.has(kind):
			out.append(COSMETIC_FOR[kind])
		return out
	if kind == ACCESSORY_KIND:
		out.append(ACCESSORY_1)
		out.append(ACCESSORY_2)
	elif is_valid_slot(kind):
		out.append(kind)
	return out


## Espaço escolhido para equipar def: o primeiro vazio entre os possíveis, senão o primeiro.
func choose_slot(def: ItemDef) -> StringName:
	var options: Array[StringName] = Equipment.slots_for(def)
	if options.is_empty():
		return &""
	for s: StringName in options:
		if _slots[s] == null:
			return s
	return options[0]


## Coloca a pilha no espaço e devolve a que estava lá (ou null).
func set_slot(slot: StringName, stack: ItemStack) -> ItemStack:
	if not is_valid_slot(slot):
		return stack
	var old: ItemStack = _slots[slot]
	_slots[slot] = stack
	changed.emit()
	return old


func equipped_stacks() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s: StringName in SLOTS:
		if _slots[s] != null:
			out.append(_slots[s])
	return out


## Pilhas que dão atributos (os 7 espaços normais; cosméticos nunca dão).
func gear_stacks() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s: StringName in GEAR_SLOTS:
		if _slots[s] != null:
			out.append(_slots[s])
	return out


## Retorna todos os amuletos engastados em equipamentos vestidos (slot, item_id, dormant, etc.).
func all_equipped_crendices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: StringName in GEAR_SLOTS:
		var st: ItemStack = _slots.get(s)
		if st == null or st.crendices.is_empty():
			continue
		for i: int in st.crendices.size():
			var cid: StringName = st.crendices[i]
			var is_d: bool = st.dormant_crendices[i] if i < st.dormant_crendices.size() else false
			out.append({
				"slot": s,
				"socket_idx": i,
				"crendice_id": cid,
				"dormant": is_d
			})
	return out


## Calcula os bônus ativos de Crendice para o contexto dado (HP, dia/noite, chuva, etc.).
func calc_crendice_bonuses(context: Dictionary = {}) -> Dictionary:
	return CrendiceSystem.calc_equipped_bonuses(self, context)



## Arma principal de prata equipada (folclore contra lobisomens e mortos-vivos).
func has_silver_weapon() -> bool:
	var w: ItemStack = get_slot(WEAPON)
	if w == null:
		return false
	var def: ItemDef = w.get_def()
	return def != null and def.silver_effective


## Algum item de prata equipado (arma, arco, aljava/flechas de prata, acessório).
func has_silver_equipped() -> bool:
	for st: ItemStack in gear_stacks():
		var def: ItemDef = st.get_def()
		if def != null and def.silver_effective:
			return true
	return false


## Retorna a munição equipada no espaço do escudo (offhand) ou null.
func get_ammo() -> ItemStack:
	var st: ItemStack = get_slot(OFFHAND)
	if st != null and st.get_def() != null and st.get_def().is_ammo:
		return st
	return null


## Verifica se há munição equipada no espaço do escudo (offhand).
func has_ammo_equipped() -> bool:
	var a: ItemStack = get_ammo()
	return a != null and a.qty > 0


## Consome munição equipada. Se acabar (qty <= 0), desocupa o espaço offhand.
func consume_ammo(amount: int = 1) -> bool:
	var st: ItemStack = get_slot(OFFHAND)
	if st == null or st.get_def() == null or not st.get_def().is_ammo or st.qty < amount:
		return false
	st.qty -= amount
	if st.qty <= 0:
		set_slot(OFFHAND, null)
	else:
		changed.emit()
	return true


func _visual_of(slot: StringName) -> StringName:
	var st: ItemStack = _slots.get(slot)
	if st == null:
		return &""
	var def: ItemDef = st.get_def()
	return def.visual_id if def != null else &""


## Visual do espaço: o cosmético correspondente, se houver, sobrepõe o equipamento real (§14.3).
func _layer(slot: StringName) -> StringName:
	var cosmetic: StringName = _visual_of(COSMETIC_FOR[slot]) if COSMETIC_FOR.has(slot) else &""
	return cosmetic if not cosmetic.is_empty() else _visual_of(slot)


## ADENDO 1: {body, outfit, head, weapon, offhand} -> visual_id (ou &""); outfit padrão traveler.
func get_appearance(body_type: StringName, title_outfit: StringName = &"") -> Dictionary:
	var outfit: StringName = _visual_of(COSMETIC_BODY)
	if outfit.is_empty():
		outfit = title_outfit if not title_outfit.is_empty() else _visual_of(BODY)
	return {
		APP_BODY: body_type,
		APP_OUTFIT: outfit if not outfit.is_empty() else DEFAULT_OUTFIT,
		APP_HEAD: _layer(HEAD),
		APP_WEAPON: _layer(WEAPON),
		APP_OFFHAND: _layer(OFFHAND),
		APP_WEAPON_ITEM: _item_id(WEAPON),
	}


func _item_id(slot: StringName) -> StringName:
	var st: ItemStack = _slots.get(slot)
	if st == null:
		return &""
	var def: ItemDef = st.get_def()
	return def.id if def != null else &""


## GDD §12.4 [EM ABERTO]: ponto onde as regras de proteção serão plugadas. Nenhuma proteção
## ativa no MVP: todo equipamento vestido cai na morte (§12.1). context: mapa, pvp, killer...
static func should_drop_on_death(_stack: ItemStack, _context: Dictionary) -> bool:
	return true


## Formato do contrato: as 7 chaves + 3 cosméticas com o item_id ou &"".
func to_client() -> Dictionary:
	var out: Dictionary = {}
	for s: StringName in SLOTS:
		out[s] = _slots[s].item_id if _slots[s] != null else &""
	return out


func to_save() -> Dictionary:
	var out: Dictionary = {}
	for s: StringName in SLOTS:
		out[String(s)] = _slots[s].to_save() if _slots[s] != null else {}
	return out


func load_save(data: Dictionary) -> int:
	var dropped: int = 0
	for s: StringName in SLOTS:
		_slots[s] = null
		var d: Variant = data.get(String(s))
		if typeof(d) != TYPE_DICTIONARY or (d as Dictionary).is_empty():
			continue
		var st: ItemStack = ItemStack.from_save(d)
		if st == null or not (s in Equipment.slots_for(st.get_def())):
			dropped += 1
			continue
		_slots[s] = st
	changed.emit()
	return dropped
