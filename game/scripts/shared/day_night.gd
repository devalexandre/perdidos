extends Node
## Autoload "DayNight": relógio de dia e noite do mundo (GDD §10.7). Mesmo caminho (/root/DayNight) no
## servidor e no cliente. As contas ficam em WorldClock (puras).
##
## Servidor (--server): dono do relógio. Começa em Balance.cfg.day_night_start_sec (ou --day-night=day|night
## para testes, que força). Emite night_changed(is_night) na virada e manda o estado aos clientes quando
## entram numa instância, a cada Balance.cfg.day_night_sync_interval_sec e quando muda (comando de teste).
## Cliente: guarda o último estado e anda o relógio sozinho entre as mensagens; emite night_changed
## localmente. A luz do cliente fica em scripts/client/env/day_night_light.gd (criada aqui).
##
## Consultas (servidor e cliente):
##   time_of_cycle() -> s desde o início do dia (com a força aplicada)
##   is_night_on_map(map_id) / night_amount_on_map(map_id)  (Campo de Treino sempre de dia)
##   clock_text() -> "HH:MM"
## Servidor (comandos de teste, MonsterDebug): set_force(WorldClock.Force.*), set_time_of_cycle(t).

## Mudou dia <-> noite (regra global; o Campo de Treino ignora — use is_night_on_map).
signal night_changed(is_night: bool)
## Cliente: chegou/mudou o estado (força, hora).
signal clock_synced()

const ARG_SERVER: String = "--server"
## Teste/captura: --day-night=day|night força; --day-night-at=<s> começa nesse ponto do ciclo.
const ARG_FORCE: String = "--day-night="
const ARG_AT: String = "--day-night-at="
const FORCE_NAMES: Dictionary[String, int] = {"day": WorldClock.Force.DAY, "night": WorldClock.Force.NIGHT,
		"none": WorldClock.Force.NONE}
const LIGHT_SCRIPT: String = "res://scripts/client/env/day_night_light.gd"
const MSEC: float = 1000.0
const MSG_NIGHT: String = "SYS_NIGHT_FALLS"
const MSG_DAY: String = "SYS_DAY_BREAKS"

var is_server: bool = false
## Força atual (WorldClock.Force).
var force: int = WorldClock.Force.NONE
## Durações em uso (o servidor manda as dele; o cliente usa estas em vez do Balance local).
var day_sec: float = 0.0
var night_sec: float = 0.0
var transition_sec: float = 0.0
var _cfg: BalanceConfig = null
## Relógio: t (s do ciclo) medido em _base_msec (ticks locais).
var _base_t: float = 0.0
var _base_msec: int = 0
var _last_night: bool = false
var _next_sync_msec: int = 0
var synced: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	is_server = ARG_SERVER in args or OS.has_feature("dedicated_server")
	_cfg = Balance.cfg.duplicate() as BalanceConfig
	day_sec = _cfg.day_night_day_sec
	night_sec = _cfg.day_night_night_sec
	transition_sec = _cfg.day_night_transition_sec
	_base_t = _cfg.day_night_start_sec
	_base_msec = Time.get_ticks_msec()
	for a: String in args:
		if a.begins_with(ARG_FORCE):
			force = FORCE_NAMES.get(a.trim_prefix(ARG_FORCE), WorldClock.Force.NONE)
		elif a.begins_with(ARG_AT) and a.trim_prefix(ARG_AT).is_valid_float():
			_base_t = a.trim_prefix(ARG_AT).to_float()
	_last_night = is_night()
	if is_server:
		Net.peer_instance_ready.connect(_on_peer_instance_ready)
		Net.log_line("day_night_ready", {"day_sec": day_sec, "night_sec": night_sec, "t": snappedf(time_of_cycle(), 0.1),
				"night": _last_night, "force": force})
	elif ResourceLoader.exists(LIGHT_SCRIPT):
		var light: Node = (load(LIGHT_SCRIPT) as Script).new()
		light.name = "DayNightLight"
		add_child(light)


func _process(_delta: float) -> void:
	var night: bool = is_night()
	if night != _last_night:
		_last_night = night
		if is_server:
			Net.log_line("day_night_turn", {"night": night, "clock": clock_text(), "force": force})
			_push_all()
			_announce(night)
		night_changed.emit(night)
	if is_server and Time.get_ticks_msec() >= _next_sync_msec:
		_push_all()


