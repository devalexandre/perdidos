class_name CombatEvents
extends RefCounted
## Barramento de eventos do combate no SERVIDOR (dono: K), para quem não tem o ServerWorld à mão:
##   CombatEvents.bus().monster_killed.connect(...)
## Os mesmos sinais saem em world.combat (CombatService), que é a forma principal (Q e N usam).
## Os sinais saem depois que o estado já foi aplicado (monstro morto, jogador com hp 0...).

## Um jogador derrotou um monstro. killer_peer = quem deu o último golpe (0 = ninguém/skill sem dono).
## xp = XP do estágio (sem evolução desde 30/09/2026). Divisão de grupo: F2 (Q).
signal monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int)
## O mesmo abate com os detalhes (CombatService.kill_info): stage (1..3; atroz = 3), form_stage (1..4),
## boss, atroz, rare, escort, entity_id, instance_id, map_id, level, xp, killer_peer. Sai logo depois de
## monster_killed. Quem já liga monster_killed (4 argumentos) pode ler last_kill durante a emissão.
signal monster_killed_info(killer_peer: int, monster_id: StringName, info: Dictionary)
## Um jogador morreu. killer_entity = entity_id de quem matou (monstro), 0 se desconhecido.
## N aplica a regra da zona e chama CombatService.revive(peer, posição). Ver respawn_managed_externally.
signal player_killed(victim_peer: int, killer_entity: int)
## O jogador voltou à vida (CombatService.revive).
signal player_revived(peer: int)
## Dano aplicado (qualquer fonte). Útil para quests de "provação" e estatísticas.
signal damage_applied(source_id: int, target_id: int, amount: int, crit: bool, damage_type: int)
## Um jogador pegou um item do chão (N marca itens do treino; Q conta objetivos de coleta).
signal drop_picked(peer: int, item_id: StringName, qty: int, instance_id: StringName)

## N põe true ao assumir o renascimento (regras de zona). Enquanto false, K renasce o jogador no
## SpawnPoint do mapa depois de CombatRules.FALLBACK_RESPAWN_DELAY_SEC.
var respawn_managed_externally: bool = false
## Detalhes do abate sendo emitido agora (preenchido só durante monster_killed / monster_killed_info).
var last_kill: Dictionary = {}

static var _bus: CombatEvents = null


static func bus() -> CombatEvents:
	if _bus == null:
		_bus = CombatEvents.new()
	return _bus
