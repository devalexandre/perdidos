extends RefCounted
## Passarinho de ambiente em pixel art (08/10/2026): 5 quadros de 16×12 px desenhados à mão aqui (idle, rabo
## levantado, bicando, asa em cima, asa embaixo), de perfil olhando para a direita (o Sprite3D espelha). Não havia
## sprite de passarinho pequeno no projeto (só o corvo do presságio, de frente e voando); a espécie é só a paleta:
## o MESMO passarinho recolorido (sabiá, anu, pardal, pombo, periquito, saíra, gaivota). Trocar por folhas
## pintadas depois = mesma ordem de quadros, sheet de 5 colunas.
## Chaves: o contorno, b dorso/cabeça, w asa/rabo, c peito/barriga, k bico, e olho, l pernas.

const FRAME_W: int = 16
const FRAME_H: int = 12
const FRAME_IDLE: int = 0
const FRAME_FLICK: int = 1
const FRAME_PECK: int = 2
const FRAME_WING_UP: int = 3
const FRAME_WING_DOWN: int = 4
const FRAME_COUNT: int = 5
## Tamanho do texel do passarinho em relação ao dos personagens: 1,5× para ler na câmera do jogo (estilo chibi,
## bicho pequeno "gordinho"); a espécie multiplica por cima (pombo, gaivota maiores).
const TEXEL_SCALE: float = 1.5

const FRAMES: Array = [
	[
		"................",
		"...........ooo..",
		"..........obbbo.",
		"..........obebkk",
		"..........obbbo.",
		".....ooooobbbo..",
		"...oowwwwwbcco..",
		"..owwwwwwwccco..",
		".owwwoowwccco...",
		"owwo...ooccoo...",
		"oo.......l.l....",
		".........l.l....",
	],
	[
		"................",
		"...........ooo..",
		"..........obbbo.",
		"..........obebkk",
		"..........obbbo.",
		"o....ooooobbbo..",
		"ow.oowwwwwbcco..",
		"owwowwwwwwccco..",
		".owwwwowwccco...",
		"...o...ooccoo...",
		".........l.l....",
		".........l.l....",
	],
	[
		"................",
		"................",
		"................",
		"................",
		"................",
		"....ooooooo.....",
		"..oowwwwwwbo....",
		".owwwwwwwbbo....",
		"owwwoowwccbooo..",
		"owo...occcobbbo.",
		"oo.....l.lobebo.",
		".......l.l.obbkk",
	],
	[
		"................",
		"................",
		"......oo........",
		".....owwo.......",
		"......owwo..ooo.",
		".......owwoobbbo",
		"........owwbbebk",
		"...ooooowwbbbbo.",
		"..owwwwbbccccoo.",
		".oww..ooccco....",
		"oo.....ooo......",
		"................",
	],
	[
		"................",
		"................",
		"............ooo.",
		"...........obbbo",
		"...oooooooobbebk",
		"..owwwwbbbbbbbo.",
		".owwoowwwccccoo.",
		"oo....owwwco....",
		"......owwo......",
		".......oo.......",
		"................",
		"................",
	],
]

## Paletas por espécie: dorso, asa, peito, bico, olho, contorno, pernas; scale = tamanho relativo.
const SPECIES: Dictionary = {
	&"sabia": {"b": Color8(132, 104, 72), "w": Color8(101, 78, 54), "c": Color8(214, 120, 52), "k": Color8(222, 186, 86),
		"e": Color8(24, 18, 16), "o": Color8(46, 32, 24), "l": Color8(150, 120, 96), "scale": 1.0},
	&"anu": {"b": Color8(44, 42, 52), "w": Color8(30, 28, 38), "c": Color8(58, 56, 68), "k": Color8(30, 28, 34),
		"e": Color8(232, 228, 210), "o": Color8(14, 12, 18), "l": Color8(40, 38, 44), "scale": 1.1},
	&"pardal": {"b": Color8(150, 112, 74), "w": Color8(112, 80, 52), "c": Color8(206, 194, 168), "k": Color8(70, 60, 54),
		"e": Color8(20, 16, 14), "o": Color8(52, 38, 28), "l": Color8(160, 126, 100), "scale": 0.9},
	&"pombo": {"b": Color8(150, 154, 170), "w": Color8(112, 116, 134), "c": Color8(160, 128, 160), "k": Color8(60, 56, 60),
		"e": Color8(210, 92, 52), "o": Color8(48, 50, 62), "l": Color8(206, 110, 110), "scale": 1.35},
	&"periquito": {"b": Color8(98, 186, 84), "w": Color8(60, 140, 64), "c": Color8(176, 222, 96), "k": Color8(232, 196, 160),
		"e": Color8(18, 18, 18), "o": Color8(26, 62, 30), "l": Color8(150, 140, 130), "scale": 1.0},
	&"saira": {"b": Color8(62, 186, 196), "w": Color8(40, 104, 170), "c": Color8(232, 200, 70), "k": Color8(36, 34, 40),
		"e": Color8(18, 18, 18), "o": Color8(18, 46, 70), "l": Color8(60, 60, 66), "scale": 0.9},
	&"gaivota": {"b": Color8(238, 238, 236), "w": Color8(150, 158, 170), "c": Color8(250, 250, 248), "k": Color8(236, 196, 64),
		"e": Color8(20, 20, 20), "o": Color8(70, 76, 88), "l": Color8(222, 170, 80), "scale": 1.45},
}
const DEFAULT_SPECIES: StringName = &"sabia"

static var _cache: Dictionary = {}


## Folha (5 quadros lado a lado) da espécie, gerada uma vez e reaproveitada.
static func sheet(species: StringName) -> Texture2D:
	if not SPECIES.has(species):
		species = DEFAULT_SPECIES
	if _cache.has(species):
		return _cache[species]
	var tex := ImageTexture.create_from_image(sheet_image(species))
	_cache[species] = tex
	return tex


static func sheet_image(species: StringName) -> Image:
	var pal: Dictionary = SPECIES.get(species, SPECIES[DEFAULT_SPECIES])
	var img := Image.create(FRAME_W * FRAME_COUNT, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for f: int in FRAME_COUNT:
		var rows: Array = FRAMES[f]
		for y: int in FRAME_H:
			var row: String = rows[y]
			for x: int in mini(FRAME_W, row.length()):
				var ch: String = row[x]
				if ch == "." or not pal.has(ch):
					continue
				img.set_pixel(f * FRAME_W + x, y, pal[ch])
	return img


static func species_scale(species: StringName) -> float:
	return float((SPECIES.get(species, SPECIES[DEFAULT_SPECIES]) as Dictionary)["scale"]) * TEXEL_SCALE
