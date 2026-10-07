class_name NetClock
extends RefCounted
## Relógio do servidor visto de qualquer processo (GDD §10.1: todos reproduzem o mesmo caminho a
## partir do instante de início dado pelo servidor).
##
## Servidor: server_now_msec() = relógio local (offset 0).
## Cliente: estima offset = relógio_servidor - relógio_local com pings simples (o NetEntity do
## jogador local manda; ver NetEntity._clock_*). Guarda as últimas SAMPLE_WINDOW amostras e usa a de
## menor RTT (a menos afetada por fila/jitter), com offset = t_servidor + RTT/2 - t_recebido.

## Amostras guardadas (a de menor RTT vale).
const SAMPLE_WINDOW: int = 8
## Pings iniciais (rajada) e intervalo entre eles; depois, um ping a cada RESYNC_INTERVAL_MSEC.
const INITIAL_PINGS: int = 5
const INITIAL_PING_INTERVAL_MSEC: float = 100.0
const RESYNC_INTERVAL_MSEC: float = 2000.0
const USEC_PER_MSEC: float = 1000.0

## offset (ms) somado ao relógio local para obter o do servidor.
static var offset_msec: float = 0.0
static var synced: bool = false
## RTT (ms) da amostra em uso.
static var rtt_msec: float = 0.0
static var _samples: Array[Vector2] = [] # (rtt, offset)
static var _pings_sent: int = 0
static var _last_ping_msec: float = -INF


## Relógio local em ms (fração de ms incluída).
static func local_now_msec() -> float:
	return Time.get_ticks_usec() / USEC_PER_MSEC


## Relógio do servidor estimado (ms, com fração).
static func server_now_msec() -> float:
	return local_now_msec() + offset_msec


## Relógio do servidor em ms inteiros (para o estado replicado).
static func server_now_msec_int() -> int:
	return int(server_now_msec())


static func reset() -> void:
	offset_msec = 0.0
	synced = false
	rtt_msec = 0.0
	_samples.clear()
	_pings_sent = 0
	_last_ping_msec = -INF


## Cliente: hora de mandar outro ping?
static func should_ping() -> bool:
	var now: float = local_now_msec()
	var interval: float = INITIAL_PING_INTERVAL_MSEC if _pings_sent < INITIAL_PINGS \
			else RESYNC_INTERVAL_MSEC
	return now - _last_ping_msec >= interval


static func mark_ping_sent() -> void:
	_pings_sent += 1
	_last_ping_msec = local_now_msec()


## Cliente: resposta do servidor ao ping mandado em client_send_msec (relógio local).
static func add_sample(client_send_msec: float, server_msec: float) -> void:
	var recv: float = local_now_msec()
	var rtt: float = maxf(0.0, recv - client_send_msec)
	_samples.append(Vector2(rtt, server_msec + rtt * 0.5 - recv))
	if _samples.size() > SAMPLE_WINDOW:
		_samples.pop_front()
	var best: Vector2 = _samples[0]
	for s: Vector2 in _samples:
		if s.x < best.x:
			best = s
	rtt_msec = best.x
	offset_msec = best.y
	synced = true
