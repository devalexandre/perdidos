class_name CharacterData
extends RefCounted
## Estado persistente de um personagem no servidor (o que vai para o CharacterStore).
## Neste marco: aparência (corpo), nível, atributos base, vida/mana atuais, Estrelas,
## inventário (40), equipamento (7 + 3 cosméticos) e marcas "uma vez". Recargas ficam só em memória.

## GDD §11.3: inventário de 40 espaços.
const INVENTORY_SIZE: int = 40
## Contrato city-walk: personagem novo começa com 100 Estrelas e 2 poções de vida pequenas.
const STARTING_STARS: int = 100
## Kit inicial: 100 poções pequenas de vida e mana, mais 3 Pergaminhos de Retorno.
const STARTING_ITEMS: Dictionary[StringName, int] = {&"potion_hp_small": 100, &"potion_mp_small": 100,
		&"return_scroll": 3}
const STARTING_KIT_FLAG: String = "starting_kit_v2"
const DEV_ALEXANDRE_STARTING_POTIONS: int = 999
## 2 = atributos com Sorte (&"luk"); saves 1 sem ela recebem CharacterStats.BASE_ATTRIBUTE ao carregar.
const SAVE_FORMAT_VERSION: int = 3
var companions_owned: Array[StringName] = []
var companion_active: StringName = &""
var companion_names: Dictionary = {}
## Nível e XP de cada companheiro (PETS-E-MONTARIAS §0.1): String(id) -> {"level": int, "xp": int}.
## Saves antigos sem a chave começam no nível 1 com 0 de XP.
var companion_progress: Dictionary = {}
var mounts_owned: Array[StringName] = []
## Causos = renome/fama pelos feitos (pontos). Limiares das molduras narrativas, em ordem de progressão.
## O renome libera itens nas lojas (ShopDef.causos_rank_N_items) e sub-histórias de título
## (QuestDef.required_causos).
const CAUSOS_THRESHOLDS: Array[int] = [0, 2, 5, 10, 18, 30]
## Pontos de Causo por feito. História (arco) concluída vale mais que um título ou um chefe.
const CAUSO_POINTS_STORY: int = 3
const CAUSO_POINTS_TITLE: int = 1
## Primeira vitória sobre o chefe (estágio 3) / a forma atroz de cada espécie, com nível acima do personagem.
const CAUSO_POINTS_BOSS: int = 1
const CAUSO_POINTS_ATROZ: int = 2
## Marca da migração dos saves antigos (Causo = 1 por história) para a escala de renome.
const CAUSOS_FAME_FLAG: String = "causos_fame_v1"
const CAUSO_STORY_PREFIX: String = "causo_story:"
const CAUSO_DEED_PREFIX: String = "causo_deed:"
const CAUSOS_RANK_KEYS: Array[String] = [
	"CAUSOS_FORASTEIRO", "CAUSOS_FALADO", "CAUSOS_ASSUNTO_DA_VILA",
	"CAUSOS_CAUSO_DE_FOGUEIRA", "CAUSOS_LENDA", "CAUSOS_MITO",
]

static func is_dev_alexandre_name(p_name: String) -> bool:
	return p_name.strip_edges().to_lower() == "devalexandre"

func _apply_dev_alexandre_inventory_bonus() -> void:
	if not is_dev_alexandre_name(char_name):
		return
	for item_id: StringName in [&"potion_hp_small", &"potion_mp_small"]:
		var current_qty: int = inventory.count(item_id)
		if current_qty == DEV_ALEXANDRE_STARTING_POTIONS:
			continue
		if current_qty < DEV_ALEXANDRE_STARTING_POTIONS:
			inventory.add(item_id, DEV_ALEXANDRE_STARTING_POTIONS - current_qty)
			continue
		var left: int = current_qty - DEV_ALEXANDRE_STARTING_POTIONS
		for slot: int in range(inventory.size()):
			if left <= 0:
				break
			var stack: ItemStack = inventory.get_slot(slot)
			if stack == null or stack.item_id != item_id:
				continue
			var remove_qty: int = mini(stack.qty, left)
			stack.qty -= remove_qty
			left -= remove_qty
			if stack.qty == 0:
				inventory.replace_at(slot, null)

