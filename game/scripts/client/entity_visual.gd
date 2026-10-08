class_name EntityVisual
extends DirectionalSprite3D
## Visual de uma entidade de rede (jogador ou NPC): sprite direcional + nome sobre a cabeça +
## balão de emote + balão de chat + Area3D na camada 2 (meta target_id) para o clique.
## Criado por EntityVisualFactory.create(entity). A entidade repassa facing_yaw e anim a cada quadro
## e chama show_emote()/show_chat() quando os eventos chegam.

## Camada de colisão das coisas clicáveis (contrato: camada 2).
const PICK_LAYER: int = 1 << 1
const PICK_AREA_NAME: StringName = &"PickArea"
const META_TARGET_ID: StringName = &"target_id"
## Fração da largura do quadro ocupada pelo corpo (raio da área de clique).
const PICK_WIDTH_FRACTION: float = 0.35
## Fração da altura do quadro onde fica o topo da cabeça (personagem ~80 de 96 px).
const HEAD_HEIGHT_FRACTION: float = 0.85
## O nome fica acima do topo do quadro (sobra espaço para chapéus).
const NAMEPLATE_FRAME_FRACTION: float = 1.0
## Espaço (texels) entre topo da cabeça e o nome, e entre o nome e os balões.
const NAMEPLATE_GAP_TEXELS: float = 2.0
const BUBBLE_GAP_TEXELS: float = 12.0
const EMOTE_DURATION_SEC: float = 3.0
const CHAT_DURATION_SEC: float = 5.0
## Duração (s) do apagar/acender do NPC que some fora do horário (NpcDef.presence).
const PRESENCE_FADE_SEC: float = 1.6
## Largura máxima (texels) do texto do balão de chat antes de quebrar linha.
const CHAT_WRAP_TEXELS: float = 140.0
const CHAT_MAX_CHARS: int = 80
const BUBBLE_PADDING_TEXELS: int = 3
const BUBBLE_TAIL_TEXELS: int = 3
const BUBBLE_FILL: Color = Color8(252, 250, 245, 240)
const BUBBLE_BORDER: Color = Color8(22, 19, 28)
const BUBBLE_TEXT: Color = Color8(22, 19, 28)
const HOVER_TINT: Color = Color(1.25, 1.25, 1.25)
## Ordem de desenho (transparentes sem teste de profundidade): nome < balão < texto do balão.
const PRIORITY_NAME: int = 10
const PRIORITY_BUBBLE: int = 11
const PRIORITY_BUBBLE_TEXT: int = 12

# --- Aparência em camadas (ADENDO 1 do contrato) ---
const APPEARANCE_BODY: StringName = &"body"
const APPEARANCE_OUTFIT: StringName = &"outfit"
const APPEARANCE_HEAD: StringName = &"head"
const APPEARANCE_WEAPON: StringName = &"weapon"
const APPEARANCE_OFFHAND: StringName = &"offhand"
const DEFAULT_OUTFIT: StringName = &"traveler"
const BACK_SUFFIX: String = "_back"
## Ordem das camadas relativa ao corpo (GDD §17.4, ADENDO 2): offhand_back < weapon_back < corpo
## < olhos < cabelo < acessório de rosto < cabeça < weapon_front < offhand_front.
const ORDER_OFFHAND_BACK: int = -2
const ORDER_WEAPON_BACK: int = -1
const ORDER_EYES: int = CharacterLayers.ORDER_EYES
const ORDER_HAIR: int = CharacterLayers.ORDER_HAIR
const ORDER_FACE: int = CharacterLayers.ORDER_FACE
const ORDER_HEAD: int = 4
const ORDER_WEAPON_FRONT: int = 5
const ORDER_OFFHAND_FRONT: int = 6
## Personalização (ADENDO 2): com alguma destas chaves e a roupa do Viajante, o corpo vira o
## corpo-base recolorido + cabelo + acessório de rosto (CharacterLayers, Agente P).
const CUSTOM_KEYS: Array[StringName] = [&"skin", &"hair_style", &"hair_color", &"eye_color", &"earrings", &"nationality"]
const CUSTOM_LAYER_ORDER: Dictionary[StringName, int] = {
	CharacterLayers.LAYER_EYES: ORDER_EYES, CharacterLayers.LAYER_HAIR: ORDER_HAIR, CharacterLayers.LAYER_FACE: ORDER_FACE}
