extends Node
## Gestos ocasionais de NPC (08/10/2026), só visual, no cliente e sem rede. Anexado pela EntityVisualFactory a todo
## NPC de qualquer mapa (filho do EntityVisual). Parado, a cada 6–15 s (sorteio próprio de cada NPC, dessincronizado)
## faz um gesto curto e volta ao idle: olhar para os lados (vira 1 setor e volta), coçar, apoiar no cajado, esticar,
## mexer na fogueira (se houver uma perto), suspirar e, raro, um balão "!" ou "…". Vira para o jogador local quando
## ele chega a ~3 m. Usa só a API pública do DirectionalSprite3D (facing_yaw, anim, play_oneshot, has_anim) e mexe no
## nó Visual por fora (escala/deslocamento leves); não pinta arte nova.
## Ordem de processamento: a NetEntity (pai) escreve facing_yaw/anim no Visual a cada quadro; este nó roda depois dela
## e ANTES do Visual (o Visual passa a ter process_priority = VISUAL_PRIORITY), então a virada vale no mesmo quadro.

## Intervalo (s) entre gestos e chance do balão raro.
const GAP_SEC: Vector2 = Vector2(6.0, 15.0)
const BUBBLE_CHANCE: float = 0.1
## Distância (m) para virar para o jogador, e a folga para soltar (histerese).
const FACE_PLAYER_M: float = 3.0
const FACE_RELEASE_M: float = 3.6
## Fogueira perto o bastante para "mexer no fogo" (m).
const FIRE_NEAR_M: float = 3.2
## Longe da câmera não gesticula (m).
const CULL_M: float = 38.0
const VISUAL_PRIORITY: int = 1
## Grupo dos pontos de fogueira (CampDressing/LivingEnvironment registram).
const FIRE_GROUP: StringName = &"env_fire_spot"
const SECTOR: float = TAU / 8.0

const GESTURES: Array[StringName] = [&"look", &"look", &"scratch", &"lean", &"stretch", &"sigh", &"fire"]
## Duração (s) de cada gesto.
const DURATION: Dictionary = {&"look": 2.6, &"scratch": 0.9, &"lean": 2.4, &"stretch": 1.5, &"sigh": 1.3,
	&"fire": 2.0, &"bubble": 0.6}

var visual: Node3D = null
var gesture: StringName = &""
var gesture_t: float = 0.0
var facing_player: bool = false
## Testes: posição do jogador local a usar (null = procura a entidade local).
var player_override: Variant = null
## Testes: yaw "de rede" quando não há NetEntity por cima.
var rest_yaw: float = 0.0

var _wait: float = 0.0
var _rng := RandomNumberGenerator.new()
var _fire_dir: Vector3 = Vector3.ZERO
var _yaw_offset: float = 0.0
var _player: Node3D = null
var _player_t: float = 0.0
var _count: int = 0


func _ready() -> void:
	name = &"Gestures"
	visual = get_parent() as Node3D
	if visual != null:
		visual.process_priority = VISUAL_PRIORITY
		rest_yaw = float(visual.get(&"facing_yaw"))
	_rng.seed = hash(str(get_instance_id())) ^ Time.get_ticks_usec()
	_wait = _rng.randf_range(2.0, GAP_SEC.y)


func _process(delta: float) -> void:
	step(delta)


## Quantos gestos já fez (testes/capturas).
func gesture_count() -> int:
	return _count


## Começa um gesto agora (capturas e testes). false se o NPC não está parado.
func force_gesture(g: StringName) -> bool:
	if not _is_idle():
		return false
	_start(g)
	return true


func step(delta: float) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var entity: Node = visual.get_parent()
	var net_yaw: float = float(entity.get(&"facing_yaw")) if entity is NetEntity else rest_yaw
	if not _is_idle():
		_reset()
		return
	# longe da câmera / fora da tela: só o relógio anda
	if _too_far():
		_reset()
		return
	var player: Variant = _player_pos(delta)
	var me: Vector3 = visual.global_position
	if player != null:
		var d: float = Vector2((player as Vector3).x - me.x, (player as Vector3).z - me.z).length()
		facing_player = d < (FACE_RELEASE_M if facing_player else FACE_PLAYER_M) and d > 0.2
	else:
		facing_player = false
	if facing_player:
		if gesture != &"bubble":
			_end_gesture()
		var to: Vector3 = (player as Vector3) - me
		visual.set(&"facing_yaw", atan2(-to.x, -to.z))
		_apply(1.0, 1.0, Vector3.ZERO)
		return
	if gesture.is_empty():
		_wait -= delta
		visual.set(&"facing_yaw", net_yaw)
		if _wait <= 0.0:
			_start(_pick())
		return
	gesture_t += delta
	var dur: float = float(DURATION.get(gesture, 1.0))
	var k: float = clampf(gesture_t / dur, 0.0, 1.0)
	_animate(k, net_yaw)
	if k >= 1.0:
		_end_gesture()
		visual.set(&"facing_yaw", net_yaw)


func _pick() -> StringName:
	if _rng.randf() < BUBBLE_CHANCE:
		return &"bubble"
	var g: StringName = GESTURES[_rng.randi() % GESTURES.size()]
	if g == &"fire" and _near_fire() == Vector3.ZERO:
		g = &"look"
	return g


