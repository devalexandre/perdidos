class_name StoryScene
extends Control
## Cena da fala da lenda depois da vitória de história (ARCO-1-TERRA-DE-PINDORAMA.md §3, §6): faixas pretas em cima e
## embaixo, vinheta, retrato e nome da lenda já calma e a fala em páginas com "Continuar". Só aparece para quem
## ganhou o crédito (o servidor manda NetProgress.story_scene só para ele; ver QuestService.on_story_boss_killed).
## A memória do rio (final do Boitatá, StoryFragments.STYLE_MEMORY): a tela escurece, a lembrança aparece com um
## brilho rosado breve e as duas falas ficam em destaque.
##
## Entrada: clique/toque, Enter/Espaço ou o botão "Continuar" avançam (com o texto ainda correndo, completa a
## página); Esc pula a cena. Cenas que chegam juntas entram na fila. Sem arte nova: retrato = 1º quadro do
## sprite do chefe (forma atroz), ou o ícone do fragmento quando o chefe ainda não tem arte.

signal finished

const PAGE_LEGEND: StringName = &"legend"
const PAGE_VISION: StringName = &"vision"
const PAGE_LINE: StringName = &"line"
## Altura das faixas pretas (fração da tela) e escurecimento do mundo por estilo.
const BAR_FRACTION: float = 0.11
const DIM_LEGEND: float = 0.38
const DIM_MEMORY: float = 0.93
const FADE_IN_SEC: float = 0.45
const FADE_OUT_SEC: float = 0.4
const MEMORY_FADE_SEC: float = 1.1
## Texto corrido: caracteres por segundo.
const TYPE_CPS: float = 55.0
## Página longa é quebrada por frases até este tamanho (caracteres).
const PAGE_MAX_CHARS: int = 230
const BOX_WIDTH_PX: float = 640.0
const PORTRAIT_PX: float = 104.0
const ICON_PX: float = 28.0
const LINE_FONT_PX: float = 30.0
const VISION_FONT_PX: float = 20.0
const COLOR_BOX: Color = Color(0.05, 0.035, 0.03, 0.9)
const COLOR_MEMORY_TEXT: Color = Color(0.97, 0.93, 0.95)
const COLOR_LINE: Color = Color(1.0, 0.86, 0.92)
const COLOR_GLOW: Color = Color(1.0, 0.45, 0.72)
const GLOW_PEAK: float = 0.55
const GLOW_REST: float = 0.12
const SHEET_ROWS: int = 5

var ui_scale: float = 1.0

var _queue: Array[Dictionary] = []
var _scene: Dictionary = {}
var _pages: Array[Dictionary] = []
var _page: int = -1
var _tween: Tween = null
var _type_tween: Tween = null
var _closing: bool = false

var _dim: ColorRect
var _vignette: TextureRect
var _glow: TextureRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _box: PanelContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _fragment_row: HBoxContainer
var _fragment_icon: TextureRect
var _fragment_text: Label
var _memory: VBoxContainer
var _vision: Label
var _line1: Label
var _line2: Label
var _continue: Button


func _init() -> void:
	name = &"StoryScene"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = _rect(&"Dim", Color(0, 0, 0, 0))
	add_child(_dim)
	_vignette = TextureRect.new()
	_vignette.name = &"Vignette"
	_vignette.texture = _radial(Color(0, 0, 0, 0), Color(0, 0, 0, 0.85), 0.5)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)
	_glow = TextureRect.new()
	_glow.name = &"Glow"
	_glow.texture = _radial(COLOR_GLOW, Color(COLOR_GLOW, 0.0), 0.0)
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.modulate.a = 0.0
	add_child(_glow)
	_bar_top = _rect(&"BarTop", Color.BLACK)
	add_child(_bar_top)
	_bar_bottom = _rect(&"BarBottom", Color.BLACK)
	add_child(_bar_bottom)

	_memory = VBoxContainer.new()
	_memory.name = &"Memory"
	_memory.alignment = BoxContainer.ALIGNMENT_CENTER
	_memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_memory)
	_vision = _label(&"Vision")
	_vision.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_memory.add_child(_vision)
	_line1 = _label(&"Line1")
	_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_memory.add_child(_line1)
	_line2 = _label(&"Line2")
	_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_memory.add_child(_line2)

	_box = PanelContainer.new()
	_box.name = &"Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.name = &"PortraitFrame"
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.name = &"Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = _label(&"Name")
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_name)
	_text = _label(&"Text")
	col.add_child(_text)
	_fragment_row = HBoxContainer.new()
	_fragment_row.name = &"Fragment"
	_fragment_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fragment_icon = TextureRect.new()
	_fragment_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fragment_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fragment_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fragment_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fragment_row.add_child(_fragment_icon)
	_fragment_text = _label(&"FragmentText")
	_fragment_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_fragment_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fragment_row.add_child(_fragment_text)

	_continue = Button.new()
	_continue.name = &"Continue"
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.pressed.connect(advance)
	add_child(_continue)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)


