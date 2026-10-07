class_name AndroidAuthScreen
extends Control

signal authenticated(token: String)

const BACKGROUND_PATH: String = "res://assets/ui/title/title_bg_painted.png"
const PANEL_BG: Color = Color8(39, 25, 16, 245)
const GOLD: Color = Color8(226, 185, 95)
const CREAM: Color = Color8(240, 223, 189)
const ERROR: Color = Color8(255, 145, 130)
const EDGE_MARGIN_PX: float = 16.0
const PANEL_MAX_WIDTH_PX: float = 900.0
const MIN_UI_SCALE: float = 1.15
const MAX_UI_SCALE: float = 1.5

var api_base: String = ""
var _ui_scale: float = 1.0
var _email: LineEdit
var _password: LineEdit
var _confirm: LineEdit
var _show_passwords: CheckBox
var _error: Label
var _submit: Button
var _google_login: Button
var _login_tab: Button
var _register_tab: Button
var _request: HTTPRequest
var _google_poll_timer: Timer
var _google_flow_id: String = ""
var _request_kind: StringName = &"credentials"
var _request_in_flight: bool = false
var _register_mode: bool = false
var _busy: bool = false


func _init(p_api_base: String = "") -> void:
	api_base = p_api_base
	name = &"AndroidAuth"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GamepadInput.register_actions()
	var viewport_size: Vector2 = get_viewport_rect().size
	_ui_scale = clampf(minf(viewport_size.x, viewport_size.y) / 420.0, MIN_UI_SCALE, MAX_UI_SCALE)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKGROUND_PATH):
		background.texture = load(BACKGROUND_PATH) as Texture2D
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.05, 0.04, 0.52)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.name = &"AuthScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	var center := CenterContainer.new()
	center.custom_minimum_size.y = maxf(0.0, viewport_size.y - UIKit.px(EDGE_MARGIN_PX * 2.0, _ui_scale))
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = maxf(0.0, minf(PANEL_MAX_WIDTH_PX,
			viewport_size.x - UIKit.px(EDGE_MARGIN_PX * 2.0, _ui_scale)))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = Color8(166, 119, 57)
	panel_style.set_border_width_all(maxi(2, UIKit.px(2.0, _ui_scale)))
	panel_style.set_corner_radius_all(UIKit.px(5.0, _ui_scale))
	panel_style.content_margin_left = UIKit.px(24.0, _ui_scale)
	panel_style.content_margin_right = UIKit.px(24.0, _ui_scale)
	panel_style.content_margin_top = UIKit.px(20.0, _ui_scale)
	panel_style.content_margin_bottom = UIKit.px(22.0, _ui_scale)
	panel.add_theme_stylebox_override(&"panel", panel_style)
	center.add_child(panel)

	var form := VBoxContainer.new()
	form.add_theme_constant_override(&"separation", UIKit.px(12.0, _ui_scale))
	panel.add_child(form)
	var title := Label.new()
	title.text = tr("TITLE_GAME_NAME")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", UIKit.read_font())
	title.add_theme_font_size_override(&"font_size", UIKit.px(36.0, _ui_scale))
	title.add_theme_color_override(&"font_color", GOLD)
	form.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("ANDROID_AUTH_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override(&"font", UIKit.read_font())
	subtitle.add_theme_font_size_override(&"font_size", UIKit.px(18.0, _ui_scale))
	subtitle.add_theme_color_override(&"font_color", CREAM)
	form.add_child(subtitle)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	form.add_child(tabs)
	_login_tab = _make_tab("ANDROID_AUTH_LOGIN_TAB")
	_login_tab.pressed.connect(_set_register_mode.bind(false))
	tabs.add_child(_login_tab)
	_register_tab = _make_tab("ANDROID_AUTH_REGISTER_TAB")
	_register_tab.pressed.connect(_set_register_mode.bind(true))
	tabs.add_child(_register_tab)

	var divider := Label.new()
	divider.text = tr("ANDROID_AUTH_GOOGLE_DIVIDER")
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider.add_theme_font_override(&"font", UIKit.read_font())
	divider.add_theme_font_size_override(&"font_size", UIKit.px(18.0, _ui_scale))
	divider.add_theme_color_override(&"font_color", CREAM)
	form.add_child(divider)
	_google_login = Button.new()
	_google_login.text = tr("ANDROID_AUTH_GOOGLE")
	_google_login.custom_minimum_size.y = UIKit.px(58.0, _ui_scale)
	_google_login.add_theme_font_override(&"font", UIKit.read_font())
	_google_login.add_theme_font_size_override(&"font_size", UIKit.px(20.0, _ui_scale))
	_google_login.pressed.connect(_start_google_login)
	form.add_child(_google_login)

	_email = _add_field(form, "ANDROID_AUTH_EMAIL", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	_email.max_length = 254
	_password = _add_field(form, "ANDROID_AUTH_PASSWORD", LineEdit.KEYBOARD_TYPE_PASSWORD)
	_password.secret = true
	_password.max_length = 128
	_show_passwords = CheckBox.new()
	_show_passwords.name = &"ShowPasswords"
	_show_passwords.text = tr("ANDROID_AUTH_SHOW_PASSWORD")
	_show_passwords.custom_minimum_size.y = UIKit.px(42.0, _ui_scale)
	_show_passwords.add_theme_font_override(&"font", UIKit.read_font())
	_show_passwords.add_theme_font_size_override(&"font_size", UIKit.px(17.0, _ui_scale))
	_show_passwords.add_theme_color_override(&"font_color", CREAM)
	_show_passwords.toggled.connect(_set_password_visibility)
	form.add_child(_show_passwords)
	_confirm = _add_field(form, "ANDROID_AUTH_CONFIRM", LineEdit.KEYBOARD_TYPE_PASSWORD)
	_confirm.secret = true
	_confirm.max_length = 128
	_confirm.visible = false

	_error = Label.new()
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.add_theme_font_override(&"font", UIKit.read_font())
	_error.add_theme_font_size_override(&"font_size", UIKit.px(17.0, _ui_scale))
	_error.add_theme_color_override(&"font_color", ERROR)
	form.add_child(_error)

	_submit = Button.new()
	_submit.custom_minimum_size.y = UIKit.px(58.0, _ui_scale)
	_submit.add_theme_font_override(&"font", UIKit.read_font())
	_submit.add_theme_font_size_override(&"font_size", UIKit.px(20.0, _ui_scale))
	_submit.pressed.connect(_submit_auth)
	form.add_child(_submit)
	_set_register_mode(false)

	_request = HTTPRequest.new()
	_request.timeout = 20.0
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	_google_poll_timer = Timer.new()
	_google_poll_timer.wait_time = 1.0
	_google_poll_timer.timeout.connect(_poll_google_login)
	add_child(_google_poll_timer)


static func api_base_from_game_host(raw_host: String) -> String:
	var host: String = raw_host.strip_edges().trim_suffix("/")
	if host.begins_with("wss://"):
		host = "https://" + host.trim_prefix("wss://")
	elif host.begins_with("ws://"):
		host = "http://" + host.trim_prefix("ws://")
	elif not host.begins_with("https://") and not host.begins_with("http://"):
		host = "https://" + host
	var authority_start: int = host.find("://") + 3
	var path_start: int = host.find("/", authority_start)
	if path_start >= 0:
		host = host.substr(0, path_start)
	return host.trim_suffix("/")


func _make_tab(key: String) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = UIKit.px(52.0, _ui_scale)
	button.add_theme_font_override(&"font", UIKit.read_font())
	button.add_theme_font_size_override(&"font_size", UIKit.px(18.0, _ui_scale))
	return button


func _add_field(parent: VBoxContainer, label_key: String, keyboard_type: int) -> LineEdit:
	var field_box := VBoxContainer.new()
	field_box.add_theme_constant_override(&"separation", UIKit.px(6.0, _ui_scale))
	parent.add_child(field_box)
	var label := Label.new()
	label.text = tr(label_key)
	label.add_theme_font_override(&"font", UIKit.read_font())
	label.add_theme_font_size_override(&"font_size", UIKit.px(18.0, _ui_scale))
	label.add_theme_color_override(&"font_color", CREAM)
	field_box.add_child(label)
	var input := LineEdit.new()
	input.virtual_keyboard_type = keyboard_type
	input.clear_button_enabled = true
	input.custom_minimum_size.y = UIKit.px(56.0, _ui_scale)
	input.add_theme_font_override(&"font", UIKit.read_font())
	input.add_theme_font_size_override(&"font_size", UIKit.px(20.0, _ui_scale))
	input.add_theme_color_override(&"font_color", CREAM)
	input.add_theme_stylebox_override(&"normal", _field_style(false))
	input.add_theme_stylebox_override(&"focus", _field_style(true))
	field_box.add_child(input)
	return input


func _field_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(23, 15, 10, 255)
	style.border_color = GOLD if focused else Color8(98, 67, 36)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = UIKit.px(12.0, _ui_scale)
	style.content_margin_right = UIKit.px(12.0, _ui_scale)
	style.content_margin_top = UIKit.px(10.0, _ui_scale)
	style.content_margin_bottom = UIKit.px(10.0, _ui_scale)
	return style


func _set_register_mode(enabled: bool) -> void:
	_register_mode = enabled
	if _confirm != null:
		_confirm.visible = enabled
		var confirm_field: Control = _confirm.get_parent() as Control
		if confirm_field != null:
			confirm_field.visible = enabled
	if _login_tab != null:
		_login_tab.set_pressed_no_signal(not enabled)
	if _register_tab != null:
		_register_tab.set_pressed_no_signal(enabled)
	if _submit != null:
		_submit.text = tr("ANDROID_AUTH_REGISTER") if enabled else tr("ANDROID_AUTH_LOGIN")
	if _error != null:
		_error.text = ""


func _set_password_visibility(visible: bool) -> void:
	if _password != null:
		_password.secret = not visible
	if _confirm != null:
		_confirm.secret = not visible


func _submit_auth() -> void:
	if _busy:
		return
	var email: String = _email.text.strip_edges()
	if email.is_empty():
		return _show_error("ANDROID_AUTH_EMAIL_REQUIRED")
	if not email.contains("@") or not email.get_slice("@", 1).contains("."):
		return _show_error("ANDROID_AUTH_EMAIL_INVALID")
	if _password.text.is_empty():
		return _show_error("ANDROID_AUTH_PASSWORD_REQUIRED")
	if _register_mode and _password.text.length() < 8:
		return _show_error("ANDROID_AUTH_PASSWORD_SHORT")
	if _register_mode and _password.text != _confirm.text:
		return _show_error("ANDROID_AUTH_PASSWORD_MISMATCH")
	if api_base.is_empty():
		return _show_error("ANDROID_AUTH_API_UNSET")
	var route: String = "/api/register" if _register_mode else "/api/login"
	var headers := PackedStringArray(["Content-Type: application/json", "ngrok-skip-browser-warning: 1"])
	var payload := {"email": email, "password": _password.text}
	_busy = true
	_submit.disabled = true
	_google_login.disabled = true
	_submit.text = tr("ANDROID_AUTH_BUSY")
	_error.text = ""
	_request_kind = &"credentials"
	_request_in_flight = true
	var err: Error = _request.request(api_base + route, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_request_in_flight = false
		_busy = false
		_submit.disabled = false
		_google_login.disabled = false
		_set_register_mode(_register_mode)
		_show_error("ANDROID_AUTH_OFFLINE")


func _start_google_login() -> void:
	if _busy:
		return
	if api_base.is_empty():
		return _show_error("ANDROID_AUTH_API_UNSET")
	_busy = true
	_submit.disabled = true
	_google_login.disabled = true
	_google_login.text = tr("ANDROID_AUTH_GOOGLE_WAIT")
	_error.text = ""
	_request_kind = &"google_start"
	_request_in_flight = true
	var headers := PackedStringArray(["Content-Type: application/json", "ngrok-skip-browser-warning: 1"])
	var err: Error = _request.request(api_base + "/api/google/start", headers,
		HTTPClient.METHOD_POST, "{}")
	if err != OK:
		_request_in_flight = false
		_finish_google_login(tr("ANDROID_AUTH_OFFLINE"))


func _poll_google_login() -> void:
	if not _busy or _request_in_flight or _google_flow_id.is_empty():
		return
	_request_kind = &"google_poll"
	_request_in_flight = true
	var url: String = api_base + "/api/google/poll?flow=" + _google_flow_id.uri_encode()
	var headers := PackedStringArray(["ngrok-skip-browser-warning: 1"])
	var err: Error = _request.request(url, headers)
	if err != OK:
		_request_in_flight = false
		_finish_google_login(tr("ANDROID_AUTH_OFFLINE"))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if _request_kind == &"google_start":
		_handle_google_start(result, response_code, data)
		return
	if _request_kind == &"google_poll":
		_handle_google_poll(result, response_code, data)
		return
	_busy = false
	_submit.disabled = false
	_google_login.disabled = false
	_set_register_mode(_register_mode)
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 \
			and typeof(data) == TYPE_DICTIONARY and str(data.get("token", "")) != "":
		authenticated.emit(str(data["token"]))
		return
	var message: String = str(data.get("message", "")) if typeof(data) == TYPE_DICTIONARY else ""
	var fallback: String = "ANDROID_AUTH_OFFLINE" if result != HTTPRequest.RESULT_SUCCESS else "ANDROID_AUTH_BAD_RESPONSE"
	_show_error_text(message if not message.is_empty() else tr(fallback))


func _handle_google_start(result: int, response_code: int, data: Variant) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 201 or typeof(data) != TYPE_DICTIONARY:
		var message: String = str(data.get("message", "")) if typeof(data) == TYPE_DICTIONARY else ""
		_finish_google_login(message if not message.is_empty() else tr("ANDROID_AUTH_GOOGLE_UNAVAILABLE"))
		return
	_google_flow_id = str(data.get("flow_id", ""))
	var login_url: String = str(data.get("login_url", ""))
	if _google_flow_id.is_empty() or login_url.is_empty():
		_finish_google_login(tr("ANDROID_AUTH_BAD_RESPONSE"))
		return
	var err: Error = OS.shell_open(login_url)
	if err != OK:
		_finish_google_login(tr("ANDROID_AUTH_BROWSER_FAILED"))
		return
	_request_kind = &"google_poll"
	_google_poll_timer.start()


func _handle_google_poll(result: int, response_code: int, data: Variant) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 202:
		_google_poll_timer.start()
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and typeof(data) == TYPE_DICTIONARY \
			and str(data.get("token", "")) != "":
		_google_poll_timer.stop()
		_busy = false
		_submit.disabled = false
		_google_login.disabled = false
		_google_login.text = tr("ANDROID_AUTH_GOOGLE")
		_google_flow_id = ""
		authenticated.emit(str(data["token"]))
		return
	var message: String = str(data.get("message", "")) if typeof(data) == TYPE_DICTIONARY else ""
	_finish_google_login(message if not message.is_empty() else tr("ANDROID_AUTH_GOOGLE_UNAVAILABLE"))


func _finish_google_login(message: String) -> void:
	_google_poll_timer.stop()
	_google_flow_id = ""
	_busy = false
	_submit.disabled = false
	_google_login.disabled = false
	_google_login.text = tr("ANDROID_AUTH_GOOGLE")
	_set_register_mode(_register_mode)
	_show_error_text(message)


func _show_error(key: String) -> void:
	_show_error_text(tr(key))


func _show_error_text(text: String) -> void:
	_error.text = text
	_error.add_theme_color_override(&"font_color", ERROR)

## Controle (GamepadInput): o primeiro botão sem foco põe o foco em "Entrar"; D-pad navega; A abre o
## teclado virtual no campo focado (A/B fecham); demais botões seguem ui_accept/ui_cancel do Godot.
func _input(event: InputEvent) -> void:
	if GamepadInput.handle_line_edit(event, get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_pressed():
		var owner_c: Control = get_viewport().gui_get_focus_owner()
		if (owner_c == null or not owner_c.is_visible_in_tree()) and is_instance_valid(_submit):
			_submit.grab_focus()
			get_viewport().set_input_as_handled()
