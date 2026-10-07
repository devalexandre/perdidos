class_name TitleScreen
extends Control
## Tela de título e criação de personagem (GDD §6.1, contrato "Tela de título" + ADENDO 2): nome (3–16),
## corpo masculino/feminino, personalização (pele, cabelo, cor do cabelo, olhos, brincos, "Aleatório") com
## prévia em camadas girando nas 8 direções, servidor/porta (avançado), Jogar → play_requested.
## Música de título pelo AudioDirector (mus_title, se existir). main.gd (A) conecta play_requested
## a Net.start_client(...) e lê get_appearance() (chaves do ADENDO 2) para mandar ao servidor.
## Controle (GamepadInput): D-pad/analógico movem o foco, A escolhe (no campo de nome, A abre o teclado), LB/RB
## trocam a aba, Y sorteia a aparência, LT/RT giram o Viajante, Start = Jogar/Criar, B fecha as configurações.

signal play_requested(player_name: String, body: StringName, host: String, port: int)

const NAME_MIN: int = 3
const NAME_MAX: int = 16
const BODIES: Array[StringName] = [&"male", &"female"]
const BODY_KEYS: Dictionary[StringName, String] = {&"male": "TITLE_BODY_MALE", &"female": "TITLE_BODY_FEMALE"}
const DEFAULT_HOST: String = "127.0.0.1"
const PORT_MIN: int = 1
const PORT_MAX: int = 65535
## Ampliação mínima da prévia (inteira).
const PREVIEW_MIN_SCALE: int = 2
const TOUCH_WIDE_MIN_SCALE: float = 1.35
## Altura (px) em que o toque atinge TOUCH_WIDE_MIN_SCALE; abaixo, a escala cai para caber (ex.: 800x360).
const TOUCH_SCALE_REF_HEIGHT: float = 520.0
## Alvo de toque mínimo (px reais) no celular.
const TOUCH_TARGET_PX: int = 44
## Proporção a partir da qual o palco fica ao lado da ficha (senão, empilhados).
const WIDE_ASPECT: float = 1.2
## Altura lógica (px / escala) abaixo da qual a ficha fica compacta (nome e servidor na mesma linha).
const COMPACT_HEIGHT: float = 480.0
## Fração da largura da tela para a ficha (toque é maior: dedos) e largura mínima (px na escala 1).
const PANEL_FRACTION_DESKTOP: float = 0.42
const PANEL_FRACTION_TOUCH: float = 0.56
const PANEL_MIN_PX: float = 400.0
## Largura máxima da ficha (px na escala 1): em telas muito largas (celular 20:9) ela não vira uma faixa.
const PANEL_MAX_PX: float = 620.0
## Altura do palco no layout em retrato (fração da tela).
const PORTRAIT_HERO_FRACTION: float = 0.4
## Ampliação máxima do Viajante por unidade de escala da UI (720p = 4x; 1080p = 6x).
const PREVIEW_SCALE_PER_UI: float = 4.0
## Pedestal pintado em title_bg_painted.png: centro do disco (fração da imagem) e raio (fração da largura).
const DAIS_CENTER_UV: Vector2 = Vector2(0.2725, 0.716)
const DAIS_RADIUS_UV: float = 0.098
## Raio do disco (px de tela) por unidade de ampliação do Viajante (disco de 128 px = 4x).
const DAIS_RADIUS_PER_SCALE: float = 32.0
## Largura da coluna de rótulos das abas (px na escala 1).
const OPTION_LABEL_PX: float = 96.0
## Abas da ficha (rótulo = chave de tradução) e nomes dos botões.
const CREATION_TABS: Array[String] = ["TITLE_BODY", "CUSTOM_HAIR", "CUSTOM_NATIONALITY"]
const CREATION_TAB_NAMES: Array[StringName] = [&"TabBody", &"TabHair", &"TabOrigin"]
## Lado das amostras de cor do quadro da nacionalidade (px na escala 1,0).
const SWATCH_PX: float = 18.0
const HAIR_SWATCH_COLUMNS: int = 5
const STEPPER_LABEL_PX: float = 118.0
## Última aparência escolhida (só conveniência do cliente; o servidor valida na criação).
const APPEARANCE_PATH: String = "user://appearance.cfg"
const APPEARANCE_SECTION: String = "appearance"
const TITLE_MUSIC: StringName = &"title"
## Céu de fim de tarde (paleta v2) para o fundo provisório.
const SKY_TOP: Color = Color8(46, 31, 74)
const SKY_MID: Color = Color8(168, 64, 106)
const SKY_BOTTOM: Color = Color8(245, 154, 106)
const SKY_MID_OFFSET: float = 0.55
## Nomes: letras (inclusive acentuadas), números e espaço.
const NAME_PATTERN: String = "^[\\p{L}\\p{N} ]+$"

## Motivo da última desconexão (chave de tradução), mostrado ao voltar para o título.
static var pending_status: String = ""

## Aplica resolução/tela cheia salvas ao abrir (desligado nos testes).
@export var apply_video_settings: bool = true
## Testes de layout touch em desktop; Android/iOS detectam automaticamente.
@export var touch_layout_override: bool = false

const PARCHMENT_BG: Color = Color8(248, 240, 222, 252)
const PARCHMENT_INSET: Color = Color8(236, 225, 204, 255)
const PARCHMENT_CARD: Color = Color8(240, 230, 212, 255)
const WOOD_FRAME: Color = Color8(68, 38, 22, 255)
const TITLE_GOLD: Color = Color8(218, 160, 48)
const TITLE_GOLD_BRIGHT: Color = Color8(255, 220, 85)
const TITLE_GOLD_DIM: Color = Color8(150, 115, 55)
const INK_DARK: Color = Color8(44, 24, 16)
const INK_RUBY: Color = Color8(155, 42, 32)
const PREVIEW_BG: Color = Color8(24, 28, 34, 250)
## Paleta da ficha de criação (paleta-mestra.gpl): madeira, pergaminho, ouro velho e folha.
const C_WOOD_DARK: Color = Color8(58, 36, 24)
const C_WOOD: Color = Color8(107, 66, 38)
const C_WOOD_LIGHT: Color = Color8(156, 106, 60)
const C_WOOD_EDGE: Color = Color8(31, 20, 14)
const C_GOLD_AGED: Color = Color8(168, 116, 30)
const C_GOLD: Color = Color8(230, 180, 58)
const C_GOLD_LIGHT: Color = Color8(250, 229, 140)
const C_PARCHMENT: Color = Color8(242, 230, 200)
const C_PARCHMENT_SHADE: Color = Color8(201, 176, 138)
const C_PARCHMENT_EDGE: Color = Color8(140, 116, 88)
const C_INK_DIM: Color = Color8(107, 76, 50)
const C_LEAF: Color = Color8(47, 107, 62)
const C_OUTLINE: Color = Color8(22, 17, 15)
## Cores da roupa original do Viajante (Terra do Sabiá) no quadro da nacionalidade.
const NAT_DEFAULT_CLOTH: Color = Color8(31, 110, 170)
const NAT_DEFAULT_ACCENT: Color = Color8(160, 48, 40)
const BACKGROUND_PATH: String = "res://assets/ui/title/title_bg_painted.png"
const CREST_MAP: Dictionary[StringName, String] = {
	&"sabia": "res://assets/ui/crests/crest_brasil.png",
	&"mouras": "res://assets/ui/crests/crest_portugal.png",
	&"sol": "res://assets/ui/crests/crest_japao.png",
	&"fiordes": "res://assets/ui/crests/crest_nordico.png",
	&"colunas": "res://assets/ui/crests/crest_grecia.png",
	&"areias": "res://assets/ui/crests/crest_egito.png",
	&"brumas": "res://assets/ui/crests/crest_celta.png",
	&"estepe": "res://assets/ui/crests/crest_eslavo.png",
	&"jade": "res://assets/ui/crests/crest_china.png",
	&"obsidiana": "res://assets/ui/crests/crest_mexico.png",
}
const PETAL_PATH: String = "res://assets/ui/title/petal.png"
const PETAL_AMOUNT: int = 24
const PETAL_LIFETIME_SEC: float = 9.0
const PETAL_MARGIN_PX: float = 20.0
const PETAL_WIND: float = 14.0
const PETAL_FALL: float = 22.0

var ui_scale: float = 1.0
var selected_body: StringName = &"male"

var _name_edit: LineEdit
var _host_edit: LineEdit
var _port_edit: LineEdit
var _advanced_box: GridContainer
var _advanced_toggle: Button
## Lista de servidores por nome (data/servers.cfg); endereço e porta ficam nos campos escondidos.
var _server_pick: OptionButton
var _servers: Array[Dictionary] = []
var _server_status_label: Label = null
var _active_http_requests: Array[HTTPRequest] = []
const SERVERS_PATH: String = "res://data/servers.cfg"
var _play: Button
var _error: Label
var _status: Label
var _body_buttons: Dictionary[StringName, Button] = {}
## Escolhas de personalização (chaves do ADENDO 2, sem "body": vem de selected_body).
var appearance: Dictionary = {}
var _options: CustomizationOptions = null
var _preview: LayeredCharacterPreview
var _swatches: Dictionary[StringName, Array] = {}
var _style_label: Label
var _earring_label: Label
var _nationality_label: Label
var _nat_card_title: Label
var _nat_card_hook: Label
var _nat_card_swatches: Array[ColorRect] = []
var _nat_card_crest: TextureRect
var _origin_buttons: Dictionary[StringName, Button] = {}
var _hair_buttons: Dictionary[StringName, Button] = {}
var _eye_buttons: Dictionary[int, Button] = {}
var _hair_slider: HSlider = null
var _settings: SettingsWindow
var _busy: bool = false
var _wide_layout: bool = false
var _touch_layout: bool = false
var _compact: bool = false
var _layout_key: String = ""
var _current_tab: int = 0
var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _tab_scroll: ScrollContainer = null
## Personagem salvo da conta (CharacterSlots); preenchido = modo seleção (JOGAR, sem editar).
var _slot: Dictionary = {}
var _name_regex := RegEx.new()
var _audio: AudioDirector = null
var _sound_ready: bool = false
var _ambience_player: AudioStreamPlayer = null
## Controle: último uso foi o controle (dicas e moldura do foco aparecem).
var _using_pad: bool = false
var _pad_hints: GamepadHints = null
var _pad_ring: GamepadInput.FocusRing = null


func _init() -> void:
	_name_regex.compile(NAME_PATTERN)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s: GameSettings = GameSettings.get_instance()
	if apply_video_settings:
		s.apply_video()
	if AudioDirector.instance == null:
		_audio = AudioDirector.new()
		_audio.name = &"AudioDirector"
		add_child(_audio)
	AudioDirector.play_music_named(TITLE_MUSIC)
	_setup_ambient_audio()
	selected_body = s.last_body if s.last_body in BODIES else BODIES[0]
	_options = CustomizationOptions.get_default()
	appearance = _load_appearance()
	var start_name: String = s.last_name
	var start_host: String = s.last_host
	var start_port: int = s.last_port if s.last_port > 0 else Balance.cfg.default_port
	_slot = CharacterSlots.first_filled()
	if not _slot.is_empty():
		_enter_slot_mode()
		start_name = str(_slot[CharacterSlots.KEY_NAME])
		if not str(_slot.get(CharacterSlots.KEY_HOST, "")).is_empty():
			start_host = str(_slot[CharacterSlots.KEY_HOST])
		if int(_slot.get(CharacterSlots.KEY_PORT, 0)) > 0:
			start_port = int(_slot[CharacterSlots.KEY_PORT])
	GamepadInput.register_actions()
	_using_pad = GamepadInput.is_connected_any()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build(start_name, start_host, str(start_port))
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed.call_deferred()
	var net: Node = get_node_or_null(^"/root/Net")
	if net != null and net.has_signal(&"connection_closed"):
		net.connect(&"connection_closed", _on_connection_closed)
	if not pending_status.is_empty():
		set_status(pending_status)
		pending_status = ""
	_sound_ready = true


