class_name ShopDef
extends Resource
## Loja de NPC: data/shops/<id>.tres. Preços vêm de ItemDef.buy_price/sell_price.

@export var id: StringName = &""
@export var items: Array[StringName] = []
@export var causos_rank_1_items: Array[StringName] = []
@export var causos_rank_2_items: Array[StringName] = []
@export var causos_rank_3_items: Array[StringName] = []
@export var causos_rank_4_items: Array[StringName] = []
@export var causos_rank_5_items: Array[StringName] = []


func available_items(causos_rank: int) -> Array[StringName]:
	var out: Array[StringName] = items.duplicate()
	var tiers: Array = [causos_rank_1_items, causos_rank_2_items, causos_rank_3_items,
			causos_rank_4_items, causos_rank_5_items]
	for rank: int in mini(maxi(causos_rank, 0), tiers.size()):
		for item_id: StringName in tiers[rank]:
			if item_id not in out:
				out.append(item_id)
	return out
