extends Node
## Dublê do autoload Net para os testes de interface (sem rede): mesmos sinais do contrato e
## métodos send_* que só registram as chamadas em `calls` ([método, args]).

signal inventory_changed(slots: Array)
signal equipment_changed(equip: Dictionary)
signal stats_changed(stats: Dictionary)
signal currency_changed(stars: int)
signal dialogue_opened(npc_entity_id: int, speaker_key: String, text_key: String, options: Array[String])
signal dialogue_closed()
signal shop_opened(shop_id: StringName, items: Array[StringName])
signal shop_closed()
signal chat_received(channel: StringName, from_name: String, text: String, from_entity_id: int)
signal emote_received(entity_id: int, emote_id: StringName)
signal system_message(key: String, args: Array)
signal connection_closed(reason_key: String)

var calls: Array[Array] = []


func last_call(method: StringName) -> Array:
	for i: int in range(calls.size() - 1, -1, -1):
		if calls[i][0] == method:
			return calls[i][1]
	return []


func count(method: StringName) -> int:
	return calls.filter(func(c: Array) -> bool: return c[0] == method).size()


func _rec(method: StringName, args: Array) -> void:
	calls.append([method, args])


func send_interact(target_id: String) -> void: _rec(&"send_interact", [target_id])
func send_dialogue_choice(option_index: int) -> void: _rec(&"send_dialogue_choice", [option_index])
func send_dialogue_close() -> void: _rec(&"send_dialogue_close", [])
func send_inventory_move(from_slot: int, to_slot: int) -> void: _rec(&"send_inventory_move", [from_slot, to_slot])
func send_use_item(slot: int) -> void: _rec(&"send_use_item", [slot])
func send_equip(slot: int) -> void: _rec(&"send_equip", [slot])
func send_unequip(equip_slot: StringName) -> void: _rec(&"send_unequip", [equip_slot])
func send_shop_buy(item_id: StringName, qty: int) -> void: _rec(&"send_shop_buy", [item_id, qty])
func send_shop_sell(slot: int, qty: int) -> void: _rec(&"send_shop_sell", [slot, qty])
func send_chat(channel: StringName, text: String) -> void: _rec(&"send_chat", [channel, text])
func send_emote(emote_id: StringName) -> void: _rec(&"send_emote", [emote_id])
func send_shop_close() -> void: _rec(&"send_shop_close", [])
