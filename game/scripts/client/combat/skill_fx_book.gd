class_name SkillFxBook
extends RefCounted
## Receitas dos efeitos das skills da Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3.4) e dos estados
## (NetProgress.status_changed). Só dados: o SkillFx interpreta. Folhas em assets/fx/skills/
## (tools/art/fx/fx_*.py). Cada skill tem uma peça-chave própria (prefixo = id da skill).
##
## Passos ("do"):
##   self / on_target / at_pos       peça em pé no conjurador / no alvo (ou conjurador) / no ponto
##   flat_self / flat_pos / flat_dir peça deitada no conjurador / no ponto / virada para a direção;
##                                   "r" = raio (m) em que a folha foi desenhada (escala para o da skill)
##   beam                            faixa deitada do conjurador na direção, esticada no comprimento da linha
##   travel                          peça deitada correndo a linha, deixando "trail" que dura a skill
##   shot                            projétil do conjurador ao alvo ("count", "every", "arc", "low", "trail")
##   drop                            peça caindo do alto sobre o alvo/ponto e "impact" ao chegar
##   scatter                         "n" peças espalhadas na área ("fall" = cai antes, "stay" = s)
##   ring                            "n" peças em volta do conjurador no raio × "r"
##   burst / converge                "n" projéteis do conjurador para fora / de fora para o conjurador
##   dash_trail                      peça no conjurador a cada "every" s por "sec" s (avanço)
##   cast                            peça em laço no conjurador enquanto conjura
##   loop_self                       peça em laço no conjurador por "sec" s
##   look                            o visual de estado da skill (LOOK) no conjurador ("self") ou alvo
## Comuns: "delay" (s), "bias" (m para a câmera), "h" (fração da altura), "arrive_look" (shot: põe o
## LOOK no alvo ao chegar), "flip" (espelha ao acaso), "scale".

const F: float = 0.55   # na frente do corpo
const B: float = -0.45  # atrás do corpo

