class_name CombatFx
extends Node3D
## Efeitos de combate no cliente (contrato arrival, K). Criado pelo NetCombat quando o jogador local
## aparece. Escuta NetCombat.hit / entity_died e, a cada quadro, as entidades da instância:
##  - números de dano flutuando (crítico maior, laranja e com "!"; dano no jogador local em vermelho);
##  - anel no chão sob o alvo do ataque do jogador local;
##  - barra de vida acima de monstros feridos/alvo e de outros jogadores feridos;
##  - animações attack (atacante) e hit (alvo); sem a folha, um "tranco" curto no sprite;
##  - combate vivo (GDD §10.2.1, Agente A): o atacante avança um passo curto no golpe (folha do golpe
##    pelo tipo de arma, ver DirectionalSprite3D.attack_style) e o alvo sofre empurrão/tremida no
##    impacto; skills mágicas tocam "cast" no conjurador. Tudo só visual (posição de rede intacta);
##  - morte sem folha _death: o corpo some aos poucos;
##  - troca de estágio (evolução): refaz o visual do monstro.

const KIND_MONSTER: StringName = &"monster"
const KIND_PLAYER: StringName = &"player"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"
const ANIM_CAST: StringName = &"cast"
## Quando o golpe "acerta" dentro da animação de ataque (fração): o empurrão do alvo espera até lá.
const STRIKE_FRACTION: float = 0.36
## Depois de um cast, o hit da própria skill não reinicia a animação do conjurador (ms).
const CAST_HOLD_MS: int = 700
# --- números de dano
const NUMBER_FONT_SIZE: int = 14
const NUMBER_CRIT_SCALE: float = 1.5
const NUMBER_RISE: float = 0.9
const NUMBER_LIFETIME_SEC: float = 0.9
const NUMBER_JITTER: float = 0.25
const NUMBER_HEIGHT_FRACTION: float = 0.8
const NUMBER_PRIORITY: int = 20
const CRIT_SUFFIX: String = "!"
const COLOR_DEALT: Color = Color8(252, 250, 245)
const COLOR_CRIT: Color = Color8(250, 190, 60)
const COLOR_TAKEN: Color = Color8(245, 90, 80)
const COLOR_OTHER: Color = Color8(200, 196, 210)
## Agente R: golpe errado.
const MISS_TEXT_KEY: String = "COMBAT_MISS"
const COLOR_MISS: Color = Color8(170, 200, 235)
## Terra do Sabiá v0.4: cura (NetCombat.healed) em número verde com "+".
const COLOR_HEAL: Color = Color8(126, 226, 96)
const HEAL_PREFIX: String = "+"
# --- anel do alvo
const RING_INNER: float = 0.38
const RING_OUTER: float = 0.5
const RING_HEIGHT: float = 0.03
const RING_COLOR: Color = Color(0.95, 0.25, 0.2, 0.85)
const RING_SPIN_DEG_PER_SEC: float = 90.0
# --- barras de vida (texels do mundo, Balance.cfg.sprite_pixel_size)
const BAR_WIDTH_TEXELS: int = 32
const BAR_HEIGHT_TEXELS: int = 4
const BAR_ABOVE_NAME_TEXELS: float = 12.0
const BAR_FALLBACK_HEIGHT: float = 2.0
const BAR_BG: Color = Color8(22, 19, 28, 230)
const BAR_FILL_MONSTER: Color = Color8(214, 64, 52)
const BAR_FILL_PLAYER: Color = Color8(110, 200, 90)
const BAR_PRIORITY: int = 9
# --- tranco sem folha de ataque / dano
const BUMP_SCALE: float = 1.12
const BUMP_SEC: float = 0.12
# --- morte sem folha: monstro some em FADE_SEC; jogador desacordado fica acinzentado
const FADE_SEC: float = 1.2
## Com folha _death: tempo parado no último quadro antes de achatar e sumir.
const DEATH_HOLD_SEC: float = 0.5
const DOWNED_TINT: Color = Color(0.55, 0.55, 0.6, 0.8)

## Contadores para testes (autoteste do combate).
var numbers_spawned: int = 0
var crit_numbers_spawned: int = 0
var misses_spawned: int = 0
var heal_numbers_spawned: int = 0
var last_number_text: String = ""
var bars_visible: int = 0

