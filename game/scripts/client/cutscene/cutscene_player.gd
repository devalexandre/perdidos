class_name CutscenePlayer
extends Control
## Cinemática em ilustrações (GDD §9.3): lista de planos em JSON (imagem por corpo, pan/zoom,
## transições, partículas, brilho, legendas por chave de tradução, efeitos e música por nome).
## Dirigida pelo tempo em _process (sem corrotinas), então pular/liberar a qualquer momento é seguro.
## Pulável: Esc (ui_cancel) pula na hora; clique/toque mostra o botão "Pular" em destaque.
## Emite finished(skipped) uma única vez; quem criou decide liberar o nó.
## Uso rápido (sobreposição em cima de tudo, ex.: "Rever abertura"): CutscenePlayer.play_overlay(tree, body).

signal finished(skipped: bool)

const ARRIVAL_SCENE: String = "res://scenes/cutscenes/arrival.tscn"
const BODIES: Array[StringName] = [&"male", &"female"]
const DEFAULT_BODY: StringName = &"male"
const BODY_TOKEN: String = "{body}"
## Resolução nativa das ilustrações (GDD §17.2).
const ART_SIZE: Vector2 = Vector2(960, 540)
const OVERLAY_LAYER: int = 120
const CAPTION_FADE_SEC: float = 0.45
const CAPTION_BOTTOM_FRACTION: float = 0.1
const CAPTION_FONT_PX: int = 26
const CAPTION_OUTLINE_PX: int = 6
const CAPTION_COLOR: Color = Color8(252, 250, 245)
const CAPTION_OUTLINE: Color = Color8(22, 19, 28, 220)
const SKIP_FADE_SEC: float = 0.35
const SKIP_IDLE_ALPHA: float = 0.45
const SKIP_HOT_SEC: float = 3.0
const SKIP_MARGIN_PX: float = 16.0
const FADE_COLORS: Dictionary[String, Color] = {
	"black": Color(0, 0, 0), "white": Color(1, 0.98, 0.93), "gold": Color(1, 0.84, 0.45)}
const PETAL_TEXTURE: String = "res://assets/ui/title/petal.png"
const GLOW_PULSE_HZ: float = 0.6
const GLOW_PULSE_AMOUNT: float = 0.15
const PARTICLE_KINDS: Array[String] = ["petals", "stars_rise", "fireflies", "motes"]

## JSON da cinemática (ver o _doc dentro do arquivo).
@export_file("*.json") var shots_path: String = "res://assets/cutscenes/arrival/shots.json"
## Corpo escolhido na criação (male/female): escolhe a variante das ilustrações.
@export var body: StringName = DEFAULT_BODY
## Começa sozinho ao entrar na árvore.
@export var autoplay: bool = true
## Toca música/efeitos pelo AudioDirector (desligar em testes).
@export var use_audio: bool = true
## Velocidade do tempo (testes).
var speed: float = 1.0

var time: float = 0.0
var total_duration: float = 0.0
var current_shot: int = -1
var playing: bool = false
var done: bool = false

var _shots: Array = []
var _starts: PackedFloat32Array = PackedFloat32Array()
var _music: Array = []
var _voice: AudioStreamPlayer = null
const VOICE_DIR: String = "res://assets/cutscenes/arrival/voice/"
const VOICE_FALLBACK_LOCALE: String = "pt_BR"
const VOICE_BUS: StringName = &"SFX"
var _end_fade: float = 1.5
var _images: Dictionary[String, Texture2D] = {}
var _front: TextureRect
var _back: TextureRect
var _glow: TextureRect
var _fade: ColorRect
var _caption: Label
var _caption_band: TextureRect
var _skip: Button
var _particles: Dictionary[String, CPUParticles2D] = {}
var _fired: Dictionary[String, bool] = {}
var _skip_hot: float = 0.0
var _skipping: float = -1.0
var _audio_owned: AudioDirector = null
var _prev_music: AudioStream = null
var _scale: float = 1.0


## Sobreposição global (CanvasLayer na raiz) que se libera sozinha ao terminar.
static func play_overlay(tree: SceneTree, p_body: StringName) -> CutscenePlayer:
	if tree == null or not ResourceLoader.exists(ARRIVAL_SCENE):
		return null
	var layer := CanvasLayer.new()
	layer.name = &"CutsceneOverlay"
	layer.layer = OVERLAY_LAYER
	var player: CutscenePlayer = (load(ARRIVAL_SCENE) as PackedScene).instantiate() as CutscenePlayer
	player.body = p_body
	layer.add_child(player)
	tree.root.add_child(layer)
	player.finished.connect(func(_s: bool) -> void: layer.queue_free())
	return player


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_shots()
	_build()
	resized.connect(_layout)
	_layout()
	if autoplay:
		play()


