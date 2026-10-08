class_name SkillsWindow
extends GameWindow
## Skills conhecidas (GDD §8.1): ícone arrastável para a barra 1–0, nível, botão "+1" para gastar
## ponto de skill, detalhes da selecionada; e os títulos conquistados (GDD §8.5) com "Exibir".
## Detalhes e dica de cada skill mostram a conjuração e a recarga EFETIVAS (GDD §8.1: nível da skill,
## DES/INT, Espírito e cast_reduction/cooldown_reduction dos itens), calculadas por CastTiming.
## Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3.0): as skills aparecem por ÁRVORE de título (5 cada),
## escolhida nas abas por título: as conhecidas com nível e "+1"; as que faltam, apagadas, com o que
## falta (pré-requisitos, título e o Mestre que ensina). Herança: o título de ramo mostra a árvore do pai.
## Atalho K.

signal level_up_requested(skill_id: StringName)
signal title_requested(title_id: StringName)

const ROW_WIDTH_PX: float = 210.0
## Skills em 2 colunas (a janela não passa da altura da tela com todas as skills); 1 em tela estreita.
const LIST_COLUMNS: int = 2
const DETAIL_WIDTH_PX: float = 230.0
## Lista vertical de títulos (abas à esquerda): largura e altura mínima da rolagem.
const TAB_WIDTH_PX: float = 168.0
const TAB_HEIGHT_PX: float = 34.0
const TAB_LIST_MIN_HEIGHT_PX: float = 160.0
## Largura total (px na escala 1,0) a partir da qual cabem 2 colunas de skills ao lado da lista e do detalhe.
const WIDE_LAYOUT_PX: float = 900.0
const SCHOOL_ORDER: Array[StringName] = [&"blade", &"arcane", &"bow", &"hybrid", &"support", &"tank"]
## Árvore das skills conhecidas sem título (aprendidas por teste): botão "Outras".
const OTHER_TREE: StringName = &"_other"
## Skill que ainda não se conhece: ícone apagado.
const LOCKED_ALPHA: float = 0.4

var _points_label: Label
var _hint: Label
var _tree_tabs: ScrollContainer
var _tree_tab_row: VBoxContainer
var _tree_pages: VBoxContainer
var _tree_tab_buttons: Dictionary[StringName, Button] = {}
var _detail: Label
var _tree_lists: Dictionary[StringName, GridContainer] = {}
var _tree_headers: Dictionary[StringName, Label] = {}
var _show_title: Button
var _hide: Button
var _progress: Dictionary = {}
var _selected: StringName = &""
var _stats: Dictionary = {}
var _tree: StringName = &""
var _building_tabs: bool = false
## Colunas de skills em uso (2 em tela larga, 1 em tela estreita).
var _columns: int = LIST_COLUMNS


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_SKILLS", p_scale)
	name = &"SkillsWindow"

	# Faixa de pontos de skill disponíveis.
	var pts_card := PanelContainer.new()
	pts_card.add_theme_stylebox_override(&"panel", UIKit.banner_box(ui_scale))
	content.add_child(pts_card)
	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_override(&"font", UIKit.read_font())
	_points_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_points_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	_points_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_points_label.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2, ui_scale)))
	pts_card.add_child(_points_label)

	var columns := HBoxContainer.new()
	columns.name = &"Columns"
	columns.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)

	# Coluna 1: títulos em lista vertical (abas à esquerda), rolável quando são muitos.
	_tree_tabs = ScrollContainer.new()
	_tree_tabs.name = &"TreeScroll"
	_tree_tabs.custom_minimum_size = Vector2(UIKit.px(TAB_WIDTH_PX, ui_scale), UIKit.px(TAB_LIST_MIN_HEIGHT_PX, ui_scale))
	_tree_tabs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tree_tabs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tree_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(_tree_tabs)
	_tree_tab_row = VBoxContainer.new()
	_tree_tab_row.name = &"TreeTabs"
	_tree_tab_row.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	_tree_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_tabs.add_child(_tree_tab_row)

	# Coluna 2: árvore do título escolhido (cabeçalho + skills).
	var left_card := PanelContainer.new()
	left_card.name = &"TreeCard"
	left_card.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale))
	columns.add_child(left_card)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	left_card.add_child(left)
	_tree_pages = VBoxContainer.new()
	_tree_pages.name = &"TreePages"
	_tree_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_tree_pages)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX * LIST_COLUMNS, ui_scale)
	_hint.add_theme_font_override(&"font", UIKit.read_font())
	_hint.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_hint.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	left.add_child(_hint)

	# Coluna 3: detalhe da skill e ações do título.
	var right_card := PanelContainer.new()
	right_card.name = &"DetailCard"
	right_card.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale))
	columns.add_child(right_card)
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	right_card.add_child(right)
	var det_box := PanelContainer.new()
	det_box.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale, 7))
	right.add_child(det_box)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = UIKit.px(DETAIL_WIDTH_PX, ui_scale)
	_detail.add_theme_font_override(&"font", UIKit.read_font())
	_detail.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_detail.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	det_box.add_child(_detail)

	var title_actions := HFlowContainer.new()
	title_actions.add_theme_constant_override(&"h_separation", UIKit.px(6, ui_scale))
	title_actions.add_theme_constant_override(&"v_separation", UIKit.px(6, ui_scale))
	right.add_child(title_actions)
	_show_title = Button.new()
	_show_title.name = &"ShowTitle"
	_show_title.focus_mode = Control.FOCUS_NONE
	_show_title.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_show_title.pressed.connect(func() -> void:
		var def: TitleDef = Content.title(_tree)
		if def != null:
			title_requested.emit(def.id))
	title_actions.add_child(_show_title)

	_hide = Button.new()
	_hide.name = &"HideTitle"
	_hide.focus_mode = Control.FOCUS_NONE
	_hide.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_hide.pressed.connect(func() -> void: title_requested.emit(&""))
	title_actions.add_child(_hide)


