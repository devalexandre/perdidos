extends Node3D
## Laço espacial no bus SFX: cresce com a preparação, acompanha o conjurador e encerra suavemente.
## Timbre por escola (08/10/2026, gen_skill_energy.py): lâmina/tanque graves e rugindo, arcano/híbrido
## elétrico e brilhante, suporte suave; as demais usam o laço genérico. Volume e tom sobem com o progresso.
const LOOP_BASE: String = "res://assets/audio/sfx/sfx_skill_charge_loop"
const SCHOOL_LOOPS: Dictionary[StringName, String] = {
	&"blade": "_blade", &"tank": "_blade", &"arcane": "_arcane", &"hybrid": "_arcane", &"support": "_support",
}
const PITCH_START: float = 0.88
const PITCH_END: float = 1.25
var follow: Node3D
var school: StringName = &""
var duration: float = 1.0
var elapsed: float = 0.0
var stopping: bool = false
var _fade_left: float = 0.12
var _fade_sec: float = 0.12
var voice: AudioStreamPlayer3D

func _ready() -> void:
	voice = AudioStreamPlayer3D.new()
	voice.name = &"ChargeVoice"
	var stream := load(loop_path(school)) as AudioStreamOggVorbis
	stream = stream.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	voice.stream = stream
	voice.bus = AudioDirector.BUS_SFX
	voice.unit_size = 8.0
	voice.max_distance = 35.0
	voice.max_db = -10.0
	voice.volume_db = -60.0
	add_child(voice)
	if is_instance_valid(follow):
		global_position = follow.global_position
	voice.play()

## Arquivo do laço da escola (cai no genérico se a escola não tiver o seu).
static func loop_path(skill_school: StringName) -> String:
	var path: String = LOOP_BASE + SCHOOL_LOOPS.get(skill_school, "") + ".ogg"
	return path if ResourceLoader.exists(path) else LOOP_BASE + ".ogg"

func stop(fade_sec: float = 0.12) -> void:
	if stopping:
		return
	stopping = true
	_fade_sec = maxf(0.001, fade_sec)
	_fade_left = _fade_sec

func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(follow) or not follow.is_inside_tree() or follow.is_queued_for_deletion():
		stop()
	else:
		global_position = follow.global_position
		if (&"hp_ratio" in follow and float(follow.get(&"hp_ratio")) <= 0.0) or elapsed >= duration:
			stop()
	var progress: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var gain: float = minf(1.0, elapsed / 0.08)
	if stopping:
		_fade_left -= delta
		gain *= clampf(_fade_left / _fade_sec, 0.0, 1.0)
		if _fade_left <= 0.0:
			voice.stop()
			queue_free()
	voice.volume_db = lerpf(-24.0, -14.0, progress) + linear_to_db(maxf(gain, 0.001))
	voice.pitch_scale = lerpf(PITCH_START, PITCH_END, progress)