# --- API ------------------------------------------------------------------------------------------

func play() -> void:
	if _shots.is_empty():
		_finish(false)
		return
	playing = true
	time = 0.0
	if use_audio:
		_start_music()
	_update(0.0)


## Pula para o fim (fade curto para preto e finished(true)).
func skip() -> void:
	if done or _skipping >= 0.0:
		return
	_skipping = 0.0


## Vai direto para um instante (testes e capturas).
func seek(t: float) -> void:
	time = clampf(t, 0.0, total_duration)
	_update(0.0)


## Um instante representativo de cada plano (meio da última legenda; testes/capturas).
func shot_midpoints() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in _shots.size():
		var caps: Array = _shots[i].get("captions", [])
		var local: float = float(_shots[i].get("duration", 1.0)) * 0.6
		if not caps.is_empty():
			local = float(caps[-1].get("at", 0.0)) + float(caps[-1].get("dur", 0.0)) * 0.5
		out.append(_starts[i] + local)
	return out


func shot_count() -> int:
	return _shots.size()


# --- Montagem -------------------------------------------------------------------------------------

func _load_shots() -> void:
	if not BODIES.has(body):
		body = DEFAULT_BODY
	var res: Resource = load(shots_path) if ResourceLoader.exists(shots_path) else null
	var data: Variant = (res as JSON).data if res is JSON else null
	if not data is Dictionary:
		push_error("Cutscene data missing/invalid: %s" % shots_path)
		return
	var d: Dictionary = data
	_shots = d.get("shots", [])
	_music = d.get("music", [])
	_end_fade = float(d.get("end_fade_sec", _end_fade))
	var t: float = 0.0
	for s: Dictionary in _shots:
		_starts.append(t)
		t += float(s.get("duration", 1.0))
	total_duration = t
	var dir: String = shots_path.get_base_dir() + "/"
	for s: Dictionary in _shots:
		var img: String = String(s.get("image", ""))
		if img.is_empty() or _images.has(img):
			continue
		var path: String = dir + img.replace(BODY_TOKEN, String(body))
		if not ResourceLoader.exists(path):
			path = dir + img.replace(BODY_TOKEN, String(DEFAULT_BODY))
		if ResourceLoader.exists(path):
			_images[img] = load(path) as Texture2D


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_back = _image_rect(&"Back")
	_front = _image_rect(&"Front")
	_glow = TextureRect.new()
	_glow.name = &"Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.texture = _radial_texture()
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.visible = false
	add_child(_glow)
	for kind: String in PARTICLE_KINDS:
		var p: CPUParticles2D = _make_particles(kind)
		p.emitting = false
		p.visible = false
		add_child(p)
		_particles[kind] = p
	_fade = ColorRect.new()
	_fade.name = &"Fade"
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	add_child(_fade)
	# Faixa escura suave atrás da legenda (legível sobre céus claros).
	_caption_band = TextureRect.new()
	_caption_band.name = &"CaptionBand"
	_caption_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_caption_band.stretch_mode = TextureRect.STRETCH_SCALE
	_caption_band.texture = _band_texture()
	_caption_band.modulate.a = 0.0
	add_child(_caption_band)
	_caption = Label.new()
	_caption.name = &"Caption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	var font: Font = UIKit.font()
	if font != null:
		_caption.add_theme_font_override(&"font", font)
	_caption.add_theme_color_override(&"font_color", CAPTION_COLOR)
	_caption.add_theme_color_override(&"font_outline_color", CAPTION_OUTLINE)
	add_child(_caption)
	_skip = Button.new()
	_skip.name = &"Skip"
	_skip.text = tr("CUTSCENE_SKIP") + "  ▸"
	_skip.tooltip_text = tr("CUTSCENE_SKIP_HINT")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.modulate.a = SKIP_IDLE_ALPHA
	_skip.pressed.connect(skip)
	add_child(_skip)


func _image_rect(n: StringName) -> TextureRect:
	var r := TextureRect.new()
	r.name = n
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.visible = false
	add_child(r)
	return r