func _apply_dev_alexandre_starting_gear() -> void:
	if not is_dev_alexandre_name(char_name):
		return
	var starting_gear: Dictionary[StringName, StringName] = {
		&"weapon": &"machete",
		&"offhand": &"leather_shield",
		&"head": &"straw_hat",
		&"body": &"leather_jerkin",
		&"feet": &"walking_boots",
	}
	for slot: StringName in starting_gear:
		if equipment.get_slot(slot) == null:
			equipment.set_slot(slot, ItemStack.create(starting_gear[slot], 1))

var char_name: String = ""
var body_type: StringName = &"male"
var level: int = CharacterStats.START_LEVEL
var base_attributes: Dictionary[StringName, int] = CharacterStats.base_attributes()
var hp: int = 0
var mp: int = 0
var stars: int = 0
## Histórias marcantes concluídas (cada story_id concede no máximo 1 Causo).
var causos: int = 0
var inventory: Inventory = Inventory.new(INVENTORY_SIZE)
## Última consume_ammo puxou uma pilha nova deste item do inventário (&"" = não). Só memória.
var ammo_refilled: StringName = &""

var equipment: Equipment = Equipment.new()
## Marcas "só uma vez por personagem" (ex.: give_item com once = true). Persistidas.
var once_flags: Dictionary[String, bool] = {}
## Migração pendente do kit; o store limpa esta marca depois de gravar o save alterado.
var starting_kit_migration_pending: bool = false
## true quando o save veio com ids antigos (LegacyIds, renomeação da nação para Pindorama): o store regrava já no formato novo.
var legacy_ids_migration_pending: bool = false
## Fluxo (Agente N, GDD §9.3): já saiu do Campo de Treino? e cidade de origem (start_map_id do título
## inicial). Saves antigos sem a chave "left_training" = já saíram (entram direto na cidade).
var left_training: bool = false
var home_map: StringName = &""
## Última cidade (ZoneDef.Kind.CITY) em que o personagem entrou: destino do Pergaminho de Retorno (30/09/2026).
## &"" = nenhuma ainda (o pergaminho leva à cidade inicial). Save: "last_city".
var last_city: StringName = &""
## Personalização da criação (ADENDO 2: skin, hair_style, hair_color, eye_color, earrings). Validada
## pelo servidor na criação (CustomizationOptions) e fixa depois. {} = padrão (Viajante atual).
var custom_appearance: Dictionary = {}
## cooldown_group -> Time.get_ticks_msec() em que libera (só memória).
var cooldown_until_msec: Dictionary[StringName, int] = {}
## Progressão (Agente Q): XP, pontos, skills, barra 1–0, títulos e quests. Save: chave "progression".
var progression: ProgressionData = ProgressionData.new()


static func create_new(p_name: String, p_body: StringName) -> CharacterData:
	var c := CharacterData.new()
	c.char_name = p_name
	c.body_type = p_body
	c.stars = STARTING_STARS
	var starting_items: Dictionary[StringName, int] = STARTING_ITEMS.duplicate()
	if is_dev_alexandre_name(p_name):
		starting_items[&"potion_hp_small"] = DEV_ALEXANDRE_STARTING_POTIONS
		starting_items[&"potion_mp_small"] = DEV_ALEXANDRE_STARTING_POTIONS
	for item_id: StringName in starting_items:
		if Content.item(item_id) == null:
			push_warning("Starting item missing from data: %s" % item_id)
			continue
		c.inventory.add(item_id, starting_items[item_id])
	c.once_flags[STARTING_KIT_FLAG] = true
	c.once_flags[CAUSOS_FAME_FLAG] = true
	c._apply_dev_alexandre_inventory_bonus()
	c._apply_dev_alexandre_starting_gear()
	var s: Dictionary = c.compute_stats()
	c.hp = s[CharacterStats.K_MAX_HP]
	c.mp = s[CharacterStats.K_MAX_MP]
	return c


## Atributos derivados atuais (sem hp/mp atuais).
func compute_stats() -> Dictionary:
	var title_id: StringName = progression.displayed_title if progression != null else &""
	return CharacterStats.compute(level, base_attributes, equipment, title_id)


## Recalcula e prende hp/mp ao máximo. Devolve o dicionário completo do contrato (stats_changed).
func refresh_stats() -> Dictionary:
	var s: Dictionary = compute_stats()
	hp = clampi(hp, 0, s[CharacterStats.K_MAX_HP])
	mp = clampi(mp, 0, s[CharacterStats.K_MAX_MP])
	s[CharacterStats.K_HP] = hp
	s[CharacterStats.K_MP] = mp
	return s


