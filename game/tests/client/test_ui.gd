extends Node
## Teste visual e funcional da interface do cliente SEM rede (dublê do Net). Precisa de display:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --resolution 1920x1080 \
##       res://tests/client/test_ui.tscn -- --out=/caminho
## Abre inventário+equipamento, loja, diálogo e chat com dados falsos; NPC com nome, balão de emote e
## cursor em cima (hover); jogador em camadas (chapéu/bastão de teste) e confere ordem/espelho;
## clique no NPC → interact_requested; ações da UI → chamadas send_* do contrato; AudioDirector
## (zonas, chão, sem arquivos = sem erro). Salva capturas em --out.

const CLIENT_VIEW_SCENE: PackedScene = preload("res://scenes/ui/client_view.tscn")
const FAKE_NET_SCRIPT: GDScript = preload("res://tests/client/fake_net.gd")
const STUB_EQUIPMENT_DIR: String = "res://tests/_stub_b/equipment/"
const SETTLE_FRAMES: int = 10
const GROUND_SIZE: float = 40.0
const NPC_ENTITY_ID: int = 1000001
const PLAYER_ENTITY_ID: int = 7
const OTHER_ENTITY_ID: int = 8
const NPC_POS: Vector3 = Vector3(2.4, 0.0, -1.2)
const OTHER_POS: Vector3 = Vector3(-2.6, 0.0, -0.4)
const NPC_ID: StringName = &"merchant"
const SHOP_ITEMS: Array[StringName] = [&"potion_hp_small", &"potion_mp_small", &"machete", &"short_sword",
	&"wooden_staff", &"leather_shield", &"straw_hat", &"walking_boots"]
## Altura (m) acima dos pés onde o cursor aponta para "passar sobre" o NPC.
const HOVER_HEIGHT: float = 1.0
const ZONE_BOX: Vector3 = Vector3(6.0, 4.0, 6.0)
const ZONE_POS: Vector3 = Vector3(10.0, 0.0, 10.0)

var _out_dir: String = "user://"
var _tag: String = ""
var _failures: int = 0
var _view: ClientView
var _ui: GameUI
var _net: Node
var _player: EntityVisual
var _npc: EntityVisual
var _other: EntityVisual
var _interacts: Array[String] = []
var _fake_items: Dictionary[StringName, ItemDef] = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var win: Vector2i = get_viewport().get_visible_rect().size
	_tag = "%dx%d" % [win.x, win.y]
	UIKit.item_provider = _item
	EntityVisual.equipment_dir = STUB_EQUIPMENT_DIR
	_net = FAKE_NET_SCRIPT.new()
	_net.name = "FakeNet"
	add_child(_net)
	_build_world()
	_view = CLIENT_VIEW_SCENE.instantiate() as ClientView
	add_child(_view)
	_ui = _view.get_game_ui()
	_ui.bind_net(_net)
	_view.interact_requested.connect(func(t: String) -> void: _interacts.append(t))
	_view.set_follow_target(_player)
	await _run()
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join("%s_%s.png" % [file, _tag])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)


