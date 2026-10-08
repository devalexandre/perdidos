class_name SettingsWindow
extends GameWindow
## Configurações (GameSettings): resolução, tela cheia e volumes por barramento. Volumes valem na
## hora; vídeo ao apertar "Aplicar". Tudo salvo em user://settings.cfg. "Controle → Ver botões" mostra o
## mapeamento do controle (GamepadInput).

## Emitido ao pedir para sair do jogo (o GameUI decide o que fazer).
signal quit_requested

const VOLUME_STEP: float = 0.05
const BUS_KEYS: Dictionary[StringName, String] = {
	GameSettings.BUS_MASTER: "UI_VOLUME_MASTER", GameSettings.BUS_MUSIC: "UI_VOLUME_MUSIC",
	GameSettings.BUS_AMBIENCE: "UI_VOLUME_AMBIENCE", GameSettings.BUS_SFX: "UI_VOLUME_SFX",
	GameSettings.BUS_UI: "UI_VOLUME_UI",
}
const SLIDER_WIDTH_PX: float = 160.0
const PAD_HELP_WIDTH_PX: float = 380.0

var _resolution: OptionButton
var _graphics_quality: OptionButton
var _fullscreen: CheckBox
## Minimapa: norte fixo / gira com a câmera (Agente N).
var _minimap_mode: OptionButton
var _sliders: Dictionary[StringName, HSlider] = {}
## Ajuda do controle (escondida até "Ver botões").
var pad_help: Label
var pad_status: Label
var _last_pad_event: String = ""


