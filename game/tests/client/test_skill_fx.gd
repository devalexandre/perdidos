extends Node3D
## Teste dos efeitos de skill (SkillFx): lança cada uma das skills de data/skills/ contra entidades de
## mentira e confere que o efeito aparece e depois some (laços pelo duration_sec), que as folhas
## existem, que cone/linha viram para o ponto, que áreas usam o raio da skill, que o laço some quando
## o alvo morre e que a conjuração cancelada não solta o efeito.
## Terra de Pindorama v0.4 (30/09/2026): também as 68 skills novas (SkillFxBook) — as que ainda não têm
## .tres em data/skills/ são montadas aqui com o tipo de alvo de TITULOS-E-SKILLS.md §3.4 — e os
## estados (NetProgress.status_changed: atordoar, prender, provocar, marcas, invisível), a cura
## (NetCombat.healed), a flecha do ataque básico com arco e o aviso novo da Queda Estelar.
## Roda com Engine.time_scale acelerado (TIME_SCALE) para caber no make test.
## Uso: godot --headless --path game res://tests/client/test_skill_fx.tscn
## (com janela, -- --shots=DIR salva uma captura por skill.)

const CASTER_ID: int = 101
const TARGET_ID: int = 202
const APPEAR_SLACK_SEC: float = 1.5
const VANISH_SLACK_SEC: float = 3.0
const SHOT_AFTER_SEC: float = 0.25
const ARCHER_ID: int = 303
const TIME_SCALE: float = 5.0
## Duração máxima dos laços das skills montadas aqui (o teste confere o ciclo, não o balanço).
const SYNTH_MAX_DURATION: float = 3.0
## id -> [tipo de alvo, raio, cone, comprimento da linha, largura, duração, conjuração] (§3.4).
const NEW_SKILLS: Dictionary = {
	&"blade_sharpen": [5, 0, 0, 0, 0, 12, 0], &"blade_aroeira_reply": [5, 0, 0, 0, 0, 1.5, 0],
	&"blade_root_grip": [2, 2.5, 0, 0, 0, 2, 0], &"blade_thick_bark": [5, 0, 0, 0, 0, 6, 0],
	&"blade_trunk_call": [2, 4, 0, 0, 0, 4, 0], &"blade_jaguar_leap": [0, 0, 0, 0, 0, 0, 0],
	&"blade_claw_rake": [0, 0, 0, 0, 0, 0, 0], &"blade_blood_scent": [5, 0, 0, 0, 0, 8, 0],
	&"blade_jaguar_roar": [3, 3, 90, 0, 0, 6, 0], &"arcane_firefly_swarm": [0, 0, 0, 0, 0, 0, 0],
	&"arcane_shared_crystal": [2, 6, 0, 0, 0, 6, 0], &"arcane_crystal_prison": [0, 0, 0, 0, 0, 2.5, 0],
	&"arcane_crystal_wall": [2, 3, 0, 0, 0, 6, 0], &"arcane_crystal_glow": [2, 6, 0, 0, 0, 8, 0],
	&"arcane_star_step": [1, 0, 0, 0, 0, 0, 0], &"arcane_fire_gaze": [4, 0, 0, 12, 1, 0, 0],
	&"arcane_fire_serpent": [4, 0, 0, 8, 1, 5, 0], &"arcane_ember_eyes": [5, 0, 0, 0, 0, 10, 0],
	&"bow_low_shot": [0, 0, 0, 0, 0, 0, 0], &"bow_double_arrow": [0, 0, 0, 0, 0, 0, 0],
	&"bow_taut_draw": [0, 0, 0, 0, 0, 0, 1.0], &"bow_warning_arrow": [0, 0, 0, 0, 0, 6, 0],
	&"bow_arrow_flock": [1, 3, 0, 0, 0, 0, 0], &"bow_mud_skin": [5, 0, 0, 0, 0, 8, 0],
	&"bow_mud_hide": [5, 0, 0, 0, 0, 10, 0], &"bow_ambush_shot": [0, 0, 0, 0, 0, 1.5, 0],
	&"bow_vine_snare": [1, 2, 0, 0, 0, 2.5, 0], &"bow_thorn_arrow": [0, 0, 0, 0, 0, 6, 0],
	&"bow_still_eye": [5, 0, 0, 0, 0, 10, 0], &"bow_true_arrow": [0, 0, 0, 0, 0, 0, 0],
	&"bow_sure_aim": [5, 0, 0, 0, 0, 10, 0], &"bow_hawk_dive": [0, 0, 0, 0, 0, 1, 0],
	&"bow_short_flight": [5, 0, 0, 0, 0, 0, 0], &"hybrid_spark_blade": [5, 0, 0, 0, 0, 8, 0],
	&"hybrid_ember_cut": [0, 0, 0, 0, 0, 4, 0], &"hybrid_steel_spark": [0, 0, 0, 0, 0, 0, 0],
	&"hybrid_sparks": [2, 3, 0, 0, 0, 0, 0], &"hybrid_ember_heart": [5, 0, 0, 0, 0, 12, 0],
	&"support_bottle_brew": [2, 4, 0, 0, 0, 10, 0], &"support_herb_tea": [6, 0, 0, 0, 0, 0, 0],
	&"support_poultice": [6, 0, 0, 0, 0, 0, 0], &"support_pequi_shade": [6, 0, 0, 0, 0, 6, 0],
	&"support_mutirao": [2, 6, 0, 0, 0, 15, 0], &"support_broadleaf_tea": [6, 0, 0, 0, 0, 0, 0],
	&"support_coconut_water": [2, 6, 0, 0, 0, 0, 0], &"support_running_sap": [6, 0, 0, 0, 0, 12, 0],
	&"support_holding_root": [6, 0, 0, 0, 0, 3, 0], &"support_new_breath": [6, 0, 0, 0, 0, 0, 0],
	&"support_ill_whistle": [3, 4, 90, 0, 0, 8, 0], &"support_omen": [0, 0, 0, 0, 0, 10, 0],
	&"support_owl_cry": [1, 3, 0, 0, 0, 5, 0], &"support_bird_lime": [0, 0, 0, 0, 0, 3, 0],
	&"support_bitter_smoke": [1, 3, 0, 0, 0, 6, 0], &"tank_shell_knock": [2, 4, 0, 0, 0, 5, 0],
	&"tank_shell_retreat": [5, 0, 0, 0, 0, 4, 0], &"tank_hard_shell": [5, 0, 0, 0, 0, 12, 0],
	&"tank_patience": [5, 0, 0, 0, 0, 8, 0], &"tank_shell_bash": [3, 2, 90, 0, 0, 1, 0],
	&"tank_thick_hide": [5, 0, 0, 0, 0, 15, 0], &"tank_tapir_stomp": [2, 2.5, 0, 0, 0, 1.5, 0],
	&"tank_tapir_ram": [0, 0, 0, 0, 0, 0, 0], &"tank_living_wall": [2, 3, 0, 0, 0, 8, 0],
	&"tank_stand_firm": [5, 0, 0, 0, 0, 6, 0], &"tank_fury": [5, 0, 0, 0, 0, 10, 0],
	&"tank_mapinguari_howl": [2, 4, 0, 0, 0, 8, 0], &"tank_heavy_claws": [3, 2, 90, 0, 0, 0, 0],
	&"tank_battle_thirst": [5, 0, 0, 0, 0, 10, 0], &"tank_last_blow": [0, 0, 0, 0, 0, 0, 0]}