func _run() -> void:
	await _frames(SETTLE_FRAMES)
	_check(_ui != null, "ClientView criou o GameUI")
	_check(_view.get_audio_director() != null and AudioDirector.instance != null, "AudioDirector ativo")
	_check(AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"UI") >= 0,
			"barramentos Music/UI existem")
	print("ui_scale=%s view_scale=%d" % [_ui.ui_scale, _view.get_view_scale()])

	# --- Mundo: NPC com emote + hover, jogador com fala.
	_npc.show_emote(&"wave")
	_other.show_emote(&"heart")
	_player.show_chat("Olá, Porto do Despertar!")
	_net.chat_received.emit(&"local", "Ana", "Alguém viu o mercador?", PLAYER_ENTITY_ID)
	_net.chat_received.emit(&"local", "Bia", "Ele fica na barraca da feira [perto do ipê]", OTHER_ENTITY_ID)
	_net.system_message.emit("SYS_NOT_ENOUGH_STARS", [])
	await _frames(SETTLE_FRAMES)
	var hover_pos: Vector2 = _world_to_window(_npc.global_position + Vector3.UP * HOVER_HEIGHT)
	_push_motion(hover_pos)
	await _frames(2)
	_check(_view.get_hover_target() == "e:%d" % NPC_ENTITY_ID, "hover no NPC → alvo %s" % _view.get_hover_target())
	_check(_npc.is_hovered(), "NPC destacado no hover")
	_check(_npc.is_emote_visible(), "balão de emote visível")
	_check(_player.is_chat_visible(), "balão de chat visível")
	_check(_npc.get_nameplate().text == tr(Content.npc(NPC_ID).name_key) if Content.npc(NPC_ID) != null else true,
			"nome do NPC traduzido: '%s'" % _npc.get_nameplate().text)
	_check(_ui.toasts.get_texts().has(tr("SYS_NOT_ENOUGH_STARS")), "mensagem de sistema traduzida")
	await _shot("ui_world_hover")

	# Clique no NPC → interact_requested (e não move).
	_push_click(hover_pos)
	await _frames(2)
	_check(_interacts == ["e:%d" % NPC_ENTITY_ID], "clique no NPC → interact_requested %s" % [_interacts])
	# Clique no chão longe de todos → não interage.
	_push_motion(_world_to_window(Vector3(0.0, 0.0, 3.0)))
	await _frames(2)
	_check(_view.get_hover_target() == "", "hover sai do NPC")
	var minimap: Minimap = _view.find_child("Minimap", true, false) as Minimap
	var area_map: WorldMap = minimap.world_map if minimap != null else null
	_check(area_map != null, "mapa local existe junto do minimapa")
	_push_key(KEY_M)
	_check(area_map != null and area_map.visible and not _ui.world_atlas.visible, "M abre o mapa local")
	_push_touch(Vector2(10, 10))
	_check(area_map != null and not area_map.visible, "toque na margem fecha o mapa local")
	_push_key(KEY_M)
	_check(area_map != null and area_map.visible, "M reabre o mapa local")
	_push_key(KEY_M)
	_check(area_map != null and not area_map.visible and _ui.world_atlas.visible, "M troca do mapa local para o atlas global")
	var atlas_view: Control = _ui.world_atlas.get("_view") as Control
	var atlas_center: Vector2 = atlas_view.global_position + atlas_view.size * 0.5
	_push_touch(atlas_center)
	_check(_ui.world_atlas.visible, "toque dentro do atlas mantém o mapa aberto")
	_push_touch(Vector2(10, 10))
	_check(not _ui.world_atlas.visible, "toque fora do mapa fecha o atlas global")

	_test_paper_doll_order()

	# --- Janelas com dados falsos.
	_net.inventory_changed.emit(_fake_slots())
	_net.equipment_changed.emit({"weapon": &"machete", "offhand": &"", "head": &"straw_hat", "body": &"leather_jerkin",
			"feet": &"", "accessory_1": &"seed_necklace", "accessory_2": &"", "cosmetic_head": &"ipe_flower_crown",
			"cosmetic_body": &"", "cosmetic_weapon": &""})
	_net.stats_changed.emit({"level": 3, "hp": 150, "max_hp": 160, "mp": 70, "max_mp": 86, "atk": 22, "matk": 13,
			"def": 9, "mdef": 5, "str": 5, "dex": 5, "vit": 5, "int": 5, "spi": 5})
	_net.currency_changed.emit(100)
	var shop_items: Array[StringName] = SHOP_ITEMS
	_net.shop_opened.emit(&"market", shop_items)
	var options: Array[String] = ["DLG_TEST_OPT_SHOP", "DLG_TEST_OPT_BYE"]
	var text_key: String = "DLG_TEST_TEXT"
	var dlg: DialogueDef = Content.dialogue(NPC_ID)
	if dlg != null and dlg.get_node_by_id(dlg.start_node) != null:
		var node: DialogueNode = dlg.get_node_by_id(dlg.start_node)
		text_key = node.text_key
		options.clear()
		for o: DialogueOption in node.options:
			options.append(o.text_key)
	_ui.equipment.open()
	await _frames(SETTLE_FRAMES)
	_check(_ui.inventory.visible and _ui.shop.visible, "loja abre com o inventário")
	_check(_ui.shop.get_row_count() == SHOP_ITEMS.size(), "loja lista %d itens" % SHOP_ITEMS.size())
	_ui.inventory.select(0)
	await _frames(2)
	_check_inside_screen()
	await _shot("ui_windows")
	# Diálogo (as janelas ficam atrás; a caixa de diálogo vai à frente).
	_ui.equipment.close()
	_ui.shop.close()
	_ui.inventory.close()
	_net.dialogue_opened.emit(NPC_ENTITY_ID, Content.npc(NPC_ID).name_key if Content.npc(NPC_ID) else "NPC",
			text_key, options)
	await _frames(SETTLE_FRAMES)
	_check(_ui.dialogue.visible and _ui.dialogue.get_option_count() == options.size(),
			"diálogo com %d opções" % options.size())
	_check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(
			Rect2(_ui.dialogue.global_position, _ui.dialogue.size)), "diálogo dentro da tela")
	await _shot("ui_dialogue")
	_net.shop_opened.emit(&"market", shop_items)

	# --- Ações → intenções do contrato.
	_ui.dialogue.choose(1)
	_check(_net.last_call(&"send_dialogue_choice") == [1], "opção → send_dialogue_choice(1)")
	_ui.shop.buy(&"potion_hp_small")
	_check(_net.last_call(&"send_shop_buy") == [&"potion_hp_small", 1], "comprar → send_shop_buy %s" % [_net.last_call(&"send_shop_buy")])
	var inv: InventoryWindow = _ui.inventory
	inv._on_slot_dropped(inv.get_slot(5), {"item_slot_drag": true, "source": &"inventory", "index": 0,
			"equip_slot": &"", "item": &"potion_hp_small", "qty": 2})
	_check(_net.last_call(&"send_inventory_move") == [0, 5], "arrastar 0→5 → send_inventory_move")
	inv._on_slot_activated(inv.get_slot(0), true)
	_check(_net.last_call(&"send_shop_sell") == [0, 1], "botão direito com loja → send_shop_sell(0, 1)")
	_ui.shop._drop_sell(Vector2.ZERO, {"item_slot_drag": true, "source": &"inventory", "index": 3, "qty": 5})
	_check(_net.last_call(&"send_shop_sell") == [3, 5], "arrastar para a loja → send_shop_sell(3, 5)")
	var closes_before: int = _net.count(&"send_shop_close")
	_ui.shop.close()
	_check(_net.count(&"send_shop_close") == closes_before + 1, "fechar a loja → send_shop_close")
	_net.shop_closed.emit()
	_check(_net.count(&"send_shop_close") == closes_before + 1, "loja fechada pelo servidor não reenvia")
	inv._on_slot_activated(inv.get_slot(1), false)
	_check(_net.last_call(&"send_equip") == [1], "duplo clique na arma → send_equip(1)")
	inv._on_slot_activated(inv.get_slot(0), true)
	_check(_net.last_call(&"send_use_item") == [0], "botão direito na poção (sem loja) → send_use_item(0)")
	_ui.equipment._unequip(&"weapon")
	_check(_net.last_call(&"send_unequip") == [&"weapon"], "desequipar → send_unequip(weapon)")
	_ui.equipment._on_slot_dropped(_ui.equipment.get_slot(&"weapon"), {"item_slot_drag": true,
			"source": &"inventory", "index": 2, "item": &"short_sword", "qty": 1})
	_check(_net.last_call(&"send_equip") == [2], "arrastar espada para Arma → send_equip(2)")
	var equips_before: int = _net.count(&"send_equip")
	_ui.equipment._on_slot_dropped(_ui.equipment.get_slot(&"head"), {"item_slot_drag": true,
			"source": &"inventory", "index": 2, "item": &"short_sword", "qty": 1})
	_check(_net.count(&"send_equip") == equips_before, "espada no espaço Cabeça é recusada no cliente")
	_check(_ui.chat.submit("Oi!"), "chat envia")
	_check(_net.last_call(&"send_chat") == [&"local", "Oi!"], "send_chat(local, 'Oi!')")
	_ui.progression.hotbar.set_mobile_layout(true)
	_check(_ui.progression.hotbar.visible and not _ui.progression.hotbar.find_child("Tray", true, false).visible
			and _ui.progression.hotbar.find_child("XPBar", true, false) != null,
			"mobile esconde slots mas mantém barra de XP")
	_ui.progression.hotbar.set_mobile_layout(false)
	_check(_ui.chat.minimize_button.text == "−", "botão recolher chat mostra estado inicial")
	_ui.chat.minimize_button.pressed.emit()
	_check(_ui.chat.is_minimized() and not _ui.chat.find_child("History", true, false).visible
			and not _ui.chat.find_child("Input", true, false).visible, "chat pode ser recolhido")
	_ui.chat.minimize_button.pressed.emit()
	_check(not _ui.chat.is_minimized() and _ui.chat.find_child("Input", true, false).visible,
			"chat pode ser expandido novamente")
	var previous_mobile: bool = GameSettings.get_instance().mobile_controls
	_ui.set_mobile_mode(true)
	_check(_ui.chat.is_minimized(), "chat inicia recolhido ao ativar controles mobile")
	_ui.chat.minimize_button.pressed.emit()
	_check(not _ui.chat.is_minimized(), "jogador mobile pode expandir o chat manualmente")
	_ui.set_mobile_mode(previous_mobile)
	_check(not _ui.chat.submit("De novo"), "segunda msg em < 1 s bloqueada")
	_check(_ui.toasts.get_texts().has(tr("SYS_CHAT_TOO_FAST")), "aviso de chat rápido")
	_ui.emotes.emote_selected.emit(&"heart")
	_check(_net.last_call(&"send_emote") == [&"heart"], "barra de emotes → send_emote(heart)")
	_push_key(KEY_3, true)
	_check(_net.last_call(&"send_emote") == [&"laugh"], "Alt+3 → send_emote(laugh)")
	_push_key(KEY_ESCAPE)
	_check(not _ui.dialogue.visible and _net.count(&"send_dialogue_close") == 1, "Esc fecha o diálogo → send_dialogue_close")
	_ui.inventory.close()
	_push_key(KEY_I)
	_check(_ui.inventory.visible, "tecla I abre o inventário")
	_push_key(KEY_I)
	_check(not _ui.inventory.visible, "tecla I fecha o inventário")
	_push_key(KEY_C)
	_check(_ui.equipment.visible, "tecla C abre o personagem")
	_push_key(KEY_C)
	_check(not _ui.equipment.visible, "tecla C fecha o personagem")
	_push_key(KEY_ESCAPE)
	_check(_ui.settings.visible, "Esc sem nada aberto → configurações")
	await _frames(SETTLE_FRAMES)
	var quality: OptionButton = _ui.settings.find_child("GraphicsQuality", true, false) as OptionButton
	var old_quality: EnvQuality.Preset = GameSettings.get_instance().graphics_quality
	_check(quality != null and quality.item_count == 3, "configurações oferecem Alta/Média/Baixa")
	_check(GameSettings.default_quality_for_platform(true) == EnvQuality.Preset.BAIXA
			and GameSettings.default_quality_for_platform(false) == EnvQuality.Preset.ALTA,
			"perfil mobile começa econômico sem alterar o padrão desktop")
	_check(is_equal_approx(GameSettings.render_scale_for_quality(true, EnvQuality.Preset.BAIXA), 0.67)
			and is_equal_approx(GameSettings.render_scale_for_quality(true, EnvQuality.Preset.MEDIA), 1.0)
			and is_equal_approx(GameSettings.render_scale_for_quality(false, EnvQuality.Preset.BAIXA), 1.0),
			"escala reduz apenas o mundo mobile no preset Baixa")
	if quality != null:
		quality.select(int(EnvQuality.Preset.BAIXA))
		quality.item_selected.emit(int(EnvQuality.Preset.BAIXA))
		_check(EnvQuality.current == EnvQuality.Preset.BAIXA, "qualidade escolhida aplica sem reiniciar")
		quality.select(int(old_quality))
		quality.item_selected.emit(int(old_quality))
	await _shot("ui_settings")
	_push_key(KEY_ESCAPE)
	_check(not _ui.settings.visible, "Esc fecha configurações")
	_push_key(KEY_ENTER)
	_check(_ui.is_typing(), "Enter abre o chat")
	var yaw_before: float = _view.camera_yaw
	Input.action_press(ClientView.ACTION_ROTATE_LEFT)
	await _frames(3)
	Input.action_release(ClientView.ACTION_ROTATE_LEFT)
	_check(is_equal_approx(_view.camera_yaw, yaw_before), "digitando no chat, Q não gira a câmera")
	_push_key(KEY_ESCAPE)
	_check(not _ui.is_typing(), "Esc cancela o chat")
	_net.connection_closed.emit("NET_NAME_IN_USE")
	_check(_ui.toasts.get_texts().has(tr("NET_NAME_IN_USE")) and TitleScreen.pending_status == "NET_NAME_IN_USE",
			"connection_closed mostra o motivo")
	TitleScreen.pending_status = ""
	await _test_party()
	await _test_audio()