func _ready() -> void:
	super._ready()
	set_progress(_progress)


## Atributos atuais (Net.client_stats) para os tempos efetivos.
func set_stats(stats: Dictionary) -> void:
	_stats = stats.duplicate()


func set_progress(progress: Dictionary) -> void:
	_progress = progress
	if not is_inside_tree():
		return
	var points: int = int(progress.get("skill_points", 0))
	_points_label.text = tr("UI_SKILL_POINTS") % points
	var skills: Dictionary = progress.get("skills", {})
	var trees: Array[StringName] = trees_for(progress)
	# Skill escolhida (clique, dica, teste) em outra árvore visível: mostra a árvore dela.
	var chosen: SkillDef = Content.skill(_selected)
	if chosen != null and chosen.tree_title in trees:
		_tree = chosen.tree_title
	if _tree not in trees:
		# Primeira árvore com alguma skill conhecida; senão a primeira.
		_tree = trees[0] if not trees.is_empty() else &""
		for t: StringName in trees:
			if tree_entries(t, {}).any(func(id: Variant) -> bool: return skills.has(String(id))):
				_tree = t
				break
	_rebuild_tree_tabs(trees)
	_hint.text = tr("UI_SKILL_NONE") if skills.is_empty() else tr("UI_SKILL_DRAG_HINT")
	for tree: StringName in trees:
		var tree_list: GridContainer = _tree_lists[tree]
		for c: Node in tree_list.get_children():
			tree_list.remove_child(c)
			c.queue_free()
		for id: Variant in tree_entries(tree, skills):
			var sid := StringName(str(id))
			if skills.has(String(sid)):
				tree_list.add_child(_skill_row(sid, int(skills[String(sid)]), points > 0))
			else:
				tree_list.add_child(_locked_row(sid))
		_refresh_tree_header(tree)
	var ids: Array = tree_entries(_tree, skills)
	if (_selected.is_empty() or not (_selected in ids.map(func(v: Variant) -> StringName: return StringName(str(v))))) \
			and not ids.is_empty():
		_selected = StringName(str(ids[0]))
	_refresh_detail()
	_refresh_title_actions()
	_shrink.call_deferred()