# ---------------------------------------------------------------- API

## Mostra a cena (StoryFragments.make_scene); se outra estiver tocando, entra na fila.
func play(scene: Dictionary) -> void:
	if is_playing():
		_queue.append(scene)
		return
	_start(scene)


func is_playing() -> bool:
	return not _scene.is_empty()


## Estado para testes/capturas: {style, page, pages, kind, name, text}.
func describe() -> Dictionary:
	var kind: StringName = _pages[_page]["kind"] if _page >= 0 and _page < _pages.size() else &""
	return {"style": String(_scene.get("style", "")), "page": _page, "pages": _pages.size(), "kind": kind,
			"name": _name.text, "text": _text.text if kind == PAGE_LEGEND else _vision.text,
			"line1": _line1.text if _line1.visible else "", "line2": _line2.text if _line2.visible else "",
			"queued": _queue.size(), "fragment": _fragment_text.text if _fragment_row.is_inside_tree() else ""}


## Próxima página (com o texto ainda correndo, só completa a página atual).
func advance() -> void:
	if not is_playing() or _closing:
		return
	if _type_tween != null and _type_tween.is_running():
		_type_tween.kill()
		_text.visible_ratio = 1.0
		return
	if _page + 1 >= _pages.size():
		skip()
		return
	_show_page(_page + 1)


## Fecha a cena (Esc ou fim das páginas) e toca a próxima da fila.
func skip() -> void:
	if not is_playing() or _closing:
		return
	_closing = true
	_kill_tweens()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, ^"modulate:a", 0.0, FADE_OUT_SEC)
	_tween.chain().tween_callback(_end)


# ---------------------------------------------------------------- páginas

func _start(scene: Dictionary) -> void:
	_scene = scene
	_closing = false
	ui_scale = UIKit.scale_for(get_viewport_rect().size)
	_pages = build_pages(scene)
	_setup_speaker()
	_style_nodes()
	visible = true
	modulate.a = 1.0
	_dim.color.a = 0.0
	_vignette.modulate.a = 0.0
	_glow.modulate.a = 0.0
	_layout()
	_bar_top.position.y = -_bar_top.size.y
	_bar_bottom.position.y = size.y
	_kill_tweens()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bar_top, ^"position:y", 0.0, FADE_IN_SEC)
	_tween.tween_property(_bar_bottom, ^"position:y", size.y - _bar_bottom.size.y, FADE_IN_SEC)
	_tween.tween_property(_dim, ^"color:a", DIM_LEGEND, FADE_IN_SEC)
	_tween.tween_property(_vignette, ^"modulate:a", 1.0, FADE_IN_SEC)
	Net.log_line("story_scene_shown", {"quest": scene.get("quest", ""), "style": scene.get("style", ""),
			"pages": _pages.size()})
	_show_page(0)


