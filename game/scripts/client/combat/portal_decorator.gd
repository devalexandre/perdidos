class_name PortalDecorator
extends Node
## Procura os mapas carregados no cliente (/root/Main/World/Instances/<instância>/Map) de tempos em tempos e põe
## o PortalFx nos portais que ainda não têm. Criado pelo SkillFx (só existe no cliente). Barato: um mapa já
## decorado é marcado e não é varrido de novo.

const INSTANCES: NodePath = ^"/root/Main/World/Instances"
const MAP_NODE_NAME: String = "Map"
const META_DONE: StringName = &"portal_fx_done"
const SCAN_EVERY_SEC: float = 0.5

## Para testes: raiz alternativa com <instância>/Map.
var instances_root: Node = null
var portals_decorated: int = 0
var _left: float = 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = SCAN_EVERY_SEC
	scan()


func scan() -> void:
	var root: Node = instances_root if instances_root != null else get_node_or_null(INSTANCES)
	if root == null:
		return
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(MAP_NODE_NAME)
		if map == null or map.has_meta(META_DONE) or not map.is_node_ready():
			continue
		portals_decorated += PortalFx.decorate_map(map)
		map.set_meta(META_DONE, true)
