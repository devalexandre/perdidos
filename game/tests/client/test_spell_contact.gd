extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var saved: int = EnvQuality.current
	var script: Script = load("res://scripts/client/combat/spell_contact_flash.gd")
	EnvQuality.current = EnvQuality.Preset.ALTA
	var effects: Array[Node3D] = []
	var lights: int = 0
	for i: int in 7:
		var effect: Node3D = script.new()
		root.add_child(effect)
		effect.set_process(false)
		effects.append(effect)
		var light: OmniLight3D = effect.get(&"_light")
		if light != null:
			lights += 1
			check(not light.shadow_enabled and light.omni_range <= 5.0, "luz local sem sombra e com alcance limitado")
	check(lights == 4, "rajada de magias respeita orçamento de quatro luzes")
	var light: OmniLight3D = effects[0].get(&"_light")
	var peak: float = light.light_energy
	effects[0].call("_process", 0.1)
	check(light.light_energy < peak, "clarão perde energia logo após contato")
	for effect: Node3D in effects:
		effect.free()
	var again: Node3D = script.new()
	root.add_child(again)
	check(again.get(&"_light") != null, "limpeza devolve orçamento de luz")
	again.free()
	var healing: Node3D = script.new()
	healing.set(&"style", &"nature")
	healing.set(&"duration", 0.7)
	root.add_child(healing)
	healing.set_process(false)
	check(is_zero_approx(float(healing.call("envelope"))), "cura começa suave em vez de estourar")
	healing.call("_process", 0.35)
	check(float(healing.call("envelope")) > 0.4, "cura cresce até um brilho suave")
	healing.free()
	EnvQuality.current = EnvQuality.Preset.BAIXA
	var low: Node3D = script.new()
	root.add_child(low)
	low.set_process(false)
	check(low.get(&"_light") == null and low.get_child_count() == 2, "qualidade baixa mantém clarão sem luz dinâmica")
	low.call("_process", 0.3)
	await process_frame
	check(not is_instance_valid(low), "clarão e seus recursos saem após dissipação")
	EnvQuality.current = saved
	print("test_spell_contact: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
