class_name AudioDirector
extends Node
## Áudio do cliente (GDD §18, contrato "Áudio"): música por zona com transição, ambiente em camadas,
## efeitos 2D/3D por nome, passos pelo tipo de chão sob o jogador local e loops posicionais do mapa
## (ex.: zumbido do cristal). Não faz nada (sem erro) quando os arquivos de áudio ainda não existem.
## Uma instância por vez (filho do ClientView ou da tela de título); acesso estático pelos métodos
## AudioDirector.play_sfx(&"buy") etc. (menus e interface não têm som).

const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_PREFIX: String = "mus_"
const SFX_PREFIX: String = "sfx_"
const AUDIO_EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const BUS_MUSIC: StringName = &"Music"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
## Efeitos com este prefixo vão para o barramento UI.
const UI_SFX_PREFIX: String = "ui_"
## Transição de música e de camadas de ambiente (contrato: 2 s).
const CROSSFADE_SEC: float = 2.0
const SILENT_DB: float = -60.0
## Zona que vale para o mapa inteiro: <map_id>_default.
const DEFAULT_ZONE: StringName = &"default"
const ZONES_NODE: NodePath = ^"AudioZones"
const META_ZONE_ID: StringName = &"zone_id"
const META_SURFACE: StringName = &"surface"
## Meta genérica para loops 3D do mapa (valor = nome do efeito, ex.: &"crystal_hum").
const META_SFX_LOOP: StringName = &"sfx_loop"
## Nós do mapa que ganham o zumbido do cristal mesmo sem meta (até C marcar com sfx_loop).
const CRYSTAL_NODE_NAMES: Array[StringName] = [&"RespawnCrystal"]
const CRYSTAL_SFX: StringName = &"crystal_hum"
const DEFAULT_SURFACE: StringName = &"stone"
const STEP_VARIANTS: int = 4
const STEP_PITCH_JITTER: float = 0.06
## Raio para baixo, a partir de um pouco acima dos pés, para achar o chão (camada 1).
const STEP_RAY_UP: float = 0.5
const STEP_RAY_DOWN: float = 2.0
const GROUND_MASK: int = 1
## Intervalo de reavaliação das zonas (s).
const ZONE_CHECK_SEC: float = 0.25
## Alcance dos efeitos 3D (m).
const SFX_3D_UNIT_SIZE: float = 6.0
const SFX_3D_MAX_DISTANCE: float = 40.0
const LOOP_3D_UNIT_SIZE: float = 4.0
const LOOP_3D_MAX_DISTANCE: float = 25.0
## Limite de efeitos simultâneos (reuso de players).
const MAX_SFX_VOICES: int = 16
const MAPS_ROOT: NodePath = ^"/root/Main/World/Instances"
const MAP_NODE_NAME: StringName = &"Map"

static var instance: AudioDirector = null

## Zona ativa (id) e música atual, para depuração/testes.
var current_zone: StringName = &""
var current_music: AudioStream = null

var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _cue_return_music: AudioStream = null
var _cue_stream: AudioStream = null
var _ambience: Dictionary[AudioStream, AudioStreamPlayer] = {}
var _voices: Array[AudioStreamPlayer] = []
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _stream_cache: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _target: Node3D = null
var _target_visual: DirectionalSprite3D = null
var _map: Node = null
var _loops: Array[Node] = []
var _zone_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tweens: Dictionary[Node, Tween] = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	_clear_loops()


func _ready() -> void:
	ensure_buses()
	GameSettings.get_instance().apply_audio()
	for i: int in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_MUSIC
		p.volume_db = SILENT_DB
		add_child(p)
		_music_players.append(p)
	# Sons do combate (golpes, dano, morte) — GDD §10.2.1.
	var combat_audio := CombatAudio.new()
	combat_audio.name = &"CombatAudio"
	add_child(combat_audio)


# --- API estática (segura sem instância) ----------------------------------------------------------

## Toca um efeito pelo nome (&"buy" ou &"sfx_buy"). Com posição → 3D no mundo.
static func play_sfx(sfx_name: StringName, world_pos: Variant = null) -> void:
	if instance != null:
		instance.play_effect(sfx_name, world_pos)


## Toca a música pelo nome (&"title" → mus_title.ogg) com transição.
static func play_music_named(music_name: StringName) -> void:
	if instance != null:
		instance.play_music(instance.load_music(music_name))


## Toca um cue uma vez e retorna à trilha anterior quando terminar.
static func play_music_cue_named(music_name: StringName) -> void:
	if instance != null:
		instance.play_music_cue(instance.load_music(music_name))


## Garante os 5 barramentos do contrato (se o default_bus_layout.tres não foi carregado).
static func ensure_buses() -> void:
	for bus: StringName in GameSettings.BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, GameSettings.BUS_MASTER)


