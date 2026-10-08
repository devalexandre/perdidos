class_name SkillFxSprite
extends MeshInstance3D
## Uma peça de efeito de skill (folha de assets/fx/skills/, tabela SkillFxSheets) tocando no mundo.
## Criada pelo SkillFx. Em pé (billboard, virada para a câmera) ou deitada no chão (flat). Pode seguir
## uma entidade (e some quando ela morre ou sai da cena), girar na direção de um voo na tela e
## ficar em laço por um tempo. Tudo só visual.
## Efeitos "anime" (07/10/2026, docs/fx-anime.md): folhas em alta de assets/fx/anime/ (<peça>.json com
## "filter": "linear" e "cols"), em grade, com filtro linear + mipmaps; blend "glow" = só aditivo.

const ADD_SHADER: String = "res://assets/shaders/skill_fx_add.gdshader"
const MIX_SHADER: String = "res://assets/shaders/skill_fx_mix.gdshader"
const ADD_SMOOTH_SHADER: String = "res://assets/shaders/skill_fx_add_smooth.gdshader"
const MIX_SMOOTH_SHADER: String = "res://assets/shaders/skill_fx_mix_smooth.gdshader"
## Folhas dos efeitos "anime" (alta resolução, degradê e alfa suaves; fora da regra de paleta da pixel art).
const ANIME_DIR: String = "res://assets/fx/anime/"
const PLANE_FLAT: StringName = &"flat"
const BLEND_ADD: StringName = &"add"
## Só a camada aditiva (brilho puro, sem o corpo em blend normal por baixo).
const BLEND_GLOW: StringName = &"glow"
## Depois das manchas de chão (≤ 5) e da sombra dos pés (6); as peças em pé por cima das deitadas.
const PRIORITY_FLAT: int = 7
const PRIORITY_UPRIGHT: int = 8
const DEFAULT_FADE_OUT_SEC: float = 0.25
## Peças de brilho = forma em blend normal (legível no chão claro do Campo) + a mesma folha somada
## (aditivo) por cima com esta intensidade. Só aditivo, o brilho some no chão claro (vira mancha branca).
const GLOW_GAIN: float = 0.55
## Altura das peças deitadas acima do ponto (evita brigar com o chão).
const FLAT_LIFT: float = 0.08

static var _shaders: Dictionary[StringName, Shader] = {}
static var _meshes: Dictionary[StringName, ArrayMesh] = {}
static var _textures: Dictionary[StringName, Texture2D] = {}
static var _infos: Dictionary[StringName, Dictionary] = {}

var piece: StringName = &""
var frames: int = 1
var fps: float = 12.0
var loop: bool = false
## Laço: tempo de vida (s). < 0 = até stop(). Sem laço: toca uma vez e some.
var life_sec: float = -1.0
var fade_in_sec: float = 0.0
var fade_out_sec: float = DEFAULT_FADE_OUT_SEC
## Entidade seguida (posição + follow_offset). Some com ela; para quando hp_ratio chega a 0.
var follow: Node3D = null
var follow_offset: Vector3 = Vector3.ZERO
## Direção do voo no mundo (projéteis): o quadro gira para ela na tela (folha desenhada para +x).
var orient_dir: Vector3 = Vector3.ZERO
## Quadro inicial (varia chamas iguais lado a lado).
var frame_offset: int = 0
var elapsed: float = 0.0

var _mat: ShaderMaterial
## Camada de brilho aditivo por cima da peça (peças de brilho): mesmos quadros, intensidade GLOW_GAIN.
var _glow_mat: ShaderMaterial = null
var _stop_at: float = -1.0
var _flat: bool = false
var _follows: bool = false