const LAYER_ANIMS: Array[StringName] = [ANIM_IDLE, ANIM_WALK, ANIM_SIT, ANIM_HIT, ANIM_ATTACK_UNARMED, ANIM_ATTACK_BLADE,
		ANIM_ATTACK_STAFF, ANIM_ATTACK_BOW, ANIM_CAST, ANIM_DEATH]
## Folhas de camada que sempre existem (as outras são opcionais: sem a folha, a camada some só nela).
const LAYER_REQUIRED_ANIMS: Array[StringName] = [ANIM_IDLE, ANIM_WALK]

## Pastas da arte de aparência (testes podem trocar).
static var outfit_dir: String = "res://assets/characters/outfits/"
static var equipment_dir: String = "res://assets/equipment/"

var appearance: Dictionary = {}
var target_id: String = ""
var display_name: String = ""
var is_npc: bool = false
var is_local: bool = false

var _nameplate: Label3D
var _emote_sprite: Sprite3D
var _chat_bg: Sprite3D
var _chat_label: Label3D
var _pick_area: Area3D
var _emote_left: float = 0.0
var _chat_left: float = 0.0
var _hovered: bool = false
## O balão atual é um emote sem imagem (texto).
var _emote_fallback: bool = false
## Piscar (camada de olhos, só no idle): folha do olho fechado e contadores.
var _blink_tex: Texture2D = null
var _blink_wait: float = 0.0
var _blink_left: float = 0.0
## Versão da escala de texel da tela já aplicada aos rótulos (DirectionalSprite3D._ui_version).
var _ui_seen: int = -1
var _follower: FollowerVisual
## NPC com rotina por horário (NpcDef.presence != ALWAYS): some e volta em PRESENCE_FADE_SEC.
var presence_def: NpcDef = null
var _mount_visual: MountedVisual


func _init() -> void:
	super._init()
	_nameplate = _make_label(UIKit.NAMEPLATE_FONT_SIZE, PRIORITY_NAME)
	_nameplate.name = &"Nameplate"
	add_child(_nameplate)

	_emote_sprite = Sprite3D.new()
	_emote_sprite.name = &"EmoteBubble"
	_emote_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emote_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_emote_sprite.shaded = false
	_emote_sprite.no_depth_test = true
	_emote_sprite.render_priority = PRIORITY_BUBBLE
	_emote_sprite.centered = true
	_emote_sprite.visible = false
	add_child(_emote_sprite)

	_chat_bg = Sprite3D.new()
	_chat_bg.name = &"ChatBubble"
	_chat_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_chat_bg.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_chat_bg.shaded = false
	_chat_bg.no_depth_test = true
	_chat_bg.render_priority = PRIORITY_BUBBLE
	_chat_bg.centered = true
	_chat_bg.visible = false
	add_child(_chat_bg)
	_chat_label = _make_label(UIKit.NAMEPLATE_FONT_SIZE, PRIORITY_BUBBLE_TEXT)
	_chat_label.name = &"ChatText"
	_chat_label.modulate = BUBBLE_TEXT
	_chat_label.outline_size = 0
	_chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_label.visible = false
	add_child(_chat_label)

	_pick_area = Area3D.new()
	_pick_area.name = PICK_AREA_NAME
	_pick_area.collision_layer = PICK_LAYER
	_pick_area.collision_mask = 0
	_pick_area.monitoring = false
	_pick_area.input_ray_pickable = false
	add_child(_pick_area)


## Configura identidade, nome e área de clique. sprite_base já deve ter sido carregado.
func setup_entity(p_target_id: String, p_display_name: String, p_is_npc: bool, p_is_local: bool) -> void:
	target_id = p_target_id
	is_npc = p_is_npc
	is_local = p_is_local
	_pick_area.set_meta(META_TARGET_ID, target_id)
	set_meta(META_TARGET_ID, target_id)
	set_display_name(p_display_name)
	_layout()


func set_display_name(text: String) -> void:
	display_name = text
	_nameplate.text = text
	refresh_party_color()
	_nameplate.visible = not text.is_empty()