class FakeEntity extends Node3D:
	var entity_id: int = 0
	var hp_ratio: float = 1.0
	var facing_yaw: float = 0.0

## Visual de mentira: guarda a tinta (invisível) e o estilo de ataque (arco).
class FakeVisual extends Node3D:
	var tint: Color = Color.WHITE
	var attack_style: StringName = &""
	func set_tint(c: Color) -> void:
		tint = c

var _fx: SkillFx
var _ents: Dictionary[int, Node3D] = {}
var _fails: int = 0
var _checks: int = 0
var _shots: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(1.5, 7.0, 5.5)
	cam.look_at(Vector3(1.5, 0.5, 0.0))
	cam.make_current()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color8(104, 150, 70)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	add_child(ground)
	_ents[CASTER_ID] = _entity(CASTER_ID, Vector3.ZERO)
	_ents[TARGET_ID] = _entity(TARGET_ID, Vector3(3, 0, 0))
	_ents[ARCHER_ID] = _entity(ARCHER_ID, Vector3(-3, 0, 2))
	var archer_v := FakeVisual.new()
	archer_v.name = &"Visual"
	archer_v.attack_style = &"simple_bow"
	_ents[ARCHER_ID].add_child(archer_v)
	var target_v := FakeVisual.new()
	target_v.name = &"Visual"
	_ents[TARGET_ID].add_child(target_v)
	Engine.time_scale = TIME_SCALE
	_fx = SkillFx.new()
	_fx.find_entity = func(id: int) -> Node3D: return _ents.get(id)
	add_child(_fx)
	await get_tree().process_frame
	_run()