func _setup_ambient_audio() -> void:
	var amb_path: String = "res://assets/audio/sfx/amb_wind_tree.ogg"
	if ResourceLoader.exists(amb_path):
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.name = &"TitleWindAmbience"
		var s: AudioStream = load(amb_path) as AudioStream
		if s != null:
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			_ambience_player.stream = s
			_ambience_player.bus = AudioDirector.BUS_AMBIENCE
			_ambience_player.volume_db = -12.0
			add_child(_ambience_player)
			_ambience_player.play()



# --- API ------------------------------------------------------------------------------------------

## Mensagem de status (ex.: conectando, falha). Aceita chave de tradução ou texto pronto.
func set_status(text: String) -> void:
	_status.text = tr(text)
	_status.visible = not _status.text.is_empty()


## Bloqueia o botão Jogar enquanto conecta.
func set_busy(value: bool) -> void:
	_busy = value
	_validate()


## Valida o nome (GDD §6.1: 3 a 16 caracteres). Retorna "" ou a chave do erro.
func validate_name(raw: String) -> String:
	var n: String = raw.strip_edges()
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "TITLE_ERR_NAME_LENGTH"
	if _name_regex.search(n) == null:
		return "TITLE_ERR_NAME_CHARS"
	return ""


## Preenche os campos (testes e automação).
func set_fields(player_name: String, body: StringName, host: String = DEFAULT_HOST, port: int = 0) -> void:
	_name_edit.text = player_name
	_select_body(body)
	_host_edit.text = host
	_port_edit.text = str(port if port > 0 else Balance.cfg.default_port)
	_sync_server_pick()
	_validate()


## Define só servidor/porta (ex.: `make run PORT=7790` passa --port ao jogo).
func set_server(host: String, port: int) -> void:
	if host != "":
		_host_edit.text = host
	if port > 0:
		_port_edit.text = str(port)
	_sync_server_pick()
	_validate()


# --- Lista de servidores ---------------------------------------------------------------------------

## Lê data/servers.cfg. No executável exportado, os servidores dev_only (Local) não aparecem.
func _load_servers() -> void:
	_servers.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SERVERS_PATH) == OK:
		var order: Variant = cfg.get_value("servers", "order", [])
		for id: Variant in (order as Array if order is Array else []):
			var sid: String = str(id)
			if not cfg.has_section(sid):
				continue
			if bool(cfg.get_value(sid, "dev_only", false)) and OS.has_feature("template"):
				continue
			_servers.append({
				"id": sid,
				"name": str(cfg.get_value(sid, "name", sid)),
				"host": str(cfg.get_value(sid, "host", "")),
				"port": int(cfg.get_value(sid, "port", Balance.cfg.default_port)),
				"status": "checking"
			})
	if _servers.is_empty():
		_servers.append({
			"id": "default",
			"name": DEFAULT_HOST,
			"host": DEFAULT_HOST,
			"port": Balance.cfg.default_port,
			"status": "checking"
		})


## Seleciona na lista o servidor dos campos escondidos; um endereço fora da lista vira "Outro (…)".
func _sync_server_pick() -> void:
	if _server_pick == null:
		return
	var host: String = _host_edit.text.strip_edges()
	var port_val: int = _port_edit.text.strip_edges().to_int()
	var idx: int = -1
	for i: int in _servers.size():
		var h: String = str(_servers[i]["host"])
		var p: int = int(_servers[i]["port"])
		if (h == host or (Net.websocket_url(h) != "" and Net.websocket_url(h) == Net.websocket_url(host))) and p == port_val:
			idx = i
			break
	if idx < 0 and not host.is_empty() and not (host == DEFAULT_HOST and OS.has_feature("template")):
		_servers.append({
			"id": "other",
			"name": "%s (%s:%d)" % [tr("TITLE_SERVER_OTHER"), host, port_val],
			"host": host,
			"port": port_val,
			"status": "checking"
		})
		idx = _servers.size() - 1
	if idx < 0:
		idx = 0
	_server_pick.clear()
	for i: int in _servers.size():
		var sv: Dictionary = _servers[i]
		var icon: String = _status_icon(str(sv.get("status", "checking")))
		_server_pick.add_item("%s%s" % [icon, str(sv["name"])])
	_server_pick.select(idx)
	_update_server_status_badge(idx)


func _status_icon(st: String) -> String:
	match st:
		"online":
			return "🟢 "
		"offline":
			return "🔴 "
		_:
			return "🟡 "


func _update_server_status_badge(idx: int) -> void:
	if _server_status_label == null or idx < 0 or idx >= _servers.size():
		return
	var sv: Dictionary = _servers[idx]
	var st: String = str(sv.get("status", "checking"))
	match st:
		"online":
			var label_txt: String = tr("TITLE_SERVER_STATUS_ONLINE")
			if label_txt == "TITLE_SERVER_STATUS_ONLINE":
				label_txt = "Online"
			_server_status_label.text = "● %s (%s:%d)" % [label_txt, str(sv.get("host", "")), int(sv.get("port", 0))]
			_server_status_label.add_theme_color_override(&"font_color", Color8(35, 125, 45))
		"offline":
			var label_txt: String = tr("TITLE_SERVER_STATUS_OFFLINE")
			if label_txt == "TITLE_SERVER_STATUS_OFFLINE":
				label_txt = "Offline"
			_server_status_label.text = "● %s (%s:%d)" % [label_txt, str(sv.get("host", "")), int(sv.get("port", 0))]
			_server_status_label.add_theme_color_override(&"font_color", INK_RUBY)
		_:
			var label_txt: String = tr("TITLE_SERVER_STATUS_CHECKING")
			if label_txt == "TITLE_SERVER_STATUS_CHECKING":
				label_txt = "Verificando..."
			_server_status_label.text = "● %s (%s)" % [label_txt, str(sv.get("host", ""))]
			_server_status_label.add_theme_color_override(&"font_color", Color8(140, 100, 30))


func _set_server_status(idx: int, status: String) -> void:
	if idx < 0 or idx >= _servers.size():
		return
	_servers[idx]["status"] = status
	if _server_pick != null and idx < _server_pick.item_count:
		var sv: Dictionary = _servers[idx]
		var icon: String = _status_icon(status)
		_server_pick.set_item_text(idx, "%s%s" % [icon, str(sv["name"])])
		if _server_pick.selected == idx:
			_update_server_status_badge(idx)


func _on_server_selected(index: int) -> void:
	if index < 0 or index >= _servers.size():
		return
	_host_edit.text = str(_servers[index]["host"])
	_port_edit.text = str(int(_servers[index]["port"]))
	_update_server_status_badge(index)
	if _error != null:
		_validate()


## Verifica o status online/offline de todos os servidores configurados
func _check_servers_status() -> void:
	for req: HTTPRequest in _active_http_requests:
		if is_instance_valid(req):
			req.queue_free()
	_active_http_requests.clear()

	for i: int in _servers.size():
		_set_server_status(i, "checking")
		var sv: Dictionary = _servers[i]
		var host: String = str(sv.get("host", "")).strip_edges()
		var port: int = int(sv.get("port", Balance.cfg.default_port))
		if host.is_empty():
			_set_server_status(i, "offline")
			continue

		var ws_url: String = Net.websocket_url(host)
		if not ws_url.is_empty() or host.contains("ngrok") or host.begins_with("http"):
			var http := HTTPRequest.new()
			http.timeout = 2.5
			add_child(http)
			_active_http_requests.append(http)
			var base_url: String = host
			if not base_url.begins_with("http://") and not base_url.begins_with("https://"):
				base_url = "https://" + base_url
			base_url = base_url.trim_suffix("/")
			var ping_url: String = base_url + "/api/health"
			var idx: int = i
			http.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
				_active_http_requests.erase(http)
				http.queue_free()
				if result == HTTPRequest.RESULT_SUCCESS and response_code > 0 and response_code != 502 and response_code != 504:
					_set_server_status(idx, "online")
				else:
					_set_server_status(idx, "offline")
			)
			var err: Error = http.request(ping_url, PackedStringArray(["ngrok-skip-browser-warning: 1"]))
			if err != OK:
				_active_http_requests.erase(http)
				http.queue_free()
				_set_server_status(idx, "offline")
		elif host == "127.0.0.1" or host == "localhost":
			_check_local_server(i, port)
		else:
			_check_remote_host(i, host, port)


func _check_local_server(idx: int, port: int) -> void:
	var http := HTTPRequest.new()
	http.timeout = 1.0
	add_child(http)
	_active_http_requests.append(http)
	http.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		_active_http_requests.erase(http)
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code > 0 and response_code < 500:
			_set_server_status(idx, "online")
		else:
			_probe_port(idx, "127.0.0.1", port)
	)
	var err: Error = http.request("http://127.0.0.1:8080/api/health")
	if err != OK:
		_active_http_requests.erase(http)
		http.queue_free()
		_probe_port(idx, "127.0.0.1", port)


func _check_remote_host(idx: int, host: String, port: int) -> void:
	var ip: String = IP.resolve_hostname(host)
	if ip.is_empty():
		_set_server_status(idx, "offline")
		return
	_probe_port(idx, host, port)


func _probe_port(idx: int, host: String, port: int) -> void:
	var tcp := StreamPeerTCP.new()
	var err: Error = tcp.connect_to_host(host, port)
	if err != OK:
		_set_server_status(idx, "offline")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		_set_server_status(idx, "online")
		return
	var timer := tree.create_timer(0.4)
	timer.timeout.connect(func() -> void:
		tcp.poll()
		var st: StreamPeerTCP.Status = tcp.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED or st == StreamPeerTCP.STATUS_CONNECTING:
			_set_server_status(idx, "online")
		elif host == "127.0.0.1":
			_set_server_status(idx, "online")
		else:
			_set_server_status(idx, "offline")
		tcp.disconnect_from_host()
	)


## Aparência escolhida, pronta para o servidor (contrato ADENDO 2): body, skin, hair_style, hair_color,
## eye_color, earrings, nationality — já validada contra data/customization/options.tres.
func get_appearance() -> Dictionary:
	if is_slot_mode():
		var saved: Dictionary = _slot_appearance()
		saved[CustomizationOptions.KEY_BODY] = selected_body
		return saved
	var a: Dictionary = appearance.duplicate()
	a[CustomizationOptions.KEY_BODY] = selected_body
	return _options.sanitize(a) if _options != null else a


## Define a aparência (testes/automação). "body", se vier, também troca o corpo.
func set_appearance(value: Dictionary) -> void:
	if value.has(CustomizationOptions.KEY_BODY):
		_select_body(StringName(str(value[CustomizationOptions.KEY_BODY])))
	appearance = value.duplicate()
	_apply_appearance()


