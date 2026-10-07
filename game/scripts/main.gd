extends Node
## /root/Main: decide servidor (feature tag dedicated_server ou argumento --server) ou cliente, e
## monta a árvore /root/Main/World/Instances/<instância>/{Map, Entities, Spawner} (contrato Fase 1).
##
## Argumentos de usuário (depois de "--"):
##   --server                      servidor dedicado (use com --headless)
##   --port=N                      porta (padrão Balance.cfg.default_port)
##   --save-dir=DIR                servidor: pasta dos saves (padrão user://server_saves/)
##   --host=H --name=N --body=male|female   cliente direto (sem tela de título; usado nos testes)
##   --autotest                    teste automático (ver tools/run_autotest.sh)
##   --autotest-role=shopper|observer   cliente: papel no autoteste (padrão observer)
##   --autotest-bad-protocol       cliente: manda protocol_version errado (testa a recusa)
##   --test-fixtures               servidor e cliente: carrega tests/server/fixtures (dados de teste)
##   --require-auth                servidor: exige o JWT da API de contas no handshake (launcher/server)
##   --auth-secrets=ARQ            servidor: secrets.env com PERDIDOS_JWT_SECRET (padrão ~/.config/perdidos/)
##   --token=JWT                   cliente: sessão vinda do launcher (o executável exportado exige)
## Sem --name (e sem --server), o cliente abre a tela de título de B (scenes/ui/title_screen.tscn),
## que emite play_requested(name, body, host, port).

const CLIENT_VIEW_SCENE: String = "res://scenes/ui/client_view.tscn"
const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const ANDROID_AUTH_SCREEN_SCRIPT: GDScript = preload("res://scripts/client/android_auth_screen.gd")
const TITLE_PLAY_SIGNAL: StringName = &"play_requested"
const SERVER_WORLD_SCRIPT: String = "res://scripts/server/server_world.gd"
const ENTITY_SCENE: String = "res://scenes/entities/net_entity.tscn"
const FIXTURES_SCRIPT: String = "res://tests/server/fixtures/test_fixtures.gd"
const CLIENT_AUTOTEST_SCRIPT: String = "res://tests/server/client_autotest.gd"
## Cena do mapa = MAP_SCENE_DIR + map_id + ".tscn" (mapas do Agente C).
const MAP_SCENE_DIR: String = "res://scenes/maps/"
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_BODY: StringName = &"male"
## Servidor: limite de quadros de processo (o tick de jogo é physics a server_tick_hz).
const SERVER_MAX_FPS: int = 60
## Depois de uma falha/queda de conexão, volta à tela de título após este tempo.
const RETURN_TO_TITLE_DELAY_SEC: float = 3.0

const ARG_SERVER: String = "server"
const ARG_HOST: String = "host"
const ARG_PORT: String = "port"
const ARG_NAME: String = "name"
const ARG_BODY: String = "body"
const ARG_SAVE_DIR: String = "save-dir"
const ARG_AUTOTEST: String = "autotest"
const ARG_AUTOTEST_BAD_PROTOCOL: String = "autotest-bad-protocol"
const ARG_TEST_FIXTURES: String = "test-fixtures"
## Agente N: roteiro de autoteste alternativo (res://tests/world/...) e aparência do cliente direto
## ("--appearance=skin:2,hair_style:curly,hair_color:5,eye_color:1,earrings:hoop").
const ARG_AUTOTEST_SCRIPT: String = "autotest-script"
const ARG_APPEARANCE: String = "appearance"
## Servidor: --transport=ws escuta WebSocket (para túnel HTTP como o ngrok); padrão ENet (UDP).
const ARG_TRANSPORT: String = "transport"
## Executável exportado: servidor padrão gravado pelo `make build-*` (SERVER_URL).
const CLIENT_CONFIG_PATH: String = "res://client_config.cfg"
## Login (launcher): o launcher abre o jogo com --token=<jwt>; o servidor da internet sobe com --require-auth.
const ARG_TOKEN: String = "token"
const ARG_REQUIRE_AUTH: String = "require-auth"
const ARG_AUTH_SECRETS: String = "auth-secrets"
const LAUNCHER_BG_PATH: String = "res://assets/ui/title/title_bg_painted.png"
## preload (não class_name): funciona mesmo antes do cache de classes ser refeito pelo import.
const AuthGateScript: GDScript = preload("res://scripts/server/auth/auth_gate.gd")

