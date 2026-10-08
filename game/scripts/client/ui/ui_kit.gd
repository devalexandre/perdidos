class_name UIKit
extends RefCounted
## Kit de interface (PC, pronto para toque): tema pixel-art gerado em código, escala por resolução,
## fonte nítida, texturas do kit de C (assets/ui/) quando existirem e utilitários comuns
## (ícones de item, emotes, formatação de mensagens). Todas as janelas usam este tema.

# --- Escala -------------------------------------------------------------------------------------
## Altura de referência (720p = escala 1,0). 1080p = 1,5.
const REFERENCE_HEIGHT: float = 720.0
const MIN_SCALE: float = 1.0
const MAX_SCALE: float = 3.0

# --- Tipografia (em px na escala 1,0) --------------------------------------------------------------
const FONT_SIZE: int = 16
const FONT_SIZE_SMALL: int = 14
const FONT_SIZE_TITLE: int = 20
const FONT_SIZE_BIG: int = 32
## Tamanho da fonte do nome sobre a cabeça, em texels do mundo (1 texel = 1 px interno com zoom 1).
const NAMEPLATE_FONT_SIZE: int = 12
const OUTLINE_SIZE: int = 3
## Pastas onde procurar uma fonte pixel de C (a primeira .ttf/.otf encontrada vence).
const FONT_DIRS: Array[String] = ["res://assets/ui/fonts/", "res://assets/fonts/"]

## Bônus de item em % que REDUZEM tempo (GDD §8.1): mostrados como "−N%".
const PERCENT_REDUCTION_STATS: Array[StringName] = [&"cast_reduction", &"cooldown_reduction"]

# --- Paleta (paleta mestra, tema "madeira, couro, pergaminho e ouro velho" — 05/10/2026) -------------
## Tons-base (todos da paleta-mestra.gpl): madeira, ouro envelhecido, pergaminho, couro vermelho, folha.
const COLOR_WOOD_DARK: Color = Color8(58, 36, 24)
const COLOR_WOOD: Color = Color8(107, 66, 38)
const COLOR_WOOD_LIGHT: Color = Color8(156, 106, 60)
const COLOR_GOLD_AGED: Color = Color8(168, 116, 30)
const COLOR_GOLD: Color = Color8(230, 180, 58)
const COLOR_GOLD_LIGHT: Color = Color8(250, 229, 140)
const COLOR_PARCHMENT: Color = Color8(242, 230, 200)
const COLOR_PARCHMENT_SHADE: Color = Color8(201, 176, 138)
const COLOR_PARCHMENT_EDGE: Color = Color8(140, 116, 88)
const COLOR_LEATHER: Color = Color8(156, 42, 38)
const COLOR_LEATHER_DARK: Color = Color8(74, 20, 20)
const COLOR_LEAF: Color = Color8(47, 107, 62)
const COLOR_LEAF_LIGHT: Color = Color8(166, 216, 106)
## Painéis escuros sobre o mundo (chat, dicas, avisos, barra): madeira escura translúcida.
const COLOR_HUD_PANEL: Color = Color8(43, 27, 18, 232)
const COLOR_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.55)

const COLOR_PANEL: Color = COLOR_WOOD_DARK
const COLOR_PANEL_INNER: Color = COLOR_WOOD
const COLOR_BORDER: Color = COLOR_GOLD
const COLOR_BORDER_DARK: Color = Color8(31, 20, 14)
const COLOR_TEXT: Color = COLOR_PARCHMENT
const COLOR_TEXT_DIM: Color = COLOR_PARCHMENT_SHADE
const COLOR_TEXT_DISABLED: Color = COLOR_PARCHMENT_EDGE
const COLOR_TITLE: Color = COLOR_GOLD_LIGHT
## Botão de couro vermelho-terroso; o "hover" é o mesmo couro com aro de ouro (texto continua AA).
const COLOR_BUTTON: Color = COLOR_LEATHER
const COLOR_BUTTON_HOVER: Color = Color8(181, 58, 42)
const COLOR_BUTTON_PRESSED: Color = COLOR_LEATHER_DARK
const COLOR_SLOT: Color = COLOR_PARCHMENT_SHADE
const COLOR_SLOT_SELECTED: Color = COLOR_GOLD
const COLOR_FIELD: Color = Color8(40, 26, 18, 245)
const COLOR_OUTLINE: Color = Color8(22, 17, 15)
const COLOR_ERROR: Color = Color8(245, 154, 106)
const COLOR_STARS: Color = COLOR_GOLD
const COLOR_NAME_PLAYER: Color = Color8(252, 250, 245)
const COLOR_NAME_LOCAL: Color = COLOR_LEAF_LIGHT
## Membros do grupo: nome sobre a cabeça, chat do grupo e destaque no painel.
const COLOR_NAME_PARTY: Color = Color8(168, 212, 245)
const COLOR_NAME_NPC: Color = COLOR_GOLD_LIGHT
const COLOR_CHAT_NAME: Color = Color8(158, 224, 200)
const COLOR_CHAT_SYSTEM: Color = COLOR_GOLD
## Moldura das janelas (GameWindow): madeira escura, filete de ouro velho; cabeçalho de madeira média.
const COLOR_WINDOW_FRAME: Color = COLOR_WOOD_DARK
const COLOR_WINDOW_HEADER: Color = COLOR_WOOD
## Abas verticais/horizontais: inativa = madeira com texto claro; ativa = pergaminho com tinta vermelha.
const COLOR_TAB: Color = COLOR_WOOD
const COLOR_TAB_HOVER: Color = COLOR_WOOD_LIGHT
const COLOR_TAB_ACTIVE: Color = COLOR_PARCHMENT
## Cartões dentro do pergaminho (blocos de conteúdo) e área de detalhe.
const COLOR_CARD: Color = Color8(232, 214, 176)
const COLOR_CARD_BORDER: Color = COLOR_PARCHMENT_EDGE
## Cor do nome por raridade (GDD §11.2): branco, verde, azul, roxo.
const RARITY_COLORS: Array[Color] = [
	Color8(252, 250, 245), Color8(166, 216, 106), Color8(90, 144, 224), Color8(201, 168, 236)]

# --- Métricas (px na escala 1,0) ------------------------------------------------------------------
const BORDER: int = 2
const PADDING: int = 6
const SEPARATION: int = 4
const SLOT_SIZE: int = 40
const ICON_SIZE: int = 32

