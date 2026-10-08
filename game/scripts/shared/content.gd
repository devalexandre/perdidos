extends Node
## Autoload "Content": carrega todas as definições de data/ uma vez (servidor e cliente).

const DIRS: Dictionary[StringName, String] = {
	&"companions": "res://data/companions/", &"mounts": "res://data/mounts/",
	&"items": "res://data/items/", &"npcs": "res://data/npcs/", &"dialogues": "res://data/dialogues/",
	&"shops": "res://data/shops/", &"audio": "res://data/audio/",
	&"monsters": "res://data/monsters/", &"skills": "res://data/skills/", &"titles": "res://data/titles/",
	&"quests": "res://data/quests/", &"zones": "res://data/zones/",
	&"title_talks": "res://data/title_talks/", # Agente R (GDD §9.3)
	# Habilidades de monstro (Arco 1, luta do Boitatá): SkillDef fora de data/skills (não se aprende por quest).
	&"monster_skills": "res://data/monster_skills/",
	# Magias automáticas dos companheiros de título (PETS-E-MONTARIAS §0.1): fora das skills do jogador.
	&"companion_skills": "res://data/companion_skills/",
}

var _db: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	for kind: StringName in DIRS:
		_db[kind] = _load_dir(DIRS[kind])

func _load_dir(path: String) -> Dictionary:
	var out: Dictionary = {}
	# No PCK, DirAccess lista .tres.remap; ResourceLoader resolve os nomes
	# originais tanto no projeto quanto no cliente exportado.
	var files: PackedStringArray = ResourceLoader.list_directory(path)
	# APKs usam assets do Android, enquanto os clientes desktop usam PCK.
	# Aceita também a listagem física quando o backend não lista os nomes remapeados.
	for filename: String in DirAccess.get_files_at(path):
		var original: String = filename.trim_suffix(".remap")
		if original.ends_with(".tres") and original not in files:
			files.append(original)
	files.sort()
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var res: Resource = load(path + f)
		if res == null:
			push_error("Content: não foi possível carregar " + path + f)
			continue
		# ZoneDef não tem "id" (chave = map_id = nome do arquivo): get() devolve null.
		var idv: Variant = res.get("id") if res else null
		var key: StringName = StringName(idv) if idv != null and StringName(idv) != &"" else StringName(f.get_basename())
		out[key] = res
	if out.is_empty():
		push_error("Content: nenhuma definição carregada de " + path)
	return out

func item(id: StringName) -> ItemDef: return _db[&"items"].get(id)
func companion(id: StringName) -> CompanionDef: return _db[&"companions"].get(id)
func mount(id: StringName) -> MountDef: return _db[&"mounts"].get(id)
func npc(id: StringName) -> NpcDef: return _db[&"npcs"].get(id)
func dialogue(id: StringName) -> DialogueDef: return _db[&"dialogues"].get(id)
func shop(id: StringName) -> ShopDef: return _db[&"shops"].get(id)
func audio_zone(id: StringName) -> AudioZoneDef: return _db[&"audio"].get(id)
func monster(id: StringName) -> MonsterDef: return _db[&"monsters"].get(id)
func skill(id: StringName) -> SkillDef: return _db[&"skills"].get(id)
func monster_skill(id: StringName) -> SkillDef: return _db[&"monster_skills"].get(id)
func companion_skill(id: StringName) -> SkillDef: return _db[&"companion_skills"].get(id)
## Skill de jogador, de monstro ou de companheiro (efeitos e sons do cliente).
func any_skill(id: StringName) -> SkillDef:
	if _db[&"skills"].has(id):
		return skill(id)
	return monster_skill(id) if _db[&"monster_skills"].has(id) else companion_skill(id)
func title(id: StringName) -> TitleDef: return _db[&"titles"].get(id)
func quest(id: StringName) -> QuestDef: return _db[&"quests"].get(id)
func zone(map_id: StringName) -> ZoneDef: return _db[&"zones"].get(map_id)
func all(kind: StringName) -> Dictionary: return _db.get(kind, {})