func _entity(id: int, at: Vector3) -> FakeEntity:
	var e := FakeEntity.new()
	e.entity_id = id
	e.name = str(id)
	add_child(e)
	e.position = at
	var marker := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 1.6, 0.2)
	marker.mesh = bm
	marker.position.y = 0.8
	e.add_child(marker)
	return e


func _check(ok: bool, what: String) -> bool:
	_checks += 1
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", what])
	return ok


func _cast_ms(def: SkillDef) -> int:
	return roundi((def.cast_time_sec + def.ground_warning_sec) * 1000.0)


func _point(def: SkillDef) -> Vector3:
	var caster: Vector3 = _ents[CASTER_ID].global_position
	match def.target_type:
		SkillDef.TargetType.GROUND_AREA:
			return Vector3(2.5, 0, 0)
		SkillDef.TargetType.CONE, SkillDef.TargetType.LINE:
			return caster + Vector3.RIGHT # conjurador + direção × célula (como o servidor)
		SkillDef.TargetType.SINGLE, SkillDef.TargetType.ALLY_OR_SELF:
			return _ents[TARGET_ID].global_position
	return caster


func _wait(cond: Callable, timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0 / TIME_SCALE) + 200
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _pieces_named(prefix: String) -> Array[SkillFxSprite]:
	var out: Array[SkillFxSprite] = []
	for c: Node in _fx.get_children():
		if c is SkillFxSprite and not c.is_queued_for_deletion() and String((c as SkillFxSprite).piece).begins_with(prefix):
			out.append(c as SkillFxSprite)
	return out


## Receitas podem reutilizar folhas de outra skill; conferir as peças declaradas, além do prefixo.
func _has_primary_effect(def: SkillDef) -> bool:
	var declared: Array[StringName] = []
	for step: Dictionary in SkillFxBook.BOOK.get(def.id, []):
		if step.has("piece"):
			declared.append(StringName(step["piece"]))
	for child: Node in _fx.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is SkillFxSprite:
			var piece: StringName = (child as SkillFxSprite).piece
			if String(piece).begins_with(String(def.id)) or piece in declared:
				return true
		elif child.get_meta(&"primary_spell_effect", false) and child.get_meta(&"skill_id", &"") == def.id:
			return true
	return false


## Filhos do SkillFx que são efeito (o PortalDecorator fica sempre).
func _fx_children() -> int:
	var n: int = 0
	for c: Node in _fx.get_children():
		if not c is PortalDecorator and not c.is_queued_for_deletion():
			n += 1
	return n