# --- Kit de C (assets/ui/): nome lógico → arquivo. Ausente = estilo gerado em código. -------------
const UI_DIR: String = "res://assets/ui/"
const KIT_PANEL: StringName = &"panel"
const KIT_BUTTON: StringName = &"button"
const KIT_BUTTON_HOVER: StringName = &"button_hover"
const KIT_BUTTON_PRESSED: StringName = &"button_pressed"
const KIT_SLOT: StringName = &"slot"
const KIT_TOOLTIP: StringName = &"tooltip"
const KIT_DIALOGUE: StringName = &"dialogue"
const KIT_CURSOR: StringName = &"cursor"
const KIT_NAME_PLATE: StringName = &"name_plate"
const KIT_CURSOR_INTERACT: StringName = &"cursor_interact"
## Nomes aceitos para cada peça (o primeiro que existir vence).
const KIT_FILES: Dictionary[StringName, Array] = {
	KIT_PANEL: ["ui_panel.png", "panel.png"],
	KIT_BUTTON: ["ui_button.png", "button.png", "ui_button_normal.png"],
	KIT_BUTTON_HOVER: ["ui_button_hover.png", "button_hover.png"],
	KIT_BUTTON_PRESSED: ["ui_button_pressed.png", "button_pressed.png"],
	KIT_SLOT: ["ui_slot.png", "slot.png", "ui_item_slot.png"],
	KIT_TOOLTIP: ["ui_tooltip.png", "tooltip.png"],
	KIT_DIALOGUE: ["ui_dialogue.png", "ui_dialogue_box.png", "dialogue.png"],
	KIT_CURSOR: ["cursor_normal.png", "ui_cursor.png", "cursor.png"],
	KIT_NAME_PLATE: ["ui_name_plate.png"],
	KIT_CURSOR_INTERACT: ["cursor_interact.png", "ui_cursor_interact.png"],
}
const KIT_META_PATH: String = "res://assets/ui/ui_kit.json"
## Acima disso o miolo do painel é considerado claro e o texto padrão vira tinta escura.
const LIGHT_PANEL_LUMINANCE: float = 0.6
## Tinta para texto sobre pergaminho.
const COLOR_INK: Color = COLOR_WOOD_DARK
const COLOR_INK_DIM: Color = COLOR_WOOD
const COLOR_INK_TITLE: Color = COLOR_LEATHER
## Ouro escuro (Ouro 1): legível no pergaminho (o Ouro 2 não passa o contraste AA).
const COLOR_INK_STARS: Color = Color8(90, 58, 16)
const COLOR_INK_ERROR: Color = COLOR_LEATHER
const COLOR_INK_GOOD: Color = COLOR_LEAF
## Margem 9-slice padrão (fração do menor lado) quando o kit não informa.
const KIT_SLICE_FRACTION: float = 1.0 / 3.0
const EMOTE_DIR: String = "res://assets/ui/emotes/"
const ITEM_ICON_DIR: String = "res://assets/items/icons/"

## Os 6 emotes do contrato, em ordem da barra.
const EMOTES: Array[StringName] = [&"wave", &"sit", &"laugh", &"cry", &"angry", &"heart"]
## Espaços de equipamento, em ordem de exibição.
const EQUIP_SLOTS: Array[StringName] = [
	&"weapon", &"offhand", &"head", &"body", &"gloves", &"feet", &"accessory_1", &"accessory_2"]
const INVENTORY_SIZE: int = 40
const INVENTORY_COLUMNS: int = 10

## Fornecedor de ItemDef (testes trocam por dados falsos). Vazio = autoload Content.
static var item_provider: Callable = Callable()

static var _font_cache: Font = null
static var _read_font_cache: Font = null
static var _world_font_cache: Font = null
static var _kit_cache: Dictionary[StringName, Texture2D] = {}
static var _kit_checked: Dictionary[StringName, bool] = {}


# --- Escala ---------------------------------------------------------------------------------------

## Escala da interface para uma janela (720p = 1,0; 1080p = 1,5).
static func scale_for(window_size: Vector2) -> float:
	return clampf(window_size.y / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE)


## Converte px da escala 1,0 para a escala dada (inteiro, para manter tudo alinhado ao pixel).
static func px(value: float, ui_scale: float) -> int:
	return roundi(value * ui_scale)


## Fator inteiro para ampliar texturas pixel-art do kit (sempre inteiro para ficar nítido).
static func texture_scale(ui_scale: float) -> int:
	return maxi(1, roundi(ui_scale))


# --- Fonte ----------------------------------------------------------------------------------------

## Fonte da interface: a fonte pixel de C se existir; senão a padrão nítida.
static func font() -> Font:
	if _font_cache != null:
		return _font_cache
	for preferred: String in ["pixel_display.ttf", "retro_pixel.ttf"]:
		for dir: String in FONT_DIRS:
			var path: String = dir + preferred
			if ResourceLoader.exists(path):
				var loaded: Font = load(path) as Font
				if loaded != null:
					_font_cache = _setup_font(loaded, false)
					return _font_cache
	for dir: String in FONT_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f: String in ResourceLoader.list_directory(dir):
			if f.ends_with(".ttf") or f.ends_with(".otf"):
				var loaded: Font = load(dir + f) as Font
				if loaded != null:
					_font_cache = _setup_font(loaded, false)
					return _font_cache
	var fallback: Font = ThemeDB.fallback_font
	if fallback is FontFile:
		var crisp: FontFile = (fallback as FontFile).duplicate() as FontFile
		crisp.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		crisp.hinting = TextServer.HINTING_LIGHT
		crisp.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font_cache = crisp
	else:
		_font_cache = fallback
	return _font_cache


## Fonte legível (para chat, diálogos, descrições de itens, tooltips):
static func read_font() -> Font:
	if _read_font_cache != null:
		return _read_font_cache
	for preferred: String in ["text_readable.ttf", "pixel_display.ttf"]:
		for dir: String in FONT_DIRS:
			var path: String = dir + preferred
			if ResourceLoader.exists(path):
				var loaded: Font = load(path) as Font
				if loaded != null:
					_read_font_cache = _setup_font(loaded, true)
					return _read_font_cache
	_read_font_cache = font()
	return _read_font_cache


static func _setup_font(f: Font, is_reading: bool) -> Font:
	if f is FontFile:
		var ff: FontFile = (f as FontFile).duplicate() as FontFile
		if is_reading:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			ff.hinting = TextServer.HINTING_LIGHT
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			var variation := FontVariation.new()
			variation.base_font = ff
			variation.variation_opentype = {&"wght": 700.0}
			variation.variation_embolden = 0.6
			return variation
		else:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			ff.hinting = TextServer.HINTING_NORMAL
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		return ff
	return f


## Fonte dos textos no mundo (nome, balões), desenhados na resolução interna 960x540 e ampliados.
static func world_font() -> Font:
	if _world_font_cache != null:
		return _world_font_cache
	_world_font_cache = read_font()
	return _world_font_cache


# --- Tema -----------------------------------------------------------------------------------------

## Tema completo da interface na escala dada.
static func build_window_theme(ui_scale: float) -> Theme:
	var t: Theme = build_theme(ui_scale)
	t.set_color(&"font_color", &"Label", COLOR_TEXT)
	t.set_color(&"default_color", &"RichTextLabel", COLOR_TEXT)
	t.set_color(&"font_color", &"CheckBox", COLOR_TEXT)
	# Mesmo vocabulário da mochila: bronze discreto, ouro na seleção e texto claro.
	for type_name: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var active: bool = state in [&"pressed", &"hover_pressed"]
			var bg: Color = COLOR_SLOT_DARK_HOVER if state == &"hover" or active else COLOR_SLOT_DARK_EMPTY
			var edge: Color = COLOR_GOLD if active else COLOR_SLOT_DARK_EDGE
			if state == &"hover":
				edge = COLOR_GOLD_AGED
			var sb: StyleBoxFlat = chamfer_box(bg, edge, maxi(1, px(1, ui_scale)), px(6, ui_scale), px(3, ui_scale))
			t.set_stylebox(state, type_name, sb)
			t.set_color(&"font_disabled_color", type_name, COLOR_TEXT_DISABLED)
			t.set_constant(&"outline_size", type_name, 0)
	for type_name: StringName in [&"Label", &"RichTextLabel"]:
		t.set_constant(&"outline_size", type_name, 0)
	for type_name: StringName in [&"HScrollBar", &"VScrollBar"]:
		t.set_stylebox(&"scroll", type_name, flat_box(COLOR_DARK_PANEL, COLOR_SLOT_DARK_EDGE, 0, 0))
		t.set_stylebox(&"grabber", type_name, chamfer_box(COLOR_WOOD_LIGHT, COLOR_GOLD_AGED, 1, 0, 2))
	return t


