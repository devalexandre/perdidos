class_name QuestLogWindow
extends GameWindow
## Diário de missões (GDD §9): missões ativas com descrição, etapa atual e progresso; abandonar.
## Atalho L. O acompanhamento na tela fica no QuestTracker (quest_log_tracker.gd).
## Abas: "Missões" (com o objetivo aberto da história, ex.: "Onde está Maria?") e "Fragmentos" (os fragmentos
## do Arco 1 com ícone e texto; o que falta aparece como silhueta "???"). Ver StoryFragments.

signal abandon_requested(quest_id: StringName)

const WIDTH_PX: float = 320.0
const TAB_QUESTS: StringName = &"quests"
const TAB_FRAGMENTS: StringName = &"fragments"
const FRAGMENT_ICON_PX: float = 40.0
## Silhueta do fragmento que falta (ícone tingido de escuro).
const COLOR_SILHOUETTE: Color = Color(0.16, 0.11, 0.08, 0.85)
const COLOR_GOAL_BORDER: Color = Color8(196, 96, 140)

## Mochila do cliente ([{item, qty}]) para os fragmentos; vazio = Net.client_inventory.
var inventory_slots: Array = []
var tab: StringName = TAB_QUESTS

var _list: VBoxContainer
var _tabs: HBoxContainer
var _tab_buttons: Dictionary[StringName, Button] = {}
var _progress: Dictionary = {}


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_QUEST_LOG", p_scale)
	name = &"QuestLogWindow"
	_tabs = HBoxContainer.new()
	_tabs.name = &"Tabs"
	_tabs.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	content.add_child(_tabs)
	var group := ButtonGroup.new()
	for t: StringName in [TAB_QUESTS, TAB_FRAGMENTS]:
		var b := Button.new()
		b.name = "Tab_" + String(t)
		b.text = tr("JOURNAL_TAB_QUESTS" if t == TAB_QUESTS else "JOURNAL_TAB_FRAGMENTS")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == tab
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_pill_tab(b, ui_scale)
		b.pressed.connect(set_tab.bind(t))
		_tabs.add_child(b)
		_tab_buttons[t] = b
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


## Troca de aba (Missões / Fragmentos).
func set_tab(value: StringName) -> void:
	tab = value
	if _tab_buttons.has(value) and not _tab_buttons[value].button_pressed:
		_tab_buttons[value].button_pressed = true
	set_progress(_progress)


func set_progress(progress: Dictionary) -> void:
	_progress = progress
	if not is_inside_tree():
		return
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if tab == TAB_FRAGMENTS:
		_build_fragments(progress)
		_shrink.call_deferred()
		return
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
	for g: Dictionary in StoryFragments.open_goals(progress):
		_list.add_child(_goal_card(g))
	if quests.is_empty():
		var none := Label.new()
		none.text = tr("UI_QUEST_NONE")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
		none.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		_list.add_child(none)
	for e: Variant in quests:
		var entry: Dictionary = e
		var q: QuestDef = Content.quest(StringName(str(entry.get("id", ""))))
		if q == null:
			continue
		var card := PanelContainer.new()
		card.name = String(q.id)
		card.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale))
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
		card.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var title := Label.new()
		title.text = tr(q.name_key)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
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
		desc.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		box.add_child(desc)
		var stage := Label.new()
		# "pos"/"steps" contam só as etapas desta aceitação (as de veterano podem estar fora).
		var total: int = int(entry.get("steps", q.steps.size()))
		stage.text = tr("UI_QUEST_STEP") % [mini(int(entry.get("pos", entry.get("step", 0))) + 1, total), total]
		stage.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		stage.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		box.add_child(stage)
		var step := Label.new()
		step.text = "▸ " + step_text(entry)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.custom_minimum_size.x = UIKit.px(WIDTH_PX - 20.0, ui_scale)
		step.add_theme_color_override(&"font_color", UIKit.COLOR_STAT_GOOD if bool(entry.get("ready", false)) \
				else UIKit.COLOR_TEXT)
		box.add_child(step)
		_list.add_child(card)
	_shrink.call_deferred()


