class_name MenuIcons
extends RefCounted
## Agente R (GDD §9.5): ícones pixel-art do menu da engrenagem, desenhados em código (sem arte ainda):
## cada ícone é uma grade 12×12 ("#" = cheio) com contorno escuro automático; a engrenagem é
## calculada (dentes em volta de um anel). Cache por (id, escala).

const GEAR: StringName = &"gear"
const SMILEY: StringName = &"smiley"
const INVENTORY: StringName = &"inventory"
const CHARACTER: StringName = &"character"
const SKILLS: StringName = &"skills"
const ATTRIBUTES: StringName = &"attributes"
const QUESTS: StringName = &"quests"
const SETTINGS: StringName = &"settings"
const FILL_CHAR: String = "#"
const GRID: Dictionary = {
	INVENTORY: [
		"....####....", "...#....#...", "...#....#...", "..########..", ".##########.",
		".####..####.", ".###.##.###.", ".##########.", ".##########.", ".##########.",
		"..########..", "............"],
	CHARACTER: [
		"....####....", "...######...", "...######...", "...######...", "....####....",
		"..########..", ".##########.", ".##.####.##.", ".##.####.##.", "....#..#....",
		"....#..#....", "...##..##..."],
	SKILLS: [
		".....##.....", ".....##.....", "....####....", "############", ".##########.",
		"..########..", "...######...", "...######...", "..###..###..", "..##....##..",
		".##......##.", "............"],
	ATTRIBUTES: [
		"..........##", "..........##", "......##..##", "......##..##", "..##..##..##",
		"..##..##..##", "..##..##..##", "..##..##..##", "..##..##..##", "############",
		"############", "............"],
	QUESTS: [
		".##########.", "#.########.#", ".#........#.", ".#.######.#.", ".#........#.",
		".#.######.#.", ".#........#.", ".#.#####..#.", ".#........#.", "#.########.#",
		".##########.", "............"],
	SETTINGS: [
		"............", ".##########.", ".##########.", "............", "............",
		".##########.", ".##########.", "............", "............", ".##########.",
		".##########.", "............"],
	SMILEY: [
		"...######...", "..########..", ".##########.", "###..##..###", "###..##..###",
		"############", "##.######.##", "###.####.###", ".###....###.", "..########..",
		"...######...", "............"],
}
## Engrenagem calculada: tamanho, raio do anel, raio dos dentes, furo e número de dentes.
const GEAR_SIZE: int = 14
const GEAR_BODY_R: float = 4.6
const GEAR_TOOTH_R: float = 6.6
const GEAR_HOLE_R: float = 2.0
const GEAR_TEETH: int = 8
const GEAR_TOOTH_WIDTH: float = 0.35
const FILL: Color = Color8(242, 230, 200)
const OUTLINE: Color = Color8(22, 19, 28)
const SMILEY_FILL: Color = Color8(250, 229, 140)
const SMILEY_INK: Color = Color8(58, 36, 24)

static var _cache: Dictionary[String, Texture2D] = {}


## Ícone pronto (cada pixel vira factor×factor).
static func icon(id: StringName, factor: int = 1, fill: Color = FILL) -> Texture2D:
	var key: String = "%s:%d:%s" % [id, factor, fill.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img: Image = _gear_image(fill) if id == GEAR else _grid_image(id, fill)
	if img == null:
		return null
	if factor > 1:
		img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _grid_image(id: StringName, fill: Color) -> Image:
	if not GRID.has(id):
		return null
	var rows: Array = GRID[id]
	var n: int = rows.size()
	# +1 px de borda para o contorno.
	var img := Image.create(n + 2, n + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var smiley: bool = id == SMILEY
	for y: int in n:
		var row: String = String(rows[y])
		for x: int in row.length():
			if row.substr(x, 1) == FILL_CHAR:
				img.set_pixel(x + 1, y + 1, SMILEY_FILL if smiley else fill)
			elif smiley and _inside_face(row, x):
				img.set_pixel(x + 1, y + 1, SMILEY_INK)
	_outline(img)
	return img


## Olhos e boca do rosto: buracos cercados de "#" na mesma linha.
static func _inside_face(row: String, x: int) -> bool:
	return row.substr(0, x).contains(FILL_CHAR) and row.substr(x + 1).contains(FILL_CHAR)


static func _gear_image(fill: Color) -> Image:
	var img := Image.create(GEAR_SIZE + 2, GEAR_SIZE + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c: float = (GEAR_SIZE - 1) * 0.5
	for y: int in GEAR_SIZE:
		for x: int in GEAR_SIZE:
			var d := Vector2(x - c, y - c)
			var r: float = d.length()
			var tooth: bool = cos(d.angle() * GEAR_TEETH) > GEAR_TOOTH_WIDTH
			if r <= GEAR_HOLE_R:
				continue
			if r <= GEAR_BODY_R or (tooth and r <= GEAR_TOOTH_R):
				img.set_pixel(x + 1, y + 1, fill)
	_outline(img)
	return img


## Contorno escuro de 1 px em volta de tudo o que é cheio.
static func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var marks: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + o
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and img.get_pixelv(p).a > 0.0 \
						and img.get_pixelv(p) != OUTLINE:
					marks.append(Vector2i(x, y))
					break
	for m: Vector2i in marks:
		img.set_pixelv(m, OUTLINE)
