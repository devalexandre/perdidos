extends Node
## Teste headless da matemática de direção do DirectionalSprite3D.
## Rodar: godot --headless --path game res://tests/client/test_direction.tscn

const D := DirectionalSprite3D.Dir
const STUB_DIR: String = "res://tests/_stub_b/"
const EPS: float = 0.0001

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_facing_with_fixed_camera()
	_test_camera_orbit_around_stationary_character()
	_test_sector_boundaries()
	_test_rows_and_mirroring()
	_test_traveler_gait()
	await _test_sprite_feet_at_origin()
	await _test_combat_anims()
	_test_cast_duration()
	_test_skill_finish()
	_test_smooth_turn()
	_test_walk_continuity()
	print("test_direction: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _test_cast_duration() -> void:
	var visual := EntityVisual.new()
	add_child(visual)
	visual.set_appearance({&"body": &"female", &"outfit": &"traveler"})
	visual.set_process(false)
	_check(visual.play_cast_duration(2.0), "conjuração temporizada existe")
	_check(is_equal_approx(visual.get_oneshot_left(), 2.0), "conjuração acompanha tempo da skill")
	visual._process(1.0)
	_check(visual.get_oneshot() == &"cast", "personagem não volta ao idle antes do fim da carga")
	var frames: int = visual.get_frame_count(&"cast")
	var frame_sec: float = visual.get_frame_sec(&"cast", frames)
	var gathered: int = visual._timed_cast_frame(frames, frame_sec)
	_check(gathered >= floori(frames * 0.35) and gathered <= floori(frames * 0.48), "carga longa sustenta mãos reunidas")
	visual._process(frame_sec)
	_check(visual._timed_cast_frame(frames, frame_sec) != gathered, "miolo da carga mantém cadência da folha")
	visual._process(0.85)
	_check(visual._timed_cast_frame(frames, frame_sec) >= floori(frames * 0.5), "liberação aparece perto do fim da carga")
	visual.cancel_cast()
	_check(visual.get_oneshot() == &"" and visual.get_oneshot_left() == 0.0, "cancelamento encerra a pose")
	visual.play_cast_duration(2.0)
	visual.play_oneshot(&"attack")
	visual.cancel_cast()
	_check(visual.get_oneshot() != &"", "cancelamento antigo não apaga outra animação")
	visual.free()


## Finalização das skills (08/10/2026): recuo no disparo, hitstop e imagem residual — só no sprite.
func _test_skill_finish() -> void:
	var v := EntityVisual.new()
	add_child(v)
	v.set_appearance({&"body": &"male", &"outfit": &"traveler", &"weapon": &"blade", &"head": &"straw_hat"})
	v.set_process(false)
	v.cull_offscreen = false
	v.play_cast_duration(1.0)
	v.play_skill_release(Vector3(1, 0, 0))
	_check(v.get_oneshot() == &"", "disparo encerra a pose de carga")
	v._process(DirectionalSprite3D.RECOIL_SEC * 0.3)
	_check(v.get_motion_offset().x < -0.001 and v.position == Vector3.ZERO,
			"recuo para longe do alvo, nó parado (%.3f)" % v.get_motion_offset().x)
	v._process(DirectionalSprite3D.RECOIL_SEC)
	_check(v.get_motion_offset().length() < 0.0001, "recuo volta ao lugar")
	v.play_oneshot(&"attack")
	var left: float = v.get_oneshot_left()
	v.play_hitstop(0.06)
	v._process(0.03)
	_check(v.is_hitstopped() and is_equal_approx(v.get_oneshot_left(), left), "hitstop congela o golpe")
	v._process(0.04)
	v._process(0.02)
	_check(not v.is_hitstopped() and v.get_oneshot_left() < left, "golpe segue depois do hitstop")
	v.play_hitstop(1.0)
	v._process(DirectionalSprite3D.HITSTOP_MAX_SEC + 0.01)
	_check(not v.is_hitstopped(), "hitstop nunca passa de %.0f ms" % (DirectionalSprite3D.HITSTOP_MAX_SEC * 1000.0))
	var ghost: Node3D = v.make_afterimage()
	var sprites: Array[Node] = ghost.get_children()
	var own: bool = not sprites.is_empty()
	for sp: Node in sprites:
		var g: Sprite3D = sp as Sprite3D
		own = own and g.material_override == null and g.transparent \
				and g.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED and g.texture != null
	var body: Sprite3D = sprites[0] as Sprite3D if not sprites.is_empty() else null
	_check(sprites.size() >= 2 and own and body.frame == v.get_body_sprite().frame \
			and body.flip_h == v.get_body_sprite().flip_h,
			"imagem residual: corpo e camadas, mesmo quadro, alfa de verdade sem pontilhado (%d)" % sprites.size())
	ghost.free()
	v.free()


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _name(sector: int) -> String:
	return D.keys()[sector]


## Yaw (convênio do contrato: 0 = olhando para -Z) que faz a entidade olhar para a direção XZ dada.
func _yaw_facing(dir_x: float, dir_z: float) -> float:
	return atan2(-dir_x, -dir_z)


func _expect(yaw: float, to_cam: Vector3, expected: int, label: String) -> void:
	var got: int = DirectionalSprite3D.compute_sector(yaw, to_cam)
	_check(got == expected, "%s: expected %s got %s" % [label, _name(expected), _name(got)])


func _test_facing_with_fixed_camera() -> void:
	# Câmera no lado +Z (yaw de câmera 0): tela-direita = +X, "para a câmera" = +Z.
	var cam := Vector3(0, 10, 10)
	_expect(0.0, cam, D.N, "yaw 0 (olha -Z, de costas)")
	_expect(PI, cam, D.S, "yaw PI (olha para a câmera)")
	_expect(_yaw_facing(1, 0), cam, D.E, "olha +X (direita da tela)")
	_expect(_yaw_facing(-1, 0), cam, D.W, "olha -X (esquerda da tela)")
	_expect(_yaw_facing(1, 1), cam, D.SE, "olha +X+Z")
	_expect(_yaw_facing(-1, 1), cam, D.SW, "olha -X+Z")
	_expect(_yaw_facing(1, -1), cam, D.NE, "olha +X-Z")
	_expect(_yaw_facing(-1, -1), cam, D.NW, "olha -X-Z")
	# Yaw fora de [-PI, PI] deve funcionar igual.
	_expect(TAU * 3.0 + PI, cam, D.S, "yaw com voltas extras")
	_expect(-TAU + _yaw_facing(1, 0), cam, D.E, "yaw negativo com volta")


func _test_camera_orbit_around_stationary_character() -> void:
	# Personagem parado olhando -Z; câmera orbita como no ClientView: offset (0,s,c) girado por yaw.
	var expected: Array[int] = [D.N, D.NE, D.E, D.SE, D.S, D.SW, D.W, D.NW]
	var pitch: float = deg_to_rad(45.0)
	for i in expected.size():
		var cam_yaw: float = i * TAU / 8.0
		var offset: Vector3 = Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, cam_yaw) * 14.0
		_expect(0.0, offset, expected[i], "órbita cam_yaw=%d°" % roundi(rad_to_deg(cam_yaw)))
	# Girar câmera e personagem juntos não muda nada.
	for i in 16:
		var a: float = i * TAU / 16.0
		var offset: Vector3 = Vector3(0, 7, 7).rotated(Vector3.UP, a)
		_expect(PI + a, offset, D.S, "câmera e personagem girados juntos %d" % i)
	# Personagem fora da origem: só o vetor relativo importa.
	var char_pos := Vector3(30, 0, -12)
	var cam_pos := char_pos + Vector3(-10, 10, 0) # câmera a -X do personagem
	_expect(0.0, cam_pos - char_pos, D.W, "câmera em -X, personagem olha -Z (esquerda da tela)")


