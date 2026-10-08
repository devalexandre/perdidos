extends "res://tests/beta/beta_route_client.gd"
## Arco 1 em rede (servidor --dev-commands): covil do chefe da história no Passo dos Ipês e no andar 4 da Caverna.
##  - de dia não há chefe da história e o ritual responde "aqui não acontece nada enquanto há sol";
##  - à noite ele nasce sozinho, atroz, com o bando de >= 10; derrotado, conta para a quest no passo do ritual;
##  - o ritual faz o chefe nascer na hora (zera a 1 h) e nunca cria um segundo;
##  - ao amanhecer, vivo e fora de luta, ele some com o bando;
##  - andar 4 da Caverna: de dia o chefe de espécie, à noite o Lobisomem da história no lugar dele.
## Rodar: tests/story/run_arc1_test.sh

const Q1: StringName = &"arc1_ch1_saci"
const SACI: StringName = &"story_saci"
const LOBISOMEM: StringName = &"story_lobisomem"


func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _progress.is_empty(), 15.0)
	await _dbg(&"leave_training")
	await _dbg(&"set_hp", [99999])
	await _dbg(&"set_hour", [12])
	await _porto()
	await _dbg(&"goto", [&"fields_sabia_crossroads"])
	var arrived: bool = await _wait(func() -> bool: return NetWorld.client_map_id == &"fields_sabia_crossroads", 30.0)
	_map_label = "fields_sabia_crossroads"
	_check("chegou_passo_dos_ipes", arrived, NetWorld.client_map_id)
	await _sleep(3.0)
	var lair: Vector3 = _marker("StoryLairs/saci")
	_check("covil_do_saci_no_mapa", lair != Vector3.INF)
	# Dia: nada de chefe da história; o ritual não acontece.
	if _quest(Q1).is_empty():
		await _dbg(&"quest_accept", [Q1])
	var ritual_i: int = Content.quest(Q1).steps.size() - 1
	await _dbg(&"quest_step", [Q1, ritual_i])
	await _dbg(&"give_item", [&"cross_sieve", 1])
	await _tp(lair + Vector3(2, 0, 0))
	await _sleep(2.0)
	_check("dia_sem_saci", _story(SACI).is_empty())
	_check("dia_ritual_responde", await _wait(func() -> bool: return "PROG_MSG_RITUAL_DAY" in _system, 5.0), _system)
	# Noite: o Saci nasce sozinho, atroz, com o bando.
	await _tp(lair + Vector3(30, 0, 0))
	await _dbg(&"set_hour", [22])
	var born: bool = await _wait(func() -> bool: return _story(SACI).size() == 1, 10.0)
	_check("noite_saci_nasce_sozinho", born, _story(SACI).size())
	if born:
		_check("saci_atroz", int(_story(SACI)[0].get(&"stage")) == MonsterDef.ATROZ_STAGE)
	await _tp(lair + Vector3(2, 0, 0))
	await _sleep(1.0)
	var escort: int = _monsters_near(&"prank_whirlwind", lair, 12.0)
	_check("saci_com_bando_de_10", escort >= MonsterSpawner.STORY_ESCORT_MIN, escort)
	_check("ritual_com_saci_vivo_nao_duplica", _story(SACI).size() == 1)
	# Vitória (nascimento natural) conta para quem está no passo do ritual.
	await _dbg(&"set_hp", [99999])
	await _chat("/derrubar chefe")
	var won: bool = await _wait(func() -> bool: return bool(_quest(Q1).get("ready", false)), 8.0)
	_check("vitoria_natural_conta_para_a_historia", won, _quest(Q1))
	_check("peneira_usada", _count_item(&"cross_sieve") == 0)
	# Volta ao passo do ritual: o Saci espera 1 h, mas o ritual faz ele nascer já (e só um).
	await _tp(lair + Vector3(30, 0, 0))
	await _dbg(&"quest_step", [Q1, ritual_i])
	await _dbg(&"give_item", [&"cross_sieve", 1])
	await _sleep(2.0)
	_check("derrotado_espera_1h", _story(SACI).is_empty())
	await _tp(lair + Vector3(2, 0, 0))
	var summoned: bool = await _wait(func() -> bool: return _story(SACI).size() == 1, 6.0)
	_check("ritual_faz_nascer_na_hora", summoned and "PROG_MSG_RITUAL_SPAWNED" in _system)
	await _tp(lair + Vector3(30, 0, 0))
	await _sleep(1.0)
	await _tp(lair + Vector3(2, 0, 0))
	await _sleep(2.0)
	_check("ritual_de_novo_nao_cria_outro", _story(SACI).size() == 1, _story(SACI).size())
	# Amanhece com ele vivo e fora de luta: some com o bando.
	await _tp(lair + Vector3(40, 0, 0))
	await _sleep(4.0)
	await _dbg(&"set_hour", [8])
	var gone: bool = await _wait(func() -> bool: return _story(SACI).is_empty(), 10.0)
	_check("amanhecer_saci_some", gone and "SYS_STORY_BOSS_VANISHED" in _system)
	await _dbg(&"quest_step", [Q1, ritual_i + 1])
	var causos: int = int(_progress.get("causos", 0))
	await _dbg(&"quest_turn_in", [Q1])
	_check("entrega_da_causo_e_gorro", int(_progress.get("causos", 0)) > causos and _count_item(&"whirlwind_cap") == 1,
			[_progress.get("causos"), _count_item(&"whirlwind_cap")])
	await _cave()
	_finish()


