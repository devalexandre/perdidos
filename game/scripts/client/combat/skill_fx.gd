class_name SkillFx
extends Node3D
## Efeitos visuais das skills no cliente (docs/briefing-sprites-personagem.md §4). Criado pelo NetCombat
## junto do CombatFx. Escuta NetProgress.skill_cast / cast_cancelled e NetCombat.hit e toca as folhas de
## assets/fx/skills/ (SkillFxSprite): rastro e impacto dos golpes, projéteis que voam até o alvo e
## explodem, áreas deitadas no chão com o raio da skill, cone e linha virados do conjurador para o
## ponto/alvo, e laços (aura, escudo, chamas, geada) que duram duration_sec e somem quando o alvo morre.
## A receita vem do id da skill; sem receita, do SkillDef.vfx (e do tipo de alvo). Só visual: nada
## aqui fala com o servidor. O som continua no CombatAudio.

const MSEC_PER_SEC: float = 1000.0
## Folga depois do lançamento em que os golpes do conjurador ainda são "da skill" (impactos, geada).
const HIT_WINDOW_SEC: float = 0.9
## Peças em pé no corpo: um pouco para a frente (câmera) para não entrar no sprite do personagem.
const FRONT_BIAS: float = 0.55
const BACK_BIAS: float = -0.45
const CHEST_FRACTION: float = 0.45
const HEAD_FRACTION: float = 1.02
const FALLBACK_HEIGHT: float = 1.6
const FLAT_LIFT: float = 0.08
# --- golpe firme
const STRIKE_DELAY_SEC: float = 0.12
const IMPACT_AFTER_SLASH_SEC: float = 0.1
# --- investida
const CHARGE_DUST_EVERY_SEC: float = 0.07
const CHARGE_DUST_SEC: float = 0.35
const CHARGE_IMPACT_SEC: float = 0.2
const DEFAULT_STUN_SEC: float = 0.8
# --- linha (Corte do Horizonte)
const WAVE_TRAVEL_SEC: float = 0.6
## Rastro: uma cópia da onda fica para trás a cada tanto e some (imagem residual).
const WAVE_ECHO_EVERY_SEC: float = 0.07
const WAVE_ECHO_FADE_SEC: float = 0.3
const WAVE_WIDTH_SCALE: float = 1.4
# --- projéteis (m/s)
const SPARK_SPEED: float = 18.0
const WISP_SPEED: float = 9.0
const WISP_BOB: float = 0.25
const MIN_FLIGHT_SEC: float = 0.08
# --- chamas no chão
const FLAME_TONGUES: int = 7
const FLAME_FILL: float = 0.8
# --- gelo
const FROST_CRYSTALS: int = 6
const FROST_WAVE_SPEED: float = 16.0
# --- estrela
const STAR_FALL_SEC: float = 0.7
const STAR_FROM: Vector3 = Vector3(-2.2, 7.0, -1.2)
# --- círculo de conjuração (arcano)
const CAST_CIRCLE_MIN_SEC: float = 0.1
# --- nome da skill gritado acima do conjurador (como os gritos dos MMOs clássicos), para todos
const SHOUT_FONT_SIZE: int = 13
const SHOUT_ABOVE_NAME: float = 0.62
const SHOUT_RISE: float = 0.35
const SHOUT_SEC: float = 1.2
const SHOUT_FADE_SEC: float = 0.45
## Abaixo dos números de dano (20) e acima das barras (9): nunca cobre um número.
const SHOUT_PRIORITY: int = 18
const SHOUT_OUTLINE: int = 5
const SHOUT_COLOR: Dictionary[StringName, Color] = {
	&"blade": Color8(244, 194, 82), &"arcane": Color8(80, 226, 214), &"bow": Color8(190, 204, 96),
	&"support": Color8(150, 222, 110), &"tank": Color8(214, 164, 92), &"hybrid": Color8(246, 140, 64)}
const SHOUT_COLOR_OTHER: Color = Color8(252, 250, 245)
## Raio (m) em que cada folha de área foi desenhada — a peça é escalada para o raio da skill.
const DESIGN_RADIUS: Dictionary[StringName, float] = {
	&"blade_clearing_sweep_arc": 3.0, &"blade_steel_spin_whirl": 3.0,
	&"arcane_creeping_flame_ground": 3.0, &"arcane_frost_burst_cone": 6.0, &"arcane_star_fall_impact": 4.0}

## Ofícios: a peça de cada um é <skill_id><CRAFT_PIECE_SUFFIX> (assets/fx/skills/, com .json).
const CRAFT_PIECE_SUFFIX: String = "_sparks"
const STEAL_PIECE: StringName = &"blade_pilfer_glint"
## Receita por skill; SkillDef.vfx é a reserva (RECIPE_BY_VFX + tipo de alvo).
const RECIPE_BY_SKILL: Dictionary[StringName, StringName] = {
	&"blade_firm_strike": &"strike", &"blade_charge": &"charge", &"blade_clearing_sweep": &"sweep",
	&"blade_horizon_cut": &"horizon", &"blade_steel_spin": &"spin", &"blade_iron_stance": &"stance",
	&"arcane_spark": &"spark", &"arcane_will_o_wisp": &"wisp", &"arcane_creeping_flame": &"flame",
	&"arcane_frost_burst": &"frost", &"arcane_star_fall": &"star", &"arcane_barrier": &"barrier",
	&"holy_light": &"holy", &"bow_fletching": &"craft",
	# Ofícios dos títulos (06/10/2026): peça <id>_sparks sobre o artesão; Surrupiar: brilho no alvo.
	&"blade_field_dressing": &"craft", &"arcane_bottle_light": &"craft", &"bow_poison_tips": &"craft",
	&"bow_feathering": &"craft", &"hybrid_ember_tips": &"craft", &"support_garrafada": &"craft",
	&"tank_shell_salve": &"craft", &"blade_pilfer": &"steal"}
const RECIPE_BY_VFX: Dictionary[StringName, StringName] = {
	&"slash": &"strike", &"spark": &"spark", &"wisp": &"wisp", &"flame": &"flame", &"frost": &"frost",
	&"star": &"star", &"shield": &"barrier", &"guard": &"stance"}

# --- Terra do Sabiá v0.4 (SkillFxBook): estados, cura, invisível, flecha do arco
## Altura (m) de onde caem os voos do céu (Mergulho do Gavião, Revoada).
const DROP_HEIGHT: float = 6.5
const ARROW_SPEED: float = 26.0
## Ataque básico com arco: a flecha voa do arqueiro ao alvo (attack_style do visual contém isto).
const BOW_STYLE_TAGS: Array[String] = ["bow", "arco"]
## Invisível (Lama no Corpo): meio transparente e puxado para o barro, para o próprio jogador e o grupo.
const STEALTH_TINT: Color = Color(0.82, 0.74, 0.62, 0.42)
## Folhinhas da cura: no máximo uma a cada tanto por alvo (cura contínua cura todo segundo).
const HEAL_FX_EVERY_SEC: float = 0.8
## Marcas sobre a cabeça: espaço entre elas (m) e altura (fração da altura do sprite).
const MARK_SPACING: float = 0.62
const MARK_HEAD: float = 1.0
## Laço do estado quando o sinal chega sem duração.
const DEFAULT_LOOK_SEC: float = 2.0
const MARK_PIECE_PREFIX: String = "status_mark_"
## Brasa (dano contínuo de fogo): língua de fogo pequena nos pés.
const BURN_PIECE: StringName = &"arcane_creeping_flame_tongue"
const BURN_SCALE: float = 0.55
## Aviso no chão antes do impacto (Queda Estelar): sombra da pedra-estrela com o chão rachando.
const WARNING_PIECE: StringName = &"arcane_star_fall_warning"
const WARNING_DESIGN_RADIUS: float = 4.0
const WARNING_START_SCALE: float = 0.45
## Projétil que sai para fora / volta (burst / converge).
const BURST_SPEED: float = 10.0

