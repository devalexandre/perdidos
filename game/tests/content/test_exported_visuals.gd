extends SceneTree
## Run with the Godot editor binary and --script <absolute path>.
## Use --path game for sources, or --main-pack build/linux/Perdidos.x86_64 for the exported PCK.
## Kept outside the PCK by the tests/* export exclusion.

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var content: Node = root.get_node("Content")
	for category: StringName in content.DIRS:
		var entries: Dictionary = content.all(category)
		check(not entries.is_empty(), "Content category empty: " + category)
		print("Content %s: %d" % [category, entries.size()])
	var factory: Script = load("res://scripts/client/entity_visual_factory.gd")
	var entity_script: Script = load("res://scripts/shared/entities/net_entity.gd")
	for id: StringName in content.all(&"npcs"):
		var entity = entity_script.new()
		entity.kind = &"npc"
		entity.def_id = id
		var visual = factory.create(entity)
		entity._visual = visual
		var base: String = content.npc(id).resolved_sprite_base()
		check(visual.sprite_base == base, "NPC sheet: " + id)
		check(ResourceLoader.exists(base + "_idle.png"), "NPC idle: " + id)
		entity.appearance = {}
		check(visual.sprite_base == base, "NPC appearance update replaced sheet: " + id)
		visual.free()
		entity.free()
	for id: StringName in content.all(&"monsters"):
		for stage in content.monster(id).stages:
			var entity = entity_script.new()
			entity.kind = &"monster"
			entity.def_id = id
			entity.stage = stage.stage
			var visual = factory.create(entity)
			check(visual.sprite_base == stage.sprite_base, "Monster sheet: " + id)
			for animation: String in ["idle", "walk"]:
				var texture: Texture2D = load(stage.sprite_base + "_" + animation + ".png")
				check(texture != null and texture.get_width() > 0, "Monster texture: " + id + "/" + animation)
			visual.free()
			entity.free()
	print("Exported visuals: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