## Cria a peça pelo nome da tabela. null se a folha não existir.
static func create(piece_name: StringName) -> SkillFxSprite:
	var info: Dictionary = sheet_info(piece_name)
	var tex: Texture2D = _texture(piece_name)
	if info.is_empty() or tex == null:
		return null
	var s := SkillFxSprite.new()
	s.name = &"Fx_" + piece_name
	s.piece = piece_name
	s.frames = int(info["frames"])
	s.fps = float(info["fps"])
	s.loop = bool(info["loop"])
	s._flat = info["plane"] == PLANE_FLAT
	s.mesh = _mesh(piece_name, info)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# O billboard move os vértices no shader: caixa folgada para não sumir na borda da tela.
	var size: Vector2 = Vector2(info["size"]) * float(info["texel"])
	var r: float = maxf(size.x, size.y) * 1.5
	s.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	var prio: int = PRIORITY_FLAT if s._flat else PRIORITY_UPRIGHT
	var smooth: bool = bool(info.get("smooth", false))
	var cols: int = int(info.get("cols", 0))
	var hf: int = cols if cols > 0 else s.frames
	var vf: int = ceili(float(s.frames) / hf)
	if info["blend"] == BLEND_GLOW:
		s._mat = _make_mat(BLEND_ADD, tex, hf, not s._flat, prio + 1, smooth, vf)
		s.material_override = s._mat
		return s
	s._mat = _make_mat(&"mix", tex, hf, not s._flat, prio, smooth, vf)
	s.material_override = s._mat
	if info["blend"] == BLEND_ADD:
		s._glow_mat = _make_mat(BLEND_ADD, tex, hf, not s._flat, prio + 1, smooth, vf)
		s._glow_mat.set_shader_parameter(&"tint", Color(GLOW_GAIN, GLOW_GAIN, GLOW_GAIN, 1.0))
		var g := MeshInstance3D.new()
		g.name = &"Glow"
		g.mesh = s.mesh
		g.custom_aabb = s.custom_aabb
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.material_override = s._glow_mat
		s.add_child(g)
	return s


static func _make_mat(blend: StringName, tex: Texture2D, n: int, billboard: bool, prio: int,
		smooth: bool = false, rows: int = 1) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(blend, smooth)
	mat.set_shader_parameter(&"sheet", tex)
	mat.set_shader_parameter(&"hframes", n)
	mat.set_shader_parameter(&"vframes", rows)
	mat.set_shader_parameter(&"billboard", billboard)
	mat.render_priority = prio
	return mat


func _param(key: StringName, value: Variant) -> void:
	_mat.set_shader_parameter(key, value)
	if _glow_mat != null:
		_glow_mat.set_shader_parameter(key, value)


## Preserva luz e recortes da folha ao trocar a cor da preparação, inclusive nas peças quentes.
func set_charge_color(color: Color) -> void:
	_param(&"charge_color", color)
	_param(&"charge_recolor", true)


static func has_piece(piece_name: StringName) -> bool:
	return not sheet_info(piece_name).is_empty() and _texture(piece_name) != null


## Dados da folha. Uma folha importada de GIF (tools/art/fx/import_fx_gif.py) traz <peça>.json ao
## lado e tem preferência sobre a tabela gerada (SkillFxSheets). As folhas "anime" (ANIME_DIR) também
## vêm com .json: "cols" (grade) e "filter": "linear" (smooth).
static func sheet_info(piece_name: StringName) -> Dictionary:
	if _infos.has(piece_name):
		return _infos[piece_name]
	var info: Dictionary = SkillFxSheets.SHEETS.get(piece_name, {}).duplicate()
	var dir: String = SkillFxSheets.DIR
	var jpath: String = dir + String(piece_name) + ".json"
	if not FileAccess.file_exists(jpath) and FileAccess.file_exists(ANIME_DIR + String(piece_name) + ".json"):
		dir = ANIME_DIR
		jpath = dir + String(piece_name) + ".json"
	if FileAccess.file_exists(jpath):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(jpath))
		if j is Dictionary:
			var d: Dictionary = j
			info = {"frames": int(d.get("frames", 1)),
				"size": Vector2i(int(d["size"][0]), int(d["size"][1])),
				"pivot": Vector2(float(d["pivot"][0]), float(d["pivot"][1])),
				"blend": StringName(str(d.get("blend", "add"))), "plane": StringName(str(d.get("plane", "billboard"))),
				"fps": float(d.get("fps", 12.0)), "loop": bool(d.get("loop", false)),
				"texel": float(d.get("texel", 1.0 / 48.0)), "imported": true,
				"cols": int(d.get("cols", 0)), "smooth": str(d.get("filter", "nearest")) == "linear", "dir": dir}
	_infos[piece_name] = info
	return info


