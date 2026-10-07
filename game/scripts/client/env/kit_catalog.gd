class_name KitCatalog
extends RefCounted
## Catálogo do kit de cenário: nome lógico ("tree_conifer_a", "bush_round_a", ...) → malhas reais
## (assets/environment/painted/meshes/*.res) + fator de escala. Os construtores de mapa usam nomes lógicos; o
## catálogo escolhe a variante (determinística pela posição) e a malha certa — hoje, na maioria, modelos dos
## pacotes CC0 convertidos por tools/art/env_kit/build_pack_kit.gd (ver assets/environment/LICENSES.md).
## Trocar o visual de um tipo de árvore em todos os mapas = mudar uma linha aqui e reconstruir os mapas.

const MESH_DIR := "res://assets/environment/painted/meshes/"

## nome lógico: [[malha, escala], ...] (uma é sorteada por instância)
const ALIAS := {
	"tree_conifer_a": [["pk_pine_1", 1.0], ["pk_pine_3", 1.05], ["pk_pine_5", 0.95]],
	"tree_conifer_b": [["pk_pine_2", 1.1], ["pk_pine_4", 0.95]],
	"tree_conifer_c": [["pk_pine_3", 0.85], ["pk_pine_1", 0.8]],
	"tree_conifer_snow_a": [["pk_pine_snow_1", 1.0], ["pk_pine_snow_3", 1.0], ["pk_pine_snow_4", 0.85]],
	"tree_broadleaf_a": [["pk_tree_common_1", 0.9], ["pk_tree_common_2", 0.9], ["pk_tree_common_3", 0.8],
		["pk_tree_common_4", 0.8], ["pk_tree_common_5", 0.95]],
	"tree_ipe_yellow_a": [["pk_ipe_yellow_1", 0.95], ["pk_ipe_yellow_2", 0.95], ["pk_ipe_yellow_3", 0.85],
		["pk_ipe_yellow_5", 1.0]],
	"tree_ipe_purple_a": [["pk_ipe_purple_1", 0.95], ["pk_ipe_purple_2", 0.95], ["pk_ipe_purple_3", 0.85],
		["pk_ipe_purple_5", 1.0]],
	"tree_ipe_yellow_giant": [["pk_ipe_giant", 0.68]],
	"tree_sakura_a": [["pk_sakura_1", 1.0], ["pk_sakura_2", 1.0]],
	"tree_olive_a": [["pk_olive_1", 1.0]],
	"tree_birch_a": [["pk_birch_1", 1.0], ["pk_birch_2", 1.0]],
	"tree_jungle_a": [["pk_jungle_1", 0.62], ["pk_jungle_2", 0.66]],
	"tree_pequi_a": [["pk_pequi_1", 1.0]],
	"tree_twisted_a": [["pk_twisted_1", 0.7], ["pk_twisted_3", 0.7]],
	"palm_date_a": [["palm_soft_a", 1.0], ["palm_soft_b", 1.0]],
	"palm_buriti_a": [["buriti_soft_a", 1.0], ["buriti_soft_b", 1.0]],
	"bush_round_a": [["pk_bush", 1.2], ["pk_bush_flowers", 1.2]],
	"bush_conifer_a": [["pk_bush", 1.1]],
	"bush_olive_a": [["pk_bush", 0.9], ["pk_bush_flowers", 0.9]],
	"bush_dry_a": [["pk_bush_dry", 1.1]],
	"bush_snow_a": [["pk_bush_snow", 1.1]],
	"bush_jungle_a": [["pk_bush_jungle", 1.1], ["pk_plant_1_big", 1.2]],
	## GDD §17.0.C: moita baixa e cheia (os construtores achatam em Y e sobrepõem várias). Malhas de
	## tools/art/env_kit/build_bush_low.gd.
	"bush_low": [["bush_low_a", 1.0], ["bush_low_b", 1.0], ["bush_low_c", 1.35]],
	"grass_tuft": [["pk_grass_short", 1.0], ["pk_grass_wispy", 1.0]],
	"grass_tuft_b": [["pk_grass_wispy_tall", 1.0], ["pk_grass_tall", 1.0]],
	"grass_golden": [["pk_grass_golden", 1.0]],
	"flowers": [["pk_flowers_a", 1.0]],
	"flowers_b": [["pk_flowers_b", 1.0], ["pk_flower_single", 1.2]],
	"flowers_purple": [["pk_flowers_purple", 1.0]],
	"mushrooms": [["pk_mushroom", 1.0]],
	"mushrooms_b": [["pk_mushroom", 0.8], ["pk_mushroom_shelf", 1.0]],
	"fern": [["pk_fern", 1.0], ["pk_plant_1", 1.0]],
	"reeds": [["pk_reeds", 1.0]],
	"rock_moss_a": [["pk_rock_moss_1", 0.7], ["pk_rock_moss_2", 0.7]],
	"rock_moss_b": [["pk_rock_moss_3", 0.4], ["pk_rock_moss_2", 0.4]],
	"rock_moss_c": [["pk_rock_moss_1", 1.15], ["pk_rock_moss_3", 1.1]],
	"rock_grey_a": [["pk_rock_1", 0.55], ["pk_rock_2", 0.55], ["pk_rock_3", 0.5]],
	"rock_red_a": [["pk_rock_red", 0.6]],
	"rock_sand_a": [["pk_rock_sand", 0.6]],
	"prop_crate": [["pk_crate_wooden", 1.0]],
	"prop_barrel": [["pk_barrel", 1.0], ["pk_barrel_apples", 1.0]],
	"prop_fence": [["pkv_prop_woodenfence_single", 1.0]],
	"petals": [["pk_petals_1", 1.0], ["pk_petals_2", 1.0], ["pk_petals_3", 1.0]],
}


## [caminho da malha, escala] para o nome lógico (sem alias: a própria malha do kit, escala 1).
static func resolve(logical: String, pos: Vector3) -> Array:
	if not ALIAS.has(logical):
		return [MESH_DIR + logical + ".res", 1.0]
	var list: Array = ALIAS[logical]
	var h := absi(int(floor(pos.x * 7.13) * 31 + floor(pos.z * 3.71) * 17 + floor(pos.x + pos.z)))
	var pick: Array = list[h % list.size()]
	var path: String = MESH_DIR + String(pick[0]) + ".res"
	if not ResourceLoader.exists(path):
		return [MESH_DIR + logical + ".res", 1.0]
	return [path, pick[1]]


## Agrupa itens [nome lógico, Transform3D, (Color)] por malha real (escala aplicada): {caminho: [[xf, semente, cor]]}.
static func group(items: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for it: Array in items:
		var t: Transform3D = it[1]
		var r := resolve(String(it[0]), t.origin)
		var s: float = r[1]
		var xf := Transform3D(t.basis.scaled(Vector3.ONE * s), t.origin)
		if not out.has(r[0]):
			out[r[0]] = []
		(out[r[0]] as Array).append([xf, rng.randf(), it[2] if it.size() > 2 else Color.WHITE])
	return out
