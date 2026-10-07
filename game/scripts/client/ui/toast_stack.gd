class_name ToastStack
extends VBoxContainer
## Mensagens de sistema (erros e avisos do servidor) no alto da tela, somem sozinhas.

const DURATION_SEC: float = 3.5
const FADE_SEC: float = 0.5
const MAX_TOASTS: int = 4
const TOP_MARGIN_PX: float = 12.0

var ui_scale: float = 1.0


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"Toasts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	position.y = UIKit.px(TOP_MARGIN_PX, ui_scale)
	grow_horizontal = Control.GROW_DIRECTION_BOTH


func push(text: String, is_error: bool = true) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD,
			UIKit.COLOR_ERROR if is_error else UIKit.COLOR_BORDER,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", UIKit.COLOR_ERROR if is_error else UIKit.COLOR_TEXT)
	panel.add_child(l)
	add_child(panel)
	while get_child_count() > MAX_TOASTS:
		var old: Node = get_child(0)
		remove_child(old)
		old.queue_free()
	var tw: Tween = panel.create_tween()
	tw.tween_interval(DURATION_SEC)
	tw.tween_property(panel, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(panel.queue_free)


func get_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for p: Node in get_children():
		if p.is_queued_for_deletion():
			continue
		out.append((p.get_child(0) as Label).text)
	return out
