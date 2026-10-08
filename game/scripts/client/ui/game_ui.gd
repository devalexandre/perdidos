class_name GameUI
extends Control
## Interface do jogo por cima do mundo: inventário, personagem/equipamento, loja, diálogo, chat,
## emotes, mensagens de sistema e configurações. Escuta os sinais do Net (ou de um dublê nos
## testes) e chama as intenções Net.send_* do contrato. Reconstrói tudo ao mudar a escala (720p/1080p).
##
## Atalhos: I inventário, C personagem, Enter chat, Esc fecha/abre configurações, Alt+1..6 emotes,
## 1..9 opções do diálogo. Todos também têm botão na tela (toque): menus na engrenagem e emotes
## na carinha, no canto inferior direito (GearMenu, GDD §9.5). Controle (joypad): GamepadInput — com ele em
## uso os controles de toque somem, a barra mostra os botões e aparece a faixa de dicas (GamepadHints).

signal quit_requested

const ACTION_INVENTORY: StringName = &"ui_toggle_inventory"
const ACTION_CHARACTER: StringName = &"ui_toggle_character"
const ACTION_CHAT: StringName = &"ui_open_chat"
const ACTION_MENU: StringName = &"ui_menu"
const ACTION_EMOTE_PREFIX: String = "emote_"
const ANY_DEVICE: int = -1
const EMOTE_SIT: StringName = &"sit"
const HUD_MARGIN_PX: float = 8.0
## Posição inicial das janelas (fração da área útil: x 0 = esquerda, 1 = direita; y 0 = logo abaixo das
## barras de vida, 1 = logo acima da barra de atalhos). Ao abrir, a janela procura um canto livre
## (WindowsLayer.arrange_window) para não empilhar umas sobre as outras.
const INVENTORY_ANCHOR: Vector2 = Vector2(1.0, 0.0)
const CHARACTER_ANCHOR: Vector2 = Vector2(0.0, 0.0)
const SHOP_ANCHOR: Vector2 = Vector2(0.5, 0.0)
const SETTINGS_ANCHOR: Vector2 = Vector2(0.5, 0.5)
## Largura mínima (px na escala 1,0) da faixa entre os controles de toque para o diálogo ficar nela.
const DIALOGUE_MIN_TOUCH_WIDTH_PX: float = 440.0
## Margem (px na escala 1,0) entre as janelas e as bordas/HUD.
const WORK_MARGIN_PX: float = 8.0
## Modo de toque: janelas que podem ficar abertas junto com o inventário (lado a lado).
const TOUCH_INVENTORY_PARTNERS: Array[StringName] = [&"ShopWindow", &"TradeWindow", &"EquipmentWindow",
	&"CrendiceAltarWindow"]
## Espaço (px na escala 1,0) entre a loja e o inventário, lado a lado.
const WINDOW_GAP_PX: float = 8.0
## Dígitos para escolher opção de diálogo.
const MAX_DIALOGUE_HOTKEYS: int = 9

## Quem fornece sinais/intenções (autoload Net por padrão; dublê nos testes).
var net: Object = null
var ui_scale: float = 1.0

var inventory: InventoryWindow
var equipment: EquipmentWindow
var shop: ShopWindow
var dialogue: DialogueBox
var chat: ChatBox
var emotes: EmoteBar
var toasts: ToastStack
## Agente G/N: M alterna mapa local, atlas global e fechado.
var world_atlas: WorldAtlas
var settings: SettingsWindow
## Agente R (GDD §9.5): engrenagem no canto inferior direito com os botões de menu e os emotes.
var gear: GearMenu
## Entradas do menu da engrenagem (compatibilidade: antes era a fileira de botões).
var hud_buttons: VBoxContainer
## Camada das janelas arrastáveis (abaixo do diálogo e dos avisos).
var windows_layer: Control
var player_bars: PlayerBars
## Agente Q (hotbar_hud.gd).
var progression: ProgressionHud
## Grupo (30/09/2026): painel na lateral, janela de convite e menu de jogador (NetParty).
var party_panel: PartyPanel
var party_invite: PartyInviteDialog
var player_menu: PlayerMenu
var net_party: Object = null
## Troca entre personagens (30/09/2026): janela da troca e pedido Aceitar/Recusar (NetTrade).
var trade_window: TradeWindow
var trade_request: PartyInviteDialog
var net_trade: Object = null
## Sistema de Crendices: Altar de consagração e encaixe de amuletos folclóricos
var crendice_altar: CrendiceAltarWindow = null
## Cena da fala da lenda depois da vitória de história (NetProgress.story_scene). Sobrevive ao _rebuild.
var story_scene: StoryScene = null
var net_crendice: Object = null
const MOBILE_CONTROLS_OVERLAY_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_controls_overlay.gd")

## Controles touch / mobile
var mobile_controls: MobileControlsOverlay = null
## Andar/alvo/botão de ação sem mouse (toque e controle usam o mesmo).
var combat_assist: CombatAssist = null
## Controle físico, dicas dos botões e moldura do foco.
var gamepad: GamepadInput = null
var gamepad_hints: GamepadHints = null
var focus_ring: GamepadInput.FocusRing = null

# Estado recebido (para reconstruir ao mudar de escala).
var _slots: Array = []
var _equip: Dictionary = {}
var _stats: Dictionary = {}
var _stars: int = 0
var _shop_open: bool = false
var _shop_id: StringName = &""
var _shop_items: Array[StringName] = []
var _dialogue_args: Array = []
var _chat_lines: PackedStringArray = []
var _chat_channels: PackedStringArray = []
var _chat_tab: StringName = ChatBox.TAB_ALL
var _chat_minimized: bool = false
var _built: bool = false


