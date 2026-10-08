class_name FollowerVisual
extends Node3D
## Seguidor local: não participa da replicação, seleção, colisão ou combate.
var owner_visual: EntityVisual
var definition: CompanionDef
var sprite: DirectionalSprite3D
var _position: Vector3 = Vector3.INF
var _path: Array[Vector2i] = []
var _repath: float = 0
var _light: OmniLight3D
var _strike_target: int = 0
var _strike_left: float = 0
var _name: Label3D
var _nickname: String = ""
var level: int = 1
## Nome da magia sobre o bicho (some depois de SPELL_LABEL_SEC).
var _spell_label: Label3D
var _spell_left: float = 0
## Cópias sem nome das magias (o SkillFx grita o nome sobre o conjurador = o dono; aqui o nome sai no bicho).
static var _quiet_defs: Dictionary[StringName, SkillDef] = {}
const SPELL_LABEL_SEC: float = 1.2
const SPELL_COLOR: Color = Color8(170, 246, 255)
## Vida com o dono parado (CompanionDef.idle_moves; só visual): um movimento sorteado a cada poucos segundos.
const IDLE_STILL_SEC: float = 0.8
const IDLE_GAP_MIN_SEC: float = 2.0
const IDLE_GAP_MAX_SEC: float = 5.0
const IDLE_MOVE_SPEED_CELLS: float = 1.6
const IDLE_SIDE_DEG: float = 55.0
const IDLE_ORBIT_DEG: float = 60.0
## Movimentos que trocam a folha (as life_* dos pets 2D começam e terminam paradas e duram a folha inteira).
const IDLE_ANIM_MOVES: Array[StringName] = [&"look", &"glide", &"sit", &"life_sit", &"life_lie", &"life_scratch",
		&"life_sniff", &"life_wag", &"life_spiral", &"life_split", &"life_pulse", &"life_orbit"]
var _owner_last: Vector3 = Vector3.INF
var _still_t: float = 0.0
var _move: StringName = &""
var _last_move: StringName = &""
var _move_t: float = 0.0
var _move_len: float = 0.0
var _next_move: float = 1.5
var _side: float = 0.0
var _drift: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
## Contadores para testes.
var strikes_seen: int = 0
var spells_seen: int = 0

func configure(owner_view: EntityVisual, def: CompanionDef, nickname: String, p_level: int = 1) -> void:
	owner_visual = owner_view
	definition = def
	_nickname = nickname
	level = maxi(1, p_level)
	sprite = DirectionalSprite3D.new()
	# Evolução visual (marcos 10/25/50): sem arte nova, o bicho cresce um pouco (só cosmético).
	sprite.visual_scale = CompanionService.visual_scale_for(def, level)
	sprite.life = DirectionalSprite3D.Life.BAKED
	# voador: altura de voo própria (a pet harpia paira atrás e acima do dono; o "atrás" é o behind de _process)
	sprite.extra_lift_m = def.fly_lift_m if def.flies else 0.0
	sprite.setup_sheets(def.sprite_base)
	add_child(sprite)
	_name = Label3D.new()
	_name.text = label_text(nickname, level)
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.position.y = 1.3
	_name.pixel_size = 0.013
	_name.font_size = 16
	add_child(_name)
	if def.id == CompanionService.LUME:
		_light = OmniLight3D.new()
		_light.light_color = Color(0.8, 1, 0.45)
		_light.light_energy = 0.8
		_light.omni_range = 4 * Balance.cfg.cell_size
		_light.shadow_enabled = false
		_light.position.y = 0.6
		add_child(_light)
	_spell_label = Label3D.new()
	_spell_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_spell_label.position.y = 1.65
	_spell_label.pixel_size = 0.013
	_spell_label.font_size = 15
	_spell_label.outline_size = 5
	_spell_label.modulate = SPELL_COLOR
	_spell_label.visible = false
	add_child(_spell_label)
	NetFollowers.companion_strike.connect(_on_strike)