## Sorteia uma aparência válida para o corpo atual (botão "Aleatório").
func randomize_appearance(rng: RandomNumberGenerator = null) -> void:
	if _options == null or is_slot_mode():
		return
	var nat: Variant = appearance.get(CustomizationOptions.KEY_NATIONALITY)
	appearance = _options.random_appearance(selected_body, rng)
	if nat != null:
		appearance[CustomizationOptions.KEY_NATIONALITY] = nat
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"skill_learned")


## Tenta jogar; retorna false se algum campo é inválido.
func request_play() -> bool:
	if not _validate() or _busy:
		return false
	if _sound_ready:
		AudioDirector.play_sfx(&"login")
	var player_name: String = _name_edit.text.strip_edges()
	var host: String = _host_edit.text.strip_edges()
	var port: int = _port_edit.text.strip_edges().to_int()
	var s: GameSettings = GameSettings.get_instance()
	s.last_name = player_name
	s.last_body = selected_body
	s.last_host = host
	s.last_port = port
	s.save()
	if not is_slot_mode():
		_save_appearance()
	if _server_pick != null and _server_pick.selected >= 0 and _server_pick.selected < _servers.size():
		var sel_sv: Dictionary = _servers[_server_pick.selected]
		if sel_sv.get("status") == "offline":
			set_status("TITLE_SERVER_OFFLINE_WARN")
		else:
			set_status("TITLE_CONNECTING")
	else:
		set_status("TITLE_CONNECTING")
	play_requested.emit(player_name, selected_body, host, port)
	return true


# --- Construção -----------------------------------------------------------------------------------

func _on_size_changed() -> void:
	var vp: Vector2 = get_viewport_rect().size
	size = vp
	if _layout_signature(vp) != _layout_key:
		_build(_name_edit.text, _host_edit.text, _port_edit.text)


func _uses_touch_layout() -> bool:
	return touch_layout_override or OS.has_feature("mobile") or OS.has_feature("android") \
			or OS.has_feature("ios")


## Escala da tela: a da UI; no toque, ampliada até TOUCH_WIDE_MIN_SCALE se a altura comportar.
func _scale_for(vp: Vector2) -> float:
	var s: float = UIKit.scale_for(vp)
	if _uses_touch_layout():
		s = maxf(s, minf(TOUCH_WIDE_MIN_SCALE, vp.y / TOUCH_SCALE_REF_HEIGHT))
	return s


## Muda quando o layout precisa ser refeito (escala, modo toque ou tamanho da janela).
func _layout_signature(vp: Vector2) -> String:
	return "%s|%.3f|%d|%d" % [_uses_touch_layout(), _scale_for(vp), int(vp.x) / 8, int(vp.y) / 8]


## px na escala atual; no toque, nunca menor que o alvo mínimo de dedo.
func _target(value: float) -> int:
	var p: int = UIKit.px(value, ui_scale)
	return maxi(p, TOUCH_TARGET_PX) if _touch_layout else p


func _build(player_name: String, host: String, port_text: String) -> void:
	for child: Node in get_children():
		if child != _audio:
			remove_child(child)
			child.queue_free()
	_body_buttons.clear()
	_swatches.clear()
	_origin_buttons.clear()
	_hair_buttons.clear()
	_eye_buttons.clear()
	_tab_buttons.clear()
	_tab_pages.clear()
	_hair_slider = null
	var vp: Vector2 = get_viewport_rect().size
	_touch_layout = _uses_touch_layout()
	_wide_layout = vp.x / maxf(1.0, vp.y) >= WIDE_ASPECT
	ui_scale = _scale_for(vp)
	_compact = vp.y / ui_scale < COMPACT_HEIGHT
	_layout_key = _layout_signature(vp)
	theme = UIKit.build_theme(ui_scale)
	theme.default_font = UIKit.world_font()
	_apply_title_theme(theme)

	var bg := TextureRect.new()
	bg.name = &"Background"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(BACKGROUND_PATH):
		# Ilustração pintada: cenário suave em resolução nativa; só o personagem usa nearest.
		bg.texture = load(BACKGROUND_PATH) as Texture2D
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var atmosphere := ShaderMaterial.new()
		atmosphere.shader = load("res://assets/ui/title/title_atmosphere.gdshader") as Shader
		bg.material = atmosphere
	else:
		bg.texture = _sky_texture()
		bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_petals()

	# Paisagem: o Viajante em pé no pedestal pintado do fundo (à esquerda) e a ficha à direita.
	# Retrato (só janela de PC estreita): Viajante em cima, ficha embaixo.
	var pad: int = UIKit.px(8 if _compact else 14, ui_scale)
	var gap: int = UIKit.px(10 if _compact else 16, ui_scale)
	var layout := MarginContainer.new()
	layout.name = &"CreationLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		layout.add_theme_constant_override(side, pad)
	var panel: Control = _traveler_panel(player_name, host, port_text)
	var split: BoxContainer
	if _wide_layout:
		var hero_right: float = _place_hero_on_dais(vp, pad)
		split = HBoxContainer.new()
		var spacer := Control.new()
		spacer.name = &"HeroSpace"
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(spacer)
		# A ficha nunca cobre o pedestal: cede largura se precisar.
		panel.custom_minimum_size.x = minf(_panel_width(vp), vp.x - pad - gap - hero_right)
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		split = VBoxContainer.new()
		var hero: Control = _hero_column(Vector2(vp.x - 2.0 * pad, vp.y * PORTRAIT_HERO_FRACTION))
		hero.custom_minimum_size.y = vp.y * PORTRAIT_HERO_FRACTION
		split.add_child(hero)
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.name = &"CreationSplit"
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_theme_constant_override(&"separation", gap)
	split.add_child(panel)
	layout.add_child(split)
	add_child(layout)

	_settings = SettingsWindow.new(ui_scale, false)
	add_child(_settings)
	_pad_hints = GamepadHints.new(ui_scale)
	_pad_hints.set_context(GamepadHints.CONTEXT_TITLE)
	add_child(_pad_hints)
	_pad_ring = GamepadInput.FocusRing.new(ui_scale)
	add_child(_pad_ring)
	_set_using_pad(_using_pad)
	_select_body(selected_body)
	select_creation_tab(_current_tab)
	_validate()
	await get_tree().process_frame
	if is_instance_valid(_settings):
		_settings.place(Vector2(0.5, 0.5))
	if _wide_layout:
		_fit_panel_height(panel, vp.y - 2.0 * pad)


## Ficha em paisagem do tamanho da aba mais alta (sem vazio sobrando e sem mudar de altura ao trocar
## de aba); se não couber, ocupa a altura toda e o conteúdo rola.
func _fit_panel_height(panel: Control, avail_h: float) -> void:
	var pages: Array[Control] = _tab_pages.duplicate()
	var scroll: ScrollContainer = _tab_scroll
	if pages.is_empty() or not is_instance_valid(scroll):
		return
	var tallest: float = 0.0
	for page: Control in pages:
		for other: Control in pages:
			other.visible = other == page
		await get_tree().process_frame
		if not is_instance_valid(scroll) or _tab_scroll != scroll:
			return
		tallest = maxf(tallest, page.get_combined_minimum_size().y)
	select_creation_tab(_current_tab)
	scroll.custom_minimum_size.y = 0.0
	var chrome: float = panel.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = maxf(0.0, minf(tallest, avail_h - chrome))


## Largura da ficha em paisagem: maior no toque (dedos), nunca espremendo o palco.
func _panel_width(vp: Vector2) -> float:
	var frac: float = PANEL_FRACTION_TOUCH if _touch_layout else PANEL_FRACTION_DESKTOP
	var widest: float = minf(vp.x * 0.62, UIKit.px(PANEL_MAX_PX, ui_scale))
	return clampf(vp.x * frac, minf(UIKit.px(PANEL_MIN_PX, ui_scale), widest), widest)


# --- Abas da ficha --------------------------------------------------------------------------------

## Quantas abas a ficha tem (Corpo, Cabelo, Origem).
func creation_tab_count() -> int:
	return CREATION_TABS.size()


## Mostra a aba index (0 = Corpo, 1 = Cabelo, 2 = Origem).
func select_creation_tab(index: int) -> void:
	_current_tab = clampi(index, 0, CREATION_TABS.size() - 1)
	for i: int in _tab_pages.size():
		_tab_pages[i].visible = i == _current_tab
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _current_tab)
	if is_instance_valid(_tab_scroll):
		_tab_scroll.scroll_vertical = 0


## Aba atual (para testes).
func current_creation_tab() -> int:
	return _current_tab


## Ficha do Viajante: moldura de madeira com filete de ouro, abas de couro, pergaminho e rodapé fixo.
func _traveler_panel(player_name: String, host: String, port_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = &"TravelerPanel"
	panel.add_theme_stylebox_override(&"panel", _wood_frame_box())
	var body := VBoxContainer.new()
	body.name = &"PanelBody"
	body.add_theme_constant_override(&"separation", 0)
	panel.add_child(body)
	if is_slot_mode():
		_slot_panel_body(body, player_name, host, port_text)
		return panel

	if not _compact:
		var head := _gold_header("TITLE_TRAVELER")
		body.add_child(head)
		body.add_child(_spacer(UIKit.px(8, ui_scale)))

	# Abas: botões separados por um vão de madeira; a ativa é do mesmo pergaminho do conteúdo e encosta nele.
	var tabs_row := HBoxContainer.new()
	tabs_row.name = &"CreationTabs"
	tabs_row.z_index = 1
	tabs_row.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	body.add_child(tabs_row)
	var group := ButtonGroup.new()
	for i: int in CREATION_TABS.size():
		var tb := Button.new()
		tb.name = CREATION_TAB_NAMES[i]
		tb.text = tr(CREATION_TABS[i])
		tb.toggle_mode = true
		tb.button_group = group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = _target(32)
		tb.clip_text = true
		_style_tab(tb)
		tb.pressed.connect(func() -> void:
			select_creation_tab(i)
			if _sound_ready:
				AudioDirector.play_sfx(&"equip"))
		tabs_row.add_child(tb)
		_tab_buttons.append(tb)

	var content := PanelContainer.new()
	content.name = &"TabContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override(&"panel", _parchment_box(true))
	body.add_child(content)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.name = &"TitleScroll"
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tab_scroll.follow_focus = true
	content.add_child(_tab_scroll)
	var pages := VBoxContainer.new()
	pages.name = &"Customization"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_scroll.add_child(pages)
	if _options != null and _options.palettes != null:
		for page: Control in [_body_page(), _hair_page(), _origin_page()]:
			pages.add_child(page)
			_tab_pages.append(page)

	body.add_child(_spacer(UIKit.px(6 if _compact else 10, ui_scale)))
	body.add_child(_footer(player_name, host, port_text))
	return panel


## Aba e seus estados: inativa = madeira; hover = madeira clara com aro de ouro; ativa = pergaminho erguido.
func _style_tab(b: Button) -> void:
	var line: int = maxi(1, UIKit.px(1, ui_scale))
	var rad: int = maxi(3, UIKit.px(6, ui_scale))
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_WOOD
	normal.border_color = C_WOOD_EDGE
	normal.border_width_left = line
	normal.border_width_right = line
	normal.border_width_top = line
	normal.corner_radius_top_left = rad
	normal.corner_radius_top_right = rad
	normal.content_margin_left = UIKit.px(8, ui_scale)
	normal.content_margin_right = UIKit.px(8, ui_scale)
	normal.content_margin_top = UIKit.px(5, ui_scale)
	normal.content_margin_bottom = UIKit.px(4, ui_scale)
	normal.anti_aliasing = false
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = C_WOOD_LIGHT
	hover.border_color = C_GOLD_AGED
	var active: StyleBoxFlat = normal.duplicate()
	active.bg_color = C_PARCHMENT
	active.border_color = C_GOLD_AGED
	active.border_width_left = maxi(2, UIKit.px(2, ui_scale))
	active.border_width_right = active.border_width_left
	active.border_width_top = maxi(2, UIKit.px(3, ui_scale))
	# Cobre a borda de cima do pergaminho: a aba ativa e o conteúdo viram uma peça só.
	active.expand_margin_bottom = maxi(2, UIKit.px(2, ui_scale)) + 1
	active.expand_margin_top = UIKit.px(3, ui_scale)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = C_GOLD_LIGHT
	focus.set_border_width_all(line)
	focus.corner_radius_top_left = rad
	focus.corner_radius_top_right = rad
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", active)
	b.add_theme_stylebox_override(&"hover_pressed", active)
	b.add_theme_stylebox_override(&"focus", focus)
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(15, ui_scale))
	b.add_theme_color_override(&"font_color", C_PARCHMENT_SHADE)
	b.add_theme_color_override(&"font_focus_color", C_PARCHMENT_SHADE)
	b.add_theme_color_override(&"font_hover_color", C_GOLD_LIGHT)
	b.add_theme_color_override(&"font_pressed_color", INK_RUBY)
	b.add_theme_color_override(&"font_hover_pressed_color", INK_RUBY)