func _init() -> void:
	name = &"GameUI"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Todo texto passa por tr() explícito (nomes de jogador não podem ser "traduzidos").
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_actions()
	if net == null:
		net = get_node_or_null(^"/root/Net")
		_connect_net()
	_connect_party()
	get_viewport().size_changed.connect(_on_size_changed)
	var settings: GameSettings = GameSettings.get_instance()
	_chat_minimized = settings.mobile_controls
	settings.mobile_controls_changed.connect(set_mobile_mode)
	story_scene = StoryScene.new()
	if not NetProgress.story_scene.is_connected(story_scene.play):
		NetProgress.story_scene.connect(story_scene.play)
	_rebuild()


## Liga a interface a um provedor de sinais/intenções (Net ou dublê).
func bind_net(p_net: Object) -> void:
	_disconnect_net()
	net = p_net
	if player_bars != null:
		player_bars.bind_net(net)
	_connect_net()


## Fecha tudo o que está aberto; retorna true se havia algo aberto.
func close_top() -> bool:
	if story_scene != null and story_scene.is_playing():
		story_scene.skip()
		return true
	if gear != null and gear.close_popups():
		return true
	if player_menu != null and player_menu.visible:
		player_menu.close()
		return true
	if trade_window != null and trade_window.visible:
		_trade_send(&"send_cancel", [])
		return true
	if chat.is_typing():
		chat.close_input()
		return true
	if dialogue.visible:
		_close_dialogue()
		return true
	for w: GameWindow in [settings, shop, inventory, equipment]:
		if w.visible:
			w.close()
			return true
	return false


func is_typing() -> bool:
	return chat != null and chat.is_typing()


# --- Sinais do Net --------------------------------------------------------------------------------

const NET_SIGNALS: Dictionary[StringName, StringName] = {
	&"inventory_changed": &"_on_inventory_changed", &"equipment_changed": &"_on_equipment_changed",
	&"stats_changed": &"_on_stats_changed", &"currency_changed": &"_on_currency_changed",
	&"dialogue_opened": &"_on_dialogue_opened", &"dialogue_closed": &"_on_dialogue_closed",
	&"shop_opened": &"_on_shop_opened", &"shop_closed": &"_on_shop_closed",
	&"chat_received": &"_on_chat_received", &"emote_received": &"_on_emote_received",
	&"system_message": &"_on_system_message", &"connection_closed": &"_on_connection_closed",
}
## Estado já recebido que o Net guarda (a interface pode nascer depois dos sinais).
const NET_CACHE_INVENTORY: StringName = &"client_inventory"
const NET_CACHE_EQUIPMENT: StringName = &"client_equipment"
const NET_CACHE_STATS: StringName = &"client_stats"
const NET_CACHE_STARS: StringName = &"client_stars"


func _connect_net() -> void:
	if net == null:
		return
	for sig: StringName in NET_SIGNALS:
		var cb := Callable(self, NET_SIGNALS[sig])
		if net.has_signal(sig) and not net.is_connected(sig, cb):
			net.connect(sig, cb)
	_prime_from_cache()


## Lê o cache do Net (client_inventory etc.), se existir.
func _prime_from_cache() -> void:
	if NET_CACHE_INVENTORY in net and not (net.get(NET_CACHE_INVENTORY) as Array).is_empty():
		_slots = (net.get(NET_CACHE_INVENTORY) as Array).duplicate(true)
	if NET_CACHE_EQUIPMENT in net:
		_equip = (net.get(NET_CACHE_EQUIPMENT) as Dictionary).duplicate()
	if NET_CACHE_STATS in net:
		_stats = (net.get(NET_CACHE_STATS) as Dictionary).duplicate()
	if NET_CACHE_STARS in net:
		_stars = int(net.get(NET_CACHE_STARS))
	if _built:
		inventory.set_slots(_slots)
		inventory.set_stars(_stars)
		equipment.set_equipment(_equip)
		equipment.set_stats(_stats)
		equipment.set_stars(_stars)
		shop.set_stars(_stars)
		if player_bars != null and not _stats.is_empty():
			player_bars.set_stats(_stats)


func _disconnect_net() -> void:
	if net == null:
		return
	for sig: StringName in NET_SIGNALS:
		var cb := Callable(self, NET_SIGNALS[sig])
		if net.has_signal(sig) and net.is_connected(sig, cb):
			net.disconnect(sig, cb)


func _send(method: StringName, args: Array = []) -> void:
	if net != null and net.has_method(method):
		net.callv(method, args)
	else:
		push_warning("GameUI: Net sem '%s' (ainda?)." % method)


func _on_inventory_changed(slots: Array) -> void:
	var before: int = _total_items(_slots)
	_slots = slots.duplicate(true)
	inventory.set_slots(_slots)
	if crendice_altar != null and crendice_altar.visible:
		crendice_altar.set_inventory_data(_slots)
	if not _shop_open and _total_items(_slots) > before and before > 0:
		AudioDirector.play_sfx(&"pickup")


func _on_equipment_changed(equip: Dictionary) -> void:
	var changed: bool = equip != _equip and not _equip.is_empty()
	_equip = equip.duplicate()
	equipment.set_equipment(_equip)
	if crendice_altar != null and crendice_altar.visible:
		crendice_altar.set_equipment_data(_equip)
	if changed:
		AudioDirector.play_sfx(&"equip")


func _on_stats_changed(stats: Dictionary) -> void:
	_stats = stats.duplicate()
	equipment.set_stats(_stats)
	if player_bars != null:
		player_bars.set_stats(_stats)


