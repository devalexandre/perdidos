class_name HotbarSlot
extends PanelContainer
## Um espaço de skill (barra 1–0 e janela de skills): ícone (arte de W em assets/skills/ ou texto
## curto na cor da escola), tecla, quantidade e arrastar-e-soltar. Dados arrastados:
## {SKILL_DRAG_KEY: true, "entry": id, "from_slot": i}.
##
## Animação (GDD §8.1 "Tempo de uso na barra", 28/09/2026), tudo com tweens suaves e sem som de UI:
## - recarga: sombra radial girando no sentido horário + segundos restantes;
## - pronto: brilho pulsante na borda quando a recarga acaba;
## - conjuração: o espaço que conjura enche de baixo para cima; os outros ficam apagados;
## - tecla/clique: o espaço afunda e clareia; recusado (recarga/sem mana) treme;
## - poção: "pop" rápido (uso instantâneo, sem sombra);
## - sem mana: ícone tingido de azul.

signal activated(slot: HotbarSlot)
signal cleared(slot: HotbarSlot)
signal dropped(slot: HotbarSlot, data: Dictionary)

const SKILL_DRAG_KEY: String = "skill_drag"
const SKILL_ICON_DIR: String = "res://assets/skills/"
const SKILL_ICON_EXT: String = ".png"
## Cores do ícone de texto por escola (paleta mestra).
const SCHOOL_COLORS: Dictionary[StringName, Color] = {
	&"blade": Color8(230, 150, 70), &"arcane": Color8(120, 170, 240)}
const DEFAULT_SCHOOL_COLOR: Color = Color8(201, 176, 138)
const COOLDOWN_SHADE: Color = Color(0.03, 0.02, 0.06, 0.66)
## Linha clara na borda da sombra que gira.
const SWEEP_EDGE: Color = Color(1.0, 0.96, 0.8, 0.55)
const NO_MANA_TINT: Color = Color(0.45, 0.5, 0.85, 1.0)
const DISABLED_TINT: Color = Color(0.5, 0.5, 0.5, 1.0)
## Espaços apagados enquanto o jogador conjura.
const CASTING_DIM: Color = Color(0.55, 0.55, 0.6, 1.0)
## Enchimento do espaço que está conjurando (cor da barra de conjuração).
const CAST_FILL: Color = Color(0.98, 0.9, 0.55, 0.42)
const CAST_EDGE: Color = Color8(250, 229, 140)
## Brilho "pronto" (dourado da paleta).
const READY_GLOW: Color = Color8(250, 229, 140)
const POTION_FLASH: Color = Color(0.75, 1.0, 0.7, 0.55)
const DENY_FLASH: Color = Color(1.0, 0.45, 0.35, 0.45)
## Clarão branco ao apertar a tecla/clicar.
const PRESS_FLASH: Color = Color(1.0, 1.0, 0.92, 0.4)
const ICON_TEXT_FONT_PX: int = 13
const KEY_FONT_PX: int = 12
const COOLDOWN_FONT_PX: int = 14
## Mostra décimos de segundo abaixo disso.
const COOLDOWN_DECIMALS_BELOW_SEC: float = 1.0
## Transparência do ícone de texto enquanto os segundos da recarga aparecem por cima.
const COOLING_TEXT_ICON_ALPHA: float = 0.25
const MSEC_PER_SEC: float = 1000.0
## Recargas menores que isto não brilham ao terminar (evita piscar com recargas mínimas).
const MIN_GLOW_COOLDOWN_MS: float = 400.0
# Tempos das animações (s).
const PRESS_DOWN_SEC: float = 0.06
const PRESS_UP_SEC: float = 0.16
const PRESS_SCALE: float = 0.86
const POP_SCALE: float = 1.2
const POP_SEC: float = 0.22
const GLOW_SEC: float = 0.75
const GLOW_PULSES: int = 2
const GLOW_SCALE: float = 1.08
const DENY_SEC: float = 0.24
const DENY_SHAKE_PX: float = 3.0
const TINT_SEC: float = 0.18
const CAST_DIM_SEC: float = 0.15
const FLASH_FADE_SEC: float = 0.35