## Árvores que o jogador vê (TITULOS-E-SKILLS.md §3.0): as dos títulos que tem (e dos pais, pela
## herança), as das skills que conhece e as que começam sem título (Flecha do Cerrado: porta de entrada).
static func trees_for(progress: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = SkillTree.visible_trees(progress.get("titles", []))
	var skills: Dictionary = progress.get("skills", {})
	var other: bool = false
	for r: Resource in Content.all(&"skills").values():
		var d: SkillDef = r as SkillDef
		if d == null:
			continue
		var known: bool = skills.has(String(d.id))
		if d.tree_title.is_empty():
			# Ofício de título (bonus_skills) fica na árvore do título, não abre "Outras".
			other = other or (known and not _is_title_bonus(d.id))
			continue
		if d.tree_title in out:
			continue
		# Porta de entrada: 1ª skill sem título nem pré-requisito, ensinada por uma lição de Mestre
		# (não pela quest de título do Campo de Treino).
		var q: QuestDef = SkillTree.quest_for_skill(d.id, NetWorld.client_map_id) if d.tree_order == 1 else null
		var open: bool = d.tree_order == 1 and d.exclusive_to_title.is_empty() and d.required_skill_levels.is_empty() \
				and q != null and not q.training_title_quest
		if known or open:
			out.append(d.tree_title)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ta: TitleDef = Content.title(a)
		var tb: TitleDef = Content.title(b)
		return (ta.sort_order if ta != null else 0) < (tb.sort_order if tb != null else 0))
	if other:
		out.append(OTHER_TREE)
	return out


## Skills de uma árvore na ordem (OTHER_TREE = conhecidas sem árvore).
static func tree_entries(tree: StringName, skills: Dictionary) -> Array:
	var out: Array = []
	if tree == OTHER_TREE:
		for id: Variant in skills:
			var d: SkillDef = Content.skill(StringName(str(id)))
			if (d == null or d.tree_title.is_empty()) and not _is_title_bonus(StringName(str(id))):
				out.append(StringName(str(id)))
		return out
	for d: SkillDef in SkillTree.tree_skills(tree):
		out.append(d.id)
	for id: Variant in skills:
		var bond: SkillDef = Content.skill(StringName(str(id)))
		if bond != null and not bond.companion_id.is_empty() and bond.tree_title == tree:
			out.append(bond.id)
	# Skills de ofício do título (TitleDef.bonus_skills, ex.: Fazer Flechas) depois das 5 da árvore.
	var td: TitleDef = Content.title(tree)
	if td != null:
		for s: StringName in td.bonus_skills:
			if Content.skill(s) != null and s not in out:
				out.append(s)
	return out


## Árvore visível que mostra o ofício: a aberta, se ele estiver nela; senão a primeira que o tem.
func _bonus_tree(skill_id: StringName, trees: Array[StringName]) -> StringName:
	var skills: Dictionary = _progress.get("skills", {})
	if skill_id in tree_entries(_tree, skills):
		return _tree
	for t: StringName in trees:
		if skill_id in tree_entries(t, skills):
			return t
	return _tree


## A skill é de ofício de algum título (aparece na árvore dele, não em "Outras").
static func _is_title_bonus(skill_id: StringName) -> bool:
	for r: Resource in Content.all(&"titles").values():
		var td: TitleDef = r as TitleDef
		if td != null and skill_id in td.bonus_skills:
			return true
	return false