## Moldura da ficha: madeira escura, filete de ouro velho, sombra.
func _wood_frame_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_WOOD_DARK, 0.97)
	sb.border_color = C_GOLD_AGED
	sb.set_border_width_all(maxi(2, UIKit.px(2, ui_scale)))
	sb.set_corner_radius_all(maxi(4, UIKit.px(8, ui_scale)))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = UIKit.px(10, ui_scale)
	var m: int = UIKit.px(8 if _compact else 12, ui_scale)
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m
	sb.content_margin_bottom = m
	sb.anti_aliasing = false
	return sb


## Pergaminho com filete de ouro (conteúdo da aba e cartão do nome). under_tabs = cantos de cima retos.
func _parchment_box(under_tabs: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PARCHMENT
	sb.border_color = C_GOLD_AGED
	sb.set_border_width_all(maxi(2, UIKit.px(2, ui_scale)))
	sb.set_corner_radius_all(maxi(3, UIKit.px(5, ui_scale)))
	if under_tabs:
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
	var m: int = UIKit.px(8 if _compact else 12, ui_scale)
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m
	sb.content_margin_bottom = m
	sb.anti_aliasing = false
	return sb


## Título dourado com filetes dos dois lados (cabeçalho da ficha, sobre a madeira).
func _gold_header(key: String) -> Control:
	var row := HBoxContainer.new()
	row.name = &"PanelHeader"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = tr(key).to_upper()
	l.add_theme_font_override(&"font", UIKit.font())
	l.add_theme_font_size_override(&"font_size", UIKit.px(16, ui_scale))
	l.add_theme_color_override(&"font_color", C_GOLD_LIGHT)
	l.add_theme_color_override(&"font_outline_color", C_OUTLINE)
	l.add_theme_constant_override(&"outline_size", maxi(2, UIKit.px(3, ui_scale)))
	for side: int in 2:
		var rule := ColorRect.new()
		rule.color = C_GOLD_AGED
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.custom_minimum_size.y = maxi(1, UIKit.px(2, ui_scale))
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rule)
		if side == 0:
			row.add_child(l)
	return row


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Grade rótulo | controle de uma aba (rótulos alinhados numa coluna).
func _option_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", UIKit.px(12, ui_scale))
	grid.add_theme_constant_override(&"v_separation", UIKit.px(10 if _compact else 18, ui_scale))
	return grid


func _add_option(grid: GridContainer, key: String, control: Control) -> void:
	var l := Label.new()
	l.text = tr(key)
	l.custom_minimum_size.x = UIKit.px(OPTION_LABEL_PX, ui_scale)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override(&"font", UIKit.read_font())
	l.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	l.add_theme_color_override(&"font_color", INK_RUBY)
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(control)


func _page(page_name: StringName) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = page_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	return page


## Aba Corpo: corpo, pele, olhos e brincos.
func _body_page() -> Control:
	var page := _page(&"BodyPage")
	var pal: CustomizationPalettes = _options.palettes
	var grid := _option_grid()
	page.add_child(grid)
	var bodies := HBoxContainer.new()
	bodies.name = &"Bodies"
	bodies.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	for body: StringName in BODIES:
		bodies.add_child(_body_card(body))
	_add_option(grid, "TITLE_BODY", bodies)
	_add_option(grid, "CUSTOM_SKIN", _swatch_row(CustomizationOptions.KEY_SKIN, pal.skin_ramps, pal.skin_keys, 0))
	_add_option(grid, "CUSTOM_EYES", _swatch_row(CustomizationOptions.KEY_EYE_COLOR, pal.eye_ramps, pal.eye_keys, 0))
	_earring_label = Label.new()
	_add_option(grid, "CUSTOM_EARRINGS", _stepper(&"Earrings", _earring_label, _step_earring))
	return page


## Aba Cabelo: estilo (◀ nome ▶) e cor.
func _hair_page() -> Control:
	var page := _page(&"HairPage")
	var pal: CustomizationPalettes = _options.palettes
	var grid := _option_grid()
	page.add_child(grid)
	_style_label = Label.new()
	_add_option(grid, "CUSTOM_HAIR", _stepper(&"HairStyle", _style_label, _step_style))
	_add_option(grid, "CUSTOM_HAIR_COLOR", _swatch_row(CustomizationOptions.KEY_HAIR_COLOR, pal.hair_ramps,
			pal.hair_keys, HAIR_SWATCH_COLUMNS))
	return page