## Resolve entity_id -> Node3D (testes trocam por um dublê).
var find_entity: Callable = Callable()
## Contadores para testes.
var effects_started: int = 0
var pieces_spawned: int = 0
var last_recipe: StringName = &""
var shouts_spawned: int = 0
var last_shout_text: String = ""

var _clock: float = 0.0
## Ações agendadas: {at, caster, fn}.
var _queue: Array[Dictionary] = []
## Voos (projéteis, estrela, onda): {sprite, from, target, to, t, dur, bob, arrive}.
var _flights: Array[Dictionary] = []
## Última skill por conjurador: {def, recipe, until}.
var _recent: Dictionary[int, Dictionary] = {}
var _cast_circles: Dictionary[int, SkillFxSprite] = {}
## Laços por entidade e chave (aura, escudo, geada): relançar reinicia.
var _loops: Dictionary[String, Array] = {}
## Estados ativos por entidade: chave do laço -> {status_id|skill_id: true} (o laço some quando esvazia).
var _status: Dictionary[int, Dictionary] = {}
## Invisíveis (a tinta é reaplicada todo quadro: o hover do EntityVisual troca a tinta).
var _stealth: Dictionary[int, bool] = {}
var _last_heal_fx: Dictionary[int, float] = {}
## Contadores para testes.
var statuses_seen: int = 0
var heals_seen: int = 0
var bow_arrows: int = 0


func _ready() -> void:
	# Portais dos mapas (PortalFx): o cliente troca a malha antiga pelo redemoinho no chão.
	var deco := PortalDecorator.new()
	deco.name = &"PortalDecorator"
	add_child(deco)
	if not find_entity.is_valid():
		var net: Node = get_node_or_null(^"/root/NetCombat")
		if net != null:
			find_entity = Callable(net, &"find_entity")
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null:
		if prog.has_signal(&"skill_cast"):
			prog.connect(&"skill_cast", _on_skill_cast)
		if prog.has_signal(&"cast_cancelled"):
			prog.connect(&"cast_cancelled", _on_cast_cancelled)
		# Contrato do servidor (Terra do Sabiá v0.4): conecta só se o sinal existir.
		if prog.has_signal(&"status_changed"):
			prog.connect(&"status_changed", _on_status_changed)
	var net2: Node = get_node_or_null(^"/root/NetCombat")
	if net2 != null and net2.has_signal(&"hit"):
		net2.connect(&"hit", _on_hit)
	if net2 != null and net2.has_signal(&"healed"):
		net2.connect(&"healed", _on_healed)


## Peças vivas (não em remoção) — para testes.
func active_pieces() -> int:
	var n: int = 0
	for c: Node in get_children():
		if c is SkillFxSprite and not c.is_queued_for_deletion():
			n += 1
	return n


static func recipe_for(def: SkillDef) -> StringName:
	if def == null:
		return &""
	if RECIPE_BY_SKILL.has(def.id):
		return RECIPE_BY_SKILL[def.id]
	if SkillFxBook.BOOK.has(def.id):
		return &"book"
	var r: StringName = RECIPE_BY_VFX.get(def.vfx, &"")
	if r == &"strike":
		match def.target_type:
			SkillDef.TargetType.CONE:
				return &"sweep"
			SkillDef.TargetType.LINE:
				return &"horizon"
			SkillDef.TargetType.SELF_AREA:
				return &"spin"
	return r


# ================================================================ eventos

func _on_skill_cast(entity_id: int, skill_id: StringName, target_entity_id: int, pos: Vector3,
		cast_ms: int) -> void:
	play(Content.skill(skill_id), entity_id, target_entity_id, pos, cast_ms)


func _on_cast_cancelled(entity_id: int, _skill_id: StringName) -> void:
	_queue = _queue.filter(func(q: Dictionary) -> bool: return q["caster"] != entity_id)
	var c: Variant = _cast_circles.get(entity_id)
	if is_instance_valid(c):
		(c as SkillFxSprite).stop(0.15)
	_cast_circles.erase(entity_id)
	_recent.erase(entity_id)


func _on_hit(source_id: int, target_id: int, amount: int, _crit: bool, _damage_type: int,
		_target_hp_ratio: float) -> void:
	var target: Node3D = _entity(target_id)
	if target == null or amount < 0:
		return
	var r: Dictionary = _recent.get(source_id, {})
	if r.is_empty() or _clock > float(r["until"]):
		_basic_hit(source_id, target_id, target)
		return
	var def: SkillDef = r["def"]
	match r["recipe"]:
		&"book":
			var hp: StringName = SkillFxBook.HIT.get(def.id, &"")
			if hp != &"":
				_upright(hp, target, _height(target) * CHEST_FRACTION, FRONT_BIAS)
		&"sweep", &"horizon", &"spin":
			_upright(&"blade_firm_strike_impact", target, _height(target) * CHEST_FRACTION, FRONT_BIAS)
		&"star":
			_upright(&"arcane_spark_impact", target, _height(target) * CHEST_FRACTION, FRONT_BIAS)
		&"frost":
			_loop_on(target_id, &"chill", [&"arcane_frost_burst_chill"], target, def.duration_sec,
					[0.0], [FRONT_BIAS])


# ================================================================ entrada principal

## Toca o efeito da skill. cast_ms = conjuração + aviso no chão (como no sinal skill_cast).
func play(def: SkillDef, caster_id: int, target_id: int, pos: Vector3, cast_ms: int) -> bool:
	if def == null:
		return false
	var recipe: StringName = recipe_for(def)
	if recipe == &"":
		var c0: Node3D = _entity(caster_id)
		if c0 != null:
			shout(def, c0)
		return false
	effects_started += 1
	last_recipe = recipe
	var delay: float = maxf(cast_ms / MSEC_PER_SEC, 0.0)
	var cast_part: float = maxf(delay - def.ground_warning_sec, 0.0)
	var caster: Node3D = _entity(caster_id)
	if caster != null:
		shout(def, caster)
	var extra: float = def.duration_sec if def.effect == SkillDef.Effect.DAMAGE_OVER_TIME else 0.0
	_recent[caster_id] = {"def": def, "recipe": recipe, "until": _clock + delay + HIT_WINDOW_SEC + extra}
	if def.school == &"arcane" and cast_part >= CAST_CIRCLE_MIN_SEC and caster != null:
		_cast_circle(caster_id, caster, cast_part)
	var ctx: Dictionary = {"def": def, "caster_id": caster_id, "target_id": target_id, "pos": pos,
		"delay": delay, "cast_part": cast_part}
	if def.ground_warning_sec > 0.0:
		_later(cast_part, caster_id, _warning.bind(ctx))
	match recipe:
		&"book":
			_book(ctx)
		&"strike":
			_later(delay + STRIKE_DELAY_SEC, caster_id, _strike.bind(ctx))
		&"charge":
			_later(delay, caster_id, _charge.bind(ctx))
		&"sweep":
			_later(delay, caster_id, _sweep.bind(ctx))
		&"horizon":
			_later(delay, caster_id, _horizon.bind(ctx))
		&"spin":
			_later(delay, caster_id, _spin.bind(ctx))
		&"stance":
			_later(delay, caster_id, _stance.bind(ctx))
		&"spark":
			_later(delay, caster_id, _projectile.bind(ctx, &"arcane_spark_projectile", &"arcane_spark_impact",
					SPARK_SPEED, 0.0))
		&"craft":
			# Ofícios: <skill>_sparks sobre o artesão (faíscas de bigorna ou folhas da cura recoloridas).
			_later(delay, caster_id, _craft_sparks.bind(ctx))
		&"steal":
			_later(delay, caster_id, _steal_glint.bind(ctx))
		&"holy":
			# Luz Sagrada: a faísca recolorida em dourado (holy_light_*.png + .json).
			_later(delay, caster_id, _projectile.bind(ctx, &"holy_light_projectile", &"holy_light_impact",
					SPARK_SPEED, 0.0))
		&"wisp":
			_later(delay, caster_id, _projectile.bind(ctx, &"arcane_will_o_wisp_projectile",
					&"arcane_will_o_wisp_impact", WISP_SPEED, WISP_BOB))
		&"flame":
			_later(delay, caster_id, _flame.bind(ctx))
		&"frost":
			_later(delay, caster_id, _frost.bind(ctx))
		&"star":
			_later(maxf(delay - STAR_FALL_SEC, cast_part), caster_id, _star.bind(ctx))
		&"barrier":
			_later(delay, caster_id, _barrier.bind(ctx))
	return true