## O que falta para aprender a skill: [texto, ...] (vazio = só falta a lição com o Mestre).
static func missing_lines(def: SkillDef, progress: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var skills: Dictionary = progress.get("skills", {})
	for m: Array in def.missing_prerequisites(skills):
		var req: SkillDef = Content.skill(m[0])
		out.append(TranslationServer.translate("UI_SKILL_REQ_LEVEL") % [
				TranslationServer.translate(req.name_key) if req != null else String(m[0]), m[1]])
	if not def.exclusive_to_title.is_empty() and not SkillTree.holds_title(progress.get("titles", []), def.exclusive_to_title):
		var t: TitleDef = Content.title(def.exclusive_to_title)
		out.append(TranslationServer.translate("UI_SKILL_REQ_TITLE") % (
				TranslationServer.translate(t.name_key) if t != null else String(def.exclusive_to_title)))
	return out


## Quem ensina (nome do NPC da quest que dá a skill), ou "".
static func teacher_name(def: SkillDef) -> String:
	var q: QuestDef = SkillTree.quest_for_skill(def.id, NetWorld.client_map_id)
	var npc: NpcDef = Content.npc(q.giver_npc) if q != null else null
	return TranslationServer.translate(npc.name_key) if npc != null else ""


## Preserva a identidade do título com contraste no painel escuro.
func _title_text_color(color: Color) -> Color:
	return color.lerp(UIKit.COLOR_TEXT, 0.4)


func _rebuild_tree_tabs(trees: Array[StringName]) -> void:
	_building_tabs = true
	_tree_lists.clear()
	_tree_headers.clear()
	_tree_tab_buttons.clear()
	var previous_scroll: int = _tree_tabs.scroll_vertical
	_columns = _columns_for_width()
	_hint.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX * _columns, ui_scale)
	for container: Control in [_tree_tab_row, _tree_pages]:
		for c: Node in container.get_children():
			container.remove_child(c)
			c.queue_free()
	for t: StringName in trees:
		var td: TitleDef = Content.title(t)
		var tab := Button.new()
		tab.name = String(t)
		tab.text = tr(td.name_key) if td != null else tr("UI_SKILL_TREE_OTHER")
		tab.tooltip_text = tab.text
		tab.toggle_mode = true
		tab.button_pressed = t == _tree
		tab.focus_mode = Control.FOCUS_NONE
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.clip_text = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(UIKit.px(TAB_WIDTH_PX - 12.0, ui_scale), UIKit.px(TAB_HEIGHT_PX, ui_scale))
		tab.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		UIKit.style_pill_tab(tab, ui_scale)
		tab.pressed.connect(_select_tree.bind(t))
		_tree_tab_row.add_child(tab)
		_tree_tab_buttons[t] = tab
		var page := VBoxContainer.new()
		page.name = "Page_" + String(t)
		page.visible = t == _tree
		page.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
		_tree_pages.add_child(page)
		var header := Label.new()
		header.name = &"TreeHeader"
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX * _columns, ui_scale)
		header.add_theme_font_override(&"font", UIKit.read_font())
		header.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
		page.add_child(header)
		var rule := ColorRect.new()
		rule.color = UIKit.COLOR_PARCHMENT_EDGE
		rule.custom_minimum_size.y = maxi(1, UIKit.px(1, ui_scale))
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(rule)
		var tree_list := GridContainer.new()
		tree_list.name = &"SkillList"
		tree_list.columns = _columns
		tree_list.add_theme_constant_override(&"h_separation", UIKit.px(10, ui_scale))
		tree_list.add_theme_constant_override(&"v_separation", UIKit.px(6, ui_scale))
		page.add_child(tree_list)
		_tree_headers[t] = header
		_tree_lists[t] = tree_list
	_building_tabs = false
	_tree_tabs.scroll_vertical = previous_scroll
	call_deferred("_ensure_selected_tree_tab_visible")


## 2 colunas de skills quando a área útil é larga; 1 em telas estreitas (celular em paisagem pequeno).
func _columns_for_width() -> int:
	var avail: float = work_rect().size.x if is_inside_tree() else INF
	return LIST_COLUMNS if avail >= UIKit.px(WIDE_LAYOUT_PX, ui_scale) else 1


func _select_tree(tree: StringName) -> void:
	if _building_tabs or tree not in _tree_tab_buttons:
		return
	_tree = tree
	_selected = &""
	set_progress(_progress)


func _ensure_selected_tree_tab_visible() -> void:
	var tab: Button = _tree_tab_buttons.get(_tree)
	if tab == null or not is_instance_valid(tab):
		return
	_tree_tabs.ensure_control_visible(tab)


func _refresh_tree_header(tree: StringName) -> void:
	var header: Label = _tree_headers.get(tree)
	if header == null:
		return
	var td: TitleDef = Content.title(tree)
	if td == null:
		header.text = tr("UI_SKILL_TREE_OTHER") if tree == OTHER_TREE else ""
		header.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
		return
	var parts: PackedStringArray = [tr("UI_SKILL_TREE_OF") % tr(td.name_key)]
	var npc: NpcDef = Content.npc(td.master_npc)
	if npc != null:
		parts.append(tr("UI_SKILL_TREE_MASTER") % tr(npc.name_key))
	var held: bool = SkillTree.holds_title(_progress.get("titles", []), tree)
	if not held:
		parts.append(tr("UI_SKILL_TREE_LOCKED"))
	var parent: TitleDef = Content.title(td.parent_title)
	if parent != null:
		parts.append(tr("UI_SKILL_TREE_INHERITS") % tr(parent.name_key))
	header.text = " · ".join(parts)
	header.add_theme_color_override(&"font_color", _title_text_color(td.color))