## Cor do nome: NPC, o próprio jogador, membro do grupo (NetParty) ou outro jogador. O GameUI chama de novo
## quando o grupo muda.
func refresh_party_color() -> void:
	var color: Color = UIKit.COLOR_NAME_PLAYER
	if is_npc:
		color = UIKit.COLOR_NAME_NPC
	elif is_local:
		color = UIKit.COLOR_NAME_LOCAL
	elif not display_name.is_empty() and NetParty.is_member(display_name):
		color = UIKit.COLOR_NAME_PARTY
	_nameplate.modulate = color


## Monta o personagem em camadas a partir do appearance replicado:
## {body, outfit, head, weapon, offhand} → visual_id ou &"". Arquivo ausente = camada omitida.
func set_appearance(p_appearance: Dictionary) -> void:
	if p_appearance == appearance and not _textures.is_empty():
		return
	appearance = p_appearance.duplicate()
	var body: StringName = StringName(appearance.get(APPEARANCE_BODY, body_type))
	if body.is_empty():
		body = body_type
	body_type = body
	var outfit: StringName = StringName(appearance.get(APPEARANCE_OUTFIT, DEFAULT_OUTFIT))
	var outfit_base: String = outfit_sheet_base(body, outfit)
	if outfit != DEFAULT_OUTFIT and not ResourceLoader.exists(outfit_base + "_" + String(ANIM_IDLE) + ".png"):
		_warn_once("EntityVisual: roupa '%s' sem folhas em '%s', usando Viajante." % [outfit, outfit_base],
				outfit_base)
		outfit_base = outfit_sheet_base(body, DEFAULT_OUTFIT)
	var custom: Array[Dictionary] = _custom_layer_specs()
	# Corpo-base personalizado só com a roupa do Viajante (as folhas de roupa ainda são personagens
	# inteiros; com elas o cabelo/brinco personalizados vão por cima da folha da roupa).
	# C3: roupas do pipeline 3D trazem mascara -> também viram corpo recolorível (CharacterLayers.outfit_has_body).
	var custom_body: bool = not custom.is_empty() and (outfit == DEFAULT_OUTFIT or CharacterLayers.outfit_has_body(outfit, body))
	setup_sheets(String((custom[0][&"sheets"] as Dictionary)[ANIM_IDLE]).trim_suffix("_%s.png" % ANIM_IDLE)
			if custom_body else outfit_base)
	clear_overlays()
	_blink_tex = null
	if not custom.is_empty():
		_apply_custom_layers(custom, custom_body)
	var head: StringName = StringName(appearance.get(APPEARANCE_HEAD, &""))
	if not head.is_empty():
		add_overlay(&"Head", _overlay_paths(APPEARANCE_HEAD, head, body, ""), ORDER_HEAD)
	var weapon: StringName = StringName(appearance.get(APPEARANCE_WEAPON, &""))
	attack_style = weapon_attack_style(weapon)
	_add_held_layer(APPEARANCE_WEAPON, weapon, body, ORDER_WEAPON_BACK, ORDER_WEAPON_FRONT)
	_add_held_layer(APPEARANCE_OFFHAND, StringName(appearance.get(APPEARANCE_OFFHAND, &"")), body,
			ORDER_OFFHAND_BACK, ORDER_OFFHAND_FRONT)
	_update_followers()


## Camadas da personalização (CharacterLayers.layer_specs, corpo-base primeiro) ou [] se a
## aparência não tiver chaves do ADENDO 2, sem options.tres ou sem as folhas do corpo-base.
func _custom_layer_specs() -> Array[Dictionary]:
	if CustomizationOptions.get_default() == null:
		return []
	var has_custom: bool = false
	for k: StringName in CUSTOM_KEYS:
		has_custom = has_custom or appearance.has(k)
	var look: Dictionary = appearance
	if not has_custom:
		# roupa 3D (sem cabelo/olhos na folha) sem personalização: monta com a aparência padrão do corpo
		var outfit: StringName = StringName(str(appearance.get(APPEARANCE_OUTFIT, DEFAULT_OUTFIT)))
		if not CharacterLayers.outfit_has_body(outfit, body_type):
			return []
		look = CustomizationOptions.get_default().default_appearance(body_type).merged(appearance, true)
	var specs: Array[Dictionary] = CharacterLayers.layer_specs(look)
	if specs.is_empty() or specs[0][&"name"] != CharacterLayers.LAYER_BASE:
		return []
	for a: StringName in REQUIRED_ANIMS:
		if not (specs[0][&"sheets"] as Dictionary).has(a):
			return []
	return specs


