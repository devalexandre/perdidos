extends Node
## Testes headless de chefes, dia e noite e forma atroz (docs/chefes-dia-noite.md):
##  - WorldClock (ciclo, virada, rampa da luz, força, Campo de Treino sempre de dia);
##  - MonsterEvolution / MonsterDef com o estágio 4 (fora da evolução, multiplicador);
##  - MonsterBrain.set_atroz (atributos +100%, proporção da vida, estágio de evolução 3, volta);
##  - covis fixos (regra de zona, 3 chefes de Pindorama na Subida Vermelha);
##  - dados reais: forma atroz das espécies de Pindorama e itens raros só em raro/chefe/atroz.
## O fluxo em rede fica em tests/monsters/run_night_test.sh.
## Rodar: godot --headless --path game res://tests/monsters/test_night.tscn

const EPS: float = 0.0001
const PINDORAMA_RARE_ITEMS: Dictionary[StringName, StringName] = {&"stone_armadillo": &"ancient_shell_shard",
		&"enchanted_firefly": &"eternal_ember", &"prank_whirlwind": &"pequi_root"}

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_test_clock()
	_test_evolution_with_atroz()
	_test_brain_atroz()
	_test_lair_rules()
	_test_real_data()
	_test_new_pindorama_species()
	_test_special_weapon_drops()
	print("test_monsters_night: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])


func _cfg(day: float, night: float, transition: float) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.day_night_day_sec = day
	c.day_night_night_sec = night
	c.day_night_transition_sec = transition
	return c


func _test_clock() -> void:
	_check(is_equal_approx(Balance.cfg.day_night_day_sec, 2400.0) and is_equal_approx(Balance.cfg.day_night_night_sec, 1200.0),
			"padrão: 40 min de dia e 20 de noite", [Balance.cfg.day_night_day_sec, Balance.cfg.day_night_night_sec])
	var c: BalanceConfig = _cfg(100.0, 50.0, 10.0)
	_check(is_equal_approx(WorldClock.cycle_sec(c), 150.0), "ciclo = dia + noite")
	_check(not WorldClock.is_night(0.0, c) and not WorldClock.is_night(99.9, c), "dia de 0 a 100")
	_check(WorldClock.is_night(100.0, c) and WorldClock.is_night(149.9, c), "noite de 100 a 150")
	_check(not WorldClock.is_night(150.0, c) and not WorldClock.is_night(-10.0, c) == false,
			"ciclo dá a volta (150 = amanhecer; -10 = fim da noite)")
	_check(is_equal_approx(WorldClock.time_of_cycle(310.0, c), 10.0), "tempo do ciclo com várias voltas")
	# rampa da luz: dia pleno, noite plena, meio da virada, monotônica no anoitecer
	_check(WorldClock.night_amount(50.0, c) < EPS, "meio do dia = 0")
	_check(absf(WorldClock.night_amount(125.0, c) - 1.0) < EPS, "meio da noite = 1")
	_check(absf(WorldClock.night_amount(100.0, c) - 0.5) < 0.01, "virada do anoitecer = 0,5")
	_check(absf(WorldClock.night_amount(150.0, c) - 0.5) < 0.01 and absf(WorldClock.night_amount(0.0, c) - 0.5) < 0.01,
			"virada do amanhecer = 0,5")
	var mono: bool = true
	var prev: float = -1.0
	for i: int in range(21):
		var v: float = WorldClock.night_amount(95.0 + float(i) * 0.5, c)
		mono = mono and v >= prev - EPS
		prev = v
	_check(mono and WorldClock.night_amount(94.9, c) < EPS and WorldClock.night_amount(105.1, c) > 1.0 - EPS,
			"anoitecer suave e dentro da transição")
	var dawn_ok: bool = WorldClock.night_amount(144.9, c) > 1.0 - EPS and WorldClock.night_amount(5.1, c) < EPS \
			and WorldClock.night_amount(147.0, c) > WorldClock.night_amount(3.0, c)
	_check(dawn_ok, "amanhecer suave")
	_check(is_equal_approx(WorldClock.sec_to_next_turn(40.0, c), 60.0) and is_equal_approx(WorldClock.sec_to_next_turn(120.0, c), 30.0),
			"segundos até a virada")
	_check(WorldClock.is_night(WorldClock.forced_time(10.0, WorldClock.Force.NIGHT, c), c), "forçar noite")
	_check(not WorldClock.is_night(WorldClock.forced_time(120.0, WorldClock.Force.DAY, c), c), "forçar dia")
	_check(is_equal_approx(WorldClock.forced_time(33.0, WorldClock.Force.NONE, c), 33.0), "sem força = relógio")
	_check(WorldClock.clock_text(0.0, c) == "06:00" and WorldClock.clock_text(100.0, c) == "18:00"
			and WorldClock.clock_text(125.0, c) == "00:00", "hora do relógio", [WorldClock.clock_text(125.0, c)])
	var lunar_day: float = 86400.0
	_check(WorldClock.lunar_phase_index(0.0) == 0
			and WorldClock.lunar_phase_index(lunar_day * 1.75) == 1
			and WorldClock.lunar_phase_index(lunar_day * 3.0) == 2
			and WorldClock.lunar_phase_index(lunar_day * 5.0) == 2
			and WorldClock.lunar_phase_index(lunar_day * 6.0) == 3
			and WorldClock.lunar_phase_index(lunar_day * 7.0) == 0, "ciclo lunar global de sete dias")
	_check(WorldClock.is_full_moon_night(lunar_day * 3.0, true)
			and not WorldClock.is_full_moon_night(lunar_day * 3.0, false), "lua cheia só habilita encontro à noite")
	# Campo de Treino sempre de dia (a menos que a noite seja forçada); cidade segue o relógio.
	var tc: BalanceConfig = _cfg(100.0, 50.0, 10.0)
	tc.day_night_training_always_day = true
	_check(not WorldClock.map_follows_clock(&"training_field", WorldClock.Force.NONE, tc), "treino sempre de dia")
	_check(WorldClock.map_follows_clock(&"training_field", WorldClock.Force.NIGHT, tc), "noite forçada vale no treino")
	_check(WorldClock.map_follows_clock(&"city_awakening", WorldClock.Force.NONE, tc), "Porto segue o relógio")
	tc.day_night_training_always_day = false
	_check(WorldClock.map_follows_clock(&"training_field", WorldClock.Force.NONE, tc), "opção: treino com noite")


func _stage(n: int, evolve: int, hp: int, atk: int) -> MonsterStage:
	var st := MonsterStage.new()
	st.stage = n
	st.max_hp = hp
	st.atk = atk
	st.def = atk / 2
	st.mdef = atk / 3
	st.matk = atk / 4
	st.level = n * 5
	st.name_key = "T_%d" % n
	return st


func _def_with_atroz() -> MonsterDef:
	var d := MonsterDef.new()
	d.id = &"t_night"
	var s4 := _stage(4, 0, 1, 1)
	s4.attack_interval_ms = 700
	s4.leash_cells = 30
	d.stages = [_stage(1, 0, 100, 10), _stage(2, 200, 400, 20), _stage(3, 1000, 1000, 50), s4]
	return d


func _test_evolution_with_atroz() -> void:
	var d: MonsterDef = _def_with_atroz()
	_check(d.atroz_stage() != null and d.atroz_stage().stage == MonsterEvolution.STAGE_ATROZ, "atroz_stage() acha o 4")
	_check(is_equal_approx(MonsterEvolution.atroz_multiplier(d), Balance.cfg.atroz_stat_multiplier), "multiplicador padrão")
	_check(is_equal_approx(Balance.cfg.atroz_stat_multiplier, 2.0), "atroz = +100% (Balance)")
	d.atroz_stat_multiplier = 3.0
	_check(is_equal_approx(MonsterEvolution.atroz_multiplier(d), 3.0), "multiplicador por espécie")
	_check(is_equal_approx(Balance.cfg.boss_respawn_sec, 600.0), "chefe do covil renasce em 10 min (Balance)")


func _test_brain_atroz() -> void:
	var d: MonsterDef = _def_with_atroz()
	var b := MonsterBrain.new()
	b.def = d
	b.stage = d.stages[2]
	b.hp = 500 # metade da vida do chefe
	_check(b.max_hp() == 1000 and b.is_boss() and not b.atroz, "chefe normal")
	var atk0: int = int(b.combat_stats()[&"atk"])
	_check(b.set_atroz(true), "vira atroz")
	_check(b.atroz and b.stage.stage == 4 and b.evolution_stage() == 3 and b.is_boss(), "atroz: estágio 4, conta como 3")
	_check(b.max_hp() == 2000 and int(b.combat_stats()[&"atk"]) == atk0 * 2, "atroz: vida e ATQ × 2",
			[b.max_hp(), b.combat_stats()])
	_check(b.hp == 1000, "atroz mantém a proporção da vida", b.hp)
	_check(b.stage.attack_interval_ms == 700 and b.stage.leash_cells == 30, "atroz: golpe mais rápido e coleira maior")
	b.rare = true
	_check(b.max_hp() == roundi(1000.0 * Balance.cfg.rare_stat_multiplier * 2.0), "raro e atroz se somam", b.max_hp())
	b.rare = false
	_check(b.set_atroz(false) and not b.atroz and b.stage.stage == 3 and b.max_hp() == 1000 and b.hp == 500,
			"volta a chefe normal", [b.stage.stage, b.hp])
	# Relógio: anoitece -> atroz (mesmo em luta); amanhece -> só volta fora de combate. Treino: sempre dia.
	var old_force: int = DayNight.force
	b._map_id = &"city_awakening"
	b.state = MonsterBrain.State.CHASE
	DayNight.force = WorldClock.Force.NIGHT
	b.update_atroz()
	_check(b.atroz, "anoiteceu: chefe em luta vira atroz")
	DayNight.force = WorldClock.Force.DAY
	b.update_atroz()
	_check(b.atroz, "amanheceu em luta: continua atroz")
	b.state = MonsterBrain.State.RETURN
	b.update_atroz()
	_check(not b.atroz and b.stage.stage == 3, "amanheceu fora de luta: volta a chefe (não some)")
	b.atroz_pinned = true
	b.update_atroz()
	_check(b.atroz, "comando de teste: atroz fixo de dia")
	b.atroz_pinned = false
	b.set_atroz(false)
	DayNight.force = WorldClock.Force.NONE
	var at_night: bool = DayNight.is_night_on_map(&"training_field")
	b._map_id = &"training_field"
	b.state = MonsterBrain.State.IDLE
	b.update_atroz()
	_check(not at_night and not b.atroz, "Campo de Treino: nunca atroz pelo relógio")
	DayNight.force = old_force
	b.stage = d.stages[1]
	_check(not b.set_atroz(true) and not b.atroz, "só o chefe vira atroz")
	var nd: MonsterDef = _def_with_atroz()
	nd.stages = [nd.stages[0], nd.stages[1], nd.stages[2]]
	b.def = nd
	b.stage = nd.stages[2]
	_check(not b.set_atroz(true), "espécie sem estágio 4 não vira atroz")
	b.free()


## Chefes fixos: covil só onde a zona aceita chefe; nunca no Campo de Treino; sem contagem de abates.
func _test_lair_rules() -> void:
	var training := ZoneDef.new()
	training.kind = ZoneDef.Kind.TRAINING
	training.bosses_allowed = true
	var hunt := ZoneDef.new()
	hunt.kind = ZoneDef.Kind.HUNT
	hunt.bosses_allowed = true
	var calm := ZoneDef.new()
	calm.kind = ZoneDef.Kind.HUNT
	calm.bosses_allowed = false
	_check(not MonsterSpawner.zone_allows_bosses(training, 3), "Campo de Treino nunca tem covil")
	_check(MonsterSpawner.zone_allows_bosses(hunt, 3), "Chapada (teto 3, bosses_allowed) tem covil")
	_check(not MonsterSpawner.zone_allows_bosses(hunt, 2), "teto 2 não tem chefe")
	_check(not MonsterSpawner.zone_allows_bosses(calm, 3), "bosses_allowed = false não tem chefe")
	_check(not ResourceLoader.exists("res://scripts/server/monsters/boss_kill_tracker.gd"), "sem chefe por contagem de abates")
	# Os 3 chefes de Pindorama têm covil fixo na Subida Vermelha (quests dos anciãos).
	var map: Node = (load("res://scenes/maps/split_sky_plateau.tscn") as PackedScene).instantiate()
	var lairs: Node = map.get_node_or_null(MonsterSpawner.LAIRS_NODE)
	var found: Array[StringName] = []
	if lairs != null:
		for m: Node in lairs.get_children():
			found.append(MonsterDef.species_of(StringName(str(m.get_meta(&"monster_id", "")))))
	for sp: StringName in [&"stone_armadillo", &"enchanted_firefly", &"prank_whirlwind"]:
		_check(sp in found, "covil fixo do chefe %s na Subida Vermelha" % sp, found)
	var spawns: Node = map.get_node_or_null(MonsterSpawner.SPAWNS_NODE)
	var boss_markers: int = 0
	for m: Node in spawns.get_children() if spawns != null else []:
		if int(m.get_meta(&"stage", 1)) >= 3:
			boss_markers += 1
	_check(boss_markers == 0, "Spawns comuns sem chefe (chefe só no covil)", boss_markers)
	map.free()


func _drops_items(st: MonsterStage) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: DropEntry in st.drops:
		out.append(e.item_id)
	return out


func _chance_of(entries: Array[DropEntry], item: StringName) -> float:
	var c: float = 0.0
	for e: DropEntry in entries:
		if e.item_id == item:
			c = maxf(c, e.chance)
	return c


func _test_real_data() -> void:
	for mid: StringName in PINDORAMA_RARE_ITEMS:
		var d: MonsterDef = Content.monster(mid)
		if not _check_bool(d != null, "espécie %s existe" % mid):
			continue
		var boss: MonsterStage = MonsterEvolution.stage_by_number(d, 3)
		var at: MonsterStage = d.atroz_stage()
		if not _check_bool(boss != null and at != null, "%s tem chefe e forma atroz" % mid):
			continue
		var item: StringName = PINDORAMA_RARE_ITEMS[mid]
		_check(Content.item(item) != null, "item raro %s existe" % item)
		_check(Content.item(item) != null and Content.item(item).rarity == ItemDef.Rarity.RARE, "%s é raro" % item)
		_check(TranslationServer.translate(at.name_key) != at.name_key, "nome da forma atroz de %s traduzido" % mid)
		_check(at.name_key != boss.name_key and at.sprite_base != "", "atroz de %s tem nome e folhas próprios" % mid)
		_check(at.aggressive and at.aggro_range_cells > boss.aggro_range_cells and at.leash_cells > boss.leash_cells
				and at.attack_interval_ms < boss.attack_interval_ms and at.walk_ms_per_cell <= boss.walk_ms_per_cell,
				"atroz de %s é mais agressiva (aggro, coleira, golpe, passo)" % mid)
		_check(at.xp_reward > boss.xp_reward and at.stars_max > boss.stars_max and at.level > boss.level,
				"atroz de %s dá mais XP/Estrelas" % mid)
		var cb: float = _chance_of(boss.drops, item)
		var ca: float = _chance_of(at.drops, item)
		var cr: float = _chance_of(d.rare_extra_drops, item)
		_check(cb > 0.0 and ca > cb and cr > 0.0, "%s: raro, chefe e atroz (maior) deixam %s" % [mid, item], [cr, cb, ca])
		for st: MonsterStage in d.stages:
			if st.stage < 3:
				_check(item not in _drops_items(st), "%s: estágio %d comum não deixa %s" % [mid, st.stage, item])
		for e: DropEntry in boss.drops:
			if e.item_id != item:
				_check(_chance_of(at.drops, e.item_id) >= e.chance, "atroz de %s: %s com chance >= chefe" % [mid, e.item_id])
		var sheet: String = at.sprite_base + "_idle.png"
		_check(ResourceLoader.exists(sheet), "folha da forma atroz existe: %s" % sheet)
		if not at.sprite_base.ends_with("_s4"):
			print("  (aviso) %s ainda usa folhas do chefe: %s" % [mid, at.sprite_base])


func _check_bool(ok: bool, what: String) -> bool:
	_check(ok, what)
	return ok


func _test_new_pindorama_species() -> void:
	for mid: String in ["buriti_boar", "cinder_serpent", "ember_mule", "highland_buriti_boar", "highland_cinder_serpent", "highland_ember_mule"]:
		var d: MonsterDef = Content.monster(StringName(mid))
		if not _check_bool(d != null, "%s registered" % mid):
			continue
		var boss: MonsterStage = MonsterEvolution.stage_by_number(d, 3)
		var at: MonsterStage = d.atroz_stage()
		if not _check_bool(boss != null and at != null, "%s has boss and atrocious form" % mid):
			continue
		for st: MonsterStage in d.stages:
			for animation: String in ["idle", "walk", "attack", "hit", "death"]:
				_check(ResourceLoader.exists(st.sprite_base + "_" + animation + ".png"), "%s stage %d %s sprite" % [mid, st.stage, animation])
			_check(TranslationServer.translate(st.name_key) != st.name_key, "%s translated stage name" % mid)
		_check(at.attack_interval_ms < boss.attack_interval_ms and at.aggro_range_cells > boss.aggro_range_cells, "%s atroz more aggressive" % mid)
		_check(at.xp_reward > boss.xp_reward and at.stars_max > boss.stars_max, "%s atroz rewards" % mid)
		var brain := MonsterBrain.new()
		brain.def = d
		brain.stage = boss
		brain.hp = boss.max_hp
		_check(brain.set_atroz(true) and brain.stage == at and brain.max_hp() > boss.max_hp, "%s night transformation" % mid)
		_check(brain.set_atroz(false) and brain.stage == boss, "%s returns to boss at dawn" % mid)
		brain.free()


func _test_special_weapon_drops() -> void:
	var ordinary: Dictionary = CombatService.special_weapon_drop(2, false)
	var boss: Dictionary = CombatService.special_weapon_drop(3, false)
	var atroz: Dictionary = CombatService.special_weapon_drop(3, true)
	_check(ordinary.is_empty(), "monstro comum não tem drop de arma especial", ordinary)
	_check(boss.get("item") == CombatService.BOSS_WEAPON_DROP_ID
			and is_equal_approx(float(boss.get("chance", 0.0)), CombatService.BOSS_WEAPON_DROP_CHANCE),
			"chefe seleciona a Lâmina do Vendaval com chance configurada", boss)
	_check(atroz.get("item") == CombatService.ATROZ_WEAPON_DROP_ID
			and is_equal_approx(float(atroz.get("chance", 0.0)), CombatService.ATROZ_WEAPON_DROP_CHANCE),
			"atroz seleciona o Cajado da Alma Atroz com chance configurada", atroz)
	_check(float(atroz.get("chance", 0.0)) > float(boss.get("chance", 0.0)), "atroz tem chance maior que chefe")
	var boss_item: ItemDef = Content.item(CombatService.BOSS_WEAPON_DROP_ID)
	var atroz_item: ItemDef = Content.item(CombatService.ATROZ_WEAPON_DROP_ID)
	_check(boss_item != null and boss_item.rarity == ItemDef.Rarity.RARE, "arma de chefe existe e é rara")
	_check(atroz_item != null and atroz_item.rarity == ItemDef.Rarity.EPIC, "arma atroz existe e é épica")