class SkillRow extends HBoxContainer:
	var skill_id: StringName = &""
	var window: SkillsWindow
	var is_locked: bool = false
	var _pressed: bool = false
	var _drag_started: bool = false

	func _init(p_skill_id: StringName, p_window: SkillsWindow, p_is_locked: bool = false) -> void:
		skill_id = p_skill_id
		window = p_window
		is_locked = p_is_locked

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_drag_started = false
			else:
				if _pressed and not _drag_started:
					_pressed = false
					if window != null and is_instance_valid(window):
						window._select(skill_id)
				_pressed = false
				_drag_started = false
		elif event is InputEventScreenTouch:
			if event.pressed:
				_pressed = true
				_drag_started = false
			else:
				if _pressed and not _drag_started:
					_pressed = false
					if window != null and is_instance_valid(window):
						window._select(skill_id)
				_pressed = false
				_drag_started = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if is_locked or skill_id.is_empty() or (Content.skill(skill_id) != null and Content.skill(skill_id).passive):
			return null
		_drag_started = true
		_pressed = false
		var def: SkillDef = Content.skill(skill_id)
		var preview: Control
		var icon: Texture2D = HotbarSlot.skill_icon(def)
		var s: int = ItemSlot.slot_pixels(window.ui_scale if window != null else 1.0)
		if icon != null:
			var tr_preview := TextureRect.new()
			tr_preview.texture = icon
			tr_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr_preview.custom_minimum_size = Vector2(s, s)
			tr_preview.size = Vector2(s, s)
			tr_preview.modulate.a = 0.85
			preview = tr_preview
		else:
			var lbl := Label.new()
			lbl.text = HotbarSlot.skill_icon_text(def)
			lbl.add_theme_color_override(&"font_color", HotbarSlot.school_color(def))
			lbl.add_theme_font_size_override(&"font_size", UIKit.px(HotbarSlot.ICON_TEXT_FONT_PX, window.ui_scale if window != null else 1.0))
			lbl.custom_minimum_size = Vector2(s, s)
			preview = lbl
		set_drag_preview(preview)
		return {HotbarSlot.SKILL_DRAG_KEY: true, "entry": skill_id, "from_slot": -1}


## Skill ainda não aprendida: ícone apagado, nome e o que falta.
func _locked_row(id: StringName) -> SkillRow:
	var def: SkillDef = Content.skill(id)
	var row := SkillRow.new(id, self, true)
	row.name = String(id)
	row.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX, ui_scale)
	var slot := HotbarSlot.new(ui_scale)
	slot.accepts_drop = false
	slot.drag_enabled = false
	slot.activate_on_release = true
	slot.set_entry(id)
	slot.modulate.a = LOCKED_ALPHA
	slot.activated.connect(func(_s: HotbarSlot) -> void: _select(id))
	row.add_child(slot)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label := Label.new()
	name_label.name = &"NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.text = tr(def.name_key) if def != null else String(id)
	name_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	name_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT if id == _selected else UIKit.COLOR_TEXT)
	col.add_child(name_label)
	var miss := Label.new()
	miss.name = &"Missing"
	miss.mouse_filter = Control.MOUSE_FILTER_PASS
	var lines: PackedStringArray = missing_lines(def, _progress) if def != null else PackedStringArray()
	miss.text = tr("UI_SKILL_MISSING") % lines[0] if not lines.is_empty() else tr("UI_SKILL_LEARN_WITH") % teacher_name(def)
	miss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	miss.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX - UIKit.ICON_SIZE * 1.5, ui_scale)
	miss.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	miss.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	col.add_child(miss)
	if def != null:
		var tip: String = "\n".join([tr(def.name_key), tr(def.desc_key)] + Array(lines))
		slot.tooltip_text = tip
		row.tooltip_text = tip
	return row


func _shrink() -> void:
	reset_size()
	clamp_to_screen()