## Gasta munição equipada. Se a pilha acabar, puxa a próxima pilha do MESMO tipo do inventário para o
## espaço da munição (o jogador não precisa reequipar no meio da caça). ammo_refilled = puxou agora.
func consume_ammo(amount: int = 1) -> bool:
	ammo_refilled = &""
	var st: ItemStack = equipment.get_ammo()
	if st == null:
		return false
	var ammo_id: StringName = st.item_id
	if not equipment.consume_ammo(amount):
		return false
	if equipment.get_ammo() == null:
		for slot: int in inventory.size():
			var next: ItemStack = inventory.get_slot(slot)
			if next != null and next.item_id == ammo_id:
				inventory.replace_at(slot, null)
				equipment.set_slot(Equipment.OFFHAND, next)
				ammo_refilled = ammo_id
				break
	return true


## História marcante concluída: CAUSO_POINTS_STORY uma única vez por story_id.
func grant_causo(story_id: StringName) -> bool:
	if story_id.is_empty():
		return false
	var flag := CAUSO_STORY_PREFIX + String(story_id)
	if once_flags.has(flag):
		return false
	once_flags[flag] = true
	causos += CAUSO_POINTS_STORY
	return true


## Feito que corre de boca em boca (título conquistado, chefe ou atroz acima do nível): soma `points`
## uma única vez por deed_id. false = feito já contado.
func grant_deed(deed_id: String, points: int) -> bool:
	if deed_id.is_empty() or points <= 0:
		return false
	var flag := CAUSO_DEED_PREFIX + deed_id
	if once_flags.has(flag):
		return false
	once_flags[flag] = true
	causos += points
	return true


## Pontos que faltam para o próximo renome (0 = já no topo).
static func causos_to_next(points: int) -> int:
	var rank: int = causos_rank_index(points)
	if rank + 1 >= CAUSOS_THRESHOLDS.size():
		return 0
	return CAUSOS_THRESHOLDS[rank + 1] - points


## Saves de antes do renome: 1 Causo por história vira CAUSO_POINTS_STORY, e cada título já conquistado
## (fora o de chegada) conta como feito.
func _migrate_causos_fame() -> void:
	if once_flags.has(CAUSOS_FAME_FLAG):
		return
	once_flags[CAUSOS_FAME_FLAG] = true
	var stories: int = 0
	for flag: String in once_flags:
		if flag.begins_with(CAUSO_STORY_PREFIX):
			stories += 1
	causos = maxi(causos, stories * CAUSO_POINTS_STORY)
	for title_id: StringName in progression.titles:
		var def: TitleDef = Content.title(title_id) if Content != null else null
		if def != null and def.tier > TitleService.ARRIVAL_TIER:
			grant_deed("title:%s" % title_id, CAUSO_POINTS_TITLE)


## Registra uma pista oral da história, distinta do Causo concedido ao concluir o arco.
func record_story_clue(story_id: StringName, clue_id: StringName) -> bool:
	if story_id.is_empty() or clue_id.is_empty():
		return false
	var flag := "story_clue:%s:%s" % [story_id, clue_id]
	if once_flags.has(flag):
		return false
	once_flags[flag] = true
	return true


func story_clue_count(story_id: StringName) -> int:
	if story_id.is_empty():
		return 0
	var prefix := "story_clue:%s:" % story_id
	var count := 0
	for flag: String in once_flags:
		if flag.begins_with(prefix):
			count += 1
	return count


func story_route(story_id: StringName) -> StringName:
	var prefix := "story_route:%s:" % story_id
	for flag: String in once_flags:
		if flag.begins_with(prefix):
			return StringName(flag.trim_prefix(prefix))
	return &""


func story_route_locked(story_id: StringName) -> bool:
	return once_flags.has("story_route_locked:%s" % story_id)


func story_arc_completed(story_id: StringName) -> bool:
	return once_flags.has("story_arc_completed:%s" % story_id)


func complete_story_arc(story_id: StringName, ending_id: StringName = &"") -> void:
	if story_id.is_empty():
		return
	once_flags["story_arc_completed:%s" % story_id] = true
	once_flags["story_route_locked:%s" % story_id] = true
	if not ending_id.is_empty():
		once_flags["story_arc_ending:%s:%s" % [story_id, ending_id]] = true


