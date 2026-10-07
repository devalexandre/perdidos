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

var _last_skill_ms: Dictionary[int, int] = {}

var _exists_cache: Dictionary[String, bool] = {}


func _ready() -> void:
	var net: Node = get_node_or_null(^"/root/NetCombat")
	if net == null:
		return
	net.connect(&"hit", _on_hit)
	net.connect(&"entity_died", _on_died)
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null and prog.has_signal(&"skill_cast"):
		prog.connect(&"skill_cast", _on_skill_cast)


## Cada skill tem o próprio som: lançamento no conjurador e impacto no alvo/ponto.
## SkillDef.sfx (se definido) sobrepõe a convenção sfx_skill_<id>_cast / _impact.
func _on_skill_cast(entity_id: int, skill_id: StringName, target_entity_id: int, pos: Vector3,
		_cast_ms: int) -> void:
	_last_skill_ms[entity_id] = Time.get_ticks_msec()
	var net: Node = get_node(^"/root/NetCombat")
	var caster: Node3D = net.call(&"find_entity", entity_id)
	var target: Node3D = net.call(&"find_entity", target_entity_id)
	var def: SkillDef = Content.skill(skill_id)
	var cast: Array[String] = []
	if def != null and not String(def.sfx).is_empty():
		cast.append(String(def.sfx))
	cast.append("sfx_skill_%s_cast" % skill_id)
	cast.append("sfx_cast_begin")
	if caster != null:
		_play(cast, caster.global_position)
	_play(["sfx_skill_%s_impact" % skill_id], target.global_position if target != null else pos)


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
	# Impacto da arma (cada arma tem o seu) + reação de quem apanhou (cada monstro tem a sua).
	# O crítico é uma camada EXTRA: nunca substitui o som da arma (senão um corte vira "pancada").
	if crit:
		_play(["sfx_hit_critical"], target.global_position)
	if source != null and source.get(&"kind") == KIND_PLAYER and not from_skill:
		_play(_weapon_hit_sounds(source), target.global_position)
	_play(_hurt_sounds(target), target.global_position)


func _on_died(entity_id: int) -> void:
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


func _exists(n: String) -> bool:
	if not _exists_cache.has(n):
		_exists_cache[n] = ResourceLoader.exists(AudioDirector.SFX_DIR + n + ".ogg")
	return _exists_cache[n]