# --- API da instância -----------------------------------------------------------------------------

## Segue o jogador local: zonas de áudio e passos.
func follow(target: Node3D) -> void:
	if _target_visual != null and is_instance_valid(_target_visual) \
			and _target_visual.footstep.is_connected(_on_footstep):
		_target_visual.footstep.disconnect(_on_footstep)
	_target = target
	_target_visual = null
	_zone_timer = 0.0


## Define o mapa atual explicitamente (senão é descoberto a partir do alvo).
func set_map(map_node: Node) -> void:
	if map_node == _map:
		return
	_clear_loops()
	_map = map_node
	current_zone = &""
	if _map != null:
		_setup_loops()


func play_effect(sfx_name: StringName, world_pos: Variant = null) -> void:
	var file: String = String(sfx_name)
	if not file.begins_with(SFX_PREFIX):
		file = SFX_PREFIX + file
	var stream: AudioStream = _load(SFX_DIR + file)
	if stream == null:
		return
	var bus: StringName = BUS_UI if file.trim_prefix(SFX_PREFIX).begins_with(UI_SFX_PREFIX) else BUS_SFX
	if world_pos is Vector3 and is_inside_tree():
		var p3: AudioStreamPlayer3D = _free_voice_3d()
		if p3 == null:
			return
		p3.stream = stream
		p3.bus = bus
		p3.global_position = world_pos as Vector3
		p3.play()
		return
	var p: AudioStreamPlayer = _free_voice()
	if p == null:
		return
	p.stream = stream
	p.bus = bus
	p.pitch_scale = 1.0
	p.play()


## Carrega mus_<nome> (null se não existe).
func load_music(music_name: StringName) -> AudioStream:
	var file: String = String(music_name)
	if not file.begins_with(MUSIC_PREFIX):
		file = MUSIC_PREFIX + file
	return _load(MUSIC_DIR + file)


## Troca a música com transição (null = silêncio).
func play_music(stream: AudioStream, volume_db: float = 0.0, loop: bool = true) -> void:
	if stream == current_music:
		return
	current_music = stream
	if _music_players.is_empty():
		return
	var old: AudioStreamPlayer = _music_players[_music_active]
	_music_active = 1 - _music_active
	var new_player: AudioStreamPlayer = _music_players[_music_active]
	_fade(old, SILENT_DB, true)
	if stream == null:
		return
	_set_loop(stream, loop)
	new_player.stream = stream
	new_player.volume_db = SILENT_DB
	new_player.play()
	_fade(new_player, volume_db, false)


func play_music_cue(stream: AudioStream) -> void:
	if stream == null or _music_players.is_empty():
		return
	_cue_return_music = current_music
	_cue_stream = stream
	play_music(stream, 0.0, false)
	_music_players[_music_active].finished.connect(_on_music_cue_finished.bind(stream), CONNECT_ONE_SHOT)


func _on_music_cue_finished(stream: AudioStream) -> void:
	if current_music != stream or _cue_stream != stream:
		return
	var previous: AudioStream = _cue_return_music
	_cue_stream = null
	_cue_return_music = null
	play_music(previous)


## Camadas de ambiente desejadas: entram e saem com transição.
func set_ambience(layers: Array[AudioStream]) -> void:
	for stream: AudioStream in _ambience.keys():
		if stream not in layers:
			var p: AudioStreamPlayer = _ambience[stream]
			_ambience.erase(stream)
			_fade(p, SILENT_DB, true, true)
	for stream: AudioStream in layers:
		if stream == null or _ambience.has(stream):
			continue
		_set_loop(stream)
		var p := AudioStreamPlayer.new()
		p.bus = BUS_AMBIENCE
		p.stream = stream
		p.volume_db = SILENT_DB
		add_child(p)
		p.play()
		_ambience[stream] = p
		_fade(p, 0.0, false)


func get_ambience_count() -> int:
	return _ambience.size()


## Chão sob uma posição (meta surface do StaticBody3D da camada 1), ou DEFAULT_SURFACE.
func surface_at(world_pos: Vector3) -> StringName:
	var world: World3D = _world()
	if world == null:
		return DEFAULT_SURFACE
	var query := PhysicsRayQueryParameters3D.create(world_pos + Vector3.UP * STEP_RAY_UP,
			world_pos + Vector3.DOWN * STEP_RAY_DOWN, GROUND_MASK)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return DEFAULT_SURFACE
	var collider: Object = hit["collider"]
	if collider != null and collider.has_meta(META_SURFACE):
		return StringName(collider.get_meta(META_SURFACE))
	return DEFAULT_SURFACE