## Grupo (30/09/2026): painel, menu do jogador, janela de convite e abas do chat (sem servidor).
func _test_party() -> void:
	var saved_player: Node3D = NetWorld.client_player
	var me := NetEntity.new()
	me.display_name = "Eu"
	NetWorld.client_player = me
	var my_name: String = _ui.local_player_name()
	_check(my_name == "Eu", "nome do jogador local para o grupo (%s)" % my_name)
	_check(not _ui.party_panel.visible, "sem grupo, sem painel")
	var state: Dictionary = {"leader": my_name, "max": 5, "xp_mode": "split", "members": [
		{"name": my_name, "level": 3, "hp": 50, "max_hp": 100, "mp": 10, "max_mp": 20, "map": "city_awakening",
				"online": true, "is_leader": true, "entity_id": 1},
		{"name": "Amiga", "level": 4, "hp": 80, "max_hp": 100, "mp": 5, "max_mp": 20, "map": "fields_sabia",
				"online": true, "is_leader": false, "entity_id": 2},
		{"name": "Sumido", "level": 2, "hp": 0, "max_hp": 1, "mp": 0, "max_mp": 1, "map": "",
				"online": false, "is_leader": false, "entity_id": 0}]}
	NetParty._cli_party_state(state)
	await _frames(2)
	_check(_ui.party_panel.visible and _ui.party_panel.member_count() == 3, "painel do grupo com 3 membros")
	_check(_ui.party_panel.xp_split_button.button_pressed and not _ui.party_panel.xp_split_button.disabled,
			"líder vê XP dividida selecionada e pode alterar")
	var row: Control = _ui.party_panel.row_for("Amiga")
	_check(row != null and (row.get_node(^"Hp") as ProgressBar).value == 80.0, "vida do membro no painel")
	_check(row != null and row.get_node_or_null(^"Map") != null, "membro em outro mapa mostra o mapa")
	var off: Control = _ui.party_panel.row_for("Sumido")
	_check(off != null and off.modulate.a < 1.0 and (off.get_node(^"Map") as Label).text == tr("UI_PARTY_OFFLINE"),
			"membro desconectado aparece apagado")
	var lead: Control = _ui.party_panel.rows.get_child(0) as Control
	_check(lead != null and (lead.find_child("Crown", true, false) as Control).modulate.a > 0.5, "coroa no líder")
	_check(_ui.party_panel.get_global_rect().end.y < _ui.chat.get_global_rect().position.y, "painel acima do chat")
	state[NetParty.K_XP_MODE] = "individual"
	NetParty._cli_party_state(state)
	await _frames(1)
	_check(_ui.party_panel.xp_individual_button.button_pressed, "painel acompanha XP individual replicada")
	_check(_ui.open_player_menu("Estranho", Vector2(300, 300)) == [PlayerMenu.ITEM_INVITE, PlayerMenu.ITEM_TRADE],
			"líder: menu de quem é de fora = convidar e propor troca")
	_check(_ui.open_player_menu("Amiga", Vector2(300, 300)) == [PlayerMenu.ITEM_LEADER, PlayerMenu.ITEM_KICK, PlayerMenu.ITEM_TRADE],
			"líder: menu do membro = passar liderança, expulsar e propor troca")
	_ui.player_menu.close()
	state["leader"] = "Amiga"
	NetParty._cli_party_state(state)
	await _frames(1)
	_check(_ui.party_panel.xp_individual_button.disabled, "membro sem liderança não pode mudar modo de XP")
	_check(_ui.open_player_menu("Estranho", Vector2(300, 300)) == [PlayerMenu.ITEM_TRADE], "membro comum não convida (só troca)")
	_ui.player_menu.close()
	NetParty.invite_received.emit("Fulana", 30.0)
	await _frames(2)
	_check(_ui.party_invite.visible and _ui.party_invite.text_label.text.contains("Fulana"), "janela de convite abre")
	await _shot("party_ui")
	_ui.party_invite.decline_button.pressed.emit()
	_check(not _ui.party_invite.visible, "recusar fecha a janela de convite")
	_ui.chat.add_message("Amiga", "oi time", &"party")
	_ui.chat.add_message("Outro", "oi mapa", &"local")
	_ui.chat.set_tab(ChatBox.TAB_PARTY)
	var lines: PackedStringArray = _ui.chat.visible_lines()
	_check(lines.size() >= 1 and "oi time" in lines[-1] and not ("oi mapa" in "\n".join(lines)), "aba Grupo filtra o chat")
	await get_tree().create_timer(1.1).timeout
	_check(_ui.chat.submit("bora"), "chat na aba Grupo envia")
	_check(_net.last_call(&"send_chat") == [&"party", "bora"], "aba Grupo → send_chat(party) %s" % [_net.last_call(&"send_chat")])
	_ui.chat.set_tab(ChatBox.TAB_ALL)
	_check("oi mapa" in "\n".join(_ui.chat.visible_lines()), "aba Todos mostra tudo")
	NetParty._cli_party_state({})
	await _frames(1)
	_check(not _ui.party_panel.visible, "grupo desfeito some o painel")
	# Troca (sem servidor): janela com os dois lados, nome e ícone dos itens, botões.
	var trade_state: Dictionary = {"partner": "Amiga",
		"mine": {"items": [{"slot": 0, "item": "potion_hp_small", "qty": 2}], "stars": 10, "confirmed": true, "committed": false},
		"theirs": {"items": [{"slot": -1, "item": "short_sword", "qty": 1}], "stars": 0, "confirmed": false, "committed": false}}
	NetTrade._cli_state(trade_state)
	await _frames(2)
	var tw: TradeWindow = _ui.trade_window
	_check(tw.visible and tw.mine_count() == 1 and tw.theirs_count() == 1, "janela de troca com os dois lados")
	var row_label: Label = tw.mine_list.get_child(0).get_node_or_null(^"Name") as Label
	_check(row_label != null and row_label.text.contains(tr(Content.item(&"potion_hp_small").name_key)), "item da troca mostra o nome")
	_check(tw.commit_button.disabled, "Trocar desligado sem a confirmação dos dois")
	_check(tw.confirm_button.text == tr("UI_TRADE_UNCONFIRM"), "confirmado: botão vira Mudar")
	trade_state["theirs"]["confirmed"] = true
	NetTrade._cli_state(trade_state)
	await _frames(1)
	_check(not tw.commit_button.disabled, "os dois confirmados: Trocar liga")
	_check(_ui.inventory.visible and _ui.inventory.trade_open, "troca abre o inventário junto")
	await _shot("trade_ui")
	_check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(tw.get_global_rect()), "janela de troca dentro da tela")
	NetTrade._cli_state({})
	await _frames(1)
	_check(not tw.visible and not _ui.inventory.trade_open, "troca fechada some a janela")
	NetWorld.client_player = saved_player
	me.free()


