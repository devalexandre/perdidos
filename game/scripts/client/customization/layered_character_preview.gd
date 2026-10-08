class_name LayeredCharacterPreview
extends Control
## Prévia 2D do personagem personalizado (GDD §6.1): corpo-base + roupa + olhos + cabelo + brincos com o shader de
## troca de paleta (CharacterLayers), animação idle (ou walk/sit), 8 direções com botões ◀ ▶ e ampliação
## inteira (pixels nítidos). Uso: set_appearance(dict); rotate_by(±1); set_anim(&"walk").

signal direction_changed(sector: int)

const FRAME_SEC: Dictionary[StringName, float] = {&"idle": 0.2, &"walk": 0.1, &"sit": 1.0}
const ROWS: int = 5
const DIRECTIONS: int = 8
const SHADOW_PATH: String = "res://assets/characters/chr_shadow.png"
const SHADOW_OPACITY: float = 0.5

## Mostra os botões de girar embaixo da prévia.
@export var show_rotate_buttons: bool = true
## Ampliação fixa (0 = maior inteiro que cabe).
@export var fixed_scale: int = 0

var appearance: Dictionary = {}
var anim: StringName = &"idle"
## Setor (0 = S, 1 = SE, 2 = L, 3 = NE, 4 = N, 5 = NO, 6 = O, 7 = SO), como o DirectionalSprite3D.
var sector: int = 0
var frame_scale: int = 1

var _stage: Control
var _shadow: Sprite2D
var _layers: Array[Dictionary] = []
var _time: float = 0.0
var _left: Button
var _right: Button
## Piscar (CharacterLayers.BLINK_*): folha do idle com o olho fechado e contadores.
var _blink_tex: Texture2D = null
var _blink_wait: float = 0.0
var _blink_left: float = 0.0


func _init() -> void:
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage = Control.new()
	_stage.name = &"Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_shadow = Sprite2D.new()
	_shadow.name = &"Shadow"
	_shadow.modulate = Color(1, 1, 1, SHADOW_OPACITY)
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(SHADOW_PATH):
		_shadow.texture = load(SHADOW_PATH) as Texture2D
	_stage.add_child(_shadow)
	_left = _arrow_button("◀", "CUSTOM_ROTATE_LEFT", -1)
	_right = _arrow_button("▶", "CUSTOM_ROTATE_RIGHT", 1)


func _ready() -> void:
	resized.connect(_layout)
	_left.visible = show_rotate_buttons
	_right.visible = show_rotate_buttons
	if appearance.is_empty():
		var o: CustomizationOptions = CustomizationOptions.get_default()
		if o != null:
			set_appearance(o.default_appearance(&"male"))
	_layout()


# --- API ------------------------------------------------------------------------------------------

func set_appearance(value: Dictionary) -> void:
	var rebuild: bool = _layer_signature(value) != _layer_signature(appearance)
	appearance = value.duplicate()
	if rebuild or _layers.is_empty():
		_rebuild()
	else:
		for l: Dictionary in _layers:
			CharacterLayers.update_material(l[&"sprite"].material, l[&"mode"], appearance)
	_update_frame()


func set_anim(value: StringName) -> void:
	anim = value
	_time = 0.0
	_update_frame()


func set_sector(value: int) -> void:
	sector = posmod(value, DIRECTIONS)
	_update_frame()
	direction_changed.emit(sector)


func rotate_by(step: int) -> void:
	set_sector(sector + step)


## Nomes das camadas desenhadas (de trás para frente), para testes.
func get_layer_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for l: Dictionary in _layers:
		out.append(l[&"name"])
	return out


# --- Interno --------------------------------------------------------------------------------------

