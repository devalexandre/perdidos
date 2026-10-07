class_name SysMsg
extends RefCounted
## Chaves de tradução dos avisos do servidor (Net.system_message). B cria em strings.csv.
## Argumentos (quando houver) entram em ordem para tr(key) % args.

const TOO_FAR: String = "SYS_TOO_FAR"
const TARGET_INVALID: String = "SYS_TARGET_INVALID"
const NOT_ENOUGH_STARS: String = "SYS_NOT_ENOUGH_STARS"
const INVENTORY_FULL: String = "SYS_INVENTORY_FULL"
const SHOP_NOT_OPEN: String = "SYS_SHOP_NOT_OPEN"
const ITEM_NOT_SOLD_HERE: String = "SYS_ITEM_NOT_SOLD_HERE"
const ITEM_NOT_SELLABLE: String = "SYS_ITEM_NOT_SELLABLE"
const ITEM_NOT_USABLE: String = "SYS_ITEM_NOT_USABLE"
const ITEM_NOT_EQUIPPABLE: String = "SYS_ITEM_NOT_EQUIPPABLE"
## args: [segundos restantes (int)]
const ITEM_ON_COOLDOWN: String = "SYS_ITEM_ON_COOLDOWN"
const CHAT_TOO_FAST: String = "SYS_CHAT_TOO_FAST"
## args: [limite de caracteres (int)]
const CHAT_TOO_LONG: String = "SYS_CHAT_TOO_LONG"
## args: [nível recomendado (String, ex. "1-10")]
const PORTAL_CLOSED: String = "SYS_PORTAL_CLOSED"
