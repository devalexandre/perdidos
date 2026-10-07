extends Node
## Autoload "NetProgress": canal de RPCs do marco "Chegada do Viajante" (docs/contracts-arrival.md).
## Mesmo caminho (/root/NetProgress) no servidor e no cliente. Validação e limite de taxa via Net.
## Dono: Agente Q (progressão: XP, pontos, skills, barra 1–0, títulos, quests).
##
## Intenções (cliente -> servidor): send_allocate_stats, send_skill_level_up, send_hotbar_set,
## send_cast, send_set_title, send_quest_abandon. Eventos (servidor -> cliente): progress_changed
## (estado privado, só o dono), skill_cast (todos da instância, para a prévia/efeito e a barra de
## conjuração) e cast_cancelled (conjuração interrompida).

# ================================================================ sinais do servidor
signal allocate_stats_intent(peer_id: int, points: Dictionary)
signal skill_level_up_intent(peer_id: int, skill_id: StringName)
signal hotbar_set_intent(peer_id: int, slot: int, entry_id: StringName)
signal cast_intent(peer_id: int, skill_id: StringName, target_entity_id: int, ground_pos: Vector3)
signal set_title_intent(peer_id: int, title_id: StringName)
signal quest_abandon_intent(peer_id: int, quest_id: StringName)
## Só com --progression-autotest no servidor (dados de teste).
signal debug_intent(peer_id: int, command: StringName, args: Array)

# ================================================================ sinais do cliente
## Estado completo da progressão do jogador local (ver Progression.snapshot()).
signal progress_changed(progress: Dictionary)
## Alguém na instância lançou (ou começou a conjurar) uma skill.
## Alguém da instância subiu de nível (efeito visual + som para todos por perto).
signal level_up(entity_id: int, level: int)
signal skill_cast(entity_id: int, skill_id: StringName, target_entity_id: int, pos: Vector3,
		cast_ms: int)
## A conjuração de alguém da instância foi interrompida (andou, atordoado, morreu). GDD §8.1.
## skill_id também pode ser o id de um item usável com conjuração.
signal cast_cancelled(entity_id: int, skill_id: StringName)
## Efeito de status numa entidade da instância começou (active = true, duration_sec = duração) ou
## acabou (active = false, 0). status_id: &"buff", &"debuff", &"taunt", &"root", &"stun",
## &"stealth", &"shield", &"def_buff", &"slow", &"dot", &"hot", &"counter", &"mp_regen".
## Para todos da instância (contrato: docs/contracts-city-walk.md, ADENDO 4).
signal status_changed(entity_id: int, status_id: StringName, skill_id: StringName, active: bool,
		duration_sec: float)

## Sem alvo de entidade em send_cast.
const NO_TARGET: int = 0
## Máximo de pontos por pedido de distribuição (anti-abuso; a regra real é dos pontos disponíveis).
const MAX_ALLOCATE_KEYS: int = 8
const MAX_DEBUG_ARGS: int = 8
## Argumento de linha de comando do teste de progressão (servidor e cliente).
const ARG_AUTOTEST: String = "progression-autotest"
## Servidor: comandos de desenvolvimento pelo chat ("/dev ...", ProgressionDebug). Nunca em produção.
const ARG_DEV_COMMANDS: String = "dev-commands"
const CLIENT_TEST_SCRIPT: String = "res://tests/progression/progression_client_test.gd"
## Cliente: captura dos efeitos de skill (precisa do servidor em --progression-autotest).
const ARG_FX_CAPTURE: String = "skill-fx-capture"
const FX_CAPTURE_SCRIPT: String = "res://tests/client/skill_fx_capture.gd"
## Título sob o nome (cliente): nó filho da placa de nome do EntityVisual.
const TITLE_PLATE_NODE: StringName = &"TitlePlate"
const TITLE_PLATE_FONT_SCALE: float = 0.8
## Deslocamento da placa do título abaixo do nome, em múltiplos do tamanho da fonte.
const TITLE_PLATE_OFFSET_LINES: float = 1.1

## Cliente: último estado recebido (janelas abertas depois do evento leem daqui).
var client_progress: Dictionary = {}
## Servidor: --progression-autotest (aceita debug_intent).
var debug_enabled: bool = false
## Servidor: --dev-commands (comandos "/dev ..." no chat; também liga debug_enabled).
var dev_commands: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var autotest: bool = ("--" + ARG_AUTOTEST) in args
	dev_commands = ("--" + ARG_DEV_COMMANDS) in args
	debug_enabled = autotest or dev_commands
	# Captura dos efeitos de skill no cliente real (tests/client/skill_fx_capture.gd).
	if ("--" + ARG_FX_CAPTURE) in args and not ("--server" in args) and ResourceLoader.exists(FX_CAPTURE_SCRIPT):
		var cap: Node = (load(FX_CAPTURE_SCRIPT) as Script).new()
		cap.name = &"SkillFxCapture"
		add_child(cap)
	if autotest and not ("--server" in args) and not OS.has_feature("dedicated_server"):
		if ResourceLoader.exists(CLIENT_TEST_SCRIPT):
			var t: Node = (load(CLIENT_TEST_SCRIPT) as Script).new()
			t.name = &"ProgressionClientTest"
			add_child(t)