func _is_flat(s: SkillFxSprite) -> bool:
	return SkillFxSprite.sheet_info(s.piece).get("plane", &"") == &"flat"


## Raio (m) em que a folha foi desenhada: DESIGN_RADIUS das receitas antigas ou "r" do passo do livro.
func _design_r(def: SkillDef, piece: StringName) -> float:
	if SkillFx.DESIGN_RADIUS.has(piece):
		return SkillFx.DESIGN_RADIUS[piece]
	for step: Dictionary in SkillFxBook.BOOK.get(def.id, []):
		if step.get("piece", &"") == piece and step.has("r"):
			return float(step["r"])
	return 0.0


## SkillDef de mentira para as skills novas que ainda não têm .tres.
func _synth(id: StringName) -> SkillDef:
	var a: Array = NEW_SKILLS[id]
	var d := SkillDef.new()
	d.id = id
	d.name_key = "TEST_" + String(id).to_upper()
	d.school = SkillFxBook.school_of(d)
	d.target_type = a[0]
	d.radius_cells = a[1]
	d.cone_deg = a[2]
	d.line_length_cells = a[3]
	d.line_width_cells = a[4]
	d.duration_sec = minf(float(a[5]), SYNTH_MAX_DURATION)
	d.cast_time_sec = a[6]
	return d


