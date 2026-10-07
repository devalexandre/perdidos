extends Node
## Luz do cliente no ciclo de dia e noite (GDD §10.7). Criado pelo autoload DayNight (só no cliente).
## A cada quadro lê DayNight.night_amount_on_map(map_id) (0 = dia, 1 = noite; rampa suave no anoitecer e no
## amanhecer) e mistura a luz do mapa carregado entre o "dia" do próprio mapa (valores da cena) e a noite:
##  - sol -> luar azul frio, mais fraco e com sombra mais leve (a direção não muda: a sombra dos pés segue);
##  - ambiente, névoa e céu pintado (env_sky_painted ou ProceduralSkyMaterial) -> azuis da noite;
##  - pós: um pouco menos de brilho e de saturação, contraste mantido (a pixel art continua legível);
##  - luzes pontuais (fogueira, cristal, lampiões) -> mais fortes à noite.
## O Environment do mapa é duplicado na primeira vez (o recurso do disco não muda). O Campo de Treino fica
## sempre de dia (WorldClock.map_follows_clock), a menos que o dono force a noite pelo comando de teste.

const INSTANCES_PATH: NodePath = ^"/root/Main/World/Instances"
const MAP_NODE: String = "Map"
const META_BASE: StringName = &"day_night_base"
## Troca forçada (comando de teste) ou entrada no mapa: a luz desliza em vez de pular (s para 0 -> 1).
const SMOOTH_SEC: float = 2.5

# ---- alvo da noite (ajustado nas capturas de .work/monsters_night/)
const MOON_COLOR: Color = Color(0.62, 0.72, 1.0)
const MOON_ENERGY_FACTOR: float = 0.42
const MOON_SHADOW_OPACITY_FACTOR: float = 0.6
const NIGHT_AMBIENT_COLOR: Color = Color(0.40, 0.47, 0.72)
const NIGHT_AMBIENT_ENERGY_FACTOR: float = 0.92
const NIGHT_FOG_COLOR: Color = Color(0.22, 0.27, 0.45)
const NIGHT_FOG_ENERGY_FACTOR: float = 0.8
const NIGHT_BRIGHTNESS_FACTOR: float = 0.94
const NIGHT_SATURATION_FACTOR: float = 0.82
const NIGHT_POINT_LIGHT_BOOST: float = 0.45
## FlickerLight (flicker_light.gd) guarda a energia base nesta variável.
const FLICKER_BASE: StringName = &"_base_energy"
## Céu pintado (env_sky_painted.gdshader) e céu procedural.
const NIGHT_SKY: Dictionary[StringName, Color] = {
	&"top_color": Color(0.05, 0.07, 0.18),
	&"mid_color": Color(0.10, 0.14, 0.30),
	&"horizon_color": Color(0.24, 0.26, 0.45),
	&"ground_color": Color(0.12, 0.13, 0.20),
	&"cloud_light": Color(0.40, 0.46, 0.66),
	&"cloud_shade": Color(0.16, 0.19, 0.34),
	&"sky_top_color": Color(0.05, 0.07, 0.18),
	&"sky_horizon_color": Color(0.24, 0.26, 0.45),
	&"ground_horizon_color": Color(0.18, 0.19, 0.30),
	&"ground_bottom_color": Color(0.08, 0.08, 0.14),
}

var _shown: Dictionary[int, float] = {}


func _process(delta: float) -> void:
	var root: Node = get_node_or_null(INSTANCES_PATH)
	if root == null:
		return
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(MAP_NODE)
		if map == null or not (&"map_id" in map):
			continue
		var target: float = DayNight.night_amount_on_map(StringName(str(map.get(&"map_id"))))
		var id: int = map.get_instance_id()
		var shown: float = _shown.get(id, target)
		shown = move_toward(shown, target, delta / SMOOTH_SEC) if absf(shown - target) > 0.02 else target
		_shown[id] = shown
		apply(map, shown)