func _world_intent(peer_id: int, intent: String) -> bool:
	return Net.call(&"_accept_world_intent", peer_id, intent)


static func _is_id(v: Variant) -> bool:
	return (typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME) \
			and String(v).length() <= Net.MAX_RAW_ID_LENGTH


# ---------------------------------------------------------------- intenções (cliente -> servidor)

@rpc("any_peer", "call_remote", "reliable")
func req_allocate_stats(points: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "allocate_stats"):
		return
	if typeof(points) != TYPE_DICTIONARY or (points as Dictionary).size() > MAX_ALLOCATE_KEYS:
		Net.log_invalid(peer_id, "allocate_stats_bad_args")
		return
	var clean: Dictionary = {}
	for k: Variant in points:
		if not _is_id(k) or typeof(points[k]) != TYPE_INT:
			Net.log_invalid(peer_id, "allocate_stats_bad_args")
			return
		clean[StringName(k)] = int(points[k])
	allocate_stats_intent.emit(peer_id, clean)


@rpc("any_peer", "call_remote", "reliable")
func req_skill_level_up(skill_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "skill_level_up"):
		return
	if not _is_id(skill_id):
		Net.log_invalid(peer_id, "skill_level_up_bad_args")
		return
	skill_level_up_intent.emit(peer_id, StringName(skill_id))


@rpc("any_peer", "call_remote", "reliable")
func req_hotbar_set(slot: Variant, entry_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "hotbar_set"):
		return
	if typeof(slot) != TYPE_INT or not _is_id(entry_id):
		Net.log_invalid(peer_id, "hotbar_set_bad_args")
		return
	hotbar_set_intent.emit(peer_id, int(slot), StringName(entry_id))


@rpc("any_peer", "call_remote", "reliable")
func req_cast(skill_id: Variant, target_entity_id: Variant, ground_pos: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "cast"):
		return
	if not _is_id(skill_id) or typeof(target_entity_id) != TYPE_INT \
			or typeof(ground_pos) != TYPE_VECTOR3 or not (ground_pos as Vector3).is_finite():
		Net.log_invalid(peer_id, "cast_bad_args")
		return
	cast_intent.emit(peer_id, StringName(skill_id), int(target_entity_id), ground_pos as Vector3)


@rpc("any_peer", "call_remote", "reliable")
func req_set_title(title_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "set_title"):
		return
	if not _is_id(title_id):
		Net.log_invalid(peer_id, "set_title_bad_args")
		return
	set_title_intent.emit(peer_id, StringName(title_id))


