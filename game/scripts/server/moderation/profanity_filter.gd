class_name ProfanityFilter
extends RefCounted
## Filtro de palavrões e ofensas (GDD §13) — servidor. Reutilizável para chat, nomes de
## personagem e, depois, nomes de guilda. Guia completo: docs/moderacao.md.
##
## Listas (dados, não código): data/chat/profanity/<idioma>.txt, uma entrada por linha:
##     <severidade> <modo><termo>
##   severidade: 1 leve, 2 palavrão, 3 ofensa/discurso de ódio (slurs.txt é sempre 3)
##   modo (prefixo opcional):  (nada) começo de palavra ("porra" pega "porras")
##                             =  palavra inteira (siglas e palavras curtas: "=fdp", "=cu")
##                             *  em qualquer lugar, até dentro de outra palavra ("*caralho")
##   Termos com espaço ("filho da puta") aceitam qualquer separador entre as palavras.
## whitelist.txt: palavras legítimas que CONTÊM um termo (problema de Scunthorpe). Se uma
## palavra da whitelist cobre o trecho encontrado, ele não é censurado.
##
## Burlas cobertas: acentos e diacríticos, maiúsculas, alfabetos parecidos (cirílico, grego),
## largura cheia, letras matemáticas/circuladas, caracteres invisíveis (TextNormalizer); leet
## (0→o, 1→i/l, 3→e, 4→a, 5→s, 7→t, @→a, $→s...), letras repetidas ("fuuuck"), separadores entre as
## letras ("f.u.c.k", "p-o-r-r-a", "p o r r a") e abreviações conhecidas (estão nas listas).

const PROFANITY_DIR: String = "res://data/chat/profanity/"
const WHITELIST_FILE: String = "whitelist.txt"
const SLURS_FILE: String = "slurs.txt"
const LIST_EXT: String = ".txt"
const COMMENT_PREFIX: String = "#"
const MASK: String = "***"
const MODE_STEM: String = ""
const MODE_EXACT: String = "="
const MODE_ANYWHERE: String = "*"
const SEVERITY_MILD: int = 1
const SEVERITY_PROFANITY: int = 2
const SEVERITY_SLUR: int = 3
const CATEGORY_PROFANITY: String = "profanity"
const CATEGORY_SLUR: String = "slur"
## Nomes: termos com pelo menos isto de letras também são procurados dentro de outras palavras.
const NAME_MIN_EMBEDDED_LENGTH: int = 4

## Leet e trocas comuns: letra do termo -> caracteres aceitos no texto (já normalizado).
const LEET: Dictionary[String, String] = {
	"a": "a4@^", "b": "b8", "c": "ckq(<¢", "e": "e3€&", "f": "f", "g": "g69", "h": "h#",
	"i": "i1!|", "k": "kq", "l": "l1|!", "o": "o0°", "q": "qk", "s": "s5$", "t": "t7+",
	"u": "uv", "z": "z2", "x": "x",
}
## Letras que também aceitam uma sequência de dois caracteres.
const LEET_DIGRAPHS: Dictionary[String, PackedStringArray] = {
	"f": ["ph"], "ñ": ["nh", "ny"],
}
## Símbolos que podem ser letra (leet): não contam como separador.
const LEET_SYMBOLS: String = "@^€&#!|°$+(<¢"
## Separadores aceitos ENTRE letras de uma palavra (não inclui espaço; espaço é tratado pelo
## TextNormalizer ao juntar letras soltas). Quantificadores possessivos (*+, ++) evitam
## retrocesso exponencial.
const SEP: String = "[^\\p{L}\\p{N}\\s@^€&#!|°$+(<¢]*+"
## Entre palavras de um termo com espaço.
const WORD_SEP: String = "[^\\p{L}\\p{N}@^€&#!|°$+(<¢]*+"
const NOT_WORD_BEFORE: String = "(?<![\\p{L}\\p{N}])"
const NOT_WORD_AFTER: String = "(?![\\p{L}\\p{N}])"


## Uma entrada das listas.
class Term:
	var id: String = ""         ## "<idioma>:<termo>" (vai para o log, nunca o texto do jogador)
	var lang: String = ""
	var text: String = ""       ## termo normalizado
	var mode: String = ""
	var severity: int = 2
	var category: String = CATEGORY_PROFANITY
	var pattern: String = ""    ## sem âncoras
	var regex: RegEx = null     ## com âncoras do modo (usado nos nomes)


