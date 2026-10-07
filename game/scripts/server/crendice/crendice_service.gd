class_name CrendiceService
extends RefCounted
## Serviço do Servidor para o Sistema de Crendices (GDD §11).
## Valida e executa a inserção, remoção e consagração de amuletos folclóricos
## nos encaixes de equipamentos dos personagens.

var world: ServerWorld = null


func _init(p_world: ServerWorld) -> void:
	world = p_world
	if NetCrendice.has_signal(&"insert_intent"):
		NetCrendice.insert_intent.connect(_on_insert_intent)
	if NetCrendice.has_signal(&"remove_intent"):
		NetCrendice.remove_intent.connect(_on_remove_intent)
	if NetCrendice.has_signal(&"consecrate_intent"):
		NetCrendice.consecrate_intent.connect(_on_consecrate_intent)


func _on_insert_intent(peer_id: int, equip_slot: StringName, inv_slot: int, socket_idx: int) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null or session.character == null:
		return

	var char_data: CharacterData = session.character
	var equip_stack: ItemStack = char_data.equipment.get_slot(equip_slot)
	if equip_stack == null:
		NetCrendice.push_result(peer_id, false, "Nenhum equipamento equipado neste espaço.")
		return

	var inv_stack: ItemStack = char_data.inventory.get_slot(inv_slot)
	if inv_stack == null:
		NetCrendice.push_result(peer_id, false, "Item inválido no inventário.")
		return

	var crendice_id: StringName = inv_stack.item_id
	var cdef: CrendiceDef = CrendiceDatabase.get_crendice(crendice_id)
	if cdef == null:
		NetCrendice.push_result(peer_id, false, "Este item não é um Amuleto de Crendice.")
		return

	var err: String = CrendiceSystem.can_insert_crendice(equip_stack, crendice_id, socket_idx)
	if not err.is_empty():
		match err:
			"CRENDICE_ERR_SLOT_MISMATCH":
				NetCrendice.push_result(peer_id, false, "Este amuleto não cabe neste tipo de equipamento.")
			"CRENDICE_ERR_SOCKETS_FULL":
				NetCrendice.push_result(peer_id, false, "Todos os encaixes deste equipamento estão ocupados.")
			"CRENDICE_ERR_NO_SOCKETS":
				NetCrendice.push_result(peer_id, false, "Este item não possui Encaixes de Crendice.")
			_:
				NetCrendice.push_result(peer_id, false, "Não foi possível engastar o amuleto.")
		return

	# Inserir no equipamento
	if not CrendiceSystem.insert_crendice(equip_stack, crendice_id, socket_idx):
		NetCrendice.push_result(peer_id, false, "Falha ao engastar o amuleto.")
		return

	# Consumir do inventário
	char_data.inventory.remove_at(inv_slot, 1)

	# Atualizar estado
	char_data.equipment.changed.emit()
	session.mark_dirty(PlayerSession.DIRTY_EQUIPMENT | PlayerSession.DIRTY_INVENTORY)
	char_data.recompute_stats()

	Net.log_line("crendice_inserted", {"peer": peer_id, "slot": String(equip_slot), "crendice": String(crendice_id)})
	NetCrendice.push_result(peer_id, true, "Amuleto engastado com sucesso!")


func _on_remove_intent(peer_id: int, equip_slot: StringName, socket_idx: int) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null or session.character == null:
		return

	var char_data: CharacterData = session.character
	var equip_stack: ItemStack = char_data.equipment.get_slot(equip_slot)
	if equip_stack == null or socket_idx < 0 or socket_idx >= equip_stack.crendices.size():
		NetCrendice.push_result(peer_id, false, "Encaixe vazio ou inválido.")
		return

	var crendice_id: StringName = equip_stack.crendices[socket_idx]
	if not char_data.inventory.can_add(crendice_id, 1):
		NetCrendice.push_result(peer_id, false, "Inventário cheio! Libere espaço para remover o amuleto.")
		return

	# Remover do encaixe
	var removed_id: StringName = CrendiceSystem.remove_crendice(equip_stack, socket_idx)
	if removed_id.is_empty():
		NetCrendice.push_result(peer_id, false, "Falha ao remover o amuleto.")
		return

	# Devolver ao inventário
	char_data.inventory.add(removed_id, 1)

	# Atualizar estado
	char_data.equipment.changed.emit()
	session.mark_dirty(PlayerSession.DIRTY_EQUIPMENT | PlayerSession.DIRTY_INVENTORY)
	char_data.recompute_stats()

	Net.log_line("crendice_removed", {"peer": peer_id, "slot": String(equip_slot), "crendice": String(removed_id)})
	NetCrendice.push_result(peer_id, true, "Amuleto desencaixado e devolvido ao inventário.")


func _on_consecrate_intent(peer_id: int, equip_slot: StringName, socket_idx: int) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null or session.character == null:
		return

	var char_data: CharacterData = session.character
	var equip_stack: ItemStack = char_data.equipment.get_slot(equip_slot)
	if equip_stack == null or socket_idx < 0 or socket_idx >= equip_stack.crendices.size():
		NetCrendice.push_result(peer_id, false, "Encaixe inválido.")
		return

	if not CrendiceSystem.consecrate_crendice(equip_stack, socket_idx):
		NetCrendice.push_result(peer_id, false, "Este amuleto já está ativo ou não precisa ser reconsagrado.")
		return

	char_data.equipment.changed.emit()
	session.mark_dirty(PlayerSession.DIRTY_EQUIPMENT)
	char_data.recompute_stats()

	Net.log_line("crendice_consecrated", {"peer": peer_id, "slot": String(equip_slot), "socket": socket_idx})
	NetCrendice.push_result(peer_id, true, "Amuleto reconsagrado no Altar! A sorte retorna ao seu espírito.")
