class_name TitleTalk
extends RefCounted
## Agente R (GDD §9.3, 27/09/2026): no nível 10, cada Mestre ganha uma opção de conversa sobre o
## título que ensina. Dados: TitleTalkDef (data/title_talks/<npc_id>.tres). Usado pelo DialogueRunner:
##  - extend_dialogue: no primeiro nó do diálogo do Mestre acrescenta a opção OPTION_KEY com a
##    condição min_level (a mesma do DialogueRunner; escondida abaixo do nível);
##  - run: a opção (ação ACTION) mostra as falas geradas (page 1..3).
## Textos com argumentos: "CHAVE|arg|arg" (cada arg é traduzido; "A,B" vira "A, B" traduzidos) —
## o DialogueBox do cliente resolve (DialogueBox.resolve_text).

const ACTION: StringName = &"title_talk"
const ARG_PAGE: StringName = &"page"
const ARG_TALK: StringName = &"talk"
const OPTION_KEY: String = "RULES_TT_OPTION"
const PAGE_WHAT: int = 1
const PAGE_STYLE: int = 2
const PAGE_CITY: int = 3
const NODE_PREFIX: String = "title_talk_"
const SEP: String = "|"
const LIST_SEP: String = ","
const K_WHAT: String = "RULES_TT_WHAT"
const K_STYLE: String = "RULES_TT_STYLE"
const K_NO_SKILLS: String = "RULES_TT_NO_SKILLS"
const K_CITY_OPEN: String = "RULES_TT_CITY_OPEN"
const K_CITY_CLOSED: String = "RULES_TT_CITY_CLOSED"
const K_OPT_STYLE: String = "RULES_TT_OPT_STYLE"
const K_OPT_CITY: String = "RULES_TT_OPT_CITY"
const K_OPT_BACK: String = "RULES_TT_OPT_BACK"
const K_OPT_THANKS: String = "RULES_TT_OPT_THANKS"
const MAP_KEY_FORMAT: String = "MAP_%s"
const REGION_KEY_FORMAT: String = "REGION_%s_NAME"
const KIND: StringName = &"title_talks"


## TitleTalkDef do NPC (null = o NPC não fala de título).
static func def_for_npc(npc_id: StringName) -> TitleTalkDef:
	for v: Variant in Content.all(KIND).values():
		var t: TitleTalkDef = v as TitleTalkDef
		if t != null and t.npc_id == npc_id:
			return t
	return null


## Acrescenta a opção no primeiro nó (se o NPC tiver TitleTalkDef e a condição de nível passar).
static func extend_dialogue(runner: DialogueRunner, session: PlayerSession, node: DialogueNode,
		keys: Array[String]) -> void:
	if session.dialogue_def == null or node == null or node.id != session.dialogue_def.start_node:
		return
	var npc: NetEntity = runner.world.get_entity(session.dialogue_npc_id)
	if npc == null:
		return
	var t: TitleTalkDef = def_for_npc(npc.def_id)
	if t == null:
		return
	var opt: DialogueOption = _option(t, OPTION_KEY, PAGE_WHAT)
	if not runner.is_option_visible(session, opt):
		return
	# Antes do "tchau" do nó (opção com a ação close), se houver; senão no fim.
	var at: int = session.dialogue_options.size()
	for i: int in session.dialogue_options.size():
		if session.dialogue_options[i].action == DialogueRunner.ACTION_CLOSE:
			at = i
			break
	at = mini(at, keys.size())
	session.dialogue_options.insert(at, opt)
	keys.insert(at, opt.text_key)


## Opção escolhida (ação ACTION): mostra a fala da página pedida.
static func run(runner: DialogueRunner, session: PlayerSession, opt: DialogueOption) -> void:
	var t: TitleTalkDef = Content.all(KIND).get(StringName(str(opt.action_args.get(ARG_TALK, "")))) as TitleTalkDef
	if t == null:
		runner.close(session, true)
		return
	var page: int = int(opt.action_args.get(ARG_PAGE, PAGE_WHAT))
	Net.log_line("title_talk", {"peer": session.peer_id, "talk": String(t.id), "page": page})
	var start: StringName = session.dialogue_def.start_node if session.dialogue_def != null else &"start"
	runner.show_node(session, build_page(t, page, start))


## Monta a fala (nó gerado) de uma página.
static func build_page(t: TitleTalkDef, page: int, start_node: StringName = &"start") -> DialogueNode:
	var node := DialogueNode.new()
	node.id = StringName(NODE_PREFIX + str(page))
	var title: TitleDef = Content.title(t.title_id) if not t.title_id.is_empty() else null
	match page:
		PAGE_STYLE:
			var skills: PackedStringArray = skill_keys(t, title)
			node.text_key = SEP.join([K_STYLE, t.style_key,
					LIST_SEP.join(skills) if not skills.is_empty() else K_NO_SKILLS])
			node.options = [_option(t, K_OPT_CITY, PAGE_CITY), _close_option()]
		PAGE_CITY:
			if title != null and not title.start_map_id.is_empty():
				node.text_key = SEP.join([K_CITY_OPEN, MAP_KEY_FORMAT % String(title.start_map_id).to_upper()])
			else:
				node.text_key = SEP.join([K_CITY_CLOSED, REGION_KEY_FORMAT % String(t.region_id).to_upper()])
			var back := DialogueOption.new()
			back.text_key = K_OPT_BACK
			back.next_node = start_node
			node.options = [back, _close_option()]
		_:
			var name_key: String = title.name_key if title != null else t.title_name_key
			var desc_key: String = title.desc_key if title != null and not title.desc_key.is_empty() \
					else t.title_desc_key
			node.text_key = SEP.join([K_WHAT, name_key, desc_key])
			node.options = [_option(t, K_OPT_STYLE, PAGE_STYLE), _close_option()]
	return node


## Chaves dos nomes das skills que o título libera (TitleDef.required_skills → SkillDef.name_key).
static func skill_keys(t: TitleTalkDef, title: TitleDef) -> PackedStringArray:
	var out: PackedStringArray = []
	if title != null:
		for sid: StringName in title.required_skills:
			var sd: SkillDef = Content.skill(sid)
			if sd != null:
				out.append(sd.name_key)
	if out.is_empty():
		out.append_array(t.skill_name_keys)
	return out


static func _option(t: TitleTalkDef, key: String, page: int) -> DialogueOption:
	var o := DialogueOption.new()
	o.text_key = key
	o.action = ACTION
	o.action_args = {ARG_TALK: t.id, ARG_PAGE: page}
	o.conditions = {DialogueRunner.COND_MIN_LEVEL: t.min_level}
	return o


static func _close_option() -> DialogueOption:
	var o := DialogueOption.new()
	o.text_key = K_OPT_THANKS
	o.action = DialogueRunner.ACTION_CLOSE
	return o