## Aplica a mistura dia/noite (amount 0..1) no mapa. Também usado pelas capturas de teste.
static func apply(map: Node, amount: float) -> void:
	var base: Dictionary = _base_of(map)
	var a: float = clampf(amount, 0.0, 1.0)
	if int(base.get("last_q", -1)) == roundi(a * 1000.0):
		return
	base["last_q"] = roundi(a * 1000.0)
	var sun: DirectionalLight3D = base.get("sun") as DirectionalLight3D
	if is_instance_valid(sun):
		sun.light_color = (base["sun_color"] as Color).lerp(MOON_COLOR, a)
		sun.light_energy = lerpf(base["sun_energy"], base["sun_energy"] * MOON_ENERGY_FACTOR, a)
		sun.shadow_opacity = lerpf(base["sun_shadow"], base["sun_shadow"] * MOON_SHADOW_OPACITY_FACTOR, a)
	var env: Environment = base.get("env") as Environment
	if env != null:
		env.ambient_light_color = (base["amb_color"] as Color).lerp(NIGHT_AMBIENT_COLOR, a)
		env.ambient_light_energy = lerpf(base["amb_energy"], base["amb_energy"] * NIGHT_AMBIENT_ENERGY_FACTOR, a)
		env.fog_light_color = (base["fog_color"] as Color).lerp(NIGHT_FOG_COLOR, a)
		env.fog_light_energy = lerpf(base["fog_energy"], base["fog_energy"] * NIGHT_FOG_ENERGY_FACTOR, a)
		env.adjustment_brightness = lerpf(base["brightness"], base["brightness"] * NIGHT_BRIGHTNESS_FACTOR, a)
		env.adjustment_saturation = lerpf(base["saturation"], base["saturation"] * NIGHT_SATURATION_FACTOR, a)
		var sky_mat: Material = base.get("sky_mat") as Material
		var sky_base: Dictionary = base.get("sky_base", {})
		for key: StringName in sky_base:
			var c: Color = (sky_base[key] as Color).lerp(NIGHT_SKY[key], a)
			if sky_mat is ShaderMaterial:
				(sky_mat as ShaderMaterial).set_shader_parameter(key, Vector3(c.r, c.g, c.b))
			else:
				sky_mat.set(key, c)
	var points: Array = base.get("points", [])
	for p: Array in points:
		var l: Light3D = p[0] as Light3D
		if not is_instance_valid(l):
			continue
		var e: float = float(p[1]) * (1.0 + NIGHT_POINT_LIGHT_BOOST * a)
		if FLICKER_BASE in l:
			l.set(FLICKER_BASE, e) # FlickerLight tremula em volta da própria base
		else:
			l.light_energy = e


## Valores de "dia" do mapa (da cena), lidos uma vez; duplica o Environment para poder mexer.
static func _base_of(map: Node) -> Dictionary:
	if map.has_meta(META_BASE):
		return map.get_meta(META_BASE)
	var base: Dictionary = {}
	var sun: DirectionalLight3D = null
	for n: Node in map.find_children("*", "DirectionalLight3D", true, false):
		if sun == null or (n as DirectionalLight3D).light_energy > sun.light_energy:
			sun = n as DirectionalLight3D
	if sun != null:
		base["sun"] = sun
		base["sun_color"] = sun.light_color
		base["sun_energy"] = sun.light_energy
		base["sun_shadow"] = sun.shadow_opacity
	var we: WorldEnvironment = null
	for n: Node in map.find_children("*", "WorldEnvironment", true, false):
		we = n as WorldEnvironment
		break
	if we != null and we.environment != null:
		var env: Environment = we.environment.duplicate(true) as Environment
		we.environment = env
		base["env"] = env
		base["amb_color"] = env.ambient_light_color
		base["amb_energy"] = env.ambient_light_energy
		base["fog_color"] = env.fog_light_color
		base["fog_energy"] = env.fog_light_energy
		base["brightness"] = env.adjustment_brightness
		base["saturation"] = env.adjustment_saturation
		var sky_mat: Material = env.sky.sky_material if env.sky != null else null
		var sky_base: Dictionary = {}
		if sky_mat is ShaderMaterial and (sky_mat as ShaderMaterial).shader != null:
			var sm := sky_mat as ShaderMaterial
			for key: StringName in NIGHT_SKY:
				var v: Variant = sm.get_shader_parameter(key)
				if v == null:
					v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), key)
				if v is Vector3:
					sky_base[key] = Color(v.x, v.y, v.z)
				elif v is Color:
					sky_base[key] = v
		elif sky_mat is ProceduralSkyMaterial:
			for key: StringName in NIGHT_SKY:
				if key in sky_mat:
					sky_base[key] = sky_mat.get(key)
		base["sky_mat"] = sky_mat
		base["sky_base"] = sky_base
	var points: Array = []
	for n: Node in map.find_children("*", "OmniLight3D", true, false):
		var e0: Variant = n.get(FLICKER_BASE) if FLICKER_BASE in n else null
		points.append([n, float(e0) if e0 != null and float(e0) > 0.0 else (n as Light3D).light_energy])
	for n: Node in map.find_children("*", "SpotLight3D", true, false):
		points.append([n, (n as Light3D).light_energy])
	base["points"] = points
	map.set_meta(META_BASE, base)
	return base