func story_arc_ending(story_id: StringName) -> StringName:
	var prefix := "story_arc_ending:%s:" % story_id
	for flag: String in once_flags:
		if flag.begins_with(prefix):
			return StringName(flag.trim_prefix(prefix))
	return &""


## A rota pode mudar até a segunda observação do Pacto; depois disso A/B ficam fechadas.
func choose_story_route(story_id: StringName, route_id: StringName) -> bool:
	if story_id.is_empty() or route_id not in [&"hunter", &"healer", &"pact"] \
			or story_clue_count(story_id) < 3 or story_arc_completed(story_id):
		return false
	var current: StringName = story_route(story_id)
	if story_route_locked(story_id) and current != route_id:
		return false
	for flag: String in once_flags.keys():
		if flag.begins_with("story_route:%s:" % story_id):
			once_flags.erase(flag)
	once_flags["story_route:%s:%s" % [story_id, route_id]] = true
	return true


## night_id deve identificar uma noite real e é usado para não contar duas observações na mesma noite.
func record_story_observation(story_id: StringName, night_id: String) -> int:
	if story_route(story_id) != &"pact" or night_id.is_empty() or story_arc_completed(story_id):
		return story_observation_count(story_id)
	if story_observation_count(story_id) >= 3:
		return 3
	var flag := "story_observation:%s:%s" % [story_id, night_id]
	if once_flags.has(flag):
		return story_observation_count(story_id)
	once_flags[flag] = true
	var count: int = story_observation_count(story_id)
	if count >= 2:
		once_flags["story_route_locked:%s" % story_id] = true
	return count


func has_story_observation(story_id: StringName, night_id: String) -> bool:
	return not night_id.is_empty() and once_flags.has("story_observation:%s:%s" % [story_id, night_id])


func story_observation_count(story_id: StringName) -> int:
	var prefix := "story_observation:%s:" % story_id
	var count := 0
	for flag: String in once_flags:
		if flag.begins_with(prefix):
			count += 1
	return count


static func causos_rank_index(points: int) -> int:
	var rank := 0
	for i in range(1, CAUSOS_THRESHOLDS.size()):
		if points < CAUSOS_THRESHOLDS[i]:
			break
		rank = i
	return rank


func to_save() -> Dictionary:
	var attrs: Dictionary = {}
	for a: StringName in base_attributes:
		attrs[String(a)] = base_attributes[a]
	return {
		"format": SAVE_FORMAT_VERSION,
		"companions": {"owned": Array(companions_owned), "active": String(companion_active), "names": companion_names.duplicate(),
				"progress": companion_progress.duplicate(true)},
		"mounts": {"owned": Array(mounts_owned)},
		"name": char_name,
		"body": String(body_type),
		"level": level,
		"attributes": attrs,
		"hp": hp,
		"mp": mp,
		"stars": stars,
		"causos": causos,
		"inventory": inventory.to_save(),
		"equipment": equipment.to_save(),
		"once_flags": once_flags.keys(),
		"left_training": left_training,
		"home_map": String(home_map),
		"last_city": String(last_city),
		"appearance": _appearance_to_save(),
		"progression": progression.to_save(),
	}


## Aparência replicada (NetEntity.appearance): equipamento (ADENDO 1) + personalização (ADENDO 2).
func full_appearance() -> Dictionary:
	var title: TitleDef = Content.title(progression.displayed_title)
	var title_outfit: StringName = title.outfit_id if title != null and progression.has_title(title.id) else &""
	if title_outfit.is_empty():
		title_outfit = nationality_outfit()
	var out: Dictionary = equipment.get_appearance(body_type, title_outfit)
	if title != null and progression.has_title(title.id) and not title.cloth_colors.is_empty():
		out[APP_TITLE_LOOK] = title.id
	for k: Variant in custom_appearance:
		if not out.has(k):
			out[k] = custom_appearance[k]
	return out


## Chave replicada com o título exibido que tem roupa própria (recolor; CharacterLayers.cloth_for).
const APP_TITLE_LOOK: StringName = &"title_look"


## Roupa-base de estudante da nacionalidade escolhida na criação (&"" = Viajante).
func nationality_outfit() -> StringName:
	var opts: CustomizationOptions = CustomizationOptions.get_default()
	if opts == null:
		return &""
	return opts.nationality_outfit(StringName(str(custom_appearance.get(CustomizationOptions.KEY_NATIONALITY, ""))))


