class_name ModerationStore
extends RefCounted
## Persistência da moderação (provisória, JSON; vai para o banco na Fase 2 junto com as contas):
##   <dir>/records/<conta>.json  — estado de sanção por CONTA (sobrevive à perda do personagem)
##   <dir>/log.jsonl             — log de moderação, uma ação por linha (só acrescenta)
##   <dir>/secret.key            — sal do hash das mensagens originais (nunca sai do servidor)
## O mesmo formato é lido/escrito por tools/moderation_review.py (revisão humana). O servidor
## relê o registro do disco se o arquivo mudou (a ferramenta pode ter decidido um caso).

const DEFAULT_DIR: String = "user://moderation/"
const AUTOTEST_DIR: String = "user://moderation_autotest/"
const RECORDS_SUBDIR: String = "records/"
const LOG_FILE: String = "log.jsonl"
const SECRET_FILE: String = "secret.key"
const EXT: String = ".json"
const SECRET_BYTES: int = 16

var dir: String = DEFAULT_DIR
var _secret: String = ""
## conta -> {"rec": ModerationRecord, "mtime": int}
var _cache: Dictionary[String, Dictionary] = {}


func _init(p_dir: String = DEFAULT_DIR, wipe: bool = false) -> void:
	dir = p_dir if p_dir.ends_with("/") else p_dir + "/"
	if wipe:
		_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir + RECORDS_SUBDIR)
	_secret = _load_or_create_secret()


func record_path(account: String) -> String:
	return dir + RECORDS_SUBDIR + account.to_lower().validate_filename() + EXT


func log_path() -> String:
	return dir + LOG_FILE


## Registro da conta (cria vazio se não existir). Relê do disco se o arquivo mudou.
func get_record(account: String) -> ModerationRecord:
	var key: String = account.to_lower()
	var path: String = record_path(key)
	var mtime: int = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
	var cached: Dictionary = _cache.get(key, {})
	if not cached.is_empty() and cached["mtime"] == mtime:
		return cached["rec"]
	var rec: ModerationRecord = null
	if mtime != 0:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			rec = ModerationRecord.from_dict(parsed)
		else:
			push_error("Corrupted moderation record: %s" % path)
	if rec == null:
		rec = ModerationRecord.new()
		rec.account = key
	_cache[key] = {"rec": rec, "mtime": mtime}
	return rec


func save_record(rec: ModerationRecord) -> bool:
	var path: String = record_path(rec.account)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write moderation record: %s" % tmp)
		return false
	f.store_string(JSON.stringify(rec.to_dict(), "\t"))
	f.close()
	var ok: bool = DirAccess.rename_absolute(tmp, path) == OK
	_cache[rec.account] = {"rec": rec, "mtime": FileAccess.get_modified_time(path)}
	return ok


## Todos os registros no disco (ferramentas e testes).
func all_records() -> Array[ModerationRecord]:
	var out: Array[ModerationRecord] = []
	for f: String in DirAccess.get_files_at(dir + RECORDS_SUBDIR):
		if f.ends_with(EXT):
			out.append(get_record(f.get_basename()))
	return out


func append_log(entry: Dictionary) -> void:
	var path: String = log_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path)
			else FileAccess.WRITE)
	if f == null:
		push_error("Cannot write moderation log: %s" % path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(entry))
	f.close()


func read_log() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(log_path()):
		return out
	for line: String in FileAccess.get_file_as_string(log_path()).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if typeof(d) == TYPE_DICTIONARY:
			out.append(d)
	return out


## Hash com sal da mensagem original: prova qual foi a mensagem (numa apelação) sem guardar o
## texto (LGPD: minimização).
func hash_message(text: String) -> String:
	return (_secret + text).sha256_text()


func _load_or_create_secret() -> String:
	var path: String = dir + SECRET_FILE
	if FileAccess.file_exists(path):
		var s: String = FileAccess.get_file_as_string(path).strip_edges()
		if not s.is_empty():
			return s
	var s2: String = Crypto.new().generate_random_bytes(SECRET_BYTES).hex_encode()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(s2)
		f.close()
	return s2


static func _wipe(p_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(p_dir):
		return
	for sub: String in DirAccess.get_directories_at(p_dir):
		_wipe(p_dir.path_join(sub))
	for f: String in DirAccess.get_files_at(p_dir):
		DirAccess.remove_absolute(p_dir.path_join(f))
	DirAccess.remove_absolute(p_dir)
