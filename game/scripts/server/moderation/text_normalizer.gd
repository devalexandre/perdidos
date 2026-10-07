class_name TextNormalizer
extends RefCounted
## Normalização de texto para o filtro de palavrões (GDD §13, docs/moderacao.md).
##
## Gera um "esqueleto" do texto: cada caractere do original vira 0..n caracteres minúsculos,
## sem acentos, com letras de outros alfabetos parecidas (cirílico, grego, largura cheia, letras
## matemáticas, circuladas, versaletes...) trocadas pela latina, e caracteres invisíveis
## (largura zero, hífen suave, seletores de variação) removidos. Katakana vira hiragana.
## Cada caractere do esqueleto guarda o índice do caractere original de onde veio, para o filtro
## trocar o trecho certo do texto ORIGINAL por "***".
##
## Não é uma NFKC completa (a Godot não traz as tabelas Unicode), mas cobre as formas de
## compatibilidade usadas para burlar filtros: largura cheia, letras matemáticas (U+1D400),
## circuladas/quadradas, sobrescritos, ligaduras latinas e sinais diacríticos combinantes.
## Leetspeak (0→o, 4→a, @→a...) NÃO é trocado aqui: o filtro trata isso na expressão de cada termo
## (um "1" pode ser "i" ou "l").

## Resultado da normalização: texto normalizado + mapa para o original.
class Skeleton:
	## Texto normalizado (minúsculas, sem acento, sem invisíveis).
	var text: String = ""
	## Para cada caractere de `text`: índice do caractere original correspondente.
	var src: PackedInt32Array = PackedInt32Array()

	## Trecho [start, end) do esqueleto -> trecho [start, end) do texto original.
	func to_original_span(start: int, end: int) -> Vector2i:
		if start >= end or start < 0 or end > src.size():
			return Vector2i(-1, -1)
		return Vector2i(src[start], src[end - 1] + 1)


const SPACE: String = " "
## Sequências de pelo menos este número de letras soltas ("p o r r a") viram uma palavra só.
const MIN_SPACED_RUN: int = 3

