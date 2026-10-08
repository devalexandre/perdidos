extends RefCounted
## Umidade do chão (08/10/2026): o clima do RainOverlay (meta &"weather_visual" = Vector2(chuva, neblina) no mapa)
## vira uma "umidade" que sobe devagar enquanto chove e seca mais devagar ainda depois. Um ponto só distribui tudo
## para os materiais pelos uniforms GLOBAIS de shader (project.godot [shader_globals], env_weather.gdshaderinc):
##   env_rain           chuva agora (fogo, vento, anéis na água e nas poças)
##   env_wetness        umidade acumulada (chão escuro/brilhante, poças crescendo)
##   env_weather_detail 1 = respingos animados; 0 = preset Baixa
## Chamado por DayNightLight._process (cliente) uma vez por quadro; nada varre a árvore de nós.

const META_WETNESS: StringName = &"weather_wetness"
## Segundos para ir de seco (0) a encharcado (1) com chuva forte. Chuva fraca (0.4) para em ~0.5.
const WET_RISE_SEC: float = 30.0
## Segundos para secar de 1 a 0 depois que a chuva para.
const WET_DRY_SEC: float = 75.0
## Umidade alvo = chuva × ganho (chuva forte encharca; fraca deixa o chão só úmido).
const RAIN_TO_WET_GAIN: float = 1.25
## Quanto a lenha molhada segura a chama depois da chuva (fire_damp = max(chuva, umidade × isto)).
const FIRE_WET_FACTOR: float = 0.6
## Fogueira: fração da luz que some com chuva forte (FlickerLight/OmniLight com a meta &"rain_dim").
const FIRE_LIGHT_RAIN_DIM: float = 0.45
const GLOBAL_RAIN: StringName = &"env_rain"
const GLOBAL_WETNESS: StringName = &"env_wetness"
const GLOBAL_DETAIL: StringName = &"env_weather_detail"

static var _published: Vector3 = Vector3(-1.0, -1.0, -1.0)


## Um passo da curva: sobe em direção ao alvo (WET_RISE_SEC para 0→1) ou seca (WET_DRY_SEC para 1→0).
static func step(wetness: float, rain: float, delta: float) -> float:
	var target: float = clampf(rain * RAIN_TO_WET_GAIN, 0.0, 1.0)
	if target > wetness:
		return minf(target, wetness + delta / WET_RISE_SEC)
	return maxf(target, wetness - delta / WET_DRY_SEC)


## Quanto a chuva abafa o fogo (mesma conta de env_fire_damp no shader).
static func fire_damp(rain: float, wetness: float) -> float:
	return clampf(maxf(rain, wetness * FIRE_WET_FACTOR), 0.0, 1.0)


## Atualiza a umidade guardada no mapa (meta) e devolve o valor novo.
static func advance(map: Node, delta: float) -> float:
	var weather: Vector2 = map.get_meta(&"weather_visual", Vector2.ZERO)
	var wet: float = step(float(map.get_meta(META_WETNESS, 0.0)), clampf(weather.x, 0.0, 1.0), delta)
	map.set_meta(META_WETNESS, wet)
	return wet


## Publica nos uniforms globais (só quando muda o bastante: sem chamada ao RenderingServer todo quadro).
static func publish(rain: float, wetness: float) -> void:
	var detail: float = 0.0 if EnvQuality.current == EnvQuality.Preset.BAIXA else 1.0
	var next := Vector3(snappedf(clampf(rain, 0.0, 1.0), 0.002), snappedf(clampf(wetness, 0.0, 1.0), 0.002), detail)
	if next == _published:
		return
	_published = next
	RenderingServer.global_shader_parameter_set(GLOBAL_RAIN, next.x)
	RenderingServer.global_shader_parameter_set(GLOBAL_WETNESS, next.y)
	RenderingServer.global_shader_parameter_set(GLOBAL_DETAIL, next.z)
