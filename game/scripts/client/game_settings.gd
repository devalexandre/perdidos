class_name GameSettings
extends RefCounted
## Configurações do jogador (só cliente), salvas em user://settings.cfg:
## resolução, tela cheia, volumes por barramento e o último perfil usado na tela de título.
## Uso: GameSettings.get_instance() → altera campos → apply() / save().

const PATH: String = "user://settings.cfg"
const SECTION_VIDEO: String = "video"
const SECTION_AUDIO: String = "audio"
const SECTION_PROFILE: String = "profile"
const SECTION_UI: String = "ui"
const SECTION_RENDERING: String = "rendering"

## Barramentos com volume próprio (default_bus_layout.tres).
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUSES: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]
## Volume linear (0..1) padrão por barramento.
const DEFAULT_VOLUME: float = 0.8
const DEFAULT_MUSIC_VOLUME: float = 0.6
## Abaixo disso o barramento é silenciado.
const MUTE_THRESHOLD: float = 0.001
## Resoluções oferecidas (janela). Múltiplos de 960x540 ficam com ampliação inteira perfeita.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)

signal mobile_controls_changed(enabled: bool)
signal graphics_quality_changed(preset_index: int)

static var _instance: GameSettings = null

var resolution: Vector2i = DEFAULT_RESOLUTION
var fullscreen: bool = false
var volumes: Dictionary[StringName, float] = {}
var last_name: String = ""
var last_body: StringName = &"male"
var last_host: String = "127.0.0.1"
var last_port: int = 0
## Minimapa (Agente N, GDD §9.4): false = norte fixo; true = gira com a câmera.
var follower_visibility: int = 0 # 0 todos, 1 grupo, 2 nenhum (o próprio sempre visível)
var minimap_rotate: bool = false
## Controles touch / mobile (analógico virtual + cluster de 4 skills e ataque).
var mobile_controls: bool = false
var graphics_quality: EnvQuality.Preset = EnvQuality.Preset.ALTA


func _init() -> void:
	mobile_controls = is_mobile_platform()
	follower_visibility = 1 if mobile_controls else 0
	graphics_quality = default_quality_for_platform(mobile_controls)
	for bus: StringName in BUSES:
		volumes[bus] = DEFAULT_MUSIC_VOLUME if bus == BUS_MUSIC else DEFAULT_VOLUME


## Instância única (carregada do disco na primeira chamada).
static func get_instance() -> GameSettings:
	if _instance == null:
		_instance = GameSettings.new()
		_instance.load_from_disk()
	return _instance


func load_from_disk(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	resolution = cfg.get_value(SECTION_VIDEO, "resolution", resolution)
	fullscreen = cfg.get_value(SECTION_VIDEO, "fullscreen", fullscreen)
	for bus: StringName in BUSES:
		volumes[bus] = clampf(float(cfg.get_value(SECTION_AUDIO, String(bus), volumes[bus])), 0.0, 1.0)
	last_name = cfg.get_value(SECTION_PROFILE, "name", last_name)
	last_body = StringName(cfg.get_value(SECTION_PROFILE, "body", String(last_body)))
	last_host = cfg.get_value(SECTION_PROFILE, "host", last_host)
	# Executável exportado: sem servidor salvo (ou com o local de desenvolvimento), usa o do build.
	var built: String = _exported_server_host()
	if not built.is_empty() and last_host in ["", "127.0.0.1", "localhost"]:
		last_host = built
	last_port = int(cfg.get_value(SECTION_PROFILE, "port", last_port))
	follower_visibility = clampi(int(cfg.get_value(SECTION_UI, "follower_visibility", follower_visibility)), 0, 2)
	minimap_rotate = bool(cfg.get_value(SECTION_UI, "minimap_rotate", minimap_rotate))
	mobile_controls = bool(cfg.get_value(SECTION_UI, "mobile_controls", mobile_controls))
	graphics_quality = quality_from_index(int(cfg.get_value(SECTION_RENDERING, "quality", graphics_quality)))


func save(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_UI, "follower_visibility", follower_visibility)
	cfg.set_value(SECTION_VIDEO, "resolution", resolution)
	cfg.set_value(SECTION_VIDEO, "fullscreen", fullscreen)
	for bus: StringName in BUSES:
		cfg.set_value(SECTION_AUDIO, String(bus), volumes[bus])
	cfg.set_value(SECTION_PROFILE, "name", last_name)
	cfg.set_value(SECTION_PROFILE, "body", String(last_body))
	cfg.set_value(SECTION_PROFILE, "host", last_host)
	cfg.set_value(SECTION_PROFILE, "port", last_port)
	cfg.set_value(SECTION_UI, "minimap_rotate", minimap_rotate)
	cfg.set_value(SECTION_UI, "mobile_controls", mobile_controls)
	cfg.set_value(SECTION_RENDERING, "quality", int(graphics_quality))
	return cfg.save(path)


func set_graphics_quality(index: int) -> void:
	var next: EnvQuality.Preset = quality_from_index(index)
	if graphics_quality == next:
		return
	graphics_quality = next
	graphics_quality_changed.emit(int(graphics_quality))
	save()


static func quality_from_index(index: int) -> EnvQuality.Preset:
	match clampi(index, int(EnvQuality.Preset.ALTA), int(EnvQuality.Preset.BAIXA)):
		int(EnvQuality.Preset.MEDIA):
			return EnvQuality.Preset.MEDIA
		int(EnvQuality.Preset.BAIXA):
			return EnvQuality.Preset.BAIXA
	return EnvQuality.Preset.ALTA


static func default_quality_for_platform(is_mobile: bool) -> EnvQuality.Preset:
	return EnvQuality.Preset.BAIXA if is_mobile else EnvQuality.Preset.ALTA


static func is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


static func render_scale_for_quality(is_mobile: bool, preset: EnvQuality.Preset) -> float:
	return 0.67 if is_mobile and preset == EnvQuality.Preset.BAIXA else 1.0


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, DEFAULT_VOLUME)


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	apply_audio()


## Aplica tudo (vídeo + áudio).
func apply() -> void:
	apply_video()
	apply_audio()


func apply_audio() -> void:
	for bus: StringName in BUSES:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_mute(idx, v < MUTE_THRESHOLD)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, MUTE_THRESHOLD)))


func apply_video() -> void:
	# Sem janela real (headless/servidor/testes embutidos) não mexe em nada.
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen: Vector2i = DisplayServer.screen_get_size()
	var size: Vector2i = resolution
	if screen.x > 0 and screen.y > 0:
		size = Vector2i(mini(size.x, screen.x), mini(size.y, screen.y))
	DisplayServer.window_set_size(size)
	var origin: Vector2i = DisplayServer.screen_get_position()
	DisplayServer.window_set_position(origin + (screen - size) / 2)


## Servidor gravado no export (res://client_config.cfg, `make build-*`); "" fora do executável exportado.
static func _exported_server_host() -> String:
	if not OS.has_feature("template"):
		return ""
	var cfg := ConfigFile.new()
	if cfg.load("res://client_config.cfg") != OK:
		return ""
	return str(cfg.get_value("server", "host", ""))