## Objetivo aberto da história (sem quest ligada): cartão com borda rosada.
func _goal_card(g: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Goal_" + String(g["id"])
	var sb: StyleBoxFlat = UIKit.dark_card_box(ui_scale)
	sb.border_color = COLOR_GOAL_BORDER
	sb.border_width_left = maxi(3, UIKit.px(5, ui_scale))
	card.add_theme_stylebox_override(&"panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	card.add_child(box)
	var kicker := _small(tr("JOURNAL_GOALS_TITLE"), UIKit.COLOR_TEXT_DIM)
	box.add_child(kicker)
	var title := Label.new()
	title.name = &"GoalTitle"
	title.text = tr(str(g["title_key"]))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	box.add_child(title)
	var desc := _small(tr(str(g["desc_key"])), UIKit.COLOR_TEXT)
	desc.custom_minimum_size.x = UIKit.px(WIDTH_PX - 20.0, ui_scale)
	box.add_child(desc)
	box.add_child(_small("▸ " + tr("JOURNAL_GOAL_OPEN"), UIKit.COLOR_TEXT_DIM))
	return card


## Aba Fragmentos: contagem e um cartão por fragmento (obtido: ícone, nome, tipo e texto; falta: silhueta e ???).
func _build_fragments(progress: Dictionary) -> void:
	var inv: Array = inventory_slots
	if inv.is_empty():
		var net: Node = get_node_or_null(^"/root/Net")
		if net != null and "client_inventory" in net:
			inv = net.get(&"client_inventory")
	var frags: Array[Dictionary] = StoryFragments.list(progress, inv)
	var got: int = 0
	for f: Dictionary in frags:
		got += 1 if f["obtained"] else 0
	var intro := _small(tr("JOURNAL_FRAGMENTS_INTRO") % [got, frags.size()], UIKit.COLOR_TEXT_DIM)
	intro.name = &"FragmentsIntro"
	intro.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	_list.add_child(intro)
	for f: Dictionary in frags:
		_list.add_child(_fragment_card(f))


func _fragment_card(f: Dictionary) -> PanelContainer:
	var obtained: bool = f["obtained"]
	var card := PanelContainer.new()
	card.name = "Fragment_" + String(f["item"])
	card.set_meta(&"obtained", obtained)
	card.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	card.add_child(row)
	var icon_box := PanelContainer.new()
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_box.add_theme_stylebox_override(&"panel", UIKit.slot_box(ui_scale, false))
	row.add_child(icon_box)
	var icon := TextureRect.new()
	icon.name = &"Icon"
	icon.texture = f["icon"]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2.ONE * UIKit.px(FRAGMENT_ICON_PX, ui_scale)
	if not obtained:
		icon.self_modulate = COLOR_SILHOUETTE
	icon_box.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	row.add_child(box)
	var title := Label.new()
	title.name = &"Name"
	title.text = tr(str(f["name_key"])) if obtained else tr("JOURNAL_FRAGMENT_UNKNOWN")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE if obtained else UIKit.COLOR_TEXT_DIM)
	box.add_child(title)
	if obtained:
		box.add_child(_small(tr(str(f["kind_key"])), UIKit.COLOR_TEXT_DIM))
	var lore := _small(tr(str(f["lore_key"])) if obtained else tr("JOURNAL_FRAGMENT_UNKNOWN_LORE"),
			UIKit.COLOR_TEXT if obtained else UIKit.COLOR_TEXT_DIM)
	lore.name = &"Lore"
	lore.add_theme_font_override(&"font", UIKit.read_font())
	lore.custom_minimum_size.x = UIKit.px(WIDTH_PX - FRAGMENT_ICON_PX - 36.0, ui_scale)
	box.add_child(lore)
	return card


func _small(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	l.add_theme_color_override(&"font_color", color)
	return l


func _shrink() -> void:
	reset_size()
	clamp_to_screen()