func _test_sector_boundaries() -> void:
	var cam := Vector3(0, 0, 1)
	var half: float = PI / 8.0
	# Relativo = yaw + PI (câmera em +Z). S cobre (-22.5°, +22.5°).
	_expect(PI + half - 0.01, cam, D.S, "limite S/SE (dentro de S)")
	_expect(PI + half + 0.01, cam, D.SE, "limite S/SE (dentro de SE)")
	_expect(PI - half + 0.01, cam, D.S, "limite SW/S (dentro de S)")
	_expect(PI - half - 0.01, cam, D.SW, "limite SW/S (dentro de SW)")
	_expect(half * 7.0 + 0.01 - PI, cam, D.N, "limite NE/N (dentro de N)")


func _test_rows_and_mirroring() -> void:
	var rows: Array[int] = [0, 1, 2, 3, 4, 3, 2, 1]
	var mirrored: Array[bool] = [false, false, false, false, false, true, true, true]
	for s in 8:
		_check(DirectionalSprite3D.sheet_row_for_sector(s) == rows[s], "linha do setor %s" % _name(s))
		_check(DirectionalSprite3D.is_sector_mirrored(s) == mirrored[s], "espelho do setor %s" % _name(s))


func _test_sprite_feet_at_origin() -> void:
	DirectionalSprite3D.asset_dir = STUB_DIR
	var v := DirectionalSprite3D.new()
	add_child(v)
	v.setup(&"male")
	await get_tree().process_frame # a geometria do Sprite3D é atualizada de forma adiada
	var body: Sprite3D = v.get_node(^"Body")
	var aabb: AABB = body.get_aabb()
	var frame_units: float = Balance.cfg.character_frame_size * Balance.cfg.sprite_pixel_size
	_check(absf(aabb.position.y) < EPS, "pés na origem (aabb.y=%f)" % aabb.position.y)
	_check(absf(aabb.size.y - frame_units) < EPS, "altura do quadro = %f (got %f)" % [frame_units, aabb.size.y])
	_check(absf(aabb.position.x + frame_units * 0.5) < EPS, "centrado em X (aabb.x=%f)" % aabb.position.x)
	_check(body.hframes == 4 and body.vframes == 5, "idle 4x5 quadros")
	v.anim = &"walk"
	_check(body.hframes == 8, "walk 8 quadros")
	var shadow: MeshInstance3D = v.get_node(^"Shadow")
	v.queue_free()