func _appearance_to_save() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in custom_appearance:
		var v: Variant = custom_appearance[k]
		out[str(k)] = String(v) if v is StringName else v
	return out


## null se o formato for inválido.
static func from_save(d: Dictionary) -> CharacterData:
	if typeof(d.get("name")) != TYPE_STRING:
		return null
	# Ids renomeados (mapa, nação, títulos, quests, itens, companheiros...): tabela única em LegacyIds.
	var migrated: Dictionary = LegacyIds.migrate(d)
	var had_legacy_ids: bool = migrated != d
	d = migrated
	var c := CharacterData.new()
	c.legacy_ids_migration_pending = had_legacy_ids
	c.char_name = d["name"]
	c.body_type = StringName(str(d.get("body", "male")))
	c.level = maxi(int(d.get("level", CharacterStats.START_LEVEL)), CharacterStats.START_LEVEL)
	var attrs: Variant = d.get("attributes", {})
	if typeof(attrs) == TYPE_DICTIONARY:
		for a: StringName in CharacterStats.ATTRIBUTES:
			c.base_attributes[a] = int((attrs as Dictionary).get(String(a), CharacterStats.BASE_ATTRIBUTE))
	c.stars = maxi(int(d.get("stars", 0)), 0)
	c.causos = maxi(int(d.get("causos", 0)), 0)
	var inv: Variant = d.get("inventory", [])
	if typeof(inv) == TYPE_ARRAY:
		c.inventory.load_save(inv)
	c._apply_dev_alexandre_inventory_bonus()
	var eq: Variant = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		c.equipment.load_save(eq)
	c._apply_dev_alexandre_starting_gear()
	var flags: Variant = d.get("once_flags", [])
	if typeof(flags) == TYPE_ARRAY:
		for f: Variant in flags:
			c.once_flags[str(f)] = true
	if not c.once_flags.has(STARTING_KIT_FLAG):
		var complete: bool = true
		for item_id: StringName in STARTING_ITEMS:
			var missing: int = maxi(STARTING_ITEMS[item_id] - c.inventory.count(item_id), 0)
			if missing > 0 and not c.inventory.add(item_id, missing):
				complete = false
		if complete:
			c.once_flags[STARTING_KIT_FLAG] = true
			c.starting_kit_migration_pending = true
	c.left_training = bool(d.get("left_training", true))
	c.home_map = StringName(str(d.get("home_map", "")))
	c.last_city = StringName(str(d.get("last_city", "")))
	var app: Variant = d.get("appearance", {})
	if typeof(app) == TYPE_DICTIONARY:
		for k: Variant in app:
			var v: Variant = (app as Dictionary)[k]
			c.custom_appearance[StringName(str(k))] = StringName(v) if v is String else (int(v) if v is float else v)
	c.progression.load_save(d.get("progression", {}))
	var companions: Variant = d.get("companions", {})
	if companions is Dictionary:
		var owned: Variant = companions.get("owned", [])
		if owned is Array:
			for value: Variant in owned:
				var id := StringName(str(value))
				if Content.companion(id) != null and id not in c.companions_owned:
					c.companions_owned.append(id)
		var active := StringName(str(companions.get("active", "")))
		if active in c.companions_owned:
			c.companion_active = active
		var names: Variant = companions.get("names", {})
		if names is Dictionary:
			for id: Variant in names:
				if Content.companion(StringName(str(id))) != null and names[id] is String:
					c.companion_names[str(id)] = str(names[id]).substr(0, 12)
		var progress: Variant = companions.get("progress", {})
		if progress is Dictionary:
			for id: Variant in progress:
				var entry: Variant = progress[id]
				if Content.companion(StringName(str(id))) != null and entry is Dictionary:
					c.companion_progress[str(id)] = {
						"level": clampi(int(entry.get("level", 1)), 1, Balance.cfg.companion_max_level),
						"xp": maxi(0, int(entry.get("xp", 0)))}
	var mounts: Variant = d.get("mounts", {})
	if mounts is Dictionary and mounts.get("owned", []) is Array:
		for value: Variant in mounts.get("owned", []):
			var id := StringName(str(value))
			if Content.mount(id) != null and id not in c.mounts_owned:
				c.mounts_owned.append(id)
	c._migrate_causos_fame()
	c.hp = int(d.get("hp", 0))
	c.mp = int(d.get("mp", 0))
	c.refresh_stats()
	return c
