class_name JsonCharacterStore
extends CharacterStore
## CharacterStore provisório: um JSON por personagem em <dir>/<nome>.json
## (padrão user://server_saves/). Some na Fase 2 (banco).

const DEFAULT_DIR: String = "user://server_saves/"
const EXTENSION: String = ".json"
const JSON_INDENT: String = "\t"

var save_dir: String = DEFAULT_DIR


func _init(p_dir: String = DEFAULT_DIR) -> void:
	save_dir = p_dir if p_dir.ends_with("/") else p_dir + "/"
	DirAccess.make_dir_recursive_absolute(save_dir)


## Nome de arquivo seguro (nomes são únicos no servidor; comparação sem caixa).
func path_for(char_name: String) -> String:
	return save_dir + char_name.to_lower().validate_filename() + EXTENSION


func exists(char_name: String) -> bool:
	return FileAccess.file_exists(path_for(char_name))


func load_character(char_name: String) -> CharacterData:
	var path: String = path_for(char_name)
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupted character save: %s" % path)
		return null
	var character: CharacterData = CharacterData.from_save(parsed)
	if character != null and (character.starting_kit_migration_pending or character.legacy_ids_migration_pending) \
			and save_character(character):
		character.starting_kit_migration_pending = false
		character.legacy_ids_migration_pending = false
	return character


func save_character(data: CharacterData) -> bool:
	var path: String = path_for(data.char_name)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write character save: %s" % tmp)
		return false
	f.store_string(JSON.stringify(data.to_save(), JSON_INDENT))
	f.close()
	# Escreve num temporário e renomeia: não deixa arquivo pela metade se o servidor cair.
	return DirAccess.rename_absolute(tmp, path) == OK