static func label_text(nickname: String, p_level: int) -> String:
	var shown: String = nickname if not nickname.is_empty() else ""
	return (shown + " " if not shown.is_empty() else "") + TranslationServer.translate("COMPANION_LEVEL_SHORT") % p_level


func _on_strike(owner_id: int, target: int, id: StringName, spell: StringName = &"") -> void:
	var entity := owner_visual.get_parent() as NetEntity
	if entity == null or entity.entity_id != owner_id or definition.id != id:
		return
	strikes_seen += 1
	var sd: SkillDef = Content.companion_skill(spell) if not spell.is_empty() else null
	# Golpe: corre/mergulha até o alvo com a folha de ataque. Magia: folha de cast (ou ataque) e o efeito.
	if sd == null or (sd.effect == SkillDef.Effect.PHYSICAL_DAMAGE and target != owner_id):
		_strike_target = target
		_strike_left = 0.55
	if not sprite.play_oneshot(&"cast" if sd != null else &"attack") and not sprite.play_oneshot(&"attack"):
		sprite.play_lunge()
	if sd != null:
		spells_seen += 1
		_spell_label.text = tr(sd.name_key)
		_spell_label.visible = true
		_spell_left = SPELL_LABEL_SEC
		_play_spell_fx(sd, owner_id, target)


func _play_spell_fx(sd: SkillDef, owner_id: int, target: int) -> void:
	var fx: SkillFx = get_node_or_null(^"/root/NetCombat/SkillFx") as SkillFx
	if fx == null:
		return
	if not _quiet_defs.has(sd.id):
		var quiet: SkillDef = sd.duplicate() as SkillDef
		quiet.name_key = ""
		_quiet_defs[sd.id] = quiet
	var node: Node3D = NetCombat.find_entity(target)
	var pos: Vector3 = node.global_position if node != null else global_position
	fx.play(_quiet_defs[sd.id], owner_id, target, pos, 0)
	# Os golpes do bicho já não passam pelo SkillFx; o próximo ataque do dono volta a ser o básico.
	fx._recent.erase(owner_id)

func _process(delta: float) -> void:
	if owner_visual == null or definition == null:
		return
	var entity := owner_visual.get_parent() as NetEntity
	if entity == null:
		return
	var policy: int = GameSettings.get_instance().follower_visibility
	var zone: ZoneDef = Content.zone(Progression.map_of(entity.instance_id))
	visible = entity.hp_ratio > 0 and (zone == null or zone.pets_allowed) \
			and (owner_visual.is_local or policy == 0 or (policy == 1 and NetParty.is_member(entity.display_name)))
	if not visible:
		return
	var behind: Vector3 = Vector3(sin(entity.facing_yaw), 0, cos(entity.facing_yaw)) * 1.5 * Balance.cfg.cell_size
	var still: bool = _owner_last != Vector3.INF and entity.global_position.distance_to(_owner_last) < 0.001
	_owner_last = entity.global_position
	var goal: Vector3 = entity.global_position + behind + _idle_offset(delta, still, behind)
	if _position == Vector3.INF or _position.distance_to(entity.global_position) > Balance.cfg.follower_teleport_cells * Balance.cfg.cell_size:
		_position = goal
		_path.clear()
	if _spell_left > 0:
		_spell_left -= delta
		_spell_label.visible = _spell_left > 0
	if _strike_left > 0:
		_strike_left -= delta
		var target: Node3D = NetCombat.find_entity(_strike_target)
		if target != null and _strike_left > 0.25:
			goal = target.global_position
	var before: Vector3 = _position
	var speed: float = (6.0 if _move.is_empty() or _strike_left > 0 else IDLE_MOVE_SPEED_CELLS) * Balance.cfg.cell_size
	if definition.flies or _strike_left > 0:
		_position = _position.move_toward(goal, delta * speed)
	else:
		_repath -= delta
		var view: ClientView = get_tree().root.find_child("ClientView", true, false) as ClientView
		var grid: WalkGrid = view.get_walk_grid() if view != null else null
		if grid != null:
			if _repath <= 0:
				_repath = 0.4
				var start: Vector2i = grid.nearest_walkable(grid.world_to_cell(_position), 3)
				var finish: Vector2i = grid.nearest_walkable(grid.world_to_cell(goal), 3)
				if start.x >= 0 and finish.x >= 0:
					_path = GridPathfinder.find_path(grid, start, finish, 32)
					if not _path.is_empty():
						_path.pop_front()
			if not _path.is_empty():
				var next: Vector3 = grid.cell_to_world(_path[0])
				_position = _position.move_toward(next, speed * delta)
				if _position.distance_to(next) < 0.01:
					_path.pop_front()
	global_position = _position
	var moving: bool = before.distance_to(_position) > 0.001
	var shown: StringName = &"walk" if moving else &"idle"
	if _move in IDLE_ANIM_MOVES and (not moving or _move == &"glide") and sprite.has_anim(_move):
		shown = _move
	sprite.anim = shown
	if moving:
		var motion: Vector3 = _position - before
		sprite.facing_yaw = atan2(-motion.x, -motion.z)
	else:
		sprite.facing_yaw = entity.facing_yaw
	if _light != null:
		var map: StringName = Progression.map_of(entity.instance_id)
		_light.visible = owner_visual.is_local and (DayNight.is_night_on_map(map) or String(map).contains("cave"))
		sprite.position.y = 0.12 + sin(Time.get_ticks_msec() * 0.003) * 0.06


