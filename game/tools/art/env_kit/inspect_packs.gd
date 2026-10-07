extends SceneTree
## Lista os modelos dos pacotes CC0 (tamanho AABB em m, superfícies, materiais/texturas) — referência para o kit.
##   godot --headless --path game --script res://tools/art/env_kit/inspect_packs.gd -- [pasta]
func _initialize() -> void:
	var dirs := ["res://assets/environment/packs/quaternius_nature", "res://assets/environment/packs/quaternius_village",
		"res://assets/environment/packs/quaternius_props", "res://assets/environment/packs/kenney_pirate"]
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		dirs = [args[0]]
	for d: String in dirs:
		for f: String in DirAccess.get_files_at(d):
			if not (f.ends_with(".gltf") or f.ends_with(".glb")):
				continue
			var ps := load(d + "/" + f) as PackedScene
			if ps == null:
				continue
			var n := ps.instantiate()
			var aabb := AABB()
			var first := true
			var info := []
			for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
				var m := (mi as MeshInstance3D).mesh
				var t: Transform3D = _xf(mi as Node3D, n)
				var box := t * m.get_aabb()
				aabb = box if first else aabb.merge(box)
				first = false
				for s in m.get_surface_count():
					var mat := m.surface_get_material(s)
					var tex := ""
					if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
						tex = (mat as BaseMaterial3D).albedo_texture.resource_path.get_file()
					info.append("%s[%s]" % [mat.resource_name if mat else "-", tex])
			print("%s/%s size=%s pos=%s mats=%s" % [d.get_file(), f, aabb.size.snapped(Vector3.ONE * 0.01), aabb.position.snapped(Vector3.ONE * 0.01), info])
			n.free()
	quit()


func _xf(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
