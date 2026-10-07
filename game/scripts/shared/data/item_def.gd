class_name ItemDef
extends Resource
## Definição de item (GDD §11). Um arquivo por item: data/items/<id>.tres.

enum ItemType { CONSUMABLE, WEAPON, OFFHAND, HEAD, BODY, FEET, ACCESSORY, MATERIAL, GLOVES, CRENDICE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }
## BOW: arco (duas mãos), ataque básico físico à distância (CombatRules.BASIC_BOW_RANGE_CELLS).
enum WeaponKind { NONE, BLADE, ARCANE, BOW }

@export var id: StringName = &""
@export var name_key: String = ""        # chave de tradução (localization/content.csv)
@export var desc_key: String = ""
@export var icon: Texture2D
@export var type: ItemType = ItemType.MATERIAL
@export var weapon_kind: WeaponKind = WeaponKind.NONE
@export var rarity: Rarity = Rarity.COMMON
@export var stackable: bool = false
@export var max_stack: int = 1           # empilháveis: até 99 (GDD §11.3)
@export var buy_price: int = 0           # em Estrelas; 0 = a loja não vende
@export var sell_price: int = 0          # quanto a loja paga
## Pode ir numa troca entre jogadores (30/09/2026). false = preso ao personagem (ex.: item de quest).
@export var tradeable: bool = true
## Área ou masmorra onde o item dropa com exclusividade. Se preenchido, NPCs nunca vendem (buy_price = 0).
@export var exclusive_drop_zone: StringName = &""
## Armas (GDD §6.2, 30/09/2026): atributo que dá o ATK com esta arma na mão principal (&"str",
## &"dex", &"int"...). Vazio = Força. Facão/espada = str, arco = dex, cajado/varinha/tomo = int.
@export var scaling_attribute: StringName = &""
## Bônus: chaves atk, matk, def, mdef, str, dex, vit, int, spi (valores int).
@export var stats: Dictionary[StringName, int] = {}
## Bônus percentuais inteiros (ex.: {&"atk": 10} aumenta ATK em 10%).
@export var stat_percent: Dictionary[StringName, int] = {}
## Consumíveis: chaves heal_hp, heal_mp (int) e cooldown_group (StringName).
@export var use_effect: Dictionary[StringName, Variant] = {}

## Sistema de Crendices (GDD §11):
## ID da definição folclórica em CrendiceDatabase (se for um amuleto).
@export var crendice_id: StringName = &""
## Número de Encaixes de Crendice (0 = calcula automático pela raridade/tipo de equipamento).
@export var crendice_sockets: int = 0

## Pode ir para a barra de atalhos (1–0): consumível (usa) ou equipável (veste/troca ao usar).
func is_hotbar_item() -> bool:
	return type == ItemType.CONSUMABLE or is_equippable()


## Vai para algum espaço do equipamento (inclusive cosméticos e munição).
func is_equippable() -> bool:
	return not get_equip_slot().is_empty() or is_cosmetic


## Espaço de equipamento em que o item entra (&"" se não é equipável).
func get_equip_slot() -> StringName:
	if is_ammo:
		return &"offhand"
	match type:
		ItemType.WEAPON: return &"weapon"
		ItemType.OFFHAND: return &"offhand"
		ItemType.HEAD: return &"head"
		ItemType.BODY: return &"body"
		ItemType.FEET: return &"feet"
		ItemType.GLOVES: return &"gloves"
		ItemType.ACCESSORY: return &"accessory"  # vai em accessory_1 ou accessory_2
	return &""

## --- Aparência (paper doll, GDD §17.4 e §14.3) ---
## Visual quando equipado. Vazio = o item não muda a aparência.
## Espaço body → roupa inteira (assets/characters/outfits/); head/weapon/offhand → camada sobreposta
## (assets/equipment/<slot>/<visual_id>/). Vários itens podem compartilhar o mesmo visual_id.
@export var visual_id: StringName = &""
## Cosmético: vai nos espaços cosmetic_*; só muda a aparência, nunca atributos (GDD §14.1).
@export var is_cosmetic: bool = false
## Arma de duas mãos: equipar tira o item da mão secundária (a menos que seja munição para arma de projéteis).
@export var two_handed: bool = false
## Bônus folclórico de prata: causa +10% de dano contra lobisomens e mortos-vivos.
@export var silver_effective: bool = false
## Munição (flechas, virotes, etc.): equipa no mesmo espaço do escudo (offhand).
@export var is_ammo: bool = false
## Arma de projéteis (arco, etc.): consome e dispara a munição equipada no espaço do escudo.
@export var is_projectile: bool = false


## Identifica se a arma é de projéteis (arco ou marcada como projétil).
func is_projectile_weapon() -> bool:
	return weapon_kind == WeaponKind.BOW or is_projectile


## Quantidade de Encaixes de Crendice (Sockets) disponíveis neste equipamento.
func get_crendice_sockets() -> int:
	if crendice_sockets > 0:
		return crendice_sockets
	if type in [ItemType.WEAPON, ItemType.OFFHAND, ItemType.HEAD, ItemType.BODY, ItemType.FEET, ItemType.ACCESSORY, ItemType.GLOVES]:
		if rarity in [Rarity.RARE, Rarity.EPIC]:
			return 2
		return 1
	return 0


func is_crendice() -> bool:
	return type == ItemType.CRENDICE or not crendice_id.is_empty()
