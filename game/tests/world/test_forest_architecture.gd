extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _ready() -> void:
 for id: String in ['enchanted_forest','enchanted_forest_glade','enchanted_forest_roots','enchanted_forest_heart']:
  var map: GameMap = load('res://scenes/maps/'+id+'.tscn').instantiate()
  add_child(map)
  for i in range(60):
   await get_tree().physics_frame
   if WalkGrid.is_nav_synced(map.get_navigation_map()): break
  var grid: WalkGrid = WalkGrid.for_map(StringName(id),map,map.get_navigation_map())
  check(grid != null,id+' grid ready')
  if grid == null: continue
  check(MinimapData.build(StringName(id),map,grid).from_grid,id+' minimap faithful')
  for obj: Dictionary in map.get_interactables().values():
   var point: Vector3 = obj.meta[&'approach_position']
   check(grid.is_walkable(grid.world_to_cell(point)),id+' portal walkable')
   var path := NavigationServer3D.map_get_path(map.get_navigation_map(),map.get_spawn_point(),point,true)
   check(path.size()>1 and path[-1].distance_to(point)<.2,id+' portal connected')
  for pack: Node3D in map.get_node('Spawns').get_children():
   check(grid.is_walkable(grid.world_to_cell(pack.position)),id+' pack walkable')
  var plants := 0
  for decor in map.get_node('Decor').get_children():
   if decor is MultiMeshInstance3D: plants += decor.multimesh.instance_count
  check(plants>1000,id+' dense woodland')
  if id.ends_with('_roots'):
   check(map.has_node('Decor/GateLintel') and map.has_node('Decor/OpenGate1'),'open cave gate')
   for point in [Vector3(-12,0,4),Vector3(12,0,-10),Vector3(-4,0,20),map.get_node('CaveReturn').position]:
    check(grid.is_walkable(grid.world_to_cell(point)),'quest/return walkable')
  if '--shots' in OS.get_cmdline_user_args():
   var camera := Camera3D.new()
   map.add_child(camera)
   camera.position=Vector3(0,78,55)
   camera.look_at(Vector3.ZERO)
   camera.projection=Camera3D.PROJECTION_ORTHOGONAL
   camera.size=110
   camera.current=true
   await get_tree().process_frame
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png('/tmp/'+id+'.png')
   if id.ends_with('_roots'):
    camera.position=Vector3(24,20,46)
    camera.look_at(Vector3(24,1,25))
    camera.size=26
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png('/tmp/forest-cave-gate.png')
  map.queue_free()
  await get_tree().process_frame
 print('FOREST ARCHITECTURE: %d failures'%failures)
 get_tree().quit(0 if failures==0 else 1)