## Aba Origem: os 10 brasões e o quadro da região escolhida.
func _origin_page() -> Control:
	var page := _page(&"OriginPage")
	var hint := Label.new()
	hint.name = &"OriginHint"
	hint.text = tr("CUSTOM_NATIONALITY_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = UIKit.px(160, ui_scale)
	hint.add_theme_font_override(&"font", UIKit.read_font())
	hint.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
	hint.add_theme_color_override(&"font_color", C_INK_DIM)
	hint.visible = not _compact and hint.text != "CUSTOM_NATIONALITY_HINT"
	page.add_child(hint)
	# Stepper técnico (escondido): automação e testes trocam a origem por ele.
	_nationality_label = Label.new()
	var nat_stepper: Control = _stepper(&"Nationality", _nationality_label, _step_nationality)
	nat_stepper.visible = false
	page.add_child(nat_stepper)

	var center := CenterContainer.new()
	page.add_child(center)
	var grid := GridContainer.new()
	grid.name = &"Origins"
	grid.columns = 5
	var sep: int = UIKit.px(6, ui_scale)
	grid.add_theme_constant_override(&"h_separation", sep)
	grid.add_theme_constant_override(&"v_separation", sep)
	center.add_child(grid)
	for nat_id: StringName in _options.nationalities:
		var btn := Button.new()
		btn.name = StringName("Origin_%s" % nat_id)
		btn.toggle_mode = true
		btn.tooltip_text = tr(_options.nationality_key(nat_id))
		btn.custom_minimum_size = Vector2(maxi(_target(50), UIKit.px(54, ui_scale)), maxi(_target(54), UIKit.px(58, ui_scale)))
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var crest_path: String = CREST_MAP.get(nat_id, "")
		if not crest_path.is_empty() and ResourceLoader.exists(crest_path):
			btn.icon = load(crest_path) as Texture2D
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			btn.text = tr(_options.nationality_key(nat_id))
		_style_card_button(btn)
		btn.pressed.connect(func() -> void:
			appearance[CustomizationOptions.KEY_NATIONALITY] = nat_id
			_apply_appearance()
			if _sound_ready:
				AudioDirector.play_sfx(&"equip"))
		grid.add_child(btn)
		_origin_buttons[nat_id] = btn
	page.add_child(_nationality_card())
	return page


## Rodapé fixo da ficha: cartão com nome e servidor, mensagens e o botão Criar.
func _footer(player_name: String, host: String, port_text: String) -> Control:
	var footer := VBoxContainer.new()
	footer.name = &"CreationFooter"
	footer.add_theme_constant_override(&"separation", UIKit.px(6 if _compact else 8, ui_scale))

	var card := PanelContainer.new()
	card.name = &"NameCard"
	var card_box: StyleBoxFlat = _parchment_box(false)
	card_box.content_margin_top = UIKit.px(6 if _compact else 10, ui_scale)
	card_box.content_margin_bottom = card_box.content_margin_top
	card.add_theme_stylebox_override(&"panel", card_box)
	footer.add_child(card)
	var card_body := VBoxContainer.new()
	card_body.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	card.add_child(card_body)

	_name_edit = LineEdit.new()
	_name_edit.name = &"NameEdit"
	_name_edit.max_length = NAME_MAX
	_name_edit.placeholder_text = tr("TITLE_NAME_PLACEHOLDER")
	_name_edit.text = player_name
	_name_edit.clear_button_enabled = true
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.y = _target(30)
	_style_field(_name_edit)
	_name_edit.text_changed.connect(func(_t: String) -> void: _validate())
	_name_edit.text_submitted.connect(func(_t: String) -> void: request_play())

	var server_row := HBoxContainer.new()
	server_row.name = &"ServerRow"
	server_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	_server_pick = OptionButton.new()
	_server_pick.name = &"ServerPick"
	_server_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_pick.clip_text = true
	_server_pick.custom_minimum_size = Vector2(UIKit.px(80, ui_scale), _target(30))
	_server_pick.add_theme_font_override(&"font", UIKit.read_font())
	_server_pick.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
	_style_choice(_server_pick)
	_server_pick.item_selected.connect(_on_server_selected)
	server_row.add_child(_server_pick)
	var refresh_btn := Button.new()
	refresh_btn.name = &"ServerRefreshBtn"
	refresh_btn.tooltip_text = tr("TITLE_SERVER_REFRESH")
	refresh_btn.custom_minimum_size = Vector2(_target(30), _target(30))
	_style_choice(refresh_btn)
	refresh_btn.draw.connect(func() -> void: _draw_refresh_icon(refresh_btn))
	refresh_btn.pressed.connect(func() -> void: _check_servers_status())
	server_row.add_child(refresh_btn)

	_server_status_label = Label.new()
	_server_status_label.name = &"ServerStatusLabel"
	_server_status_label.add_theme_font_override(&"font", UIKit.read_font())
	_server_status_label.add_theme_font_size_override(&"font_size", UIKit.px(11, ui_scale))
	_server_status_label.add_theme_color_override(&"font_color", C_INK_DIM)

	if is_slot_mode():
		# Personagem salvo: o nome é do slot e não muda; só o servidor é escolhido.
		_name_edit.visible = false
		card_body.add_child(_name_edit)
		var grid_slot := GridContainer.new()
		grid_slot.columns = 2
		grid_slot.add_theme_constant_override(&"h_separation", UIKit.px(12, ui_scale))
		grid_slot.add_theme_constant_override(&"v_separation", UIKit.px(4, ui_scale))
		card_body.add_child(grid_slot)
		_add_option(grid_slot, "TITLE_HOST", server_row)
		grid_slot.add_child(Control.new())
		grid_slot.add_child(_server_status_label)
		_server_status_label.visible = not _compact
	elif _compact:
		# Pouca altura (celular deitado): nome e servidor lado a lado, sem rótulos.
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
		_name_edit.size_flags_stretch_ratio = 1.3
		row.add_child(_name_edit)
		row.add_child(server_row)
		card_body.add_child(row)
		_server_status_label.visible = false
		card_body.add_child(_server_status_label)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", UIKit.px(12, ui_scale))
		grid.add_theme_constant_override(&"v_separation", UIKit.px(6, ui_scale))
		card_body.add_child(grid)
		_add_option(grid, "TITLE_NAME", _name_edit)
		_add_option(grid, "TITLE_HOST", server_row)
		grid.add_child(Control.new())
		grid.add_child(_server_status_label)

	# Endereço e porta não aparecem para o jogador: ficam escondidos e são preenchidos pela lista.
	_advanced_toggle = Button.new()
	_advanced_toggle.visible = false
	_advanced_box = GridContainer.new()
	_advanced_box.columns = 2
	_advanced_box.visible = false
	card_body.add_child(_advanced_box)
	_advanced_box.add_child(_label("TITLE_HOST"))
	_host_edit = LineEdit.new()
	_host_edit.name = &"HostEdit"
	_host_edit.text = host if not host.is_empty() else DEFAULT_HOST
	_host_edit.text_changed.connect(func(_t: String) -> void: _validate())
	_advanced_box.add_child(_host_edit)
	_advanced_box.add_child(_label("TITLE_PORT"))
	_port_edit = LineEdit.new()
	_port_edit.name = &"PortEdit"
	_port_edit.text = port_text
	_port_edit.text_changed.connect(func(_t: String) -> void: _validate())
	_advanced_box.add_child(_port_edit)
	_load_servers()
	_sync_server_pick()
	_check_servers_status()

	_error = Label.new()
	_error.name = &"ErrorLabel"
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_font_override(&"font", UIKit.read_font())
	_error.add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	_error.add_theme_color_override(&"font_color", INK_RUBY)
	card_body.add_child(_error)
	_status = Label.new()
	_status.name = &"StatusLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	_status.add_theme_font_override(&"font", UIKit.read_font())
	_status.add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	_status.add_theme_color_override(&"font_color", C_INK_DIM)
	card_body.add_child(_status)

	_play = Button.new()
	_play.name = &"Play"
	_play.text = tr("TITLE_PLAY" if is_slot_mode() else "TITLE_CREATE_CHARACTER").to_upper()
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.custom_minimum_size.y = _target(40)
	_style_play_button(_play)
	_play.pressed.connect(func() -> void: request_play())
	footer.add_child(_play)
	return footer


# --- Slot de personagem (modo seleção) ----------------------------------------------------------

## true = a conta já tem personagem salvo: a tela mostra o slot para JOGAR, sem editar.
func is_slot_mode() -> bool:
	return not _slot.is_empty()


## Personagem do slot mostrado (cópia; {} = modo criação).
func get_slot() -> Dictionary:
	return _slot.duplicate()


## Recarrega os slots (ex.: o main gravou o slot e reabriu a tela) e refaz a tela no modo certo.
func reload_slots() -> void:
	_slot = CharacterSlots.first_filled()
	if is_slot_mode():
		_enter_slot_mode()
		_build(str(_slot[CharacterSlots.KEY_NAME]), _host_edit.text, _port_edit.text)
	else:
		_build(_name_edit.text, _host_edit.text, _port_edit.text)


## Corpo e aparência vêm do slot (aparência vazia = padrão do corpo, ou do masculino).
func _enter_slot_mode() -> void:
	var saved: Dictionary = _slot_appearance()
	var body: StringName = StringName(str(_slot.get(CharacterSlots.KEY_BODY, saved.get(CustomizationOptions.KEY_BODY, ""))))
	selected_body = body if body in BODIES else BODIES[0]
	appearance = saved.duplicate()
	appearance.erase(CustomizationOptions.KEY_BODY)


func _slot_appearance() -> Dictionary:
	var v: Variant = _slot.get(CharacterSlots.KEY_APPEARANCE, {})
	var saved: Dictionary = (v as Dictionary).duplicate() if v is Dictionary else {}
	var out: Dictionary = {}
	for k: Variant in saved:
		out[StringName(str(k))] = StringName(saved[k]) if saved[k] is String else saved[k]
	if out.is_empty() and _options != null:
		var body: StringName = StringName(str(_slot.get(CharacterSlots.KEY_BODY, "")))
		out = _options.default_appearance(body if body in BODIES else BODIES[0])
	return out


## Ficha do modo seleção: "SEUS PERSONAGENS", cartão do slot, aviso de que não muda mais, servidor e JOGAR.
func _slot_panel_body(body: VBoxContainer, player_name: String, host: String, port_text: String) -> void:
	body.add_child(_gold_header("TITLE_SLOTS_HEADER"))
	body.add_child(_spacer(UIKit.px(8, ui_scale)))
	var card := PanelContainer.new()
	card.name = &"SlotCard"
	card.add_theme_stylebox_override(&"panel", _parchment_box(false))
	body.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", UIKit.px(6 if _compact else 10, ui_scale))
	card.add_child(col)

	var entry := PanelContainer.new()
	entry.name = &"Slot_0"
	var esb: StyleBoxFlat = _choice_styles()[&"pressed"]
	esb.content_margin_left = UIKit.px(10, ui_scale)
	esb.content_margin_right = UIKit.px(10, ui_scale)
	esb.content_margin_top = UIKit.px(8, ui_scale)
	esb.content_margin_bottom = UIKit.px(8, ui_scale)
	entry.add_theme_stylebox_override(&"panel", esb)
	col.add_child(entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UIKit.px(12, ui_scale))
	entry.add_child(row)
	var saved: Dictionary = _slot_appearance()
	var nat: StringName = StringName(str(saved.get(CustomizationOptions.KEY_NATIONALITY, "")))
	var crest_path: String = CREST_MAP.get(nat, "")
	if not crest_path.is_empty() and ResourceLoader.exists(crest_path):
		var crest := TextureRect.new()
		crest.name = &"SlotCrest"
		var side: int = UIKit.px(56 if not _compact else 40, ui_scale)
		crest.custom_minimum_size = Vector2(side, side)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.texture = load(crest_path) as Texture2D
		row.add_child(crest)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	row.add_child(info)
	var name_label := Label.new()
	name_label.name = &"SlotName"
	name_label.text = str(_slot.get(CharacterSlots.KEY_NAME, player_name))
	name_label.clip_text = true
	name_label.add_theme_font_override(&"font", UIKit.read_font())
	name_label.add_theme_font_size_override(&"font_size", UIKit.px(20, ui_scale))
	name_label.add_theme_color_override(&"font_color", INK_RUBY)
	info.add_child(name_label)
	var details: PackedStringArray = [tr(BODY_KEYS[selected_body])]
	if not nat.is_empty() and _options != null and nat in _options.nationalities:
		details.append(tr(_options.nationality_key(nat)))
	var detail_label := Label.new()
	detail_label.name = &"SlotDetails"
	detail_label.text = " · ".join(details)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_override(&"font", UIKit.read_font())
	detail_label.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	detail_label.add_theme_color_override(&"font_color", INK_DARK)
	info.add_child(detail_label)
	var level: int = int(_slot.get(CharacterSlots.KEY_LEVEL, 0))
	if level > 0:
		var level_label := Label.new()
		level_label.name = &"SlotLevel"
		level_label.text = tr("TITLE_SLOT_LEVEL") % level
		level_label.add_theme_font_override(&"font", UIKit.read_font())
		level_label.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
		level_label.add_theme_color_override(&"font_color", C_INK_DIM)
		info.add_child(level_label)
	var count := Label.new()
	count.name = &"SlotCount"
	var used: int = 0
	for d: Dictionary in CharacterSlots.load_slots():
		used += 0 if d.is_empty() else 1
	count.text = tr("TITLE_SLOT_COUNT") % [maxi(1, used), CharacterSlots.slot_count()]
	count.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	count.add_theme_font_override(&"font", UIKit.read_font())
	count.add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	count.add_theme_color_override(&"font_color", C_INK_DIM)
	row.add_child(count)

	var note := Label.new()
	note.name = &"SlotLockedNote"
	note.text = tr("TITLE_SLOT_LOCKED")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = UIKit.px(160, ui_scale)
	note.add_theme_font_override(&"font", UIKit.read_font())
	note.add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	note.add_theme_color_override(&"font_color", C_INK_DIM)
	col.add_child(note)

	body.add_child(_spacer(UIKit.px(6 if _compact else 10, ui_scale)))
	body.add_child(_footer(player_name, host, port_text))


## Botão Criar: folha com aro de ouro (destaque principal da ficha).
func _style_play_button(b: Button) -> void:
	var border: int = maxi(2, UIKit.px(2, ui_scale))
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_LEAF
	normal.border_color = C_GOLD
	normal.set_border_width_all(border)
	normal.set_corner_radius_all(maxi(3, UIKit.px(6, ui_scale)))
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = UIKit.px(4, ui_scale)
	normal.shadow_offset = Vector2(0, UIKit.px(2, ui_scale))
	normal.content_margin_left = UIKit.px(16, ui_scale)
	normal.content_margin_right = UIKit.px(16, ui_scale)
	normal.content_margin_top = UIKit.px(6, ui_scale)
	normal.content_margin_bottom = UIKit.px(6, ui_scale)
	normal.anti_aliasing = false
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = C_LEAF.lightened(0.15)
	hover.border_color = C_GOLD_LIGHT
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = C_LEAF.darkened(0.25)
	pressed.shadow_size = 0
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color8(86, 92, 78)
	disabled.border_color = C_GOLD_AGED.darkened(0.3)
	disabled.shadow_size = 0
	var focus: StyleBoxFlat = normal.duplicate()
	focus.draw_center = false
	focus.border_color = C_GOLD_LIGHT
	focus.shadow_size = 0
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.add_theme_stylebox_override(&"disabled", disabled)
	b.add_theme_stylebox_override(&"focus", focus)
	b.add_theme_font_override(&"font", UIKit.font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(16, ui_scale))
	b.add_theme_color_override(&"font_color", Color8(255, 245, 200))
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color8(255, 245, 200))
	b.add_theme_color_override(&"font_focus_color", Color8(255, 245, 200))
	b.add_theme_color_override(&"font_disabled_color", Color8(196, 200, 186))
	b.add_theme_color_override(&"font_outline_color", Color8(10, 36, 24))
	b.add_theme_constant_override(&"outline_size", maxi(2, UIKit.px(3, ui_scale)))


## Campo de texto sobre o pergaminho: miolo claro, borda de madeira, ouro no foco.
func _style_field(e: LineEdit) -> void:
	var border: int = maxi(1, UIKit.px(1, ui_scale))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color8(252, 246, 230)
	normal.border_color = C_PARCHMENT_EDGE
	normal.set_border_width_all(border)
	normal.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	normal.content_margin_left = UIKit.px(8, ui_scale)
	normal.content_margin_right = UIKit.px(6, ui_scale)
	normal.content_margin_top = UIKit.px(3, ui_scale)
	normal.content_margin_bottom = UIKit.px(3, ui_scale)
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = C_GOLD_AGED
	focus.set_border_width_all(maxi(2, UIKit.px(2, ui_scale)))
	e.add_theme_stylebox_override(&"normal", normal)
	e.add_theme_stylebox_override(&"focus", focus)
	e.add_theme_font_override(&"font", UIKit.read_font())
	e.add_theme_font_size_override(&"font_size", UIKit.px(15, ui_scale))
	e.add_theme_color_override(&"font_color", INK_DARK)
	e.add_theme_color_override(&"font_placeholder_color", C_INK_DIM)
	e.add_theme_color_override(&"clear_button_color", C_INK_DIM)
	e.add_theme_color_override(&"clear_button_color_pressed", INK_RUBY)