## Troca de paleta no corpo-base (pele/olhos/raspado, com máscara) e no cabelo (rampa de cinza),
## pelo shader char_palette_swap_3d (CharacterLayers.make_material_3d); brinco sem troca de cor.
func _apply_custom_layers(specs: Array[Dictionary], custom_body: bool) -> void:
	for spec: Dictionary in specs:
		var layer: StringName = spec[&"name"]
		var mode: int = spec[&"mode"]
		match layer:
			CharacterLayers.LAYER_BASE:
				if custom_body:
					var masks: Dictionary[StringName, Texture2D] = {}
					var mask_paths: Dictionary = spec[&"masks"]
					for a: Variant in mask_paths:
						masks[StringName(a)] = load(mask_paths[a]) as Texture2D
					set_body_material(CharacterLayers.make_material_3d(mode, appearance), masks)
			CharacterLayers.LAYER_EYES:
				# Sobre folha de roupa (sem recolor da pele) a pele que cobre o olho antigo é a do Viajante.
				var look: Dictionary = appearance if custom_body else appearance.merged({&"skin": 0}, true)
				add_overlay(layer, spec[&"sheets"], ORDER_EYES, LayerRows.ALL, CharacterLayers.make_material_3d(mode, look))
				var bp: String = CharacterLayers.eyes_blink_path(body_type)
				_blink_tex = load(bp) as Texture2D if bp != "" else null
				_blink_wait = CharacterLayers.next_blink_wait()
			CharacterLayers.LAYER_HAIR, CharacterLayers.LAYER_FACE:
				var material: ShaderMaterial = CharacterLayers.make_material_3d(mode, appearance) \
						if mode != CharacterLayers.MODE_PLAIN else null
				add_overlay(layer, spec[&"sheets"], CUSTOM_LAYER_ORDER[layer], LayerRows.ALL, material)
	_layout()


## Estilo do golpe dos arcos (folha _attack_bow).
const ATTACK_STYLE_BOW: String = "bow"


## Estilo do golpe (GDD §10.2.1) pelo visual da arma: sem arma = &"unarmed" (soco/chute); com arma =
## o próprio visual_id (&"blade", &"staff"...) -> folha _attack_<visual_id> (resolve_anim cai para
## _attack / _attack_unarmed se ela não existir).
static func weapon_attack_style(weapon_visual: StringName) -> StringName:
	if weapon_visual.is_empty():
		return ATTACK_STYLE_UNARMED
	# Arcos (visual_id "simple_bow", "..._bow") usam o mesmo golpe: _attack_bow (Terra de Pindorama v0.4).
	if String(weapon_visual).ends_with(ATTACK_STYLE_BOW):
		return StringName(ATTACK_STYLE_BOW)
	return weapon_visual


## Base das folhas da roupa: traveler = folhas atuais do Viajante; outras em outfits/.
static func outfit_sheet_base(body: StringName, outfit: StringName) -> String:
	if outfit.is_empty() or outfit == DEFAULT_OUTFIT:
		return "%s%s%s" % [asset_dir, TRAVELER_PREFIX, body]
	return "%schr_%s_%s" % [outfit_dir, body, outfit]


## Arma/mão secundária: variante _back atrás do corpo nas linhas de costas (se não houver _back,
## a folha normal vai atrás), folha normal na frente nas demais.
func _add_held_layer(slot: StringName, visual_id: StringName, body: StringName, back_order: int,
		front_order: int) -> void:
	if visual_id.is_empty():
		return
	# todo arco ("simple_bow", "..._bow") usa a camada equipment/weapon/bow/ (tools/art/title_outfits/bow.py)
	if slot == APPEARANCE_WEAPON and weapon_attack_style(visual_id) == StringName(ATTACK_STYLE_BOW):
		visual_id = StringName(ATTACK_STYLE_BOW)
	var layer: String = String(slot).capitalize()
	var front_paths: Dictionary[StringName, String] = _overlay_paths(slot, visual_id, body, "")
	var back_paths: Dictionary[StringName, String] = _overlay_paths(slot, visual_id, body, BACK_SUFFIX)
	for anim_name: StringName in back_paths.keys():
		if not ResourceLoader.exists(back_paths[anim_name]):
			back_paths[anim_name] = front_paths[anim_name]
	add_overlay(StringName(layer + "Back"), back_paths, back_order, LayerRows.BACK_ONLY)
	add_overlay(StringName(layer + "Front"), front_paths, front_order, LayerRows.FRONT_ONLY)


