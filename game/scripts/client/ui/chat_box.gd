class_name ChatBox
extends PanelContainer
## Chat (GDD §13): histórico, campo de digitação (Enter abre/envia, Esc cancela), limite de
## 200 caracteres e aviso local de "rápido demais" (1 msg/s; o servidor também valida).
## Abas "Todos" e "Grupo" (30/09/2026): "Todos" mostra tudo; "Grupo" só o chat do grupo e os avisos do
## grupo, e o que se digita nela vai para o grupo (canal &"party"). Em qualquer aba, "/g <mensagem>"
## fala com o grupo e "/grupo ..." / "/online" são comandos (o servidor interpreta).
## Moderação (docs/moderacao.md): as mensagens já chegam censuradas ("***") do servidor; quando o
## chat do jogador é bloqueado, mostra um aviso acima do histórico com a contagem regressiva (lida
## das mensagens de sistema ModMsg.*) e não deixa enviar enquanto o bloqueio com tempo durar.

signal send_requested(channel: StringName, text: String)
## Aviso local (chave de tradução) — o GameUI mostra como mensagem de sistema.
signal notice(key: String)
signal minimized_changed(minimized: bool)

const CHANNEL_LOCAL: StringName = &"local"
const CHANNEL_PARTY: StringName = &"party"
## Linhas de sistema (avisos); as do grupo usam CHANNEL_PARTY_SYSTEM e aparecem também na aba "Grupo".
const CHANNEL_SYSTEM: StringName = &"system"
const CHANNEL_PARTY_SYSTEM: StringName = &"party_system"
const TAB_ALL: StringName = &"all"
const TAB_PARTY: StringName = &"party"
const COLOR_PARTY: Color = UIKit.COLOR_NAME_PARTY
const MAX_LENGTH: int = 200
const MIN_INTERVAL_MSEC: int = 1000
const MAX_HISTORY: int = 100
const WIDTH_PX: float = 392.0
const HISTORY_HEIGHT_PX: float = 156.0
const MARGIN_PX: float = 8.0
## Opacidade do painel quando não está digitando (fica discreto sobre o jogo).
const IDLE_ALPHA: float = 0.92
## Madeira escura translúcida (tema), um pouco mais opaca ao digitar.
const COLOR_CHAT_PANEL: Color = UIKit.COLOR_HUD_PANEL
const COLOR_CHAT_PANEL_FOCUS: Color = Color8(43, 27, 18, 248)
const COLOR_CHAT_TEXT: Color = UIKit.COLOR_TEXT

var ui_scale: float = 1.0

var _history: RichTextLabel
var _input: LineEdit
var _lines: PackedStringArray = []
## Canal de cada linha de _lines (mesma ordem).
var _channels: PackedStringArray = []
var _tab: StringName = TAB_ALL
var tab_all: Button
var tab_party: Button
var minimize_button: Button
var _minimized: bool = false
var _last_send_msec: int = -MIN_INTERVAL_MSEC
var _banner: Label
var _banner_accum: float = 0.0

