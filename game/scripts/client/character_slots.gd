class_name CharacterSlots
extends RefCounted
## Slots de personagem da conta neste aparelho (05/10/2026: 1 slot por conta). O personagem salvo é
## definitivo: a tela de título mostra o slot para JOGAR, sem editar. Quem manda é o servidor (dono do
## nome, aparência do save e Balance.cfg.characters_per_account); aqui fica só a lembrança local para
## a tela de seleção, atualizada com a aparência que o servidor replicou ao entrar no mundo.
##
## user://character_slots.cfg, uma seção por conta ("account_<id>" pelo JWT; "local" sem conta):
##   slot_<i> = {"name", "body", "appearance", "host", "port", "level"}

const PATH: String = "user://character_slots.cfg"
const LOCAL_ACCOUNT: String = "local"
const KEY_NAME: String = "name"
const KEY_BODY: String = "body"
const KEY_APPEARANCE: String = "appearance"
const KEY_HOST: String = "host"
const KEY_PORT: String = "port"
const KEY_LEVEL: String = "level"

## Caminho do arquivo (testes trocam por um temporário).
static var path: String = PATH


static func slot_count() -> int:
	return maxi(1, Balance.cfg.characters_per_account)


## Seção da conta atual: account_id do JWT do launcher/Android (sem verificar a assinatura; o
## servidor verifica), ou "local" sem conta.
static func account_key(token: String = "") -> String:
	var t: String = token if not token.is_empty() else str(Net.client_auth_token)
	var id: int = account_id_of(t)
	return "account_%d" % id if id > 0 else LOCAL_ACCOUNT


static func account_id_of(token: String) -> int:
	var parts: PackedStringArray = token.split(".")
	if parts.size() != 3:
		return 0
	var payload: String = parts[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var raw: PackedByteArray = Marshalls.base64_to_raw(payload)
	var claims: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(claims) != TYPE_DICTIONARY:
		return 0
	return int((claims as Dictionary).get("account_id", 0))


## Slots da conta, sempre com slot_count() posições ({} = vazio).
static func load_slots(account: String = "") -> Array[Dictionary]:
	var acc: String = account if not account.is_empty() else account_key()
	var cfg := ConfigFile.new()
	cfg.load(path)
	var out: Array[Dictionary] = []
	for i: int in slot_count():
		var v: Variant = cfg.get_value(acc, "slot_%d" % i, {})
		var d: Dictionary = v if v is Dictionary else {}
		out.append(d if not str(d.get(KEY_NAME, "")).strip_edges().is_empty() else {})
	return out


## Primeiro slot ocupado ({} = nenhum).
static func first_filled(account: String = "") -> Dictionary:
	for d: Dictionary in load_slots(account):
		if not d.is_empty():
			return d
	return {}


static func has_free_slot(account: String = "") -> bool:
	for d: Dictionary in load_slots(account):
		if d.is_empty():
			return true
	return false


## Grava o personagem no slot dele (mesmo nome, sem diferenciar maiúsculas) ou no primeiro livre.
## false = sem slot livre para um nome novo.
static func remember(data: Dictionary, account: String = "") -> bool:
	var acc: String = account if not account.is_empty() else account_key()
	var char_name: String = str(data.get(KEY_NAME, "")).strip_edges()
	if char_name.is_empty():
		return false
	var slots: Array[Dictionary] = load_slots(acc)
	var index: int = -1
	for i: int in slots.size():
		if not slots[i].is_empty() and str(slots[i][KEY_NAME]).to_lower() == char_name.to_lower():
			index = i
			break
	if index < 0:
		index = slots.find({})
	if index < 0:
		return false
	var merged: Dictionary = slots[index].duplicate()
	for k: Variant in data:
		var v: Variant = data[k]
		# Aparência/corpo vazios (ex.: só o nome veio do servidor) não apagam o que já se sabia.
		if (v is Dictionary and (v as Dictionary).is_empty()) or (v is String and (v as String).is_empty()):
			if merged.has(k):
				continue
		merged[k] = v
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(acc, "slot_%d" % index, merged)
	return cfg.save(path) == OK