@onready var instances_root: Node3D = $World/Instances

var args: Dictionary[String, String] = {}
var client_view: Node = null
var _server_world: Node = null
var _title_screen: Node = null
## Servidor escolhido na tela de título (vai para o slot do personagem).
var _slot_host: String = ""
var _slot_port: int = 0
var _android_auth: AndroidAuthScreen = null
var _autotest: bool = false
var _fixtures: Script = null
var _current_instance_id: StringName = &""


func _ready() -> void:
	args = parse_user_args()
	_autotest = args.has(ARG_AUTOTEST)
	var is_server: bool = OS.has_feature("dedicated_server") or args.has(ARG_SERVER)
	if args.has(ARG_TEST_FIXTURES) and not is_server and ResourceLoader.exists(FIXTURES_SCRIPT):
		# (No servidor quem instala é o ServerWorld.)
		_fixtures = load(FIXTURES_SCRIPT) as Script
		_fixtures.call("install_content")
	if not is_server:
		Net.client_auth_token = args.get(ARG_TOKEN, "")
		# Executável exportado aberto direto (sem o launcher): não há sessão para mandar ao servidor.
		if OS.has_feature("template") and Net.client_auth_token.is_empty():
			if OS.get_name() == "Android":
				_show_android_auth()
			else:
				_show_launcher_required()
			return
	if is_server:
		_start_server()
	elif args.has(ARG_NAME) or args.has(ARG_AUTOTEST_BAD_PROTOCOL) \
			or not ResourceLoader.exists(TITLE_SCREEN_SCENE):
		_start_client(args.get(ARG_HOST, default_host()), _get_port(), args.get(ARG_NAME, ""),
				StringName(args.get(ARG_BODY, String(DEFAULT_BODY))))
	else:
		_show_title_screen()


## Servidor padrão: no executável exportado, o do client_config.cfg (gravado pelo `make build-*`);
## rodando pelo editor/`make run`, 127.0.0.1.
static func default_host() -> String:
	var h: String = exported_server_host()
	return h if not h.is_empty() else DEFAULT_HOST


static func exported_server_host() -> String:
	if not OS.has_feature("template"):
		return ""
	var cfg := ConfigFile.new()
	if cfg.load(CLIENT_CONFIG_PATH) != OK:
		return ""
	return str(cfg.get_value("server", "host", ""))


static func parse_user_args() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for raw: String in OS.get_cmdline_user_args():
		var a: String = raw.trim_prefix("--")
		var eq: int = a.find("=")
		if eq >= 0:
			out[a.substr(0, eq)] = a.substr(eq + 1)
		else:
			out[a] = ""
	return out


func _get_port() -> int:
	if args.has(ARG_PORT) and args[ARG_PORT].is_valid_int():
		return args[ARG_PORT].to_int()
	return Balance.cfg.default_port


## Cria a subárvore de uma instância (servidor e cliente). Retorna null se o mapa não existir.
func create_instance_node(instance_id: StringName, map_id: StringName) -> Node3D:
	var map_path: String = MAP_SCENE_DIR + String(map_id) + ".tscn"
	if not ResourceLoader.exists(map_path):
		push_error("Map scene not found: %s" % map_path)
		return null
	var packed: PackedScene = load(map_path) as PackedScene
	var inst := Node3D.new()
	inst.name = Net.instance_node_name(instance_id)
	var map_node: Node = packed.instantiate()
	map_node.name = "Map"
	inst.add_child(map_node)
	var entities := Node3D.new()
	entities.name = "Entities"
	inst.add_child(entities)
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("../Entities")
	spawner.add_spawnable_scene(ENTITY_SCENE)
	inst.add_child(spawner)
	instances_root.add_child(inst)
	var fixtures: Script = _fixtures
	if fixtures == null and args.has(ARG_TEST_FIXTURES) and ResourceLoader.exists(FIXTURES_SCRIPT):
		fixtures = load(FIXTURES_SCRIPT) as Script
	if fixtures != null:
		fixtures.call("install_map", map_node)
	return inst


