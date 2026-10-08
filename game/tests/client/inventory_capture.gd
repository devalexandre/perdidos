extends Node
## Captura do inventário NO CLIENTE REAL (redesenho 07/10/2026): mochila com itens variados (todas as
## raridades, equipamentos, consumíveis, materiais e crendices), um item selecionado e a dica aberta.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/inventory_capture.gd
## --shot-dir=DIR [--ui-mobile] [--ui-tag=nome] (tests/client/run_ui_capture.sh com SCRIPT=...).
## Salva DIR/<tag>_inventory.png, <tag>_inventory_tab.png (aba Equipamento) e <tag>_inventory_shop.png.

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_MOBILE: String = "ui-mobile"
const ARG_TAG: String = "ui-tag"
const SETTLE_SEC: float = 4.0
const STEP_SEC: float = 0.6
## [item, quantidade, espaço]: espalhado pela mochila como num jogo de verdade (com buracos).
const SAMPLE: Array = [
	[&"potion_hp_small", 27, 0], [&"potion_mp_small", 12, 1], [&"return_scroll", 3, 2],
	[&"nectar_solar_da_mata", 2, 3], [&"machete", 1, 4], [&"silver_machete", 1, 5],
	[&"obsidian_machete", 1, 6], [&"living_flame_staff", 1, 7], [&"straw_hat", 1, 8],
	[&"leather_jerkin", 1, 9], [&"buriti_ring", 1, 10], [&"bracadeiras_do_rastreador", 1, 11],
	[&"simple_arrow", 99, 12], [&"fire_arrow", 40, 13], [&"anaconda_scale", 8, 16],
	[&"spider_silk", 14, 17], [&"crystal_scale", 3, 18], [&"eternal_ember", 1, 19],
	[&"river_memory", 1, 20], [&"figa_de_madeira", 1, 24], [&"dente_de_onca", 1, 25],
	[&"brasa_que_nao_apaga", 1, 26],
]
const STARS: int = 12480
const SELECT_SLOT: int = 7

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _ui: GameUI = null
var _tag: String = ""


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("inventory_capture_timeout")
		get_tree().quit(2))


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	var view: Node = main_node.get("client_view") if main_node != null else null
	_ui = view.call(&"get_game_ui") as GameUI if view != null else null
	if _ui == null:
		print("inventory_capture_no_ui")
		get_tree().quit(1)
		return
	var was_mobile: bool = GameSettings.get_instance().mobile_controls
	var size: Vector2 = _ui.get_viewport_rect().size
	_tag = args.get(ARG_TAG, "%s_%dx%d" % ["mobile" if args.has(ARG_MOBILE) else "desktop", int(size.x), int(size.y)])
	var want_mobile: bool = args.has(ARG_MOBILE)
	if want_mobile != was_mobile:
		GameSettings.get_instance().mobile_controls = want_mobile
		_ui.set_mobile_mode(want_mobile)
		await _wait(STEP_SEC)
	var slots: Array = []
	slots.resize(UIKit.INVENTORY_SIZE)
	for s: Array in SAMPLE:
		if Content.item(s[0]) != null:
			slots[int(s[2])] = {"item": String(s[0]), "qty": int(s[1])}
	_ui._on_inventory_changed(slots)
	_ui._on_currency_changed(STARS)
	_ui.inventory.open()
	await _wait(STEP_SEC)
	_ui.inventory.select(SELECT_SLOT)
	await _wait(0.2)
	_hover(_ui.inventory.get_slot(SELECT_SLOT))
	await _wait(1.5)
	await _shot("inventory")
	if _ui.inventory.has_method(&"set_tab"):
		_ui.inventory.call(&"set_tab", 1)
		await _wait(STEP_SEC)
		await _shot("inventory_tab")
		_ui.inventory.call(&"set_tab", 0)
	_ui.inventory.close()
	await _wait(0.2)
	var shop: ShopDef = Content.shop(&"market")
	if shop != null:
		_ui._on_shop_opened(&"market", shop.items.slice(0, 8))
		await _wait(STEP_SEC)
		_ui.inventory.select(0)
		await _wait(0.2)
		await _shot("inventory_shop")
		_ui._on_shop_closed()
		_ui.inventory.close()
	GameSettings.get_instance().mobile_controls = was_mobile
	print("inventory_capture_done")
	get_tree().quit(0)


## Leva o mouse até o espaço (a dica do Godot aparece após o hover).
func _hover(c: Control) -> void:
	if c == null or not c.is_visible_in_tree() or UIKit.is_touch_layout():
		return
	var at: Vector2 = c.get_global_rect().get_center()
	get_viewport().warp_mouse(at)
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s_%s.png" % [dir, _tag, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("inventory_capture_shot ", path)
