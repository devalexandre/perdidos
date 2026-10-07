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

func configure(owner_view: EntityVisual, def: CompanionDef, nickname: String) -> void:
	owner_visual = owner_view
	definition = def
	sprite = DirectionalSprite3D.new()
	sprite.visual_scale = def.visual_scale
	sprite.life = DirectionalSprite3D.Life.BAKED
	sprite.setup_sheets(def.sprite_base)
	add_child(sprite)
	_name = Label3D.new()
	_name.text = nickname
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
	NetFollowers.companion_strike.connect(_on_strike)

func _on_strike(owner_id: int, target: int, id: StringName) -> void:
	var entity := owner_visual.get_parent() as NetEntity
	if entity != null and entity.entity_id == owner_id and definition.id == id:
		_strike_target = target
		_strike_left = 0.55

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
	var goal: Vector3 = entity.global_position + behind
	if _position == Vector3.INF or _position.distance_to(entity.global_position) > Balance.cfg.follower_teleport_cells * Balance.cfg.cell_size:
		_position = goal
		_path.clear()
	if _strike_left > 0:
		_strike_left -= delta
		var target: Node3D = NetCombat.find_entity(_strike_target)
		if target != null and _strike_left > 0.25:
			goal = target.global_position
	var before: Vector3 = _position
	var speed: float = 6 * Balance.cfg.cell_size
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
	sprite.anim = &"walk" if moving else &"idle"
	if moving:
		var motion: Vector3 = _position - before
		sprite.facing_yaw = atan2(-motion.x, -motion.z)
	else:
		sprite.facing_yaw = entity.facing_yaw
	if _light != null:
		var map: StringName = Progression.map_of(entity.instance_id)
		_light.visible = owner_visual.is_local and (DayNight.is_night_on_map(map) or String(map).contains("cave"))
		sprite.position.y = 0.12 + sin(Time.get_ticks_msec() * 0.003) * 0.06