static func build_theme(ui_scale: float) -> Theme:
	var t := Theme.new()
	t.default_font = read_font()
	t.default_font_size = px(FONT_SIZE, ui_scale)
	var border: int = maxi(1, px(BORDER, ui_scale))
	var pad: int = px(PADDING, ui_scale)

	var panel: StyleBox = _kit_style(KIT_PANEL, ui_scale, pad)
	if panel == null:
		panel = flat_box(COLOR_PANEL, COLOR_BORDER, border, pad)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)

	var tooltip: StyleBox = _kit_style(KIT_TOOLTIP, ui_scale, pad)
	if tooltip == null:
		tooltip = flat_box(COLOR_FIELD, COLOR_BORDER, border, pad)
	t.set_stylebox(&"panel", &"TooltipPanel", tooltip)
	t.set_color(&"font_color", &"TooltipLabel", COLOR_TEXT)
	t.set_font_size(&"font_size", &"TooltipLabel", px(FONT_SIZE_SMALL, ui_scale))

	var btn_normal: StyleBox = _kit_style(KIT_BUTTON, ui_scale, pad)
	var btn_hover: StyleBox = _kit_style(KIT_BUTTON_HOVER, ui_scale, pad)
	var btn_pressed: StyleBox = _kit_style(KIT_BUTTON_PRESSED, ui_scale, pad)
	if btn_normal == null:
		btn_normal = flat_box(COLOR_BUTTON, COLOR_BORDER, border, pad)
	if btn_hover == null:
		btn_hover = flat_box(COLOR_BUTTON_HOVER, COLOR_BORDER, border, pad)
	if btn_pressed == null:
		btn_pressed = flat_box(COLOR_BUTTON_PRESSED, COLOR_BORDER, border, pad)
	var btn_disabled: StyleBox = flat_box(COLOR_PARCHMENT_SHADE, COLOR_PARCHMENT_EDGE, border, pad)
	var btn_focus: StyleBox = flat_box(Color.TRANSPARENT, COLOR_TITLE, border, pad)
	btn_focus.draw_center = false
	for type_name: StringName in [&"Button", &"OptionButton", &"CheckBox", &"MenuButton"]:
		t.set_stylebox(&"normal", type_name, btn_normal)
		t.set_stylebox(&"hover", type_name, btn_hover)
		t.set_stylebox(&"pressed", type_name, btn_pressed)
		t.set_stylebox(&"hover_pressed", type_name, btn_pressed)
		t.set_stylebox(&"disabled", type_name, btn_disabled)
		t.set_stylebox(&"focus", type_name, btn_focus)
		t.set_color(&"font_color", type_name, COLOR_TEXT)
		t.set_color(&"font_hover_color", type_name, COLOR_TITLE)
		t.set_color(&"font_pressed_color", type_name, COLOR_TITLE)
		t.set_color(&"font_hover_pressed_color", type_name, COLOR_TITLE)
		t.set_color(&"font_focus_color", type_name, COLOR_TEXT)
		t.set_color(&"font_disabled_color", type_name, COLOR_INK_DIM)
		t.set_color(&"font_outline_color", type_name, COLOR_OUTLINE)
	# CheckBox: sem caixa de botão em volta, só o texto.
	var empty := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(state, &"CheckBox", empty)
	t.set_constant(&"h_separation", &"Button", px(SEPARATION, ui_scale))
	var box_px: int = px(FONT_SIZE, ui_scale)
	t.set_icon(&"unchecked", &"CheckBox", _check_icon(box_px, border, false))
	t.set_icon(&"checked", &"CheckBox", _check_icon(box_px, border, true))
	t.set_icon(&"unchecked_disabled", &"CheckBox", _check_icon(box_px, border, false))
	t.set_icon(&"checked_disabled", &"CheckBox", _check_icon(box_px, border, true))

	var field: StyleBox = flat_box(COLOR_FIELD, COLOR_BORDER_DARK, border, pad)
	var field_focus: StyleBox = flat_box(COLOR_FIELD, COLOR_BORDER, border, pad)
	var read_f: Font = read_font()
	for type_name: StringName in [&"LineEdit", &"TextEdit", &"SpinBox"]:
		t.set_stylebox(&"normal", type_name, field)
		t.set_stylebox(&"focus", type_name, field_focus)
		t.set_stylebox(&"read_only", type_name, field)
		t.set_font(&"font", type_name, read_f)
		t.set_color(&"font_color", type_name, COLOR_TEXT)
		t.set_color(&"font_placeholder_color", type_name, COLOR_TEXT_DISABLED)
		t.set_color(&"caret_color", type_name, COLOR_TITLE)
		t.set_color(&"selection_color", type_name, COLOR_BUTTON_HOVER)
	t.set_font(&"font", &"TooltipLabel", read_f)
	t.set_stylebox(&"normal", &"RichTextLabel", StyleBoxEmpty.new())
	t.set_color(&"default_color", &"RichTextLabel", COLOR_TEXT)
	t.set_font(&"normal_font", &"RichTextLabel", read_f)
	t.set_font(&"bold_font", &"RichTextLabel", read_f)
	t.set_font_size(&"normal_font_size", &"RichTextLabel", px(FONT_SIZE, ui_scale))
	t.set_font_size(&"bold_font_size", &"RichTextLabel", px(FONT_SIZE, ui_scale))
	t.set_constant(&"outline_size", &"RichTextLabel", px(OUTLINE_SIZE, ui_scale))
	t.set_color(&"font_outline_color", &"RichTextLabel", COLOR_OUTLINE)

	t.set_color(&"font_color", &"Label", COLOR_TEXT)
	t.set_color(&"font_outline_color", &"Label", COLOR_OUTLINE)
	t.set_constant(&"outline_size", &"Label", maxi(2, px(OUTLINE_SIZE - 1, ui_scale)))

	# Barras e deslizadores de volume.
	var slider_track: StyleBox = flat_box(COLOR_FIELD, COLOR_BORDER_DARK, border, 0)
	slider_track.content_margin_top = px(SEPARATION, ui_scale)
	slider_track.content_margin_bottom = px(SEPARATION, ui_scale)
	t.set_stylebox(&"slider", &"HSlider", slider_track)
	var fill: StyleBox = flat_box(COLOR_BORDER, COLOR_BORDER, 0, 0)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_icon(&"grabber", &"HSlider", _square_icon(px(FONT_SIZE, ui_scale), COLOR_TITLE))
	t.set_icon(&"grabber_highlight", &"HSlider", _square_icon(px(FONT_SIZE, ui_scale), COLOR_TEXT))

	var popup: StyleBox = flat_box(COLOR_PANEL, COLOR_BORDER, border, pad)
	t.set_stylebox(&"panel", &"PopupMenu", popup)
	t.set_color(&"font_color", &"PopupMenu", COLOR_TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", COLOR_TITLE)
	t.set_stylebox(&"hover", &"PopupMenu", flat_box(COLOR_BUTTON_HOVER, COLOR_BUTTON_HOVER, 0, 0))

	# Barra de rolagem: trilho de pergaminho escurecido e cursor de madeira (larga o bastante para o dedo).
	var scroll_bg: StyleBoxFlat = flat_box(COLOR_PARCHMENT_SHADE, COLOR_PARCHMENT_EDGE, maxi(1, px(1, ui_scale)), 0)
	var scroll_grab: StyleBoxFlat = flat_box(COLOR_WOOD_LIGHT, COLOR_WOOD_DARK, maxi(1, px(1, ui_scale)), 0)
	var scroll_hot: StyleBoxFlat = flat_box(COLOR_WOOD, COLOR_GOLD_AGED, maxi(1, px(1, ui_scale)), 0)
	var thick: int = px(SEPARATION + 1, ui_scale)
	for sb: StyleBoxFlat in [scroll_bg, scroll_grab, scroll_hot]:
		sb.content_margin_left = thick
		sb.content_margin_right = thick
		sb.content_margin_top = thick
		sb.content_margin_bottom = thick
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", bar, scroll_bg)
		t.set_stylebox(&"scroll_focus", bar, scroll_bg)
		t.set_stylebox(&"grabber", bar, scroll_grab)
		t.set_stylebox(&"grabber_highlight", bar, scroll_hot)
		t.set_stylebox(&"grabber_pressed", bar, scroll_hot)

	var sep: int = px(SEPARATION, ui_scale)
	for type_name: StringName in [&"VBoxContainer", &"HBoxContainer", &"BoxContainer"]:
		t.set_constant(&"separation", type_name, sep)
	t.set_constant(&"h_separation", &"GridContainer", sep)
	t.set_constant(&"v_separation", &"GridContainer", sep)
	if kit_panel_is_light():
		# Janelas de pergaminho: texto em tinta escura (textos sobre o mundo definem a própria cor).
		t.set_color(&"font_color", &"Label", COLOR_INK)
		t.set_color(&"font_outline_color", &"Label", Color.TRANSPARENT)
		t.set_color(&"default_color", &"RichTextLabel", COLOR_INK)
		t.set_color(&"font_color", &"CheckBox", COLOR_INK)
	return t


## Caixa lisa pixel-art (sem arredondamento nem suavização).
static func flat_box(bg: Color, border_color: Color, border: int, padding: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_color
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = padding + border
	sb.content_margin_right = padding + border
	sb.content_margin_top = padding + border
	sb.content_margin_bottom = padding + border
	return sb


## Estilo do espaço de item (normal ou selecionado).
static func slot_box(ui_scale: float, selected: bool) -> StyleBox:
	if not selected:
		var kit: StyleBox = _kit_style(KIT_SLOT, ui_scale, 0)
		if kit != null:
			return kit
	var border: int = maxi(1, px(BORDER, ui_scale))
	return flat_box(COLOR_SLOT, COLOR_SLOT_SELECTED if selected else COLOR_BORDER_DARK, border, 0)


## Estilo do painel da caixa de diálogo (kit de C ou painel padrão).
static func dialogue_box(ui_scale: float) -> StyleBox:
	var pad: int = px(PADDING * 2, ui_scale)
	var kit: StyleBox = _kit_style(KIT_DIALOGUE, ui_scale, pad)
	if kit != null:
		return kit
	var sb: StyleBoxFlat = flat_box(COLOR_PARCHMENT, COLOR_WOOD, maxi(2, px(4, ui_scale)), pad)
	sb.shadow_size = px(8, ui_scale)
	sb.shadow_color = COLOR_SHADOW
	return sb


## Placa de couro com aro de ouro para o nome de quem fala (diálogo).
static func name_plate(ui_scale: float) -> StyleBox:
	var kit: StyleBox = _kit_style(KIT_NAME_PLATE, ui_scale, px(4, ui_scale))
	if kit != null:
		kit.content_margin_left += px(6, ui_scale)
		kit.content_margin_right += px(6, ui_scale)
		return kit
	var sb: StyleBoxFlat = flat_box(COLOR_LEATHER, COLOR_GOLD_AGED, maxi(1, px(2, ui_scale)), px(4, ui_scale))
	sb.content_margin_left = px(12, ui_scale)
	sb.content_margin_right = px(12, ui_scale)
	return sb


## Moldura de janela: madeira escura com filete de ouro velho e sombra (kit de madeira se existir).
static func window_frame(ui_scale: float) -> StyleBoxFlat:
	var frame: StyleBoxFlat = flat_box(COLOR_WINDOW_FRAME, COLOR_GOLD_AGED, maxi(2, px(3, ui_scale)), px(3, ui_scale))
	frame.shadow_size = px(8, ui_scale)
	frame.shadow_color = COLOR_SHADOW
	return frame


## Cabeçalho da janela (título arrastável): madeira média com filete de ouro embaixo.
static func window_header(ui_scale: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = flat_box(COLOR_WINDOW_HEADER, COLOR_GOLD_AGED, 0, px(5, ui_scale))
	sb.border_width_bottom = maxi(1, px(2, ui_scale))
	sb.content_margin_left = px(8, ui_scale)
	return sb


## Miolo de pergaminho das janelas.
static func paper_box(ui_scale: float) -> StyleBoxFlat:
	return flat_box(COLOR_PARCHMENT, COLOR_PARCHMENT_EDGE, maxi(1, px(1, ui_scale)), px(PADDING, ui_scale))


## Cartão dentro do pergaminho (bloco de conteúdo: lista, detalhe, atributos).
static func card_box(ui_scale: float, padding: float = 8.0) -> StyleBoxFlat:
	return flat_box(COLOR_CARD, COLOR_CARD_BORDER, maxi(1, px(1, ui_scale)), px(padding, ui_scale))


## Faixa de destaque escura dentro do pergaminho (pontos a gastar, avisos).
static func banner_box(ui_scale: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = flat_box(COLOR_WOOD_DARK, COLOR_GOLD_AGED, maxi(1, px(1, ui_scale)), px(5, ui_scale))
	sb.content_margin_left = px(12, ui_scale)
	sb.content_margin_right = px(12, ui_scale)
	return sb


## Painel escuro sobre o mundo (chat, avisos, barra de atalhos): madeira escura translúcida.
static func hud_box(ui_scale: float, padding: float = PADDING, bg: Color = COLOR_HUD_PANEL) -> StyleBoxFlat:
	return flat_box(bg, COLOR_GOLD_AGED, maxi(1, px(BORDER, ui_scale)), px(padding, ui_scale))


## Estilos de uma aba (normal, hover, pressed=ativa, disabled). accent = faixa na lateral (cor do título);
## vertical = faixa à esquerda (lista de títulos), senão embaixo (abas horizontais).
static func tab_styles(ui_scale: float, accent: Color = COLOR_GOLD_AGED, vertical: bool = true) -> Dictionary:
	var stripe: int = maxi(3, px(5, ui_scale))
	var line: int = maxi(1, px(1, ui_scale))
	var out: Dictionary = {}
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var bg: Color = COLOR_TAB
		var edge: Color = COLOR_BORDER_DARK
		match state:
			&"hover":
				bg = COLOR_TAB_HOVER
			&"pressed":
				bg = COLOR_TAB_ACTIVE
				edge = COLOR_GOLD_AGED
			&"disabled":
				bg = COLOR_PARCHMENT_SHADE
		var sb: StyleBoxFlat = flat_box(bg, edge, line, px(6, ui_scale))
		sb.content_margin_left = px(10, ui_scale)
		sb.content_margin_right = px(8, ui_scale)
		var a: Color = accent if state == &"pressed" else accent.darkened(0.15)
		if vertical:
			sb.border_width_left = stripe
		else:
			sb.border_width_bottom = stripe
		# A faixa usa a cor de destaque; as outras bordas ficam finas na cor da borda.
		sb.border_color = a if state != &"disabled" else COLOR_PARCHMENT_EDGE
		if state == &"pressed":
			sb.expand_margin_right = line if vertical else 0
		out[state] = sb
	return out


## Aplica os estilos de aba a um botão (toggle) e as cores de texto (claro na madeira, tinta na ativa).
static func style_tab(b: Button, ui_scale: float, accent: Color = COLOR_GOLD_AGED, vertical: bool = true) -> void:
	var st: Dictionary = tab_styles(ui_scale, accent, vertical)
	b.add_theme_stylebox_override(&"normal", st[&"normal"])
	b.add_theme_stylebox_override(&"hover", st[&"hover"])
	b.add_theme_stylebox_override(&"pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"hover_pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"disabled", st[&"disabled"])
	b.add_theme_color_override(&"font_color", COLOR_TEXT)
	b.add_theme_color_override(&"font_hover_color", COLOR_GOLD_LIGHT)
	b.add_theme_color_override(&"font_pressed_color", COLOR_INK_TITLE)
	b.add_theme_color_override(&"font_hover_pressed_color", COLOR_INK_TITLE)
	b.add_theme_color_override(&"font_disabled_color", COLOR_INK_DIM)
	b.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	b.add_theme_constant_override(&"outline_size", 0)


## true quando o jogo está no modo de controles de toque (celular ou opção ligada).
static func is_touch_layout() -> bool:
	return GameSettings.get_instance().mobile_controls


# --- Kit de C -------------------------------------------------------------------------------------

## Textura do kit (assets/ui/) ou null se C ainda não entregou.
static func kit_texture(piece: StringName) -> Texture2D:
	if _kit_checked.get(piece, false):
		return _kit_cache.get(piece)
	_kit_checked[piece] = true
	for file: String in KIT_FILES.get(piece, []):
		var path: String = UI_DIR + file
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				_kit_cache[piece] = tex
				return tex
	return null


## Esquece o cache do kit (ex.: C entregou arquivos novos durante o desenvolvimento).
static func reset_cache() -> void:
	_kit_cache.clear()
	_kit_checked.clear()
	_light_cache = -1
	_kit_meta.clear()
	_font_cache = null
	_read_font_cache = null
	_world_font_cache = null


static func _kit_style(piece: StringName, ui_scale: float, padding: int) -> StyleBox:
	var tex: Texture2D = kit_texture(piece)
	if tex == null:
		return null
	var k: int = texture_scale(ui_scale)
	var scaled: Texture2D = scale_texture(tex, k)
	var sb := StyleBoxTexture.new()
	sb.texture = scaled
	# Margens do 9-slice: ui_kit.json de C (esq, cima, dir, baixo); senão 1/3 do menor lado.
	var fallback: int = floori(minf(tex.get_width(), tex.get_height()) * KIT_SLICE_FRACTION)
	var m: Array = _kit_margins(tex.resource_path.get_file(), fallback)
	sb.texture_margin_left = m[0] * k
	sb.texture_margin_top = m[1] * k
	sb.texture_margin_right = m[2] * k
	sb.texture_margin_bottom = m[3] * k
	sb.content_margin_left = m[0] * k + padding
	sb.content_margin_top = m[1] * k + padding
	sb.content_margin_right = m[2] * k + padding
	sb.content_margin_bottom = m[3] * k + padding
	# Miolo e bordas repetidos em vez de esticados: detalhes da textura (veios, rebites) continuam pixel art.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


static var _kit_meta: Dictionary = {}

static func _kit_margins(file_name: String, fallback: int) -> Array:
	if _kit_meta.is_empty() and FileAccess.file_exists(KIT_META_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_META_PATH))
		if parsed is Dictionary:
			_kit_meta = parsed
	var entry: Variant = _kit_meta.get(file_name)
	if entry is Dictionary and (entry as Dictionary).get("nine_slice") is Array \
			and ((entry as Dictionary)["nine_slice"] as Array).size() == 4:
		var ns: Array = (entry as Dictionary)["nine_slice"]
		return [int(ns[0]), int(ns[1]), int(ns[2]), int(ns[3])]
	return [fallback, fallback, fallback, fallback]


## Cores de texto para usar DENTRO de janelas: tinta escura sobre pergaminho, claras sobre painel escuro.
static func c_text() -> Color: return COLOR_INK if kit_panel_is_light() else COLOR_TEXT
static func c_text_dim() -> Color: return COLOR_INK_DIM if kit_panel_is_light() else COLOR_TEXT_DIM
static func c_title() -> Color: return COLOR_INK_TITLE if kit_panel_is_light() else COLOR_TITLE
static func c_stars() -> Color: return COLOR_INK_STARS if kit_panel_is_light() else COLOR_STARS
static func c_error() -> Color: return COLOR_INK_ERROR if kit_panel_is_light() else COLOR_ERROR


## true se o painel do kit é claro (pergaminho) → texto em tinta escura.
static var _light_cache: int = -1

static func kit_panel_is_light() -> bool:
	if _light_cache >= 0:
		return _light_cache == 1
	_light_cache = 1 if _compute_panel_light() else 0
	return _light_cache == 1


static func _compute_panel_light() -> bool:
	var tex: Texture2D = kit_texture(KIT_PANEL)
	if tex == null:
		return false
	var img: Image = tex.get_image()
	if img == null:
		return false
	if img.is_compressed():
		img.decompress()
	var c: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	return c.get_luminance() > LIGHT_PANEL_LUMINANCE


## Amplia uma textura pixel-art por fator inteiro com vizinho mais próximo.
static func scale_texture(tex: Texture2D, factor: int) -> Texture2D:
	if factor <= 1:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Cursor do mouse (normal/interagir): kit de C se existir; senão forma de cursor do sistema.
static func apply_cursor(interact: bool) -> void:
	var tex: Texture2D = kit_texture(KIT_CURSOR_INTERACT if interact else KIT_CURSOR)
	if tex != null:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if interact else Input.CURSOR_ARROW)


# --- Itens e emotes -------------------------------------------------------------------------------

static func item(id: StringName) -> ItemDef:
	if id == &"":
		return null
	if item_provider.is_valid():
		return item_provider.call(id) as ItemDef
	var content: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/Content") \
			if Engine.get_main_loop() is SceneTree else null
	if content == null:
		return null
	return content.call(&"item", id) as ItemDef


## Ícone do item: ItemDef.icon, senão assets/items/icons/icon_item_<id>.png, senão null.
static func item_icon(def: ItemDef) -> Texture2D:
	if def == null:
		return null
	if def.icon != null:
		return def.icon
	var path: String = "%sicon_item_%s.png" % [ITEM_ICON_DIR, def.id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func item_name(def: ItemDef) -> String:
	if def == null:
		return ""
	return TranslationServer.translate(def.name_key) if not def.name_key.is_empty() else String(def.id)


## Cor da raridade para texto sobre o pergaminho (tons escuros das mesmas rampas).
const RARITY_COLORS_INK: Array[Color] = [
	Color8(58, 36, 24), Color8(47, 107, 62), Color8(47, 85, 168), Color8(90, 58, 140)]

static func rarity_color_on_panel(def: ItemDef) -> Color:
	if not kit_panel_is_light():
		return rarity_color(def)
	if def == null:
		return COLOR_INK
	return RARITY_COLORS_INK[clampi(def.rarity, 0, RARITY_COLORS_INK.size() - 1)]


static func rarity_color(def: ItemDef) -> Color:
	if def == null:
		return COLOR_TEXT
	return RARITY_COLORS[clampi(def.rarity, 0, RARITY_COLORS.size() - 1)]


## Texto da dica do item: nome, tipo, descrição, atributos e preço.
static func item_tooltip_text(def: ItemDef, qty: int = 1, show_sell_price: bool = true) -> String:
	if def == null:
		return ""
	var lines: PackedStringArray = []
	var title: String = item_name(def)
	if qty > 1:
		title += " x%d" % qty
	lines.append(title)
	lines.append(TranslationServer.translate("ITEM_TYPE_%s" % ItemDef.ItemType.keys()[def.type]))
	if not def.desc_key.is_empty():
		lines.append(TranslationServer.translate(def.desc_key))
	for stat: StringName in def.stats:
		var v: int = def.stats[stat]
		if stat in PERCENT_REDUCTION_STATS:
			# GDD §8.1: redução de conjuração/recarga em % (ex.: "Conjuração −8%").
			lines.append("%s −%d%%" % [stat_label(stat), v])
		else:
			lines.append("%s %s%d" % [stat_label(stat), "+" if v >= 0 else "", v])
	if def.use_effect.has(&"heal_hp"):
		lines.append(TranslationServer.translate("ITEM_HEAL_HP") % int(def.use_effect[&"heal_hp"]))
	if def.use_effect.has(&"heal_mp"):
		lines.append(TranslationServer.translate("ITEM_HEAL_MP") % int(def.use_effect[&"heal_mp"]))
	if def.use_effect.has(&"def_buff_pct"):
		lines.append(TranslationServer.translate("ITEM_DEF_BUFF") % [roundi(float(def.use_effect[&"def_buff_pct"]) * 100.0),
				roundi(float(def.use_effect.get(&"buff_sec", 0.0)))])
	if def.type == ItemDef.ItemType.CONSUMABLE:
		if CastTiming.is_instant_item(def):
			lines.append(TranslationServer.translate("UI_ITEM_INSTANT"))
		else:
			lines.append(TranslationServer.translate("UI_ITEM_TIMING") % [
					seconds_text(CastTiming.item_base_cast_sec(def)),
					seconds_text(CastTiming.item_base_cooldown_sec(def))])
	if show_sell_price and def.sell_price > 0:
		lines.append(TranslationServer.translate("ITEM_SELL_PRICE") % def.sell_price)
	return "\n".join(lines)


## Segundos com 1 casa decimal e vírgula ("0,4", "12").
static func seconds_text(v: float) -> String:
	return String.num(v, 1).replace(".", ",").trim_suffix(",0")


## Nome curto de atributo traduzido (STAT_ATK, STAT_STR...).
static func stat_label(stat: StringName) -> String:
	return TranslationServer.translate("STAT_%s" % String(stat).to_upper())


## Balão do emote (assets/ui/emotes/emote_<id>.png) ou null se C ainda não entregou.
static func emote_texture(emote_id: StringName) -> Texture2D:
	var path: String = "%semote_%s.png" % [EMOTE_DIR, emote_id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Rótulo traduzido do emote (usado quando não há imagem).
static func emote_label(emote_id: StringName) -> String:
	return TranslationServer.translate("EMOTE_%s" % String(emote_id).to_upper())


## Traduz uma mensagem de sistema do servidor: chave + argumentos (formato % do GDScript).
static func format_message(key: String, args: Array) -> String:
	var text: String = TranslationServer.translate(key)
	if args.is_empty() or not text.contains("%"):
		return text
	var translated_args: Array = []
	for a: Variant in args:
		# Argumentos que são chaves de tradução (ex.: nome de item) também são traduzidos.
		translated_args.append(TranslationServer.translate(a) if a is String or a is StringName else a)
	# Formato inválido não pode derrubar a interface.
	if text.count("%") > translated_args.size() + text.count("%%") * 2:
		return text
	return text % translated_args


## Caixa de marcar pixel-art: borda dourada, miolo escuro, marcada = quadrado claro no meio.
static func _check_icon(size: int, border: int, checked: bool) -> Texture2D:
	var n: int = maxi(size, border * 4)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_BORDER)
	img.fill_rect(Rect2i(border, border, n - border * 2, n - border * 2), COLOR_FIELD)
	if checked:
		var inset: int = border * 2
		img.fill_rect(Rect2i(inset, inset, n - inset * 2, n - inset * 2), COLOR_TITLE)
	return ImageTexture.create_from_image(img)


static func _square_icon(size: int, color: Color) -> Texture2D:
	var img := Image.create(maxi(1, size), maxi(1, size), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# --- Inventário moderno (07/10/2026) --------------------------------------------------------------
## Painel escuro com filete de ouro e cantos chanfrados (referência: mochila "moderna" com DNA do RO).
## Usado pelo inventário (miolo escuro dentro da moldura de madeira) e pela dica rica de item.
const COLOR_DARK_PANEL: Color = Color8(27, 19, 14)
const COLOR_DARK_PANEL_EDGE: Color = Color8(118, 84, 36)
const COLOR_DARK_CARD: Color = Color8(37, 26, 19)
const COLOR_SLOT_DARK: Color = Color8(45, 32, 23)
const COLOR_SLOT_DARK_EMPTY: Color = Color8(34, 24, 17)
const COLOR_SLOT_DARK_EDGE: Color = Color8(66, 48, 33)
const COLOR_SLOT_DARK_HOVER: Color = Color8(58, 42, 29)
## Borda por raridade nos espaços escuros (comum = bronze discreto; demais = rampa de RARITY_COLORS).
const RARITY_EDGE_COLORS: Array[Color] = [
	Color8(104, 82, 60), Color8(98, 168, 74), Color8(80, 132, 220), Color8(170, 120, 226)]
const COLOR_STAT_GOOD: Color = Color8(166, 216, 106)
const COLOR_STAT_BAD: Color = Color8(245, 154, 106)
## Chanfro dos cantos (px na escala 1,0).
const CHAMFER: int = 4
## Largura da dica rica de item (px na escala 1,0).
const TOOLTIP_WIDTH: int = 280

static var _icon_cache: Dictionary[String, Texture2D] = {}


## Lado dos ícones 32x32 no inventário, em px. Desktop a 720p: 40 px (1,25x); acima disso, 3/4 do fator inteiro
## da escala (1080p = 48 px). O dono pediu a janela menor (08/10/2026; antes 48/64). Toque: no mínimo 2x (dedo).
static func inventory_icon_px(ui_scale: float) -> int:
	var k: int = texture_scale(ui_scale)
	if is_touch_layout():
		return ICON_SIZE * maxi(2, k)
	return ICON_SIZE * k * 3 / 4 if k >= 2 else ICON_SIZE * 5 / 4


## Caixa escura chanfrada (corner_detail 1 = canto cortado em diagonal, sem arredondar).
static func chamfer_box(bg: Color, edge: Color, border: int, padding: int, chamfer: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = flat_box(bg, edge, border, padding)
	sb.set_corner_radius_all(chamfer)
	sb.corner_detail = 1
	return sb


## Miolo escuro do inventário (no lugar do pergaminho).
static func dark_body_box(ui_scale: float) -> StyleBoxFlat:
	return chamfer_box(COLOR_DARK_PANEL, COLOR_DARK_PANEL_EDGE, maxi(1, px(1, ui_scale)), px(8, ui_scale),
			px(CHAMFER, ui_scale))


## Cartão escuro (detalhe do item, dica).
static func dark_card_box(ui_scale: float, padding: float = 8.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = chamfer_box(COLOR_DARK_CARD, COLOR_SLOT_DARK_EDGE, maxi(1, px(1, ui_scale)),
			px(padding, ui_scale), px(CHAMFER, ui_scale))
	return sb


## Espaço de item escuro: vazio bem discreto; cheio com borda da raridade (incomum+ com brilho);
## selecionado com aro de ouro claro; hover com miolo um pouco mais claro.
static func dark_slot_box(ui_scale: float, rarity: int, selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var line: int = maxi(1, px(1, ui_scale))
	var empty: bool = rarity < 0
	var bg: Color = COLOR_SLOT_DARK_EMPTY if empty else COLOR_SLOT_DARK
	if hovered:
		bg = COLOR_SLOT_DARK_HOVER
	var edge: Color = COLOR_SLOT_DARK_EDGE if empty else RARITY_EDGE_COLORS[clampi(rarity, 0, RARITY_EDGE_COLORS.size() - 1)]
	var border: int = line if empty or rarity == 0 else maxi(2, px(2, ui_scale))
	if selected:
		edge = COLOR_GOLD_LIGHT
		border = maxi(2, px(2, ui_scale))
	var sb: StyleBoxFlat = chamfer_box(bg, edge, border, 0, px(3, ui_scale))
	if not empty and rarity > 0 and not selected:
		sb.shadow_color = Color(edge, 0.35)
		sb.shadow_size = maxi(1, px(2, ui_scale))
	elif selected:
		sb.shadow_color = Color(COLOR_GOLD, 0.45)
		sb.shadow_size = maxi(2, px(3, ui_scale))
	return sb


## Botão-aba das categorias do inventário: madeira escura; ativa com borda de ouro e miolo mais claro.
static func style_pill_tab(b: Button, ui_scale: float) -> void:
	var line: int = maxi(1, px(1, ui_scale))
	var pad: int = px(6, ui_scale)
	var normal: StyleBoxFlat = chamfer_box(COLOR_SLOT_DARK_EMPTY, COLOR_SLOT_DARK_EDGE, line, pad, px(3, ui_scale))
	var hover: StyleBoxFlat = chamfer_box(COLOR_SLOT_DARK_HOVER, COLOR_GOLD_AGED, line, pad, px(3, ui_scale))
	var active: StyleBoxFlat = chamfer_box(Color8(66, 46, 26), COLOR_GOLD, maxi(1, px(1, ui_scale)), pad, px(3, ui_scale))
	active.border_width_bottom = maxi(2, px(2, ui_scale))
	for sb: StyleBoxFlat in [normal, hover, active]:
		sb.content_margin_left = px(10, ui_scale)
		sb.content_margin_right = px(10, ui_scale)
		sb.content_margin_top = px(4, ui_scale)
		sb.content_margin_bottom = px(4, ui_scale)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", active)
	b.add_theme_stylebox_override(&"hover_pressed", active)
	b.add_theme_stylebox_override(&"focus", chamfer_box(Color.TRANSPARENT, COLOR_GOLD_LIGHT, line, pad, px(3, ui_scale)))
	b.add_theme_color_override(&"font_color", COLOR_TEXT_DIM)
	b.add_theme_color_override(&"font_hover_color", COLOR_PARCHMENT)
	b.add_theme_color_override(&"font_pressed_color", COLOR_GOLD_LIGHT)
	b.add_theme_color_override(&"font_hover_pressed_color", COLOR_GOLD_LIGHT)
	b.add_theme_color_override(&"font_focus_color", COLOR_PARCHMENT)
	b.add_theme_color_override(&"font_outline_color", COLOR_OUTLINE)
	b.add_theme_constant_override(&"outline_size", maxi(1, px(2, ui_scale)))


## Nome traduzido da raridade (Comum, Incomum, Raro, Épico).
static func rarity_name(def: ItemDef) -> String:
	if def == null:
		return ""
	return TranslationServer.translate("RARITY_%s" % ItemDef.Rarity.keys()[clampi(def.rarity, 0, 3)])


## Tipo traduzido do item (crendice/munição/cosmético com nome próprio).
static func item_type_name(def: ItemDef) -> String:
	if def == null:
		return ""
	return TranslationServer.translate("ITEM_TYPE_%s" % ItemDef.ItemType.keys()[def.type])


## Linhas de atributo do item: [{label, value, good}] (bônus fixos e % de redução).
static func item_stat_lines(def: ItemDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null:
		return out
	for stat: StringName in def.stats:
		var v: int = def.stats[stat]
		if stat in PERCENT_REDUCTION_STATS:
			out.append({"label": stat_label(stat), "value": "−%d%%" % v, "good": v >= 0})
		else:
			out.append({"label": stat_label(stat), "value": "%s%d" % ["+" if v >= 0 else "−", absi(v)], "good": v >= 0})
	for stat: StringName in def.stat_percent:
		var p: int = def.stat_percent[stat]
		out.append({"label": stat_label(stat), "value": "%s%d%%" % ["+" if p >= 0 else "−", absi(p)], "good": p >= 0})
	return out


## Efeitos de uso e tempo (consumíveis), já traduzidos.
static func item_effect_lines(def: ItemDef) -> PackedStringArray:
	var lines: PackedStringArray = []
	if def == null:
		return lines
	if def.use_effect.has(&"heal_hp"):
		lines.append(TranslationServer.translate("ITEM_HEAL_HP") % int(def.use_effect[&"heal_hp"]))
	if def.use_effect.has(&"heal_mp"):
		lines.append(TranslationServer.translate("ITEM_HEAL_MP") % int(def.use_effect[&"heal_mp"]))
	if def.use_effect.has(&"def_buff_pct"):
		lines.append(TranslationServer.translate("ITEM_DEF_BUFF") % [roundi(float(def.use_effect[&"def_buff_pct"]) * 100.0),
				roundi(float(def.use_effect.get(&"buff_sec", 0.0)))])
	if def.type == ItemDef.ItemType.CONSUMABLE:
		if CastTiming.is_instant_item(def):
			lines.append(TranslationServer.translate("UI_ITEM_INSTANT"))
		else:
			lines.append(TranslationServer.translate("UI_ITEM_TIMING") % [
					seconds_text(CastTiming.item_base_cast_sec(def)),
					seconds_text(CastTiming.item_base_cooldown_sec(def))])
	return lines


## Número com separador de milhar ("12.480").
static func thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Texto das Estrelas com milhar ("12.480 Estrelas"), a partir de UI_STARS ("%d Estrelas").
static func stars_text(stars: int) -> String:
	return TranslationServer.translate("UI_STARS").replace("%d", thousands(stars))


## Rótulo pronto (fonte, cor, contorno) para painéis escuros.
static func dark_label(text: String, ui_scale: float, size: int = FONT_SIZE_SMALL, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", px(size, ui_scale))
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", COLOR_OUTLINE)
	l.add_theme_constant_override(&"outline_size", maxi(1, px(2, ui_scale)))
	return l


## Ficha do item (dica rica): cabeçalho, atributos, efeitos, descrição e rodapé de preço, empilhados.
## width = largura do texto (px na escala 1,0). O inventário monta as mesmas peças em duas colunas.
static func item_card(def: ItemDef, qty: int, ui_scale: float, width: float = TOOLTIP_WIDTH,
		show_sell_price: bool = true, show_icon: bool = true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", px(4, ui_scale))
	if def == null:
		return box
	box.add_child(item_card_head(def, qty, ui_scale, width, show_icon))
	var stats: Control = item_card_stats(def, ui_scale, width)
	if stats != null:
		box.add_child(_gold_rule(ui_scale))
		box.add_child(stats)
	var desc: Control = item_card_desc(def, ui_scale, width)
	if desc != null:
		box.add_child(_gold_rule(ui_scale))
		box.add_child(desc)
	var foot: Control = item_card_footer(def, ui_scale, show_sell_price)
	if foot != null:
		box.add_child(foot)
	return box


## Cabeçalho da ficha: ícone 2x num espaço da raridade, nome na cor da raridade e "Raridade · Tipo".
static func item_card_head(def: ItemDef, qty: int, ui_scale: float, width: float, show_icon: bool = true) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", px(8, ui_scale))
	var text_w: float = width
	if show_icon:
		var frame := PanelContainer.new()
		var fb: StyleBoxFlat = dark_slot_box(ui_scale, def.rarity, false)
		fb.set_content_margin_all(px(3, ui_scale))
		frame.add_theme_stylebox_override(&"panel", fb)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(frame)
		var icon := TextureRect.new()
		icon.texture = item_icon(def)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ip: int = inventory_icon_px(ui_scale)
		icon.custom_minimum_size = Vector2(ip, ip)
		frame.add_child(icon)
		text_w -= (ip + px(6, ui_scale) + px(8, ui_scale)) / ui_scale
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override(&"separation", px(1, ui_scale))
	head.add_child(titles)
	var title: String = item_name(def) + ("  ×%d" % qty if qty > 1 else "")
	var name_l: Label = dark_label(title, ui_scale, FONT_SIZE + 1, rarity_color(def))
	name_l.name = &"ItemName"
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = px(maxf(80.0, text_w), ui_scale)
	titles.add_child(name_l)
	var sub: Label = dark_label("%s · %s" % [rarity_name(def), item_type_name(def)], ui_scale, FONT_SIZE_SMALL - 1,
			COLOR_TEXT_DIM)
	sub.name = &"ItemKind"
	titles.add_child(sub)
	return head


## Atributos em pares (rótulo apagado, valor verde/laranja) e efeitos de uso; null se não há nada.
static func item_card_stats(def: ItemDef, ui_scale: float, width: float, columns: int = 2) -> Control:
	var stats: Array[Dictionary] = item_stat_lines(def)
	var effects: PackedStringArray = item_effect_lines(def)
	if stats.is_empty() and effects.is_empty():
		return null
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", px(2, ui_scale))
	if not stats.is_empty():
		var grid := GridContainer.new()
		grid.columns = columns * 2
		grid.add_theme_constant_override(&"h_separation", px(10, ui_scale))
		grid.add_theme_constant_override(&"v_separation", px(1, ui_scale))
		box.add_child(grid)
		for s: Dictionary in stats:
			grid.add_child(dark_label(String(s["label"]), ui_scale, FONT_SIZE_SMALL, COLOR_TEXT_DIM))
			var v: Label = dark_label(String(s["value"]), ui_scale, FONT_SIZE_SMALL,
					COLOR_STAT_GOOD if bool(s["good"]) else COLOR_STAT_BAD)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.custom_minimum_size.x = px(36, ui_scale)
			grid.add_child(v)
	for e: String in effects:
		var el: Label = dark_label(e, ui_scale, FONT_SIZE_SMALL, COLOR_STAT_GOOD)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size.x = px(width, ui_scale)
		box.add_child(el)
	return box


## Descrição (lenda do item) quebrada na largura dada; null se não há.
static func item_card_desc(def: ItemDef, ui_scale: float, width: float) -> Label:
	if def.desc_key.is_empty():
		return null
	var d: Label = dark_label(TranslationServer.translate(def.desc_key), ui_scale, FONT_SIZE_SMALL,
			COLOR_PARCHMENT_SHADE)
	d.name = &"ItemDesc"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = px(width, ui_scale)
	return d


## Rodapé: preço de venda com a estrela e "Não negociável"; null se não há nada.
static func item_card_footer(def: ItemDef, ui_scale: float, show_sell_price: bool = true) -> HBoxContainer:
	var price_on: bool = show_sell_price and def.sell_price > 0
	if not price_on and def.tradeable:
		return null
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override(&"separation", px(4, ui_scale))
	if price_on:
		foot.add_child(star_icon_rect(ui_scale))
		foot.add_child(dark_label(TranslationServer.translate("UI_ITEM_SELLS_FOR") % thousands(def.sell_price),
				ui_scale, FONT_SIZE_SMALL, COLOR_GOLD))
	if not def.tradeable:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(spacer)
		foot.add_child(dark_label(TranslationServer.translate("UI_ITEM_BOUND"), ui_scale, FONT_SIZE_SMALL - 1,
				COLOR_STAT_BAD))
	return foot


## Dica rica (painel escuro chanfrado com filete de ouro) para qualquer espaço de item.
static func item_tooltip_panel(def: ItemDef, qty: int, ui_scale: float, show_sell_price: bool = true) -> Control:
	var panel := PanelContainer.new()
	var sb: StyleBoxFlat = chamfer_box(Color(COLOR_DARK_PANEL, 0.97), COLOR_GOLD_AGED, maxi(1, px(1, ui_scale)),
			px(9, ui_scale), px(CHAMFER, ui_scale))
	sb.shadow_color = COLOR_SHADOW
	sb.shadow_size = px(6, ui_scale)
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.add_child(item_card(def, qty, ui_scale, TOOLTIP_WIDTH, show_sell_price))
	return panel


static func _gold_rule(ui_scale: float) -> Control:
	var r := ColorRect.new()
	r.color = Color(COLOR_GOLD_AGED, 0.55)
	r.custom_minimum_size = Vector2(0, maxi(1, px(1, ui_scale)))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Estrela pixel-art (moeda do jogo) ampliada por fator inteiro.
static func star_icon(ui_scale: float) -> Texture2D:
	return _pixel_icon("star", [
		"....##....",
		"....##....",
		"...#oo#...",
		"####oo####",
		"#oooooooo#",
		".#oooooo#.",
		"..#oooo#..",
		"..#o##o#..",
		".#o#..#o#.",
		".##....##.",
	], {"#": Color8(140, 86, 18), "o": COLOR_GOLD}, texture_scale(ui_scale) + 1)


## Losango do título das janelas modernas.
static func diamond_icon(ui_scale: float) -> Texture2D:
	return _pixel_icon("diamond", [
		"...#...",
		"..#o#..",
		".#ooo#.",
		"#ooOoo#",
		".#ooo#.",
		"..#o#..",
		"...#...",
	], {"#": COLOR_GOLD_AGED, "o": COLOR_GOLD, "O": COLOR_GOLD_LIGHT}, texture_scale(ui_scale) + 1)


static func star_icon_rect(ui_scale: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = star_icon(ui_scale)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _pixel_icon(key: String, rows: Array, colors: Dictionary, factor: int) -> Texture2D:
	var cache_key: String = "%s@%d" % [key, factor]
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	var w: int = String(rows[0]).length()
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in mini(w, row.length()):
			var ch: String = row[x]
			if colors.has(ch):
				img.set_pixel(x, y, colors[ch])
	if factor > 1:
		img.resize(w * factor, rows.size() * factor, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[cache_key] = tex
	return tex
