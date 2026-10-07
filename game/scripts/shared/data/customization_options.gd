class_name CustomizationOptions
extends Resource
## Opções de personalização (GDD §6.1; contrato ADENDO 2): data/customization/options.tres.
## Usado pelo cliente (tela de criação) e pelo servidor (validar as escolhas na criação: is_valid/sanitize).
## Chaves de appearance: body, skin (int), hair_style (StringName), hair_color (int), eye_color (int),
## earrings (StringName; &"" = nenhum), nationality (StringName; região de origem, GDD §4.0).
## Cosmético nunca dá poder (GDD §14).

const PATH: String = "res://data/customization/options.tres"
const BODIES: Array[StringName] = [&"male", &"female"]
const KEY_BODY: StringName = &"body"
const KEY_SKIN: StringName = &"skin"
const KEY_HAIR_STYLE: StringName = &"hair_style"
const KEY_HAIR_COLOR: StringName = &"hair_color"
const KEY_EYE_COLOR: StringName = &"eye_color"
const KEY_EARRINGS: StringName = &"earrings"
const KEY_NATIONALITY: StringName = &"nationality"
const NO_EARRINGS: StringName = &""

@export var palettes: CustomizationPalettes
## Estilos de cabelo por corpo (pasta assets/characters/hair/<estilo>/<corpo>_*.png). O primeiro é o padrão.
## "buzz" (raspado) não tem folha: é o próprio corpo-base (cabelo curtinho na máscara B).
@export var hair_styles_male: Array[StringName] = []
@export var hair_styles_female: Array[StringName] = []
## Brincos (assets/characters/face/<id>/<corpo>_*.png), sem o "nenhum".
@export var earrings: Array[StringName] = []
## id → chave de tradução (localization/customization.csv).
@export var style_keys: Dictionary[StringName, String] = {}
@export var earring_keys: Dictionary[StringName, String] = {}
## Nacionalidades (ids de data/world/regions). Muda a roupa-base de estudante com que o Viajante chega;
## o título, quando tem roupa, vale por cima (CharacterData.full_appearance).
@export var nationalities: Array[StringName] = []
## id → chave de tradução (WA_R_* em localization/world_atlas.csv).
@export var nationality_keys: Dictionary[StringName, String] = {}
## id → outfit_id da roupa-base (assets/characters/outfits/chr_<corpo>_<outfit>_*.png).
## Nacionalidade sem entrada (ou sem folhas) usa o Viajante.
@export var nationality_outfits: Dictionary[StringName, StringName] = {}
@export var default_nationality: StringName = &"sabia"
## Enquanto a região não tem folha própria: [tecido, detalhe] que recolorem a roupa do Viajante (o azul vira
## "tecido", o vermelho vira "detalhe", mantendo o sombreado). Sem entrada = cores originais.
@export var nationality_colors: Dictionary[StringName, PackedColorArray] = {}
## Padrões = o Viajante atual.
@export var default_skin: int = 0
@export var default_hair_color: int = 0
@export var default_eye_color: int = 0
@export var default_earrings: StringName = &""

static var _cached: CustomizationOptions = null


## Instância de data/customization/options.tres (cache).
static func get_default() -> CustomizationOptions:
	if _cached == null and ResourceLoader.exists(PATH):
		_cached = load(PATH) as CustomizationOptions
	return _cached


func styles_for(body: StringName) -> Array[StringName]:
	return hair_styles_female if body == &"female" else hair_styles_male


## Lista de brincos para o seletor, com &"" (nenhum) primeiro.
func earring_choices() -> Array[StringName]:
	var out: Array[StringName] = [NO_EARRINGS]
	out.append_array(earrings)
	return out


func nationality_key(id: StringName) -> String:
	return nationality_keys.get(id, String(id))


## [tecido, detalhe] da nacionalidade, ou vazio (cores originais do Viajante).
func nationality_cloth(id: StringName) -> PackedColorArray:
	var c: PackedColorArray = nationality_colors.get(id, PackedColorArray())
	return c if c.size() >= 2 else PackedColorArray()


## Roupa-base da nacionalidade (&"" = Viajante).
func nationality_outfit(id: StringName) -> StringName:
	return nationality_outfits.get(id, &"")