func _layout() -> void:
	var sz: Vector2 = size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_scale = maxf(sz.x / ART_SIZE.x, sz.y / ART_SIZE.y)
	var ui: float = UIKit.scale_for(sz)
	_caption.add_theme_font_size_override(&"font_size", roundi(CAPTION_FONT_PX * ui))
	_caption.add_theme_constant_override(&"outline_size", roundi(CAPTION_OUTLINE_PX * ui))
	var cap_h: float = sz.y * 0.16
	_caption.position = Vector2(sz.x * 0.1, sz.y * (1.0 - CAPTION_BOTTOM_FRACTION) - cap_h)
	_caption.size = Vector2(sz.x * 0.8, cap_h)
	_caption_band.position = Vector2(0, _caption.position.y - cap_h * 0.3)
	_caption_band.size = Vector2(sz.x, sz.y - _caption_band.position.y)
	_caption.add_theme_constant_override(&"shadow_offset_x", roundi(2 * ui))
	_caption.add_theme_constant_override(&"shadow_offset_y", roundi(2 * ui))
	_caption.add_theme_color_override(&"font_shadow_color", CAPTION_OUTLINE)
	_skip.theme = UIKit.build_theme(ui)
	_skip.reset_size()
	var m: float = SKIP_MARGIN_PX * ui
	_skip.position = sz - _skip.get_combined_minimum_size() - Vector2(m, m)
	var tex_px: int = maxi(1, roundi(_scale))
	for kind: String in _particles:
		var p: CPUParticles2D = _particles[kind]
		p.scale = Vector2(tex_px, tex_px)
		_place_emitter(kind, p, sz)
	_update(0.0)


# --- Laço -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if done:
		return
	_skip_hot = maxf(0.0, _skip_hot - delta)
	_skip.modulate.a = 1.0 if (_skip_hot > 0.0 or _skip.is_hovered()) else SKIP_IDLE_ALPHA
	if _skipping >= 0.0:
		_skipping += delta
		_fade.color = Color(0, 0, 0, maxf(_fade.color.a, clampf(_skipping / SKIP_FADE_SEC, 0.0, 1.0)))
		_caption.modulate.a = maxf(0.0, _caption.modulate.a - delta / SKIP_FADE_SEC)
		_caption_band.modulate.a = _caption.modulate.a
		if _skipping >= SKIP_FADE_SEC:
			_finish(true)
		return
	if not playing:
		return
	time += delta * speed
	_update(delta * speed)
	if time >= total_duration:
		_finish(false)


func _input(event: InputEvent) -> void:
	if done or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		# Controle: B (ui_cancel) pula; os outros botões não vazam para o jogo por baixo.
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		_skip_hot = SKIP_HOT_SEC
		accept_event()


func _update(dt: float) -> void:
	if _shots.is_empty() or _front == null:
		return
	var i: int = _shot_index(time)
	if i != current_shot:
		_enter_shot(i)
	var s: Dictionary = _shots[i]
	var local: float = time - _starts[i]
	var dur: float = float(s.get("duration", 1.0))
	var k: float = clampf(local / maxf(dur, 0.001), 0.0, 1.0)
	var eased: float = ease(k, -1.6)
	_place_image(_front, s, eased)
	# Transição de entrada.
	var in_kind: String = String(s.get("in", "cut"))
	var in_sec: float = float(s.get("in_sec", 0.0))
	var fade_a: float = 0.0
	var fade_c: Color = Color.BLACK
	_back.visible = false
	if in_kind == "crossfade" and in_sec > 0.0 and local < in_sec and i > 0:
		var prev: Dictionary = _shots[i - 1]
		var pk: float = clampf((_starts[i] - _starts[i - 1] + local) / float(prev.get("duration", 1.0)), 0.0, 1.0)
		_back.visible = _back.texture != null
		_place_image(_back, prev, ease(pk, -1.6))
		_front.modulate.a = clampf(local / in_sec, 0.0, 1.0)
	else:
		_front.modulate.a = 1.0
		if FADE_COLORS.has(in_kind) and in_sec > 0.0 and local < in_sec:
			fade_c = FADE_COLORS[in_kind]
			fade_a = 1.0 - clampf(local / in_sec, 0.0, 1.0)
	# Transição de saída (e o fade final da cinemática).
	var out_kind: String = String(s.get("out", ""))
	var out_sec: float = float(s.get("out_sec", 0.0))
	if i == _shots.size() - 1 and out_kind.is_empty():
		out_kind = "black"
		out_sec = _end_fade
	if FADE_COLORS.has(out_kind) and out_sec > 0.0 and local > dur - out_sec:
		var oa: float = clampf((local - (dur - out_sec)) / out_sec, 0.0, 1.0)
		if oa > fade_a:
			fade_a = oa
			fade_c = FADE_COLORS[out_kind]
	if String(s.get("image", "")).is_empty():
		fade_a = 0.0
	fade_c.a = fade_a
	_fade.color = fade_c
	_update_glow(s, local, eased)
	_update_captions(s, local)
	_update_cues(i, s, local)