## Combate vivo (GDD §10.2.1, Agente A): golpe pelo tipo de arma em todas as camadas, cast, morte,
## avanço do golpe e empurrão do alvo (só visuais).
func _test_combat_anims() -> void:
	DirectionalSprite3D.asset_dir = "res://assets/characters/"
	_check(DirectionalSprite3D.lunge_curve(0.0) == 0.0 and DirectionalSprite3D.lunge_curve(1.0) == 0.0,
			"avanço começa e termina em 0")
	_check(is_equal_approx(DirectionalSprite3D.lunge_curve(0.5), 1.0), "avanço máximo no impacto")
	_check(DirectionalSprite3D.lunge_curve(0.2) < 0.0, "recua um pouco na preparação")
	var cases: Array = [[&"", &"attack_unarmed"], [&"blade", &"attack_blade"], [&"staff", &"attack_staff"],
			[&"bow", &"attack_bow"], [&"simple_bow", &"attack_bow"]]
	for body: StringName in [&"male", &"female"]:
		for c: Array in cases:
			var v := EntityVisual.new()
			add_child(v)
			v.set_appearance({&"body": body, &"outfit": &"traveler", &"weapon": c[0], &"head": &"straw_hat",
					&"skin": 2, &"hair_style": &"ponytail", &"hair_color": 3, &"eye_color": 1, &"earrings": &"hoop"})
			_check(v.resolve_anim(&"attack") == c[1], "%s arma '%s' -> %s (got %s)" % [body, c[0], c[1], v.resolve_anim(&"attack")])
			_check(v.has_anim(&"cast") and v.has_anim(&"death"), "%s: folhas cast e death" % body)
			_check(v.play_oneshot(&"attack"), "%s: golpe toca" % body)
			# C3: golpes do pipeline 3D têm 8 quadros (antes 6); a duração segue a folha (quadros x 70 ms).
			var nf: int = v.get_frame_count(c[1])
			_check(nf >= 6 and is_equal_approx(v.get_oneshot_left(), v.get_frame_sec(c[1], nf) * nf),
					"%s: golpe %d quadros x %.0f ms" % [body, nf, v.get_frame_sec(c[1], nf) * 1000.0])
			await get_tree().process_frame
			await get_tree().process_frame
			for layer: StringName in [&"Hair", &"FaceAccessory", &"Head"]:
				var spr: Sprite3D = v.get_overlay_sprite(layer)
				_check(spr != null and spr.visible and spr.texture != null
						and spr.texture.resource_path.ends_with("_%s.png" % c[1]),
						"%s %s: camada %s no golpe" % [body, c[0], layer])
			if not (c[0] as StringName).is_empty():
				var front: Sprite3D = v.get_overlay_sprite(&"WeaponFront")
				_check(front != null and front.texture != null and front.texture.resource_path.ends_with("_%s.png" % c[1]),
						"%s: arma %s com a folha do golpe" % [body, c[0]])
			v.play_lunge(Vector3(1, 0, 0))
			await get_tree().create_timer(0.05).timeout
			v.play_knockback(Vector3(0, 0, 1))
			v.queue_free()
	# avanço: desloca o sprite (e as camadas) sem mexer no nó
	var w := EntityVisual.new()
	add_child(w)
	w.set_appearance({&"body": &"male", &"weapon": &"blade"})
	w.play_oneshot(&"attack")
	w.play_lunge(Vector3(1, 0, 0))
	var peak: float = 0.0
	for i: int in 30:
		await get_tree().create_timer(0.02).timeout
		peak = maxf(peak, w.get_body_sprite().position.x)
	_check(peak > 0.1 * Balance.cfg.cell_size, "avanço visível (%.3f)" % peak)
	_check(w.position == Vector3.ZERO and w.get_body_sprite().position.length() < 0.001, "volta ao lugar; nó parado")
	w.play_knockback(Vector3(0, 0, 1))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(w.get_motion_offset().length() > 0.0, "empurrão do alvo")
	w.queue_free()