func _overlay_paths(slot: StringName, visual_id: StringName, body: StringName,
		suffix: String) -> Dictionary[StringName, String]:
	var out: Dictionary[StringName, String] = {}
	for anim_name: StringName in LAYER_ANIMS:
		out[anim_name] = "%s%s/%s/%s_%s%s.png" % [equipment_dir, slot, visual_id, body, anim_name, suffix]
	# sit, golpes, cast e morte são opcionais: sem a folha, a camada some só nessa animação (sem aviso;
	# ex.: a arma só tem o golpe do próprio tipo e some na morte).
	for anim_name: StringName in LAYER_ANIMS:
		if not anim_name in LAYER_REQUIRED_ANIMS and not ResourceLoader.exists(out[anim_name]):
			out.erase(anim_name)
	return out


## Mostra o balão do emote por alguns segundos (imagem de C; sem ela, balão com o nome traduzido).
func show_emote(emote_id: StringName) -> void:
	var tex: Texture2D = UIKit.emote_texture(emote_id)
	if tex == null:
		_show_bubble(UIKit.emote_label(emote_id), EMOTE_DURATION_SEC)
		_emote_fallback = true
		return
	_hide_chat()
	_emote_sprite.texture = tex
	_emote_sprite.visible = true
	_emote_left = EMOTE_DURATION_SEC
	_layout()


## Mostra um balão de fala com o texto por alguns segundos.
func show_chat(text: String) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	if clean.length() > CHAT_MAX_CHARS:
		clean = clean.substr(0, CHAT_MAX_CHARS - 1) + "…"
	_show_bubble(clean, CHAT_DURATION_SEC)


func _show_bubble(text: String, duration: float) -> void:
	_emote_fallback = false
	_chat_label.text = text
	_apply_world_ui()
	var size: Vector2 = _measure(text)
	_chat_bg.texture = _bubble_texture(Vector2i(size.ceil()))
	_chat_bg.visible = true
	_chat_label.visible = true
	_chat_left = duration
	_emote_left = 0.0
	_emote_sprite.visible = false
	_layout()


## Destaque quando o cursor está sobre a entidade.
func set_hovered(value: bool) -> void:
	_hovered = value
	set_tint(HOVER_TINT if value else Color.WHITE)


func is_hovered() -> bool:
	return _hovered


func get_pick_area() -> Area3D:
	return _pick_area


func get_nameplate() -> Label3D:
	return _nameplate


func is_emote_visible() -> bool:
	return _emote_sprite.visible or (_emote_fallback and _chat_bg.visible)


func is_chat_visible() -> bool:
	return _chat_bg.visible


func setup_sheets(base: String) -> void:
	super.setup_sheets(base)
	_layout()


func _process(delta: float) -> void:
	super._process(delta)
	# Bandos não empilham dezenas de nomes. Chefes, raros e o alvo continuam identificados.
	var entity := get_parent() as NetEntity
	if entity != null and NetFollowers.is_revealed(entity.entity_id):
		set_tint(Color(1.25, 1.1, 0.7))
	elif not _hovered:
		set_tint(Color.WHITE)
	if entity != null and entity.kind == NetEntity.KIND_MONSTER:
		_nameplate.visible = not _nameplate.text.is_empty() and (_hovered \
				or NetCombat.client_attack_target == entity.entity_id \
				or entity.stage >= 3 or bool(entity.appearance.get("rare", false)))
	if _ui_seen != DirectionalSprite3D._ui_version:
		_layout()
	if _emote_left > 0.0:
		_emote_left -= delta
		if _emote_left <= 0.0:
			_emote_sprite.visible = false
	if _chat_left > 0.0:
		_chat_left -= delta
		if _chat_left <= 0.0:
			_hide_chat()
	_update_blink(delta)
	if presence_def != null:
		_update_presence(delta)