func _on_currency_changed(stars: int) -> void:
	if _shop_open and stars != _stars:
		AudioDirector.play_sfx(&"buy" if stars < _stars else &"sell")
	_stars = stars
	inventory.set_stars(stars)
	equipment.set_stars(stars)
	shop.set_stars(stars)
	if trade_window != null:
		trade_window.set_my_stars(stars)


func _on_dialogue_opened(npc_entity_id: int, speaker_key: String, text_key: String, options: Array) -> void:
	_dialogue_args = [npc_entity_id, speaker_key, text_key, options.duplicate()]
	dialogue.show_dialogue(npc_entity_id, speaker_key, text_key, options)


func _on_dialogue_closed() -> void:
	_dialogue_args = []
	dialogue.hide_dialogue()


func _on_shop_opened(shop_id: StringName, items: Array) -> void:
	_shop_open = true
	_shop_id = shop_id
	_shop_items.assign(items)
	shop.set_shop(shop_id, _shop_items)
	inventory.set_shop_open(true)
	inventory.open()
	shop.open()
	_dock_shop()


## Loja logo à esquerda do inventário (os dois são usados juntos para comprar e vender).
func _dock_shop() -> void:
	shop.fit_to_screen()
	if UIKit.is_touch_layout():
		_dock_pair(shop)
		return
	var gap: int = UIKit.px(WINDOW_GAP_PX, ui_scale)
	shop.position = Vector2(inventory.position.x - shop.size.x - gap, inventory.position.y)
	shop.clamp_to_screen()


func _on_shop_closed() -> void:
	_shop_open = false
	shop.close()
	inventory.set_shop_open(false)
	inventory.set_shop_open(false)


func _on_chat_received(channel: StringName, from_name: String, text: String, _from_entity_id: int) -> void:
	chat.add_message(from_name, text, channel)
	_save_chat()
	AudioDirector.play_sfx(&"chat")


func _save_chat() -> void:
	_chat_lines = chat.get_lines()
	_chat_channels = chat.get_channels()
	_chat_tab = chat.get_tab()


func _on_emote_received(_entity_id: int, emote_id: StringName) -> void:
	AudioDirector.play_sfx(&"sit" if emote_id == EMOTE_SIT else &"emote")


func _on_system_message(key: String, args: Array) -> void:
	if key == "PROG_MSG_WEREWOLF_ENDING_DEATH" \
			and ResourceLoader.exists("res://assets/audio/music/mus_werewolf_death.ogg"):
		AudioDirector.play_music_cue_named(&"werewolf_death")
	show_system_message(key, args)


## Conexão encerrada (main.gd volta ao título depois): mostra o motivo aqui e na tela de título.
func _on_connection_closed(reason_key: String) -> void:
	if reason_key.is_empty():
		return
	toasts.push(tr(reason_key), true)
	chat.add_system(tr(reason_key))
	TitleScreen.pending_status = reason_key


## Mostra uma mensagem de sistema (chave + argumentos) como aviso e no chat.
func show_system_message(key: String, args: Array = []) -> void:
	var text: String = UIKit.format_message(key, args)
	toasts.push(text, key.begins_with("SYS_") or key.begins_with("ERR_") or key.begins_with("PARTY_ERR_"))
	chat.add_system(text, key.begins_with("PARTY_"))
	_save_chat()


# --- Área útil das janelas ------------------------------------------------------------------------

## Camada das janelas: informa a área útil e arruma cada janela que abre num lugar livre.
class WindowsLayer extends Control:
	var ui: GameUI = null

	func work_rect() -> Rect2:
		return ui.work_rect() if ui != null else Rect2(Vector2.ZERO, size)

	func preferred_top() -> float:
		return ui.preferred_top() if ui != null else 0.0

	func max_rect() -> Rect2:
		return ui.max_rect() if ui != null else Rect2(Vector2.ZERO, size)

	## Primeira posição (entre a âncora da janela e os cantos) que menos cobre as outras janelas abertas.
	func arrange_window(w: GameWindow) -> void:
		var candidates: Array[Vector2] = [w.default_anchor, Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.5, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 1.0)]
		var best: Vector2 = w.default_anchor
		var best_overlap: float = INF
		for a: Vector2 in candidates:
			w.place(a)
			var overlap: float = 0.0
			var mine := Rect2(w.position, w.size)
			for other: Node in get_children():
				if other != w and other is GameWindow and (other as GameWindow).visible:
					overlap += mine.intersection(Rect2((other as GameWindow).position, (other as GameWindow).size)).get_area()
			if overlap < best_overlap - 1.0:
				best_overlap = overlap
				best = a
			if overlap <= 0.0:
				break
		w.place(best)


## Área útil das janelas (coordenadas da tela): sem a barra de atalhos embaixo. No modo de toque, a
## tela inteira (a janela fica por cima dos controles, centrada, uma por vez).
func work_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var m: float = UIKit.px(WORK_MARGIN_PX, ui_scale)
	var bottom: float = screen.y - m
	if not UIKit.is_touch_layout() and progression != null and is_instance_valid(progression.hotbar) \
			and progression.hotbar.is_visible_in_tree():
		bottom = minf(bottom, progression.hotbar.get_global_rect().position.y - m)
	return Rect2(m, m, maxf(0.0, screen.x - m * 2.0), maxf(0.0, bottom - m))


## Limite de tamanho das janelas: a tela inteira com margem.
func max_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var m: float = UIKit.px(WORK_MARGIN_PX, ui_scale)
	return Rect2(m, m, maxf(0.0, screen.x - m * 2.0), maxf(0.0, screen.y - m * 2.0))