var _ring: MeshInstance3D
var _bars: Dictionary[int, Sprite3D] = {}
var _bar_ratio: Dictionary[int, float] = {}
var _fading: Dictionary[int, float] = {}
var _last_cast_ms: Dictionary[int, int] = {}
## Contadores para testes (combate vivo).
var lunges_played: int = 0
var knockbacks_played: int = 0
var casts_played: int = 0
var flinches_played: int = 0


func _ready() -> void:
	NetCombat.hit.connect(_on_hit)
	NetCombat.entity_died.connect(_on_died)
	if NetCombat.has_signal(&"healed"): # contrato do servidor; conecta só se existir
		NetCombat.connect(&"healed", _on_healed)
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null and prog.has_signal(&"skill_cast"):
		prog.connect(&"skill_cast", _on_skill_cast)
	_ring = _make_ring()
	add_child(_ring)


func get_target_ring() -> MeshInstance3D:
	return _ring


func _process(delta: float) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var target_id: int = NetCombat.client_attack_target
	var seen: Dictionary[int, bool] = {}
	var ring_on: bool = false
	bars_visible = 0
	for e: Node3D in NetCombat.all_entities():
		var id: int = int(e.get(&"entity_id"))
		var kind := StringName(str(e.get(&"kind")))
		var ratio: float = float(e.get(&"hp_ratio"))
		var visual: Node3D = e.get_node_or_null(^"Visual") as Node3D
		if kind == KIND_MONSTER and visual is EntityVisual:
			_check_stage(e, visual as EntityVisual)
			_check_fade(id, ratio, visual as EntityVisual, delta)
		elif kind == KIND_PLAYER and visual is EntityVisual:
			_check_downed(id, ratio, visual as EntityVisual)
		if id == target_id and ratio > 0.0:
			ring_on = true
			var vscale: float = 1.0
			if visual != null and "visual_scale" in visual:
				vscale = maxf(0.8, float(visual.visual_scale))
			_ring.global_position = e.global_position + Vector3.UP * RING_HEIGHT
			_ring.scale = Vector3(vscale, 0.15 * vscale, vscale)
		var show_bar: bool = ratio > 0.0 and ((kind == KIND_MONSTER and (ratio < 1.0 or id == target_id)) \
				or (kind == KIND_PLAYER and id != local_id and ratio < 1.0))
		if show_bar:
			seen[id] = true
			bars_visible += 1
			_update_bar(id, e, visual, ratio, kind == KIND_MONSTER)
	_ring.visible = ring_on
	if ring_on:
		_ring.rotate_y(deg_to_rad(RING_SPIN_DEG_PER_SEC) * delta)
	for id: int in _bars.keys():
		if not seen.has(id):
			_bars[id].queue_free()
			_bars.erase(id)
			_bar_ratio.erase(id)


# ---------------------------------------------------------------- eventos

func _on_hit(source_id: int, target_id: int, amount: int, crit: bool, _damage_type: int,
		_target_hp_ratio: float) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var target: Node3D = NetCombat.find_entity(target_id)
	var source: Node3D = NetCombat.find_entity(source_id)
	var strike_delay: float = 0.0
	if source != null and not _casting(source_id):
		_play(source, ANIM_ATTACK)
		strike_delay = _lunge(source, target)
	if target == null:
		return
	# Agente R (GDD §10.2): golpe errado (esquiva) = "Errou", sem animação de dano no alvo.
	if amount == NetCombat.MISS_AMOUNT:
		misses_spawned += 1
		spawn_number(target, tr(MISS_TEXT_KEY), COLOR_MISS, false)
		return
	_play(target, ANIM_HIT)
	_knockback(target, source, strike_delay)
	_flinch(target, strike_delay)
	var color: Color = COLOR_OTHER
	if target_id == local_id:
		color = COLOR_TAKEN
	elif crit:
		color = COLOR_CRIT
	elif source_id == local_id:
		color = COLOR_DEALT
	spawn_number(target, str(amount) + (CRIT_SUFFIX if crit else ""), color, crit)


## Cura: número verde "+N" subindo do curado (para todos da instância).
func _on_healed(_source_id: int, target_id: int, amount: int) -> void:
	if amount <= 0:
		return
	var target: Node3D = NetCombat.find_entity(target_id)
	if target == null:
		return
	heal_numbers_spawned += 1
	spawn_number(target, HEAL_PREFIX + str(amount), COLOR_HEAL, false)