## Pares "caracteres de origem" -> "letra latina". Tudo já em minúsculas.
const FOLD_GROUPS: Dictionary[String, String] = {
	# Latim com diacríticos (Latin-1, Extended-A/B, Extended Additional mais comuns).
	"àáâãäåāăąǎǟǡǻȁȃȧạảấầẩẫậắằẳẵặⱥɐ": "a",
	"ḃḅḇƀɓ": "b",
	"çćĉċčḉƈȼ": "c",
	"ďđḋḍḏḑḓɖɗð": "d",
	"èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệɇɛ": "e",
	"ḟƒ": "f",
	"ĝğġģǥǧǵḡɠɡ": "g",
	"ĥħȟḣḥḧḩḫẖɦ": "h",
	"ìíîïĩīĭįıǐȉȋḭḯỉịɨ": "i",
	"ĵǰȷɉ": "j",
	"ķĸǩḱḳḵƙ": "k",
	"ĺļľŀłƚḷḹḻḽɫɬ": "l",
	"ḿṁṃɱ": "m",
	"ńņňŉŋǹṅṇṉṋɲ": "n",
	"òóôõöøōŏőơǒǫǭǿȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợɵ": "o",
	"ṕṗƥ": "p",
	"ɋ": "q",
	"ŕŗřȑȓṙṛṝṟɍɽ": "r",
	"śŝşšșṡṣṥṧṩſ": "s",
	"ţťŧțṫṭṯṱẗƭʈ": "t",
	"ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữựʉ": "u",
	"ṽṿʋ": "v",
	"ŵẁẃẅẇẉẘ": "w",
	"ẋẍ": "x",
	"ýÿŷȳẏẙỳỵỷỹƴɏ": "y",
	"źżžƶẑẓẕȥ": "z",
	# Versaletes e outras letras "fonéticas" parecidas.
	"ᴀ": "a", "ʙ": "b", "ᴄ": "c", "ᴅ": "d", "ᴇ": "e", "ꜰ": "f", "ɢ": "g", "ʜ": "h", "ɪ": "i",
	"ᴊ": "j", "ᴋ": "k", "ʟ": "l", "ᴍ": "m", "ɴ": "n", "ᴏ": "o", "ᴘ": "p", "ʀ": "r",
	"ꜱ": "s", "ᴛ": "t", "ᴜ": "u", "ᴠ": "v", "ᴡ": "w", "ʏ": "y", "ᴢ": "z",
	# Cirílico parecido com latim (depois de to_lower).
	"аӑӓ": "a", "вьъ": "b", "сҫ": "c", "ԁ": "d", "еёѐєӗ": "e", "һ": "h", "іїӏ": "i", "ј": "j",
	"кқӄ": "k", "м": "m", "нң": "h", "оӧө": "o", "р": "p", "ԛ": "q", "г": "r", "ѕ": "s",
	"т": "t", "уўӯӱӳү": "y", "хҳ": "x", "ԝ": "w", "п": "n", "и": "u", "з": "3",
	# Grego parecido com latim.
	"αάἀἁ": "a", "β": "b", "δ": "d", "εέ": "e", "ζ": "z", "ηή": "n", "ιίϊΐ": "i", "κ": "k",
	"ν": "v", "οό": "o", "ρ": "p", "τ": "t", "υύϋΰ": "u", "χ": "x", "ωώ": "w", "μ": "u",
	"ς": "s", "σ": "o", "γ": "y",
	# Sobrescritos, subscritos e ordinais.
	"ª": "a", "º": "o", "ᵃ": "a", "ᵇ": "b", "ᶜ": "c", "ᵈ": "d", "ᵉ": "e", "ᶠ": "f", "ᵍ": "g",
	"ʰ": "h", "ⁱ": "i", "ʲ": "j", "ᵏ": "k", "ˡ": "l", "ᵐ": "m", "ⁿ": "n", "ᵒ": "o", "ᵖ": "p",
	"ʳ": "r", "ˢ": "s", "ᵗ": "t", "ᵘ": "u", "ᵛ": "v", "ʷ": "w", "ˣ": "x", "ʸ": "y", "ᶻ": "z",
	"⁰₀": "0", "¹₁": "1", "²₂": "2", "³₃": "3", "⁴₄": "4", "⁵₅": "5", "⁶₆": "6", "⁷₇": "7",
	"⁸₈": "8", "⁹₉": "9",
}
## Um caractere que vira vários.
const FOLD_MULTI: Dictionary[String, String] = {
	"ß": "ss", "ẞ": "ss", "æ": "ae", "ǽ": "ae", "œ": "oe", "þ": "th", "ĳ": "ij", "ﬀ": "ff",
	"ﬁ": "fi", "ﬂ": "fl", "ﬃ": "ffi", "ﬄ": "ffl", "ﬅ": "st", "ﬆ": "st", "ǆ": "dz", "ǳ": "dz",
	"ǉ": "lj", "ǌ": "nj", "…": "...",
}
## Katakana de meia largura (U+FF61..U+FF9F) -> hiragana (na mesma ordem).
const HALFWIDTH_KANA_FROM: String = "｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ"
const HALFWIDTH_KANA_TO: String = "。「」、・をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん゛゜"

static var _fold: Dictionary = {}
## Cache code point -> resultado de fold_char (a maioria das mensagens repete poucos caracteres).
static var _memo: Dictionary[int, String] = {}


## Normaliza `text`. Com `join_spaced` = true, sequências de letras soltas separadas por espaço
## ("p o r r a", "f u c k") viram uma palavra só no esqueleto.
static func skeleton(text: String, join_spaced: bool = true) -> Skeleton:
	_ensure_tables()
	var out: PackedStringArray = PackedStringArray()
	var src: PackedInt32Array = PackedInt32Array()
	for i: int in text.length():
		var cp: int = text.unicode_at(i)
		var folded: String = _memo.get(cp, "\uffff")
		if folded == "\uffff":
			folded = fold_char(cp)
			_memo[cp] = folded
		if folded.is_empty():
			continue
		# Marcas de sonorização do japonês juntam com o kana anterior (か + ゛ = が).
		if (folded == "゛" or folded == "゜") and not out.is_empty():
			var prev: int = out[out.size() - 1].unicode_at(0)
			var voiced: int = _voice_kana(prev, folded == "゜")
			if voiced != 0:
				out[out.size() - 1] = String.chr(voiced)
				continue
		for ch: String in folded:
			out.append(ch)
			src.append(i)
	var sk := Skeleton.new()
	if join_spaced:
		_join_spaced_letters(out, src)
	sk.text = "".join(out)
	sk.src = src
	return sk