func _run() -> void:
	print("test_skill_fx:")
	# 1) todas as folhas da tabela existem e carregam
	var missing: Array[String] = []
	for p: StringName in SkillFxSheets.SHEETS.keys():
		if not SkillFxSprite.has_piece(p):
			missing.append(String(p))
	_check(missing.is_empty() and SkillFxSheets.SHEETS.size() >= 24,
			"%d folhas em assets/fx/skills (faltando: %s)" % [SkillFxSheets.SHEETS.size(), missing])
	# 2) cada skill: aparece e some
	var skills: Array = Content.all(&"skills").values()
	var synthesized: int = 0
	for id: StringName in NEW_SKILLS:
		if Content.skill(id) == null:
			skills.append(_synth(id))
			synthesized += 1
	skills.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return String(a.id) < String(b.id))
	_check(skills.size() >= 80, "%d skills (%d de data/skills, %d montadas aqui por ainda não terem .tres)" %
			[skills.size(), skills.size() - synthesized, synthesized])
	var missing_icons: Array[String] = []
	for def0: SkillDef in skills:
		if not ResourceLoader.exists("res://assets/skills/%s.png" % def0.id):
			missing_icons.append(String(def0.id))
	_check(missing_icons.is_empty(), "ícone 32x32 para cada skill (faltando: %s)" % [missing_icons])
	for def: SkillDef in skills:
		var recipe: StringName = SkillFx.recipe_for(def)
		if not _check(recipe != &"", "%s tem receita de efeito" % def.id):
			continue
		var cast_ms: int = _cast_ms(def)
		var before: int = _fx.pieces_spawned + _fx.primary_volumes_spawned
		var shouts_before: int = _fx.shouts_spawned
		# Finalização (08/10/2026): toda receita emite um contato visual, uma vez, depois da liberação.
		var contact_at: Array[float] = []
		var on_impact: Callable = func(cid: int, sid: StringName, _at: Vector3) -> void:
			if cid == CASTER_ID and sid == def.id:
				contact_at.append(_fx._clock)
		SkillPresentation.events.impact.connect(on_impact)
		var t0: float = _fx._clock
		_fx.play(def, CASTER_ID, TARGET_ID if def.target_type in [SkillDef.TargetType.SINGLE,
				SkillDef.TargetType.ALLY_OR_SELF] else 0, _point(def), cast_ms)
		var name_txt: String = tr(def.name_key)
		_check(_fx.shouts_spawned == shouts_before + 1 and _fx.last_shout_text == name_txt \
				and _fx.find_child("SkillShout", false, false) != null,
				"%s: nome gritado acima do conjurador (\"%s\")" % [def.id, name_txt])
		# o efeito principal (não só o círculo de conjuração) precisa surgir
		var appeared: bool = await _wait(func() -> bool:
			return _has_primary_effect(def), cast_ms / 1000.0 + APPEAR_SLACK_SEC)
		_check(appeared and _fx.pieces_spawned + _fx.primary_volumes_spawned > before, "%s: efeito aparece (%s, %d peças)" %
				[def.id, recipe, _fx.pieces_spawned + _fx.primary_volumes_spawned - before])
		if def.target_type in [SkillDef.TargetType.CONE, SkillDef.TargetType.LINE]:
			var flat: Array = [] # preenchido dentro do lambda (arrays passam por referência)
			await _wait(func() -> bool:
				flat.clear()
				flat.append_array(_pieces_named(String(def.id)).filter(_is_flat))
				for child: Node in _fx.get_children():
					if child.get_meta(&"primary_spell_effect", false) and child.get_meta(&"skill_id", &"") == def.id and not child.is_queued_for_deletion():
						flat.append(child)
				return not flat.is_empty(), 1.0)
			var ok: bool = not flat.is_empty() and absf(angle_difference(flat[0].rotation.y, -PI / 2.0)) < 0.05
			_check(ok, "%s: forma virada do conjurador para o ponto (+X)" % def.id)
		var has_flat_area: bool = false
		for step: Dictionary in SkillFxBook.BOOK.get(def.id, []):
			has_flat_area = has_flat_area or (step.has("r") and String(step.get("do", "")) in ["flat_self", "flat_pos"])
		if def.target_type in [SkillDef.TargetType.GROUND_AREA, SkillDef.TargetType.SELF_AREA] and def.radius_cells > 0.0 \
				and (not SkillFxBook.BOOK.has(def.id) or has_flat_area):
			var ok2: bool = await _wait(func() -> bool:
				for s: SkillFxSprite in _pieces_named(String(def.id)):
					var dr: float = _design_r(def, s.piece)
					if dr > 0.0:
						return is_equal_approx(s.scale.x, def.radius_cells / dr)
				return false, cast_ms / 1000.0 + APPEAR_SLACK_SEC)
			_check(ok2, "%s: área no chão com o raio da skill (%.1f)" % [def.id, def.radius_cells])
		if not _shots.is_empty():
			await get_tree().create_timer(SHOT_AFTER_SEC).timeout
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, def.id])
		var vanish: float = cast_ms / 1000.0 + def.duration_sec + VANISH_SLACK_SEC
		var gone: bool = await _wait(func() -> bool: return _fx.active_pieces() == 0, vanish)
		_check(gone, "%s: efeito some (em até %.1f s)" % [def.id, vanish])
		_check(await _wait(func() -> bool: return _fx_children() == 0, 1.5),
				"%s: nome e peças saem da cena" % def.id)
		SkillPresentation.events.impact.disconnect(on_impact)
		_check(contact_at.size() == 1 and contact_at[0] >= t0 + cast_ms / 1000.0 - 0.03,
				"%s: um contato visual (som + reação) após a liberação (%s)" % [def.id, contact_at])
	# 3) laço some quando o alvo morre
	var barrier: SkillDef = Content.skill(&"arcane_barrier")
	_fx.play(barrier, CASTER_ID, TARGET_ID, _point(barrier), 0)
	await get_tree().create_timer(0.3).timeout
	var had: bool = not _pieces_named("arcane_barrier").is_empty()
	(_ents[TARGET_ID] as FakeEntity).hp_ratio = 0.0
	var gone2: bool = await _wait(func() -> bool: return _pieces_named("arcane_barrier").is_empty(), 1.0)
	_check(had and gone2, "escudo some quando o alvo morre (antes dos %.0f s)" % barrier.duration_sec)
	(_ents[TARGET_ID] as FakeEntity).hp_ratio = 1.0
	# 4) geada no alvo atingido pela Explosão de Gelo (NetCombat.hit)
	var frost: SkillDef = Content.skill(&"arcane_frost_burst")
	_fx.play(frost, CASTER_ID, 0, _point(frost), 0)
	_fx._on_hit(CASTER_ID, TARGET_ID, 12, false, 1, 0.9)
	await get_tree().process_frame
	_check(not _pieces_named("arcane_frost_burst_chill").is_empty(), "geada presa ao alvo lento")
	await _wait(func() -> bool: return _fx.active_pieces() == 0, frost.duration_sec + VANISH_SLACK_SEC)
	# 5b) Terra de Pindorama v0.4: estados, cura, invisível, arco, aviso da Queda Estelar
	await _run_v04()
	# 5c) portais dos mapas: o Gate antigo some e cada portal ganha o PortalFx (coroa de chamas + disco de luz)
	await _run_portals()
	# 6) finalização: carga → disparo → contato
	await _run_finish()
	# 5) conjuração cancelada: o projétil não sai
	var spark: SkillDef = Content.skill(&"arcane_spark")
	_fx.play(spark, CASTER_ID, TARGET_ID, _point(spark), 400)
	_fx._on_cast_cancelled(CASTER_ID, spark.id)
	await get_tree().create_timer(0.8).timeout
	_check(_pieces_named("arcane_spark_").is_empty(), "conjuração cancelada não solta o efeito")
	Engine.time_scale = 1.0
	print("RESULT: %s (%d/%d)" % ["PASS" if _fails == 0 else "FAIL", _checks - _fails, _checks])
	get_tree().quit(0 if _fails == 0 else 1)


