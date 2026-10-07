extends SceneTree

func _init() -> void:
	var path := "res://assets/environment/painted/meshes/camp_tent_v2_a.res"
	var m := load(path) as Mesh
	print("Mesh: ", path, " surfaces: ", m.get_surface_count())
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		print("  surface ", i, ": ", mat)
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			print("    shader: ", sm.shader.resource_path if sm.shader else "null")
			for prop in ["albedo_tex", "tint", "triplanar", "tile_m", "uv_scale", "use_vertex_ao", "top_amount", "top_tex", "tex_noise", "detail"]:
				print("    ", prop, " = ", sm.get_shader_parameter(prop))
	quit(0)