## Topo preferido das janelas: logo abaixo das barras de vida (se a janela couber ali).
func preferred_top() -> float:
	var m: float = UIKit.px(WORK_MARGIN_PX, ui_scale)
	if player_bars != null and is_instance_valid(player_bars) and player_bars.visible:
		return player_bars.get_global_rect().end.y + m
	return m


## Área livre para a caixa de diálogo no modo de toque: entre o analógico e os botões de ação.
func touch_free_band() -> Vector2:
	var screen: Vector2 = get_viewport_rect().size
	var left: float = 0.0
	var right: float = screen.x
	if mobile_controls != null and mobile_controls.visible:
		if mobile_controls.joystick != null:
			left = mobile_controls.joystick.get_global_rect().end.x
		if mobile_controls.action_cluster != null:
			right = mobile_controls.action_cluster.get_global_rect().position.x
	return Vector2(left, right)


## Área da caixa de diálogo: acima da barra de atalhos/XP; no toque, entre o analógico e os botões de ação
## (se a faixa livre for estreita demais, usa a largura toda — a caixa fica por cima dos controles).
func dialogue_area() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var m: float = UIKit.px(WORK_MARGIN_PX, ui_scale)
	var bottom: float = screen.y - m
	if progression != null and is_instance_valid(progression.hotbar) and progression.hotbar.is_visible_in_tree():
		bottom = minf(bottom, progression.hotbar.get_global_rect().position.y - m)
	var left: float = m
	var right: float = screen.x - m
	if UIKit.is_touch_layout():
		var band: Vector2 = touch_free_band()
		if band.y - band.x - m * 2.0 >= UIKit.px(DIALOGUE_MIN_TOUCH_WIDTH_PX, ui_scale):
			left = band.x + m
			right = band.y - m
	return Rect2(left, m, maxf(0.0, right - left), maxf(0.0, bottom - m))


## Ordem de desenho: HUD (chat, barras, atalhos, controles de toque) < janelas < diálogo < avisos/menus.
func _restack() -> void:
	if windows_layer == null:
		return
	# No toque, a engrenagem/emotes ficam abaixo das janelas (senão cobrem o botão de fechar em telas baixas).
	var order: Array = [gear, windows_layer] if UIKit.is_touch_layout() else [windows_layer, gear]
	for n: Node in order + [dialogue, toasts, party_invite, trade_request, player_menu, world_atlas]:
		if n != null and is_instance_valid(n) and n.get_parent() == self:
			move_child(n, -1)


## Modo de toque: abrir uma janela fecha as outras (exceto as que fazem par com o inventário).
func _on_window_opened(w: GameWindow) -> void:
	if not UIKit.is_touch_layout():
		return
	for other: Node in windows_layer.get_children():
		if other == w or not (other is GameWindow) or not (other as GameWindow).visible:
			continue
		var pair: bool = (w == inventory and StringName(other.name) in TOUCH_INVENTORY_PARTNERS) \
				or (other == inventory and StringName(w.name) in TOUCH_INVENTORY_PARTNERS)
		if not pair:
			(other as GameWindow).close()
	if StringName(w.name) in TOUCH_INVENTORY_PARTNERS and inventory.visible:
		_dock_pair(w)


## Duas janelas lado a lado (a dada à esquerda do inventário), centradas juntas na área útil.
func _dock_pair(w: GameWindow) -> void:
	var gap: float = UIKit.px(WINDOW_GAP_PX, ui_scale)
	var work: Rect2 = work_rect()
	var total: float = w.size.x + gap + inventory.size.x
	var x0: float = work.position.x + maxf(0.0, (work.size.x - total) * 0.5)
	# Topos alinhados, o par centrado na vertical pela mais alta.
	var y0: float = work.position.y + maxf(0.0, (work.size.y - maxf(w.size.y, inventory.size.y)) * 0.5)
	w.position = Vector2(x0, y0).floor()
	inventory.position = Vector2(x0 + w.size.x + gap, y0).floor()
	w.clamp_to_screen()
	inventory.clamp_to_screen()


# --- Construção -----------------------------------------------------------------------------------

func _on_size_changed() -> void:
	var s: float = UIKit.scale_for(get_viewport_rect().size)
	if not is_equal_approx(s, ui_scale):
		_rebuild()