## Só o texto normalizado (para listas de termos e whitelist).
static func normalize(text: String) -> String:
	return skeleton(text, false).text


## Caractere (code point) -> texto normalizado ("" = remover).
static func fold_char(cp: int) -> String:
	_ensure_tables()
	if _is_invisible(cp):
		return ""
	if _is_combining(cp):
		return ""
	if _is_space(cp):
		return SPACE
	# Largura cheia (！..～) -> ASCII.
	if cp >= 0xFF01 and cp <= 0xFF5E:
		cp -= 0xFEE0
	# Letras e dígitos matemáticos (negrito, itálico, gótico, duplo...).
	elif cp >= 0x1D400 and cp <= 0x1D6A3:
		var k: int = (cp - 0x1D400) % 52
		cp = (0x61 + k - 26) if k >= 26 else (0x61 + k)
	elif cp >= 0x1D7CE and cp <= 0x1D7FF:
		cp = 0x30 + (cp - 0x1D7CE) % 10
	# Letras circuladas, entre parênteses, quadradas e indicadores regionais.
	elif cp >= 0x24B6 and cp <= 0x24CF:
		cp = 0x61 + cp - 0x24B6
	elif cp >= 0x24D0 and cp <= 0x24E9:
		cp = 0x61 + cp - 0x24D0
	elif cp >= 0x249C and cp <= 0x24B5:
		cp = 0x61 + cp - 0x249C
	elif cp >= 0x1F130 and cp <= 0x1F149:
		cp = 0x61 + cp - 0x1F130
	elif cp >= 0x1F150 and cp <= 0x1F169:
		cp = 0x61 + cp - 0x1F150
	elif cp >= 0x1F170 and cp <= 0x1F189:
		cp = 0x61 + cp - 0x1F170
	elif cp >= 0x1F1E6 and cp <= 0x1F1FF:
		cp = 0x61 + cp - 0x1F1E6
	elif cp >= 0x2460 and cp <= 0x2468:
		cp = 0x31 + cp - 0x2460
	# Katakana -> hiragana.
	elif cp >= 0x30A1 and cp <= 0x30F6:
		cp -= 0x60
	elif cp >= 0xFF61 and cp <= 0xFF9F:
		return HALFWIDTH_KANA_TO[cp - 0xFF61]
	var ch: String = String.chr(cp).to_lower()
	if ch.length() != 1:
		return ch
	if _fold.has(ch):
		return _fold[ch]
	return ch


## Letra (qualquer alfabeto) ou dígito, depois da normalização.
static func is_word_char(ch: String) -> bool:
	if ch.is_empty():
		return false
	var cp: int = ch.unicode_at(0)
	if (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x30 and cp <= 0x39):
		return true
	if cp < 0x80:
		return false
	# Fora do ASCII: letra se tem caixa diferente, ou está nos blocos CJK/kana/hangul.
	if ch.to_upper() != ch.to_lower():
		return true
	return (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x3400 and cp <= 0x9FFF) \
			or (cp >= 0xAC00 and cp <= 0xD7AF) or cp == 0xF1 or (cp >= 0x0E00 and cp <= 0x0EFF)


static func _ensure_tables() -> void:
	if not _fold.is_empty():
		return
	for group: String in FOLD_GROUPS:
		for ch: String in group:
			_fold[ch] = FOLD_GROUPS[group]
	for k: String in FOLD_MULTI:
		_fold[k] = FOLD_MULTI[k]
	# "ñ" fica como está (espanhol "coño" x italiano "cono"); o filtro trata "ñ" como "ñ|nh|ny".
	_fold.erase("ñ")