## Nome traduzido da skill acima do conjurador: sobe um pouco e some (~1,2 s). Visto por todos da instância.
func shout(def: SkillDef, caster: Node3D) -> Label3D:
	var l := Label3D.new()
	l.name = &"SkillShout"
	l.text = tr(def.name_key)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.pixel_size = DirectionalSprite3D.world_text_pixel_size()
	l.font = UIKit.world_font()
	l.font_size = roundi(SHOUT_FONT_SIZE * DirectionalSprite3D.world_text_font_scale())
	l.outline_size = SHOUT_OUTLINE
	l.outline_modulate = UIKit.COLOR_OUTLINE
	l.modulate = SHOUT_COLOR.get(SkillFxBook.school_of(def), SHOUT_COLOR_OTHER)
	l.no_depth_test = true
	l.shaded = false
	l.render_priority = SHOUT_PRIORITY
	l.outline_render_priority = SHOUT_PRIORITY - 1
	add_child(l)
	var start: Vector3 = caster.global_position + Vector3.UP * (_name_height(caster) + SHOUT_ABOVE_NAME)
	l.global_position = start
	l.scale = Vector3.ONE * 0.6
	var tw: Tween = l.create_tween()
	tw.tween_property(l, ^"scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, ^"global_position", start + Vector3.UP * SHOUT_RISE, SHOUT_SEC)
	tw.parallel().tween_property(l, ^"modulate:a", 0.0, SHOUT_FADE_SEC).set_delay(SHOUT_SEC - SHOUT_FADE_SEC)
	tw.tween_callback(l.queue_free)
	shouts_spawned += 1
	last_shout_text = l.text
	return l


func _name_height(e: Node3D) -> float:
	var v: Node = e.get_node_or_null(^"Visual")
	if v is EntityVisual and (v as EntityVisual).get_nameplate() != null:
		return (v as EntityVisual).get_nameplate().position.y
	return _height(e) + 0.2


# ================================================================ receitas

func _strike(ctx: Dictionary) -> void:
	var target: Node3D = _entity(ctx["target_id"])
	if target == null:
		return
	var h: float = _height(target)
	var slash: SkillFxSprite = _upright(&"blade_firm_strike_slash", target, h * CHEST_FRACTION, FRONT_BIAS)
	if slash != null and randf() < 0.5:
		slash.set_flip(true) # golpe ora da esquerda, ora da direita
	_later(IMPACT_AFTER_SLASH_SEC, int(ctx["caster_id"]), func() -> void:
		var t: Node3D = _entity(ctx["target_id"])
		if t != null:
			_upright(&"blade_firm_strike_impact", t, _height(t) * CHEST_FRACTION, FRONT_BIAS))


func _charge(ctx: Dictionary) -> void:
	var caster_id: int = ctx["caster_id"]
	var n: int = int(CHARGE_DUST_SEC / CHARGE_DUST_EVERY_SEC) + 1
	for i: int in n:
		_later(i * CHARGE_DUST_EVERY_SEC, caster_id, func() -> void:
			var c: Node3D = _entity(caster_id)
			if c != null:
				_at(&"blade_charge_dust", c.global_position, 0.0))
	var def: SkillDef = ctx["def"]
	var stun: float = float(def.extra.get(&"stun_sec", DEFAULT_STUN_SEC))
	_later(CHARGE_IMPACT_SEC, caster_id, func() -> void:
		var t: Node3D = _entity(ctx["target_id"])
		if t == null:
			return
		var h: float = _height(t)
		_upright(&"blade_charge_impact", t, h * CHEST_FRACTION, FRONT_BIAS)
		_loop_on(int(ctx["target_id"]), &"stun", [&"blade_charge_stun"], t, stun, [h * HEAD_FRACTION], [FRONT_BIAS]))


func _sweep(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	var origin: Vector3 = c.global_position if c != null else ctx["pos"]
	var s: SkillFxSprite = _flat(&"blade_clearing_sweep_arc", origin, _radius(ctx["def"]))
	if s != null:
		s.face_ground_dir(_dir(origin, ctx))


func _horizon(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	var origin: Vector3 = c.global_position if c != null else ctx["pos"]
	var def: SkillDef = ctx["def"]
	var dir: Vector3 = _dir(origin, ctx)
	var length: float = maxf(def.line_length_cells, 1.0) * _cell()
	var s: SkillFxSprite = _flat(&"blade_horizon_cut_wave", origin, 0.0)
	if s == null:
		return
	var k: float = maxf(def.line_width_cells, 1.0) * _cell() / 2.0 * WAVE_WIDTH_SCALE
	s.scale = Vector3.ONE * k
	s.face_ground_dir(dir)
	s.life_sec = WAVE_TRAVEL_SEC + 0.2
	var from: Vector3 = origin + Vector3.UP * FLAT_LIFT
	_fly(s, from, null, from + dir * length, WAVE_TRAVEL_SEC, 0.0, Callable())
	var echoes: int = int(WAVE_TRAVEL_SEC / WAVE_ECHO_EVERY_SEC)
	for i: int in range(1, echoes):
		var u: float = float(i) / echoes
		_later(WAVE_TRAVEL_SEC * u, int(ctx["caster_id"]), func() -> void:
			var e: SkillFxSprite = _flat(&"blade_horizon_cut_wave", origin + dir * length * u, 0.0)
			if e != null:
				e.scale = Vector3.ONE * k * 0.92
				e.face_ground_dir(dir)
				e.frame_offset = i
				e.stop(WAVE_ECHO_FADE_SEC))
	for i: int in 3:
		_later(WAVE_TRAVEL_SEC * (i + 1) / 4.0, int(ctx["caster_id"]), func() -> void:
			_at(&"blade_charge_dust", origin + dir * length * (i + 1) / 4.0, 0.0))


func _spin(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	if c == null:
		_flat(&"blade_steel_spin_whirl", ctx["pos"], _radius(ctx["def"]))
		return
	var s: SkillFxSprite = _flat(&"blade_steel_spin_whirl", c.global_position, _radius(ctx["def"]))
	if s != null:
		s.follow = c
		s.follow_offset = Vector3.UP * FLAT_LIFT


func _craft_sparks(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	if c != null:
		_upright(StringName(String((ctx["def"] as SkillDef).id) + CRAFT_PIECE_SUFFIX), c, 0.0, FRONT_BIAS)


## Surrupiar: brilho dourado no peito do monstro (a mão leve passou por ali).
func _steal_glint(ctx: Dictionary) -> void:
	var t: Node3D = _entity(ctx["target_id"])
	if t != null:
		_upright(STEAL_PIECE, t, _height(t) * CHEST_FRACTION, FRONT_BIAS)
	else:
		_at(STEAL_PIECE, ctx["pos"] + Vector3.UP * 0.5, FRONT_BIAS)


func _stance(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	if c == null:
		return
	var def: SkillDef = ctx["def"]
	_loop_on(ctx["caster_id"], &"stance",
			[&"blade_iron_stance_back", &"blade_iron_stance_glow", &"blade_iron_stance_front"], c,
			def.duration_sec, [0.0, 0.0, 0.0], [BACK_BIAS, FRONT_BIAS * 0.5, FRONT_BIAS])


func _projectile(ctx: Dictionary, fly_piece: StringName, impact_piece: StringName, speed: float,
		bob: float) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	var t: Node3D = _entity(ctx["target_id"])
	var to: Vector3 = ctx["pos"]
	if t != null:
		to = t.global_position + Vector3.UP * _height(t) * CHEST_FRACTION
	var from: Vector3 = to
	if c != null:
		from = c.global_position + Vector3.UP * _height(c) * CHEST_FRACTION
	var s: SkillFxSprite = SkillFxSprite.create(fly_piece)
	if s == null:
		return
	_add(s, from)
	s.set_depth_bias(FRONT_BIAS)
	s.orient_dir = (to - from) if (to - from).length() > 0.01 else Vector3.RIGHT
	var dur: float = maxf(from.distance_to(to) / speed, MIN_FLIGHT_SEC)
	var target_id: int = ctx["target_id"]
	_fly(s, from, t, to, dur, bob, func(at: Vector3) -> void:
		var tt: Node3D = _entity(target_id)
		if tt != null:
			_upright(impact_piece, tt, _height(tt) * CHEST_FRACTION, FRONT_BIAS)
		else:
			_at(impact_piece, at, FRONT_BIAS))


func _flame(ctx: Dictionary) -> void:
	var def: SkillDef = ctx["def"]
	var pos: Vector3 = ctx["pos"]
	var r: float = _radius(def)
	var g: SkillFxSprite = _flat(&"arcane_creeping_flame_ground", pos, r)
	if g != null:
		g.life_sec = def.duration_sec
		g.fade_in_sec = 0.2
		g.fade_out_sec = 0.5
	for i: int in FLAME_TONGUES:
		var a: float = TAU * i / FLAME_TONGUES + randf_range(-0.3, 0.3)
		var d: float = r * FLAME_FILL * sqrt(randf_range(0.05, 1.0)) if i > 0 else 0.0
		var p: Vector3 = pos + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var s: SkillFxSprite = SkillFxSprite.create(&"arcane_creeping_flame_tongue")
		if s == null:
			return
		s.frame_offset = randi() % s.frames
		s.life_sec = def.duration_sec - randf_range(0.0, 0.4)
		s.fade_in_sec = 0.15 + 0.05 * i
		s.fade_out_sec = 0.4
		if randf() < 0.5:
			s.set_flip(true)
		_add(s, p)


func _frost(ctx: Dictionary) -> void:
	var c: Node3D = _entity(ctx["caster_id"])
	var origin: Vector3 = c.global_position if c != null else ctx["pos"]
	var def: SkillDef = ctx["def"]
	var dir: Vector3 = _dir(origin, ctx)
	var r: float = _radius(def)
	var s: SkillFxSprite = _flat(&"arcane_frost_burst_cone", origin, r)
	if s != null:
		s.face_ground_dir(dir)
	var half: float = deg_to_rad(maxf(def.cone_deg, 10.0)) * 0.5
	for i: int in FROST_CRYSTALS:
		var d: float = lerpf(r * 0.25, r * 0.85, float(i) / maxf(FROST_CRYSTALS - 1, 1))
		var a: float = randf_range(-half * 0.75, half * 0.75)
		var p: Vector3 = origin + dir.rotated(Vector3.UP, a) * d
		_later(d / FROST_WAVE_SPEED, int(ctx["caster_id"]), func() -> void:
			var cr: SkillFxSprite = _at(&"arcane_frost_burst_crystal", p, 0.0)
			if cr != null and randf() < 0.5:
				cr.set_flip(true))


func _star(ctx: Dictionary) -> void:
	var def: SkillDef = ctx["def"]
	var pos: Vector3 = ctx["pos"]
	var fall: float = minf(STAR_FALL_SEC, maxf(float(ctx["delay"]) - float(ctx["cast_part"]), MIN_FLIGHT_SEC)) \
			if def.ground_warning_sec > 0.0 else MIN_FLIGHT_SEC * 3.0
	var s: SkillFxSprite = SkillFxSprite.create(&"arcane_star_fall_star")
	if s == null:
		return
	var from: Vector3 = pos + STAR_FROM
	_add(s, from)
	s.orient_dir = pos - from
	_fly(s, from, null, pos, fall, 0.0, func(_at_pos: Vector3) -> void:
		_flat(&"arcane_star_fall_impact", pos, _radius(def))
		_at(&"arcane_star_fall_burst", pos, 0.2))


func _barrier(ctx: Dictionary) -> void:
	var tid: int = ctx["target_id"] if int(ctx["target_id"]) > 0 else ctx["caster_id"]
	var t: Node3D = _entity(tid)
	if t == null:
		return
	var def: SkillDef = ctx["def"]
	var loops: Array = _loop_on(tid, &"barrier", [&"arcane_barrier_shield"], t, def.duration_sec, [0.0],
			[FRONT_BIAS])
	for s: SkillFxSprite in loops:
		s.scale = Vector3.ONE * 0.2
		s.create_tween().tween_property(s, ^"scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)


func _cast_circle(caster_id: int, caster: Node3D, sec: float) -> void:
	var old: Variant = _cast_circles.get(caster_id)
	if is_instance_valid(old):
		(old as SkillFxSprite).stop(0.1)
	var s: SkillFxSprite = _flat(&"arcane_cast_circle", caster.global_position, 0.0)
	if s == null:
		return
	s.follow = caster
	s.follow_offset = Vector3.UP * FLAT_LIFT
	s.life_sec = sec
	s.fade_in_sec = 0.12
	s.fade_out_sec = 0.2
	_cast_circles[caster_id] = s


# ================================================================ peças

func _add(s: SkillFxSprite, at: Vector3) -> void:
	add_child(s)
	s.global_position = at
	pieces_spawned += 1


## Peça em pé presa a uma entidade (segue e some com ela).
func _upright(piece: StringName, target: Node3D, height: float, bias: float) -> SkillFxSprite:
	var s: SkillFxSprite = SkillFxSprite.create(piece)
	if s == null:
		return null
	s.follow = target
	s.follow_offset = Vector3.UP * height
	_add(s, target.global_position + s.follow_offset)
	s.set_depth_bias(bias)
	return s


## Peça em pé num ponto fixo.
func _at(piece: StringName, at: Vector3, bias: float) -> SkillFxSprite:
	var s: SkillFxSprite = SkillFxSprite.create(piece)
	if s == null:
		return null
	_add(s, at)
	s.set_depth_bias(bias)
	return s


## Peça deitada no chão; radius > 0 escala a folha para o raio da skill.
func _flat(piece: StringName, at: Vector3, radius: float) -> SkillFxSprite:
	var s: SkillFxSprite = SkillFxSprite.create(piece)
	if s == null:
		return null
	if radius > 0.0 and DESIGN_RADIUS.has(piece):
		s.scale = Vector3.ONE * radius / DESIGN_RADIUS[piece]
	_add(s, at + Vector3.UP * FLAT_LIFT)
	return s


## Laço preso a uma entidade (uma ou mais peças em camadas). Relançar reinicia.
func _loop_on(entity_id: int, key: StringName, pieces: Array, target: Node3D, sec: float, heights: Array,
		biases: Array) -> Array:
	var k: String = "%d:%s" % [entity_id, key]
	# Mesmo laço ainda vivo (ex.: o lançamento e depois o status_changed do servidor): só estica o tempo.
	var olds: Array = _loops.get(k, [])
	var same: bool = olds.size() == pieces.size() and not olds.is_empty()
	for i: int in olds.size():
		var o: Variant = olds[i]
		if not is_instance_valid(o) or (o as SkillFxSprite).is_stopping() or (o as SkillFxSprite).piece != pieces[i]:
			same = false
			break
	if same:
		for o: SkillFxSprite in olds:
			o.life_sec = o.elapsed + maxf(sec, 0.3)
		return olds
	for old: Variant in olds:
		if is_instance_valid(old):
			(old as SkillFxSprite).stop(0.1)
	var out: Array = []
	for i: int in pieces.size():
		var s: SkillFxSprite = _upright(pieces[i], target, heights[i], biases[i])
		if s == null:
			continue
		s.life_sec = maxf(sec, 0.3)
		s.fade_in_sec = 0.15
		s.fade_out_sec = 0.3
		out.append(s)
	_loops[k] = out
	return out


func _fly(s: SkillFxSprite, from: Vector3, target: Node3D, to: Vector3, dur: float, bob: float,
		arrive: Callable) -> void:
	_flights.append({"sprite": s, "from": from, "target": target, "to": to, "t": 0.0, "dur": dur,
		"bob": bob, "arrive": arrive})


# ================================================================ tempo

func _later(sec: float, caster_id: int, fn: Callable) -> void:
	if sec <= 0.0:
		fn.call()
		return
	_queue.append({"at": _clock + sec, "caster": caster_id, "fn": fn})


func _process(delta: float) -> void:
	_clock += delta
	for eid: int in _stealth.keys():
		var e: Node3D = _entity(eid)
		if e == null:
			_stealth.erase(eid)
			continue
		var v: Node = e.get_node_or_null(^"Visual")
		if v != null and v.has_method(&"set_tint"):
			v.call(&"set_tint", Color(1.25,1.1,0.7) if NetFollowers.is_revealed(eid) else STEALTH_TINT)
	if not _queue.is_empty():
		var due: Array[Dictionary] = []
		var keep: Array[Dictionary] = []
		for q: Dictionary in _queue:
			(due if _clock >= float(q["at"]) else keep).append(q)
		_queue = keep
		for q: Dictionary in due:
			(q["fn"] as Callable).call()
	var done: Array[int] = []
	for i: int in _flights.size():
		var f: Dictionary = _flights[i]
		var s: SkillFxSprite = f["sprite"]
		if not is_instance_valid(s):
			done.append(i)
			continue
		var tgt: Node3D = f["target"]
		var to: Vector3 = f["to"]
		if tgt != null and is_instance_valid(tgt) and tgt.is_inside_tree():
			to = tgt.global_position + Vector3.UP * _height(tgt) * CHEST_FRACTION
			f["to"] = to
		f["t"] = float(f["t"]) + delta
		var u: float = clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		var from: Vector3 = f["from"]
		var p: Vector3 = from.lerp(to, u)
		p.y += sin(u * PI) * float(f["bob"]) + sin(float(f["t"]) * 14.0) * float(f["bob"]) * 0.3
		s.global_position = p
		if s.orient_dir != Vector3.ZERO and (to - p).length() > 0.05:
			s.orient_dir = to - p
		if u >= 1.0:
			done.append(i)
			var arrive: Callable = f["arrive"]
			if arrive.is_valid():
				arrive.call(to)
				s.queue_free()
			else:
				s.stop(0.15)
	for j: int in range(done.size() - 1, -1, -1):
		_flights.remove_at(done[j])


# ================================================================ util

func _entity(entity_id: int) -> Node3D:
	if entity_id <= 0 or not find_entity.is_valid():
		return null
	var e: Variant = find_entity.call(entity_id)
	return e as Node3D if e is Node3D and is_instance_valid(e) else null


func _height(e: Node3D) -> float:
	var v: Node = e.get_node_or_null(^"Visual")
	if v is DirectionalSprite3D:
		var h: float = (v as DirectionalSprite3D).get_world_height()
		if h > 0.1:
			return h
	return FALLBACK_HEIGHT


func _cell() -> float:
	return Balance.cfg.cell_size if Balance.cfg != null else 1.0


func _radius(def: SkillDef) -> float:
	return def.radius_cells * _cell()


## Direção do conjurador para o ponto (cone/linha: pos = conjurador + dir; alvo, se houver).
func _dir(origin: Vector3, ctx: Dictionary) -> Vector3:
	var p: Vector3 = ctx["pos"]
	var t: Node3D = _entity(ctx["target_id"])
	var d := Vector3(p.x - origin.x, 0.0, p.z - origin.z)
	if d.length() < 0.2 and t != null:
		d = Vector3(t.global_position.x - origin.x, 0.0, t.global_position.z - origin.z)
	if d.length() < 0.01:
		var c: Node3D = _entity(ctx["caster_id"])
		var yaw: Variant = c.get(&"facing_yaw") if c != null else null
		d = Vector3(-sin(float(yaw)), 0.0, -cos(float(yaw))) if yaw != null else Vector3.FORWARD
	return d.normalized()


# ================================================================ Terra do Sabiá v0.4 (SkillFxBook)

## Aviso no chão antes do impacto (ground_warning_sec): a sombra cresce até o raio e some no impacto.
func _warning(ctx: Dictionary) -> void:
	var def: SkillDef = ctx["def"]
	var r: float = maxf(_radius(def), _cell())
	var s: SkillFxSprite = _flat(WARNING_PIECE, ctx["pos"], 0.0)
	if s == null:
		return
	var k: float = r / WARNING_DESIGN_RADIUS
	s.life_sec = maxf(def.ground_warning_sec, 0.2)
	s.fade_in_sec = 0.15
	s.fade_out_sec = 0.15
	s.scale = Vector3.ONE * k * WARNING_START_SCALE
	s.create_tween().tween_property(s, ^"scale", Vector3.ONE * k, s.life_sec).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)


## Toca a receita do livro: cada passo no seu tempo (conjuração + "delay").
func _book(ctx: Dictionary) -> void:
	var def: SkillDef = ctx["def"]
	var caster_id: int = ctx["caster_id"]
	var delay: float = ctx["delay"]
	for step: Dictionary in SkillFxBook.BOOK.get(def.id, []):
		var kind: String = step.get("do", "")
		if kind == "cast":
			if float(ctx["cast_part"]) > 0.05:
				_later(0.0, caster_id, _step_cast.bind(ctx, step))
			continue
		_later(delay + float(step.get("delay", 0.0)), caster_id, _step.bind(ctx, step))


func _step(ctx: Dictionary, step: Dictionary) -> void:
	var def: SkillDef = ctx["def"]
	var caster_id: int = ctx["caster_id"]
	var c: Node3D = _entity(caster_id)
	var pos: Vector3 = ctx["pos"]
	var piece: StringName = step.get("piece", &"")
	var bias: float = float(step.get("bias", FRONT_BIAS))
	match String(step.get("do", "")):
		"self":
			if c == null:
				return
			var s: SkillFxSprite = _upright(piece, c, _height(c) * float(step.get("h", 0.0)), bias)
			if s != null and step.has("ahead"):
				s.follow = null
				s.global_position = c.global_position + _dir(c.global_position, ctx) * float(step["ahead"])
		"at_caster_pos":
			if c != null:
				_at(piece, c.global_position, bias)
		"on_target":
			var t: Node3D = _entity(ctx["target_id"])
			if t == null:
				t = c
			if t == null:
				_at(piece, pos, bias)
				return
			var s2: SkillFxSprite = _upright(piece, t, _height(t) * float(step.get("h", 0.0)), bias)
			if s2 != null and bool(step.get("flip", false)) and randf() < 0.5:
				s2.set_flip(true)
		"at_pos":
			_at(piece, pos, bias)
		"flat_self", "flat_pos":
			var at: Vector3 = pos
			if String(step["do"]) == "flat_self":
				if c == null:
					return
				at = c.global_position
			var s3: SkillFxSprite = _flat(piece, at, 0.0)
			if s3 == null:
				return
			_scale_to_radius(s3, def, step)
			if String(step["do"]) == "flat_self" and bool(step.get("follow", true)):
				s3.follow = c
				s3.follow_offset = Vector3.UP * FLAT_LIFT
			if step.get("life", "") == "dur":
				s3.life_sec = maxf(def.duration_sec, 0.5)
				s3.fade_in_sec = 0.2
				s3.fade_out_sec = 0.5
		"flat_dir":
			var origin: Vector3 = c.global_position if c != null else pos
			var s4: SkillFxSprite = _flat(piece, origin, 0.0)
			if s4 != null:
				_scale_to_radius(s4, def, step)
				s4.face_ground_dir(_dir(origin, ctx))
		"beam":
			_step_beam(ctx, step, c)
		"travel":
			_step_travel(ctx, step, c)
		"shot":
			var n: int = int(step.get("count", 1))
			for i: int in n:
				_later(float(step.get("every", 0.0)) * i, caster_id, _step_shot.bind(ctx, step, i))
		"drop":
			_step_drop(ctx, step)
		"scatter":
			_step_scatter(ctx, step, c)
		"ring":
			if c == null:
				return
			var n2: int = int(step.get("n", 6))
			var rr: float = maxf(_radius(def), _cell()) * float(step.get("r", 1.0))
			var life: float = maxf(def.duration_sec, 1.0)
			for i: int in n2:
				var a: float = TAU * i / n2
				var s5: SkillFxSprite = _at(piece, c.global_position + Vector3(cos(a), 0.0, sin(a)) * rr, 0.0)
				if s5 != null:
					s5.life_sec = life
					s5.fade_out_sec = 0.4
					s5.frame_offset = 0
		"burst", "converge":
			if c == null:
				return
			var n3: int = int(step.get("n", 3))
			var dist: float = float(step.get("dist", 2.0))
			var chest: Vector3 = c.global_position + Vector3.UP * _height(c) * CHEST_FRACTION
			for i: int in n3:
				var a2: float = TAU * i / n3 + randf_range(-0.3, 0.3)
				var far: Vector3 = chest + Vector3(cos(a2), 0.0, sin(a2)) * dist
				var out: bool = String(step["do"]) == "burst"
				var s6: SkillFxSprite = SkillFxSprite.create(piece)
				if s6 == null:
					return
				_add(s6, chest if out else far)
				s6.set_depth_bias(FRONT_BIAS)
				s6.orient_dir = (far - chest) if out else (chest - far)
				_fly(s6, chest if out else far, null if out else c, far if out else chest, dist / BURST_SPEED, 0.2,
						Callable())
		"dash_trail":
			var every: float = maxf(float(step.get("every", 0.07)), 0.02)
			var nn: int = int(float(step.get("sec", 0.35)) / every) + 1
			for i: int in nn:
				_later(i * every, caster_id, func() -> void:
					var cc: Node3D = _entity(caster_id)
					if cc != null:
						_at(piece, cc.global_position, 0.0))
		"loop_self":
			if c == null:
				return
			var loops: Array = _loop_on(caster_id, StringName("fx:" + String(piece)), [piece], c,
					float(step.get("sec", 1.0)), [0.0], [bias])
			if bool(step.get("face", false)):
				var d: Vector3 = _dir(c.global_position, ctx)
				var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
				var right: Vector3 = cam.global_transform.basis.x if cam != null else Vector3.RIGHT
				for s7: SkillFxSprite in loops:
					s7.set_flip(d.dot(right) < 0.0)
		"look":
			var who: int = caster_id
			if step.get("on", "self") == "target" and int(ctx["target_id"]) > 0:
				who = ctx["target_id"]
			look_on(who, def.id, _look_sec(def))


func _step_cast(ctx: Dictionary, step: Dictionary) -> void:
	var caster_id: int = ctx["caster_id"]
	var c: Node3D = _entity(caster_id)
	if c == null:
		return
	var s: Array = _loop_on(caster_id, &"cast", [step["piece"]], c, float(ctx["cast_part"]), [0.0],
			[float(step.get("bias", FRONT_BIAS))])
	for sp: SkillFxSprite in s:
		_cast_circles[caster_id] = sp # cancelar a conjuração também apaga


func _scale_to_radius(s: SkillFxSprite, def: SkillDef, step: Dictionary) -> void:
	var design: float = float(step.get("r", 0.0))
	var r: float = def.radius_cells * _cell()
	if design > 0.0 and r > 0.0:
		s.scale = Vector3.ONE * r / design


func _step_beam(ctx: Dictionary, step: Dictionary, c: Node3D) -> void:
	var def: SkillDef = ctx["def"]
	var origin: Vector3 = c.global_position if c != null else ctx["pos"]
	var s: SkillFxSprite = _flat(step["piece"], origin, 0.0)
	if s == null:
		return
	var length: float = maxf(def.line_length_cells, 1.0) * _cell()
	var width: float = maxf(def.line_width_cells, 1.0) * _cell()
	s.scale = Vector3(width / float(step.get("width", 2.0)) * 1.4, 1.0, length / float(step.get("len", 12.0)))
	s.face_ground_dir(_dir(origin, ctx))


## Peça deitada correndo a linha (Serpente de Fogo), deixando o rastro que queima pela duração.
func _step_travel(ctx: Dictionary, step: Dictionary, c: Node3D) -> void:
	var def: SkillDef = ctx["def"]
	var caster_id: int = ctx["caster_id"]
	var origin: Vector3 = c.global_position if c != null else ctx["pos"]
	var dir: Vector3 = _dir(origin, ctx)
	var length: float = maxf(def.line_length_cells, 1.0) * _cell()
	var sec: float = float(step.get("sec", 0.8))
	var s: SkillFxSprite = _flat(step["piece"], origin, 0.0)
	if s != null:
		s.face_ground_dir(dir)
		s.life_sec = sec + 0.2
		var from: Vector3 = origin + Vector3.UP * FLAT_LIFT
		_fly(s, from, null, from + dir * length, sec, 0.0, Callable())
	var trail: StringName = step.get("trail", &"")
	if trail == &"":
		return
	var every: float = maxf(float(step.get("every_m", 1.0)), 0.3)
	var n: int = int(length / every)
	for i: int in range(1, n + 1):
		var u: float = float(i) / n
		_later(sec * u, caster_id, func() -> void:
			var t: SkillFxSprite = _flat(trail, origin + dir * length * u, 0.0)
			if t != null:
				t.face_ground_dir(dir)
				t.frame_offset = i
				t.life_sec = maxf(def.duration_sec - sec * u, 0.6)
				t.fade_in_sec = 0.1
				t.fade_out_sec = 0.5)


func _step_shot(ctx: Dictionary, step: Dictionary, index: int) -> void:
	var def: SkillDef = ctx["def"]
	var c: Node3D = _entity(ctx["caster_id"])
	var t: Node3D = _entity(ctx["target_id"])
	var low: float = float(step.get("low", CHEST_FRACTION))
	var to: Vector3 = ctx["pos"]
	if t != null:
		to = t.global_position + Vector3.UP * _height(t) * low
	var from: Vector3 = to
	if c != null:
		from = c.global_position + Vector3.UP * _height(c) * low
	var spread: float = float(step.get("spread", 0.0))
	if spread > 0.0:
		from += Vector3(randf_range(-spread, spread), randf_range(0.0, spread), randf_range(-spread, spread))
	var s: SkillFxSprite = SkillFxSprite.create(step["piece"])
	if s == null:
		return
	_add(s, from)
	s.set_depth_bias(FRONT_BIAS)
	s.orient_dir = (to - from) if (to - from).length() > 0.01 else Vector3.RIGHT
	s.frame_offset = index
	var dur: float = maxf(from.distance_to(to) / float(step.get("speed", ARROW_SPEED)), MIN_FLIGHT_SEC)
	var target_id: int = ctx["target_id"]
	var caster_id: int = ctx["caster_id"]
	var impact: StringName = step.get("impact", &"")
	var trail: StringName = step.get("trail", &"")
	if trail != &"":
		var every: float = maxf(float(step.get("trail_every", 0.06)), 0.02)
		var ground_y: float = c.global_position.y if c != null else to.y
		for i: int in int(dur / every):
			_later(every * (i + 1), caster_id, func() -> void:
				if is_instance_valid(s):
					_at(trail, Vector3(s.global_position.x, ground_y, s.global_position.z), 0.0))
	_fly(s, from, t, to, dur, float(step.get("arc", 0.0)), func(at: Vector3) -> void:
		var tt: Node3D = _entity(target_id)
		if impact != &"":
			if tt != null:
				_upright(impact, tt, _height(tt) * CHEST_FRACTION, FRONT_BIAS)
			else:
				_at(impact, at, FRONT_BIAS)
			if step.has("impact2"):
				_later(float(step["impact2"]), caster_id, func() -> void:
					var t2: Node3D = _entity(target_id)
					if t2 != null:
						_upright(impact, t2, _height(t2) * CHEST_FRACTION * 1.2, FRONT_BIAS))
		if bool(step.get("arrive_look", false)) and target_id > 0:
			look_on(target_id, def.id, _look_sec(def)))


## Algo cai do alto sobre o alvo (ou ponto) e estoura: Mergulho do Gavião.
func _step_drop(ctx: Dictionary, step: Dictionary) -> void:
	var t: Node3D = _entity(ctx["target_id"])
	var to: Vector3 = t.global_position if t != null else ctx["pos"]
	var from: Vector3 = to + Vector3(-0.6, float(step.get("height", DROP_HEIGHT)), -0.4)
	var s: SkillFxSprite = SkillFxSprite.create(step["piece"])
	if s == null:
		return
	_add(s, from)
	s.set_depth_bias(FRONT_BIAS)
	var impact: StringName = step.get("impact", &"")
	var target_id: int = ctx["target_id"]
	_fly(s, from, null, to + Vector3.UP * 0.4, float(step.get("fall", 0.45)), 0.0, func(at: Vector3) -> void:
		var tt: Node3D = _entity(target_id)
		if impact == &"":
			return
		if tt != null:
			_upright(impact, tt, 0.0, FRONT_BIAS)
		else:
			_at(impact, at, FRONT_BIAS))


## Várias peças espalhadas pela área (Revoada: cada flecha cai do céu e finca; Fumaça: nuvens rolando).
func _step_scatter(ctx: Dictionary, step: Dictionary, c: Node3D) -> void:
	var def: SkillDef = ctx["def"]
	var center: Vector3 = ctx["pos"]
	if def.target_type == SkillDef.TargetType.SELF_AREA and c != null:
		center = c.global_position
	var r: float = maxf(_radius(def), _cell()) * float(step.get("fill", 0.8))
	var n: int = int(step.get("n", 6))
	var over: float = float(step.get("over", 0.3))
	var stay_v: Variant = step.get("stay", 1.5)
	var stay: float = maxf(def.duration_sec, 1.0) if str(stay_v) == "dur" else float(stay_v)
	var fall: StringName = step.get("fall", &"")
	var piece: StringName = step["piece"]
	for i: int in n:
		var a: float = TAU * i / n + randf_range(-0.4, 0.4)
		var d: float = r * sqrt(randf_range(0.05, 1.0)) if i > 0 else 0.0
		var p: Vector3 = center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		_later(over * i / maxf(n, 1), int(ctx["caster_id"]), func() -> void:
			if fall == &"":
				_settle(piece, p, stay, i)
				return
			var f: SkillFxSprite = SkillFxSprite.create(fall)
			if f == null:
				return
			var top: Vector3 = p + Vector3(0.0, DROP_HEIGHT * 0.6, 0.0)
			_add(f, top)
			f.set_depth_bias(FRONT_BIAS * 0.5)
			_fly(f, top, null, p, 0.3, 0.0, func(_at_pos: Vector3) -> void: _settle(piece, p, stay, i)))


func _settle(piece: StringName, p: Vector3, stay: float, i: int) -> void:
	var s: SkillFxSprite = _at(piece, p, 0.0)
	if s == null:
		return
	s.frame_offset = i
	s.life_sec = stay
	s.fade_in_sec = 0.1
	s.fade_out_sec = 0.4
	if randf() < 0.5:
		s.set_flip(true)


func _look_sec(def: SkillDef) -> float:
	for k: StringName in [&"stun_sec", &"root_sec"]:
		if def.extra.has(k):
			return float(def.extra[k])
	return def.duration_sec if def.duration_sec > 0.0 else DEFAULT_LOOK_SEC


# ================================================================ estados (NetProgress.status_changed)

## Visual de estado da skill numa entidade (o mesmo que o status_changed põe). Relançar estica o tempo.
func look_on(entity_id: int, skill_id: StringName, sec: float, status_id: StringName = &"") -> void:
	var e: Node3D = _entity(entity_id)
	if e == null:
		return
	var look: Dictionary = _look_for(skill_id, status_id)
	if look.is_empty():
		return
	if look.has("mark"):
		_mark_on(entity_id, look["mark"], e, sec)
		return
	if look.has("burn"):
		var burn: Array = _loop_on(entity_id, &"burn", [BURN_PIECE], e, sec, [0.0], [FRONT_BIAS])
		for s: SkillFxSprite in burn:
			s.scale = Vector3.ONE * BURN_SCALE
		return
	var pieces: Array = look["p"]
	var hs: Array = []
	var bs: Array = (look.get("b", []) as Array).duplicate() # as tabelas são constantes (só leitura)
	for i: int in pieces.size():
		hs.append(_height(e) * float((look.get("h", []) as Array)[i]) if i < (look.get("h", []) as Array).size() else 0.0)
		if i >= bs.size():
			bs.append(FRONT_BIAS)
	_loop_on(entity_id, _look_key(skill_id, status_id, look), pieces, e, sec, hs, bs)


func _look_key(skill_id: StringName, status_id: StringName, look: Dictionary) -> StringName:
	if look.has("key"):
		return look["key"]
	if look.has("mark"):
		return StringName("mark:" + String(look["mark"]))
	if look.has("burn"):
		return &"burn"
	if SkillFxBook.LOOK.has(skill_id):
		return StringName("sk:" + String(skill_id))
	return StringName("st:" + String(status_id))


## Qual visual: o da skill (LOOK), senão o genérico do status (buff/debuff pela chave de mods).
func _look_for(skill_id: StringName, status_id: StringName) -> Dictionary:
	if SkillFxBook.LOOK.has(skill_id):
		return SkillFxBook.LOOK[skill_id]
	if status_id == &"buff" or status_id == &"debuff":
		var def: SkillDef = Content.skill(skill_id) if skill_id != &"" else null
		var table: Array = SkillFxBook.BUFF_BY_MOD if status_id == &"buff" else SkillFxBook.DEBUFF_BY_MOD
		if def != null:
			for pair: Array in table:
				if def.extra.has(pair[0]):
					if status_id == &"buff":
						return {"p": [pair[1]], "b": [FRONT_BIAS], "key": StringName("aura:" + String(pair[1]))}
					return {"mark": pair[1]}
	return SkillFxBook.STATUS_GENERIC.get(status_id, {})


func _on_status_changed(entity_id: int, status_id: StringName, skill_id: StringName, active: bool,
		duration_sec: float) -> void:
	statuses_seen += 1
	if status_id == &"stealth":
		if active:
			_stealth[entity_id] = true
		else:
			_stealth.erase(entity_id)
			var e0: Node3D = _entity(entity_id)
			var v0: Node = e0.get_node_or_null(^"Visual") if e0 != null else null
			if v0 != null and v0.has_method(&"set_tint"):
				v0.call(&"set_tint", Color.WHITE)
		return
	var look: Dictionary = _look_for(skill_id, status_id)
	if look.is_empty():
		return
	var key: StringName = _look_key(skill_id, status_id, look)
	var per: Dictionary = _status.get(entity_id, {})
	var who: Dictionary = per.get(key, {})
	var tag: String = "%s|%s" % [status_id, skill_id]
	if active:
		who[tag] = true
		per[key] = who
		_status[entity_id] = per
		look_on(entity_id, skill_id, duration_sec if duration_sec > 0.0 else DEFAULT_LOOK_SEC, status_id)
		return
	who.erase(tag)
	if not who.is_empty():
		return
	per.erase(key)
	_stop_loop(entity_id, key)
	if String(key).begins_with("mark:"):
		_layout_marks(entity_id)


func _stop_loop(entity_id: int, key: StringName) -> void:
	var k: String = "%d:%s" % [entity_id, key]
	for s: Variant in _loops.get(k, []):
		if is_instance_valid(s):
			(s as SkillFxSprite).stop(0.25)
	_loops.erase(k)


## Marca sobre a cabeça (debuff, lentidão, veneno...). Várias marcas ficam lado a lado.
func _mark_on(entity_id: int, kind: StringName, e: Node3D, sec: float) -> void:
	var piece := StringName(MARK_PIECE_PREFIX + String(kind))
	if not SkillFxSprite.has_piece(piece):
		piece = &"status_mark_debuff"
	_loop_on(entity_id, StringName("mark:" + String(kind)), [piece], e, sec, [_height(e) * MARK_HEAD], [FRONT_BIAS])
	_layout_marks(entity_id)


func _layout_marks(entity_id: int) -> void:
	var marks: Array[SkillFxSprite] = []
	var prefix: String = "%d:mark:" % entity_id
	for k: String in _loops.keys():
		if k.begins_with(prefix):
			for s: Variant in _loops[k]:
				if is_instance_valid(s) and not (s as SkillFxSprite).is_stopping():
					marks.append(s as SkillFxSprite)
	for i: int in marks.size():
		var x: float = (i - (marks.size() - 1) * 0.5) * MARK_SPACING
		marks[i].follow_offset = Vector3(x, marks[i].follow_offset.y, 0.0)


## Número verde fica com o CombatFx; aqui, folhinhas subindo no curado.
func _on_healed(_source_id: int, target_id: int, amount: int) -> void:
	heals_seen += 1
	if amount <= 0:
		return
	var t: Node3D = _entity(target_id)
	if t == null or _clock - float(_last_heal_fx.get(target_id, -INF)) < HEAL_FX_EVERY_SEC:
		return
	_last_heal_fx[target_id] = _clock
	_upright(&"status_heal", t, 0.0, FRONT_BIAS)


## Golpe sem skill: flecha do ataque básico com arco; brasas da Lâmina Faiscante; gotas da Sede de Luta.
func _basic_hit(source_id: int, target_id: int, target: Node3D) -> void:
	var src: Node3D = _entity(source_id)
	if src == null:
		return
	var h: float = _height(target) * CHEST_FRACTION
	if _loops.has("%d:sk:hybrid_spark_blade" % source_id):
		var em: SkillFxSprite = _upright(&"hybrid_steel_spark_impact", target, h, FRONT_BIAS)
		if em != null:
			em.scale = Vector3.ONE * 0.6
	if _loops.has("%d:sk:tank_battle_thirst" % source_id):
		var d: SkillFxSprite = SkillFxSprite.create(&"tank_battle_thirst_drop")
		if d != null:
			var from: Vector3 = target.global_position + Vector3.UP * h
			_add(d, from)
			d.set_depth_bias(FRONT_BIAS)
			d.orient_dir = src.global_position - target.global_position
			_fly(d, from, src, src.global_position, maxf(from.distance_to(src.global_position) / BURST_SPEED, 0.15),
					0.3, Callable())
	if not is_bow_user(src):
		return
	var a: SkillFxSprite = SkillFxSprite.create(&"bow_arrow")
	if a == null:
		return
	var from2: Vector3 = src.global_position + Vector3.UP * _height(src) * CHEST_FRACTION
	var to: Vector3 = target.global_position + Vector3.UP * h
	_add(a, from2)
	a.set_depth_bias(FRONT_BIAS)
	a.orient_dir = to - from2 if (to - from2).length() > 0.01 else Vector3.RIGHT
	bow_arrows += 1
	_fly(a, from2, target, to, maxf(from2.distance_to(to) / ARROW_SPEED, MIN_FLIGHT_SEC), 0.05,
			func(_at_pos: Vector3) -> void:
				var tt: Node3D = _entity(target_id)
				if tt != null:
					_upright(&"bow_arrow_impact", tt, _height(tt) * CHEST_FRACTION, FRONT_BIAS))


## Arqueiro? (arma do visual com "bow"/"arco" no estilo de ataque).
static func is_bow_user(e: Node3D) -> bool:
	var v: Node = e.get_node_or_null(^"Visual") if e != null else null
	var style: Variant = v.get(&"attack_style") if v != null else null
	if style == null:
		style = e.get(&"attack_style") if e != null else null
	if style == null:
		return false
	var s: String = String(style).to_lower()
	for tag: String in BOW_STYLE_TAGS:
		if s.contains(tag):
			return true
	return false