## Camadas: frente (S) = corpo < chapéu < arma; costas (N) = arma(_back) < corpo < chapéu; espelho igual.
func _test_paper_doll_order() -> void:
	var cam: Camera3D = _view.get_camera()
	var cases: Array[Array] = [[PI, [&"Body", &"Head", &"WeaponFront"]], [0.0, [&"WeaponBack", &"Body", &"Head"]],
			[PI * 0.25, [&"WeaponBack", &"Body", &"Head"]]]
	for c: Array in cases:
		_player.facing_yaw = c[0]
		_player._process(0.0)
		var got: Array[StringName] = _player.get_visible_layer_order()
		_check(str(got) == str(c[1]), "camadas yaw %.2f: %s" % [c[0], got])
		var hat: Sprite3D = _player.get_overlay_sprite(&"Head")
		_check(hat.flip_h == _player.get_body_sprite().flip_h and hat.frame % hat.hframes
				== _player.get_body_sprite().frame % _player.get_body_sprite().hframes,
				"chapéu no mesmo quadro/espelho do corpo (yaw %.2f)" % c[0])
		# Ordem de profundidade: camada da frente mais perto da câmera.
		var body_d: float = cam.global_position.distance_to(_player.get_body_sprite().global_position)
		var hat_d: float = cam.global_position.distance_to(hat.global_position)
		_check(hat_d < body_d, "chapéu mais perto da câmera que o corpo")
	_player.facing_yaw = PI