const BOOK: Dictionary[StringName, Array] = {
	# ---------------------------------------------------------------- Facão Firme / Aroeira / Onça
	&"blade_sharpen": [{"do": "self", "piece": &"blade_sharpen_whet", "bias": F}, {"do": "look", "on": "self"}],
	&"blade_aroeira_reply": [{"do": "look", "on": "self"}],
	&"blade_root_grip": [{"do": "flat_self", "piece": &"blade_root_grip_roots", "r": 2.5, "follow": false}],
	&"blade_thick_bark": [{"do": "look", "on": "self"}],
	&"blade_trunk_call": [{"do": "self", "piece": &"blade_trunk_call_trunk", "bias": B}],
	&"blade_jaguar_leap": [{"do": "shot", "piece": &"blade_jaguar_leap_spirit", "impact": &"blade_jaguar_leap_impact",
		"speed": 16.0, "arc": 0.9}],
	&"blade_claw_rake": [{"do": "on_target", "piece": &"blade_claw_rake_claws", "h": 0.45, "bias": F}],
	&"blade_blood_scent": [{"do": "look", "on": "self"}],
	&"blade_jaguar_roar": [{"do": "self", "piece": &"blade_jaguar_roar_head", "bias": F},
		{"do": "flat_dir", "piece": &"blade_jaguar_roar_cone", "r": 3.0}],
	# ---------------------------------------------------------------- Vaga-lume / Cristal / Boitatá
	&"arcane_firefly_swarm": [{"do": "shot", "piece": &"arcane_firefly_swarm_bug", "impact": &"arcane_firefly_swarm_pop",
		"speed": 8.0, "count": 4, "every": 0.13, "arc": 0.7, "spread": 0.35}],
	&"arcane_shared_crystal": [{"do": "burst", "piece": &"arcane_shared_crystal_shard", "n": 3, "dist": 2.2},
		{"do": "look", "on": "self"}],
	&"arcane_crystal_prison": [{"do": "look", "on": "target"}],
	&"arcane_crystal_wall": [{"do": "ring", "piece": &"arcane_crystal_wall_spike", "n": 8, "r": 0.9}],
	&"arcane_crystal_glow": [{"do": "loop_self", "piece": &"arcane_crystal_glow_gem", "sec": 2.4, "bias": F}],
	&"arcane_star_step": [{"do": "at_caster_pos", "piece": &"arcane_star_step_out", "bias": F},
		{"do": "at_pos", "piece": &"arcane_star_step_in", "bias": F, "delay": 0.25}],
	&"arcane_fire_gaze": [{"do": "self", "piece": &"arcane_fire_gaze_eye", "bias": F},
		{"do": "beam", "piece": &"arcane_fire_gaze_beam", "len": 12.0, "width": 2.3, "delay": 0.15}],
	&"arcane_fire_serpent": [{"do": "travel", "piece": &"arcane_fire_serpent_head", "trail": &"arcane_fire_serpent_trail",
		"every_m": 1.1, "sec": 0.8}],
	&"arcane_ember_eyes": [{"do": "look", "on": "self"}],
	# ---------------------------------------------------------------- Flecha do Cerrado / Brejo / Gavião
	&"bow_low_shot": [{"do": "shot", "piece": &"bow_arrow", "impact": &"bow_arrow_impact", "speed": 26.0, "low": 0.16,
		"trail": &"bow_low_shot_skim", "trail_every": 0.05}],
	&"bow_double_arrow": [{"do": "shot", "piece": &"bow_double_arrow_pair", "impact": &"bow_arrow_impact",
		"speed": 24.0, "impact2": 0.12}],
	&"bow_taut_draw": [{"do": "cast", "piece": &"bow_taut_draw_charge", "bias": F},
		{"do": "shot", "piece": &"bow_taut_draw_arrow", "impact": &"bow_taut_draw_impact", "speed": 30.0}],
	&"bow_warning_arrow": [{"do": "shot", "piece": &"bow_warning_arrow_arrow", "impact": &"bow_arrow_impact",
		"speed": 24.0, "arrive_look": true}],
	&"bow_arrow_flock": [{"do": "scatter", "piece": &"bow_arrow_flock_stuck", "fall": &"bow_arrow_flock_fall", "n": 10,
		"over": 0.5, "fill": 0.85, "stay": 1.6}],
	&"bow_mud_skin": [{"do": "self", "piece": &"bow_mud_skin_splash", "bias": F}, {"do": "look", "on": "self"}],
	&"bow_mud_hide": [{"do": "self", "piece": &"bow_mud_hide_mud", "bias": F}],
	&"bow_ambush_shot": [{"do": "self", "piece": &"bow_ambush_shot_reeds", "bias": F},
		{"do": "shot", "piece": &"bow_arrow", "impact": &"bow_arrow_impact", "speed": 26.0, "delay": 0.45}],
	&"bow_vine_snare": [{"do": "flat_pos", "piece": &"bow_vine_snare_trap", "r": 2.0}],
	&"bow_thorn_arrow": [{"do": "shot", "piece": &"bow_thorn_arrow_arrow", "impact": &"bow_arrow_impact",
		"speed": 24.0, "arrive_look": true}],
	&"bow_still_eye": [{"do": "self", "piece": &"bow_still_eye_eye", "bias": F}, {"do": "look", "on": "self"}],
	&"bow_true_arrow": [{"do": "shot", "piece": &"bow_true_arrow_arrow", "impact": &"bow_true_arrow_pierce",
		"speed": 34.0}],
	&"bow_sure_aim": [{"do": "look", "on": "self"}],
	&"bow_hawk_dive": [{"do": "drop", "piece": &"bow_hawk_dive_hawk", "impact": &"bow_hawk_dive_impact",
		"fall": 0.45, "height": 6.5}],
	&"bow_short_flight": [{"do": "self", "piece": &"bow_short_flight_wings", "bias": B}],
	# ---------------------------------------------------------------- Brasa no Facão
	&"hybrid_spark_blade": [{"do": "look", "on": "self"}],
	&"hybrid_ember_cut": [{"do": "on_target", "piece": &"hybrid_ember_cut_slash", "h": 0.45, "bias": F, "flip": true}],
	&"hybrid_steel_spark": [{"do": "dash_trail", "piece": &"hybrid_steel_spark_trail", "every": 0.06, "sec": 0.35},
		{"do": "on_target", "piece": &"hybrid_steel_spark_impact", "h": 0.45, "bias": F, "delay": 0.22}],
	&"hybrid_sparks": [{"do": "self", "piece": &"hybrid_sparks_anvil", "bias": F},
		{"do": "flat_self", "piece": &"hybrid_sparks_ground", "r": 3.0, "delay": 0.22, "follow": false}],
	&"hybrid_ember_heart": [{"do": "look", "on": "self"}],
	# ---------------------------------------------------------------- Raiz do Cerrado / Buriti / Matinta
	&"support_bottle_brew": [{"do": "self", "piece": &"support_bottle_brew_bottle", "bias": F},
		{"do": "flat_self", "piece": &"support_bottle_brew_ground", "r": 4.0, "delay": 0.35, "follow": false,
			"life": "dur"}],
	&"support_herb_tea": [{"do": "on_target", "piece": &"support_herb_tea_cup", "bias": F}],
	&"support_poultice": [{"do": "on_target", "piece": &"support_poultice_wrap", "bias": F}],
	&"support_pequi_shade": [{"do": "look", "on": "target"}],
	&"support_mutirao": [{"do": "loop_self", "piece": &"support_mutirao_flags", "sec": 3.0, "bias": F},
		{"do": "look", "on": "self"}],
	&"support_broadleaf_tea": [{"do": "on_target", "piece": &"support_broadleaf_tea_leaf", "bias": F}],
	&"support_coconut_water": [{"do": "self", "piece": &"support_coconut_water_coco", "bias": F},
		{"do": "flat_self", "piece": &"support_coconut_water_splash", "r": 6.0, "delay": 0.45, "follow": false}],
	&"support_running_sap": [{"do": "look", "on": "target"}],
	&"support_holding_root": [{"do": "look", "on": "target"}],
	&"support_new_breath": [{"do": "on_target", "piece": &"support_new_breath_wind", "bias": F}],
	&"support_ill_whistle": [{"do": "flat_dir", "piece": &"support_ill_whistle_cone", "r": 4.0}],
	&"support_omen": [{"do": "look", "on": "target"}],
	&"support_owl_cry": [{"do": "at_pos", "piece": &"support_owl_cry_owl", "bias": F},
		{"do": "flat_pos", "piece": &"support_owl_cry_ground", "r": 3.0, "delay": 0.4}],
	&"support_bird_lime": [{"do": "shot", "piece": &"support_bird_lime_blob", "speed": 14.0, "arc": 1.0,
		"arrive_look": true}],
	&"support_bitter_smoke": [{"do": "scatter", "piece": &"support_bitter_smoke_cloud", "n": 7, "over": 0.3,
		"fill": 0.8, "stay": "dur"}],
	# ---------------------------------------------------------------- Jabuti / Anta / Mapinguari
	&"tank_shell_knock": [{"do": "self", "piece": &"tank_shell_knock_shell", "bias": F}],
	&"tank_shell_retreat": [{"do": "look", "on": "self"}],
	&"tank_hard_shell": [{"do": "look", "on": "self"}],
	&"tank_patience": [{"do": "look", "on": "self"}],
	&"tank_shell_bash": [{"do": "flat_dir", "piece": &"tank_shell_bash_cone", "r": 2.0}],
	&"tank_thick_hide": [{"do": "look", "on": "self"}],
	&"tank_tapir_stomp": [{"do": "flat_self", "piece": &"tank_tapir_stomp_print", "r": 2.5, "follow": false}],
	&"tank_tapir_ram": [{"do": "loop_self", "piece": &"tank_tapir_ram_spirit", "sec": 0.45, "bias": B, "face": true},
		{"do": "dash_trail", "piece": &"blade_charge_dust", "every": 0.07, "sec": 0.35},
		{"do": "on_target", "piece": &"tank_tapir_ram_impact", "h": 0.45, "bias": F, "delay": 0.25}],
	&"tank_living_wall": [{"do": "ring", "piece": &"tank_living_wall_stake", "n": 7, "r": 0.9}],
	&"tank_stand_firm": [{"do": "look", "on": "self"}],
	&"tank_fury": [{"do": "look", "on": "self"}],
	&"tank_mapinguari_howl": [{"do": "self", "piece": &"tank_mapinguari_howl_mouth", "bias": F},
		{"do": "flat_self", "piece": &"tank_mapinguari_howl_ground", "r": 4.0, "delay": 0.15, "follow": false}],
	&"tank_heavy_claws": [{"do": "self", "piece": &"tank_heavy_claws_rend", "bias": F, "ahead": 0.9},
		{"do": "flat_dir", "piece": &"tank_heavy_claws_marks", "r": 2.0}],
	&"tank_battle_thirst": [{"do": "converge", "piece": &"tank_battle_thirst_drop", "n": 4, "dist": 2.2},
		{"do": "look", "on": "self"}],
	&"tank_last_blow": [{"do": "on_target", "piece": &"tank_last_blow_smash", "bias": F}],
	# ---------------------------------------------------------------- Companheiros (PETS-E-MONTARIAS §0.1)
	# Só peças que já existem (reaproveitadas): vínculo do dono e magias automáticas dos bichos.
	&"bow_companion_hawk_strike": [{"do": "drop", "piece": &"bow_hawk_dive_hawk", "impact": &"bow_hawk_dive_impact",
		"fall": 0.35, "height": 5.0}],
	&"bow_companion_sky_eye": [{"do": "self", "piece": &"bow_still_eye_eye", "bias": F}],
	&"bow_companion_guara_bite": [{"do": "on_target", "piece": &"blade_claw_rake_claws", "h": 0.3, "bias": F}],
	&"bow_companion_guara_track": [{"do": "shot", "piece": &"bow_warning_arrow_arrow", "impact": &"bow_arrow_impact",
		"speed": 24.0, "arrive_look": true}],
	&"arcane_companion_lume_light": [{"do": "loop_self", "piece": &"arcane_crystal_glow_gem", "sec": 1.6, "bias": F}],
	&"arcane_companion_lume_guide": [{"do": "burst", "piece": &"arcane_firefly_swarm_bug", "n": 5, "dist": 2.6}],
	&"comp_harpy_feather_gust": [{"do": "scatter", "piece": &"bow_arrow_flock_stuck", "fall": &"bow_arrow_flock_fall",
		"n": 5, "over": 0.3, "fill": 0.8, "stay": 0.8}],
	&"comp_harpy_high_cry": [{"do": "on_target", "piece": &"bow_still_eye_eye", "h": 0.9, "bias": F},
		{"do": "look", "on": "target"}],
	&"comp_harpy_royal_dive": [{"do": "drop", "piece": &"bow_hawk_dive_hawk", "impact": &"bow_hawk_dive_impact",
		"fall": 0.45, "height": 6.5}],
	&"comp_guara_howl": [{"do": "flat_pos", "piece": &"blade_root_grip_roots", "r": 2.5}],
	&"comp_guara_pounce": [{"do": "on_target", "piece": &"blade_jaguar_leap_impact", "h": 0.45, "bias": F}],
	&"comp_guara_deep_bite": [{"do": "on_target", "piece": &"blade_claw_rake_claws", "h": 0.35, "bias": F, "flip": true}],
	&"comp_lume_spark": [{"do": "shot", "piece": &"arcane_firefly_swarm_bug", "impact": &"arcane_firefly_swarm_pop",
		"speed": 10.0, "arc": 0.5}],
	&"comp_lume_heal": [{"do": "loop_self", "piece": &"arcane_crystal_glow_gem", "sec": 1.0, "bias": F}],
	&"comp_lume_swarm": [{"do": "shot", "piece": &"arcane_firefly_swarm_bug", "impact": &"arcane_firefly_swarm_pop",
		"speed": 8.0, "count": 4, "every": 0.13, "arc": 0.7, "spread": 0.35}],
}

