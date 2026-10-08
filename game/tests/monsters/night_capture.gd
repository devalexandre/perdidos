extends Node
## Capturas no cliente real (janela) para conferir dia, noite, chefe e forma atroz (docs/chefes-dia-noite.md).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/monsters/night_capture.gd --shot-dir=DIR e
## --autotest-role=porto|campo. Servidor com --dev-commands (tests/monsters/run_night_capture.sh). Usa só os
## comandos de teste do chat (MonsterDebug) e o teleporte de teste da progressão.
##   porto — Porto do Despertar: dia, anoitecer (meio da transição), noite; chefe e atroz lado a lado.
##   covis — Chapada, Subida Vermelha: os 3 covis fixos dos chefes de Pindorama, de dia (chefe + bando) e de noite (atroz).
##   campo — Campo de Treino, Terra de Pindorama: dia (sempre de dia) e noite forçada; para cada espécie de Pindorama,
##           chefe de dia, o mesmo chefe à noite (atroz) e os dois lado a lado na mesma luz.

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_ROLE: String = "autotest-role"
const SPECIES: Array[String] = ["tatu", "vagalume", "redemoinho"]
## Terra de Pindorama no Campo de Treino (tools/art/build_training_field.gd: PINDORAMA_C = (0, 0, 52)).
const PINDORAMA_SPOT: Vector2 = Vector2(0.0, 40.0)
## Onde os chefes nascem em relação ao jogador (células): à esquerda e à direita.
const LEFT: String = "-4 1"
const RIGHT: String = "4 1"
const CENTER: String = "0 3"
const SETTLE_SEC: float = 2.5
const LIGHT_SEC: float = 5.0
const CMD_GAP_SEC: float = 1.2
const DUSK_MID_SEC: float = 15.0

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC * 2.0)
	_hide_chat()
	var role: String = args.get(ARG_ROLE, "campo")
	if role == "porto":
		await _porto()
	elif role == "covis":
		await _covis()
	else:
		await _campo()
	Net.log_line("night_capture_done", {})
	get_tree().quit(0)


func _porto() -> void:
	await _cmd("/dia")
	await _wait(LIGHT_SEC)
	await _shot("porto_dia")
	await _cmd("/anoitecer")
	await _wait(DUSK_MID_SEC)
	await _shot("porto_anoitecendo")
	await _cmd("/noite")
	await _wait(LIGHT_SEC)
	await _shot("porto_noite")
	await _cmd("/dia")
	await _wait(LIGHT_SEC)
	await _cmd("/chefe tatu " + LEFT)
	await _cmd("/atroz tatu " + RIGHT)
	await _shot("porto_chefe_e_atroz_dia")
	await _cmd("/noite")
	await _wait(LIGHT_SEC)
	await _shot("porto_atroz_noite")
	await _cmd("/limpar")
	await _cmd("/hora normal")


func _campo() -> void:
	NetProgress.send_debug(&"teleport", [PINDORAMA_SPOT.x, PINDORAMA_SPOT.y])
	await _wait(SETTLE_SEC * 2.0)
	await _cmd("/hora normal")
	await _wait(LIGHT_SEC)
	await _shot("campo_dia")
	await _cmd("/noite")
	await _wait(LIGHT_SEC)
	await _shot("campo_noite_forcada")
	for sp: String in SPECIES:
		await _cmd("/dia")
		await _wait(LIGHT_SEC)
		await _cmd("/chefe %s %s" % [sp, CENTER])
		await _wait(SETTLE_SEC)
		await _shot("%s_chefe_dia" % sp)
		await _cmd("/noite")
		await _wait(LIGHT_SEC)
		await _shot("%s_atroz_noite" % sp)
		await _cmd("/limpar")
		await _cmd("/dia")
		await _wait(LIGHT_SEC)
		await _cmd("/chefe %s %s" % [sp, LEFT])
		await _cmd("/atroz %s %s" % [sp, RIGHT])
		await _wait(SETTLE_SEC)
		await _shot("%s_chefe_e_atroz_dia" % sp)
		await _cmd("/limpar")
	await _cmd("/hora normal")


## Covis fixos da Subida Vermelha (game/tools/world/build_hunt_areas.py).
const LAIR_MAP: StringName = &"split_sky_plateau"
const LAIRS: Array = [["ventania", Vector2(-22.0, -28.0)], ["rainha_lume", Vector2(-1.0, -28.0)],
		["tatu_montanha", Vector2(20.0, -28.0)]]
const LAIR_VIEW_OFFSET: float = 3.0


func _covis() -> void:
	NetProgress.send_debug(&"goto", [String(LAIR_MAP)])
	await _wait(SETTLE_SEC * 4.0)
	_hide_chat()
	await _cmd("/dia")
	for l: Array in LAIRS:
		var p: Vector2 = l[1]
		NetProgress.send_debug(&"teleport", [p.x + LAIR_VIEW_OFFSET, p.y + LAIR_VIEW_OFFSET])
		await _wait(LIGHT_SEC)
		await _shot("covil_%s_dia" % l[0])
	await _cmd("/covil")
	await _cmd("/noite")
	await _wait(LIGHT_SEC)
	for l: Array in LAIRS:
		var p: Vector2 = l[1]
		NetProgress.send_debug(&"teleport", [p.x + LAIR_VIEW_OFFSET, p.y + LAIR_VIEW_OFFSET])
		await _wait(LIGHT_SEC)
		await _shot("covil_%s_noite" % l[0])
	await _cmd("/hora normal")


func _cmd(text: String) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, text)
	await _wait(CMD_GAP_SEC)


func _hide_chat() -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	if view == null:
		return
	for n: Node in view.find_children("*Chat*", "Control", true, false):
		(n as Control).modulate.a = 0.0


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [dir, label]
	img.save_png(path)
	Net.log_line("night_capture_shot", {"file": path, "clock": DayNight.clock_text(), "night": DayNight.is_night()})
