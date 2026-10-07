class_name MinimapData
extends RefCounted
## Dados do minimapa de um mapa (GDD §9.4), usados pelo Minimap e pelo WorldMap:
##   - imagem vista de cima: ZoneDef.minimap_texture + minimap_world_rect (arte de W); sem ela, uma
##     imagem gerada da WalkGrid (1 pixel por célula: andável, borda e bloqueado);
##   - ícones: Mestres e lojas (NpcDef do mapa, no marcador NpcPoints/<spawn_marker>) e portais
##     (Interactables com interact_type &"portal"). Meta opcional minimap_icon no nó sobrepõe.
## Coordenadas do mapa: x do mundo → direita, z do mundo → baixo (norte = -Z em cima).

enum Icon { NONE, MASTER, SHOP, PORTAL, QUEST }

const META_MINIMAP_ICON: StringName = &"minimap_icon"
const META_INTERACT_TYPE: StringName = &"interact_type"
const TYPE_PORTAL: StringName = &"portal"
const ICON_BY_NAME: Dictionary[StringName, Icon] = {
	&"master": Icon.MASTER, &"shop": Icon.SHOP, &"portal": Icon.PORTAL, &"none": Icon.NONE}
## NpcDef cujo id contém isto é Mestre (os Mestres de todas as nações usam "master" no id).
const MASTER_ID_TOKEN: String = "master"
const NPC_POINTS_NODE: String = "NpcPoints"
const INTERACTABLES_NODE: String = "Interactables"
# Cores da imagem gerada da grade (paleta da UI, UIKit).
const COLOR_WALKABLE: Color = UIKit.COLOR_TEXT_DIM
const COLOR_EDGE: Color = UIKit.COLOR_BUTTON
const COLOR_BLOCKED: Color = UIKit.COLOR_SLOT
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var map_id: StringName = &""
var zone: ZoneDef = null
var texture: Texture2D = null
## Retângulo do mundo (x, z mínimos e tamanho) coberto pela textura.
var world_rect: Rect2 = Rect2()
## Textura gerada da grade (sem arte de W).
var from_grid: bool = false
## [{icon: Icon, pos: Vector2 (x, z do mundo), key: String (nome traduzível)}]
var icons: Array[Dictionary] = []


## Monta os dados do mapa. grid pode ser null (ainda sem navmesh): sem arte, texture fica null.
static func build(p_map_id: StringName, map_node: Node, grid: WalkGrid) -> MinimapData:
	var d := MinimapData.new()
	d.map_id = p_map_id
	d.zone = Content.zone(p_map_id)
	if d.zone != null and d.zone.minimap_texture != null:
		d.texture = d.zone.minimap_texture
		d.world_rect = d.zone.minimap_world_rect
	elif grid != null:
		d.texture = ImageTexture.create_from_image(grid_image(grid))
		d.world_rect = Rect2(grid.origin, Vector2(grid.size) * grid.cell_size)
		d.from_grid = true
	if map_node != null:
		d._collect_icons(map_node)
	return d


## Imagem de 1 pixel por célula: andável claro, borda escura, bloqueado bem escuro.
static func grid_image(g: WalkGrid) -> Image:
	var img := Image.create(g.size.x, g.size.y, false, Image.FORMAT_RGBA8)
	for y: int in g.size.y:
		for x: int in g.size.x:
			var c := Vector2i(x, y)
			var color: Color = COLOR_BLOCKED
			if g.is_walkable(c):
				color = COLOR_WALKABLE
				for n: Vector2i in NEIGHBORS:
					if not g.is_walkable(c + n):
						color = COLOR_EDGE
						break
			img.set_pixel(x, y, color)
	return img


## Pixels de textura por unidade do mundo.
func texels_per_unit() -> float:
	if texture == null or world_rect.size.x <= 0.0:
		return 1.0
	return texture.get_width() / world_rect.size.x


## Posição (x, z do mundo) → pixel da textura.
func world_to_texel(p: Vector2) -> Vector2:
	if texture == null or world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return Vector2.ZERO
	return (p - world_rect.position) / world_rect.size * Vector2(texture.get_size())


func _collect_icons(map_node: Node) -> void:
	var points: Node = map_node.get_node_or_null(NPC_POINTS_NODE)
	if points != null:
		for def: Resource in Content.all(&"npcs").values():
			var npc: NpcDef = def as NpcDef
			if npc == null or npc.map_id != map_id:
				continue
			var marker: Node3D = points.get_node_or_null(String(npc.spawn_marker)) as Node3D
			if marker == null:
				continue
			var icon: Icon = _icon_override(marker, _npc_icon(npc))
			if icon != Icon.NONE:
				_add_icon(icon, marker, npc.name_key)
	var inter: Node = map_node.get_node_or_null(INTERACTABLES_NODE)
	if inter != null:
		for child: Node in inter.get_children():
			if not (child is Node3D):
				continue
			var auto: Icon = Icon.PORTAL if StringName(str(child.get_meta(META_INTERACT_TYPE, ""))) == TYPE_PORTAL \
					else Icon.NONE
			var icon: Icon = _icon_override(child, auto)
			if icon != Icon.NONE:
				_add_icon(icon, child as Node3D, "")


static func _npc_icon(npc: NpcDef) -> Icon:
	if npc.shop != null:
		return Icon.SHOP
	if String(npc.id).contains(MASTER_ID_TOKEN):
		return Icon.MASTER
	return Icon.NONE


static func _icon_override(node: Node, auto: Icon) -> Icon:
	if not node.has_meta(META_MINIMAP_ICON):
		return auto
	return ICON_BY_NAME.get(StringName(str(node.get_meta(META_MINIMAP_ICON))), auto)


func _add_icon(icon: Icon, node: Node3D, key: String) -> void:
	var p: Vector3 = node.global_position if node.is_inside_tree() else node.position
	icons.append({&"icon": icon, &"pos": Vector2(p.x, p.z), &"key": key})