@rpc("any_peer", "call_remote", "reliable")
func req_quest_abandon(quest_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _world_intent(peer_id, "quest_abandon"):
		return
	if not _is_id(quest_id):
		Net.log_invalid(peer_id, "quest_abandon_bad_args")
		return
	quest_abandon_intent.emit(peer_id, StringName(quest_id))


@rpc("any_peer", "call_remote", "reliable")
func req_debug(command: Variant, args: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not debug_enabled:
		Net.log_invalid(peer_id, "debug_disabled")
		return
	if not _world_intent(peer_id, "debug") or not _is_id(command) or typeof(args) != TYPE_ARRAY \
			or (args as Array).size() > MAX_DEBUG_ARGS:
		return
	debug_intent.emit(peer_id, StringName(command), args)


# ---------------------------------------------------------------- eventos (servidor -> cliente)

## Estado privado: só para o dono.
func push_progress(peer_id: int, progress: Dictionary) -> void:
	_cli_progress.rpc_id(peer_id, progress)


## Para todos os peers da instância (efeito/prévia da skill).
func push_skill_cast(peer_ids: Array[int], entity_id: int, skill_id: StringName,
		target_entity_id: int, pos: Vector3, cast_ms: int) -> void:
	for p: int in peer_ids:
		_cli_skill_cast.rpc_id(p, entity_id, String(skill_id), target_entity_id, pos, cast_ms)


## Para todos os peers da instância: a conjuração foi interrompida.
func push_cast_cancelled(peer_ids: Array[int], entity_id: int, skill_id: StringName) -> void:
	for p: int in peer_ids:
		_cli_cast_cancelled.rpc_id(p, entity_id, String(skill_id))


## Para todos os peers da instância: efeito de status começou/acabou (ver status_changed).
func push_status_changed(peer_ids: Array[int], entity_id: int, status_id: StringName,
		skill_id: StringName, active: bool, duration_sec: float) -> void:
	for p: int in peer_ids:
		_cli_status_changed.rpc_id(p, entity_id, String(status_id), String(skill_id), active, duration_sec)


## Para todos os peers da instância: efeito de subir de nível.
func push_level_up(peer_ids: Array[int], entity_id: int, level: int) -> void:
	for p: int in peer_ids:
		_cli_level_up.rpc_id(p, entity_id, level)


# ---------------------------------------------------------------- cliente

func _connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


## points: {&"str": 2, &"vit": 1, ...} (soma <= pontos disponíveis).
func send_allocate_stats(points: Dictionary) -> void:
	if not _connected():
		return
	var raw: Dictionary = {}
	for k: Variant in points:
		raw[String(k)] = int(points[k])
	req_allocate_stats.rpc_id(Net.SERVER_PEER_ID, raw)


func send_skill_level_up(skill_id: StringName) -> void:
	if _connected():
		req_skill_level_up.rpc_id(Net.SERVER_PEER_ID, String(skill_id))


## entry_id = skill_id (ou item_id de consumível); &"" limpa o espaço. Só fora de combate.
func send_hotbar_set(slot: int, entry_id: StringName) -> void:
	if _connected():
		req_hotbar_set.rpc_id(Net.SERVER_PEER_ID, slot, String(entry_id))


## target_entity_id = NO_TARGET quando não há alvo; ground_pos = ponto no chão (áreas, cone, linha).
func send_cast(skill_id: StringName, target_entity_id: int, ground_pos: Vector3) -> void:
	if _connected():
		req_cast.rpc_id(Net.SERVER_PEER_ID, String(skill_id), target_entity_id, ground_pos)


func send_set_title(title_id: StringName) -> void:
	if _connected():
		req_set_title.rpc_id(Net.SERVER_PEER_ID, String(title_id))


func send_quest_abandon(quest_id: StringName) -> void:
	if _connected():
		req_quest_abandon.rpc_id(Net.SERVER_PEER_ID, String(quest_id))


## Só funciona com o servidor em --progression-autotest.
func send_debug(command: StringName, args: Array = []) -> void:
	if _connected():
		req_debug.rpc_id(Net.SERVER_PEER_ID, String(command), args)


@rpc("authority", "call_remote", "reliable")
func _cli_progress(progress: Dictionary) -> void:
	client_progress = progress
	progress_changed.emit(progress)


@rpc("authority", "call_remote", "reliable")
func _cli_level_up(entity_id: int, level: int) -> void:
	level_up.emit(entity_id, level)


@rpc("authority", "call_remote", "reliable")
func _cli_skill_cast(entity_id: int, skill_id: String, target_entity_id: int, pos: Vector3,
		cast_ms: int) -> void:
	skill_cast.emit(entity_id, StringName(skill_id), target_entity_id, pos, cast_ms)


@rpc("authority", "call_remote", "reliable")
func _cli_status_changed(entity_id: int, status_id: String, skill_id: String, active: bool,
		duration_sec: float) -> void:
	status_changed.emit(entity_id, StringName(status_id), StringName(skill_id), active, duration_sec)


@rpc("authority", "call_remote", "reliable")
func _cli_cast_cancelled(entity_id: int, skill_id: String) -> void:
	cast_cancelled.emit(entity_id, StringName(skill_id))


# ---------------------------------------------------------------- título sob o nome (cliente)

## Chamado pelo NetEntity (cliente) quando title_id muda ou o visual nasce: cria/atualiza uma
## placa menor logo abaixo do nome, na cor da camada do título.
func apply_title_plate(entity: Node3D, title_id: StringName) -> void:
	if Net.is_server or entity == null:
		return
	var visual: Node = entity.get_node_or_null(^"Visual")
	if visual == null or not visual.has_method(&"get_nameplate"):
		return
	var nameplate: Label3D = visual.call(&"get_nameplate") as Label3D
	if nameplate == null:
		return
	var plate: Label3D = nameplate.get_node_or_null(NodePath(String(TITLE_PLATE_NODE))) as Label3D
	var def: TitleDef = Content.title(title_id) if not title_id.is_empty() else null
	if def == null:
		if plate != null:
			plate.visible = false
		return
	if plate == null:
		plate = nameplate.duplicate(0) as Label3D
		plate.name = TITLE_PLATE_NODE
		for c: Node in plate.get_children():
			c.queue_free()
		nameplate.add_child(plate)
	plate.font_size = roundi(nameplate.font_size * TITLE_PLATE_FONT_SCALE)
	plate.position = Vector3(0.0, -nameplate.font_size * nameplate.pixel_size * TITLE_PLATE_OFFSET_LINES, 0.0)
	plate.text = "«%s»" % tr(def.name_key)
	plate.modulate = def.color
	plate.visible = nameplate.visible