func _run_finish() -> void:
	var contact_at: Array[float] = []
	var on_impact: Callable = func(cid: int, _sid: StringName, _at: Vector3) -> void:
		if cid == CASTER_ID:
			contact_at.append(_fx._clock)
	SkillPresentation.events.impact.connect(on_impact)
	# projétil: a reação do alvo guardada no hit da rede só sai quando a peça chega
	var wisp: SkillDef = Content.skill(&"arcane_will_o_wisp")
	var reacted: Array[float] = []
	var t0: float = _fx._clock
	_fx.play(wisp, CASTER_ID, TARGET_ID, _point(wisp), 0)
	var held: bool = SkillPresentation.defer(CASTER_ID, func() -> void: reacted.append(_fx._clock))
	_check(held and reacted.is_empty(), "hit da rede durante o voo fica guardado (sem flash/número antes)")
	await _wait(func() -> bool: return not contact_at.is_empty(), 2.0)
	_check(contact_at.size() == 1 and contact_at[0] - t0 >= 0.2,
			"contato do projétil na chegada, não no disparo (%.2f s depois)" % (contact_at[0] - t0 if not contact_at.is_empty() else -1.0))
	_check(reacted.size() == 1 and not contact_at.is_empty() and is_equal_approx(reacted[0], contact_at[0]),
			"reação do alvo sai no mesmo quadro do impacto")
	_check(not SkillPresentation.defer(CASTER_ID, func() -> void: pass), "depois do contato, hits seguem na hora")
	await _wait(func() -> bool: return _fx.active_pieces() == 0, 3.0)
	# corpo a corpo: o som/reação no corte, não no começo do lançamento; conjurador segura no contato
	contact_at.clear()
	var strike: SkillDef = Content.skill(&"blade_firm_strike")
	t0 = _fx._clock
	_fx.play(strike, CASTER_ID, TARGET_ID, _point(strike), 0)
	_check(contact_at.is_empty(), "Golpe Firme não soa no início do lançamento")
	await _wait(func() -> bool: return not contact_at.is_empty(), 1.5)
	var dt: float = contact_at[0] - t0 if not contact_at.is_empty() else -1.0
	_check(dt >= SkillFx.STRIKE_DELAY_SEC + SkillFx.IMPACT_AFTER_SLASH_SEC - 0.03,
			"Golpe Firme: contato junto da peça de impacto (%.2f s)" % dt)
	await _wait(func() -> bool: return _fx.active_pieces() == 0, 3.0)
	# investida: imagens residuais, anel de poeira e clarão quente no contato
	contact_at.clear()
	var ghosts0: int = _fx.afterimages
	var rings0: int = _fx.dust_rings
	var flashes0: int = _fx.warm_flashes
	var charge: SkillDef = Content.skill(&"blade_charge")
	_fx.play(charge, CASTER_ID, TARGET_ID, _point(charge), 0)
	await _wait(func() -> bool: return not contact_at.is_empty(), 1.5)
	_check(_fx.dust_rings == rings0 + 1, "investida: anel de poeira na partida")
	_check(_fx.warm_flashes == flashes0 + 1, "investida: clarão quente no contato")
	_check(_fx.afterimages == ghosts0, "investida: sem DirectionalSprite3D (dublê), nenhuma cópia criada")
	await _wait(func() -> bool: return _fx.active_pieces() == 0 and _fx.find_child("DustRing", false, false) == null, 3.0)
	_check(_fx.find_child("DustRing", false, false) == null, "anel de poeira sai da cena")
	# prazo vencido (peça nunca chega): as reações guardadas saem assim mesmo
	SkillPresentation.await_contact(CASTER_ID, 0.05)
	var late: Array[int] = []
	SkillPresentation.defer(CASTER_ID, func() -> void: late.append(1))
	await get_tree().create_timer(0.2 * TIME_SCALE).timeout
	_check(late.size() == 1, "prazo vencido solta a reação guardada")
	SkillPresentation.events.impact.disconnect(on_impact)