func _rebuild() -> void:
	ui_scale = UIKit.scale_for(get_viewport_rect().size)
	var reopen: Dictionary[StringName, bool] = {}
	if _built:
		for w: GameWindow in [inventory, equipment, shop, settings]:
			reopen[w.name] = w.visible
		_save_chat()
	for child: Node in get_children():
		remove_child(child)
		if child != story_scene:
			child.queue_free()
	theme = UIKit.build_theme(ui_scale)
	var layer := WindowsLayer.new()
	layer.ui = self
	windows_layer = layer
	windows_layer.name = &"Windows"
	windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	chat = ChatBox.new(ui_scale)
	chat.minimized_changed.connect(func(value: bool) -> void: _chat_minimized = value)
	chat.send_requested.connect(func(ch: StringName, text: String) -> void: _send(&"send_chat", [ch, text]))
	chat.notice.connect(func(key: String) -> void: show_system_message(key))
	add_child(chat)
	chat.set_lines(_chat_lines, _chat_channels)
	chat.set_tab.call_deferred(_chat_tab)
	chat.set_minimized.call_deferred(_chat_minimized)

	_build_hud_buttons()
	add_child(windows_layer)
	windows_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	inventory = InventoryWindow.new(ui_scale)
	inventory.move_requested.connect(func(a: int, b: int) -> void: _send(&"send_inventory_move", [a, b]))
	inventory.use_requested.connect(func(i: int) -> void: _send(&"send_use_item", [i]))
	inventory.equip_requested.connect(func(i: int) -> void: _send(&"send_equip", [i]))
	inventory.unequip_requested.connect(func(s: StringName) -> void: _send(&"send_unequip", [s]))
	inventory.sell_requested.connect(func(i: int, q: int) -> void: _send(&"send_shop_sell", [i, q]))
	windows_layer.add_child(inventory)

	equipment = EquipmentWindow.new(ui_scale)
	equipment.equip_requested.connect(func(i: int) -> void: _send(&"send_equip", [i]))
	equipment.unequip_requested.connect(func(s: StringName) -> void: _send(&"send_unequip", [s]))
	windows_layer.add_child(equipment)

	shop = ShopWindow.new(ui_scale)
	shop.buy_requested.connect(func(id: StringName, q: int) -> void: _send(&"send_shop_buy", [id, q]))
	shop.sell_requested.connect(func(i: int, q: int) -> void: _send(&"send_shop_sell", [i, q]))
	shop.closed.connect(_on_shop_window_closed)
	windows_layer.add_child(shop)

	trade_window = TradeWindow.new(ui_scale)
	trade_window.offer_item_requested.connect(func(i: int, q: int) -> void: _trade_send(&"send_item", [i, q]))
	trade_window.offer_stars_requested.connect(func(n: int) -> void: _trade_send(&"send_stars", [n]))
	trade_window.confirm_requested.connect(func(on: bool) -> void: _trade_send(&"send_confirm", [on]))
	trade_window.commit_requested.connect(_trade_send.bind(&"send_commit", []))
	trade_window.cancel_requested.connect(_trade_send.bind(&"send_cancel", []))
	windows_layer.add_child(trade_window)
	inventory.trade_offer_requested.connect(func(i: int, q: int) -> void: _trade_send(&"send_item", [i, q]))

	settings = SettingsWindow.new(ui_scale)
	settings.quit_requested.connect(func() -> void: quit_requested.emit())
	windows_layer.add_child(settings)

	crendice_altar = CrendiceAltarWindow.new(ui_scale)
	crendice_altar.insert_requested.connect(func(slot: StringName, s_idx: int, inv_idx: int) -> void:
		if net_crendice != null:
			net_crendice.req_insert(slot, s_idx, inv_idx)
	)
	crendice_altar.remove_requested.connect(func(slot: StringName, s_idx: int) -> void:
		if net_crendice != null:
			net_crendice.req_remove(slot, s_idx)
	)
	crendice_altar.consecrate_requested.connect(func(slot: StringName, s_idx: int) -> void:
		if net_crendice != null:
			net_crendice.req_consecrate(slot, s_idx)
	)
	windows_layer.add_child(crendice_altar)

	# Agente Q: barra 1–0, XP, janelas de skills/atributos/missões e acompanhamento de missões.
	progression = ProgressionHud.new(self)
	add_child(progression)

	dialogue = DialogueBox.new(ui_scale)
	dialogue.choice_selected.connect(func(i: int) -> void: _send(&"send_dialogue_choice", [i]))
	dialogue.close_requested.connect(_close_dialogue)
	add_child(dialogue)

	toasts = ToastStack.new(ui_scale)
	add_child(toasts)
	# Barras de vida e mana do jogador (K, scripts/client/combat/player_bars.gd).
	player_bars = PlayerBars.new(ui_scale, net)
	add_child(player_bars)
	# Grupo: painel na lateral (abaixo das barras), convite e menu de jogador.
	party_panel = PartyPanel.new(ui_scale, net_party)
	party_panel.local_name = local_player_name()
	party_panel.leave_requested.connect(_party_send.bind(&"send_leave", []))
	party_panel.xp_mode_requested.connect(func(mode: StringName) -> void:
		_party_send(&"send_xp_mode", [mode]))
	party_panel.member_clicked.connect(func(n: String, at: Vector2) -> void: open_player_menu(n, at))
	add_child(party_panel)
	party_invite = PartyInviteDialog.new(ui_scale)
	party_invite.accept_requested.connect(_party_send.bind(&"send_accept", []))
	party_invite.decline_requested.connect(_party_send.bind(&"send_decline", []))
	add_child(party_invite)
	player_menu = PlayerMenu.new(ui_scale)
	player_menu.invite_requested.connect(func(n: String) -> void: _party_send(&"send_invite", [n]))
	player_menu.kick_requested.connect(func(n: String) -> void: _party_send(&"send_kick", [n]))
	player_menu.make_leader_requested.connect(func(n: String) -> void: _party_send(&"send_make_leader", [n]))
	player_menu.trade_requested.connect(func(n: String) -> void: _trade_send(&"send_request", [n]))
	add_child(player_menu)
	trade_request = PartyInviteDialog.new(ui_scale, "UI_TRADE_REQUEST_TITLE", "UI_TRADE_REQUEST_TEXT", &"TradeRequestDialog")
	trade_request.accept_requested.connect(_trade_send.bind(&"send_accept", []))
	trade_request.decline_requested.connect(_trade_send.bind(&"send_decline", []))
	add_child(trade_request)
	if net_trade != null and str(net_trade.get(&"client_request_from")) != "":
		trade_request.show_invite.call_deferred(str(net_trade.get(&"client_request_from")), Balance.cfg.trade_request_timeout_sec)
	if net_party != null and str(net_party.get(&"client_invite_from")) != "":
		party_invite.show_invite.call_deferred(str(net_party.get(&"client_invite_from")), Balance.cfg.party_invite_timeout_sec)
	# Agente G: atlas do mundo (M), por cima de tudo.
	world_atlas = WorldAtlas.new()
	add_child(world_atlas)

	combat_assist = CombatAssist.new(self)
	add_child(combat_assist)
	# Controles touch para mobile (analógico virtual + cluster de 4 atalhos)
	var is_mob: bool = GameSettings.get_instance().mobile_controls
	if is_mob:
		mobile_controls = (MOBILE_CONTROLS_OVERLAY_SCRIPT as Script).new(self, ui_scale)
		add_child(mobile_controls)
		if progression != null and progression.hotbar != null:
			progression.hotbar.set_mobile_layout(true)
		if chat != null:
			chat.set_mobile_layout(true)
			chat.set_minimized(true)
		if gear != null:
			gear.set_mobile_layout(true)
	gamepad = GamepadInput.new(self, combat_assist)
	add_child(gamepad)
	gamepad_hints = GamepadHints.new(ui_scale)
	gamepad_hints.visible = false
	gamepad_hints.anchor = chat
	add_child(gamepad_hints)
	gamepad.hints = gamepad_hints
	focus_ring = GamepadInput.FocusRing.new(ui_scale)
	focus_ring.pad = gamepad
	add_child(focus_ring)
	gamepad.mode_changed.connect(func(_on: bool) -> void: _apply_input_layout())
	_apply_input_layout()

	inventory.default_anchor = INVENTORY_ANCHOR
	equipment.default_anchor = CHARACTER_ANCHOR
	shop.default_anchor = SHOP_ANCHOR
	settings.default_anchor = SETTINGS_ANCHOR
	crendice_altar.default_anchor = Vector2(0.5, 0.5)
	trade_window.default_anchor = Vector2(0.5, 0.0)
	_restack()
	windows_layer.child_entered_tree.connect(func(n: Node) -> void:
		if n is GameWindow:
			(n as GameWindow).opened.connect(_on_window_opened.bind(n)))
	for w: Node in windows_layer.get_children():
		if w is GameWindow:
			(w as GameWindow).opened.connect(_on_window_opened.bind(w))

	# Estado atual.
	inventory.set_slots(_slots)
	inventory.set_stars(_stars)
	inventory.set_shop_open(_shop_open)
	equipment.set_equipment(_equip)
	equipment.set_stats(_stats)
	equipment.set_stars(_stars)
	shop.set_stars(_stars)
	shop.set_shop(_shop_id, _shop_items)
	# Cena da história por cima de tudo (mantida entre reconstruções).
	if story_scene != null:
		add_child(story_scene)
	_built = true
	# Posições iniciais depois do primeiro layout.
	await get_tree().process_frame
	if not is_instance_valid(inventory):
		return
	inventory.place(INVENTORY_ANCHOR)
	equipment.place(CHARACTER_ANCHOR)
	shop.place(SHOP_ANCHOR)
	settings.place(SETTINGS_ANCHOR)
	for w: GameWindow in [inventory, equipment, shop, settings]:
		if reopen.get(w.name, false):
			w.visible = true
	if _shop_open:
		shop.visible = true
		_dock_shop()
	if net_trade != null and not (net_trade.get(&"client_trade") as Dictionary).is_empty():
		_on_trade_changed(net_trade.get(&"client_trade") as Dictionary)
	if not _dialogue_args.is_empty():
		dialogue.show_dialogue(_dialogue_args[0], _dialogue_args[1], _dialogue_args[2], _dialogue_args[3])