## Visual de estado de cada skill (em quem recebe o efeito): peças, alturas (fração) e profundidade.
## Usado pelo passo "look" e por NetProgress.status_changed. "mark" = marca sobre a cabeça (fila).
const LOOK: Dictionary[StringName, Dictionary] = {
	&"blade_iron_stance": {"p": [&"blade_iron_stance_back", &"blade_iron_stance_glow", &"blade_iron_stance_front"],
		"b": [B, F * 0.5, F]},
	&"arcane_barrier": {"p": [&"arcane_barrier_shield"], "b": [F]},
	&"blade_sharpen": {"p": [&"status_aura_atk"], "b": [F]},
	&"blade_aroeira_reply": {"p": [&"blade_aroeira_reply_guard"], "b": [F]},
	&"blade_thick_bark": {"p": [&"blade_thick_bark_back", &"blade_thick_bark_front"], "b": [B, F]},
	&"blade_blood_scent": {"p": [&"status_aura_crit", &"blade_blood_scent_eyes"], "b": [F, F]},
	&"blade_jaguar_roar": {"mark": &"atk_down"},
	&"arcane_shared_crystal": {"p": [&"arcane_shared_crystal_back", &"arcane_shared_crystal_front"], "b": [B, F]},
	&"arcane_crystal_prison": {"p": [&"arcane_crystal_prison_back", &"arcane_crystal_prison_front"], "b": [B, F]},
	&"arcane_crystal_wall": {"p": [&"status_aura_guard"], "b": [F]},
	&"arcane_crystal_glow": {"p": [&"status_aura_mana"], "b": [F]},
	&"arcane_ember_eyes": {"p": [&"status_aura_matk", &"arcane_ember_eyes_glow"], "b": [F, F]},
	&"bow_warning_arrow": {"mark": &"vuln"},
	&"comp_harpy_high_cry": {"mark": &"vuln"},
	&"bow_mud_skin": {"p": [&"status_aura_evade"], "b": [F]},
	&"bow_thorn_arrow": {"mark": &"poison"},
	&"bow_still_eye": {"p": [&"status_aura_crit"], "b": [F]},
	&"bow_sure_aim": {"p": [&"bow_sure_aim_back", &"bow_sure_aim_front"], "b": [B, F]},
	&"hybrid_spark_blade": {"p": [&"hybrid_spark_blade_edge"], "b": [F]},
	&"hybrid_ember_cut": {"burn": true},
	&"hybrid_ember_heart": {"p": [&"status_aura_atk", &"hybrid_ember_heart_core"], "b": [F, F]},
	&"support_bottle_brew": {"p": [&"status_aura_regen"], "b": [F]},
	&"support_pequi_shade": {"p": [&"support_pequi_shade_tree"], "b": [F]},
	&"support_mutirao": {"p": [&"status_aura_atk"], "b": [F]},
	&"support_running_sap": {"p": [&"support_running_sap_flow"], "b": [F]},
	&"support_holding_root": {"p": [&"support_holding_root_back", &"support_holding_root_front"], "b": [B, F]},
	&"support_ill_whistle": {"mark": &"def_down"},
	&"support_omen": {"p": [&"support_omen_bird"], "h": [0.35], "b": [F]},
	&"support_owl_cry": {"mark": &"slow"},
	&"support_bird_lime": {"p": [&"support_bird_lime_glue"], "b": [F]},
	&"support_bitter_smoke": {"mark": &"heal_down"},
	&"tank_shell_retreat": {"p": [&"tank_shell_retreat_dome"], "b": [F]},
	&"tank_hard_shell": {"p": [&"tank_hard_shell_back"], "b": [B]},
	&"tank_patience": {"p": [&"status_aura_regen", &"tank_patience_jabuti"], "b": [F, F]},
	&"tank_thick_hide": {"p": [&"tank_thick_hide_back", &"tank_thick_hide_front"], "b": [B, F]},
	&"tank_living_wall": {"p": [&"status_aura_guard"], "b": [F]},
	&"tank_stand_firm": {"p": [&"tank_stand_firm_stones"], "b": [F]},
	&"tank_fury": {"p": [&"tank_fury_rage"], "b": [B]},
	&"tank_mapinguari_howl": {"mark": &"def_down"},
	&"tank_battle_thirst": {"p": [&"status_aura_lifesteal"], "b": [F]},
	&"arcane_frost_burst": {"p": [&"arcane_frost_burst_chill"], "b": [F], "key": &"chill"},
}