## Páginas da cena: falas (quebradas por frases) e, na memória, a lembrança e as duas falas.
static func build_pages(scene: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if StringName(str(scene.get("style", ""))) == StoryFragments.STYLE_MEMORY:
		out.append({"kind": PAGE_LEGEND, "text": TranslationServer.translate(StoryFragments.MEMORY_INTRO_KEY)})
		out.append({"kind": PAGE_VISION, "text": TranslationServer.translate(StoryFragments.MEMORY_VISION_KEY)})
		out.append({"kind": PAGE_LINE, "lines": 1})
		out.append({"kind": PAGE_LINE, "lines": 2})
		return out
	var keys: Array = scene.get("pages", [])
	if keys.is_empty() and not str(scene.get("text_key", "")).is_empty():
		keys = [str(scene["text_key"])]
	for k: Variant in keys:
		for chunk: String in split_text(TranslationServer.translate(str(k))):
			out.append({"kind": PAGE_LEGEND, "text": chunk})
	return out


## Quebra uma fala longa: a narração antes da fala entre aspas fica numa página e a fala noutra; cada parte
## maior que PAGE_MAX_CHARS é dividida por frases.
static func split_text(text: String, max_chars: int = PAGE_MAX_CHARS) -> PackedStringArray:
	var parts: PackedStringArray = []
	var quote_at: int = text.find(": \"")
	if quote_at > 0 and text.length() > max_chars:
		parts.append(text.substr(0, quote_at + 1).strip_edges())
		parts.append(text.substr(quote_at + 1).strip_edges())
	else:
		parts.append(text.strip_edges())
	var out: PackedStringArray = []
	for p: String in parts:
		if p.length() <= max_chars:
			out.append(p)
			continue
		var cur: String = ""
		for sentence: String in _sentences(p):
			if not cur.is_empty() and cur.length() + 1 + sentence.length() > max_chars:
				out.append(cur)
				cur = sentence
			else:
				cur = sentence if cur.is_empty() else cur + " " + sentence
		if not cur.is_empty():
			out.append(cur)
	return out


static func _sentences(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var start: int = 0
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if c in [".", "!", "?"]:
			var end: int = i + 1
			while end < text.length() and text[end] in ["\"", "”", ".", "!", "?"]:
				end += 1
			if end >= text.length() or text[end] == " ":
				out.append(text.substr(start, end - start).strip_edges())
				start = end + 1
				i = end
		i += 1
	if start < text.length():
		var rest: String = text.substr(start).strip_edges()
		if not rest.is_empty():
			out.append(rest)
	return out


func _show_page(i: int) -> void:
	_page = i
	var p: Dictionary = _pages[i]
	var kind: StringName = p["kind"]
	var last: bool = i + 1 >= _pages.size()
	var memory: bool = kind != PAGE_LEGEND
	_box.visible = not memory
	_memory.visible = memory
	if _fragment_row.get_parent() != null:
		_fragment_row.get_parent().remove_child(_fragment_row)
	var fragment: String = _fragment_name()
	if last and not fragment.is_empty():
		(_text.get_parent() if not memory else _memory).add_child(_fragment_row)
		_fragment_row.alignment = BoxContainer.ALIGNMENT_CENTER if memory else BoxContainer.ALIGNMENT_BEGIN
	var t: Tween = create_tween().set_parallel(true)
	match kind:
		PAGE_LEGEND:
			_text.text = str(p["text"])
			_text.visible_ratio = 0.0
			if _type_tween != null:
				_type_tween.kill()
			_type_tween = create_tween()
			_type_tween.tween_property(_text, ^"visible_ratio", 1.0, maxf(0.2, _text.text.length() / TYPE_CPS))
		PAGE_VISION:
			# Escurecimento e a lembrança; o brilho rosado acende e apaga (os olhos do homem).
			_vision.text = str(p["text"])
			_vision.visible = true
			_line1.visible = false
			_line2.visible = false
			_vision.modulate.a = 0.0
			t.tween_property(_dim, ^"color:a", DIM_MEMORY, MEMORY_FADE_SEC)
			t.tween_property(_vision, ^"modulate:a", 1.0, MEMORY_FADE_SEC).set_delay(0.3)
			var g: Tween = create_tween()
			g.tween_interval(MEMORY_FADE_SEC)
			g.tween_property(_glow, ^"modulate:a", GLOW_PEAK, 0.5).set_trans(Tween.TRANS_SINE)
			g.tween_property(_glow, ^"modulate:a", GLOW_REST, 1.1).set_trans(Tween.TRANS_SINE)
		PAGE_LINE:
			var n: int = int(p.get("lines", 1))
			_vision.visible = false
			_line1.text = TranslationServer.translate(StoryFragments.MEMORY_LINE_KEYS[0])
			_line2.text = TranslationServer.translate(StoryFragments.MEMORY_LINE_KEYS[1])
			_line1.visible = true
			_line2.visible = n >= 2
			var fresh: Label = _line2 if n >= 2 else _line1
			fresh.modulate.a = 0.0
			t.tween_property(fresh, ^"modulate:a", 1.0, 0.9)
			t.tween_property(_dim, ^"color:a", DIM_MEMORY, 0.3)
			var g2: Tween = create_tween()
			g2.tween_property(_glow, ^"modulate:a", GLOW_PEAK * 0.7, 0.35)
			g2.tween_property(_glow, ^"modulate:a", GLOW_REST, 0.9)
	t.tween_interval(0.01)  # a Tween paralela não pode ficar vazia (página de fala)
	_continue.text = TranslationServer.translate("STORY_SCENE_CONTINUE") + ("  ▸" if not last else "")
	if _fragment_row.get_parent() != null:
		_fragment_text.text = TranslationServer.translate("STORY_SCENE_FRAGMENT") % fragment
	_layout.call_deferred()


## Nome do fragmento entregue nesta vitória ("" = nenhum).
func _fragment_name() -> String:
	for it: Variant in _scene.get("items", []):
		for f: Dictionary in StoryFragments.FRAGMENTS:
			if StringName(str(it)) == f["item"]:
				var def: ItemDef = Content.item(f["item"])
				_fragment_icon.texture = def.icon if def != null else null
				return TranslationServer.translate(def.name_key) if def != null else str(it)
	return ""


func _setup_speaker() -> void:
	var monster_id := StringName(str(_scene.get("monster", "")))
	var key: String = StoryFragments.legend_name_key(monster_id)
	var shown: String = TranslationServer.translate(key)
	var def: MonsterDef = Content.monster(monster_id)
	var stage: MonsterStage = def.atroz_stage() if def != null else null
	if shown == key:
		shown = TranslationServer.translate(stage.name_key) if stage != null else ""
	_name.text = shown
	var tex: Texture2D = portrait_for(stage)
	if tex == null:
		for it: Variant in _scene.get("items", []):
			var item: ItemDef = Content.item(StringName(str(it)))
			if item != null and item.icon != null:
				tex = item.icon
				break
	_portrait.texture = tex
	_portrait_frame.visible = tex != null


## Retrato: primeiro quadro da folha parada (linha de frente) do estágio, ou null sem arte.
static func portrait_for(stage: MonsterStage) -> Texture2D:
	if stage == null or stage.sprite_base.is_empty():
		return null
	var path: String = stage.sprite_base + "_idle.png"
	if not ResourceLoader.exists(path):
		return null
	var sheet: Texture2D = load(path) as Texture2D
	if sheet == null:
		return null
	var fh: int = maxi(1, sheet.get_height() / SHEET_ROWS)
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(0, 0, mini(fh, sheet.get_width()), fh)
	return a


func _end() -> void:
	_closing = false
	_scene = {}
	_pages.clear()
	_page = -1
	visible = false
	modulate.a = 1.0
	finished.emit()
	if not _queue.is_empty():
		_start(_queue.pop_front())


func _kill_tweens() -> void:
	if _tween != null:
		_tween.kill()
	if _type_tween != null:
		_type_tween.kill()


# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if not is_playing() or not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		# Teclas do jogo (atalhos, chat) não passam por baixo da cena.
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_playing():
		return
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		advance()
	accept_event()


# ---------------------------------------------------------------- visual

func _style_nodes() -> void:
	var line: int = maxi(1, UIKit.px(2, ui_scale))
	var box: StyleBoxFlat = UIKit.flat_box(COLOR_BOX, UIKit.COLOR_GOLD_AGED, line, UIKit.px(14, ui_scale))
	box.border_width_left = 0
	box.border_width_right = 0
	box.shadow_size = UIKit.px(10, ui_scale)
	box.shadow_color = Color(0, 0, 0, 0.6)
	_box.add_theme_stylebox_override(&"panel", box)
	(_box.get_child(0) as HBoxContainer).add_theme_constant_override(&"separation", UIKit.px(14, ui_scale))
	var frame: StyleBoxFlat = UIKit.flat_box(Color(0.12, 0.08, 0.06, 1.0), UIKit.COLOR_GOLD, line, UIKit.px(3, ui_scale))
	_portrait_frame.add_theme_stylebox_override(&"panel", frame)
	_portrait.custom_minimum_size = Vector2.ONE * UIKit.px(PORTRAIT_PX, ui_scale)
	_name.add_theme_font_override(&"font", UIKit.font())
	_name.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_TITLE + 2, ui_scale))
	_name.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	_text.add_theme_font_override(&"font", UIKit.read_font())
	_text.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE + 2, ui_scale))
	_text.add_theme_color_override(&"font_color", UIKit.COLOR_PARCHMENT)
	_text.add_theme_constant_override(&"line_spacing", UIKit.px(3, ui_scale))
	_fragment_row.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	_fragment_icon.custom_minimum_size = Vector2.ONE * UIKit.px(ICON_PX, ui_scale)
	_fragment_text.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_fragment_text.add_theme_color_override(&"font_color", COLOR_LINE)
	_memory.add_theme_constant_override(&"separation", UIKit.px(18, ui_scale))
	_vision.add_theme_font_override(&"font", UIKit.read_font())
	_vision.add_theme_font_size_override(&"font_size", UIKit.px(VISION_FONT_PX, ui_scale))
	_vision.add_theme_color_override(&"font_color", COLOR_MEMORY_TEXT)
	for l: Label in [_line1, _line2]:
		l.add_theme_font_override(&"font", UIKit.font())
		l.add_theme_font_size_override(&"font_size", UIKit.px(LINE_FONT_PX, ui_scale))
		l.add_theme_color_override(&"font_color", COLOR_LINE)
		l.add_theme_color_override(&"font_shadow_color", Color(COLOR_GLOW, 0.55))
		l.add_theme_constant_override(&"shadow_offset_x", 0)
		l.add_theme_constant_override(&"shadow_offset_y", 0)
		l.add_theme_constant_override(&"shadow_outline_size", UIKit.px(10, ui_scale))
	for l: Label in [_name, _text, _vision, _line1, _line2, _fragment_text]:
		l.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
		l.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(3, ui_scale)))
	var flat: StyleBoxFlat = UIKit.flat_box(Color(0, 0, 0, 0), UIKit.COLOR_GOLD_AGED, line, UIKit.px(6, ui_scale))
	flat.content_margin_left = UIKit.px(14, ui_scale)
	flat.content_margin_right = UIKit.px(14, ui_scale)
	var hover: StyleBoxFlat = flat.duplicate() as StyleBoxFlat
	hover.bg_color = Color(UIKit.COLOR_GOLD_AGED, 0.25)
	hover.border_color = UIKit.COLOR_GOLD
	_continue.add_theme_stylebox_override(&"normal", flat)
	_continue.add_theme_stylebox_override(&"hover", hover)
	_continue.add_theme_stylebox_override(&"pressed", hover)
	_continue.add_theme_stylebox_override(&"hover_pressed", hover)
	_continue.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	_continue.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	_continue.add_theme_color_override(&"font_hover_color", Color.WHITE)
	_continue.custom_minimum_size.y = UIKit.px(44.0 if UIKit.is_touch_layout() else 32.0, ui_scale)