func _init(p_scale: float = 1.0, allow_quit: bool = true) -> void:
	super._init("UI_SETTINGS", p_scale)
	name = &"SettingsWindow"
	var s: GameSettings = GameSettings.get_instance()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UIKit.px(UIKit.PADDING * 2, ui_scale))
	grid.add_theme_constant_override(&"v_separation", UIKit.px(4, ui_scale))
	_section("UI_SETTINGS_VIDEO", grid)
	grid.add_child(_label("UI_RESOLUTION"))
	_resolution = OptionButton.new()
	for r: Vector2i in GameSettings.RESOLUTIONS:
		_resolution.add_item("%d x %d" % [r.x, r.y])
	_resolution.select(maxi(0, GameSettings.RESOLUTIONS.find(s.resolution)))
	grid.add_child(_resolution)
	grid.add_child(_label("UI_GRAPHICS_QUALITY"))
	_graphics_quality = OptionButton.new()
	_graphics_quality.name = &"GraphicsQuality"
	for key: String in ["UI_GRAPHICS_HIGH", "UI_GRAPHICS_MEDIUM", "UI_GRAPHICS_LOW"]:
		_graphics_quality.add_item(tr(key))
	_graphics_quality.select(int(s.graphics_quality))
	_graphics_quality.item_selected.connect(_on_graphics_quality_selected)
	grid.add_child(_graphics_quality)
	grid.add_child(_label("UI_FULLSCREEN"))
	_fullscreen = CheckBox.new()
	_fullscreen.button_pressed = s.fullscreen
	grid.add_child(_fullscreen)
	grid.add_child(_label("UI_MINIMAP_MODE"))
	_minimap_mode = OptionButton.new()
	_minimap_mode.name = &"MinimapMode"
	_minimap_mode.add_item(tr("UI_MINIMAP_NORTH_UP"))
	_minimap_mode.add_item(tr("UI_MINIMAP_ROTATE"))
	_minimap_mode.select(1 if s.minimap_rotate else 0)
	_minimap_mode.item_selected.connect(func(i: int) -> void:
		GameSettings.get_instance().minimap_rotate = i == 1)
	grid.add_child(_minimap_mode)
	grid.add_child(_label("UI_MOBILE_CONTROLS"))
	var mobile_cb := CheckBox.new()
	mobile_cb.name = &"MobileControls"
	mobile_cb.button_pressed = s.mobile_controls
	mobile_cb.toggled.connect(func(pressed: bool) -> void:
		GameSettings.get_instance().mobile_controls = pressed
		GameSettings.get_instance().mobile_controls_changed.emit(pressed)
	)
	grid.add_child(mobile_cb)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UIKit.px(16, ui_scale))
	grid.add_theme_constant_override(&"v_separation", UIKit.px(6, ui_scale))
	_section("UI_SETTINGS_AUDIO", grid)
	for bus: StringName in GameSettings.BUSES:
		grid.add_child(_label(BUS_KEYS[bus]))
		var slider := HSlider.new()
		slider.name = String(bus)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = VOLUME_STEP
		slider.value = s.get_volume(bus)
		slider.custom_minimum_size.x = UIKit.px(SLIDER_WIDTH_PX, ui_scale)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		grid.add_child(slider)
		_sliders[bus] = slider
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UIKit.px(16, ui_scale))
	_section("UI_SETTINGS_CONTROLS", grid)
	grid.add_child(_label("UI_PAD_HELP"))
	var pad_toggle := Button.new()
	pad_toggle.name = &"PadHelpToggle"
	pad_toggle.text = tr("UI_PAD_HELP_SHOW")
	pad_toggle.toggle_mode = true
	pad_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(pad_toggle)
	pad_help = Label.new()
	pad_help.name = &"PadHelp"
	pad_help.text = tr("UI_PAD_HELP_TEXT")
	pad_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad_help.custom_minimum_size.x = UIKit.px(PAD_HELP_WIDTH_PX, ui_scale)
	pad_help.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	pad_help.visible = false
	content.add_child(pad_help)
	pad_toggle.toggled.connect(func(on: bool) -> void: pad_help.visible = on)
	pad_status = Label.new()
	pad_status.name = &"PadStatus"
	pad_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad_status.custom_minimum_size.x = UIKit.px(PAD_HELP_WIDTH_PX, ui_scale)
	pad_status.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	content.add_child(pad_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	var replay := Button.new()
	replay.name = &"ReplayIntro"
	replay.text = tr("CUTSCENE_REPLAY")
	replay.pressed.connect(func() -> void:
		CutscenePlayer.play_overlay(get_tree(), GameSettings.get_instance().last_body))
	buttons.add_child(replay)
	if allow_quit:
		var quit := Button.new()
		quit.text = tr("UI_QUIT")
		quit.pressed.connect(func() -> void: quit_requested.emit())
		buttons.add_child(quit)
	var apply := Button.new()
	apply.name = &"Apply"
	apply.text = tr("UI_APPLY")
	apply.pressed.connect(apply_video)
	buttons.add_child(apply)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var names: PackedStringArray = []
	for device: int in Input.get_connected_joypads():
		names.append(Input.get_joy_name(device))
	pad_status.text = tr("UI_PAD_STATUS_VERSION") % ProjectSettings.get_setting("application/config/version", "")
	pad_status.text += "\n" + (tr("UI_PAD_STATUS_NONE") if names.is_empty() else tr("UI_PAD_STATUS_CONNECTED") % ", ".join(names))
	pad_status.text += "\n" + (tr("UI_PAD_STATUS_WAIT") if _last_pad_event.is_empty() else tr("UI_PAD_STATUS_EVENT") % _last_pad_event)


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and GamepadInput.is_pad_activity(event):
		_last_pad_event = event.as_text()


func apply_video() -> void:
	var s: GameSettings = GameSettings.get_instance()
	s.resolution = GameSettings.RESOLUTIONS[clampi(_resolution.selected, 0, GameSettings.RESOLUTIONS.size() - 1)]
	s.fullscreen = _fullscreen.button_pressed
	s.apply_video()
	s.save()


func close() -> void:
	GameSettings.get_instance().save()
	super.close()


func _on_volume_changed(value: float, bus: StringName) -> void:
	GameSettings.get_instance().set_volume(bus, value)


func _on_graphics_quality_selected(index: int) -> void:
	GameSettings.get_instance().set_graphics_quality(index)


func _label(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key)
	return l


func _section(key: String, grid: GridContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale, 6))
	content.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	card.add_child(box)
	box.add_child(UIKit.dark_label(tr(key), ui_scale, UIKit.FONT_SIZE, UIKit.COLOR_GOLD_LIGHT))
	box.add_child(grid)