## Skill lançada: mágicas (não físicas) tocam "cast" no conjurador; físicas, o golpe com avanço.
func _on_skill_cast(entity_id: int, skill_id: StringName, _target_entity_id: int, _pos: Vector3,
		_cast_ms: int) -> void:
	var caster: Node3D = NetCombat.find_entity(entity_id)
	if caster == null:
		return
	var def: SkillDef = Content.skill(skill_id)
	if def != null and def.effect == SkillDef.Effect.PHYSICAL_DAMAGE:
		return # o golpe (e o avanço) vem com o hit
	var v: Node3D = caster.get_node_or_null(^"Visual") as Node3D
	if v is DirectionalSprite3D and (v as DirectionalSprite3D).play_oneshot(ANIM_CAST):
		_last_cast_ms[entity_id] = Time.get_ticks_msec()
		casts_played += 1


func _casting(entity_id: int) -> bool:
	return Time.get_ticks_msec() - _last_cast_ms.get(entity_id, -CAST_HOLD_MS) < CAST_HOLD_MS


## Avanço do atacante na direção do alvo. Devolve o atraso até o impacto (s) para o empurrão do alvo.
func _lunge(source: Node3D, target: Node3D) -> float:
	var v: Node3D = source.get_node_or_null(^"Visual") as Node3D
	if not v is DirectionalSprite3D:
		return 0.0
	var ds := v as DirectionalSprite3D
	var dir := Vector3.ZERO
	if target != null:
		dir = target.global_position - source.global_position
	ds.play_lunge(dir)
	lunges_played += 1
	return ds.get_oneshot_left() * STRIKE_FRACTION


func _knockback(target: Node3D, source: Node3D, delay: float) -> void:
	var v: Node3D = target.get_node_or_null(^"Visual") as Node3D
	if not v is DirectionalSprite3D:
		return
	var dir := Vector3.ZERO
	if source != null:
		dir = target.global_position - source.global_position
	(v as DirectionalSprite3D).play_knockback(dir, delay)
	knockbacks_played += 1


## Reação ao golpe (GDD §17.0.C): achatamento + flash branco no impacto, com ou sem folha _hit.
func _flinch(target: Node3D, delay: float) -> void:
	var v: Node3D = target.get_node_or_null(^"Visual") as Node3D
	if v is DirectionalSprite3D:
		(v as DirectionalSprite3D).play_flinch(delay)
		flinches_played += 1


func _on_died(_entity_id: int) -> void:
	pass # a animação de morte vem do anim replicado; o sumiço sem folha é feito em _check_fade.


# ---------------------------------------------------------------- números

func spawn_number(target: Node3D, text: String, color: Color, crit: bool) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.pixel_size = DirectionalSprite3D.world_text_pixel_size()
	l.font = UIKit.world_font()
	l.font_size = roundi(NUMBER_FONT_SIZE * (NUMBER_CRIT_SCALE if crit else 1.0)
			* DirectionalSprite3D.world_text_font_scale())
	l.outline_size = UIKit.OUTLINE_SIZE
	l.outline_modulate = UIKit.COLOR_OUTLINE
	l.no_depth_test = true
	l.shaded = false
	l.render_priority = NUMBER_PRIORITY
	l.outline_render_priority = NUMBER_PRIORITY - 1
	l.modulate = color
	l.text = text
	add_child(l)
	var h: float = _visual_height(target)
	var start: Vector3 = target.global_position + Vector3(randf_range(-NUMBER_JITTER, NUMBER_JITTER),
			h * NUMBER_HEIGHT_FRACTION, 0.0)
	l.global_position = start
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, ^"global_position", start + Vector3.UP * NUMBER_RISE, NUMBER_LIFETIME_SEC)
	tw.tween_property(l, ^"modulate:a", 0.0, NUMBER_LIFETIME_SEC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)
	numbers_spawned += 1
	if crit:
		crit_numbers_spawned += 1
	last_number_text = text
	return l


# ---------------------------------------------------------------- barras

