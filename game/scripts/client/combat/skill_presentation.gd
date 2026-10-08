class_name SkillPresentation
extends RefCounted
## Eventos locais de apresentação; não enviam mensagens nem alteram dano no servidor.
##
## Contato visual (08/10/2026): o servidor manda o hit na liberação, mas o projétil/golpe da skill só
## encosta no alvo um pouco depois. O SkillFx avisa await_contact() ao lançar e contact() quando a peça
## encosta; enquanto isso, CombatFx e CombatAudio guardam a reação do alvo (flash, recuo, número, som de
## dor) com defer() e ela sai no mesmo quadro do impacto visual. Sem SkillFx nada é adiado.
class Events extends RefCounted:
	signal impact(caster_id: int, skill_id: StringName, at: Vector3)
static var events: Events = Events.new()
static var visual_owners: int = 0
## Hits que chegam até este tanto depois do contato ainda contam como "da skill" (hitstop).
const RECENT_CONTACT_MS: int = 350

## Conjurador -> msec limite (Time.get_ticks_msec) da espera pelo contato visual.
static var _awaiting: Dictionary[int, int] = {}
## Conjurador -> reações guardadas (Callable) até o contato.
static var _deferred: Dictionary[int, Array] = {}
## Conjurador -> msec do último contato (hits um pouco atrasados pela rede ainda são da skill).
static var _last_contact: Dictionary[int, int] = {}


## A skill do conjurador vai encostar no alvo em até max_sec. Uma espera antiga é solta antes.
static func await_contact(caster_id: int, max_sec: float) -> void:
	release(caster_id)
	_awaiting[caster_id] = Time.get_ticks_msec() + roundi(maxf(max_sec, 0.05) * 1000.0)


static func is_awaiting(caster_id: int) -> bool:
	return _awaiting.has(caster_id) and Time.get_ticks_msec() < _awaiting[caster_id]


## Golpe da skill: esperando o contato ou logo depois dele.
static func is_skill_hit(caster_id: int) -> bool:
	return is_awaiting(caster_id) \
			or Time.get_ticks_msec() - _last_contact.get(caster_id, -RECENT_CONTACT_MS) < RECENT_CONTACT_MS


## Guarda a reação até o contato. false = sem espera (quem chamou executa já).
static func defer(caster_id: int, fn: Callable) -> bool:
	if not is_awaiting(caster_id):
		return false
	if not _deferred.has(caster_id):
		_deferred[caster_id] = []
	_deferred[caster_id].append(fn)
	return true


## A peça encostou: avisa o impacto (som) e solta as reações guardadas no mesmo quadro.
static func contact(caster_id: int, skill_id: StringName, at: Vector3) -> void:
	_awaiting.erase(caster_id)
	_last_contact[caster_id] = Time.get_ticks_msec()
	events.impact.emit(caster_id, skill_id, at)
	_flush(caster_id)


## Encerra a espera sem impacto (cancelou, venceu o prazo, o SkillFx saiu) e solta o que ficou guardado.
static func release(caster_id: int) -> void:
	_awaiting.erase(caster_id)
	_flush(caster_id)


## Esperas vencidas (o projétil sumiu sem chegar): solta as reações para não ficarem presas.
static func flush_expired() -> void:
	var now: int = Time.get_ticks_msec()
	for id: int in _awaiting.keys():
		if now >= _awaiting[id]:
			release(id)


static func release_all() -> void:
	for id: int in _awaiting.keys():
		release(id)
	for id: int in _deferred.keys():
		_flush(id)


static func _flush(caster_id: int) -> void:
	var fns: Array = _deferred.get(caster_id, [])
	_deferred.erase(caster_id)
	for fn: Callable in fns:
		if fn.is_valid():
			fn.call()