func _test_audio() -> void:
	var audio: AudioDirector = _view.get_audio_director()
	AudioDirector.play_sfx(&"ui_click")
	AudioDirector.play_sfx(&"does_not_exist")
	AudioDirector.play_sfx(&"sfx_buy", Vector3.ZERO)
	# Mapa falso com zona "docks" e chão de madeira.
	var map := Node3D.new()
	map.name = "Map"
	map.set_meta(&"map_id", &"city_awakening")
	var zones := Node3D.new()
	zones.name = "AudioZones"
	map.add_child(zones)
	var area := Area3D.new()
	area.set_meta(&"zone_id", &"docks")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ZONE_BOX
	cs.shape = box
	area.add_child(cs)
	zones.add_child(area)
	area.position = ZONE_POS
	var deck := StaticBody3D.new()
	deck.collision_layer = 1
	deck.set_meta(&"surface", &"wood")
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(ZONE_BOX.x, 0.2, ZONE_BOX.z)
	dcs.shape = dbox
	deck.add_child(dcs)
	deck.position = ZONE_POS + Vector3.UP * 0.05
	map.add_child(deck)
	$World.add_child(map)
	audio.set_map(map)
	await _frames(SETTLE_FRAMES)
	_check(audio.current_zone == AudioDirector.DEFAULT_ZONE, "zona padrão fora das docas (%s)" % audio.current_zone)
	_player.position = ZONE_POS
	await get_tree().create_timer(AudioDirector.ZONE_CHECK_SEC * 2.0).timeout
	_check(audio.current_zone == &"docks", "entrou na zona docks (%s)" % audio.current_zone)
	await get_tree().physics_frame
	_check(audio.surface_at(_player.global_position) == &"wood", "chão de madeira sob o jogador")
	_check(audio.surface_at(Vector3.ZERO) == &"stone", "chão sem meta = stone")
	var zone_music: AudioStream = audio.current_music
	_ui._on_system_message("PROG_MSG_WEREWOLF_ENDING_HEALED", [])
	_check(audio.current_music == zone_music, "final curado não toca a música triste")
	_ui._on_system_message("PROG_MSG_WEREWOLF_ENDING_DEATH", [])
	_check(audio.current_music != zone_music and audio.current_music.resource_path.ends_with("mus_werewolf_death.ogg"),
			"final mortal toca o cue triste original")
	print("música atual: %s, camadas de ambiente: %d" % [audio.current_music, audio.get_ambience_count()])
	_player.position = Vector3.ZERO