static func _texture(piece_name: StringName) -> Texture2D:
	if not _textures.has(piece_name):
		var path: String = str(sheet_info(piece_name).get("dir", SkillFxSheets.DIR)) + String(piece_name) + ".png"
		_textures[piece_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[piece_name]


static func _shader(blend: StringName, smooth: bool = false) -> Shader:
	var key: StringName = StringName(String(blend) + ("_smooth" if smooth else ""))
	if not _shaders.has(key):
		var path: String = ADD_SHADER if blend == BLEND_ADD else MIX_SHADER
		if smooth:
			path = ADD_SMOOTH_SHADER if blend == BLEND_ADD else MIX_SMOOTH_SHADER
		_shaders[key] = load(path) as Shader
	return _shaders[key]


## Quad com o pivô da folha na origem. Em pé: plano XY (y para cima). Deitado: plano XZ, com o
## "para cima" da imagem apontando para -Z (a frente, mesma convenção do facing_yaw).
static func _mesh(piece_name: StringName, info: Dictionary) -> ArrayMesh:
	# (info vem de sheet_info: tabela gerada ou .json da folha importada)
	if _meshes.has(piece_name):
		return _meshes[piece_name]
	var sz: Vector2i = info["size"]
	var pv: Vector2 = info["pivot"]
	var t: float = float(info["texel"])
	var flat: bool = info["plane"] == PLANE_FLAT
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
		var px: Vector2 = Vector2(c.x * sz.x, c.y * sz.y) - pv
		verts.append(Vector3(px.x * t, 0.0, px.y * t) if flat else Vector3(px.x * t, -px.y * t, 0.0))
		uvs.append(c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[piece_name] = m
	return m


func duration() -> float:
	return frames / fps


func set_depth_bias(meters: float) -> void:
	_param(&"depth_bias", meters)


## Espelha na horizontal (em pé: no shader, que ignora o sinal da escala; deitada: pela escala).
func set_flip(on: bool) -> void:
	if _flat:
		scale.x = -absf(scale.x) if on else absf(scale.x)
	else:
		_param(&"flip", -1.0 if on else 1.0)


func set_tint(c: Color) -> void:
	_mat.set_shader_parameter(&"tint", c)
	if _glow_mat != null:
		_glow_mat.set_shader_parameter(&"tint", Color(c.r * GLOW_GAIN, c.g * GLOW_GAIN, c.b * GLOW_GAIN, c.a))


## Deitada no chão, com a frente da folha na direção dada (plano XZ).
func face_ground_dir(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() > 0.001:
		rotation.y = atan2(-d.x, -d.z)


## Termina com o sumiço (laços e peças seguidoras).
func stop(fade_sec: float = DEFAULT_FADE_OUT_SEC) -> void:
	if _stop_at >= 0.0:
		return
	fade_out_sec = maxf(fade_sec, 0.001)
	_stop_at = elapsed


func is_stopping() -> bool:
	return _stop_at >= 0.0


func _ready() -> void:
	_apply(0.0)


func _process(delta: float) -> void:
	elapsed += delta
	_apply(delta)


func _apply(_delta: float) -> void:
	# (um seguido já liberado compara igual a null: a marca guarda que havia alguém para seguir)
	if follow != null:
		_follows = true
	if _follows:
		if not is_instance_valid(follow) or not follow.is_inside_tree():
			queue_free()
			follow = null
			return
		global_position = follow.global_position + follow_offset
		var hp: Variant = follow.get(&"hp_ratio")
		if hp != null and float(hp) <= 0.0:
			stop()
	var f: int
	if loop:
		f = (int(elapsed * fps) + frame_offset) % frames
		if life_sec >= 0.0 and elapsed >= life_sec:
			stop()
	else:
		f = mini(int(elapsed * fps), frames - 1)
		if elapsed >= duration() and _stop_at < 0.0:
			queue_free()
			return
	_param(&"frame", f)
	var a: float = 1.0
	if fade_in_sec > 0.0:
		a = minf(a, elapsed / fade_in_sec)
	if _stop_at >= 0.0:
		var k: float = 1.0 - (elapsed - _stop_at) / fade_out_sec
		if k <= 0.0:
			queue_free()
			return
		a = minf(a, k)
	_param(&"fade", clampf(a, 0.0, 1.0))
	if orient_dir != Vector3.ZERO and not _flat:
		_orient()


func _orient() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var p: Vector3 = global_position
	if cam.is_position_behind(p):
		return
	var a: Vector2 = cam.unproject_position(p)
	var b: Vector2 = cam.unproject_position(p + orient_dir.normalized() * 0.5)
	var d: Vector2 = b - a
	if d.length() > 0.01:
		# tela: y para baixo; vista: y para cima
		_param(&"roll", -atan2(d.y, d.x))