var ui_scale: float = 1.0
var index: int = -1
## skill_id ou item_id (consumível); &"" = vazio.
var entry_id: StringName = &""
## Pode ser arrastado (barra: move; janela de skills: copia) e aceita soltar?
var drag_enabled: bool = true
var accepts_drop: bool = true
## Janela de skills: seleciona ao SOLTAR o clique. Selecionar reconstrói a lista; no aperto, isso destruía
## o ícone antes do arrasto começar e não dava para arrastar a skill para a barra.
var activate_on_release: bool = false
var _press_pending: bool = false
## Quantas vezes o brilho "pronto" tocou (testes).
var ready_glows: int = 0

var _icon: TextureRect
var _text_icon: Label
var _key_label: Label
var _qty_label: Label
var _fx: SlotFx
var _cd_label: Label
var _cd_end_msec: float = 0.0
var _cd_total_msec: float = 0.0
var _was_cooling: bool = false
var _has_mana: bool = true
var _enabled: bool = true
var _dimmed: bool = false
var _scale_tween: Tween
var _mod_tween: Tween
var _tint_tween: Tween
var _glow_tween: Tween
var _flash_tween: Tween


## Camada de efeitos desenhada por cima do ícone: sombra radial, enchimento da conjuração, brilho.
class SlotFx extends Control:
	## Fração da recarga que falta (0 = pronto, 1 = acabou de começar).
	var cooldown_frac: float = 0.0:
		set(v):
			cooldown_frac = v
			queue_redraw()
	## Progresso da conjuração neste espaço (<0 = não conjura).
	var cast_frac: float = -1.0:
		set(v):
			cast_frac = v
			queue_redraw()
	## Brilho da borda (0..1).
	var glow: float = 0.0:
		set(v):
			glow = v
			queue_redraw()
	var flash_color: Color = Color.TRANSPARENT:
		set(v):
			flash_color = v
			queue_redraw()
	var border_px: float = 2.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if cast_frac >= 0.0:
			var h: float = size.y * clampf(cast_frac, 0.0, 1.0)
			draw_rect(Rect2(0.0, size.y - h, size.x, h), CAST_FILL)
			draw_rect(Rect2(0.0, size.y - h, size.x, maxf(1.0, border_px * 0.5)), CAST_EDGE)
			draw_rect(r, CAST_EDGE, false, border_px)
		if cooldown_frac > 0.0:
			_draw_sweep(cooldown_frac)
		if flash_color.a > 0.0:
			draw_rect(r, flash_color)
		if glow > 0.0:
			var c: Color = READY_GLOW
			c.a = glow
			draw_rect(r, c, false, border_px * 1.5)
			var soft: Color = READY_GLOW
			soft.a = glow * 0.22
			draw_rect(r.grow(-border_px * 1.5), soft)

	## Sombra do tempo que falta: do ângulo atual até o topo, no sentido horário (clareia girando).
	func _draw_sweep(frac: float) -> void:
		var c: Vector2 = size * 0.5
		var start: float = TAU * (1.0 - frac)   # 0 = topo; cresce no sentido horário
		var angles: Array[float] = [start]
		for k: int in 4:
			var corner: float = TAU * (0.125 + 0.25 * k)
			if corner > start:
				angles.append(corner)
		angles.append(TAU)
		var pts := PackedVector2Array([c])
		for a: float in angles:
			pts.append(_edge_point(a))
		draw_colored_polygon(pts, COOLDOWN_SHADE)
		draw_line(c, _edge_point(start), SWEEP_EDGE, maxf(1.0, border_px * 0.5))

	## Ponto na borda do retângulo na direção a (0 = topo, sentido horário).
	func _edge_point(a: float) -> Vector2:
		var c: Vector2 = size * 0.5
		var d := Vector2(sin(a), -cos(a))
		var tx: float = INF if absf(d.x) < 0.0001 else c.x / absf(d.x)
		var ty: float = INF if absf(d.y) < 0.0001 else c.y / absf(d.y)
		return c + d * minf(tx, ty)


