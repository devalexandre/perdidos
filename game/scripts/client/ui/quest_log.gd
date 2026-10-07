class_name QuestLogWindow
extends GameWindow
## Diário de missões (GDD §9): missões ativas com descrição, etapa atual e progresso; abandonar.
## Atalho L. O acompanhamento na tela fica no QuestTracker (quest_log_tracker.gd).

signal abandon_requested(quest_id: StringName)

const WIDTH_PX: float = 320.0

var _list: VBoxContainer
var _progress: Dictionary = {}


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_QUEST_LOG", p_scale)
	name = &"QuestLogWindow"
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	_list.add_theme_constant_override(&"separation", UIKit.px(UIKit.PADDING, ui_scale))
	content.add_child(_list)


func _ready() -> void:
	super._ready()
	set_progress(_progress)


## Texto da etapa atual: "Derrote Redemoinhos Arteiros 3/5" (ou "Pronta! Volte ao Mestre.").
static func step_text(entry: Dictionary) -> String:
	var q: QuestDef = Content.quest(StringName(str(entry.get("id", ""))))
	if q == null:
		return ""
	if bool(entry.get("ready", false)):
		return TranslationServer.translate("UI_QUEST_READY")
	var i: int = int(entry.get("step", 0))
	if i < 0 or i >= q.steps.size():
		return ""
	var s: QuestStep = q.steps[i]
	var text: String = TranslationServer.translate(s.text_key)
	# "need" = quantidade desta aceitação (cresce com os títulos já conquistados).
	var need: int = int(entry.get("need", s.count))
	if need > 1:
		text += " %d/%d" % [int(entry.get("count", 0)), need]
	if int(entry.get("trial_ms", -1)) > 0:
		text += " · " + TranslationServer.translate("UI_QUEST_TRIAL_TIME") % ceili(int(entry["trial_ms"]) / 1000.0)
	return text


func set_progress(progress: Dictionary) -> void:
	_progress = progress
	if not is_inside_tree():
		return
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var quests: Array = progress.get("quests", [])
	# Faixa de renome: causos, título de renome e (se o servidor mandar) quanto falta para o próximo.
	var banner := PanelContainer.new()
	banner.name = &"CausosBanner"
	banner.add_theme_stylebox_override(&"panel", UIKit.banner_box(ui_scale))
	_list.add_child(banner)
	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	banner.add_child(banner_box)
	var causo_summary := Label.new()
	causo_summary.name = &"CausosSummary"
	causo_summary.text = tr("UI_CAUSOS_SUMMARY") % [int(progress.get("causos", 0)),
			tr(str(progress.get("causos_rank", "CAUSOS_FORASTEIRO")))]
	causo_summary.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	causo_summary.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	causo_summary.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2, ui_scale)))
	banner_box.add_child(causo_summary)
	if progress.has("causos_next") and int(progress["causos_next"]) > 0 and tr("UI_CAUSOS_NEXT") != "UI_CAUSOS_NEXT":
		var next := Label.new()
		next.name = &"CausosNext"
		next.text = tr("UI_CAUSOS_NEXT") % int(progress["causos_next"])
		next.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		next.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		next.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
		next.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2, ui_scale)))
		banner_box.add_child(next)
	var clue_summary := Label.new()
	clue_summary.name = &"WerewolfCluesSummary"
	clue_summary.text = tr("UI_WEREWOLF_CLUES_SUMMARY") % mini(int(progress.get("werewolf_clues", 0)), 3)
	clue_summary.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	clue_summary.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	clue_summary.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	clue_summary.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2, ui_scale)))
	banner_box.add_child(clue_summary)
	if quests.is_empty():
		var none := Label.new()
		none.text = tr("UI_QUEST_NONE")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
		none.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		_list.add_child(none)
	for e: Variant in quests:
		var entry: Dictionary = e
		var q: QuestDef = Content.quest(StringName(str(entry.get("id", ""))))
		if q == null:
			continue
		var card := PanelContainer.new()
		card.name = String(q.id)
		card.add_theme_stylebox_override(&"panel", UIKit.card_box(ui_scale))
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
		card.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var title := Label.new()
		title.text = tr(q.name_key)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_color_override(&"font_color", UIKit.c_title())
		head.add_child(title)
		var ab := Button.new()
		ab.text = tr("UI_QUEST_ABANDON")
		ab.focus_mode = Control.FOCUS_NONE
		ab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ab.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		ab.pressed.connect(func() -> void: abandon_requested.emit(q.id))
		head.add_child(ab)
		var desc := Label.new()
		desc.text = tr(q.desc_key)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = UIKit.px(WIDTH_PX - 20.0, ui_scale)
		desc.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		desc.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		box.add_child(desc)
		var stage := Label.new()
		# "pos"/"steps" contam só as etapas desta aceitação (as de veterano podem estar fora).
		var total: int = int(entry.get("steps", q.steps.size()))
		stage.text = tr("UI_QUEST_STEP") % [mini(int(entry.get("pos", entry.get("step", 0))) + 1, total), total]
		stage.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		stage.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		box.add_child(stage)
		var step := Label.new()
		step.text = "▸ " + step_text(entry)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.custom_minimum_size.x = UIKit.px(WIDTH_PX - 20.0, ui_scale)
		step.add_theme_color_override(&"font_color", UIKit.COLOR_INK_GOOD if bool(entry.get("ready", false)) \
				else UIKit.c_text())
		box.add_child(step)
		_list.add_child(card)
	_shrink.call_deferred()


func _shrink() -> void:
	reset_size()
	clamp_to_screen()