## Bloqueio de chat (sobrevive à reconstrução da interface): fim em ticks do cliente (0 = sem
## bloqueio com tempo) e bloqueio sem prazo (aguardando revisão).
static var muted_until_msec: int = 0
static var muted_review: bool = false
const BANNER_REFRESH_SEC: float = 0.25
const COLOR_BANNER: Color = UIKit.COLOR_ERROR


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"ChatBox"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.hud_box(ui_scale, UIKit.PADDING, COLOR_CHAT_PANEL))
	var box := VBoxContainer.new()
	add_child(box)
	_banner = Label.new()
	_banner.name = &"MutedBanner"
	_banner.visible = false
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	_banner.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_banner.add_theme_color_override(&"font_color", COLOR_BANNER)
	box.add_child(_banner)
	var tabs := HBoxContainer.new()
	tabs.name = &"Tabs"
	tabs.add_theme_constant_override(&"separation", UIKit.px(2.0, ui_scale))
	box.add_child(tabs)
	tab_all = _make_tab(TAB_ALL)
	tabs.add_child(tab_all)
	tab_party = _make_tab(TAB_PARTY)
	tabs.add_child(tab_party)
	minimize_button = Button.new()
	minimize_button.name = &"Minimize"
	minimize_button.custom_minimum_size = Vector2(UIKit.px(48, ui_scale), UIKit.px(44, ui_scale))
	minimize_button.focus_mode = Control.FOCUS_NONE
	minimize_button.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	minimize_button.pressed.connect(func() -> void: set_minimized(not _minimized))
	tabs.add_child(minimize_button)
	_history = RichTextLabel.new()
	_history.name = &"History"
	_history.bbcode_enabled = true
	_history.scroll_following = true
	_history.selection_enabled = false
	_history.custom_minimum_size = Vector2(UIKit.px(WIDTH_PX, ui_scale), UIKit.px(HISTORY_HEIGHT_PX, ui_scale))
	_history.add_theme_font_override(&"normal_font", UIKit.read_font())
	_history.add_theme_font_override(&"bold_font", UIKit.read_font())
	_history.add_theme_font_size_override(&"normal_font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	_history.add_theme_font_size_override(&"bold_font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	_history.add_theme_color_override(&"default_color", COLOR_CHAT_TEXT)
	_history.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_history.add_theme_constant_override(&"outline_size", UIKit.px(2.0, ui_scale))
	_history.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_history)
	_input = LineEdit.new()
	_input.name = &"Input"
	_input.max_length = MAX_LENGTH
	_input.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_input.add_theme_color_override(&"font_color", COLOR_CHAT_TEXT)
	_input.add_theme_color_override(&"font_placeholder_color", UIKit.COLOR_TEXT_DIM)
	_input.add_theme_stylebox_override(&"normal", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER_DARK,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	_input.add_theme_stylebox_override(&"focus", UIKit.flat_box(COLOR_CHAT_PANEL_FOCUS, UIKit.COLOR_BORDER,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui)
	_input.focus_exited.connect(_update_alpha)
	_input.focus_entered.connect(_update_alpha)
	box.add_child(_input)
	_update_alpha()


func _make_tab(tab: StringName) -> Button:
	var b := Button.new()
	b.name = &"TabAll" if tab == TAB_ALL else &"TabParty"
	b.toggle_mode = true
	b.button_pressed = tab == _tab
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	UIKit.style_tab(b, ui_scale, UIKit.COLOR_GOLD, false)
	b.pressed.connect(set_tab.bind(tab))
	return b


## Troca a aba ("Todos" ou "Grupo") e refaz o histórico com o filtro.
func set_tab(tab: StringName) -> void:
	_tab = tab
	tab_all.set_pressed_no_signal(tab == TAB_ALL)
	tab_party.set_pressed_no_signal(tab == TAB_PARTY)
	_input.placeholder_text = tr("UI_CHAT_PARTY_PLACEHOLDER") if tab == TAB_PARTY else tr("UI_CHAT_PLACEHOLDER")
	_redraw()


func get_tab() -> StringName:
	return _tab


func _ready() -> void:
	tab_all.text = tr("UI_CHAT_TAB_ALL")
	tab_party.text = tr("UI_CHAT_TAB_PARTY")
	minimize_button.text = "−"
	minimize_button.tooltip_text = tr("UI_CHAT_MINIMIZE")
	_input.placeholder_text = tr("UI_CHAT_PLACEHOLDER")
	_place()
	get_viewport().size_changed.connect(_place)
	if not Net.system_message.is_connected(_on_system_message):
		Net.system_message.connect(_on_system_message)
	_update_banner()


func _process(delta: float) -> void:
	_banner_accum += delta
	if _banner_accum >= BANNER_REFRESH_SEC:
		_banner_accum = 0.0
		_update_banner()


## Chat bloqueado com prazo (o servidor recusaria a mensagem)?
static func is_muted() -> bool:
	return muted_until_msec > Time.get_ticks_msec()


## Segundos restantes do bloqueio com prazo (0 = nenhum).
static func muted_seconds_left() -> int:
	return maxi(ceili((muted_until_msec - Time.get_ticks_msec()) / 1000.0), 0)


## Lê "HH:MM:SS" ou "Nd HH:MM:SS" (ModerationService.format_duration) -> segundos (-1 = inválido).
static func parse_duration(text: String) -> int:
	var days: int = 0
	var rest: String = text.strip_edges()
	if rest.contains("d "):
		var d: String = rest.get_slice("d ", 0)
		if not d.is_valid_int():
			return -1
		days = d.to_int()
		rest = rest.get_slice("d ", 1)
	var parts: PackedStringArray = rest.split(":")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
		return -1
	return days * 86400 + parts[0].to_int() * 3600 + parts[1].to_int() * 60 + parts[2].to_int()


static func format_left(sec: int) -> String:
	var d: int = sec / 86400
	var r: int = sec % 86400
	var hms: String = "%02d:%02d:%02d" % [r / 3600, (r % 3600) / 60, r % 60]
	return ("%dd %s" % [d, hms]) if d > 0 else hms


func _on_system_message(key: String, args: Array) -> void:
	match key:
		ModMsg.MUTED, ModMsg.MUTED_NOW:
			var sec: int = parse_duration(str(args[0])) if not args.is_empty() else -1
			if sec > 0:
				muted_until_msec = Time.get_ticks_msec() + sec * 1000
				muted_review = false
		ModMsg.PENDING_REVIEW, ModMsg.CHARACTER_LOST:
			muted_review = true
			muted_until_msec = 0
		_:
			return
	_update_banner()


func _update_banner() -> void:
	if _banner == null:
		return
	var text: String = ""
	if is_muted():
		text = UIKit.format_message(ModMsg.UI_BANNER, [format_left(muted_seconds_left())])
	elif muted_review:
		text = tr(ModMsg.UI_BANNER_REVIEW)
	if _banner.visible != not text.is_empty():
		_banner.visible = not text.is_empty()
		if is_inside_tree():
			_place()
	_banner.text = text


## Enter fora do campo: começa a digitar.
func open_input() -> void:
	if _minimized:
		set_minimized(false)
	_input.grab_focus()


func close_input() -> void:
	_input.text = ""
	_input.release_focus()


func is_typing() -> bool:
	return _input.has_focus()


func add_message(from_name: String, text: String, channel: StringName = CHANNEL_LOCAL) -> void:
	if channel == CHANNEL_PARTY:
		_append("[color=#%s]%s %s:[/color] [color=#%s]%s[/color]" % [COLOR_PARTY.to_html(false),
				_escape(tr("UI_CHAT_PARTY_PREFIX")), _escape(from_name), COLOR_PARTY.lightened(0.35).to_html(false),
				_escape(text)], CHANNEL_PARTY)
		return
	_append("[color=#%s]%s:[/color] %s" % [UIKit.COLOR_CHAT_NAME.to_html(false),
			_escape(from_name), _escape(text)], CHANNEL_LOCAL)


## party = aviso do grupo (aparece também na aba "Grupo").
func add_system(text: String, party: bool = false) -> void:
	_append("[color=#%s]%s[/color]" % [UIKit.COLOR_CHAT_SYSTEM.to_html(false), _escape(text)],
			CHANNEL_PARTY_SYSTEM if party else CHANNEL_SYSTEM)


func get_lines() -> PackedStringArray:
	return _lines


func get_channels() -> PackedStringArray:
	return _channels


## Reaplica um histórico (reconstrução da interface ao mudar a escala).
func set_lines(lines: PackedStringArray, channels: PackedStringArray = PackedStringArray()) -> void:
	_lines = lines.duplicate()
	_channels = channels.duplicate()
	while _channels.size() < _lines.size():
		_channels.append(String(CHANNEL_SYSTEM))
	_redraw()


## Linhas visíveis na aba atual.
func visible_lines() -> PackedStringArray:
	if _tab == TAB_ALL:
		return _lines
	var out := PackedStringArray()
	for i: int in _lines.size():
		if _channels[i] in [String(CHANNEL_PARTY), String(CHANNEL_PARTY_SYSTEM)]:
			out.append(_lines[i])
	return out


func _shows(channel: StringName) -> bool:
	return _tab == TAB_ALL or channel in [CHANNEL_PARTY, CHANNEL_PARTY_SYSTEM]


func _redraw() -> void:
	_history.clear()
	_history.append_text("\n".join(visible_lines()))


## Tenta enviar (retorna false se vazio ou rápido demais).
func submit(text: String) -> bool:
	var clean: String = text.strip_edges().left(MAX_LENGTH)
	if clean.is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	if is_muted():
		notice.emit(ModMsg.MUTED_LOCAL)
		return false
	if now - _last_send_msec < MIN_INTERVAL_MSEC:
		notice.emit("SYS_CHAT_TOO_FAST")
		return false
	_last_send_msec = now
	# Na aba "Grupo" o texto vai para o grupo; comandos ("/...") seguem como estão.
	send_requested.emit(CHANNEL_PARTY if _tab == TAB_PARTY and not clean.begins_with("/") else CHANNEL_LOCAL, clean)
	return true


func _on_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		close_input()
		return
	if submit(text):
		close_input()


func _on_input_gui(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_input()
		_input.accept_event()


func _append(bbcode: String, channel: StringName = CHANNEL_SYSTEM) -> void:
	_lines.append(bbcode)
	_channels.append(String(channel))
	if _lines.size() > MAX_HISTORY:
		_lines = _lines.slice(_lines.size() - MAX_HISTORY)
		_channels = _channels.slice(_channels.size() - MAX_HISTORY)
		_redraw()
		return
	if not _shows(channel):
		return
	if _history.get_parsed_text().length() > 0:
		_history.append_text("\n")
	_history.append_text(bbcode)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _update_alpha() -> void:
	modulate.a = 1.0 if _input.has_focus() else IDLE_ALPHA
	add_theme_stylebox_override(&"panel", UIKit.hud_box(ui_scale, UIKit.PADDING,
			COLOR_CHAT_PANEL_FOCUS if _input.has_focus() else COLOR_CHAT_PANEL))


var _is_mobile: bool = false


func set_mobile_layout(is_mobile: bool) -> void:
	_is_mobile = is_mobile
	_place()


func set_minimized(value: bool) -> void:
	if _minimized == value:
		return
	_minimized = value
	if value and _input.has_focus():
		close_input()
	_history.visible = not value
	_input.visible = not value
	minimize_button.text = "+" if value else "−"
	minimize_button.tooltip_text = tr("UI_CHAT_EXPAND") if value else tr("UI_CHAT_MINIMIZE")
	_update_banner()
	_place()
	minimized_changed.emit(value)


func is_minimized() -> bool:
	return _minimized


func _place() -> void:
	var compact: bool = _is_mobile and _minimized
	tab_all.visible = not compact
	tab_party.visible = not compact
	minimize_button.text = "Chat" if compact else ("+" if _minimized else "−")
	reset_size()
	var screen: Vector2 = get_parent_area_size()
	var m: int = UIKit.px(MARGIN_PX, ui_scale)
	var bottom_offset: float = UIKit.px(215.0, ui_scale) if _is_mobile and not _minimized else float(m)
	position = Vector2(m, screen.y - size.y - bottom_offset)
	if compact:
		position.x = maxf(m, screen.x * 0.38 - size.x * 0.5)