func _start(g: StringName) -> void:
	gesture = g
	gesture_t = 0.0
	_count += 1
	_yaw_offset = SECTOR * (1.0 if _rng.randf() < 0.5 else -1.0)
	match g:
		&"stretch":
			_oneshot(&"cast")
		&"fire":
			_fire_dir = _near_fire()
			_oneshot(&"attack")
		&"bubble":
			if visual.has_method(&"show_chat"):
				visual.call(&"show_chat", "!" if _rng.randf() < 0.45 else "…")


func _oneshot(anim_name: StringName) -> void:
	if visual.has_method(&"has_anim") and visual.has_method(&"play_oneshot"):
		var resolved: StringName = visual.call(&"resolve_anim", anim_name) if visual.has_method(&"resolve_anim") else anim_name
		if bool(visual.call(&"has_anim", resolved)):
			visual.call(&"play_oneshot", anim_name)


## k = 0..1 do gesto. Escala/deslocamento leves no nó Visual (o sprite em si é do DirectionalSprite3D).
func _animate(k: float, net_yaw: float) -> void:
	var bell: float = sin(PI * k)
	var side: Vector3 = _camera_right()
	match gesture:
		&"look":
			# vira 1 setor, volta, vira para o outro lado, volta
			var off: float = 0.0
			if k < 0.4:
				off = _yaw_offset
			elif k > 0.5 and k < 0.9:
				off = -_yaw_offset
			visual.set(&"facing_yaw", net_yaw + off)
			_apply(1.0, 1.0, Vector3.ZERO)
		&"scratch":
			var jit: float = sin(gesture_t * 42.0) * 0.018 * bell
			_apply(1.0 + 0.015 * bell, 1.0 - 0.03 * bell, side * jit)
		&"lean":
			# apoia no cajado: pende para um lado e afunda um pouco
			var lean: float = smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.75, 1.0, k))
			_apply(1.0 + 0.02 * lean, 1.0 - 0.045 * lean, side * 0.08 * lean * signf(_yaw_offset))
		&"stretch":
			# fica na ponta dos pés e se estica (com a folha de conjuração, se houver: braços para cima)
			_apply(1.0 - 0.04 * bell, 1.0 + 0.08 * bell, Vector3.UP * 0.04 * bell)
		&"sigh":
			# enche o peito e solta
			var b: float = sin(TAU * k) * (1.0 - k)
			_apply(1.0 + 0.02 * b, 1.0 + 0.035 * b, Vector3.ZERO)
		&"fire":
			if _fire_dir != Vector3.ZERO:
				var to: Vector3 = _fire_dir - visual.global_position
				visual.set(&"facing_yaw", atan2(-to.x, -to.z))
			var dip: float = smoothstep(0.1, 0.35, k) * (1.0 - smoothstep(0.7, 1.0, k))
			_apply(1.0 + 0.02 * dip, 1.0 - 0.06 * dip, Vector3.ZERO)
		_:
			_apply(1.0, 1.0, Vector3.ZERO)


func _apply(sx: float, sy: float, offset: Vector3) -> void:
	visual.scale = Vector3(sx, sy, sx)
	visual.position = offset


func _end_gesture() -> void:
	gesture = &""
	gesture_t = 0.0
	_wait = _rng.randf_range(GAP_SEC.x, GAP_SEC.y)
	_apply(1.0, 1.0, Vector3.ZERO)


func _reset() -> void:
	if not gesture.is_empty():
		_end_gesture()
	facing_player = false
	if visual.scale != Vector3.ONE or visual.position != Vector3.ZERO:
		_apply(1.0, 1.0, Vector3.ZERO)


func _is_idle() -> bool:
	if visual == null:
		return false
	var a: StringName = visual.get(&"anim")
	if a != &"idle":
		return false
	# golpe/conjuração de verdade tocando (não a nossa): não interrompe
	if visual.has_method(&"get_oneshot"):
		var o: StringName = visual.call(&"get_oneshot")
		if not o.is_empty() and gesture.is_empty():
			return false
	# NPC fora do horário (apagado) não gesticula
	if &"presence" in visual and float(visual.get(&"presence")) < 0.5:
		return false
	return true


func _too_far() -> bool:
	if visual.has_method(&"is_offscreen") and bool(visual.call(&"is_offscreen")):
		return true
	var cam: Camera3D = visual.get_viewport().get_camera_3d() if visual.is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(visual.global_position) > CULL_M


func _camera_right() -> Vector3:
	var cam: Camera3D = visual.get_viewport().get_camera_3d() if visual.is_inside_tree() else null
	var r: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
	r.y = 0.0
	return r.normalized() if r.length() > 0.01 else Vector3.RIGHT


func _near_fire() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var me: Vector3 = visual.global_position
	for n: Node in get_tree().get_nodes_in_group(FIRE_GROUP):
		var p: Vector3 = (n as Node3D).global_position
		if Vector2(p.x - me.x, p.z - me.z).length() < FIRE_NEAR_M:
			return p
	return Vector3.ZERO


## Posição do jogador local (procura na irmandade de entidades a cada 1 s).
func _player_pos(delta: float) -> Variant:
	if player_override != null:
		return player_override
	_player_t -= delta
	if (_player == null or not is_instance_valid(_player)) and _player_t <= 0.0:
		_player_t = 1.0
		var entity: Node = visual.get_parent()
		var ents: Node = entity.get_parent() if entity != null else null
		if ents != null:
			for e: Node in ents.get_children():
				if e != entity and e.has_method(&"is_local_player") and bool(e.call(&"is_local_player")):
					_player = e as Node3D
					break
	return _player.global_position if _player != null and is_instance_valid(_player) else null
