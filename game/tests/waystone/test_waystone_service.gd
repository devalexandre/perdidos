extends Node
## Teste unitário do WaystoneService (Dona Ana), sem servidor: rede de cidades, conhecer ao falar, salvar,
## listar destinos, recusar cidade desconhecida e cobrar quando o custo for > 0. Código 0 = passou.

const PORTO: StringName = &"city_awakening"
const SERRA: StringName = &"city_serra_dourada"
const SUMIDOURO: StringName = &"city_sumidouro"

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var net: Dictionary[StringName, NpcDef] = WaystoneService.network()
	_check(net.has(PORTO) and net.has(SERRA) and net.has(SUMIDOURO), "rede tem as três cidades", net.keys())
	_check(not net.has(&"training_field"), "Campo de Treino fora da rede")
	for map_id: StringName in net:
		var z: ZoneDef = Content.zone(map_id)
		_check(z != null and z.kind == ZoneDef.Kind.CITY, "%s é cidade" % map_id)
		_check(net[map_id].name_key == "NPC_DONA_ANA_NAME" and net[map_id].dialogue.id == WaystoneService.DIALOGUE_ID,
				"%s: NpcDef da Dona Ana (%s)" % [map_id, net[map_id].id])

	var c := CharacterData.create_new("AnaTeste", &"female")
	c.stars = 5
	var s := PlayerSession.new(0, null, c)
	var svc := WaystoneService.new(null)
	_check(WaystoneService.saved_city(c).is_empty(), "personagem novo sem cidade salva")
	_check(WaystoneService.destinations(c, PORTO).is_empty(), "sem cidades conhecidas, sem destinos")

	# Conhecer ao falar.
	svc.on_talk(s, PORTO)
	_check(WaystoneService.knows(c, PORTO) and c.once_flags.has("waystone:city_awakening") and s.save_pending,
			"falar com a Dona Ana do Porto faz o Porto conhecido (once_flags)")
	_check(not WaystoneService.learn(c, PORTO), "conhecer de novo não muda nada")

	# Salvar.
	_check(svc.save_here(s, PORTO) and WaystoneService.saved_city(c) == PORTO, "salvar no Porto")
	svc.on_talk(s, SERRA)
	_check(svc.save_here(s, SERRA) and WaystoneService.saved_city(c) == SERRA, "salvar na Serra troca o ponto salvo")
	var saves: int = c.once_flags.keys().filter(func(k: String) -> bool: return k.begins_with(WaystoneService.SAVE_PREFIX)).size()
	_check(saves == 1, "só um ponto salvo por personagem", saves)
	_check(not svc.save_here(s, &"training_field"), "não salva fora da rede")
	var back: CharacterData = CharacterData.from_save(c.to_save())
	_check(WaystoneService.saved_city(back) == SERRA and WaystoneService.knows(back, PORTO)
			and WaystoneService.knows(back, SERRA) and not WaystoneService.knows(back, SUMIDOURO),
			"ponto salvo e cidades conhecidas sobrevivem ao save")

	# Destinos.
	_check(WaystoneService.destinations(c, SERRA) == [PORTO], "da Serra, lista só o Porto", WaystoneService.destinations(c, SERRA))
	_check(WaystoneService.destinations(c, PORTO) == [SERRA], "do Porto, lista só a Serra")

	# Recusas.
	_check(svc.travel(s, SERRA, SUMIDOURO, 0) == WaystoneService.MSG_UNKNOWN, "recusa cidade desconhecida")
	_check(svc.travel(s, SERRA, &"fields_pindorama", 0) == WaystoneService.MSG_UNKNOWN, "recusa mapa que não é cidade da rede")
	_check(svc.travel(s, SERRA, SERRA, 0) == WaystoneService.MSG_SAME, "recusa viajar para a cidade onde já está")
	c.hp = 0
	_check(svc.travel(s, SERRA, PORTO, 0) == WaystoneService.MSG_DEAD, "caído não viaja")
	c.hp = 100

	# Custo.
	_check(svc.travel(s, SERRA, PORTO, 0) == "" and c.stars == 5, "grátis com custo 0")
	_check(svc.travel(s, SERRA, PORTO, 10) == WaystoneService.MSG_NO_STARS and c.stars == 5,
			"sem Estrelas suficientes: recusa e não cobra")
	c.stars = 50
	_check(svc.travel(s, SERRA, PORTO, 10) == "" and c.stars == 40, "com custo 10: cobra 10 Estrelas", c.stars)
	_check(WaystoneService.travel_cost() == Balance.cfg.waystone_teleport_stars and WaystoneService.travel_cost() >= 0,
			"custo padrão vem do Balance (%d)" % WaystoneService.travel_cost())

	print("test_waystone_service: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String, detail: Variant = null) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description + ("" if detail == null or condition else " -> %s" % str(detail)))
	if not condition:
		_failures += 1
