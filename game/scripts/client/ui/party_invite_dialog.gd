class_name PartyInviteDialog
extends PanelContainer
## Janela de pedido com Aceitar e Recusar e a contagem do tempo que falta (30/09/2026). Usada para o convite
## de grupo ("<nome> convidou você para o grupo.", NetParty) e para o pedido de troca (NetTrade): as chaves do
## título e do texto vêm no construtor. Criada pelo GameUI, que liga accept_requested/decline_requested.

signal accept_requested
signal decline_requested

## Posição: centro da tela, um pouco acima do meio (fração da altura).
const TOP_FRACTION: float = 0.22
const WIDTH_PX: float = 300.0

var ui_scale: float = 1.0
var title_label: Label
var text_label: Label
var timer_label: Label
var accept_button: Button
var decline_button: Button
var from_name: String = ""
var title_key: String = "UI_PARTY_INVITE_TITLE"
var text_key: String = "UI_PARTY_INVITE_TEXT"
var _deadline_msec: int = 0


func _init(p_scale: float = 1.0, p_title_key: String = "UI_PARTY_INVITE_TITLE",
		p_text_key: String = "UI_PARTY_INVITE_TEXT", p_name: StringName = &"PartyInviteDialog") -> void:
	ui_scale = p_scale
	title_key = p_title_key
	text_key = p_text_key
	name = p_name
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(6.0, ui_scale))
	add_child(box)
	title_label = Label.new()
	title_label.add_theme_color_override(&"font_color", UIKit.c_title())
	title_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	text_label = Label.new()
	text_label.name = &"Text"
	text_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override(&"font_color", UIKit.c_text())
	box.add_child(text_label)
	timer_label = Label.new()
	timer_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_color_override(&"font_color", UIKit.c_text_dim())
	timer_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	box.add_child(timer_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", UIKit.px(12.0, ui_scale))
	box.add_child(buttons)
	accept_button = Button.new()
	accept_button.name = &"Accept"
	accept_button.focus_mode = Control.FOCUS_NONE
	accept_button.pressed.connect(_answer.bind(true))
	buttons.add_child(accept_button)
	decline_button = Button.new()
	decline_button.name = &"Decline"
	decline_button.focus_mode = Control.FOCUS_NONE
	decline_button.pressed.connect(_answer.bind(false))
	buttons.add_child(decline_button)


func _ready() -> void:
	title_label.text = tr(title_key)
	accept_button.text = tr("UI_PARTY_ACCEPT")
	decline_button.text = tr("UI_PARTY_DECLINE")


func show_invite(p_from: String, timeout_sec: float) -> void:
	from_name = p_from
	text_label.text = UIKit.format_message(text_key, [p_from])
	_deadline_msec = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	visible = true
	_update_timer()
	reset_size()
	_place()
	move_to_front()


func hide_invite() -> void:
	visible = false
	from_name = ""


func _process(_delta: float) -> void:
	if visible:
		_update_timer()
		if Time.get_ticks_msec() >= _deadline_msec:
			hide_invite()


func _update_timer() -> void:
	timer_label.text = "%d s" % maxi(0, ceili((_deadline_msec - Time.get_ticks_msec()) / 1000.0))


func _answer(accept: bool) -> void:
	hide_invite()
	if accept:
		accept_requested.emit()
	else:
		decline_requested.emit()


func _place() -> void:
	var screen: Vector2 = get_parent_area_size()
	position = Vector2(floorf((screen.x - size.x) * 0.5), floorf(screen.y * TOP_FRACTION))
