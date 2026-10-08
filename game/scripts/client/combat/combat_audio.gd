class_name CombatAudio
extends Node
## Sons do combate (GDD §10.2.1): golpe do atacante, dano no alvo, crítico, erro e morte.
## Escuta o NetCombat e escolhe o primeiro arquivo que existir numa lista do mais específico para o
## mais genérico (ex.: sfx_mon_<id>_attack → sfx_mon_attack_generic). Arquivos do catálogo
## tools/audio/sound_catalog.json (fase "combat"). Criado pelo AudioDirector.

const KIND_MONSTER: StringName = &"monster"
const KIND_PLAYER: StringName = &"player"
const WEAPON_KEY: StringName = &"weapon"
const WEAPON_ITEM_KEY: StringName = &"weapon_item"
## Depois de lançar uma skill, o golpe que ela causa não toca também o som de ataque básico.
const SKILL_SUPPRESS_MS: int = 500
## Disparo (fim da carga, 08/10/2026): som próprio da skill, senão o da escola (suporte), senão o
## genérico sorteado entre as variações (sfx_skill_release, _2, _3...). Gerados por gen_skill_energy.py.
const RELEASE_GENERIC: String = "sfx_skill_release"
const RELEASE_SCHOOL: Dictionary[StringName, String] = {&"support": "sfx_skill_release_support"}
## Impacto forte (estalo + grave) dos golpes de skill sem som próprio, sorteado entre as variações.
const IMPACT_GENERIC: String = "sfx_skill_impact"
const DAMAGE_EFFECTS: Array[SkillDef.Effect] = [SkillDef.Effect.PHYSICAL_DAMAGE, SkillDef.Effect.MAGIC_DAMAGE,
	SkillDef.Effect.DAMAGE_OVER_TIME, SkillDef.Effect.DASH_STUN, SkillDef.Effect.MULTI_HIT,
	SkillDef.Effect.KNOCKBACK, SkillDef.Effect.PULL, SkillDef.Effect.STUN]
const MAX_VARIANTS: int = 4

var _last_skill_ms: Dictionary[int, int] = {}

var _exists_cache: Dictionary[String, bool] = {}
var _charges: Dictionary[int, Node3D] = {}
var _pending_impacts: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	SkillPresentation.events.impact.connect(_on_visual_impact)
	var net: Node = get_node_or_null(^"/root/NetCombat")
	if net == null:
		return
	net.connect(&"hit", _on_hit)
	net.connect(&"entity_died", _on_died)
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null and prog.has_signal(&"skill_cast"):
		prog.connect(&"skill_cast", _on_skill_cast)
		prog.connect(&"cast_cancelled", _on_cast_cancelled)


## Cada skill tem o próprio som: lançamento no conjurador e impacto no alvo/ponto.
## SkillDef.sfx (se definido) sobrepõe a convenção sfx_skill_<id>_cast / _impact.
func _on_skill_cast(entity_id: int, skill_id: StringName, target_entity_id: int, pos: Vector3,
		cast_ms: int) -> void:
	_on_cast_cancelled(entity_id, skill_id)
	_last_skill_ms[entity_id] = Time.get_ticks_msec() + maxi(0, cast_ms)
	var net: Node = get_node(^"/root/NetCombat")
	var caster: Node3D = net.call(&"find_entity", entity_id)
	var target: Node3D = net.call(&"find_entity", target_entity_id)
	var def: SkillDef = Content.any_skill(skill_id)
	var cast: Array[String] = []
	if def != null and not String(def.sfx).is_empty():
		cast.append(String(def.sfx))
	cast.append("sfx_skill_%s_cast" % skill_id)
	cast.append("sfx_cast_begin")
	if caster != null:
		_play(cast, caster.global_position)
		var charge_sec: float = maxf(0.0, cast_ms / 1000.0 - (def.ground_warning_sec if def != null else 0.0))
		if charge_sec >= 0.12:
			var charge: Node3D = (load("res://scripts/client/combat/skill_charge_audio.gd") as Script).new()
			charge.set(&"follow", caster)
			charge.set(&"duration", charge_sec)
			charge.set(&"school", def.school if def != null else &"")
			add_child(charge)
			_charges[entity_id] = charge
	var impact: Array[String] = _impact_sounds(skill_id, def, caster)
	var release_sec: float = maxf(0.0, cast_ms / 1000.0 - (def.ground_warning_sec if def != null else 0.0))
	if cast_ms > 0:
		_pending_impacts[entity_id] = {"left": cast_ms / 1000.0, "target": target_entity_id,
			"pos": pos, "sound": impact, "caster": caster, "release": release_sec if release_sec >= 0.12 else -1.0,
			"skill": skill_id, "visual": _uses_visual_impact(def), "timeout": cast_ms / 1000.0 + 10.0,
			"school": def.school if def != null else &""}
	elif _uses_visual_impact(def):
		_pending_impacts[entity_id] = {"left": 0.0, "target": target_entity_id, "pos": pos,
			"sound": impact, "caster": caster, "skill": skill_id, "release": -1.0,
			"visual": true, "timeout": 10.0}
	else:
		_play(impact, target.global_position if target != null else pos)