func _init(p_scale: float = 1.0, p_index: int = -1, key_text: String = "") -> void:
	ui_scale = p_scale
	index = p_index
	mouse_filter = Control.MOUSE_FILTER_STOP
	var s: int = ItemSlot.slot_pixels(ui_scale)
	custom_minimum_size = Vector2(s, s)
	add_theme_stylebox_override(&"panel", UIKit.slot_box(ui_scale, false))
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_text_icon = _label(ICON_TEXT_FONT_PX, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	add_child(_text_icon)
	_fx = SlotFx.new()
	_fx.name = &"Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.border_px = maxf(1.0, UIKit.px(UIKit.BORDER, ui_scale))
	add_child(_fx)
	_cd_label = _label(COOLDOWN_FONT_PX, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_cd_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	add_child(_cd_label)
	_key_label = _label(KEY_FONT_PX, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_key_label.text = key_text
	_key_label.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	add_child(_key_label)
	_qty_label = _label(KEY_FONT_PX, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_qty_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	add_child(_qty_label)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## Troca o rótulo do canto (tecla ou botão do controle).
func set_key_text(text: String) -> void:
	_key_label.text = text
	# "RT+X" não cabe no tamanho das teclas: fonte menor para rótulos longos.
	if text.length() > 2:
		_key_label.add_theme_font_size_override(&"font_size", UIKit.px(KEY_FONT_PX - 3, ui_scale))
	else:
		_key_label.add_theme_font_size_override(&"font_size", UIKit.px(KEY_FONT_PX, ui_scale))


func _label(font_px: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", UIKit.px(font_px, ui_scale))
	l.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	l.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	return l


# ---------------------------------------------------------------- ícones (compartilhado)

static func skill_icon(def: SkillDef) -> Texture2D:
	if def == null:
		return null
	if def.icon != null:
		return def.icon
	var path: String = SKILL_ICON_DIR + String(def.id) + SKILL_ICON_EXT
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func skill_icon_text(def: SkillDef) -> String:
	if def == null:
		return ""
	return def.icon_text if not def.icon_text.is_empty() \
			else TranslationServer.translate(def.name_key).left(2).to_upper()


static func school_color(def: SkillDef) -> Color:
	return SCHOOL_COLORS.get(def.school, DEFAULT_SCHOOL_COLOR) if def != null else DEFAULT_SCHOOL_COLOR


## Nome traduzido de uma entrada da barra (skill ou item).
static func entry_name(entry: StringName) -> String:
	var sd: SkillDef = Content.skill(entry)
	if sd != null:
		return TranslationServer.translate(sd.name_key)
	var item: ItemDef = UIKit.item(entry)
	return UIKit.item_name(item) if item != null else ""


# ---------------------------------------------------------------- estado

func set_entry(p_entry: StringName, qty: int = 0) -> void:
	if p_entry != entry_id:
		# Outra coisa no espaço: a recarga/brilho anteriores não valem para ela.
		_was_cooling = false
		_cd_end_msec = 0.0
		_fx.glow = 0.0
	entry_id = p_entry
	_icon.texture = null
	_text_icon.text = ""
	_qty_label.text = ""
	tooltip_text = ""
	var sd: SkillDef = Content.skill(entry_id)
	if sd != null:
		_icon.texture = skill_icon(sd)
		if _icon.texture == null:
			_text_icon.text = skill_icon_text(sd)
			_text_icon.add_theme_color_override(&"font_color", school_color(sd))
		tooltip_text = TranslationServer.translate(sd.name_key) + "\n" + TranslationServer.translate(sd.desc_key)
		return
	var item: ItemDef = UIKit.item(entry_id)
	if item != null:
		_icon.texture = UIKit.item_icon(item)
		if _icon.texture == null:
			_text_icon.text = UIKit.item_name(item).left(3)
			_text_icon.add_theme_color_override(&"font_color", UIKit.rarity_color(item))
		_qty_label.text = str(qty)
		tooltip_text = UIKit.item_tooltip_text(item, qty, false)


func is_empty() -> bool:
	return entry_id.is_empty()


## Recarga: termina em end_msec (relógio local), de um total de total_msec.
func set_cooldown(end_msec: float, total_msec: float) -> void:
	_cd_end_msec = end_msec
	_cd_total_msec = maxf(total_msec, 1.0)
	_update_cooldown()


## Fração da recarga que falta (0 = pronto).
func cooldown_fraction() -> float:
	return _fx.cooldown_frac


func set_usable(has_mana: bool, enabled: bool = true) -> void:
	if has_mana == _has_mana and enabled == _enabled:
		return
	_has_mana = has_mana
	_enabled = enabled
	var tint: Color = Color.WHITE
	if not enabled:
		tint = DISABLED_TINT
	elif not has_mana:
		tint = NO_MANA_TINT
	if _tint_tween != null:
		_tint_tween.kill()
	if not is_inside_tree():
		_icon.modulate = tint
		_text_icon.modulate = tint
		return
	_tint_tween = create_tween().set_parallel(true)
	_tint_tween.tween_property(_icon, "modulate", tint, TINT_SEC)
	_tint_tween.tween_property(_text_icon, "modulate", tint, TINT_SEC)


func has_mana() -> bool:
	return _has_mana


## Conjurando: os outros espaços ficam apagados; o que conjura enche de baixo para cima.
## own_frac < 0 = este espaço não conjura.
func set_casting(dim: bool, own_frac: float = -1.0) -> void:
	_fx.cast_frac = own_frac
	var want_dim: bool = dim and own_frac < 0.0
	if want_dim == _dimmed:
		return
	_dimmed = want_dim
	if _mod_tween != null:
		_mod_tween.kill()
	if not is_inside_tree():
		modulate = CASTING_DIM if want_dim else Color.WHITE
		return
	_mod_tween = create_tween()
	_mod_tween.tween_property(self, "modulate", CASTING_DIM if want_dim else Color.WHITE, CAST_DIM_SEC)


func is_dimmed() -> bool:
	return _dimmed


func is_cooling_down() -> bool:
	return Time.get_ticks_msec() < _cd_end_msec


func _process(_delta: float) -> void:
	if _fx.cooldown_frac > 0.0 or is_cooling_down():
		_update_cooldown()


func _update_cooldown() -> void:
	var left: float = _cd_end_msec - Time.get_ticks_msec()
	if left <= 0.0:
		if _was_cooling and _cd_total_msec >= MIN_GLOW_COOLDOWN_MS and not is_empty():
			ready_glow()
		_was_cooling = false
		_fx.cooldown_frac = 0.0
		_cd_label.text = ""
		_text_icon.self_modulate.a = 1.0
		return
	_was_cooling = true
	_fx.cooldown_frac = clampf(left / _cd_total_msec, 0.0, 1.0)
	# Os segundos ficam por cima; o ícone de texto (sem arte) some para não embolar com eles.
	_text_icon.self_modulate.a = COOLING_TEXT_ICON_ALPHA
	var sec: float = left / MSEC_PER_SEC
	_cd_label.text = ("%.1f" % (ceilf(sec * 10.0) / 10.0)).replace(".", ",") if sec < COOLDOWN_DECIMALS_BELOW_SEC \
			else str(ceili(sec))


# ---------------------------------------------------------------- animações (sem som de UI)

func _scale_to(values: Array, times: Array, trans: Tween.TransitionType = Tween.TRANS_QUAD) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	_scale_tween = create_tween()
	for i: int in values.size():
		_scale_tween.tween_property(self, "scale", Vector2.ONE * float(values[i]), float(times[i])) \
				.set_trans(trans).set_ease(Tween.EASE_OUT)


func _flash(color: Color, fade_sec: float = FLASH_FADE_SEC) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if not is_inside_tree():
		return
	_fx.flash_color = color
	var clear := Color(color, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fx, "flash_color", clear, fade_sec)


## Tecla/clique: afunda e clareia rapidinho.
func press() -> void:
	_scale_to([PRESS_SCALE, 1.0], [PRESS_DOWN_SEC, PRESS_UP_SEC], Tween.TRANS_BACK)
	_flash(PRESS_FLASH, PRESS_UP_SEC)


## Uso instantâneo (poção): "pop" rápido, sem sombra de recarga.
func pop() -> void:
	_scale_to([POP_SCALE, 1.0], [POP_SEC * 0.35, POP_SEC * 0.65], Tween.TRANS_BACK)
	_flash(POTION_FLASH, POP_SEC * 1.5)


## Recusado (recarga, sem mana): treme de leve e pisca em vermelho.
func deny() -> void:
	if not is_inside_tree():
		return
	_flash(DENY_FLASH, DENY_SEC)
	var tw: Tween = create_tween()
	var base: Vector2 = position
	var d: float = UIKit.px(DENY_SHAKE_PX, ui_scale)
	for k: int in 4:
		tw.tween_property(self, "position:x", base.x + (d if k % 2 == 0 else -d), DENY_SEC / 5.0)
	tw.tween_property(self, "position:x", base.x, DENY_SEC / 5.0)


## Recarga terminou: brilho pulsante na borda + pulso de escala.
func ready_glow() -> void:
	ready_glows += 1
	if _glow_tween != null:
		_glow_tween.kill()
	if not is_inside_tree():
		return
	_glow_tween = create_tween()
	for k: int in GLOW_PULSES:
		_glow_tween.tween_property(_fx, "glow", 1.0, GLOW_SEC * 0.25).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(_fx, "glow", 0.0, GLOW_SEC * 0.25).set_trans(Tween.TRANS_SINE)
	_scale_to([GLOW_SCALE, 1.0], [GLOW_SEC * 0.2, GLOW_SEC * 0.3], Tween.TRANS_SINE)


func glow_amount() -> float:
	return _fx.glow


# ---------------------------------------------------------------- entrada

func _gui_input(event: InputEvent) -> void:
	if activate_on_release and event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pending = not is_empty()
			accept_event() # o clique não pode atravessar para o mundo (o personagem andava)
		elif _press_pending:
			_press_pending = false
			activated.emit(self)
			accept_event()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not is_empty():
			activated.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not is_empty():
			cleared.emit(self)
			accept_event()
	elif event is InputEventScreenTouch and event.pressed and not is_empty():
		activated.emit(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty() or not drag_enabled:
		return null
	_press_pending = false
	var s: int = ItemSlot.slot_pixels(ui_scale)
	if _icon.texture != null:
		var tr_preview := TextureRect.new()
		tr_preview.texture = _icon.texture
		tr_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_preview.custom_minimum_size = Vector2(s, s)
		tr_preview.size = Vector2(s, s)
		tr_preview.modulate.a = 0.85
		set_drag_preview(tr_preview)
	else:
		var preview := Label.new()
		preview.text = _text_icon.text
		preview.add_theme_color_override(&"font_color", _text_icon.get_theme_color(&"font_color"))
		preview.add_theme_font_size_override(&"font_size", UIKit.px(ICON_TEXT_FONT_PX, ui_scale))
		preview.custom_minimum_size = Vector2(s, s)
		set_drag_preview(preview)
	return {SKILL_DRAG_KEY: true, "entry": entry_id, "from_slot": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not accepts_drop or not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.has(SKILL_DRAG_KEY):
		return true
	# Consumível ou equipamento arrastado do inventário (equipamento: usar na barra veste/troca).
	if d.has(ItemSlot.DRAG_KEY) and StringName(d.get("source", &"")) == ItemSlot.SOURCE_INVENTORY:
		var item: ItemDef = UIKit.item(StringName(d.get("item", &"")))
		return item != null and item.is_hotbar_item()
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(self, data as Dictionary)
