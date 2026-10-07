extends Node
## Agente H (GDD §8.1 "Tempo de uso na barra", 28/09/2026): fórmulas de conjuração e recarga
## (CastTiming + Balance "Cast & cooldown"), soma de cast_reduction/cooldown_reduction dos itens
## equipados (CharacterStats) e poções instantâneas.
## Rodar: godot --headless --path game res://tests/progression/test_cast_timing.tscn

const EPS: float = 0.0001
const SCRIPTS: Array[String] = ["res://scripts/client/ui/hotbar.gd", "res://scripts/client/ui/hotbar_hud.gd",
	"res://scripts/client/ui/hotbar_slot.gd", "res://scripts/client/ui/cast_bar.gd",
	"res://scripts/client/ui/cast_bars_overlay.gd", "res://scripts/client/ui/skills_window.gd",
	"res://scripts/client/ui/attributes_window.gd", "res://scripts/server/item_service.gd",
	"res://scripts/server/progression/skill_caster.gd", "res://scripts/server/progression/progression.gd",
	"res://scripts/server/server_world.gd", "res://scripts/shared/net_progress.gd"]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var b: BalanceConfig = Balance.cfg
	_check(is_equal_approx(b.cast_time_per_skill_level, 0.06) and is_equal_approx(b.cast_reduction_per_dex, 0.005)
			and is_equal_approx(b.cast_reduction_per_int, 0.003) and is_equal_approx(b.cast_reduction_attr_cap, 0.5)
			and is_equal_approx(b.cast_reduction_total_cap, 0.6) and is_equal_approx(b.cooldown_reduction_cap, 0.4),
			"constantes do GDD §8.1 no Balance")
	var spark: SkillDef = Content.skill(&"arcane_spark")
	_check(spark != null and spark.cast_time_sec > 0.0, "Faísca tem conjuração base", spark)
	var zero: Dictionary = {&"dex": 0, &"int": 0, &"spi": 0}
	# Nível da skill: menor nível = mais rápida.
	var base: float = spark.cast_time_sec
	_near(CastTiming.skill_cast_sec(spark, 1, zero), base, "nível 1 sem atributos = base")
	_near(CastTiming.skill_cast_sec(spark, 5, zero), base * 1.24, "nível 5 = base × 1,24")
	_near(CastTiming.skill_cast_sec(spark, 10, zero), base * 1.54, "nível 10 = base × 1,54")
	_check(CastTiming.skill_cast_sec(spark, 1, zero) < CastTiming.skill_cast_sec(spark, 2, zero)
			and CastTiming.skill_cast_sec(spark, 2, zero) < CastTiming.skill_cast_sec(spark, 10, zero),
			"conjuração cresce com o nível da skill")
	# Atributos: DES 0,5% e INT 0,3% por ponto, parte de atributos até 50%.
	var s1: Dictionary = {&"dex": 20, &"int": 10}
	_near(CastTiming.cast_attr_reduction(s1), 0.13, "DES 20 + INT 10 = 13%")
	_near(CastTiming.skill_cast_sec(spark, 1, s1), base * 0.87, "conjuração com DES/INT")
	_check(CastTiming.skill_cast_sec(spark, 1, s1) < CastTiming.skill_cast_sec(spark, 1, {&"dex": 5, &"int": 5}),
			"mais DES/INT = conjuração menor")
	var big: Dictionary = {&"dex": 90, &"int": 90}
	_near(CastTiming.cast_attr_reduction(big), 0.5, "parte de atributos limitada a 50%")
	# Itens: cast_reduction (%) soma, total limitado a 60%.
	_near(CastTiming.cast_reduction({&"dex": 20, &"int": 10, &"cast_reduction": 18}), 0.31, "13% + itens 18% = 31%")
	_near(CastTiming.cast_reduction({&"dex": 90, &"int": 90, &"cast_reduction": 30}), 0.6, "total limitado a 60%")
	_near(CastTiming.skill_cast_sec(spark, 10, {&"dex": 90, &"int": 90, &"cast_reduction": 30}), base * 1.54 * 0.4,
			"nível 10 com redução máxima")
	# Chaves String (Net.client_stats vem com StringName, JSON com String): as duas funcionam.
	_near(CastTiming.cast_reduction({"dex": 20, "int": 10, "cast_reduction": 18}), 0.31, "aceita chaves String")
	# Instantânea continua instantânea.
	var strike: SkillDef = Content.skill(&"blade_firm_strike")
	_near(CastTiming.skill_cast_sec(strike, 10, zero), 0.0, "base 0 = instantânea em qualquer nível")
	# Recarga: ESP 0,4% por ponto + itens, até 40%.
	_near(CastTiming.skill_cooldown_sec(spark, zero), spark.cooldown_sec, "recarga sem ESP = base")
	_near(CastTiming.cooldown_reduction({&"spi": 25}), 0.1, "ESP 25 = 10%")
	_near(CastTiming.skill_cooldown_sec(spark, {&"spi": 25, &"cooldown_reduction": 5}), spark.cooldown_sec * 0.85,
			"ESP 25 + itens 5% = 15%")
	_near(CastTiming.cooldown_reduction({&"spi": 200, &"cooldown_reduction": 20}), 0.4, "recarga limitada a 40%")
	# Itens de dados com as reduções novas.
	var wand: ItemDef = Content.item(&"ipe_wand")
	var tome: ItemDef = Content.item(&"simple_tome")
	var neck: ItemDef = Content.item(&"seed_necklace")
	_check(wand.stats.get(&"cast_reduction", 0) == 8 and tome.stats.get(&"cast_reduction", 0) == 10
			and neck.stats.get(&"cooldown_reduction", 0) == 5, "ipê +8%, tomo +10% conjuração; colar +5% recarga")
	var eq := Equipment.new()
	eq.set_slot(&"weapon", ItemStack.create(&"ipe_wand", 1))
	eq.set_slot(&"offhand", ItemStack.create(&"simple_tome", 1))
	eq.set_slot(&"accessory_1", ItemStack.create(&"seed_necklace", 1))
	var st: Dictionary = CharacterStats.compute(5, CharacterStats.base_attributes(), eq)
	_check(int(st[CharacterStats.K_CAST_REDUCTION]) == 18 and int(st[CharacterStats.K_COOLDOWN_REDUCTION]) == 5,
			"CharacterStats soma cast_reduction/cooldown_reduction dos equipados", st)
	var plain: Dictionary = CharacterStats.compute(5, CharacterStats.base_attributes(), Equipment.new())
	_check(CastTiming.skill_cast_sec(spark, 1, st) < CastTiming.skill_cast_sec(spark, 1, plain)
			and CastTiming.skill_cooldown_sec(spark, st) < CastTiming.skill_cooldown_sec(spark, plain),
			"equipar os itens reduz conjuração e recarga")
	var tip: String = UIKit.item_tooltip_text(wand)
	_check(tip.contains("−8%"), "dica do item mostra a redução", tip)
	# Poções: instantâneas, sem recarga; outros usáveis têm tempo.
	for id: StringName in [&"potion_hp_small", &"potion_hp_medium", &"potion_mp_small", &"potion_mp_medium"]:
		var p: ItemDef = Content.item(id)
		_check(CastTiming.is_instant_item(p) and CastTiming.item_cast_sec(p, zero) == 0.0
				and CastTiming.item_cooldown_sec(p, zero) == 0.0 and not p.use_effect.has(&"cooldown_group"),
				"poção %s instantânea e sem recarga" % id)
	var scroll := ItemDef.new()
	scroll.id = &"test_scroll"
	scroll.type = ItemDef.ItemType.CONSUMABLE
	scroll.use_effect = {&"cast_sec": 2.0, &"cooldown_sec": 20.0, &"cooldown_group": &"scroll"}
	_check(not CastTiming.is_instant_item(scroll) and CastTiming.item_group(scroll) == &"scroll", "pergaminho não é poção")
	_near(CastTiming.item_cast_sec(scroll, {&"dex": 20, &"int": 10}), 2.0 * 0.87, "usável: conjuração com DES/INT")
	_near(CastTiming.item_cooldown_sec(scroll, {&"spi": 25}), 18.0, "usável: recarga com ESP")
	var bare := ItemDef.new()
	bare.id = &"test_bare"
	bare.type = ItemDef.ItemType.CONSUMABLE
	_near(CastTiming.item_base_cast_sec(bare), b.item_default_cast_sec, "usável sem dados: conjuração padrão")
	_near(CastTiming.item_base_cooldown_sec(bare), b.item_default_cooldown_sec, "usável sem dados: recarga padrão")
	_check(CastTiming.item_group(bare) == &"test_bare", "grupo padrão = id do item")
	# Texto das dicas (janela de skills).
	var lines: PackedStringArray = SkillsWindow.timing_lines(spark, 3, {&"dex": 20, &"int": 10, &"cast_reduction": 8, &"spi": 25})
	_check(lines.size() == 2 and lines[0].contains("0,") and lines[1].contains("1,35") and lines[0].contains("0,35"), "dica mostra conjuração e recarga efetivas", lines)
	# Os scripts tocados pelo tempo de uso compilam (servidor e cliente).
	for path: String in SCRIPTS:
		var sc: Script = load(path) as Script
		_check(sc != null and sc.can_instantiate(), "compila: " + path)
	print("test_cast_timing: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _near(got: float, want: float, what: String) -> void:
	_check(absf(got - want) < EPS, what, {"got": got, "want": want})


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail)])
	else:
		print("  ok   %s" % what)
