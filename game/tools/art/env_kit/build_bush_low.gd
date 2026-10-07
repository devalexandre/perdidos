extends SceneTree
## GDD §17.0.C (P2, 28/09/2026): malhas da "moita baixa" (nome lógico bush_low no KitCatalog).
## Reaproveitam modelos prontos do projeto (regra do dono: "o que der para pegar pronto, pegar e modificar"): as
## copas pintadas do kit (bush_round_a / bush_jungle_a: montes de folhas com normais esféricas e oclusão pintada na
## cor de vértice) e o arbusto CC0 do Quaternius (pk_bush_jungle = Bush_Common do Stylized Nature MegaKit) com materiais próprios: verde mais próximo do gramado (a moita não vira um
## "repolho" escuro colado no chão), vento suave e contínuo, variação por instância (MultiMesh). Os construtores
## achatam em Y e sobrepõem vários montes para formar massas cheias e baixas.
##   godot --headless --path game --script res://tools/art/env_kit/build_bush_low.gd

const DIR := "res://assets/environment/painted/meshes/"
const VARIANTS := {
	"bush_low_a": ["bush_round_a", Color(1.0, 1.1, 0.84), Color(1.0, 1.08, 0.86)],
	"bush_low_b": ["bush_jungle_a", Color(0.92, 1.06, 0.84), Color(0.95, 1.05, 0.86)],
	# Quaternius Stylized Nature MegaKit (CC0), Bush_Common com folhas de selva (pk_bush_jungle, build_pack_kit.gd).
	"bush_low_c": ["pk_bush_jungle", Color(0.95, 1.08, 0.86), Color(0.95, 1.08, 0.86)],
}


func _initialize() -> void:
	for out_name: String in VARIANTS:
		var spec: Array = VARIANTS[out_name]
		var src: ArrayMesh = load(DIR + String(spec[0]) + ".res") as ArrayMesh
		if src == null:
			push_error("sem malha " + String(spec[0]))
			quit(1)
			return
		var mesh := src.duplicate(true) as ArrayMesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if not m is ShaderMaterial:
				continue
			var nm := (m as ShaderMaterial).duplicate() as ShaderMaterial
			var alpha: bool = nm.get_shader_parameter(&"use_alpha") != false and nm.get_shader_parameter(&"alpha_cut") != null
			nm.set_shader_parameter(&"tint", spec[2] if alpha else spec[1])
			nm.set_shader_parameter(&"wind_strength", 0.03)
			nm.set_shader_parameter(&"wind_speed", 1.1)
			nm.set_shader_parameter(&"use_instance_custom", true)
			nm.set_shader_parameter(&"value_variation", 0.1)
			nm.set_shader_parameter(&"hue_variation", 0.08)
			mesh.surface_set_material(i, nm)
		var err := ResourceSaver.save(mesh, DIR + out_name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("bush_low: ", out_name, " err=", err, " surfaces=", mesh.get_surface_count())
	quit()