func _build_hud_buttons() -> void:
	# GDD §9.5: uma engrenagem (menus) + carinha (emotes) no canto; atalhos de teclado iguais.
	gear = GearMenu.new(ui_scale)
	add_child(gear)
	emotes = gear.emotes
	emotes.emote_selected.connect(send_emote)
	hud_buttons = gear.entries
	add_menu_entry("UI_INVENTORY", "I", MenuIcons.INVENTORY, func() -> void: inventory.toggle())
	add_menu_entry("UI_CHARACTER", "C", MenuIcons.CHARACTER, func() -> void: equipment.toggle())
	add_menu_entry("UI_MENU", "Esc", MenuIcons.SETTINGS, func() -> void: settings.toggle())


## Entrada no menu da engrenagem (ícone + nome + atalho). index < 0 = no fim.
func add_menu_entry(key: String, hotkey: String, icon_id: StringName, cb: Callable, index: int = -1) -> Button:
	return gear.add_entry(key, hotkey, icon_id, cb, index)


# --- Grupo (NetParty) -----------------------------------------------------------------------------

const PARTY_SIGNALS: Dictionary[StringName, StringName] = {
	&"party_changed": &"_on_party_changed", &"invite_received": &"_on_party_invite",
	&"invite_closed": &"_on_party_invite_closed", &"player_list_received": &"_on_player_list",
	&"player_menu_requested": &"_on_player_menu_requested",
}


func _connect_party() -> void:
	if net_party == null:
		net_party = get_node_or_null(^"/root/NetParty")
	if net_trade == null:
		net_trade = get_node_or_null(^"/root/NetTrade")
	if net_trade != null:
		for sig: StringName in TRADE_SIGNALS:
			var tcb := Callable(self, TRADE_SIGNALS[sig])
			if net_trade.has_signal(sig) and not net_trade.is_connected(sig, tcb):
				net_trade.connect(sig, tcb)
	if net_crendice == null:
		net_crendice = get_node_or_null(^"/root/NetCrendice")
	if net_crendice != null:
		if net_crendice.has_signal(&"altar_opened") and not net_crendice.is_connected(&"altar_opened", Callable(self, &"_on_crendice_altar_opened")):
			net_crendice.connect(&"altar_opened", Callable(self, &"_on_crendice_altar_opened"))
		if net_crendice.has_signal(&"result_received") and not net_crendice.is_connected(&"result_received", Callable(self, &"_on_crendice_result")):
			net_crendice.connect(&"result_received", Callable(self, &"_on_crendice_result"))
	if net_party == null:
		return
	for sig: StringName in PARTY_SIGNALS:
		var cb := Callable(self, PARTY_SIGNALS[sig])
		if net_party.has_signal(sig) and not net_party.is_connected(sig, cb):
			net_party.connect(sig, cb)