# ---------------------------------------------------------------- servidor

func _start_server() -> void:
	Net.is_server = true
	Engine.physics_ticks_per_second = Balance.cfg.server_tick_hz
	Engine.max_fps = SERVER_MAX_FPS
	var script: Script = load(SERVER_WORLD_SCRIPT)
	_server_world = script.new()
	_server_world.name = "ServerWorld"
	_server_world.set("main_node", self)
	_server_world.set("autotest", _autotest)
	_server_world.set("test_fixtures", args.has(ARG_TEST_FIXTURES))
	_server_world.set("save_dir", args.get(ARG_SAVE_DIR, ""))
	add_child(_server_world)
	if args.has(ARG_REQUIRE_AUTH) and not _setup_auth():
		get_tree().quit(1)
		return
	var transport: StringName = Net.TRANSPORT_WS if args.get(ARG_TRANSPORT, "") == "ws" else Net.TRANSPORT_ENET
	if Net.start_server(_get_port(), transport) != OK:
		get_tree().quit(1)


## --require-auth: liga o AuthGate no Net (segredo do JWT + donos dos nomes na pasta dos saves).
func _setup_auth() -> bool:
	var secret: String = AuthGateScript.load_secret(args.get(ARG_AUTH_SECRETS, ""))
	if secret.is_empty():
		push_error("--require-auth: PERDIDOS_JWT_SECRET not found (env or %s)" % AuthGateScript.default_secrets_path())
		Net.log_line("auth_secret_missing", {"path": args.get(ARG_AUTH_SECRETS, AuthGateScript.default_secrets_path())})
		return false
	var dir: String = args.get(ARG_SAVE_DIR, "")
	if dir.is_empty():
		dir = JsonCharacterStore.DEFAULT_DIR
	Net.auth_gate = AuthGateScript.new(secret, dir)
	Net.log_line("auth_required", {"owners": dir.path_join(AuthGateScript.OWNERS_FILE)})
	return true


# ---------------------------------------------------------------- cliente