func _arrow_button(text: String, tip_key: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tr(tip_key)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(rotate_by.bind(step))
	add_child(b)
	return b


static func _layer_signature(a: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [a.get(&"body", ""), a.get(&"hair_style", ""), a.get(&"earrings", ""), a.get(&"outfit", ""), a.get(&"title_look", ""), a.get(&"archetype", "")]


func _rebuild() -> void:
	for l: Dictionary in _layers:
		(l[&"sprite"] as Node).queue_free()
	_layers.clear()
	for spec: Dictionary in CharacterLayers.layer_specs(appearance):
		var textures: Dictionary[StringName, Texture2D] = {}
		var masks: Dictionary[StringName, Texture2D] = {}
		for a: StringName in spec[&"sheets"]:
			textures[a] = load(spec[&"sheets"][a]) as Texture2D
		for a: StringName in spec[&"masks"]:
			masks[a] = load(spec[&"masks"][a]) as Texture2D
		if textures.is_empty():
			continue
		var s := Sprite2D.new()
		s.name = spec[&"name"]
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.vframes = ROWS
		s.material = CharacterLayers.make_material(spec[&"mode"], appearance)
		_stage.add_child(s)
		_layers.append({&"name": spec[&"name"], &"mode": spec[&"mode"], &"sprite": s, &"textures": textures, &"masks": masks})
	var bp: String = CharacterLayers.eyes_blink_path(StringName(str(appearance.get(&"body", &"male"))))
	_blink_tex = load(bp) as Texture2D if bp != "" else null
	_blink_wait = CharacterLayers.next_blink_wait()
	_layout()


func _layout() -> void:
	var btn_h: float = 0.0
	if show_rotate_buttons:
		btn_h = maxf(_left.get_combined_minimum_size().y, _right.get_combined_minimum_size().y)
	var fh: int = _frame_px()
	var avail := Vector2(size.x, size.y - btn_h)
	frame_scale = fixed_scale if fixed_scale > 0 else maxi(1, int(floor(minf(avail.x, avail.y) / fh)))
	var box: float = fh * frame_scale
	_stage.position = Vector2(floorf((size.x - box) * 0.5), floorf((avail.y - box) * 0.5))
	_stage.size = Vector2(box, box)
	for l: Dictionary in _layers:
		(l[&"sprite"] as Sprite2D).scale = Vector2(frame_scale, frame_scale)
	if _shadow.texture != null:
		_shadow.scale = Vector2(frame_scale, frame_scale)
		_shadow.position = Vector2(box * 0.5, box - frame_scale * 2)
	if show_rotate_buttons:
		var y: float = size.y - btn_h
		_left.position = Vector2(_stage.position.x, y)
		_right.position = Vector2(_stage.position.x + box - _right.get_combined_minimum_size().x, y)


func _frame_px() -> int:
	for l: Dictionary in _layers:
		var t: Texture2D = (l[&"textures"] as Dictionary).get(&"idle")
		if t != null:
			return t.get_height() / ROWS
	return 96


func get_minimum_size_for_scale(k: int) -> Vector2:
	var btn_h: float = _left.get_combined_minimum_size().y if show_rotate_buttons else 0.0
	return Vector2(_frame_px() * k, _frame_px() * k + btn_h)


func _process(delta: float) -> void:
	_time += delta
	if _blink_left > 0.0:
		_blink_left -= delta
	else:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_left = CharacterLayers.BLINK_SEC
			_blink_wait = CharacterLayers.next_blink_wait()
	_update_frame()


## Duração do quadro: folhas do Viajante com mais quadros (idle 12...) seguem o ciclo do jogo
## (DirectionalSprite3D.TRAVELER_CYCLE_MS); as antigas, FRAME_SEC.
static func frame_sec(shown: StringName, frames: int) -> float:
	if frames > int(DirectionalSprite3D.TRAVELER_REF_FRAMES.get(shown, 1 << 30)):
		return float(DirectionalSprite3D.TRAVELER_CYCLE_MS[shown]) / 1000.0 / frames
	return FRAME_SEC.get(shown, 0.2)


## Olho fechado agora (piscar no idle).
func is_blinking() -> bool:
	return _blink_left > 0.0 and _blink_tex != null and anim == CharacterLayers.BLINK_ANIM


func _update_frame() -> void:
	var row: int = DirectionalSprite3D.sheet_row_for_sector(sector)
	for l: Dictionary in _layers:
		var s: Sprite2D = l[&"sprite"]
		var textures: Dictionary = l[&"textures"]
		var shown: StringName = anim if textures.has(anim) else &"idle"
		var tex: Texture2D = textures.get(shown)
		if l[&"name"] == CharacterLayers.LAYER_EYES and shown == CharacterLayers.BLINK_ANIM and is_blinking():
			tex = _blink_tex
		if tex == null:
			s.visible = false
			continue
		s.visible = true
		if s.texture != tex:
			s.texture = tex
			var fh: int = tex.get_height() / ROWS
			s.hframes = maxi(1, tex.get_width() / fh)
			var mask: Texture2D = (l[&"masks"] as Dictionary).get(shown)
			if mask != null:
				(s.material as ShaderMaterial).set_shader_parameter(&"mask_tex", mask)
		var frames: int = s.hframes
		var col: int = int(_time / frame_sec(shown, frames)) % frames
		s.frame = row * frames + col
		s.flip_h = DirectionalSprite3D.traveler_frame_mirrored(shown, col, sector)
