class_name Inventory
extends RefCounted
## Contêiner genérico de N espaços (servidor): inventário (40), depois armazém (60), túmulo, loja.
## Cada espaço é null ou um ItemStack. Empilha até ItemDef.max_stack. Quem replica é o dono do
## contêiner (ServerWorld manda só para o peer dono, via RPC direcionado).

## Emitido a cada mudança (o dono decide replicar/salvar).
signal changed

var _slots: Array[ItemStack] = []
## Itens que entram por add() saem marcados com este map_id (&"" = livres). Ajustado pelo ZoneRules
## (Agente N) ao entrar num mapa que prende itens (Campo de Treino). Pilhas de marcas diferentes
## não se juntam.
var bind_zone: StringName = &""


func _init(size: int) -> void:
	_slots.resize(size)


func size() -> int:
	return _slots.size()


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < _slots.size()


func get_slot(slot: int) -> ItemStack:
	return _slots[slot] if is_valid_slot(slot) else null


func count(item_id: StringName) -> int:
	var total: int = 0
	for s: ItemStack in _slots:
		if s != null and s.item_id == item_id:
			total += s.qty
	return total


func has_item(item_id: StringName, qty: int = 1) -> bool:
	return count(item_id) >= qty


func free_slot_count() -> int:
	var n: int = 0
	for s: ItemStack in _slots:
		if s == null:
			n += 1
	return n


func first_free_slot() -> int:
	for i: int in range(_slots.size()):
		if _slots[i] == null:
			return i
	return -1


## Quanto de item_id ainda cabe (pilhas existentes + espaços vazios).
func capacity_for(item_id: StringName) -> int:
	var max_stack: int = ItemStack.max_stack_of(item_id)
	var room: int = 0
	for s: ItemStack in _slots:
		if s == null:
			room += max_stack
		elif s.item_id == item_id and s.bound_zone == bind_zone:
			room += maxi(max_stack - s.qty, 0)
	return room


func can_add(item_id: StringName, qty: int) -> bool:
	return qty > 0 and capacity_for(item_id) >= qty


## Confere um pacote inteiro sem contar o mesmo espaço vazio para recompensas diferentes.
## Usado por missões com mais de um item para manter a entrega realmente atômica.
func can_add_all(items: Dictionary[StringName, int]) -> bool:
	var empty_slots: int = 0
	for stack: ItemStack in _slots:
		if stack == null:
			empty_slots += 1
	for item_id: StringName in items:
		var qty: int = int(items[item_id])
		var def: ItemDef = Content.item(item_id)
		if def == null or qty <= 0:
			return false
		var max_stack: int = ItemStack.max_stack_of(item_id)
		var left: int = qty
		for stack: ItemStack in _slots:
			if stack != null and stack.item_id == item_id and stack.bound_zone == bind_zone:
				left -= maxi(0, max_stack - stack.qty)
				if left <= 0:
					break
		if left <= 0:
			continue
		var slots_needed: int = ceili(float(left) / float(max_stack))
		if slots_needed > empty_slots:
			return false
		empty_slots -= slots_needed
	return true


## Adiciona tudo ou nada (completa pilhas existentes primeiro). false = não coube.
func add(item_id: StringName, qty: int) -> bool:
	if Content.item(item_id) == null or not can_add(item_id, qty):
		return false
	var max_stack: int = ItemStack.max_stack_of(item_id)
	var left: int = qty
	for s: ItemStack in _slots:
		if left <= 0:
			break
		if s != null and s.item_id == item_id and s.bound_zone == bind_zone and s.qty < max_stack:
			var put: int = mini(max_stack - s.qty, left)
			s.qty += put
			left -= put
	for i: int in range(_slots.size()):
		if left <= 0:
			break
		if _slots[i] == null:
			var put: int = mini(max_stack, left)
			_slots[i] = ItemStack.create(item_id, put)
			_slots[i].bound_zone = bind_zone
			left -= put
	changed.emit()
	return true


## Coloca uma pilha inteira num espaço vazio específico. false = espaço inválido/ocupado.
func put_at(slot: int, stack: ItemStack) -> bool:
	if not is_valid_slot(slot) or _slots[slot] != null or stack == null:
		return false
	_slots[slot] = stack
	changed.emit()
	return true


## Troca o conteúdo de um espaço (pode ser null) e devolve o que estava lá.
func replace_at(slot: int, stack: ItemStack) -> ItemStack:
	if not is_valid_slot(slot):
		return stack
	var old: ItemStack = _slots[slot]
	_slots[slot] = stack
	changed.emit()
	return old


## Remove qty do espaço. false = espaço vazio ou quantidade insuficiente.
func remove_at(slot: int, qty: int) -> bool:
	var s: ItemStack = get_slot(slot)
	if s == null or qty <= 0 or qty > s.qty:
		return false
	s.qty -= qty
	if s.qty == 0:
		_slots[slot] = null
	changed.emit()
	return true


## Move de um espaço para outro: junta pilhas iguais (até max_stack), senão troca.
func move(from_slot: int, to_slot: int) -> bool:
	if not is_valid_slot(from_slot) or not is_valid_slot(to_slot) or from_slot == to_slot:
		return false
	var a: ItemStack = _slots[from_slot]
	if a == null:
		return false
	var b: ItemStack = _slots[to_slot]
	if b != null and b.item_id == a.item_id and b.bound_zone == a.bound_zone \
			and b.qty < b.get_max_stack():
		var put: int = mini(b.get_max_stack() - b.qty, a.qty)
		b.qty += put
		a.qty -= put
		if a.qty == 0:
			_slots[from_slot] = null
	else:
		_slots[to_slot] = a
		_slots[from_slot] = b
	changed.emit()
	return true


## Divide qty de um espaço para um espaço vazio.
func split(from_slot: int, to_slot: int, qty: int) -> bool:
	var a: ItemStack = get_slot(from_slot)
	if a == null or not is_valid_slot(to_slot) or _slots[to_slot] != null \
			or qty <= 0 or qty >= a.qty:
		return false
	a.qty -= qty
	_slots[to_slot] = a.copy_with_qty(qty)
	changed.emit()
	return true


## Formato do contrato: N posições, cada uma {} ou {"item": StringName, "qty": int}.
func to_client() -> Array:
	var out: Array = []
	for s: ItemStack in _slots:
		out.append(s.to_client() if s != null else {})
	return out


func to_save() -> Array:
	var out: Array = []
	for s: ItemStack in _slots:
		out.append(s.to_save() if s != null else {})
	return out


## Carrega de to_save(); itens cujo ItemDef não existe mais são descartados (retorna quantos).
func load_save(data: Array) -> int:
	var dropped: int = 0
	for i: int in range(_slots.size()):
		_slots[i] = null
		if i >= data.size() or typeof(data[i]) != TYPE_DICTIONARY or (data[i] as Dictionary).is_empty():
			continue
		var s: ItemStack = ItemStack.from_save(data[i])
		if s == null or Content.item(s.item_id) == null:
			dropped += 1
			continue
		_slots[i] = s
	changed.emit()
	return dropped