# ---------------------------------------------------------------- consultas

func config() -> BalanceConfig:
	_cfg.day_night_day_sec = day_sec
	_cfg.day_night_night_sec = night_sec
	_cfg.day_night_transition_sec = transition_sec
	return _cfg


## Tempo do ciclo sem a força (s desde o início do dia).
func raw_time_of_cycle() -> float:
	return WorldClock.time_of_cycle(_base_t + float(Time.get_ticks_msec() - _base_msec) / MSEC, config())


## Tempo do ciclo com a força aplicada.
func time_of_cycle() -> float:
	return WorldClock.forced_time(raw_time_of_cycle(), force, config())


func is_night() -> bool:
	return WorldClock.is_night(time_of_cycle(), config())


func night_amount() -> float:
	return WorldClock.night_amount(time_of_cycle(), config())


func is_night_on_map(map_id: StringName) -> bool:
	return WorldClock.map_follows_clock(map_id, force, config()) and is_night()


func night_amount_on_map(map_id: StringName) -> float:
	return night_amount() if WorldClock.map_follows_clock(map_id, force, config()) else 0.0


func clock_text() -> String:
	return WorldClock.clock_text(time_of_cycle(), config())


func lunar_phase_index() -> int:
	return WorldClock.lunar_phase_index(float(Time.get_unix_time_from_system()))


func is_full_moon_night(map_id: StringName) -> bool:
	return is_night_on_map(map_id) and lunar_phase_index() == 2


## Identificador estável por dia UTC, para deduplicar observações mesmo após reinício do servidor.
func story_night_id() -> String:
	return str(floori(float(Time.get_unix_time_from_system()) / WorldClock.LUNAR_DAY_SEC))


func sec_to_next_turn() -> float:
	return WorldClock.sec_to_next_turn(time_of_cycle(), config())


## Estado para log/debug.
func describe() -> Dictionary:
	return {"clock": clock_text(), "night": is_night(), "t": snappedf(time_of_cycle(), 0.1),
			"force": force, "next_turn_sec": roundi(sec_to_next_turn()), "day_sec": day_sec,
			"night_sec": night_sec}


# ---------------------------------------------------------------- servidor: comandos de teste

func set_force(value: int) -> void:
	force = value
	Net.log_line("day_night_force", describe())
	_push_all()


## Pula o relógio para t (s desde o início do dia; ex.: day_sec - 10 = 10 s antes de anoitecer).
func set_time_of_cycle(t: float) -> void:
	_base_t = t
	_base_msec = Time.get_ticks_msec()
	Net.log_line("day_night_set_time", describe())
	_push_all()


## Aviso da virada para quem está num mapa que segue o relógio (o Campo de Treino não recebe).
func _announce(night: bool) -> void:
	for p: int in Net.get_world_peer_ids():
		var map_id := StringName(String(Net.get_peer_instance(p)).get_slice(Net.INSTANCE_SEPARATOR, 0))
		if WorldClock.map_follows_clock(map_id, force, config()):
			Net.push_system_message(p, MSG_NIGHT if night else MSG_DAY)


func _on_peer_instance_ready(peer_id: int, _instance_id: StringName) -> void:
	_push(peer_id)


func _push_all() -> void:
	_next_sync_msec = Time.get_ticks_msec() + int(_cfg.day_night_sync_interval_sec * MSEC)
	for p: int in Net.get_world_peer_ids():
		_push(p)


func _push(peer_id: int) -> void:
	if multiplayer.multiplayer_peer == null or peer_id not in multiplayer.get_peers():
		return
	_cli_clock.rpc_id(peer_id, raw_time_of_cycle(), force, day_sec, night_sec, transition_sec)


# ---------------------------------------------------------------- cliente

@rpc("authority", "call_remote", "reliable")
func _cli_clock(t: float, p_force: int, p_day_sec: float, p_night_sec: float, p_transition_sec: float) -> void:
	day_sec = p_day_sec
	night_sec = p_night_sec
	transition_sec = p_transition_sec
	force = p_force
	_base_t = t
	_base_msec = Time.get_ticks_msec()
	synced = true
	clock_synced.emit()
