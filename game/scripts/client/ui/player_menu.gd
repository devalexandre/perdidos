class_name PlayerMenu
extends PanelContainer
## Menu de outro jogador (30/09/2026): abre ao clicar (esquerdo ou direito) num jogador no mundo, ou num
## membro no painel do grupo. Itens conforme o grupo do jogador local (NetParty.client_party):
##   - fora do grupo dele e (sem grupo ou sou o líder): "Convidar para o grupo";
##   - membro do meu grupo e sou o líder: "Passar a liderança" e "Expulsar do grupo";
##   - jogador no mundo (with_trade): "Propor troca".
## Fecha ao escolher, com Esc ou ao clicar fora.

signal invite_requested(player_name: String)
signal kick_requested(player_name: String)
signal make_leader_requested(player_name: String)
signal trade_requested(player_name: String)

const ITEM_INVITE: StringName = &"invite"
const ITEM_KICK: StringName = &"kick"
const ITEM_LEADER: StringName = &"leader"
## Troca entre personagens (sempre aparece para outro jogador; o servidor confere distância e combate).
const ITEM_TRADE: StringName = &"trade"

var ui_scale: float = 1.0
var target_name: String = ""
var title_label: Label
var items_box: VBoxContainer


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"PlayerMenu"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(4.0, ui_scale))
	add_child(box)
	title_label = Label.new()
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.add_theme_color_override(&"font_color", UIKit.c_title())
	title_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	box.add_child(title_label)
	items_box = VBoxContainer.new()
	items_box.add_theme_constant_override(&"separation", UIKit.px(3.0, ui_scale))
	box.add_child(items_box)


## Abre perto de screen_pos para o jogador `player_name`. local_name = jogador local; party = NetParty.client_party.
## Devolve os itens mostrados (vazio = não abriu).
func open_for(player_name: String, screen_pos: Vector2, local_name: String, party: Dictionary,
		with_trade: bool = false) -> Array[StringName]:
	target_name = player_name
	for c: Node in items_box.get_children():
		items_box.remove_child(c)
		c.queue_free()
	var items: Array[StringName] = []
	var in_party: bool = not party.is_empty()
	var am_leader: bool = in_party and str(party.get(NetParty.K_LEADER, "")).to_lower() == local_name.to_lower()
	var is_member: bool = false
	for m: Variant in party.get(NetParty.K_MEMBERS, []):
		if str((m as Dictionary).get(NetParty.K_NAME, "")).to_lower() == player_name.to_lower():
			is_member = true
	if player_name.is_empty() or player_name.to_lower() == local_name.to_lower():
		visible = false
		return items
	if not is_member and (not in_party or am_leader):
		items.append(ITEM_INVITE)
	if is_member and am_leader:
		items.append(ITEM_LEADER)
		items.append(ITEM_KICK)
	if with_trade:
		items.append(ITEM_TRADE)
	if items.is_empty():
		visible = false
		return items
	title_label.text = player_name
	for it: StringName in items:
		items_box.add_child(_item_button(it))
	visible = true
	reset_size()
	var screen: Vector2 = get_parent_area_size()
	position = Vector2(clampf(screen_pos.x, 0.0, maxf(0.0, screen.x - size.x)),
			clampf(screen_pos.y, 0.0, maxf(0.0, screen.y - size.y))).floor()
	move_to_front()
	return items


## Botão do item (testes apertam por aqui).
func button_for(item: StringName) -> Button:
	return items_box.get_node_or_null(NodePath(String(item))) as Button


func close() -> void:
	visible = false


func _item_button(item: StringName) -> Button:
	var b := Button.new()
	b.name = String(item)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	match item:
		ITEM_INVITE:
			b.text = tr("UI_PARTY_INVITE")
		ITEM_KICK:
			b.text = tr("UI_PARTY_KICK")
		ITEM_LEADER:
			b.text = tr("UI_PARTY_MAKE_LEADER")
		ITEM_TRADE:
			b.text = tr("UI_TRADE_PROPOSE")
	b.pressed.connect(_choose.bind(item))
	return b


func _choose(item: StringName) -> void:
	var who: String = target_name
	close()
	match item:
		ITEM_INVITE:
			invite_requested.emit(who)
		ITEM_KICK:
			kick_requested.emit(who)
		ITEM_LEADER:
			make_leader_requested.emit(who)
		ITEM_TRADE:
			trade_requested.emit(who)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and not get_global_rect().has_point((event as InputEventMouseButton).global_position):
		close()