func _shot_index(t: float) -> int:
	for i: int in range(_shots.size() - 1, -1, -1):
		if t >= _starts[i]:
			return i
	return 0


func _enter_shot(i: int) -> void:
	current_shot = i
	var s: Dictionary = _shots[i]
	_back.texture = _front.texture
	var img: String = String(s.get("image", ""))
	_front.texture = _images.get(img, null)
	_front.visible = _front.texture != null
	var kind: String = String(s.get("particles", ""))
	for pk: String in _particles:
		var p: CPUParticles2D = _particles[pk]
		var on: bool = pk == kind
		if on and not p.emitting:
			p.visible = true
			p.restart()
			p.emitting = true
		elif not on and p.emitting:
			p.emitting = false
			p.visible = false


func _place_image(r: TextureRect, s: Dictionary, k: float) -> void:
	if r.texture == null:
		return
	var zoom: Array = s.get("zoom", [1.0, 1.0])
	var z: float = lerpf(float(zoom[0]), float(zoom[1]), k)
	var focus: Array = s.get("focus", [[0.5, 0.5], [0.5, 0.5]])
	var f: Vector2 = _vec(focus[0]).lerp(_vec(focus[1]), k)
	var tex_size: Vector2 = ART_SIZE * _scale * maxf(z, 1.0)
	var pos: Vector2 = size * 0.5 - f * tex_size
	pos.x = clampf(pos.x, size.x - tex_size.x, 0.0)
	pos.y = clampf(pos.y, size.y - tex_size.y, 0.0)
	r.position = pos.round()
	r.size = tex_size.round()


## [x, y] ou {"male": [x, y], "female": [x, y]}.
func _vec(v: Variant) -> Vector2:
	if v is Dictionary:
		v = (v as Dictionary).get(String(body), (v as Dictionary).get(String(DEFAULT_BODY), [0.5, 0.5]))
	var a: Array = v
	return Vector2(float(a[0]), float(a[1]))


func _update_glow(s: Dictionary, local: float, k: float) -> void:
	var g: Variant = s.get("glow", null)
	if not g is Dictionary or not _front.visible:
		_glow.visible = false
		return
	var gd: Dictionary = g
	var p: Vector2 = _vec(gd.get("pos", [0.5, 0.5]))
	var c: Array = gd.get("color", [1, 0.8, 0.4, 0.8])
	var grow: float = lerpf(1.0, float(gd.get("grow", 1.0)), k * k)
	var pulse: float = 1.0 + sin(local * TAU * GLOW_PULSE_HZ) * GLOW_PULSE_AMOUNT
	var radius: float = float(gd.get("radius", 0.06)) * _front.size.x * grow * pulse
	_glow.visible = true
	_glow.size = Vector2(radius, radius) * 2.0
	_glow.position = _front.position + p * _front.size - Vector2(radius, radius)
	_glow.modulate = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) * _front.modulate.a)


func _update_captions(s: Dictionary, local: float) -> void:
	var alpha: float = 0.0
	var key: String = ""
	for c: Dictionary in s.get("captions", []):
		var at: float = float(c.get("at", 0.0))
		var dur: float = float(c.get("dur", 2.0))
		if local >= at and local <= at + dur:
			key = String(c.get("key", ""))
			alpha = minf(clampf((local - at) / CAPTION_FADE_SEC, 0.0, 1.0),
					clampf((at + dur - local) / CAPTION_FADE_SEC, 0.0, 1.0))
			break
	if not key.is_empty():
		_caption.text = tr(key)
		_play_voice(key)
	_caption.modulate.a = alpha
	_caption_band.modulate.a = alpha


## Narração: uma fala por legenda, no idioma atual (assets/cutscenes/arrival/voice/<idioma>/<CHAVE>.ogg);
## se o idioma não tiver narração, usa pt_BR. Gerada por tools/audio/narration.py.
func _play_voice(key: String) -> void:
	if not use_audio or _fired.has("v:" + key):
		return
	_fired["v:" + key] = true
	var stream: AudioStream = null
	for lang: String in [TranslationServer.get_locale(), TranslationServer.get_locale().get_slice("_", 0), VOICE_FALLBACK_LOCALE]:
		var path: String = "%s%s/%s.ogg" % [VOICE_DIR, lang, key]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		return
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		_voice.name = &"Narration"
		_voice.bus = VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) >= 0 else &"Master"
		add_child(_voice)
	_voice.stream = stream
	_voice.play()