## Botão de escolha sobre o pergaminho (servidor, setas, corpo): pergaminho escuro; ativo = ouro.
func _choice_styles() -> Dictionary[StringName, StyleBoxFlat]:
	var border: int = maxi(1, UIKit.px(1, ui_scale))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color8(233, 218, 186)
	normal.border_color = C_PARCHMENT_EDGE
	normal.set_border_width_all(border)
	normal.border_width_bottom = maxi(2, UIKit.px(2, ui_scale))
	normal.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	normal.content_margin_left = UIKit.px(8, ui_scale)
	normal.content_margin_right = UIKit.px(8, ui_scale)
	normal.content_margin_top = UIKit.px(3, ui_scale)
	normal.content_margin_bottom = UIKit.px(3, ui_scale)
	normal.anti_aliasing = false
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color8(246, 236, 212)
	hover.border_color = C_GOLD_AGED
	var on: StyleBoxFlat = normal.duplicate()
	on.bg_color = Color8(250, 232, 168)
	on.border_color = C_GOLD_AGED
	on.set_border_width_all(maxi(2, UIKit.px(2, ui_scale)))
	var focus: StyleBoxFlat = normal.duplicate()
	focus.draw_center = false
	focus.border_color = C_GOLD_AGED
	return {&"normal": normal, &"hover": hover, &"pressed": on, &"focus": focus}


func _style_choice(b: Button) -> void:
	var st: Dictionary[StringName, StyleBoxFlat] = _choice_styles()
	b.add_theme_stylebox_override(&"normal", st[&"normal"])
	b.add_theme_stylebox_override(&"hover", st[&"hover"])
	b.add_theme_stylebox_override(&"pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"hover_pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"focus", st[&"focus"])
	b.add_theme_color_override(&"font_color", INK_DARK)
	b.add_theme_color_override(&"font_focus_color", INK_DARK)
	b.add_theme_color_override(&"font_hover_color", INK_RUBY)
	b.add_theme_color_override(&"font_pressed_color", INK_RUBY)
	b.add_theme_color_override(&"font_hover_pressed_color", INK_RUBY)


## Ícone de "atualizar" desenhado (a fonte pixel não tem ⟳).
func _draw_refresh_icon(b: Button) -> void:
	var c: Vector2 = b.size * 0.5
	var r: float = minf(b.size.x, b.size.y) * 0.24
	var w: float = maxf(2.0, roundf(2.0 * ui_scale))
	var col: Color = INK_RUBY if b.is_hovered() else INK_DARK
	b.draw_arc(c, r, -PI * 0.35, PI * 1.35, 18, col, w)
	var tip: Vector2 = c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * r
	var h: float = r * 0.75
	b.draw_colored_polygon(PackedVector2Array([tip + Vector2(-h * 0.2, -h * 0.75), tip + Vector2(h * 0.75, h * 0.1),
			tip + Vector2(-h * 0.45, h * 0.45)]), col)


func _body_card(body: StringName) -> Control:
	var b := Button.new()
	b.name = String(body)
	b.text = tr(BODY_KEYS[body])
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UIKit.px(70, ui_scale), maxi(_target(42), UIKit.px(34, ui_scale)))
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	_style_choice(b)
	b.pressed.connect(_select_body.bind(body))
	_body_buttons[body] = b
	return b


## Botão de pergaminho (girar, aleatório, configurações) sobre o palco.
func _style_gold_button(b: Button) -> void:
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	_style_choice(b)


# --- Palco do Viajante e prévia -------------------------------------------------------------------

## Onde o centro do pedestal pintado do fundo cai na tela (mesmo "cover" centrado do TextureRect do fundo)
## e o raio do disco, em px de tela. Sem a ilustração: centro do lado esquerdo.
func _dais_on_screen(vp: Vector2) -> Dictionary:
	var tex: Texture2D = load(BACKGROUND_PATH) as Texture2D if ResourceLoader.exists(BACKGROUND_PATH) else null
	if tex == null:
		return {&"center": Vector2(vp.x * 0.28, vp.y * 0.72), &"radius": vp.y * 0.18}
	var ts: Vector2 = tex.get_size()
	var s: float = maxf(vp.x / ts.x, vp.y / ts.y)
	var offset: Vector2 = (vp - ts * s) * 0.5
	return {&"center": offset + DAIS_CENTER_UV * ts * s, &"radius": DAIS_RADIUS_UV * ts.x * s}


## Põe o Viajante em pé no centro do pedestal pintado (escala inteira proporcional ao disco), com
## girar/aleatório logo abaixo e configurações/sair no canto. Retorna até onde (x) o pedestal vai.
func _place_hero_on_dais(vp: Vector2, pad: float) -> float:
	var dais: Dictionary = _dais_on_screen(vp)
	var center: Vector2 = dais[&"center"]
	var radius: float = dais[&"radius"]
	var hero := Control.new()
	hero.name = &"HeroStageRoot"
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)

	_preview = LayeredCharacterPreview.new()
	_preview.name = &"Preview"
	_preview.show_rotate_buttons = false
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame: float = _preview.get_minimum_size_for_scale(1).y
	var row_h: int = _target(30)
	# Disco maior = Viajante maior; a cabeça nunca passa do topo da tela.
	var k_room: int = floori((center.y - pad) / frame)
	var k: int = clampi(roundi(radius / DAIS_RADIUS_PER_SCALE), 1, maxi(1, k_room))
	_preview.fixed_scale = k
	var box: Vector2 = _preview.get_minimum_size_for_scale(k)
	# Os pés (sombra) ficam 2 texels acima da base do quadro: alinhá-los ao centro do disco.
	_preview.position = Vector2(roundf(center.x - box.x * 0.5), roundf(center.y - box.y + 2.0 * k))
	_preview.size = box
	hero.add_child(_preview)

	# Área de arrastar/tocar para girar: o Viajante e o disco.
	var drag := Control.new()
	drag.name = &"Dais"
	drag.mouse_filter = Control.MOUSE_FILTER_STOP
	var half_w: float = maxf(radius, box.x * 0.35)
	drag.position = Vector2(center.x - half_w, _preview.position.y + box.y * 0.2)
	drag.size = Vector2(half_w * 2.0, center.y + radius * 0.35 - drag.position.y)
	hero.add_child(drag)
	_connect_drag_rotate(drag)

	var rot_row := _rotate_row(row_h)
	rot_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hero.add_child(rot_row)
	var row_size: Vector2 = rot_row.get_combined_minimum_size()
	var row_y: float = minf(vp.y - pad - row_size.y, center.y + radius * 0.55)
	rot_row.position = Vector2(roundf(center.x - row_size.x * 0.5), roundf(maxf(row_y, center.y + 2.0 * k)))
	rot_row.size = row_size

	var sys_row := _system_row(_target(28))
	sys_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sys_row.position = Vector2(pad, pad)
	hero.add_child(sys_row)
	return maxf(center.x + radius * 1.1, rot_row.position.x + row_size.x)


## Retrato (janela de PC estreita): Viajante centrado em cima da ficha, sem pedestal.
func _hero_column(avail: Vector2) -> Control:
	var column := VBoxContainer.new()
	column.name = &"HeroStageRoot"
	column.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	var stage := CenterContainer.new()
	stage.name = &"StageArea"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(stage)
	_preview = LayeredCharacterPreview.new()
	_preview.name = &"Preview"
	_preview.show_rotate_buttons = false
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row_h: int = _target(30)
	var frame: float = _preview.get_minimum_size_for_scale(1).y
	var stage_h: float = avail.y - row_h * 2.0 - UIKit.px(12, ui_scale)
	var k_max: int = maxi(PREVIEW_MIN_SCALE, roundi(ui_scale * PREVIEW_SCALE_PER_UI))
	var k: int = clampi(floori(minf(avail.x, stage_h) / frame), 1, k_max)
	_preview.fixed_scale = k
	_preview.custom_minimum_size = _preview.get_minimum_size_for_scale(k)
	stage.add_child(_preview)
	_connect_drag_rotate(stage)
	var rot_row := _rotate_row(row_h)
	column.add_child(rot_row)
	column.add_child(_system_row(_target(28)))
	return column


## ◀ Aleatório ▶ (girar o Viajante e sortear a aparência).
func _rotate_row(row_h: int) -> HBoxContainer:
	var rot_row := HBoxContainer.new()
	rot_row.name = &"RotateRow"
	rot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rot_row.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	var rot_l := Button.new()
	rot_l.name = &"RotateLeft"
	rot_l.text = "◀"
	rot_l.tooltip_text = tr("CUSTOM_ROTATE_LEFT")
	rot_l.custom_minimum_size = Vector2(row_h, row_h)
	_style_gold_button(rot_l)
	rot_l.pressed.connect(func() -> void: _rotate_preview(-1))
	rot_row.add_child(rot_l)
	var rnd := Button.new()
	rnd.name = &"Random"
	rnd.text = tr("CUSTOM_RANDOM")
	rnd.custom_minimum_size = Vector2(UIKit.px(110, ui_scale), row_h)
	_style_gold_button(rnd)
	rnd.pressed.connect(func() -> void: randomize_appearance())
	rnd.visible = not is_slot_mode()
	rot_row.add_child(rnd)
	var rot_r := Button.new()
	rot_r.name = &"RotateRight"
	rot_r.text = "▶"
	rot_r.tooltip_text = tr("CUSTOM_ROTATE_RIGHT")
	rot_r.custom_minimum_size = Vector2(row_h, row_h)
	_style_gold_button(rot_r)
	rot_r.pressed.connect(func() -> void: _rotate_preview(1))
	rot_row.add_child(rot_r)
	return rot_row


## Configurações e Sair.
func _system_row(h: int) -> HBoxContainer:
	var sys_row := HBoxContainer.new()
	sys_row.name = &"SystemRow"
	sys_row.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	var settings_btn := Button.new()
	settings_btn.name = &"SettingsButton"
	settings_btn.text = tr("TITLE_SETTINGS")
	settings_btn.custom_minimum_size.y = h
	_style_gold_button(settings_btn)
	settings_btn.pressed.connect(func() -> void: _settings.toggle())
	sys_row.add_child(settings_btn)
	var quit_btn := Button.new()
	quit_btn.name = &"QuitButton"
	quit_btn.text = tr("TITLE_QUIT")
	quit_btn.custom_minimum_size.y = h
	_style_gold_button(quit_btn)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	sys_row.add_child(quit_btn)
	return sys_row


## Arrastar (ou tocar dos lados) no palco gira o Viajante.
func _connect_drag_rotate(stage: Control) -> void:
	var drag_info: Array = [0.0, false]
	stage.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				drag_info[1] = true
				drag_info[0] = mb.position.x
			elif drag_info[1]:
				drag_info[1] = false
				var diff: float = mb.position.x - float(drag_info[0])
				if absf(diff) <= 10.0 * ui_scale:
					var mid: float = stage.size.x * 0.5
					if mb.position.x < mid - 15.0 * ui_scale:
						_rotate_preview(-1)
					elif mb.position.x > mid + 15.0 * ui_scale:
						_rotate_preview(1)
		elif event is InputEventMouseMotion and drag_info[1]:
			var mm := event as InputEventMouseMotion
			if absf(mm.position.x - float(drag_info[0])) >= 22.0 * ui_scale:
				_rotate_preview(1 if mm.position.x > float(drag_info[0]) else -1)
				drag_info[0] = mm.position.x)