func _check_inside_screen() -> void:
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for w: Control in [_ui.inventory, _ui.equipment, _ui.shop, _ui.chat]:
		var r := Rect2(w.global_position, w.size)
		_check(screen.encloses(r), "%s dentro da tela (%s em %s)" % [w.name, r, screen.size])


func _world_to_window(p: Vector3) -> Vector2:
	var internal: Vector2 = _view.get_camera().unproject_position(p)
	return _view.get_view_offset() + internal * _view.get_view_scale()


func _push_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev)


func _push_click(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up)


func _push_key(key: Key, alt: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.alt_pressed = alt
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _push_touch(pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventScreenTouch
	up.pressed = false
	get_viewport().push_input(up)


func _fake_slots() -> Array:
	var slots: Array = []
	slots.resize(UIKit.INVENTORY_SIZE)
	slots.fill({})
	slots[0] = {"item": &"potion_hp_small", "qty": 2}
	slots[1] = {"item": &"machete", "qty": 1}
	slots[2] = {"item": &"short_sword", "qty": 1}
	slots[3] = {"item": &"spinning_leaf", "qty": 5}
	slots[4] = {"item": &"potion_mp_small", "qty": 3}
	slots[9] = {"item": &"ribbon_bracelet", "qty": 1}
	slots[10] = {"item": &"wooden_staff", "qty": 1}
	return slots


## ItemDef real do Content; se C ainda não entregou, um falso com ícone gerado.
func _item(id: StringName) -> ItemDef:
	var real: ItemDef = Content.item(id)
	if real != null:
		return real
	if not _fake_items.has(id):
		var d := ItemDef.new()
		d.id = id
		d.name_key = String(id)
		d.buy_price = 10
		d.sell_price = 5
		d.stackable = String(id).begins_with("potion") or id == &"spinning_leaf"
		d.max_stack = 99 if d.stackable else 1
		d.type = ItemDef.ItemType.CONSUMABLE if String(id).begins_with("potion") else ItemDef.ItemType.WEAPON
		_fake_items[id] = d
	return _fake_items[id]


func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color8(90, 144, 224)
	world.add_child(env)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color8(201, 176, 138)
	plane.material = mat
	mesh_inst.mesh = plane
	ground.add_child(mesh_inst)
	world.add_child(ground)

	_player = EntityVisualFactory.create_from(&"player", &"male", PLAYER_ENTITY_ID, "Ana", true)
	_player.set_appearance({&"body": &"male", &"outfit": &"traveler", &"head": &"test_hat",
			&"weapon": &"test_stick", &"offhand": &""})
	world.add_child(_player)
	_player.facing_yaw = PI
	_npc = EntityVisualFactory.create_from(&"npc", NPC_ID, NPC_ENTITY_ID, "")
	world.add_child(_npc)
	_npc.position = NPC_POS
	_npc.facing_yaw = PI * 0.75
	_other = EntityVisualFactory.create_from(&"player", &"female", OTHER_ENTITY_ID, "Bia")
	world.add_child(_other)
	_other.position = OTHER_POS
	_other.facing_yaw = PI * 1.2
	_other.anim = &"walk"