func _on_cast_cancelled(entity_id: int, _skill_id: StringName) -> void:
	var charge: Variant = _charges.get(entity_id)
	if is_instance_valid(charge):
		charge.call(&"stop")
	_charges.erase(entity_id)
	_pending_impacts.erase(entity_id)
	_last_skill_ms.erase(entity_id)


func _process(delta: float) -> void:
	for id: int in _charges.keys():
		if not is_instance_valid(_charges[id]):
			_charges.erase(id)
	for id: int in _pending_impacts.keys():
		var job: Dictionary = _pending_impacts[id]
		var caster: Variant = job["caster"]
		if not is_instance_valid(caster) or not caster.is_inside_tree() or caster.is_queued_for_deletion() \
				or (&"hp_ratio" in caster and float(caster.get(&"hp_ratio")) <= 0.0):
			_on_cast_cancelled(id, &"")
			continue
		job["left"] -= delta
		job["timeout"] -= delta
		if float(job.get("release", -1.0)) >= 0.0:
			job["release"] -= delta
			if float(job["release"]) <= 0.0:
				job["release"] = -1.0
				var release: Array[String] = _release_sounds(job["skill"], job.get("school", &""))
				if not release.is_empty():
					_play(release, (caster as Node3D).global_position)
		if float(job["timeout"]) <= 0.0:
			_pending_impacts.erase(id)
			continue
		if float(job["left"]) <= 0.0 and not bool(job["visual"]):
			var target: Node3D = get_node(^"/root/NetCombat").call(&"find_entity", int(job["target"]))
			_play(job["sound"], target.global_position if is_instance_valid(target) else job["pos"])
			_pending_impacts.erase(id)


## Com SkillFx, toda receita emite o contato visual (SkillFx._contact): o impacto toca nele, inclusive
## golpes corpo a corpo (no corte, não no começo do lançamento). Sem receita, vale o relógio da conjuração.
func _uses_visual_impact(def: SkillDef) -> bool:
	if def == null or SkillPresentation.visual_owners == 0:
		return false
	return SkillFx.recipe_for(def) != &""


## Disparo: próprio → da escola → genérico sorteado. Só nomes que existem (lista vazia = mudo).
func _release_sounds(skill_id: StringName, school: StringName) -> Array[String]:
	var out: Array[String] = []
	for n: String in ["sfx_skill_%s_release" % skill_id, RELEASE_SCHOOL.get(school, ""), _variant(RELEASE_GENERIC)]:
		if not n.is_empty() and _exists(n):
			out.append(n)
	return out


## Impacto da skill: o próprio; senão, golpe físico de jogador usa o acerto da arma do conjurador (decisão do
## dono, 08/10/2026: cada arma soa diferente); o impacto forte genérico fica para as demais skills de dano e como
## último recurso.
func _impact_sounds(skill_id: StringName, def: SkillDef, caster: Node3D) -> Array[String]:
	var out: Array[String] = ["sfx_skill_%s_impact" % skill_id]
	if def != null and caster != null and def.effect in [SkillDef.Effect.PHYSICAL_DAMAGE, SkillDef.Effect.MULTI_HIT,
			SkillDef.Effect.DASH_STUN, SkillDef.Effect.KNOCKBACK] and caster.get(&"kind") == KIND_PLAYER \
			and caster.get(&"appearance") is Dictionary:
		out.append_array(_weapon_hit_sounds(caster))
	if def != null and def.effect in DAMAGE_EFFECTS:
		var generic: String = _variant(IMPACT_GENERIC)
		if not generic.is_empty():
			out.append(generic)
	return out


func _on_visual_impact(caster_id: int, skill_id: StringName, at: Vector3) -> void:
	var job: Dictionary = _pending_impacts.get(caster_id, {})
	if job.is_empty() or job["skill"] != skill_id or not bool(job["visual"]):
		return
	_play(job["sound"], at)
	_pending_impacts.erase(caster_id) # uma camada sonora por lançamento, inclusive flechas múltiplas