func _update_cues(i: int, s: Dictionary, local: float) -> void:
	for c: Dictionary in s.get("sfx", []):
		var id: String = "%d:%s" % [i, c.get("name", "")]
		if _fired.has(id) or local < float(c.get("at", 0.0)):
			continue
		_fired[id] = true
		if use_audio:
			AudioDirector.play_sfx(StringName(c.get("name", "")))


func _finish(skipped: bool) -> void:
	if done:
		return
	if _voice != null:
		_voice.stop()
	done = true
	playing = false
	_fade.color = Color(0, 0, 0, 1)
	_caption.modulate.a = 0.0
	_caption_band.modulate.a = 0.0
	for p: CPUParticles2D in _particles.values():
		p.emitting = false
	if use_audio:
		_stop_music()
	finished.emit(skipped)


# --- Áudio ----------------------------------------------------------------------------------------

func _start_music() -> void:
	if AudioDirector.instance == null:
		_audio_owned = AudioDirector.new()
		_audio_owned.name = &"AudioDirector"
		add_child(_audio_owned)
	else:
		_prev_music = AudioDirector.instance.current_music
	var dir: AudioDirector = AudioDirector.instance
	if dir == null:
		return
	for m: Variant in _music:
		var stream: AudioStream = dir.load_music(StringName(m))
		if stream != null:
			dir.play_music(stream)
			return


func _stop_music() -> void:
	# Quem já tinha música (ex.: "Rever abertura" dentro do jogo) volta para ela.
	if _audio_owned == null and AudioDirector.instance != null:
		AudioDirector.instance.play_music(_prev_music)


# --- Partículas -----------------------------------------------------------------------------------

func _make_particles(kind: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = StringName("Particles_" + kind)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	match kind:
		"petals":
			p.texture = load(PETAL_TEXTURE) as Texture2D if ResourceLoader.exists(PETAL_TEXTURE) else _dot_texture(3)
			p.amount = 36
			p.lifetime = 10.0
			p.preprocess = 10.0
			p.direction = Vector2(0.4, 1)
			p.spread = 30.0
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 45.0
			p.gravity = Vector2(8, 10)
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
		"stars_rise":
			p.texture = _dot_texture(1)
			p.amount = 90
			p.lifetime = 2.2
			p.preprocess = 2.2
			p.direction = Vector2(0, -1)
			p.spread = 4.0
			p.initial_velocity_min = 180.0
			p.initial_velocity_max = 340.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.0
			p.scale_amount_max = 3.0
			p.color = Color(1, 0.95, 0.85, 0.85)
		"fireflies":
			p.texture = _dot_texture(1)
			p.amount = 26
			p.lifetime = 5.0
			p.preprocess = 5.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector2(0, -1.5)
			p.color_ramp = _twinkle_ramp(Color(0.95, 1.0, 0.55))
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
		"motes":
			p.texture = _dot_texture(1)
			p.amount = 30
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.direction = Vector2(0, 1)
			p.spread = 180.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.0
			p.gravity = Vector2.ZERO
			p.color_ramp = _twinkle_ramp(Color(1.0, 0.9, 0.6))
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
	return p


## Área de emissão em coordenadas da partícula (o nó é escalado por _scale).
func _place_emitter(kind: String, p: CPUParticles2D, sz: Vector2) -> void:
	var local: Vector2 = sz / p.scale
	match kind:
		"petals":
			p.position = Vector2(sz.x * 0.4, -16)
			p.emission_rect_extents = Vector2(local.x * 0.6, 4)
		"stars_rise":
			p.position = Vector2(sz.x * 0.5, sz.y + 8)
			p.emission_rect_extents = Vector2(local.x * 0.5, 4)
		_:
			p.position = sz * 0.5
			p.emission_rect_extents = local * Vector2(0.45, 0.4)


static func _dot_texture(px: int) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _twinkle_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c, 0.0))
	g.set_color(1, Color(c, 0.0))
	g.add_point(0.3, Color(c, 1.0))
	g.add_point(0.7, Color(c, 0.6))
	return g


static func _radial_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _band_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.086, 0.075, 0.11, 0.0))
	g.set_color(1, Color(0.086, 0.075, 0.11, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 64
	return t