func _run_v04() -> void:
	# atordoar / prender / provocar (status_changed genérico) aparecem e somem com active = false
	for pair: Array in [[&"stun", &"tank_tapir_stomp", "blade_charge_stun"], [&"root", &"bow_vine_snare", "status_root_front"],
			[&"taunt", &"tank_shell_knock", "status_taunt"]]:
		_fx._on_status_changed(TARGET_ID, pair[0], pair[1], true, 5.0)
		await get_tree().process_frame
		var on: bool = not _pieces_named(pair[2]).is_empty()
		_fx._on_status_changed(TARGET_ID, pair[0], pair[1], false, 0.0)
		var off: bool = await _wait(func() -> bool: return _pieces_named(pair[2]).is_empty(), 1.5)
		_check(on and off, "status %s (%s): %s aparece e some quando acaba" % [pair[0], pair[1], pair[2]])
	# peça própria da skill no estado (Sombra de Pequizeiro sobre o aliado)
	_fx._on_status_changed(TARGET_ID, &"buff", &"support_pequi_shade", true, 5.0)
	await get_tree().process_frame
	_check(not _pieces_named("support_pequi_shade_tree").is_empty(), "buff da Sombra de Pequizeiro: copa sobre o aliado")
	_fx._on_status_changed(TARGET_ID, &"buff", &"support_pequi_shade", false, 0.0)
	# duas marcas de debuff lado a lado sobre a cabeça
	_fx._on_status_changed(TARGET_ID, &"debuff", &"tank_mapinguari_howl", true, 5.0)
	_fx._on_status_changed(TARGET_ID, &"slow", &"support_owl_cry", true, 5.0)
	await get_tree().process_frame
	var marks: Array[SkillFxSprite] = _pieces_named("status_mark_")
	_check(marks.size() == 2 and absf(marks[0].follow_offset.x - marks[1].follow_offset.x) > 0.3,
			"duas marcas de debuff lado a lado (%d)" % marks.size())
	_fx._on_status_changed(TARGET_ID, &"debuff", &"tank_mapinguari_howl", false, 0.0)
	_fx._on_status_changed(TARGET_ID, &"slow", &"support_owl_cry", false, 0.0)
	_check(await _wait(func() -> bool: return _pieces_named("status_mark_").is_empty(), 1.5), "marcas somem no fim")
	# invisível: meio transparente enquanto dura, volta ao normal depois
	var tv: FakeVisual = _ents[TARGET_ID].get_node(^"Visual")
	_fx._on_status_changed(TARGET_ID, &"stealth", &"bow_mud_hide", true, 5.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var half: bool = tv.tint.a < 0.7 and tv.tint.a > 0.2
	_fx._on_status_changed(TARGET_ID, &"stealth", &"bow_mud_hide", false, 0.0)
	await get_tree().process_frame
	_check(half and tv.tint == Color.WHITE, "invisível: meio transparente (alfa %.2f) e volta ao normal" % tv.tint.a)
	# cura: folhinhas no curado (o número verde é do CombatFx)
	_fx._on_healed(CASTER_ID, TARGET_ID, 42)
	await get_tree().process_frame
	_check(_fx.heals_seen == 1 and not _pieces_named("status_heal").is_empty(), "cura: folhas verdes no curado")
	# ataque básico com arco: a flecha voa do arqueiro ao alvo e estoura
	var arrows0: int = _fx.bow_arrows
	_fx._on_hit(ARCHER_ID, TARGET_ID, 10, false, 0, 0.8)
	await get_tree().process_frame
	var flying: bool = not _pieces_named("bow_arrow").is_empty()
	var hit_fx: bool = await _wait(func() -> bool: return not _pieces_named("bow_arrow_impact").is_empty(), 1.5)
	_check(_fx.bow_arrows == arrows0 + 1 and flying and hit_fx, "ataque básico com arco: flecha voa e acerta")
	_fx._on_hit(CASTER_ID, TARGET_ID, 10, false, 0, 0.8)
	_check(_fx.bow_arrows == arrows0 + 1, "golpe sem arco não solta flecha")
	# aviso novo da Queda Estelar (sombra com o chão rachando, sem estrela no círculo)
	var star: SkillDef = Content.skill(&"arcane_star_fall")
	if star != null:
		_fx.play(star, CASTER_ID, 0, _point(star), _cast_ms(star))
		_check(await _wait(func() -> bool: return not _pieces_named("arcane_star_fall_warning").is_empty(),
				star.cast_time_sec + 1.0), "Queda Estelar: aviso no chão (sombra da pedra-estrela)")
	await _wait(func() -> bool: return _fx.active_pieces() == 0, 8.0)


func _run_portals() -> void:
	for map_id: String in ["fields_pindorama", "enchanted_forest", "split_sky_plateau", "city_awakening", "training_field"]:
		var path: String = "res://scenes/maps/%s.tscn" % map_id
		if not ResourceLoader.exists(path):
			continue
		var map: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		add_child(map)
		await get_tree().physics_frame
		var portals: Array[Area3D] = []
		for a: Node in map.get_node(^"Interactables").get_children():
			if a is Area3D and StringName(str(a.get_meta(&"interact_type", &""))) == &"portal":
				portals.append(a as Area3D)
		var n: int = PortalFx.decorate_map(map)
		var ok: bool = n == portals.size() and n > 0
		var gates_hidden: bool = true
		for a: Area3D in portals:
			var fx: PortalFx = a.get_node_or_null(^"PortalFx") as PortalFx
			ok = ok and fx != null and fx.disc_material != null and not fx.flame_materials.is_empty()
			var gate: Node = a.get_node_or_null(^"Gate")
			if gate != null:
				gates_hidden = gates_hidden and not (gate as MeshInstance3D).visible
		_check(ok and gates_hidden, "%s: %d portais com PortalFx, Gate antigo escondido" % [map_id, portals.size()])
		_check(PortalFx.decorate_map(map) == 0, "%s: decorar de novo não duplica" % map_id)
		map.queue_free()
		await get_tree().process_frame