func _skill_order(a: Variant, b: Variant) -> bool:
	var da: SkillDef = Content.skill(StringName(str(a)))
	var db: SkillDef = Content.skill(StringName(str(b)))
	var sa: int = SCHOOL_ORDER.find(da.school) if da != null else -1
	var sb: int = SCHOOL_ORDER.find(db.school) if db != null else -1
	return String(a) < String(b) if sa == sb else sa < sb


func _skill_row(id: StringName, level: int, can_raise: bool) -> SkillRow:
	var def: SkillDef = Content.skill(id)
	var row := SkillRow.new(id, self, false)
	row.name = String(id)
	row.custom_minimum_size.x = UIKit.px(ROW_WIDTH_PX, ui_scale)
	var slot := HotbarSlot.new(ui_scale)
	slot.accepts_drop = false
	slot.activate_on_release = true
	slot.set_entry(id)
	if def != null:
		var tip: String = "\n".join([tr(def.name_key), tr(def.desc_key)] + Array(timing_lines(def, level, _stats)))
		slot.tooltip_text = tip
		row.tooltip_text = tip
	slot.activated.connect(func(_s: HotbarSlot) -> void: _select(id))
	row.add_child(slot)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label := Label.new()
	name_label.name = &"NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.text = tr(def.name_key) if def != null else String(id)
	name_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	name_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT if id == _selected else UIKit.COLOR_TEXT)
	col.add_child(name_label)
	var lvl := Label.new()
	lvl.mouse_filter = Control.MOUSE_FILTER_PASS
	var max_level: int = mini(def.max_level, Balance.cfg.max_skill_level) if def != null else level
	lvl.text = tr("UI_SKILL_LEVEL") % [level, max_level]
	lvl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	lvl.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	col.add_child(lvl)
	var up := Button.new()
	up.name = &"LevelUp"
	up.text = tr("UI_SKILL_LEVEL_UP")
	up.focus_mode = Control.FOCUS_NONE
	up.disabled = not can_raise or level >= max_level
	up.pressed.connect(func() -> void: level_up_requested.emit(id))
	row.add_child(up)
	return row


func _select(id: StringName) -> void:
	_selected = id
	var chosen: SkillDef = Content.skill(_selected)
	var trees: Array[StringName] = trees_for(_progress)
	var target_tree: StringName = chosen.tree_title if (chosen != null and not chosen.tree_title.is_empty()) else (OTHER_TREE if (chosen != null and OTHER_TREE in trees) else _tree)
	if chosen != null and chosen.tree_title.is_empty() and _is_title_bonus(id):
		target_tree = _bonus_tree(id, trees)
	if target_tree in trees and target_tree != _tree:
		_tree = target_tree
		set_progress(_progress)
		return
	_update_row_selection()
	_refresh_detail()
	_refresh_title_actions()


func _update_row_selection() -> void:
	for tree_list: GridContainer in _tree_lists.values():
		for row: Node in tree_list.get_children():
			var name_label: Label = row.find_child("NameLabel", true, false) as Label
			if name_label != null:
				var is_sel: bool = StringName(row.name) == _selected
				name_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT if is_sel else UIKit.COLOR_TEXT)


func _refresh_detail() -> void:
	var def: SkillDef = Content.skill(_selected)
	if def == null:
		_detail.text = ""
		return
	var level: int = maxi(1, int((_progress.get("skills", {}) as Dictionary).get(String(def.id), 1)))
	var lines: PackedStringArray = [tr(def.name_key), tr(def.desc_key), tr("UI_SKILL_MANA") % def.mana_cost]
	lines.append_array(timing_lines(def, level, _stats))
	if def.range_cells > 0.0:
		lines.append(tr("UI_SKILL_RANGE") % _num(def.range_cells))
	if def.requires_bow:
		lines.append(tr("UI_SKILL_NEEDS_BOW"))
	# Árvore: pré-requisitos (cumpridos ou não) e quem ensina.
	var skills: Dictionary = _progress.get("skills", {})
	for req_id: StringName in def.required_skill_levels:
		var req: SkillDef = Content.skill(req_id)
		var ok: bool = int(skills.get(String(req_id), 0)) >= def.required_skill_levels[req_id]
		lines.append(tr("UI_SKILL_REQ_OK" if ok else "UI_SKILL_REQ_NO") % (tr("UI_SKILL_REQ_LEVEL") % [
				tr(req.name_key) if req != null else String(req_id), def.required_skill_levels[req_id]]))
	if not skills.has(String(def.id)):
		if not def.exclusive_to_title.is_empty():
			var t: TitleDef = Content.title(def.exclusive_to_title)
			var held: bool = SkillTree.holds_title(_progress.get("titles", []), def.exclusive_to_title)
			lines.append(tr("UI_SKILL_REQ_OK" if held else "UI_SKILL_REQ_NO") % (tr("UI_SKILL_REQ_TITLE") % (
					tr(t.name_key) if t != null else String(def.exclusive_to_title))))
		var who: String = teacher_name(def)
		if not who.is_empty():
			lines.append(tr("UI_SKILL_LEARN_WITH") % who)
	_detail.text = "\n".join(lines)