## NPC fora do horário: apaga em pontilhado (com nome e sombra) e deixa de ser clicável; volta igual.
func _update_presence(delta: float, instant: bool = false) -> void:
	var target: float = 1.0 if presence_def.is_present_now() else 0.0
	presence = target if instant else move_toward(presence, target, delta / PRESENCE_FADE_SEC)
	var shown: bool = presence > 0.001
	if visible != shown:
		visible = shown
	_nameplate.modulate.a = presence
	_pick_area.collision_layer = PICK_LAYER if presence >= 0.5 else 0


## Liga a rotina por horário (fábrica, NPC com NpcDef.presence) já no estado certo, sem animar.
func set_presence_def(def: NpcDef) -> void:
	presence_def = def if def != null and def.presence != NpcDef.Presence.ALWAYS else null
	if presence_def != null:
		_update_presence(0.0, true)


## Piscar: a cada poucos segundos, por CharacterLayers.BLINK_SEC, a camada de olhos do idle usa a folha
## do olho fechado (mesmos quadros). Roda depois de _update_overlays (super._process).
func _update_blink(delta: float) -> void:
	if _blink_tex == null:
		return
	if _blink_left > 0.0:
		_blink_left -= delta
	else:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_left = CharacterLayers.BLINK_SEC
			_blink_wait = CharacterLayers.next_blink_wait()
	if _blink_left <= 0.0 or _shown_anim() != CharacterLayers.BLINK_ANIM:
		return
	var eyes: Sprite3D = get_overlay_sprite(CharacterLayers.LAYER_EYES)
	if eyes == null or not eyes.visible:
		return
	eyes.texture = _blink_tex
	var mat: ShaderMaterial = eyes.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(SHADER_SHEET_PARAM, _blink_tex)


## Olho fechado agora (piscar)?
func is_blinking() -> bool:
	return _blink_tex != null and _blink_left > 0.0 and _shown_anim() == CharacterLayers.BLINK_ANIM


# --- Internos -------------------------------------------------------------------------------------

func _hide_chat() -> void:
	_chat_left = 0.0
	_emote_fallback = false
	_chat_bg.visible = false
	_chat_label.visible = false


## Rótulos e balões com 1 px de fonte = 1 px de tela no foco (escala de texel fracionária, GDD §17.0.C).
func _apply_world_ui() -> void:
	_ui_seen = DirectionalSprite3D._ui_version
	var text_px: float = DirectionalSprite3D.world_text_pixel_size()
	var fscale: float = DirectionalSprite3D.world_text_font_scale()
	for l: Label3D in [_nameplate, _chat_label]:
		l.pixel_size = text_px
		l.font_size = roundi(UIKit.NAMEPLATE_FONT_SIZE * fscale)
	_chat_label.width = CHAT_WRAP_TEXELS * fscale


## Posiciona nome e balões acima da cabeça e dimensiona a área de clique.
func _layout() -> void:
	_apply_world_ui()
	var texel: float = Balance.cfg.sprite_pixel_size
	var frame_h: int = get_frame_height()
	if frame_h <= 0:
		frame_h = Balance.cfg.character_frame_size
	var sprite_h: float = get_world_height() if get_frame_height() > 0 else frame_h * texel
	# Rótulos em billboard completo: px de fonte = px de tela no foco. Deslocamentos verticais no mundo são
	# encurtados pela inclinação da câmera: × _pitch_comp() para manter o espaçamento na tela.
	var text_px: float = DirectionalSprite3D.world_text_pixel_size()
	var img_px: float = DirectionalSprite3D.world_image_pixel_size()
	var up: float = _pitch_comp()
	var name_y: float = sprite_h * NAMEPLATE_FRAME_FRACTION + (NAMEPLATE_GAP_TEXELS * texel
			+ _nameplate.font_size * 0.5 * text_px) * up
	_nameplate.position = Vector3(0.0, name_y, 0.0)
	var bubble_base: float = name_y + (BUBBLE_GAP_TEXELS * texel) * up
	if _emote_sprite.texture != null:
		_emote_sprite.pixel_size = img_px
		_emote_sprite.position = Vector3(0.0, bubble_base + _emote_sprite.texture.get_height() * 0.5 * img_px * up, 0.0)
	if _chat_bg.texture != null:
		_chat_bg.pixel_size = text_px
		var bubble_h: float = _chat_bg.texture.get_height() * text_px * up
		# O rabinho fica embaixo: o centro do texto sobe metade do rabinho.
		var center_y: float = bubble_base + bubble_h * 0.5
		_chat_bg.position = Vector3(0.0, center_y, 0.0)
		_chat_label.position = Vector3(0.0, center_y + BUBBLE_TAIL_TEXELS * 0.5 * text_px * up, 0.0)
	_update_pick_shape(sprite_h, frame_h * texel)