## Visual genérico por status_id (quando a skill não tem LOOK próprio).
const STATUS_GENERIC: Dictionary[StringName, Dictionary] = {
	&"stun": {"p": [&"blade_charge_stun"], "h": [1.02], "b": [F], "key": &"stun"},
	&"root": {"p": [&"status_root_back", &"status_root_front"], "b": [B, F], "key": &"root"},
	&"taunt": {"p": [&"status_taunt"], "h": [1.0], "b": [F], "key": &"taunt"},
	&"slow": {"mark": &"slow"},
	&"dot": {"mark": &"poison"},
	&"hot": {"p": [&"status_aura_regen"], "b": [F], "key": &"hot"},
	&"mp_regen": {"p": [&"status_aura_mana"], "b": [F], "key": &"mp_regen"},
	&"shield": {"p": [&"arcane_barrier_shield"], "b": [F], "key": &"shield"},
	&"def_buff": {"p": [&"status_aura_def"], "b": [F], "key": &"def_buff"},
	&"counter": {"p": [&"blade_aroeira_reply_guard"], "b": [F], "key": &"counter"},
	&"buff": {"p": [&"status_aura_atk"], "b": [F], "key": &"buff"},
	&"debuff": {"mark": &"debuff"},
}

## Reforço/enfraquecimento genérico: a aura/marca sai da primeira chave de mods em SkillDef.extra.
const BUFF_BY_MOD: Array = [[&"lifesteal", &"status_aura_lifesteal"], [&"crit", &"status_aura_crit"],
	[&"range_cells", &"status_aura_crit"], [&"evade", &"status_aura_evade"], [&"dmg_taken_pct", &"status_aura_guard"],
	[&"def_pct", &"status_aura_def"], [&"matk_pct", &"status_aura_matk"], [&"atk_pct", &"status_aura_atk"]]