static func _num(v: float) -> String:
	return String.num(v, 1).replace(".", ",").trim_suffix(",0")


## Segundos com até 2 casas ("0,37", "2,9", "12").
static func _sec(v: float) -> String:
	return String.num(v, 2).replace(".", ",")


static func _pct(frac: float) -> String:
	return String.num(frac * CastTiming.PERCENT, 1).replace(".", ",").trim_suffix(",0")


## Linhas "Conjuração X s (base) · nível +a% · DES/INT −b% · itens −c%" e "Recarga Y s (base) · Espírito
## −d% · itens −e%" com os valores efetivos (GDD §8.1). Também usada nas dicas da barra.
static func timing_lines(def: SkillDef, level: int, stats: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var tr_: Callable = func(k: String) -> String: return TranslationServer.translate(k)
	if def.cast_time_sec <= 0.0:
		out.append(tr_.call("UI_SKILL_INSTANT"))
	else:
		var parts: PackedStringArray = [tr_.call("UI_SKILL_CAST_EFFECTIVE") % [
				_sec(CastTiming.skill_cast_sec(def, level, stats)), _num(def.cast_time_sec)]]
		var lvl: float = CastTiming.skill_level_factor(level) - 1.0
		if lvl > 0.0:
			parts.append(tr_.call("UI_TIMING_LEVEL") % _pct(lvl))
		var attr: float = CastTiming.cast_attr_reduction(stats)
		var items: float = CastTiming.cast_item_reduction(stats)
		if attr > 0.0:
			parts.append(tr_.call("UI_TIMING_ATTR") % _pct(attr))
		if items > 0.0:
			parts.append(tr_.call("UI_TIMING_ITEMS") % _pct(items))
		if attr + items > Balance.cfg.cast_reduction_total_cap or attr >= Balance.cfg.cast_reduction_attr_cap:
			parts.append(tr_.call("UI_TIMING_CAPPED") % _pct(CastTiming.cast_reduction(stats)))
		out.append(" · ".join(parts))
	if def.cooldown_sec > 0.0:
		var cparts: PackedStringArray = [tr_.call("UI_SKILL_COOLDOWN_EFFECTIVE") % [
				_sec(CastTiming.skill_cooldown_sec(def, stats)), _num(def.cooldown_sec)]]
		var spi: float = CastTiming.cooldown_attr_reduction(stats)
		var citems: float = CastTiming.cooldown_item_reduction(stats)
		if spi > 0.0:
			cparts.append(tr_.call("UI_TIMING_SPI") % _pct(spi))
		if citems > 0.0:
			cparts.append(tr_.call("UI_TIMING_ITEMS") % _pct(citems))
		if spi + citems > Balance.cfg.cooldown_reduction_cap:
			cparts.append(tr_.call("UI_TIMING_CAPPED") % _pct(CastTiming.cooldown_reduction(stats)))
		out.append(" · ".join(cparts))
	return out


func _refresh_title_actions() -> void:
	var shown := StringName(str(_progress.get("displayed_title", "")))
	var def: TitleDef = Content.title(_tree)
	var can_show: bool = def != null and SkillTree.holds_title(_progress.get("titles", []), _tree)
	var is_shown: bool = def != null and def.id == shown
	_show_title.visible = can_show
	_show_title.text = tr("UI_TITLE_SHOWN") if is_shown else tr("UI_TITLE_SHOW")
	_show_title.disabled = is_shown
	_hide.visible = not shown.is_empty()
	_hide.text = tr("UI_TITLE_HIDE")
	_hide.disabled = shown.is_empty()