func _on_crendice_altar_opened(altar_name: String) -> void:
	if crendice_altar == null:
		return
	crendice_altar.set_equipment_data(_equip)
	crendice_altar.set_inventory_data(_slots)
	crendice_altar.open_altar(altar_name)


func _on_crendice_result(action: String, ok: bool, message: String) -> void:
	var tr_msg: String = tr(message)
	if toasts != null:
		toasts.push(tr_msg, not ok)
	if ok:
		AudioDirector.play_sfx(&"skill_learned" if action == "consecrate" else &"equip")


# --- Troca (NetTrade) ------------------------------------------------------------------------------

const TRADE_SIGNALS: Dictionary[StringName, StringName] = {
	&"request_received": &"_on_trade_request", &"request_closed": &"_on_trade_request_closed",
	&"trade_changed": &"_on_trade_changed",
}


func _trade_send(method: StringName, args: Array) -> void:
	if net_trade != null and net_trade.has_method(method):
		net_trade.callv(method, args)


func _on_trade_request(from_name: String, timeout_sec: float) -> void:
	trade_request.show_invite(from_name, timeout_sec)
	AudioDirector.play_sfx(&"chat")


func _on_trade_request_closed() -> void:
	trade_request.hide_invite()


## Troca aberta: janela da troca ao lado do inventário (o inventário abre junto; botão direito põe na oferta).
func _on_trade_changed(state: Dictionary) -> void:
	var was_open: bool = trade_window.visible
	inventory.trade_open = not state.is_empty()
	trade_window.set_state(state, _stars)
	if not state.is_empty() and not was_open:
		inventory.open()
		trade_window.fit_to_screen()
		if UIKit.is_touch_layout():
			_dock_pair(trade_window)
			return
		var gap: int = UIKit.px(WINDOW_GAP_PX, ui_scale)
		trade_window.position = Vector2(inventory.position.x - trade_window.size.x - gap, inventory.position.y)
		trade_window.clamp_to_screen()


func _party_send(method: StringName, args: Array) -> void:
	if net_party != null and net_party.has_method(method):
		net_party.callv(method, args)


## Nome do jogador local (para o menu e o painel).
func local_player_name() -> String:
	var nw: Node = get_node_or_null(^"/root/NetWorld")
	var p: Variant = nw.get(&"client_player") if nw != null else null
	if is_instance_valid(p) and p is Node:
		return str((p as Node).get(&"display_name"))
	return str(net.get(&"_client_name")) if net != null and &"_client_name" in net else ""


## Abre o menu do jogador (convidar, passar liderança, expulsar). Devolve os itens mostrados.
func open_player_menu(player_name: String, at: Vector2 = Vector2.INF) -> Array[StringName]:
	if at == Vector2.INF:
		at = get_global_mouse_position()
	var party: Dictionary = net_party.get(&"client_party") if net_party != null else {}
	return player_menu.open_for(player_name, at, local_player_name(), party, true)


func _on_player_menu_requested(_entity_id: int, player_name: String) -> void:
	open_player_menu(player_name)


func _on_party_changed(_state: Dictionary) -> void:
	if party_panel != null:
		party_panel.local_name = local_player_name()
	# Nome sobre a cabeça: membros do grupo ganham a cor do grupo.
	var nc: Node = get_node_or_null(^"/root/NetCombat")
	if nc != null and nc.has_method(&"all_entities"):
		for e: Node3D in nc.call(&"all_entities"):
			var v: Node = e.call(&"get_visual") if e.has_method(&"get_visual") else null
			if v != null and v.has_method(&"refresh_party_color"):
				v.call(&"refresh_party_color")


func _on_party_invite(from_name: String, timeout_sec: float) -> void:
	party_invite.show_invite(from_name, timeout_sec)
	AudioDirector.play_sfx(&"chat")


func _on_party_invite_closed() -> void:
	party_invite.hide_invite()


## /online e /grupo: lista no chat (uma linha por jogador).
func _on_player_list(kind: StringName, entries: Array) -> void:
	var party: bool = kind == NetParty.LIST_PARTY
	if party:
		var max_size: int = int((net_party.get(&"client_party") as Dictionary).get(NetParty.K_MAX, Balance.cfg.party_max_size)) \
				if net_party != null else Balance.cfg.party_max_size
		chat.add_system(UIKit.format_message("UI_PARTY_LIST_HEADER", [entries.size(), max_size]), true)
	else:
		chat.add_system(UIKit.format_message("UI_ONLINE_HEADER", [entries.size()]))
	for e: Variant in entries:
		var d: Dictionary = e
		var who: String = str(d.get(NetParty.K_NAME, ""))
		if bool(d.get(NetParty.K_IS_LEADER, false)):
			who += " (%s)" % tr("UI_PARTY_LEADER")
		if not bool(d.get(NetParty.K_ONLINE, true)):
			chat.add_system("  " + UIKit.format_message("UI_PLAYER_LIST_OFFLINE", [who]), party)
			continue
		chat.add_system("  " + UIKit.format_message("UI_PLAYER_LIST_ENTRY", [who, int(d.get(NetParty.K_LEVEL, 1)),
				PartyPanel.map_display_name(StringName(str(d.get(NetParty.K_MAP, ""))))]), party)
	_save_chat()


