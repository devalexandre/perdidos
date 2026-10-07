class_name IntroState
extends RefCounted
## Lembra, por nome de personagem e nesta máquina, quem já viu a cinemática de chegada (GDD §9.3).
## Arquivo próprio (user://intro_seen.cfg) para não mexer no formato do settings.cfg.
## Nunca toca em modo headless, autoteste ou com --name (quem decide é main.gd).

const PATH: String = "user://intro_seen.cfg"
const SECTION: String = "seen"


static func _key(player_name: String) -> String:
	return player_name.strip_edges().to_lower().uri_encode()


static func has_seen(player_name: String, path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return bool(cfg.get_value(SECTION, _key(player_name), false))


static func mark_seen(player_name: String, path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(SECTION, _key(player_name), true)
	cfg.save(path)


## Deve tocar a abertura agora? (não em headless nem quando já viu).
static func should_autoplay(player_name: String, path: String = PATH) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not ResourceLoader.exists(CutscenePlayer.ARRIVAL_SCENE):
		return false
	return not has_seen(player_name, path)
