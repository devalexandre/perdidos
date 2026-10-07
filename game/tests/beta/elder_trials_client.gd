extends "res://tests/beta/beta_route_client.gd"
## Isola as três provas para cobrir transferência, falha, nova tentativa e recompensa.

func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _progress.is_empty(), 15.0)
	# O portal usa o título inicial do treino; a mesma preparação do roteiro normal.
	await _training()
	if not await _portal("training_exit", &"city_awakening"):
		_finish()
		return
	for qid: StringName in [&"elder_ze_steel_song", &"elder_aninha_root_fire", &"elder_tiao_sky_feast"]:
		var q: QuestDef = Content.quest(qid)
		for title: StringName in q.required_titles:
			await _dbg(&"grant_title", [title])
		await _dbg(&"quest_accept", [qid])
		await _dbg(&"quest_step", [qid, 3])
		await _dbg(&"set_hp", [99999])
		await _dbg(&"quest_trial", [qid])
		_check(String(qid) + "_arena", await _wait(func() -> bool: return NetWorld.client_map_id == &"elder_trial_arena", 15.0))
		await _sleep(1.0)
		_check(String(qid) + "_privada", String(_local.instance_id).contains(":"))
		if qid == &"elder_aninha_root_fire":
			await _dbg(&"kill_protected", [3])
			_check("mudas_falha_volta", await _wait(func() -> bool: return NetWorld.client_map_id == &"city_awakening", 15.0))
			_check("mudas_falha_nao_avanca", int(_quest(qid).get("step", -1)) == 3)
			await _dbg(&"quest_trial", [qid])
			await _wait(func() -> bool: return NetWorld.client_map_id == &"elder_trial_arena", 15.0)
			await _sleep(1.0)
		if qid == &"elder_ze_steel_song":
			var targets: Array[Node3D] = _entities(KIND_MONSTER, &"trial_twin_shield_puppet")
			_check("fantoche_nasce", not targets.is_empty())
			if not targets.is_empty():
				var before: int = _my_hits
				NetCombat.send_attack(int(targets[0].get(&"entity_id")))
				_check("arena_permite_combate", await _wait(func() -> bool: return _my_hits > before, 10.0))
			await _dbg(&"kill", [&"trial_twin_shield_puppet", 0])
		else:
			await _dbg(&"trial_time", [1.0])
		_check(String(qid) + "_retorno", await _wait(func() -> bool: return NetWorld.client_map_id == &"city_awakening", 15.0))
		_check(String(qid) + "_concluida", bool(_quest(qid).get("ready", false)))
		await _dbg(&"quest_turn_in", [qid])
		_check(String(qid) + "_titulo", q.reward_title in (_progress.get("titles", []) as Array))
	_finish()