func _layout() -> void:
	var s: Vector2 = get_viewport_rect().size
	size = s
	var bar_h: float = floorf(s.y * BAR_FRACTION)
	_dim.size = s
	_bar_top.size = Vector2(s.x, bar_h)
	_bar_bottom.size = Vector2(s.x, bar_h)
	if not (_tween != null and _tween.is_running() and _page <= 0):
		_bar_top.position = Vector2.ZERO
		_bar_bottom.position = Vector2(0.0, s.y - bar_h)
	var w: float = minf(UIKit.px(BOX_WIDTH_PX, ui_scale), s.x - UIKit.px(32, ui_scale))
	var text_w: float = w - UIKit.px(PORTRAIT_PX + 14 + 40, ui_scale) if _portrait_frame.visible \
			else w - UIKit.px(40, ui_scale)
	_text.custom_minimum_size.x = text_w
	_box.custom_minimum_size.x = w
	_box.reset_size()
	_box.position = Vector2(floorf((s.x - _box.size.x) * 0.5), floorf(s.y - bar_h - _box.size.y - UIKit.px(10, ui_scale)))
	var mw: float = minf(UIKit.px(760, ui_scale), s.x - UIKit.px(48, ui_scale))
	for l: Label in [_vision, _line1, _line2]:
		l.custom_minimum_size.x = mw
	_memory.reset_size()
	_memory.position = Vector2(floorf((s.x - _memory.size.x) * 0.5), floorf((s.y - _memory.size.y) * 0.5))
	_continue.reset_size()
	_continue.position = Vector2(s.x - _continue.size.x - UIKit.px(24, ui_scale),
			s.y - bar_h + floorf((bar_h - _continue.size.y) * 0.5))


static func _rect(n: StringName, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = n
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _label(n: StringName) -> Label:
	var l := Label.new()
	l.name = n
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Gradiente radial (centro -> borda); inner_stop = até onde o centro fica na cor de dentro.
static func _radial(inner: Color, outer: Color, inner_stop: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	if inner_stop > 0.0:
		g.add_point(inner_stop, inner)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 1.0) if inner_stop > 0.0 else Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t