static func _is_invisible(cp: int) -> bool:
	return cp == 0x00AD or cp == 0x034F or cp == 0x061C or cp == 0x115F or cp == 0x1160 \
			or cp == 0x17B4 or cp == 0x17B5 or (cp >= 0x180B and cp <= 0x180E) \
			or (cp >= 0x200B and cp <= 0x200F) or (cp >= 0x202A and cp <= 0x202E) \
			or (cp >= 0x2060 and cp <= 0x2064) or (cp >= 0x2066 and cp <= 0x206F) \
			or cp == 0x3164 or (cp >= 0xFE00 and cp <= 0xFE0F) or cp == 0xFEFF or cp == 0xFFA0 \
			or (cp >= 0xE0000 and cp <= 0xE007F) or (cp >= 0xE0100 and cp <= 0xE01EF) \
			or (cp < 0x20 and cp != 0x09 and cp != 0x0A)


static func _is_combining(cp: int) -> bool:
	return (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x1AB0 and cp <= 0x1AFF) \
			or (cp >= 0x1DC0 and cp <= 0x1DFF) or (cp >= 0x20D0 and cp <= 0x20FF) \
			or (cp >= 0xFE20 and cp <= 0xFE2F) or cp == 0x0483 or cp == 0x0484 \
			or cp == 0x0485 or cp == 0x0486 or cp == 0x0487 or cp == 0x0488 or cp == 0x0489


static func _is_space(cp: int) -> bool:
	return cp == 0x20 or cp == 0x09 or cp == 0x0A or cp == 0xA0 or (cp >= 0x2000 and cp <= 0x200A) \
			or cp == 0x202F or cp == 0x205F or cp == 0x3000 or cp == 0x1680


## か(304B)..ぽ: kana que ganham ゛ (cp + 1) ou ゜ (cp + 2, só は..ほ).
static func _voice_kana(cp: int, handakuten: bool) -> int:
	if handakuten:
		if cp >= 0x306F and cp <= 0x307B and (cp - 0x306F) % 3 == 0:
			return cp + 2
		return 0
	if cp == 0x3046:
		return 0x3094
	if (cp >= 0x304B and cp <= 0x3062 and (cp - 0x304B) % 2 == 0) \
			or (cp >= 0x3064 and cp <= 0x3068 and (cp - 0x3064) % 2 == 0) \
			or (cp >= 0x306F and cp <= 0x307B and (cp - 0x306F) % 3 == 0):
		return cp + 1
	return 0


## Remove os espaços dentro de sequências de >= MIN_SPACED_RUN "palavras" de uma letra só.
static func _join_spaced_letters(chars: PackedStringArray, src: PackedInt32Array) -> void:
	# Tokens = trechos sem espaço: [início, fim) no array.
	var tokens: Array[Vector2i] = []
	var start: int = -1
	for i: int in chars.size():
		if chars[i] == SPACE:
			if start >= 0:
				tokens.append(Vector2i(start, i))
				start = -1
		elif start < 0:
			start = i
	if start >= 0:
		tokens.append(Vector2i(start, chars.size()))
	var remove: Dictionary[int, bool] = {}
	var run: Array[Vector2i] = []
	for t: Vector2i in tokens + [Vector2i(-1, -1)]:
		if t.x >= 0 and _letter_count(chars, t) == 1:
			run.append(t)
			continue
		if run.size() >= MIN_SPACED_RUN:
			for k: int in range(1, run.size()):
				for j: int in range(run[k - 1].y, run[k].x):
					remove[j] = true
		run.clear()
	if remove.is_empty():
		return
	var keys: Array = remove.keys()
	keys.sort()
	keys.reverse()
	for j: int in keys:
		chars.remove_at(j)
		src.remove_at(j)


## Letras/dígitos do token (sem nenhum, conta os símbolos de leet: "@" sozinho é um "a").
static func _letter_count(chars: PackedStringArray, t: Vector2i) -> int:
	var n: int = 0
	var leet: int = 0
	for i: int in range(t.x, t.y):
		if is_word_char(chars[i]):
			n += 1
		elif "@$!|€".contains(chars[i]):
			leet += 1
	return n if n > 0 else leet