func _update_pick_shape(height: float, width: float) -> void:
	var shape_node: CollisionShape3D = _pick_area.get_node_or_null(^"Shape") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = &"Shape"
		_pick_area.add_child(shape_node)
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(width * PICK_WIDTH_FRACTION, Balance.cfg.sprite_pixel_size)
	cyl.height = maxf(height * HEAD_HEIGHT_FRACTION, Balance.cfg.sprite_pixel_size)
	shape_node.shape = cyl
	shape_node.position = Vector3(0.0, cyl.height * 0.5, 0.0)


func _make_label(font_size: int, priority: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.pixel_size = Balance.cfg.sprite_pixel_size if Balance.cfg != null else 1.0 / 48.0
	l.font = UIKit.world_font()
	l.font_size = font_size
	l.outline_size = UIKit.OUTLINE_SIZE
	l.outline_modulate = UIKit.COLOR_OUTLINE
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.render_priority = priority
	l.outline_render_priority = priority - 1
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _measure(text: String) -> Vector2:
	var f: Font = _chat_label.font
	return f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, CHAT_WRAP_TEXELS,
			_chat_label.font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)


## Balão pixel-art com borda de 1 texel e rabinho, do tamanho exato do texto.
func _bubble_texture(text_size: Vector2i) -> Texture2D:
	var w: int = text_size.x + BUBBLE_PADDING_TEXELS * 2 + 2
	var body_h: int = text_size.y + BUBBLE_PADDING_TEXELS * 2 + 2
	var h: int = body_h + BUBBLE_TAIL_TEXELS
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y: int in body_h:
		for x: int in w:
			var corner: bool = (x == 0 or x == w - 1) and (y == 0 or y == body_h - 1)
			if corner:
				continue
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == body_h - 1
			img.set_pixel(x, y, BUBBLE_BORDER if edge else BUBBLE_FILL)
	# Rabinho em "V" centralizado.
	var cx: int = w / 2
	for i: int in BUBBLE_TAIL_TEXELS:
		var y: int = body_h - 1 + i
		var half: int = BUBBLE_TAIL_TEXELS - i
		for x: int in range(cx - half, cx + half + 1):
			var edge: bool = x == cx - half or x == cx + half
			img.set_pixel(x, y, BUBBLE_BORDER if edge else BUBBLE_FILL)
		img.set_pixel(cx, body_h - 1 + BUBBLE_TAIL_TEXELS, BUBBLE_BORDER)
	return ImageTexture.create_from_image(img)


func _shown_anim() -> StringName:
	if not String(appearance.get(&"mount", "")).is_empty() and anim != ANIM_DEATH and _textures.has(ANIM_SIT):
		return ANIM_SIT
	return super._shown_anim()

func _update_followers() -> void:
	if _follower != null:
		remove_child(_follower)
		_follower.queue_free()
		_follower = null
	if _mount_visual != null:
		remove_child(_mount_visual)
		_mount_visual.queue_free()
		_mount_visual = null
	_shadow.show()
	var companion: CompanionDef = Content.companion(StringName(str(appearance.get(&"companion", ""))))
	if companion != null:
		_follower = FollowerVisual.new()
		_follower.configure(self, companion, str(appearance.get(&"companion_name", "")),
				int(appearance.get(&"companion_level", 1)))
		add_child(_follower)
	var mount: MountDef = Content.mount(StringName(str(appearance.get(&"mount", ""))))
	if mount != null:
		_mount_visual = MountedVisual.new()
		_mount_visual.configure(self, mount)
		add_child(_mount_visual)
	_apply_anim_texture()
