class_name AuthGate
extends RefCounted
## Servidor com --require-auth: o cliente manda o JWT da API de contas no handshake
## (Net._srv_hello). Aqui conferimos o token e ligamos o nome do personagem à conta:
## o primeiro que entra com um nome é o dono dele; outra conta não pode usar esse nome.
##
## Segredo: $PERDIDOS_JWT_SECRET ou o arquivo secrets.env (padrão ~/.config/perdidos/secrets.env,
## o mesmo que a API cria). Nunca é impresso.
## Donos dos nomes: <pasta dos saves>/character_owners.json  {"nome_minúsculo": account_id}.

const Jwt: GDScript = preload("res://scripts/server/auth/jwt_hs256.gd")
const SECRET_KEY: String = "PERDIDOS_JWT_SECRET"
const OWNERS_FILE: String = "character_owners.json"
const MIN_SECRET_LENGTH: int = 32

## Motivos de recusa (vão ao cliente em Net._cli_rejected).
const REASON_OK: StringName = &""
const REASON_REQUIRED: StringName = &"auth_required"
const REASON_INVALID: StringName = &"auth_invalid"
const REASON_EXPIRED: StringName = &"auth_expired"
const REASON_NAME_OWNED: StringName = &"name_owned"
## A conta já usou todos os slots de personagem (Balance.cfg.characters_per_account).
const REASON_SLOT_FULL: StringName = &"slot_full"

var _secret: String = ""
var _owners_path: String = ""
var _owners: Dictionary = {}


## Lê o segredo; "" = não achou (o servidor não deve subir com --require-auth).
static func load_secret(secrets_path: String = "") -> String:
	var env: String = OS.get_environment(SECRET_KEY).strip_edges()
	if not env.is_empty():
		return env if env.length() >= MIN_SECRET_LENGTH else ""
	var path: String = secrets_path if not secrets_path.is_empty() else default_secrets_path()
	if not FileAccess.file_exists(path):
		return ""
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#") or not line.contains("="):
			continue
		var eq: int = line.find("=")
		if line.substr(0, eq).strip_edges() == SECRET_KEY:
			var v: String = line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
			return v if v.length() >= MIN_SECRET_LENGTH else ""
	return ""


static func default_secrets_path() -> String:
	var base: String = OS.get_environment("XDG_CONFIG_HOME")
	if OS.get_name() == "Windows":
		base = OS.get_environment("APPDATA")
	if base.is_empty():
		base = OS.get_environment("HOME").path_join(".config")
	return base.path_join("perdidos").path_join("secrets.env")


func _init(secret: String, save_dir: String) -> void:
	_secret = secret
	DirAccess.make_dir_recursive_absolute(save_dir)
	_owners_path = save_dir.path_join(OWNERS_FILE)
	if FileAccess.file_exists(_owners_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_owners_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			_owners = parsed
		else:
			push_error("Corrupted %s; refusing to overwrite it" % _owners_path)
			_owners_path = ""


## Confere token + dono do nome. Resultado: {"reason": StringName (vazio = ok), "account_id": int}.
## Quando ok e o nome ainda não tinha dono, ele passa a ser desta conta (gravado em disco).
func check(token: Variant, char_name: String) -> Dictionary:
	if typeof(token) != TYPE_STRING or str(token).is_empty():
		return {"reason": REASON_REQUIRED, "account_id": 0}
	var res: Dictionary = Jwt.verify(str(token), _secret, int(Time.get_unix_time_from_system()))
	if not res["ok"]:
		var reason: StringName = REASON_EXPIRED if res["error"] == Jwt.ERR_EXPIRED else REASON_INVALID
		return {"reason": reason, "account_id": 0}
	var account_id: int = int((res["claims"] as Dictionary)["account_id"])
	var key: String = char_name.to_lower()
	var owner: int = int(_owners.get(key, 0))
	if owner != 0 and owner != account_id:
		return {"reason": REASON_NAME_OWNED, "account_id": account_id}
	if owner == 0:
		if _owners_path.is_empty():
			return {"reason": REASON_INVALID, "account_id": account_id}
		# Nome novo: só se a conta ainda tem slot livre. "owned" = os personagens que ela já tem.
		var owned: Array[String] = names_of(account_id)
		if owned.size() >= maxi(1, Balance.cfg.characters_per_account):
			return {"reason": REASON_SLOT_FULL, "account_id": account_id, "owned": owned}
		_owners[key] = account_id
		_save_owners()
	return {"reason": REASON_OK, "account_id": account_id}


func owner_of(char_name: String) -> int:
	return int(_owners.get(char_name.to_lower(), 0))


## Personagens (nomes em minúsculas, como gravados) desta conta.
func names_of(account_id: int) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _owners:
		if int(_owners[k]) == account_id:
			out.append(str(k))
	out.sort()
	return out


## Grava num temporário e troca (não deixa o arquivo pela metade se o servidor cair).
func _save_owners() -> void:
	var tmp: String = _owners_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(_owners, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, _owners_path) != OK:
		push_error("Cannot replace %s" % _owners_path)