func _rotate_preview(dir: int) -> void:
	if is_instance_valid(_preview):
		_preview.rotate_by(dir)
		if _sound_ready:
			AudioDirector.play_sfx(&"swing_blade")


## Quadro da nacionalidade: brasão da região, nome, frase do atlas (WA_R_*_HOOK) e cores.
func _nationality_card() -> Control:
	var card := PanelContainer.new()
	card.name = &"NationalityCard"
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color8(232, 214, 176)
	csb.border_color = C_PARCHMENT_EDGE
	csb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	csb.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	csb.content_margin_left = UIKit.px(10, ui_scale)
	csb.content_margin_right = UIKit.px(10, ui_scale)
	csb.content_margin_top = UIKit.px(8, ui_scale)
	csb.content_margin_bottom = UIKit.px(8, ui_scale)
	card.add_theme_stylebox_override(&"panel", csb)

	var h_main := HBoxContainer.new()
	h_main.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	card.add_child(h_main)

	_nat_card_crest = TextureRect.new()
	_nat_card_crest.name = &"Crest"
	var crest_size: int = UIKit.px(52, ui_scale)
	_nat_card_crest.custom_minimum_size = Vector2(crest_size, crest_size)
	_nat_card_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nat_card_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nat_card_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_nat_card_crest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	h_main.add_child(_nat_card_crest)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	h_main.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	v.add_child(head)
	_nat_card_title = Label.new()
	_nat_card_title.name = &"Region"
	_nat_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nat_card_title.add_theme_font_override(&"font", UIKit.read_font())
	_nat_card_title.add_theme_font_size_override(&"font_size", UIKit.px(17, ui_scale))
	_nat_card_title.add_theme_color_override(&"font_color", INK_RUBY)
	head.add_child(_nat_card_title)
	_nat_card_swatches.clear()
	var side: int = UIKit.px(SWATCH_PX * 0.75, ui_scale)
	for i: int in 2:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(side, side)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(sw)
		_nat_card_swatches.append(sw)
	_nat_card_hook = Label.new()
	_nat_card_hook.name = &"Hook"
	_nat_card_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nat_card_hook.custom_minimum_size.x = UIKit.px(150, ui_scale)
	_nat_card_hook.add_theme_font_override(&"font", UIKit.read_font())
	_nat_card_hook.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	_nat_card_hook.add_theme_color_override(&"font_color", INK_DARK)
	v.add_child(_nat_card_hook)
	return card


func _update_nationality_card() -> void:
	if not is_instance_valid(_nat_card_title) or _options == null:
		return
	var nat: StringName = StringName(str(appearance.get(CustomizationOptions.KEY_NATIONALITY, _options.default_nationality)))
	var key: String = _options.nationality_key(nat)
	_nat_card_title.text = tr(key)
	var hook_key: String = key + "_HOOK"
	_nat_card_hook.text = tr(hook_key) if tr(hook_key) != hook_key else ""
	var cloth: PackedColorArray = _options.nationality_cloth(nat)
	var colors: Array[Color] = [NAT_DEFAULT_CLOTH, NAT_DEFAULT_ACCENT]
	if cloth.size() >= 2:
		colors = [cloth[0], cloth[1]]
	for i: int in _nat_card_swatches.size():
		_nat_card_swatches[i].color = colors[i]
	if is_instance_valid(_nat_card_crest):
		var crest_path: String = CREST_MAP.get(nat, "")
		if not crest_path.is_empty() and ResourceLoader.exists(crest_path):
			_nat_card_crest.texture = load(crest_path) as Texture2D
			_nat_card_crest.visible = true
		else:
			_nat_card_crest.visible = false


## Cartão de brasão: pergaminho escuro; escolhido = fundo dourado com aro de ouro.
func _style_card_button(b: Button) -> void:
	var st: Dictionary[StringName, StyleBoxFlat] = _choice_styles()
	for s: StyleBoxFlat in st.values():
		s.content_margin_left = UIKit.px(4, ui_scale)
		s.content_margin_right = UIKit.px(4, ui_scale)
		s.content_margin_top = UIKit.px(4, ui_scale)
		s.content_margin_bottom = UIKit.px(4, ui_scale)
	b.add_theme_stylebox_override(&"normal", st[&"normal"])
	b.add_theme_stylebox_override(&"hover", st[&"hover"])
	b.add_theme_stylebox_override(&"pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"hover_pressed", st[&"pressed"])
	b.add_theme_stylebox_override(&"focus", st[&"focus"])


## Fileira de amostras de cor (uma por rampa). columns 0 = tudo numa linha.
func _swatch_row(key: StringName, ramps: Array[PackedColorArray], keys: PackedStringArray, columns: int) -> Control:
	var grid := GridContainer.new()
	grid.name = StringName("Swatches_%s" % key)
	grid.columns = columns if columns > 0 else maxi(1, ramps.size())
	var sep: int = UIKit.px(5, ui_scale)
	grid.add_theme_constant_override(&"h_separation", sep)
	grid.add_theme_constant_override(&"v_separation", sep)
	var buttons: Array = []
	var side: int = _target(28 if _compact else 34)
	var border: int = maxi(1, UIKit.px(1, ui_scale))
	var ring: int = maxi(2, UIKit.px(3, ui_scale))
	var rad: int = maxi(2, UIKit.px(4, ui_scale))
	for i: int in ramps.size():
		var b := Button.new()
		b.name = StringName("%s_%d" % [key, i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(side, side)
		b.tooltip_text = tr(keys[i]) if i < keys.size() else ""
		var c: Color = CustomizationPalettes.swatch(ramps[i])
		var off := StyleBoxFlat.new()
		off.bg_color = c
		off.border_color = C_WOOD
		off.set_border_width_all(border)
		off.set_corner_radius_all(rad)
		off.anti_aliasing = false
		var hover: StyleBoxFlat = off.duplicate()
		hover.border_color = C_GOLD_AGED
		hover.set_border_width_all(maxi(2, UIKit.px(2, ui_scale)))
		# Escolhida: aro escuro grosso com brilho de ouro em volta (lê bem em qualquer cor, até no amarelo).
		var on: StyleBoxFlat = off.duplicate()
		on.border_color = C_WOOD_DARK
		on.set_border_width_all(ring)
		on.expand_margin_left = ring
		on.expand_margin_right = ring
		on.expand_margin_top = ring
		on.expand_margin_bottom = ring
		on.shadow_color = C_GOLD
		on.shadow_size = maxi(3, UIKit.px(5, ui_scale))
		for state: StringName in [&"normal", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(state, off)
		b.add_theme_stylebox_override(&"hover", hover)
		b.add_theme_stylebox_override(&"pressed", on)
		b.add_theme_stylebox_override(&"hover_pressed", on)
		b.pressed.connect(_set_choice.bind(key, i))
		grid.add_child(b)
		buttons.append(b)
	_swatches[key] = buttons
	return grid


## ◀ nome ▶ (estilo de cabelo, brincos, nacionalidade).
func _stepper(node_name: StringName, value_label: Label, step: Callable) -> Control:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	var h: int = _target(30)
	var prev := Button.new()
	prev.name = &"Prev"
	prev.text = "◀"
	prev.tooltip_text = tr("CUSTOM_PREV")
	prev.custom_minimum_size = Vector2(h, h)
	_style_gold_button(prev)
	prev.pressed.connect(step.bind(-1))
	row.add_child(prev)

	var field := PanelContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color8(252, 246, 230)
	fsb.border_color = C_PARCHMENT_EDGE
	fsb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	fsb.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	fsb.content_margin_left = UIKit.px(6, ui_scale)
	fsb.content_margin_right = UIKit.px(6, ui_scale)
	field.add_theme_stylebox_override(&"panel", fsb)
	row.add_child(field)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	value_label.custom_minimum_size.x = UIKit.px(STEPPER_LABEL_PX * 0.8, ui_scale)
	value_label.add_theme_font_override(&"font", UIKit.read_font())
	value_label.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	value_label.add_theme_color_override(&"font_color", INK_DARK)
	field.add_child(value_label)

	var next := Button.new()
	next.name = &"Next"
	next.text = "▶"
	next.tooltip_text = tr("CUSTOM_NEXT")
	next.custom_minimum_size = Vector2(h, h)
	_style_gold_button(next)
	next.pressed.connect(step.bind(1))
	row.add_child(next)
	return row


func _set_choice(key: StringName, index: int) -> void:
	appearance[key] = index
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"equip")


func _step_style(step: int) -> void:
	var styles: Array[StringName] = _options.styles_for(selected_body)
	if styles.is_empty():
		return
	var i: int = styles.find(StringName(str(appearance.get(CustomizationOptions.KEY_HAIR_STYLE, ""))))
	appearance[CustomizationOptions.KEY_HAIR_STYLE] = styles[posmod(i + step, styles.size())]
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"equip")


func _step_earring(step: int) -> void:
	var ears: Array[StringName] = _options.earring_choices()
	if ears.is_empty():
		return
	var i: int = ears.find(StringName(str(appearance.get(CustomizationOptions.KEY_EARRINGS, ""))))
	appearance[CustomizationOptions.KEY_EARRINGS] = ears[posmod(i + step, ears.size())]
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"equip")


func _step_nationality(step: int) -> void:
	var nats: Array[StringName] = _options.nationalities
	if nats.is_empty():
		return
	var i: int = nats.find(StringName(str(appearance.get(CustomizationOptions.KEY_NATIONALITY, ""))))
	appearance[CustomizationOptions.KEY_NATIONALITY] = nats[posmod(i + step, nats.size())]
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"equip")


func _apply_appearance() -> void:
	appearance = get_appearance()
	appearance.erase(CustomizationOptions.KEY_BODY)
	if _options == null:
		return
	if is_instance_valid(_preview):
		_preview.set_appearance(get_appearance())
	for key: StringName in _swatches:
		var chosen: int = int(appearance.get(key, 0))
		for i: int in _swatches[key].size():
			(_swatches[key][i] as Button).set_pressed_no_signal(i == chosen)
	if is_instance_valid(_style_label):
		_style_label.text = tr(_options.style_key(appearance[CustomizationOptions.KEY_HAIR_STYLE]))
	if is_instance_valid(_earring_label):
		_earring_label.text = tr(_options.earring_key(appearance[CustomizationOptions.KEY_EARRINGS]))
	if is_instance_valid(_nationality_label):
		_nationality_label.text = tr(_options.nationality_key(appearance[CustomizationOptions.KEY_NATIONALITY]))
	_update_nationality_card()

	# Sincroniza cards de Origem
	var current_nat: StringName = StringName(str(appearance.get(CustomizationOptions.KEY_NATIONALITY, "")))
	for n_id: StringName in _origin_buttons:
		_origin_buttons[n_id].set_pressed_no_signal(n_id == current_nat)

	# Sincroniza cards de Olhos
	var current_eye: int = int(appearance.get(CustomizationOptions.KEY_EYE_COLOR, 0))
	for e_idx: int in _eye_buttons:
		_eye_buttons[e_idx].set_pressed_no_signal(e_idx == current_eye)

	# Sincroniza Slider de Cabelo
	if is_instance_valid(_hair_slider):
		_hair_slider.set_value_no_signal(float(appearance.get(CustomizationOptions.KEY_HAIR_COLOR, 0)))


