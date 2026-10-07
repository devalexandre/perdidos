class_name CustomizationPalettes
extends Resource
## Rampas de cor da personalização (GDD §6.1, §17.4; contrato ADENDO 2): data/customization/palettes.tres.
## Cada rampa vai do tom mais escuro (índice 0 = contorno/sombra funda) ao mais claro, até 6 tons, e é o que o
## shader assets/shaders/char_palette_swap.gdshader usa no lugar da rampa de cinza/máscara.
## Índices = valores de appearance.skin (0–5), .hair_color (0–9), .eye_color (0–5). Cores derivadas da
## paleta mestra v2 (assets/_reference/style_anchor/paleta-mestra-v2-proposta.gpl).

const MAX_TONES: int = 6

@export var skin_ramps: Array[PackedColorArray] = []
@export var skin_keys: PackedStringArray = []
@export var hair_ramps: Array[PackedColorArray] = []
@export var hair_keys: PackedStringArray = []
@export var eye_ramps: Array[PackedColorArray] = []
@export var eye_keys: PackedStringArray = []


func skin_count() -> int:
	return skin_ramps.size()


func hair_count() -> int:
	return hair_ramps.size()


func eye_count() -> int:
	return eye_ramps.size()


## Rampa pronta para o shader (sempre MAX_TONES cores; repete o último tom).
static func padded(ramp: PackedColorArray) -> PackedColorArray:
	var out := PackedColorArray()
	for i: int in MAX_TONES:
		out.append(ramp[mini(i, ramp.size() - 1)] if not ramp.is_empty() else Color.MAGENTA)
	return out


func skin(index: int) -> PackedColorArray:
	return padded(skin_ramps[clampi(index, 0, skin_ramps.size() - 1)]) if not skin_ramps.is_empty() else padded([])


func hair(index: int) -> PackedColorArray:
	return padded(hair_ramps[clampi(index, 0, hair_ramps.size() - 1)]) if not hair_ramps.is_empty() else padded([])


func eye(index: int) -> PackedColorArray:
	return padded(eye_ramps[clampi(index, 0, eye_ramps.size() - 1)]) if not eye_ramps.is_empty() else padded([])


## Cor de amostra (botão) de uma rampa: o tom do meio-claro.
static func swatch(ramp: PackedColorArray) -> Color:
	if ramp.is_empty():
		return Color.MAGENTA
	return ramp[mini(ramp.size() - 1, (ramp.size() * 2) / 3)]
