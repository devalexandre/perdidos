extends OmniLight3D
## Luz de fogueira tremulando (energia e alcance oscilam com ruído suave). Só visual.

@export var amount: float = 0.25
@export var speed: float = 7.0

var _base_energy: float
var _base_range: float
var _t: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_base_energy = light_energy
	_base_range = omni_range
	_seed = fmod(global_position.x * 13.7 + global_position.z * 7.3, 100.0)
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(delta: float) -> void:
	_t += delta * speed
	var n := sin(_t + _seed) * 0.5 + sin(_t * 2.3 + _seed * 1.7) * 0.3 + sin(_t * 5.1) * 0.2
	light_energy = _base_energy * (1.0 + n * amount)
	omni_range = _base_range * (1.0 + n * amount * 0.3)