func _update_bar(id: int, e: Node3D, visual: Node3D, ratio: float, is_monster: bool) -> void:
	var bar: Sprite3D = _bars.get(id)
	if bar == null:
		bar = Sprite3D.new()
		bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bar.shaded = false
		bar.no_depth_test = true
		bar.render_priority = BAR_PRIORITY
		add_child(bar)
		_bars[id] = bar
		_bar_ratio[id] = -1.0
	if not is_equal_approx(_bar_ratio[id], ratio):
		_bar_ratio[id] = ratio
		bar.texture = _bar_texture(ratio, BAR_FILL_MONSTER if is_monster else BAR_FILL_PLAYER)
	bar.pixel_size = DirectionalSprite3D.world_image_pixel_size()
	var y: float = BAR_FALLBACK_HEIGHT
	if visual is EntityVisual:
		y = (visual as EntityVisual).get_nameplate().position.y \
				+ BAR_ABOVE_NAME_TEXELS * Balance.cfg.sprite_pixel_size / cos(deg_to_rad(Balance.cfg.camera_pitch_deg))
	bar.global_position = e.global_position + Vector3.UP * y


static func _bar_texture(ratio: float, fill: Color) -> Texture2D:
	var img := Image.create(BAR_WIDTH_TEXELS, BAR_HEIGHT_TEXELS, false, Image.FORMAT_RGBA8)
	img.fill(BAR_BG)
	var inner: int = BAR_WIDTH_TEXELS - 2
	var filled: int = clampi(ceili(inner * ratio), 0, inner)
	for x: int in range(1, 1 + filled):
		for y: int in range(1, BAR_HEIGHT_TEXELS - 1):
			img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- animações

func _play(entity: Node3D, anim_name: StringName) -> void:
	var v: Node3D = entity.get_node_or_null(^"Visual") as Node3D
	if v == null:
		return
	if v is DirectionalSprite3D:
		# Sem a folha, o tranco vem da vida procedural (play_flinch no alvo; o atacante já avança no golpe).
		(v as DirectionalSprite3D).play_oneshot(anim_name)
		return
	# Visual que não é sprite direcional: tranco curto na escala.
	var base: Vector3 = v.scale
	var tw: Tween = v.create_tween()
	tw.tween_property(v, ^"scale", base * BUMP_SCALE, BUMP_SEC * 0.5)
	tw.tween_property(v, ^"scale", base, BUMP_SEC * 0.5)


func _check_stage(e: Node3D, v: EntityVisual) -> void:
	var st: int = int(e.get(&"stage"))
	var atroz: bool = CombatVisuals.is_atroz(e) or st == CombatVisuals.ATROZ_STAGE
	if int(v.get_meta(CombatVisuals.META_STAGE, st)) != st \
			or bool(v.get_meta(CombatVisuals.META_ATROZ, atroz)) != atroz:
		CombatVisuals.refresh_monster(v, e)


## Morte do monstro (GDD §17.0.C): achata e some em pontilhado. Com folha _death, espera a animação terminar.
func _check_fade(id: int, ratio: float, v: EntityVisual, delta: float) -> void:
	if ratio > 0.0:
		if _fading.has(id):
			_fading.erase(id)
			v.reset_life()
		return
	var waited: float = _fading.get(id, 0.0) + delta
	_fading[id] = waited
	var hold: float = 0.0
	if v.has_anim(DirectionalSprite3D.ANIM_DEATH):
		hold = v.get_frame_sec(DirectionalSprite3D.ANIM_DEATH, v.get_frame_count(DirectionalSprite3D.ANIM_DEATH)) \
				* v.get_frame_count(DirectionalSprite3D.ANIM_DEATH) + DEATH_HOLD_SEC
	if waited >= hold:
		v.play_death_fade()


## Jogador com vida 0 (sem folha _death): acinzentado até renascer.
func _check_downed(id: int, ratio: float, v: EntityVisual) -> void:
	var downed: bool = ratio <= 0.0 and not v.has_anim(DirectionalSprite3D.ANIM_DEATH)
	if downed and not _fading.has(id):
		_fading[id] = 0.0
		v.set_tint(DOWNED_TINT)
	elif not downed and _fading.has(id):
		_fading.erase(id)
		v.set_tint(Color.WHITE)


func _visual_height(e: Node3D) -> float:
	var v: Node = e.get_node_or_null(^"Visual")
	if v is DirectionalSprite3D:
		return (v as DirectionalSprite3D).get_world_height()
	return BAR_FALLBACK_HEIGHT


func _make_ring() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = RING_INNER
	mesh.outer_radius = RING_OUTER
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = RING_COLOR
	mat.no_depth_test = false
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.name = &"TargetRing"
	m.mesh = mesh
	m.scale = Vector3(1.0, 0.15, 1.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	return m