const DEBUFF_BY_MOD: Array = [[&"heal_received_pct", &"heal_down"], [&"dmg_taken_pct", &"vuln"],
	[&"def_pct", &"def_down"], [&"atk_pct", &"atk_down"], [&"matk_pct", &"atk_down"]]

## Peça de impacto em cada golpe da skill (NetCombat.hit dentro da janela do lançamento).
const HIT: Dictionary[StringName, StringName] = {
	&"blade_root_grip": &"blade_charge_impact", &"blade_trunk_call": &"blade_firm_strike_impact",
	&"blade_jaguar_roar": &"blade_jaguar_leap_impact", &"bow_arrow_flock": &"bow_arrow_impact",
	&"hybrid_sparks": &"hybrid_steel_spark_impact", &"tank_shell_bash": &"tank_tapir_ram_impact",
	&"tank_tapir_stomp": &"tank_tapir_ram_impact", &"tank_heavy_claws": &"blade_claw_rake_claws",
	&"support_ill_whistle": &"status_mark_debuff", &"arcane_fire_gaze": &"arcane_will_o_wisp_impact",
	&"arcane_fire_serpent": &"arcane_will_o_wisp_impact"}

## Escola pelo começo do id (a escola vem do SkillDef; isto é a reserva para cor e ícone).
const SCHOOL_BY_PREFIX: Dictionary[String, StringName] = {
	"blade_": &"blade", "arcane_": &"arcane", "bow_": &"bow", "hybrid_": &"hybrid", "support_": &"support",
	"tank_": &"tank"}


static func school_of(def: SkillDef) -> StringName:
	if def == null:
		return &""
	if not def.school.is_empty():
		return def.school
	for p: String in SCHOOL_BY_PREFIX:
		if String(def.id).begins_with(p):
			return SCHOOL_BY_PREFIX[p]
	return &""