var terms: Array[Term] = []
var whitelist: PackedStringArray = PackedStringArray()
## Termos de começo de palavra/palavra inteira (um lookbehind só na frente: rápido) e termos
## "em qualquer lugar"; o grupo i+1 de cada um é o termo i da lista correspondente.
var _combined: RegEx = null
var _combined_terms: Array[Term] = []
## Primeiro caractere possível -> {"re": RegEx ancorado em \G, "terms": Array[Term]} (só os termos
## de começo de palavra que podem começar com ele: evita testar centenas de termos por posição).
var _buckets: Dictionary[String, Dictionary] = {}
var _anywhere: RegEx = null
var _anywhere_terms: Array[Term] = []
## Regex com cada termo em qualquer lugar (nomes de personagem).
var _embedded: RegEx = null
var _embedded_terms: Array[Term] = []


func _init(dir: String = PROFANITY_DIR) -> void:
	load_dir(dir)


func is_ready() -> bool:
	return _combined != null


## Carrega todas as listas de `dir` (substitui as atuais).
func load_dir(dir: String) -> void:
	terms.clear()
	whitelist.clear()
	# (O preset de exportação do servidor inclui data/chat/* — os .txt vão no pacote.)
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	var seen: Dictionary[String, bool] = {}
	for f: String in files:
		if not f.ends_with(LIST_EXT):
			continue
		var path: String = dir.path_join(f)
		if f == WHITELIST_FILE:
			for line: String in _read_lines(path):
				var w: String = TextNormalizer.normalize(line)
				if not w.is_empty():
					whitelist.append(w)
			continue
		var lang: String = f.get_basename()
		for line: String in _read_lines(path):
			var t: Term = _parse_term(line, lang, f == SLURS_FILE)
			if t == null or seen.has(t.mode + t.text):
				continue
			seen[t.mode + t.text] = true
			terms.append(t)
	_compile()


## Adiciona um termo em tempo de execução (testes, ferramentas).
func add_term(line: String, lang: String = "extra") -> void:
	var t: Term = _parse_term(line, lang, false)
	if t != null:
		terms.append(t)
		_compile()


## Filtra `text`. Devolve {text (com "***"), filtered (bool), hits: [{id, lang, severity,
## category, start, end}], max_severity}. A mensagem continua sendo entregue com o texto filtrado.
func filter_text(text: String) -> Dictionary:
	var hits: Array[Dictionary] = find_hits(text)
	var out: String = text
	var max_sev: int = 0
	# Do fim para o começo para não mexer nos índices.
	for k: int in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[k]
		out = out.substr(0, h["start"]) + MASK + out.substr(h["end"])
		max_sev = maxi(max_sev, h["severity"])
	return {"text": out, "filtered": not hits.is_empty(), "hits": hits, "max_severity": max_sev}