func _test_traveler_gait() -> void:
	var visual := DirectionalSprite3D.new()
	visual.sprite_base = "res://assets/characters/base/chr_female_base"
	# C3: com as folhas do pipeline 3D (LEGACY_SE_FIX = false) só o espelho SO/O/NO; com as atuais, a correção do SE.
	for sector: int in [D.SE, D.SW]:
		for col: int in 8:
			var expected: bool = ((col % 4 >= 2) != (sector == D.SW)) if DirectionalSprite3D.LEGACY_SE_FIX else (sector == D.SW)
			_check(visual.frame_mirrored(&"walk", col, sector) == expected,
					"pose SE/SW consistente: setor %d quadro %d" % [sector, col])
	visual.sprite_base = "res://assets/npcs/npc_merchant"
	_check(not visual.frame_mirrored(&"walk", 2, D.SE), "correção do Viajante não altera NPCs")
	visual.anim = &"walk"
	visual.walk_cycle_ms = 400.0
	visual._anim_time = 0.15
	visual.walk_cycle_ms = 600.0
	_check(absf(visual._anim_time / 0.6 - 0.375) < EPS, "mudança de velocidade preserva fase do passo")
	visual.free()


## Virada suave (08/10/2026): passa pelos setores do meio, pelo lado mais curto, sem mexer em facing_yaw.
func _test_smooth_turn() -> void:
	_check(DirectionalSprite3D.sector_distance(D.E, D.W) == 4 and DirectionalSprite3D.sector_distance(D.SW, D.SE) == 2,
			"distância entre setores pelo lado curto")
	_check(DirectionalSprite3D.turn_step_toward(D.S, D.E) == D.SE and DirectionalSprite3D.turn_step_toward(D.S, D.W) == D.SW,
			"90°: vai pelo lado mais curto")
	_check(DirectionalSprite3D.turn_step_toward(D.E, D.W) == D.SE, "180° E→W passa pela frente (SE)")
	_check(DirectionalSprite3D.turn_step_toward(D.W, D.E) == D.SW, "180° W→E passa pela frente (SW)")
	_check(DirectionalSprite3D.turn_step_toward(D.SE, D.NW) == D.S, "180° SE→NW passa pela frente (S)")
	DirectionalSprite3D.asset_dir = STUB_DIR
	var v := DirectionalSprite3D.new()
	v.setup(&"male")
	var step: float = DirectionalSprite3D.TURN_STEP_MS / 1000.0
	v._update_turn(D.S, 0.0)
	_check(v.get_sector() == D.S, "primeiro quadro entra direto na direção")
	v._update_turn(D.SE, 0.016)
	_check(v.get_sector() == D.SE and not v.is_turning(), "1 setor de diferença: na hora")
	v._update_turn(D.S, 0.016)
	v._update_turn(D.N, 0.016)
	var seen: Array[int] = [v.get_sector()]
	var t: float = 0.0
	while v.get_sector() != D.N and t < 1.0:
		v._update_turn(D.N, 0.016)
		t += 0.016
		if seen[-1] != v.get_sector():
			seen.append(v.get_sector())
	_check(seen == [D.SE, D.E, D.NE, D.N], "180° S→N passa por SE, E, NE (%s)" % [seen])
	_check(t >= step * 2.5 and t <= step * 3.0 + 0.05, "virada de 180° em ~3 passos de %.0f ms (%.0f ms)" % [step * 1000.0, t * 1000.0])
	_check(v.get_target_sector() == D.N and not v.is_turning(), "chegou ao setor alvo")
	v.turn_step_ms = 0.0
	v._update_turn(D.S, 0.016)
	_check(v.get_sector() == D.S, "turn_step_ms = 0 desliga a virada suave")
	v.free()
	DirectionalSprite3D.asset_dir = "res://assets/characters/"