func _load_appearance() -> Dictionary:
	var cfg := ConfigFile.new()
	var out: Dictionary = {}
	if cfg.load(APPEARANCE_PATH) == OK:
		for k: String in cfg.get_section_keys(APPEARANCE_SECTION) if cfg.has_section(APPEARANCE_SECTION) else PackedStringArray():
			var v: Variant = cfg.get_value(APPEARANCE_SECTION, k)
			out[StringName(k)] = StringName(v) if v is String else v
	return out


func _save_appearance() -> void:
	var cfg := ConfigFile.new()
	for k: StringName in appearance:
		var v: Variant = appearance[k]
		cfg.set_value(APPEARANCE_SECTION, String(k), String(v) if v is StringName else v)
	cfg.save(APPEARANCE_PATH)


func _select_body(body: StringName) -> void:
	if body not in BODIES:
		body = BODIES[0]
	selected_body = body
	for b: StringName in _body_buttons:
		_body_buttons[b].set_pressed_no_signal(b == body)
	_apply_appearance()
	if _sound_ready:
		AudioDirector.play_sfx(&"equip")


func _on_advanced_toggled(on: bool) -> void:
	_advanced_box.visible = on
	_advanced_toggle.text = "%s %s" % [tr("TITLE_ADVANCED"), "▾" if on else "▸"]


func _validate() -> bool:
	if _name_edit == null:
		return false
	var err: String = ""
	if not _name_edit.text.strip_edges().is_empty():
		err = validate_name(_name_edit.text)
	if err.is_empty() and _host_edit.text.strip_edges().is_empty():
		err = "TITLE_ERR_HOST"
	var port_text: String = _port_edit.text.strip_edges()
	if err.is_empty() and (not port_text.is_valid_int() or port_text.to_int() < PORT_MIN or port_text.to_int() > PORT_MAX):
		err = "TITLE_ERR_PORT"
	_error.text = tr(err) if not err.is_empty() else ""
	_error.visible = not _error.text.is_empty()
	var ok: bool = err.is_empty() and validate_name(_name_edit.text).is_empty()
	_play.disabled = not ok or _busy
	return ok


func _label(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.add_theme_font_override(&"font", UIKit.read_font())
	l.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
	l.add_theme_color_override(&"font_color", INK_DARK)
	return l


func _section_header(key: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = tr(key).to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", UIKit.read_font())
	l.add_theme_font_size_override(&"font_size", UIKit.px(16, ui_scale))
	l.add_theme_color_override(&"font_color", INK_RUBY)
	for side: int in 2:
		var rule := ColorRect.new()
		rule.color = Color8(160, 112, 56)
		rule.custom_minimum_size = Vector2(UIKit.px(44, ui_scale), maxi(1, UIKit.px(2, ui_scale)))
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rule)
		if side == 0:
			row.add_child(l)
	return row


## Partículas místicas de éter e pétalas de ipê caindo sobre o fundo (cenário vivo animado).
func _add_petals() -> void:
	var size: Vector2 = get_viewport_rect().size

	# 1. Centelhas mágicas de éter (motes dourados/celestes flutuando suavemente do chão e portal)
	var sparks := CPUParticles2D.new()
	sparks.name = &"MagicMotes"
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = glow
	sparks.amount = 36
	sparks.lifetime = 5.5
	sparks.preprocess = 5.5
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.position = Vector2(size.x * 0.32, size.y * 0.72)
	sparks.emission_rect_extents = Vector2(size.x * 0.32, size.y * 0.28)
	sparks.direction = Vector2(0.25, -1.0)
	sparks.spread = 45.0
	sparks.gravity = Vector2(1.5, -9.0)
	sparks.initial_velocity_min = 14.0
	sparks.initial_velocity_max = 32.0
	sparks.color = Color8(255, 222, 105, 230)
	sparks.scale_amount_min = 2.0 * ui_scale
	sparks.scale_amount_max = 4.5 * ui_scale
	add_child(sparks)

	# 2. Pétalas de ipê
	if not ResourceLoader.exists(PETAL_PATH):
		return
	var petals := CPUParticles2D.new()
	petals.name = &"Petals"
	petals.texture = load(PETAL_PATH) as Texture2D
	petals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var petal_glow := CanvasItemMaterial.new()
	petal_glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	petals.material = petal_glow
	petals.amount = PETAL_AMOUNT
	petals.lifetime = PETAL_LIFETIME_SEC
	petals.preprocess = PETAL_LIFETIME_SEC
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.position = Vector2(size.x * 0.2, size.y * 0.32)
	petals.emission_rect_extents = Vector2(size.x * 0.2, size.y * 0.3)
	petals.direction = Vector2(1.0, 1.0)
	petals.spread = 25.0
	petals.gravity = Vector2(4.0, 3.0)
	petals.initial_velocity_min = 10.0
	petals.initial_velocity_max = 30.0
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	var scale_px: float = maxf(1.0, floorf(size.y / Balance.cfg.internal_resolution.y))
	petals.scale_amount_min = scale_px
	petals.scale_amount_max = scale_px
	add_child(petals)


## Painel de pergaminho Sun Haven e moldura de madeira: leitura aconchegante e nítida.
func _apply_title_theme(t: Theme) -> void:
	var border: int = maxi(1, UIKit.px(UIKit.BORDER, ui_scale))
	var pad: int = UIKit.px(UIKit.PADDING, ui_scale)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PARCHMENT_BG
	panel.border_color = WOOD_FRAME
	panel.set_border_width_all(maxi(2, UIKit.px(3, ui_scale)))
	panel.set_corner_radius_all(maxi(3, UIKit.px(6, ui_scale)))
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = UIKit.px(16, ui_scale)
	panel.content_margin_left = pad * 2
	panel.content_margin_right = pad * 2
	panel.content_margin_top = pad * 2
	panel.content_margin_bottom = pad * 2
	panel.anti_aliasing = false
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	var normal: StyleBoxFlat = UIKit.flat_box(Color8(224, 212, 192), WOOD_FRAME, border, pad)
	var hover: StyleBoxFlat = UIKit.flat_box(Color8(238, 226, 206), TITLE_GOLD, border, pad)
	var pressed: StyleBoxFlat = UIKit.flat_box(Color8(200, 185, 160), WOOD_FRAME, border, pad)
	for sb: StyleBoxFlat in [normal, hover, pressed]:
		sb.set_corner_radius_all(UIKit.px(4, ui_scale))
	for type_name: StringName in [&"Button", &"OptionButton", &"CheckBox"]:
		t.set_stylebox(&"normal", type_name, normal)
		t.set_stylebox(&"hover", type_name, hover)
		t.set_stylebox(&"pressed", type_name, pressed)
		t.set_stylebox(&"hover_pressed", type_name, pressed)
		t.set_color(&"font_color", type_name, INK_DARK)
		t.set_color(&"font_hover_color", type_name, INK_RUBY)
		t.set_color(&"font_pressed_color", type_name, INK_RUBY)
		t.set_font(&"font", type_name, UIKit.read_font())
		t.set_font_size(&"font_size", type_name, UIKit.px(13, ui_scale))
	t.set_color(&"font_color", &"Label", INK_DARK)
	t.set_font(&"font", &"Label", UIKit.read_font())
	t.set_font_size(&"font_size", &"Label", UIKit.px(13, ui_scale))
	var line_edit_sb := StyleBoxFlat.new()
	line_edit_sb.bg_color = Color8(255, 255, 255, 250)
	line_edit_sb.border_color = WOOD_FRAME
	line_edit_sb.set_border_width_all(border)
	line_edit_sb.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	line_edit_sb.content_margin_left = pad * 1.5
	line_edit_sb.content_margin_right = pad * 1.5
	line_edit_sb.content_margin_top = pad
	line_edit_sb.content_margin_bottom = pad
	t.set_stylebox(&"normal", &"LineEdit", line_edit_sb)
	t.set_color(&"font_color", &"LineEdit", INK_DARK)
	t.set_font(&"font", &"LineEdit", UIKit.read_font())
	t.set_font_size(&"font_size", &"LineEdit", UIKit.px(15, ui_scale))


func _sky_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, SKY_TOP)
	g.set_color(1, SKY_BOTTOM)
	g.add_point(SKY_MID_OFFSET, SKY_MID)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	return t


## Falha/recusa enquanto o título ainda está na tela (ex.: nome em uso).
func _on_connection_closed(reason_key: String) -> void:
	set_busy(false)
	if not reason_key.is_empty():
		set_status(reason_key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE \
			and _settings.visible:
		_settings.close()
		get_viewport().set_input_as_handled()
	elif (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_pressed() \
			and handle_pad_button(event):
		get_viewport().set_input_as_handled()


# --- Controle -------------------------------------------------------------------------------------

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	_set_using_pad(connected or GamepadInput.is_connected_any())
	if _using_pad:
		focus_default()


func _set_using_pad(value: bool) -> void:
	_using_pad = value
	if is_instance_valid(_pad_hints):
		_pad_hints.visible = value
	if is_instance_valid(_pad_ring):
		_pad_ring.active = value


func _input(event: InputEvent) -> void:
	if GamepadInput.is_pad_activity(event):
		if not _using_pad:
			_set_using_pad(true)
	elif GamepadInput.is_other_activity(event) and _using_pad:
		_set_using_pad(false)
	if GamepadInput.handle_line_edit(event, get_viewport()):
		get_viewport().set_input_as_handled()


## Foco inicial do controle: as configurações (se abertas) ou o botão Jogar/Criar.
func focus_default() -> void:
	if is_instance_valid(_settings) and _settings.visible:
		var first: Control = GamepadInput.first_focusable(_settings)
		if first != null:
			first.grab_focus()
			return
	if is_instance_valid(_play) and _play.is_visible_in_tree():
		_play.grab_focus()


## Botão do controle que a interface não consumiu. true = usou.
func handle_pad_button(event: InputEvent) -> bool:
	var owner_c: Control = get_viewport().gui_get_focus_owner()
	if event.is_action_pressed(GamepadInput.ACTION_START):
		if is_instance_valid(_settings) and _settings.visible:
			_settings.close()
		request_play()
		return true
	if event.is_action_pressed(GamepadInput.ACTION_B):
		if is_instance_valid(_settings) and _settings.visible:
			_settings.close()
			focus_default()
			return true
		return false
	if owner_c == null or not owner_c.is_visible_in_tree():
		# Primeiro toque no controle sem foco: só acorda o foco (não age às cegas).
		if event is InputEventJoypadButton:
			focus_default()
			return true
		return false
	if event.is_action_pressed(GamepadInput.ACTION_LB) or event.is_action_pressed(GamepadInput.ACTION_RB):
		if is_slot_mode() or _tab_buttons.is_empty():
			return false
		var step: int = -1 if event.is_action_pressed(GamepadInput.ACTION_LB) else 1
		select_creation_tab(posmod(_current_tab + step, CREATION_TABS.size()))
		_tab_buttons[_current_tab].grab_focus()
		if _sound_ready:
			AudioDirector.play_sfx(&"equip")
		return true
	if event.is_action_pressed(GamepadInput.ACTION_Y) and not is_slot_mode():
		randomize_appearance()
		return true
	if event.is_action_pressed(GamepadInput.ACTION_LT) or event.is_action_pressed(GamepadInput.ACTION_RT):
		_rotate_preview(-1 if event.is_action_pressed(GamepadInput.ACTION_LT) else 1)
		return true
	return false