func style_key(style: StringName) -> String:
	return style_keys.get(style, String(style))


func earring_key(id: StringName) -> String:
	return earring_keys.get(id, String(id))


func default_appearance(body: StringName = &"male") -> Dictionary:
	if body not in BODIES:
		body = BODIES[0]
	var styles: Array[StringName] = styles_for(body)
	return {
		KEY_BODY: body,
		KEY_SKIN: default_skin,
		KEY_HAIR_STYLE: styles[0] if not styles.is_empty() else &"",
		KEY_HAIR_COLOR: default_hair_color,
		KEY_EYE_COLOR: default_eye_color,
		KEY_EARRINGS: default_earrings,
		KEY_NATIONALITY: default_nationality if default_nationality in nationalities or nationalities.is_empty() \
				else nationalities[0],
	}


## true se todas as chaves de personalização existem e são válidas para o corpo.
func is_valid(appearance: Dictionary) -> bool:
	return sanitize(appearance) == _only_custom_keys(appearance)


## Cópia com cada escolha inválida/ausente trocada pelo padrão (tipos normalizados).
func sanitize(appearance: Dictionary) -> Dictionary:
	var body: StringName = StringName(str(appearance.get(KEY_BODY, BODIES[0])))
	var out: Dictionary = default_appearance(body)
	var n_skin: int = palettes.skin_count() if palettes != null else 0
	var n_hair: int = palettes.hair_count() if palettes != null else 0
	var n_eye: int = palettes.eye_count() if palettes != null else 0
	out[KEY_SKIN] = _int_in(appearance.get(KEY_SKIN), n_skin, out[KEY_SKIN])
	out[KEY_HAIR_COLOR] = _int_in(appearance.get(KEY_HAIR_COLOR), n_hair, out[KEY_HAIR_COLOR])
	out[KEY_EYE_COLOR] = _int_in(appearance.get(KEY_EYE_COLOR), n_eye, out[KEY_EYE_COLOR])
	var style: Variant = appearance.get(KEY_HAIR_STYLE)
	if (style is StringName or style is String) and StringName(style) in styles_for(out[KEY_BODY]):
		out[KEY_HAIR_STYLE] = StringName(style)
	var ear: Variant = appearance.get(KEY_EARRINGS)
	if (ear is StringName or ear is String) and StringName(ear) in earring_choices():
		out[KEY_EARRINGS] = StringName(ear)
	var nat: Variant = appearance.get(KEY_NATIONALITY)
	if (nat is StringName or nat is String) and StringName(nat) in nationalities:
		out[KEY_NATIONALITY] = StringName(nat)
	return out


## Aparência aleatória válida (botão "Aleatório").
func random_appearance(body: StringName, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out: Dictionary = default_appearance(body)
	# A nacionalidade é escolha de identidade: o "Aleatório" não mexe nela (fica a padrão; a tela preserva a atual).
	var styles: Array[StringName] = styles_for(out[KEY_BODY])
	var ears: Array[StringName] = earring_choices()
	out[KEY_SKIN] = rng.randi_range(0, maxi(0, palettes.skin_count() - 1))
	out[KEY_HAIR_COLOR] = rng.randi_range(0, maxi(0, palettes.hair_count() - 1))
	out[KEY_EYE_COLOR] = rng.randi_range(0, maxi(0, palettes.eye_count() - 1))
	if not styles.is_empty():
		out[KEY_HAIR_STYLE] = styles[rng.randi_range(0, styles.size() - 1)]
	out[KEY_EARRINGS] = ears[rng.randi_range(0, ears.size() - 1)]
	return out


static func _int_in(v: Variant, count: int, fallback: int) -> int:
	if (v is int or v is float) and int(v) == v and int(v) >= 0 and int(v) < count:
		return int(v)
	return fallback


static func _only_custom_keys(appearance: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: StringName in [KEY_BODY, KEY_SKIN, KEY_HAIR_STYLE, KEY_HAIR_COLOR, KEY_EYE_COLOR, KEY_EARRINGS, KEY_NATIONALITY]:
		if appearance.has(k):
			var v: Variant = appearance[k]
			out[k] = StringName(v) if v is String else (int(v) if v is float else v)
	return out
