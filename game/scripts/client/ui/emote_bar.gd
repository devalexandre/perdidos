class_name EmoteBar
extends HBoxContainer
## Barra dos 6 emotes (GDD §13): botões com o balão de C (ou o nome traduzido). Atalhos Alt+1..6
## ficam no GameUI. Toque funciona igual ao clique.

signal emote_selected(emote_id: StringName)

var ui_scale: float = 1.0


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"EmoteBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in UIKit.EMOTES.size():
		var id: StringName = UIKit.EMOTES[i]
		var b := Button.new()
		b.name = String(id)
		b.focus_mode = Control.FOCUS_NONE
		var tex: Texture2D = UIKit.emote_texture(id)
		if tex != null:
			b.icon = UIKit.scale_texture(tex, UIKit.texture_scale(ui_scale))
			b.expand_icon = false
		else:
			b.text = UIKit.emote_label(id)
		b.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		b.tooltip_text = "%s (Alt+%d)" % [UIKit.emote_label(id), i + 1]
		b.pressed.connect(func() -> void: emote_selected.emit(id))
		add_child(b)