# --- Loop -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		follow(null)
	if _target == null:
		return
	if _target_visual == null:
		_target_visual = _find_visual(_target)
		if _target_visual != null:
			_target_visual.footstep.connect(_on_footstep)
	_zone_timer -= delta
	if _zone_timer > 0.0:
		return
	_zone_timer = ZONE_CHECK_SEC
	if _map == null or not is_instance_valid(_map):
		_map = null
		set_map(_discover_map())
	_update_zone()


func _update_zone() -> void:
	if not is_instance_valid(_map) or not is_instance_valid(_target):
		return
	# A transfer detaches the old player before the new map finishes entering.
	if not _map.is_inside_tree() or not _target.is_inside_tree():
		return
	var map_id: StringName = &""
	if &"map_id" in _map:
		map_id = StringName(_map.get(&"map_id"))
	elif _map.has_meta(&"map_id"):
		map_id = StringName(_map.get_meta(&"map_id"))
	var pos: Vector3 = _target.global_position
	var best: AudioZoneDef = _zone_def(map_id, DEFAULT_ZONE)
	var default_def: AudioZoneDef = best
	var best_id: StringName = DEFAULT_ZONE
	var zones: Node = _map.get_node_or_null(ZONES_NODE)
	if zones != null:
		for area: Node in zones.get_children():
			if not (area is Area3D) or not area.has_meta(META_ZONE_ID):
				continue
			var zone_id: StringName = StringName(area.get_meta(META_ZONE_ID))
			if not area_contains(area as Area3D, pos):
				continue
			var def: AudioZoneDef = _zone_def(map_id, zone_id)
			if def != null and (best == null or def.priority > best.priority or best_id == DEFAULT_ZONE):
				best = def
				best_id = zone_id
	if best_id == current_zone:
		return
	current_zone = best_id
	if best == null:
		return
	play_music(best.music, best.music_volume_db)
	var layers: Array[AudioStream] = []
	if default_def != null and default_def != best:
		layers.append_array(default_def.ambience)
	layers.append_array(best.ambience)
	set_ambience(layers)


