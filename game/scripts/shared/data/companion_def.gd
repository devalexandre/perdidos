class_name CompanionDef
extends Resource

@export var id: StringName = &""
@export var name_key: String = ""
@export var title_id: StringName = &""
@export var bond_quest_id: StringName = &""
@export var sprite_base: String = ""
@export var visual_scale: float = 0.7
@export var flies: bool = false
## Altura de voo (m) do sprite acima do chão quando flies (a sombra continua no chão, menor). 0 = rente ao chão.
## O seguidor fica 1,5 célula ATRÁS do dono (follower_visual.gd); com a altura, a pet voa atrás e acima dele.
@export var fly_lift_m: float = 0.0
## Vida com o dono parado (só visual, cliente): movimentos sorteados a cada poucos segundos (follower_visual.gd).
## Voador: &"drift" (paira um pouco para o lado), &"orbit" (volta curta em volta/atrás do dono), &"swap_side" (muda
## de lado), &"look" (folha "look": olha em volta), &"glide" (folha "glide": plana de asas abertas).
## Terrestre: &"wander" (voltinha perto do dono), &"sit" (folha "sit", se houver), &"look", &"swap_side".
## Vazio = fica parado atrás do dono (como antes).
@export var idle_moves: Array[StringName] = []
@export var bond_skills: Array[StringName] = []
## OBSOLETO (08/10/2026): o PVP do bicho usa Balance.companion_pvp_damage_mult.
@export var pvp_proc_mult: float = 0.5

@export_group("Combate (PETS-E-MONTARIAS §0.1)")
## Ataque automático no alvo atual do dono. 0 = não ataca corpo a corpo (Lume: só magias).
@export var attack_interval_sec: float = 0.0
## Alcance do golpe (células) a partir de onde o bicho está.
@export var attack_range_cells: float = 1.0
## Quanto o bicho se afasta do dono para chegar ao alvo (células). A harpia mergulha do ombro (0).
@export var chase_cells: float = 0.0
@export var attack_mult: float = 1.0
## &"physical" (ATK do bicho) ou &"magic" (ATQM do bicho).
@export var damage_kind: StringName = &"physical"
## Poder = power_base + power_per_level × nível + attribute_frac × atributo do dono.
@export var power_base: float = 3.0
@export var power_per_level: float = 1.0
## Atributo do dono ligado ao título: &"dex" (Harpia), &"str" (Guará), &"int" (Lume).
@export var owner_attribute: StringName = &"dex"
@export var attribute_frac: float = 0.4
## Magias automáticas (data/companion_skills/), na ordem em que se liberam (Balance.companion_spell_levels).
@export var spells: Array[StringName] = []
## Os golpes ignoram esta fração da DEF do alvo (mergulho da harpia).
@export var def_ignore: float = 0.0