## Porto: Dona Jacinta oferece o capítulo 1 em páginas (Continuar...) e a Jandira conta o causo do primeiro relato.
func _porto() -> void:
	await _dbg(&"goto", [&"city_awakening"])
	await _wait(func() -> bool: return NetWorld.client_map_id == &"city_awakening", 30.0)
	_map_label = "city_awakening"
	await _sleep(3.0)
	var talked: bool = await _talk(&"dona_jacinta")
	_check("jacinta_no_porto", talked)
	if not talked:
		return
	_check("jacinta_oferece_capitulo_1", await _choose("QUEST_ARC1_CH1_OPTION"), _opts)
	var pages: Array[String] = [_text]
	while "QUEST_OPT_CONTINUE" in _opts and pages.size() < 8:
		await _choose("QUEST_OPT_CONTINUE")
		pages.append(_text)
	_check("oferta_em_paginas", pages == ["QUEST_ARC1_CH1_OFFER", "QUEST_ARC1_CH1_OFFER_P2", "QUEST_ARC1_CH1_OFFER_P3",
			"QUEST_ARC1_CH1_OFFER_P4"], pages)
	await _choose("QUEST_OPT_ACCEPT")
	_check("capitulo_1_aceito", await _wait(func() -> bool: return not _quest(Q1).is_empty(), 5.0))
	Net.send_dialogue_close()
	if await _talk(&"fruit_vendor"):
		_check("jandira_tem_o_causo", await _choose("QUEST_ARC1_CH1_LORE_1_OPT"), _opts)
		while "QUEST_OPT_CONTINUE" in _opts:
			await _choose("QUEST_OPT_CONTINUE")
		_check("causo_termina_na_ultima_pagina", _text == "QUEST_ARC1_CH1_LORE_1_P3" and "QUEST_OPT_LORE_DONE" in _opts,
				[_text, _opts])
		await _choose("QUEST_OPT_LORE_DONE")
		_check("relato_1_conta", await _wait(func() -> bool: return int(_quest(Q1).get("step", 0)) == 1, 5.0), _quest(Q1))
	Net.send_dialogue_close()


## Andar 4 da Caverna: de dia o chefe de espécie; à noite o Lobisomem da história no lugar dele.
func _cave() -> void:
	await _dbg(&"set_hour", [12])
	await _dbg(&"goto", [&"cave_reino_encoberto_4"])
	var arrived: bool = await _wait(func() -> bool: return NetWorld.client_map_id == &"cave_reino_encoberto_4", 30.0)
	_map_label = "cave_reino_encoberto_4"
	_check("chegou_andar_4", arrived)
	await _sleep(3.0)
	var lair: Vector3 = _marker("StoryLairs/lobisomem")
	await _tp(lair + Vector3(0, 0, 14))
	await _sleep(2.0)
	_check("dia_chefe_de_especie", _boss(&"cave_werewolf") != null and _story(LOBISOMEM).is_empty())
	await _dbg(&"set_hour", [22])
	var swapped: bool = await _wait(func() -> bool: return _story(LOBISOMEM).size() == 1, 10.0)
	_check("noite_lobisomem_da_historia", swapped)
	await _wait(func() -> bool: return _species_boss(&"cave_werewolf") == null, 10.0)
	_check("noite_chefe_de_especie_cede_o_lugar", _species_boss(&"cave_werewolf") == null)
	await _dbg(&"set_hour", [12])
	await _sleep(1.0)


func _story(mid: StringName) -> Array[Node3D]:
	return _entities(KIND_MONSTER, mid)


func _species_boss(mid: StringName) -> Node3D:
	for e: Node3D in _entities(KIND_MONSTER, mid):
		if int(e.get(&"stage")) >= CombatRules.STAGE_BOSS:
			return e
	return null


func _monsters_near(mid: StringName, p: Vector3, radius: float) -> int:
	var n: int = 0
	for e: Node3D in _entities(KIND_MONSTER, mid):
		if _flat(e.global_position, p) <= radius:
			n += 1
	return n