## Ponto dentro de alguma CollisionShape3D da área (caixa, esfera, cilindro, cápsula; outras = AABB).
static func area_contains(area: Area3D, world_pos: Vector3) -> bool:
	for child: Node in area.get_children():
		var cs: CollisionShape3D = child as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var local: Vector3 = cs.global_transform.affine_inverse() * world_pos
		var shape: Shape3D = cs.shape
		if shape is BoxShape3D:
			var half: Vector3 = (shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				return true
		elif shape is SphereShape3D:
			if local.length() <= (shape as SphereShape3D).radius:
				return true
		elif shape is CylinderShape3D:
			var cyl: CylinderShape3D = shape as CylinderShape3D
			if Vector2(local.x, local.z).length() <= cyl.radius and absf(local.y) <= cyl.height * 0.5:
				return true
		elif shape is CapsuleShape3D:
			var cap: CapsuleShape3D = shape as CapsuleShape3D
			if Vector2(local.x, local.z).length() <= cap.radius and absf(local.y) <= cap.height * 0.5:
				return true
		else:
			var aabb: AABB = shape.get_debug_mesh().get_aabb()
			if aabb.has_point(local):
				return true
	return false


# --- Internos -------------------------------------------------------------------------------------

func _on_footstep() -> void:
	if not Balance.cfg.footsteps_enabled or _target == null or not is_instance_valid(_target):
		return
	var surface: StringName = surface_at(_target.global_position)
	var n: int = _rng.randi_range(1, STEP_VARIANTS)
	var stream: AudioStream = _load("%s%sstep_%s_%d" % [SFX_DIR, SFX_PREFIX, surface, n])
	if stream == null:
		return
	var p: AudioStreamPlayer = _free_voice()
	if p == null:
		return
	p.stream = stream
	p.bus = BUS_SFX
	p.pitch_scale = 1.0 + _rng.randf_range(-STEP_PITCH_JITTER, STEP_PITCH_JITTER)
	var jitter: float = Balance.cfg.footstep_volume_jitter_db
	p.volume_db = Balance.cfg.footstep_volume_db + _rng.randf_range(-jitter, jitter)
	p.play()


func _zone_def(map_id: StringName, zone_id: StringName) -> AudioZoneDef:
	var content: Node = get_node_or_null(^"/root/Content")
	if content == null:
		return null
	var full := StringName("%s_%s" % [map_id, zone_id])
	var def: AudioZoneDef = content.call(&"audio_zone", full) as AudioZoneDef
	if def != null:
		return def
	# O Content indexa pelo campo id quando preenchido: procura pelo nome do arquivo.
	var all: Dictionary = content.call(&"all", &"audio")
	for key: Variant in all:
		var res: Resource = all[key]
		if res is AudioZoneDef and res.resource_path.get_file().get_basename() == String(full):
			return res as AudioZoneDef
	return null


func _discover_map() -> Node:
	# Sobe a partir do alvo: <instância>/Entities/<entidade> → <instância>/Map.
	var node: Node = _target
	while node != null:
		var map_node: Node = node.get_node_or_null(NodePath(String(MAP_NODE_NAME)))
		if map_node != null and node != _target:
			return map_node
		node = node.get_parent()
	var root: Node = get_node_or_null(MAPS_ROOT)
	if root != null:
		for inst: Node in root.get_children():
			var m: Node = inst.get_node_or_null(NodePath(String(MAP_NODE_NAME)))
			if m != null:
				return m
	return null


func _find_visual(target: Node) -> DirectionalSprite3D:
	for child: Node in target.get_children():
		if child is DirectionalSprite3D:
			return child as DirectionalSprite3D
	return target as DirectionalSprite3D if target is DirectionalSprite3D else null


func _setup_loops() -> void:
	var found: Array[Node] = []
	_collect_loop_nodes(_map, found)
	for node: Node in found:
		var sfx: StringName = StringName(node.get_meta(META_SFX_LOOP)) if node.has_meta(META_SFX_LOOP) \
				else CRYSTAL_SFX
		var file: String = String(sfx)
		if not file.begins_with(SFX_PREFIX):
			file = SFX_PREFIX + file
		var stream: AudioStream = _load(SFX_DIR + file)
		if stream == null:
			continue
		_set_loop(stream)
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.bus = BUS_SFX
		p.unit_size = LOOP_3D_UNIT_SIZE
		p.max_distance = LOOP_3D_MAX_DISTANCE
		p.autoplay = true
		node.add_child(p)
		_loops.append(p)


func _collect_loop_nodes(node: Node, out: Array[Node]) -> void:
	if node is Node3D and (node.has_meta(META_SFX_LOOP) or node.name in CRYSTAL_NODE_NAMES):
		out.append(node)
	for child: Node in node.get_children():
		_collect_loop_nodes(child, out)


func _clear_loops() -> void:
	for p: Node in _loops:
		if is_instance_valid(p):
			p.queue_free()
	_loops.clear()


func _free_voice() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _voices:
		if not p.playing:
			# Voz reaproveitada: volta ao padrão (os passos baixam volume e mudam o tom).
			p.volume_db = 0.0
			p.pitch_scale = 1.0
			return p
	if _voices.size() >= MAX_SFX_VOICES:
		return null
	var p := AudioStreamPlayer.new()
	add_child(p)
	_voices.append(p)
	return p


func _free_voice_3d() -> AudioStreamPlayer3D:
	# As vozes 3D ficam dentro do mapa: ao trocar de mapa elas somem junto (beta, 30/09/2026).
	_voices_3d = _voices_3d.filter(func(v: Variant) -> bool: return is_instance_valid(v))
	for p: AudioStreamPlayer3D in _voices_3d:
		if not p.playing:
			return p
	if _voices_3d.size() >= MAX_SFX_VOICES:
		return null
	var world_root: Node = get_node_or_null(MAPS_ROOT)
	if world_root == null:
		world_root = get_tree().current_scene
	if world_root == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.unit_size = SFX_3D_UNIT_SIZE
	p.max_distance = SFX_3D_MAX_DISTANCE
	world_root.add_child(p)
	_voices_3d.append(p)
	return p


func _world() -> World3D:
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree():
		return _target.get_world_3d()
	return null


## Carrega <base>.ogg/.wav/.mp3; lembra o que não existe para não procurar de novo.
func _load(base: String) -> AudioStream:
	if _stream_cache.has(base):
		return _stream_cache[base]
	if _missing.has(base):
		return null
	for ext: String in AUDIO_EXTENSIONS:
		if ResourceLoader.exists(base + ext):
			var s: AudioStream = load(base + ext) as AudioStream
			if s != null:
				_stream_cache[base] = s
				return s
	_missing[base] = true
	return null


static func _set_loop(stream: AudioStream, loop: bool = true) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if loop and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if wav.loop_end == 0:
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif not loop:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED


func _fade(p: AudioStreamPlayer, to_db: float, stop_after: bool, free_after: bool = false) -> void:
	if p == null:
		return
	var running: Tween = _tweens.get(p)
	if running != null and running.is_valid():
		running.kill()
	var tw: Tween = create_tween()
	_tweens[p] = tw
	tw.tween_property(p, "volume_db", to_db, CROSSFADE_SEC)
	if free_after:
		tw.tween_callback(p.queue_free)
	elif stop_after:
		tw.tween_callback(p.stop)
