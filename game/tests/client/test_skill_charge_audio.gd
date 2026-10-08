extends Node
class Caster extends Node3D:
	var hp_ratio: float = 1.0
	var kind: StringName = &"player"

class ArmedCaster extends Caster:
	var appearance: Dictionary = {&"weapon": &"blade"}

class RecordingAudio extends CombatAudio:
	var played: Array[String] = []
	func _play(candidates: Array[String], _pos: Vector3) -> void:
		played.append(candidates[0])

var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	AudioDirector.ensure_buses()
	var main := Node.new()
	main.name = &"Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var parent: Node = main
	for node_name: String in ["World", "Instances", "test", "Entities"]:
		var node := Node.new()
		node.name = node_name
		parent.add_child(node)
		parent = node
	var caster := Caster.new()
	caster.name = &"101"
	parent.add_child(caster)
	var audio := RecordingAudio.new()
	add_child(audio)
	audio.set_process(false)
	NetProgress.skill_cast.emit(101, &"arcane_spark", 0, Vector3.ZERO, 2000)
	check(audio.played.size() == 1, "impacto não toca no início da preparação")
	var charge: Node3D = audio._charges[101]
	charge.set_process(false)
	var voice: AudioStreamPlayer3D = charge.get(&"voice")
	check(voice.playing and voice.bus == AudioDirector.BUS_SFX, "carga toca no bus SFX")
	check((voice.stream as AudioStreamOggVorbis).loop, "som acompanha cargas de qualquer duração")
	check(charge.get(&"school") == &"arcane", "carga recebe a escola da skill")
	var loop_of: Callable = (load("res://scripts/client/combat/skill_charge_audio.gd") as Script).loop_path
	check(String(loop_of.call(&"arcane")).ends_with("_arcane.ogg") and String(loop_of.call(&"tank")).ends_with("_blade.ogg")
			and String(loop_of.call(&"bow")).ends_with("sfx_skill_charge_loop.ogg"), "laço por escola, genérico como reserva")
	charge.call("_process", 0.3)
	var start_volume: float = voice.volume_db
	var start_pitch: float = voice.pitch_scale
	caster.position = Vector3(3, 0, 2)
	charge.call("_process", 0.8)
	check(voice.volume_db > start_volume and voice.pitch_scale > start_pitch, "som cresce durante a carga")
	check(charge.global_position == caster.global_position, "som acompanha posição do personagem")
	NetProgress.cast_cancelled.emit(101, &"arcane_spark")
	check(audio._pending_impacts.is_empty() and bool(charge.get(&"stopping")), "cancelamento interrompe carga e remove impacto futuro")
	charge.call("_process", 0.2)
	await get_tree().process_frame
	check(not is_instance_valid(charge), "voz cancelada é removida")
	audio._process(3.0)
	check(audio.played.size() == 1, "cancelar não produz impacto depois")
	NetProgress.skill_cast.emit(101, &"arcane_spark", 0, Vector3.ZERO, 2000)
	audio._process(1.0)
	check(audio.played.size() == 2, "impacto espera o fim da conjuração")
	audio._process(1.1)
	# 08/10/2026: a liberação (sfx_skill_release*) toca no fim da carga, junto do impacto.
	check(audio.played.size() == 4 and audio.played[2].begins_with("sfx_skill_release")
			and audio.played.back().ends_with("_impact"), "liberação e impacto tocam no fim da carga (%s)" % [audio.played])
	SkillPresentation.visual_owners += 1
	NetProgress.skill_cast.emit(101, &"arcane_spark", 0, Vector3.ZERO, 500)
	audio._process(1.0)
	check(audio.played.size() == 6 and audio.played.back().begins_with("sfx_skill_release"),
			"projétil espera a chegada visual, mesmo após terminar carga")
	SkillPresentation.events.impact.emit(101, &"arcane_spark", Vector3(1, 0, 3))
	check(audio.played.size() == 7, "som coincide com chegada visual")
	SkillPresentation.events.impact.emit(101, &"arcane_spark", Vector3(1, 0, 3))
	check(audio.played.size() == 7, "chegadas múltiplas não duplicam som")
	var generic_impact: Array[String] = audio._impact_sounds(&"arcane_fire_serpent", Content.any_skill(&"arcane_fire_serpent"), caster)
	check(generic_impact.size() >= 2 and generic_impact[1].begins_with("sfx_skill_impact"),
			"skill de dano sem som próprio usa o impacto forte genérico (%s)" % [generic_impact])
	# Decisão do dono (08/10/2026): golpe físico de jogador sem som próprio usa o acerto da arma antes do genérico.
	var armed := ArmedCaster.new()
	var weapon_impact: Array[String] = audio._impact_sounds(&"blade_x", Content.any_skill(&"blade_firm_strike"), armed)
	check(weapon_impact.size() >= 3 and weapon_impact[1] == "sfx_hit_blade" and weapon_impact.back().begins_with("sfx_skill_impact"),
			"golpe físico usa o som da arma antes do impacto genérico (%s)" % [weapon_impact])
	armed.free()
	check(audio._release_sounds(&"support_x", &"support")[0] == "sfx_skill_release_support", "suporte libera suave")
	# Finalização (08/10/2026): golpe corpo a corpo e dor do alvo saem no contato visual, juntos e uma vez.
	var victim := Caster.new()
	victim.name = &"202"
	victim.kind = &"monster"
	parent.add_child(victim)
	var n0: int = audio.played.size()
	NetProgress.skill_cast.emit(101, &"blade_firm_strike", 202, Vector3.ZERO, 0)
	check(audio.played.size() == n0 + 1, "golpe instantâneo não toca impacto no lançamento")
	SkillPresentation.await_contact(101, 1.0) # o SkillFx faz isto no play()
	NetCombat.hit.emit(101, 202, 12, true, 0, 0.5)
	check(audio.played.size() == n0 + 1, "crítico e dor do alvo esperam o contato visual")
	SkillPresentation.contact(101, &"blade_firm_strike", Vector3(3, 0, 0))
	var tail: Array[String] = audio.played.slice(n0 + 1)
	check(tail.size() == 3 and tail[0] == "sfx_skill_blade_firm_strike_impact" and tail[1] == "sfx_hit_critical" \
			and tail[2].begins_with("sfx_mon_"), "impacto, crítico e dor no mesmo quadro do contato (%s)" % [tail])
	SkillPresentation.contact(101, &"blade_firm_strike", Vector3(3, 0, 0))
	check(audio.played.size() == n0 + 4, "segundo contato não repete o impacto")
	victim.free()
	SkillPresentation.visual_owners -= 1
	NetProgress.skill_cast.emit(101, &"arcane_spark", 0, Vector3.ZERO, 2000)
	caster.hp_ratio = 0.0
	audio._process(0.1)
	check(audio._pending_impacts.is_empty() and audio._charges.is_empty(), "morte limpa carga e impacto")
	caster.hp_ratio = 1.0
	NetProgress.skill_cast.emit(101, &"arcane_spark", 0, Vector3.ZERO, 2000)
	caster.free()
	audio._process(0.1)
	check(audio._pending_impacts.is_empty(), "remoção do personagem limpa impacto futuro")
	audio.free()
	main.free()
	print("test_skill_charge_audio: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
