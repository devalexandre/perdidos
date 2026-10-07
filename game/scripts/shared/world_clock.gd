class_name WorldClock
extends RefCounted
## Relógio do mundo (GDD §10.7): contas puras do ciclo de dia e noite, iguais no servidor e no cliente.
## O estado autoritativo e a replicação ficam no autoload DayNight (scripts/shared/day_night.gd).
##
## Um ciclo = dia (Balance.cfg.day_night_day_sec) + noite (day_night_night_sec). "t" = segundos desde o
## início do dia atual do ciclo (0 <= t < ciclo). É noite quando t >= duração do dia.
## night_amount(t) vai de 0 (dia pleno) a 1 (noite plena) com uma rampa suave (smoothstep) de
## day_night_transition_sec centrada em cada virada (anoitecer e amanhecer): só a luz usa a rampa;
## a regra do jogo (forma atroz) usa is_night(t).
## Forçar (comando de teste do dono): FORCE_DAY / FORCE_NIGHT congelam o relógio no meio do dia/da noite.

enum Force { NONE, DAY, NIGHT }

## Hora mostrada (só texto): o dia vai das 6h às 18h e a noite das 18h às 6h.
const DAY_START_HOUR: float = 6.0
const DAY_HOURS: float = 12.0
const HOURS_PER_DAY: float = 24.0
const LUNAR_DAY_SEC: float = 86400.0
const LUNAR_CYCLE_DAYS: float = 7.0
const LUNAR_PHASE_KEYS: Array[String] = ["HUD_MOON_NEW", "HUD_MOON_WAXING", "HUD_MOON_FULL", "HUD_MOON_WANING"]


## Fase compartilhada por todos os clientes; o ciclo de sete dias usa relógio Unix, não tempo local de jogo.
## 0 = nova, 1 = crescente, 2 = cheia, 3 = minguante.
static func lunar_phase_index(unix_time: float, epoch_unix: float = 0.0,
		cycle_days: float = LUNAR_CYCLE_DAYS) -> int:
	var cycle_sec: float = maxf(1.0, cycle_days) * LUNAR_DAY_SEC
	var lunar_day: int = floori(fposmod(unix_time - epoch_unix, cycle_sec) / LUNAR_DAY_SEC)
	if lunar_day == 0:
		return 0
	if lunar_day <= 2:
		return 1
	if lunar_day <= 5:
		return 2
	return 3


static func is_full_moon_night(unix_time: float, is_night: bool, epoch_unix: float = 0.0,
		cycle_days: float = LUNAR_CYCLE_DAYS) -> bool:
	return is_night and lunar_phase_index(unix_time, epoch_unix, cycle_days) == 2


static func day_sec(cfg: BalanceConfig = null) -> float:
	var c: BalanceConfig = cfg if cfg != null else Balance.cfg
	return maxf(1.0, c.day_night_day_sec)


static func night_sec(cfg: BalanceConfig = null) -> float:
	var c: BalanceConfig = cfg if cfg != null else Balance.cfg
	return maxf(1.0, c.day_night_night_sec)


static func cycle_sec(cfg: BalanceConfig = null) -> float:
	return day_sec(cfg) + night_sec(cfg)


## Segundos desde o início do dia do ciclo, para `elapsed` segundos desde a origem do relógio.
static func time_of_cycle(elapsed: float, cfg: BalanceConfig = null) -> float:
	return fposmod(elapsed, cycle_sec(cfg))


## Tempo do ciclo efetivo com a força aplicada (forçado = meio do dia ou meio da noite).
static func forced_time(t: float, force: int, cfg: BalanceConfig = null) -> float:
	match force:
		Force.DAY:
			return day_sec(cfg) * 0.5
		Force.NIGHT:
			return day_sec(cfg) + night_sec(cfg) * 0.5
	return t


static func is_night(t: float, cfg: BalanceConfig = null) -> bool:
	return fposmod(t, cycle_sec(cfg)) >= day_sec(cfg)


## 0 = dia pleno, 1 = noite plena; rampa suave de day_night_transition_sec em volta de cada virada.
static func night_amount(t: float, cfg: BalanceConfig = null) -> float:
	var c: BalanceConfig = cfg if cfg != null else Balance.cfg
	var cyc: float = cycle_sec(c)
	var tt: float = fposmod(t, cyc)
	var half: float = maxf(0.001, c.day_night_transition_sec * 0.5)
	var d: float = day_sec(c)
	# distância (com sinal) até o anoitecer e até o amanhecer (0 e cyc são o amanhecer)
	var to_dusk: float = tt - d
	var to_dawn: float = tt if tt < d * 0.5 else tt - cyc
	if absf(to_dusk) <= half:
		return smoothstep(-half, half, to_dusk)
	if absf(to_dawn) <= half:
		return 1.0 - smoothstep(-half, half, to_dawn)
	return 1.0 if tt >= d else 0.0


## Segundos até a próxima virada (dia -> noite ou noite -> dia).
static func sec_to_next_turn(t: float, cfg: BalanceConfig = null) -> float:
	var tt: float = fposmod(t, cycle_sec(cfg))
	var d: float = day_sec(cfg)
	return d - tt if tt < d else cycle_sec(cfg) - tt


## Hora do relógio de parede (0..24) só para texto/depuração.
static func clock_hour(t: float, cfg: BalanceConfig = null) -> float:
	var tt: float = fposmod(t, cycle_sec(cfg))
	var d: float = day_sec(cfg)
	var h: float
	if tt < d:
		h = DAY_START_HOUR + DAY_HOURS * tt / d
	else:
		h = DAY_START_HOUR + DAY_HOURS + (HOURS_PER_DAY - DAY_HOURS) * (tt - d) / night_sec(cfg)
	return fposmod(h, HOURS_PER_DAY)


## "HH:MM" da hora do relógio.
static func clock_text(t: float, cfg: BalanceConfig = null) -> String:
	var h: float = clock_hour(t, cfg)
	var hh: int = floori(h)
	var mm: int = floori((h - float(hh)) * 60.0)
	return "%02d:%02d" % [hh, mm]


## O mapa segue o relógio? (Campo de Treino fica sempre de dia, salvo quando a noite é forçada.)
static func map_follows_clock(map_id: StringName, force: int, cfg: BalanceConfig = null) -> bool:
	var c: BalanceConfig = cfg if cfg != null else Balance.cfg
	if force == Force.NIGHT or not c.day_night_training_always_day:
		return true
	if map_id == &"training_field":
		return false
	var zone: ZoneDef = Content.zone(map_id) if not map_id.is_empty() else null
	return zone == null or zone.kind != ZoneDef.Kind.TRAINING