func _on_hit(source_id: int, target_id: int, amount: int, crit: bool, _damage_type: int,
		_target_hp_ratio: float) -> void:
	var net: Node = get_node(^"/root/NetCombat")
	var source: Node3D = net.call(&"find_entity", source_id)
	var target: Node3D = net.call(&"find_entity", target_id)
	var miss: bool = amount == int(net.get(&"MISS_AMOUNT"))
	var from_skill: bool = Time.get_ticks_msec() - _last_skill_ms.get(source_id, -SKILL_SUPPRESS_MS) \
			< SKILL_SUPPRESS_MS
	if source != null and not from_skill:
		_play(_attack_sounds(source, miss), source.global_position)
	if target == null or miss:
		return
	# Skill: crítico e dor do alvo saem no contato visual, junto do impacto (SkillPresentation).
	if SkillPresentation.defer(source_id, _target_sounds.bind(source_id, target_id, crit, from_skill)):
		return
	_target_sounds(source_id, target_id, crit, from_skill)


func _target_sounds(source_id: int, target_id: int, crit: bool, from_skill: bool) -> void:
	var net: Node = get_node(^"/root/NetCombat")
	var source: Node3D = net.call(&"find_entity", source_id)
	var target: Node3D = net.call(&"find_entity", target_id)
	if target == null:
		return
	# Impacto da arma (cada arma tem o seu) + reação de quem apanhou (cada monstro tem a sua).
	# O crítico é uma camada EXTRA: nunca substitui o som da arma (senão um corte vira "pancada").
	if crit:
		_play(["sfx_hit_critical"], target.global_position)
	if source != null and source.get(&"kind") == KIND_PLAYER and not from_skill:
		_play(_weapon_hit_sounds(source), target.global_position)
	_play(_hurt_sounds(target), target.global_position)


func _on_died(entity_id: int) -> void:
	_on_cast_cancelled(entity_id, &"")
	var e: Node3D = get_node(^"/root/NetCombat").call(&"find_entity", entity_id)
	if e == null:
		return
	if e.get(&"kind") == KIND_MONSTER:
		_play(["sfx_mon_%s_death" % e.get(&"def_id"), "sfx_mon_death_generic"], e.global_position)
	elif e.get(&"kind") == KIND_PLAYER:
		_play(["sfx_player_down"], e.global_position)


## Som de quem ataca: monstro pela espécie; jogador pela arma visível (lâmina, cajado) ou desarmado.
func _attack_sounds(e: Node3D, miss: bool) -> Array[String]:
	var out: Array[String] = []
	if miss:
		out.append("sfx_miss")
	if e.get(&"kind") == KIND_MONSTER:
		out.append_array(["sfx_mon_%s_attack" % e.get(&"def_id"), "sfx_mon_attack_generic"])
	else:
		var app: Dictionary = e.get(&"appearance")
		var item: StringName = app.get(WEAPON_ITEM_KEY, &"")
		if not String(item).is_empty():
			out.append("sfx_weapon_%s_swing" % item)
		match app.get(WEAPON_KEY, &""):
			&"blade": out.append("sfx_swing_blade")
			&"staff": out.append("sfx_swing_staff")
			_: out.append("sfx_swing_unarmed")
	return out


## Som do golpe acertando, pela arma do atacante: item → tipo → desarmado.
func _weapon_hit_sounds(e: Node3D) -> Array[String]:
	var app: Dictionary = e.get(&"appearance")
	var out: Array[String] = []
	var item: StringName = app.get(WEAPON_ITEM_KEY, &"")
	if not String(item).is_empty():
		out.append("sfx_weapon_%s_hit" % item)
	match app.get(WEAPON_KEY, &""):
		&"blade": out.append("sfx_hit_blade")
		&"staff": out.append("sfx_hit_staff")
		_: out.append("sfx_hit_unarmed")
	return out


func _hurt_sounds(e: Node3D) -> Array[String]:
	if e.get(&"kind") == KIND_MONSTER:
		return ["sfx_mon_%s_hurt" % e.get(&"def_id"), "sfx_mon_hurt_generic"]
	return ["sfx_player_hurt"]


func _play(candidates: Array[String], pos: Vector3) -> void:
	for n: String in candidates:
		if _exists(n):
			AudioDirector.play_sfx(StringName(n), pos)
			return


## Sorteia entre <base>, <base>_2 … <base>_N que existirem ("" se nenhum), para o som não repetir.
func _variant(base: String) -> String:
	var found: Array[String] = []
	for i: int in range(1, MAX_VARIANTS + 1):
		var n: String = base if i == 1 else "%s_%d" % [base, i]
		if _exists(n):
			found.append(n)
	return "" if found.is_empty() else found.pick_random()


func _exists(n: String) -> bool:
	if not _exists_cache.has(n):
		_exists_cache[n] = ResourceLoader.exists(AudioDirector.SFX_DIR + n + ".ogg")
	return _exists_cache[n]