## Deslocamento do alvo "atrás do dono" pela vida com o dono parado. Dono andando: volta para trás dele.
func _idle_offset(delta: float, still: bool, behind: Vector3) -> Vector3:
	if definition.idle_moves.is_empty() or _strike_left > 0 or not still:
		_still_t = 0.0
		_move = &""
		_side = 0.0
		_drift = Vector3.ZERO
		_next_move = _rng.randf_range(1.0, 2.5)
		return Vector3.ZERO
	_still_t += delta
	if _still_t >= IDLE_STILL_SEC:
		if _move.is_empty():
			_next_move -= delta
			if _next_move <= 0.0:
				_start_idle_move()
		else:
			_move_t += delta
			if _move_t >= _move_len:
				if _move == &"orbit":
					_side = -(_side if _side != 0.0 else 1.0)
				_move = &""
				_drift = Vector3.ZERO
				_next_move = _rng.randf_range(IDLE_GAP_MIN_SEC, IDLE_GAP_MAX_SEC)
	var ang: float = _side * deg_to_rad(IDLE_SIDE_DEG)
	if _move == &"orbit":
		# volta curta POR TRAS do dono: de um lado ao outro (nunca passa na frente dele)
		var s0: float = _side if _side != 0.0 else 1.0
		ang = s0 * deg_to_rad(IDLE_ORBIT_DEG) * cos(clampf(_move_t / _move_len, 0.0, 1.0) * PI)
	return behind.rotated(Vector3.UP, ang) - behind + _drift


func _start_idle_move() -> void:
	var pool: Array[StringName] = []
	for m: StringName in definition.idle_moves:
		if m != _last_move and (not m in IDLE_ANIM_MOVES or sprite.has_anim(m)):
			pool.append(m)
	if pool.is_empty():
		_next_move = IDLE_GAP_MAX_SEC
		return
	_move = pool[_rng.randi() % pool.size()]
	_last_move = _move
	_move_t = 0.0
	var cell: float = Balance.cfg.cell_size
	match _move:
		&"swap_side":
			_side = -_side if _side != 0.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
			_move_len = 1.5
		&"drift", &"wander":
			_drift = Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.6, 0.6)) * cell
			_move_len = _rng.randf_range(1.5, 3.0)
		&"orbit":
			_move_len = 3.2
		&"look":
			_move_len = 2.4
		&"glide":
			_move_len = _rng.randf_range(2.0, 3.5)
		_:
			_move_len = _rng.randf_range(3.0, 5.0)
	if _move in DirectionalSprite3D.LIFE_ANIMS:
		# toca a folha uma vez inteira (quadros × tempo do quadro) e volta ao idle
		var frames: int = sprite.get_frame_count(_move)
		_move_len = sprite.get_frame_sec(_move, frames) * frames