## Trechos ofensivos (índices no texto ORIGINAL), em ordem e sem sobreposição.
func find_hits(text: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if _combined == null or text.is_empty():
		return hits
	var sk: TextNormalizer.Skeleton = TextNormalizer.skeleton(text)
	_scan_word_starts(sk, hits)
	_scan(_anywhere, _anywhere_terms, sk, hits)
	return _merge(hits)


## Termos de começo de palavra: só nas posições sem letra/dígito antes, e só o balde do caractere.
func _scan_word_starts(sk: TextNormalizer.Skeleton, hits: Array[Dictionary]) -> void:
	var text: String = sk.text
	var n: int = text.length()
	var prev_word: bool = false
	var skip_until: int = 0
	for p: int in n:
		var ch: String = text[p]
		var was_word: bool = prev_word
		prev_word = TextNormalizer.is_word_char(ch)
		if was_word or p < skip_until or not _buckets.has(ch):
			continue
		var b: Dictionary = _buckets[ch]
		var m: RegExMatch = (b["re"] as RegEx).search(text, p)
		if m == null:
			continue
		var t: Term = _group_term(m, b["terms"])
		if t == null or _is_whitelisted(text, m.get_start(), m.get_end()):
			continue
		var span: Vector2i = sk.to_original_span(m.get_start(), m.get_end())
		hits.append({"id": t.id, "lang": t.lang, "severity": t.severity, "category": t.category,
				"start": span.x, "end": span.y})
		skip_until = m.get_end()


func _scan(re: RegEx, list: Array[Term], sk: TextNormalizer.Skeleton, hits: Array[Dictionary]) -> void:
	if re == null:
		return
	var pos: int = 0
	while pos < sk.text.length():
		var m: RegExMatch = re.search(sk.text, pos)
		if m == null:
			break
		var t: Term = _group_term(m, list)
		if t == null or _is_whitelisted(sk.text, m.get_start(), m.get_end()):
			pos = m.get_start() + 1
			continue
		var span: Vector2i = sk.to_original_span(m.get_start(), m.get_end())
		hits.append({"id": t.id, "lang": t.lang, "severity": t.severity, "category": t.category,
				"start": span.x, "end": span.y})
		pos = maxi(m.get_end(), m.get_start() + 1)


## Nome de personagem/guilda: mais rígido (sem espaços, termos longos valem dentro de palavras:
## "XxPorraxX"). Devolve {allowed, hits}.
func check_name(p_name: String) -> Dictionary:
	var hits: Array[Dictionary] = find_hits(p_name)
	if hits.is_empty() and _embedded != null:
		var sk: TextNormalizer.Skeleton = TextNormalizer.skeleton(p_name)
		var m: RegExMatch = _embedded.search(sk.text)
		while m != null:
			if not _is_whitelisted(sk.text, m.get_start(), m.get_end()):
				var t: Term = _group_term(m, _embedded_terms)
				if t != null:
					var span: Vector2i = sk.to_original_span(m.get_start(), m.get_end())
					hits.append({"id": t.id, "lang": t.lang, "severity": t.severity,
							"category": t.category, "start": span.x, "end": span.y})
					break
			m = _embedded.search(sk.text, m.get_start() + 1)
	return {"allowed": hits.is_empty(), "hits": hits}


func is_name_allowed(p_name: String) -> bool:
	return check_name(p_name)["allowed"]


# ---------------------------------------------------------------- interno

static func _read_lines(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not FileAccess.file_exists(path):
		push_warning("Profanity list not found: %s" % path)
		return out
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		var hash_at: int = line.find(" " + COMMENT_PREFIX)
		if hash_at >= 0:
			line = line.substr(0, hash_at).strip_edges()
		if line.is_empty() or line.begins_with(COMMENT_PREFIX):
			continue
		out.append(line)
	return out


## "<sev> <modo><termo>" (ou só "<modo><termo>", severidade 2).
func _parse_term(line: String, lang: String, is_slur: bool) -> Term:
	var t := Term.new()
	var rest: String = line.strip_edges()
	var first: String = rest.get_slice(" ", 0)
	if first.is_valid_int():
		t.severity = clampi(first.to_int(), SEVERITY_MILD, SEVERITY_SLUR)
		rest = rest.substr(first.length()).strip_edges()
	if rest.begins_with(MODE_EXACT) or rest.begins_with(MODE_ANYWHERE):
		t.mode = rest[0]
		rest = rest.substr(1)
	if is_slur:
		t.severity = SEVERITY_SLUR
		t.category = CATEGORY_SLUR
	elif t.severity >= SEVERITY_SLUR:
		t.category = CATEGORY_SLUR
	t.text = TextNormalizer.normalize(rest).strip_edges()
	if t.text.is_empty():
		return null
	t.lang = lang
	t.id = "%s:%s" % [lang, t.text]
	t.pattern = _term_pattern(t.text)
	t.regex = RegEx.new()
	if t.regex.compile("(*UCP)" + _anchored(t)) != OK:
		push_warning("Invalid profanity term: %s" % line)
		return null
	return t


static func _term_pattern(norm: String) -> String:
	# Unidades: letra do termo (letras iguais seguidas viram uma unidade com mínimo n).
	var units: Array[Dictionary] = []
	for w: String in norm.split(" ", false):
		var first: bool = true
		for ch: String in w:
			if not first and units[units.size() - 1]["ch"] == ch:
				units[units.size() - 1]["n"] += 1
				continue
			units.append({"ch": ch, "n": 1, "word_start": first})
			first = false
	var out: String = ""
	for k: int in units.size():
		var u: Dictionary = units[k]
		if k > 0:
			out += WORD_SEP if u["word_start"] else SEP
		var chars: String = LEET.get(u["ch"], u["ch"])
		var cls: String = "[" + _escape_class(chars) + "]"
		for dg: String in LEET_DIGRAPHS.get(u["ch"], PackedStringArray()):
			cls += "|" + _escape_class(dg)
			chars += dg
		# X(?:SEP X){n-1,}: letra repetida, com ou sem separador ("rr", "r.r", "rrrr").
		var x: String = "(?:%s)" % cls
		# Possessivo quando a próxima letra não aceita os mesmos caracteres (sem retrocesso).
		var next_chars: String = ""
		if k + 1 < units.size():
			var nu: Dictionary = units[k + 1]
			next_chars = LEET.get(nu["ch"], nu["ch"])
			for dg: String in LEET_DIGRAPHS.get(nu["ch"], PackedStringArray()):
				next_chars += dg
		var overlap: bool = false
		for c: String in next_chars:
			if chars.contains(c):
				overlap = true
				break
		out += "%s(?:%s%s){%d,}%s" % [x, SEP, x, u["n"] - 1, "" if overlap else "+"]
	return out


static func _anchored(t: Term) -> String:
	match t.mode:
		MODE_EXACT:
			return NOT_WORD_BEFORE + t.pattern + NOT_WORD_AFTER
		MODE_ANYWHERE:
			return t.pattern
		_:
			return NOT_WORD_BEFORE + t.pattern


static func _escape_class(chars: String) -> String:
	var out: String = ""
	for ch: String in chars:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}-/#&~".contains(ch) else ch
	return out


func _compile() -> void:
	_combined = null
	_anywhere = null
	_embedded = null
	_combined_terms.clear()
	_anywhere_terms.clear()
	_embedded_terms.clear()
	if terms.is_empty():
		return
	# Mais longos primeiro: na mesma posição ganha o termo mais completo.
	terms.sort_custom(func(a: Term, b: Term) -> bool:
		return a.text.length() > b.text.length() if a.text.length() != b.text.length() else a.id < b.id)
	var word_alts: PackedStringArray = PackedStringArray()
	var any_alts: PackedStringArray = PackedStringArray()
	var emb_alts: PackedStringArray = PackedStringArray()
	for t: Term in terms:
		if t.mode == MODE_ANYWHERE:
			_anywhere_terms.append(t)
			any_alts.append("(" + t.pattern + ")")
		else:
			_combined_terms.append(t)
			word_alts.append("(" + t.pattern + (NOT_WORD_AFTER if t.mode == MODE_EXACT else "") + ")")
		if t.text.replace(" ", "").length() >= NAME_MIN_EMBEDDED_LENGTH:
			_embedded_terms.append(t)
			emb_alts.append("(" + t.pattern + ")")
	_combined = _compile_alts(NOT_WORD_BEFORE + "(?:", word_alts)
	_build_buckets()
	_anywhere = _compile_alts("(?:", any_alts)
	_embedded = _compile_alts("(?:", emb_alts)


func _build_buckets() -> void:
	_buckets.clear()
	var by_char: Dictionary[String, Array] = {}
	for t: Term in _combined_terms:
		var first: String = t.text[0]
		var chars: String = LEET.get(first, first)
		for dg: String in LEET_DIGRAPHS.get(first, PackedStringArray()):
			chars += dg[0]
		for c: String in chars:
			if not by_char.has(c):
				by_char[c] = []
			if not by_char[c].has(t):
				by_char[c].append(t)
	for c: String in by_char:
		var list: Array[Term] = []
		var alts: PackedStringArray = PackedStringArray()
		for t: Term in by_char[c]:
			list.append(t)
			alts.append("(" + t.pattern + (NOT_WORD_AFTER if t.mode == MODE_EXACT else "") + ")")
		var re: RegEx = _compile_alts("\\G(?:", alts)
		if re != null:
			_buckets[c] = {"re": re, "terms": list}


static func _compile_alts(prefix: String, alts: PackedStringArray) -> RegEx:
	if alts.is_empty():
		return null
	var re := RegEx.new()
	if re.compile("(*UCP)" + prefix + "|".join(alts) + ")") != OK:
		push_error("Profanity regex failed to compile")
		return null
	return re


## Grupo i+1 do regex = list[i].
static func _group_term(m: RegExMatch, list: Array[Term]) -> Term:
	for i: int in list.size():
		if m.get_start(i + 1) >= 0:
			return list[i]
	return null


## Alguma palavra da whitelist cobre [start, end) do texto normalizado?
func _is_whitelisted(sk_text: String, start: int, end: int) -> bool:
	for w: String in whitelist:
		var from: int = maxi(0, end - w.length())
		var at: int = sk_text.find(w, from)
		while at >= 0 and at <= start:
			if at + w.length() >= end:
				return true
			at = sk_text.find(w, at + 1)
	return false


## Junta trechos que se sobrepõem ou encostam (fica um "***" só).
static func _merge(hits: Array[Dictionary]) -> Array[Dictionary]:
	if hits.size() < 2:
		return hits
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start"] < b["start"])
	var out: Array[Dictionary] = [hits[0]]
	for k: int in range(1, hits.size()):
		var last: Dictionary = out[out.size() - 1]
		var h: Dictionary = hits[k]
		if h["start"] <= last["end"]:
			last["end"] = maxi(last["end"], h["end"])
			if h["severity"] > last["severity"]:
				last["severity"] = h["severity"]
				last["category"] = h["category"]
				last["id"] = h["id"]
				last["lang"] = h["lang"]
		else:
			out.append(h)
	return out