# --- Ações ----------------------------------------------------------------------------------------

func send_emote(emote_id: StringName) -> void:
	_send(&"send_emote", [emote_id])


func _close_dialogue() -> void:
	if not dialogue.visible:
		return
	dialogue.hide_dialogue()
	_dialogue_args = []
	_send(&"send_dialogue_close")


func _on_shop_window_closed() -> void:
	# Fechar a janela avisa o servidor (libera o NPC). Se foi o servidor que fechou, não reenvia.
	var was_open: bool = _shop_open
	_shop_open = false
	inventory.set_shop_open(false)
	if was_open:
		_send(&"send_shop_close")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	if is_typing():
		return
	var key: InputEventKey = event as InputEventKey
	if dialogue.visible and not key.alt_pressed:
		var digit: int = key.keycode - KEY_1
		if digit >= 0 and digit < MAX_DIALOGUE_HOTKEYS and digit < dialogue.get_option_count():
			dialogue.choose(digit)
			get_viewport().set_input_as_handled()
			return
	for i: int in UIKit.EMOTES.size():
		if event.is_action_pressed(StringName(ACTION_EMOTE_PREFIX + str(i + 1)), false, true):
			send_emote(UIKit.EMOTES[i])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(ACTION_INVENTORY, false, true):
		inventory.toggle()
	elif event.is_action_pressed(ACTION_CHARACTER, false, true):
		equipment.toggle()
	elif event.is_action_pressed(WorldAtlas.ACTION_TOGGLE, false, true):
		_toggle_map_views()
	elif event.is_action_pressed(ACTION_CHAT):
		chat.open_input()
	elif event.is_action_pressed(ACTION_MENU):
		if not close_top():
			settings.open()
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle_map_views() -> void:
	var minimap: Minimap = get_parent().get_node_or_null(^"Minimap") as Minimap if get_parent() != null else null
	var area_map: WorldMap = minimap.world_map if minimap != null else null
	if world_atlas.visible:
		world_atlas.close()
	elif area_map != null and area_map.visible:
		area_map.visible = false
		world_atlas.open()
	elif area_map != null:
		area_map.visible = true
	else:
		world_atlas.open()


func _register_actions() -> void:
	_add_key(ACTION_INVENTORY, KEY_I)
	_add_key(ACTION_CHARACTER, KEY_C)
	_add_key(ACTION_CHAT, KEY_ENTER)
	_add_key(ACTION_CHAT, KEY_KP_ENTER)
	_add_key(ACTION_MENU, KEY_ESCAPE)
	WorldAtlas.register_action()
	for i: int in UIKit.EMOTES.size():
		_add_key(StringName(ACTION_EMOTE_PREFIX + str(i + 1)), KEY_1 + i, true)


func _add_key(action: StringName, key: Key, alt: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.alt_pressed = alt
	ev.device = ANY_DEVICE
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == key:
			return
	InputMap.action_add_event(action, ev)


static func _total_items(slots: Array) -> int:
	var n: int = 0
	for e: Variant in slots:
		if e is Dictionary:
			n += int((e as Dictionary).get("qty", 0))
	return n


func set_mobile_mode(enabled: bool) -> void:
	GameSettings.get_instance().mobile_controls = enabled
	if enabled:
		if mobile_controls == null:
			mobile_controls = (MOBILE_CONTROLS_OVERLAY_SCRIPT as Script).new(self, ui_scale)
			add_child(mobile_controls)
		mobile_controls.visible = true
		if progression != null and progression.hotbar != null:
			progression.hotbar.set_mobile_layout(true)
		if chat != null:
			chat.set_mobile_layout(true)
			chat.set_minimized(true)
		if gear != null:
			gear.set_mobile_layout(true)
	else:
		if mobile_controls != null:
			mobile_controls.visible = false
		if progression != null and progression.hotbar != null:
			progression.hotbar.set_mobile_layout(false)
		if chat != null:
			chat.set_mobile_layout(false)
		if gear != null:
			gear.set_mobile_layout(false)
	_apply_input_layout()
	_restack()


## Controle em uso (GamepadInput.is_pad_mode).
func is_pad_mode() -> bool:
	return gamepad != null and is_instance_valid(gamepad) and gamepad.is_pad_mode()


## Toque × controle: com o controle em uso os controles de toque somem (a configuração mobile_controls
## continua como está e volta a valer quando o controle sai de uso), a barra de atalhos reaparece com os
## botões do controle no lugar das teclas e a faixa de dicas aparece.
func _apply_input_layout() -> void:
	var pad: bool = is_pad_mode()
	var touch: bool = GameSettings.get_instance().mobile_controls and not pad
	if mobile_controls != null and is_instance_valid(mobile_controls):
		mobile_controls.visible = touch
		if pad and mobile_controls.config_dialog != null:
			mobile_controls.config_dialog.visible = false
	if progression != null and is_instance_valid(progression.hotbar):
		progression.hotbar.set_mobile_layout(touch)
		progression.hotbar.set_key_texts(GamepadInput.SLOT_LABELS if pad else Hotbar.KEY_TEXTS)
	# Chat compacto do toque fica no meio da barra; com o controle a barra aparece, então o chat volta ao canto.
	if chat != null and is_instance_valid(chat):
		chat.set_mobile_layout(touch)
	if gear != null and is_instance_valid(gear):
		gear.set_mobile_layout(touch)
		for b: Node in gear.entries.get_children():
			var hotkey: Control = b.get_node_or_null(^"Row/Hotkey") as Control
			if hotkey != null:
				hotkey.visible = not pad
	if gamepad_hints != null and is_instance_valid(gamepad_hints):
		gamepad_hints.visible = pad