## Andar: novo clique logo depois de parar continua o ciclo; partida do zero começa no quadro de passagem;
## parar assenta. Mesma velocidade de passada (walk_cycle_ms).
func _test_walk_continuity() -> void:
	DirectionalSprite3D.asset_dir = STUB_DIR
	var v := DirectionalSprite3D.new()
	v.setup(&"male")
	v.walk_cycle_ms = 400.0
	v.anim = &"walk"
	var frames: int = v.get_frame_count(&"walk")
	var col: int = int(v._anim_time / v.get_frame_sec(&"walk", frames))
	_check(col == int(frames * DirectionalSprite3D.WALK_START_PHASE), "partida no quadro de passagem (%d)" % col)
	v._anim_time = 0.23
	v.anim = &"idle"
	_check(v._settle_t == 0.0, "parar de andar começa o assentar")
	v._life_t += 0.1
	v.anim = &"walk"
	_check(is_equal_approx(v._anim_time, 0.23), "novo clique logo depois: ciclo continua (%.3f)" % v._anim_time)
	v.anim = &"idle"
	v._life_t += DirectionalSprite3D.WALK_RESUME_SEC + 0.1
	v.anim = &"walk"
	_check(absf(v._anim_time - 0.4 * DirectionalSprite3D.WALK_START_PHASE) < 0.001, "parado há tempo: recomeça na passagem")
	_check(is_equal_approx(v.get_frame_sec(&"walk", 12) * 12.0, 0.4) and is_equal_approx(v.get_frame_sec(&"walk", 8) * 8.0, 0.4),
			"folha de 12 ou 8 quadros: mesma passada (walk_cycle_ms)")
	v.free()
	DirectionalSprite3D.asset_dir = "res://assets/characters/"
