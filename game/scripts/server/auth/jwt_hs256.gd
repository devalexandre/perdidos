class_name JwtHs256
extends RefCounted
## Verificação de JWT HS256 (o token que a API de contas, launcher/server, entrega no login).
## Só confere: assinatura HMAC-SHA256 com o segredo compartilhado, alg = HS256, exp e account_id.

const ERR_MALFORMED: StringName = &"malformed"
const ERR_SIGNATURE: StringName = &"signature"
const ERR_EXPIRED: StringName = &"expired"
## Tokens maiores que isso são lixo (o nosso tem ~300 bytes).
const MAX_TOKEN_LENGTH: int = 4096


## Resultado: {"ok": bool, "error": StringName, "claims": Dictionary}.
static func verify(token: String, secret: String, now_unix: int) -> Dictionary:
	var fail := func(err: StringName) -> Dictionary:
		return {"ok": false, "error": err, "claims": {}}
	if token.is_empty() or token.length() > MAX_TOKEN_LENGTH or secret.is_empty():
		return fail.call(ERR_MALFORMED)
	var parts: PackedStringArray = token.split(".")
	if parts.size() != 3:
		return fail.call(ERR_MALFORMED)
	var header: Variant = JSON.parse_string(base64url_decode(parts[0]).get_string_from_utf8())
	if typeof(header) != TYPE_DICTIONARY or str((header as Dictionary).get("alg", "")) != "HS256":
		return fail.call(ERR_MALFORMED)
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer()) != OK:
		return fail.call(ERR_MALFORMED)
	ctx.update((parts[0] + "." + parts[1]).to_utf8_buffer())
	var expected: PackedByteArray = ctx.finish()
	var got: PackedByteArray = base64url_decode(parts[2])
	if got.size() != expected.size() or not Crypto.new().constant_time_compare(expected, got):
		return fail.call(ERR_SIGNATURE)
	var claims: Variant = JSON.parse_string(base64url_decode(parts[1]).get_string_from_utf8())
	if typeof(claims) != TYPE_DICTIONARY:
		return fail.call(ERR_MALFORMED)
	var c: Dictionary = claims
	var exp: Variant = c.get("exp")
	var account: Variant = c.get("account_id")
	if typeof(exp) not in [TYPE_INT, TYPE_FLOAT] or typeof(account) not in [TYPE_INT, TYPE_FLOAT] \
			or int(account) <= 0:
		return fail.call(ERR_MALFORMED)
	if now_unix >= int(exp):
		return fail.call(ERR_EXPIRED)
	c["account_id"] = int(account)
	return {"ok": true, "error": &"", "claims": c}


## Base64 URL-safe sem padding (RFC 7515) -> bytes. Entrada inválida -> vazio.
static func base64url_decode(s: String) -> PackedByteArray:
	var b: String = s.replace("-", "+").replace("_", "/")
	while b.length() % 4 != 0:
		b += "="
	return Marshalls.base64_to_raw(b)


## Para testes: assina um token igual ao da API.
static func sign(claims: Dictionary, secret: String) -> String:
	var enc := func(bytes: PackedByteArray) -> String:
		return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")
	var signing: String = enc.call(JSON.stringify({"alg": "HS256", "typ": "JWT"}).to_utf8_buffer()) \
			+ "." + enc.call(JSON.stringify(claims).to_utf8_buffer())
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(signing.to_utf8_buffer())
	return signing + "." + enc.call(ctx.finish())