## Tela simples "Abra pelo launcher" (executável exportado sem --token).
func _show_launcher_required() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LauncherRequired"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(LAUNCHER_BG_PATH):
		bg.texture = load(LAUNCHER_BG_PATH) as Texture2D
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.16, 0.15, 0.94)
	box.border_color = Color8(150, 125, 70)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override(&"panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 16)
	col.custom_minimum_size = Vector2(460, 0)
	panel.add_child(col)
	var title := Label.new()
	title.text = tr("LAUNCHER_REQUIRED_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 30)
	title.add_theme_color_override(&"font_color", Color8(230, 190, 90))
	col.add_child(title)
	var text := Label.new()
	text.text = tr("LAUNCHER_REQUIRED_TEXT")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override(&"font_color", Color8(247, 239, 218))
	col.add_child(text)
	var close := Button.new()
	close.text = tr("LAUNCHER_REQUIRED_CLOSE")
	close.custom_minimum_size = Vector2(160, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(get_tree().quit)
	col.add_child(close)


func _show_android_auth() -> void:
	if FileAccess.file_exists("user://android_token.txt"):
		var saved_token: String = FileAccess.get_file_as_string("user://android_token.txt").strip_edges()
		if not saved_token.is_empty():
			_on_android_authenticated(saved_token)
			return
	var game_host: String = default_host()
	args[ARG_HOST] = game_host
	_android_auth = ANDROID_AUTH_SCREEN_SCRIPT.new() as AndroidAuthScreen
	_android_auth.api_base = AndroidAuthScreen.api_base_from_game_host(game_host)
	_android_auth.authenticated.connect(_on_android_authenticated)
	add_child(_android_auth)


func _on_android_authenticated(token: String) -> void:
	Net.client_auth_token = token
	var f := FileAccess.open("user://android_token.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(token)
		f.close()
	if is_instance_valid(_android_auth):
		_android_auth.queue_free()
		_android_auth = null
	_show_title_screen()


func _show_title_screen() -> void:
	var packed: PackedScene = load(TITLE_SCREEN_SCENE) as PackedScene
	_title_screen = packed.instantiate()
	add_child(_title_screen)
	if (args.has(ARG_HOST) or args.has(ARG_PORT)) and _title_screen.has_method(&"set_server"):
		_title_screen.call(&"set_server", args.get(ARG_HOST, ""), _get_port() if args.has(ARG_PORT) else 0)
	if _title_screen.has_signal(TITLE_PLAY_SIGNAL):
		_title_screen.connect(TITLE_PLAY_SIGNAL, _on_play_requested)
	else:
		push_error("Title screen has no %s signal" % TITLE_PLAY_SIGNAL)


func _on_play_requested(player_name: String, body: StringName, host: String, port: int) -> void:
	_slot_host = host
	_slot_port = port
	# Personalização escolhida na criação (ADENDO 2): vai ao servidor pelo NetWorld ao conectar.
	if _title_screen != null and _title_screen.has_method(&"get_appearance"):
		NetWorld.client_appearance = _title_screen.call(&"get_appearance")
	if _title_screen != null:
		_title_screen.queue_free()
		_title_screen = null
	# Cinemática de chegada (GDD §9.3; agente I): 1ª vez deste nome nesta máquina. Só neste fluxo
	# de título (nunca com --name/--autotest/headless).
	if not _autotest and not args.has(ARG_NAME) and IntroState.should_autoplay(player_name):
		var intro: CutscenePlayer = (load(CutscenePlayer.ARRIVAL_SCENE) as PackedScene).instantiate()
		intro.body = body
		add_child(intro)
		await intro.finished
		IntroState.mark_seen(player_name)
		intro.queue_free()
	_start_client(host, port, player_name, body)


func _start_client(host: String, port: int, player_name: String, body: StringName) -> void:
	if client_view == null and ResourceLoader.exists(CLIENT_VIEW_SCENE):
		var packed: PackedScene = load(CLIENT_VIEW_SCENE) as PackedScene
		client_view = packed.instantiate()
		client_view.name = "ClientView"
		add_child(client_view)
		if client_view.has_signal("move_requested"):
			client_view.connect("move_requested", Net.send_move_request)
		if client_view.has_signal("interact_requested"):
			# Monstro -> ataque, item no chão -> pegar, o resto -> Net.send_interact (K).
			client_view.connect("interact_requested", NetCombat.route_interact)
	if not Net.status_changed.is_connected(_on_status_changed):
		Net.status_changed.connect(_on_status_changed)
		Net.enter_instance_requested.connect(_on_enter_instance_requested)
		Net.local_player_spawned.connect(_on_local_player_spawned)
		Net.connection_closed.connect(_on_connection_closed)
	var protocol_override: int = -1
	if args.has(ARG_AUTOTEST_BAD_PROTOCOL):
		protocol_override = Balance.cfg.protocol_version + 1
	if args.has(ARG_APPEARANCE):
		NetWorld.client_appearance = parse_appearance_arg(args[ARG_APPEARANCE])
	if _autotest or args.has(ARG_AUTOTEST_BAD_PROTOCOL):
		_start_client_autotest()
	Net.start_client(host, port, player_name, body, protocol_override)


func _on_status_changed(text: String) -> void:
	if not text.is_empty():
		print("[client] status: ", text)
	if client_view != null and client_view.has_method("show_status"):
		client_view.call("show_status", text)


## Sem --name (fluxo normal do jogador): falhou/caiu -> volta para a tela de título.
func _on_connection_closed(reason_key: String) -> void:
	if args.has(ARG_NAME) or not ResourceLoader.exists(TITLE_SCREEN_SCENE):
		return
	# Conta sem slot livre: o servidor diz qual personagem ela já tem; ele aparece no slot ao voltar.
	if Net.last_rejection == Net.REJECT_SLOT_FULL and not Net.rejection_detail.is_empty():
		CharacterSlots.remember({CharacterSlots.KEY_NAME: Net.rejection_detail,
				CharacterSlots.KEY_HOST: _slot_host, CharacterSlots.KEY_PORT: _slot_port,
			CharacterSlots.KEY_LEVEL: int(NetProgress.client_progress.get("level", 1))})
	await get_tree().create_timer(RETURN_TO_TITLE_DELAY_SEC).timeout
	_clear_instances()
	if client_view != null:
		client_view.queue_free()
		client_view = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	if OS.get_name() == "Android" and reason_key in [&"NET_AUTH_REQUIRED", &"NET_AUTH_INVALID"]:
		Net.client_auth_token = ""
		if FileAccess.file_exists("user://android_token.txt"):
			DirAccess.remove_absolute("user://android_token.txt")
		_show_android_auth()
		return
	if _title_screen == null:
		_show_title_screen()


func _clear_instances() -> void:
	for child: Node in instances_root.get_children():
		instances_root.remove_child(child)
		child.queue_free()


func _on_enter_instance_requested(instance_id: StringName, map_id: StringName) -> void:
	# Cliente só tem a instância em que está.
	_clear_instances()
	var inst: Node3D = create_instance_node(instance_id, map_id)
	if inst == null:
		return
	_current_instance_id = instance_id
	Net.notify_instance_ready(instance_id)


func _on_local_player_spawned(player: Node3D) -> void:
	Net.log_line("local_player_spawned", {"entity": player.get("entity_id"),
			"pos": str(player.get("net_position"))})
	if client_view != null and client_view.has_method("set_follow_target"):
		client_view.call("set_follow_target", player)
	_remember_slot(player)


## Fluxo da tela de título (sem --name): o personagem que entrou no mundo fica no slot da conta, com a
## aparência que o servidor replicou (a do save, definitiva). A tela de título passa a abrir nele.
func _remember_slot(player: Node3D) -> void:
	if args.has(ARG_NAME) or _autotest:
		return
	var app: Dictionary = (player.get(&"appearance") as Dictionary).duplicate() if player.get(&"appearance") is Dictionary else {}
	CharacterSlots.remember({CharacterSlots.KEY_NAME: str(player.get(&"display_name")),
			CharacterSlots.KEY_BODY: str(app.get(&"body", "")), CharacterSlots.KEY_APPEARANCE: app,
			CharacterSlots.KEY_HOST: _slot_host, CharacterSlots.KEY_PORT: _slot_port})


func get_current_instance_id() -> StringName:
	return _current_instance_id


## "chave:valor,chave:valor" -> aparência (valores inteiros viram int).
static func parse_appearance_arg(raw: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in raw.split(",", false):
		var kv: PackedStringArray = pair.split(":")
		if kv.size() == 2:
			out[StringName(kv[0])] = kv[1].to_int() if kv[1].is_valid_int() else StringName(kv[1])
	return out


## O autoteste do cliente fica em tests/server/client_autotest.gd (dono: A).
func _start_client_autotest() -> void:
	var script_path: String = args.get(ARG_AUTOTEST_SCRIPT, CLIENT_AUTOTEST_SCRIPT)
	if not ResourceLoader.exists(script_path):
		push_error("Client autotest script missing")
		get_tree().quit(1)
		return
	var t: Node = (load(script_path) as Script).new()
	t.name = "ClientAutotest"
	t.set("main_node", self)
	t.set("args", args)
	add_child(t)
