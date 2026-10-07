class_name BalanceConfig
extends Resource
## Todas as constantes [PROVISÓRIO] do GDD. Nunca usar número mágico no código: ler de Balance.cfg.

@export_group("Network")
@export var protocol_version: int = 4 # 4: companheiros e montarias (NetFollowers)
@export var default_port: int = 7777
@export var server_tick_hz: int = 20 # GDD 15.3
@export var client_interp_delay_ms: int = 100 # OBSOLETO (movimento por células, GDD §10.1)
@export var max_client_msgs_per_sec: int = 30 # GDD 15.4

@export_group("Movement")
## [EM ABERTO] no GDD — valor padrão configurável.
@export var player_move_speed: float = 5.0 # OBSOLETO: use walk_ms_per_cell

@export_group("Rendering")
@export var world_pixels_per_unit: int = 48 # GDD 17.2 (rev. 2026-09-27)
@export var sprite_pixel_size: float = 1.0 / 48.0 # GDD 17.2 (rev. 2026-09-27)
@export var internal_resolution: Vector2i = Vector2i(960, 540) # GDD 17.2 (rev. 2026-09-27)
## GDD §17.0.A: o mundo 3D é desenhado na resolução NATIVA da janela ("native"). "internal" = modo
## antigo (SubViewport internal_resolution ampliada por múltiplo inteiro), mantido para comparação/depuração.
@export_enum("native", "internal") var world_render_mode: String = "native"
## Tamanho do Viajante na tela (fração da altura da janela) com zoom 1.0, no modo "native". GDD §17.0.C
## (28/09/2026): personagens menores, ≈9–11% da altura em 1080p, como nos MMOs 2.5D clássicos. A escala de
## texel dos sprites (px de tela por texel) é altura_janela × isto / character_body_px; se ficar a menos de
## sprite_texel_snap de um inteiro, vira esse inteiro (escala inteira sempre que possível). Fora disso a escala é
## fracionária e o shader dos sprites faz "pixel AA" (texels continuam blocos sólidos; ver char_palette_swap_3d).
## 1080p → 1,29 (≈10%); 720p → 1 (inteiro); 1440p → 1,71; 2160p → 2,57.
@export var character_screen_fraction: float = 0.10
@export var sprite_texel_snap: float = 0.15
## Altura do corpo do Viajante dentro do quadro de character_frame_size (px de arte).
@export var character_body_px: int = 84
@export var character_frame_size: int = 96 # GDD 17.2 (rev. 2026-09-27)

@export_group("Camera")
## GDD §17.0.C (28/09/2026): câmera mais inclinada para baixo (≈55–60°), leitura de MMO 2.5D clássico.
@export var camera_pitch_deg: float = 57.0
## Zoom livre pequeno: 1.0 = padrão (≈10% da tela); min afasta, max aproxima.
@export var camera_zoom_min: float = 0.8
@export var camera_zoom_max: float = 1.25
## Distância base câmera→alvo com zoom 1.0 (m). Mais longe = perspectiva mais "chapada" (FOV menor).
@export var camera_base_distance: float = 26.0
@export var camera_rotate_speed_deg: float = 90.0
## Sprites projetam no chão uma sombra de verdade (silhueta deitada ao longo do sol), além da sombra macia
## colada aos pés (GDD §17.0.C). Só com sol que projete sombra.
@export var sprite_cast_shadow: bool = true

@export_group("Party & instances")
## GDD §5 (decisão do dono em 30/09/2026): todo mapa tem UMA instância (instance_id = map_id); grupos não
## criam cópias. Os números abaixo regem o grupo, a divisão de XP e a posse dos drops.
@export var party_max_size: int = 5 # GDD 5.4
## Slots de personagem por conta (05/10/2026: 1). Personagem criado é definitivo (aparência fixa).
@export var characters_per_account: int = 1
@export var instance_destroy_delay_sec: float = 300.0 # OBSOLETO (sem instância por grupo desde 30/09/2026)
@export var leader_reconnect_grace_sec: float = 180.0 # GDD 5.3
## GDD §6.3 "XP dividida no grupo": cada membro perto recebe XP_total × (1 + bônus × (membros − 1)) / membros.
@export var party_xp_bonus_per_member: float = 0.1
## Alcance (células) para dividir a XP e o crédito de abate das quests com o grupo do dono do monstro
## (mesmo mapa, a até isto do monstro).
@export var party_share_range_cells: float = 30.0
## GDD §10.5: o drop pertence a quem causou mais dano no monstro (e ao grupo dele) por isto (s); depois, livre.
@export var drop_owner_sec: float = 10.0
## Convite de grupo: expira depois disto (s); o mesmo jogador só convida de novo depois de party_invite_cooldown_sec.
@export var party_invite_timeout_sec: float = 60.0
@export var party_invite_cooldown_sec: float = 3.0
## De quanto em quanto tempo (s) o servidor reenvia o painel do grupo (vida, mana, mapa) se algo mudou.
@export var party_state_interval_sec: float = 0.5
## /online liberado para todos (beta). false = só com --dev-commands.
@export var online_list_public: bool = true

@export_group("Trade")
## Troca entre personagens (pedido do dono, 30/09/2026): os dois no mesmo mapa, a até isto (células); a troca
## cancela se alguém se afastar além disso.
@export var trade_range_cells: float = 6.0
## O pedido de troca expira depois disto (s); quem pede espera trade_request_cooldown_sec entre pedidos.
@export var trade_request_timeout_sec: float = 30.0
@export var trade_request_cooldown_sec: float = 3.0
## Máximo de pilhas diferentes que cada lado oferece.
@export var trade_max_items: int = 10
## Não pede nem aceita troca em combate (GDD §6.4: 6 s sem causar/receber dano).
@export var trade_blocked_in_combat: bool = true

@export_group("Interaction")
@export var pickup_range: float = 2.0 # GDD 15.4
@export var interact_range: float = 3.0 # GDD 15.4

@export_group("Audio")
## Passos: bem discretos (referência: nos MMOs clássicos o personagem quase não faz som ao andar).
## Aplicado sobre o barramento SFX. 0 dB = volume original do arquivo.
@export var footstep_volume_db: float = -18.0
## Variação aleatória de volume por passo (± dB), para não soar mecânico.
@export var footstep_volume_jitter_db: float = 2.0
@export var footsteps_enabled: bool = true

@export_group("Movement (grid)")
## GDD §10.1: movimento clássico por células. Tamanho da célula em unidades do mundo (1 un. = 1 m).
@export var cell_size: float = 1.0
## Tempo para atravessar uma célula em linha reta (diagonal = ×diagonal_cost).
@export var walk_ms_per_cell: int = 200
@export var diagonal_cost: float = 1.4
## Segurar o clique: intervalo entre novos pedidos de movimento para o cursor.
@export var hold_walk_repeat_ms: int = 120
## Maior distância (em células) que um único pedido de movimento pode percorrer.
@export var max_walk_cells: int = 40

@export_group("Boss escort")
## GDD §10.6: o chefe fixo do covil anda com este bando da mesma espécie (normais + médios).
@export var boss_escort_normals: int = 4
@export var boss_escort_mediums: int = 2

@export_group("Progression")
## GDD §6.2 / §8.1 (decisões de 27/09/2026).
@export var attribute_points_per_level: int = 3
@export var skill_points_per_level: int = 1
@export var hotbar_slots: int = 10   # teclas 1 a 0
@export var max_skill_level: int = 10
## GDD §6.3: XP para o próximo nível = floor(xp_curve_base * nivel ^ xp_curve_exponent); nível máximo.
@export var xp_curve_base: float = 100.0
@export var xp_curve_exponent: float = 1.6
@export var max_character_level: int = 25
## GDD §6.4: "fora de combate" = tantos segundos sem causar/receber dano (a barra só muda fora dele).
@export var out_of_combat_sec: float = 6.0

@export_group("Luck & accuracy")
## GDD §6.2 / §10.2 (27/09/2026, Agente R): Sorte (SOR) e Destreza (DES) no combate e nos drops.
## Crítico (só físico): chance = crit_base_chance + SOR × crit_chance_per_luk (limitado a 100%).
@export var crit_base_chance: float = 0.05
@export var crit_chance_per_luk: float = 0.003
## Acerto (só físico; mágico sempre acerta): clamp(hit_base_chance + (DES_atacante − DES_alvo) ×
## hit_chance_per_dex, hit_chance_min, hit_chance_max). O "errou" é a esquiva do alvo.
@export var hit_base_chance: float = 0.80
@export var hit_chance_per_dex: float = 0.01
@export var hit_chance_min: float = 0.50
@export var hit_chance_max: float = 0.95
## DES dos monstros quando o estágio não define (MonsterStage.dex < 0): base + nível × por_nível.
@export var monster_dex_base: int = 3
@export var monster_dex_per_level: float = 1.0
## Drop: chance final = chance_da_tabela × (1 + SOR × drop_chance_per_luk) (SOR de quem derrotou).
@export var drop_chance_per_luk: float = 0.01
## Monstros raros: ao (re)nascer, chance = rare_base_chance × MonsterDef.rare_chance_multiplier ×
## (1 + SOR × rare_chance_per_luk), com a maior SOR entre os jogadores da instância a até
## rare_luck_range_cells do ponto de nascimento.
@export var rare_base_chance: float = 0.01
@export var rare_chance_per_luk: float = 0.02
@export var rare_luck_range_cells: float = 30.0
## Variante rara: atributos (vida, ATQ, ATQM, DEF, DEFM) × isto; drops com chance × e rolagens extras.
@export var rare_stat_multiplier: float = 1.5
@export var rare_drop_chance_multiplier: float = 2.0
@export var rare_extra_drop_rolls: int = 1

@export_group("Boss lairs")
## GDD §10.6.1 (decisão de 30/09/2026): cada chefe vive no seu covil fixo (BossLairs/ do mapa) e renasce
## depois disto (s) quando derrotado; o marcador pode trocar com a meta respawn_sec. Nunca em zonas TRAINING.
@export var boss_respawn_sec: float = 600.0

@export_group("Day & night")
## GDD §10.7 (números [PROVISÓRIO]; o dono sugeriu 40 min de dia e 20 de noite). Relógio autoritativo no
## servidor (WorldClock + autoload DayNight), replicado aos clientes.
@export var day_night_day_sec: float = 2400.0
@export var day_night_night_sec: float = 1200.0
## Ponto do ciclo (s desde o início do dia) em que o servidor começa ao ligar.
@export var day_night_start_sec: float = 60.0
## Transição visual (s) do anoitecer e do amanhecer, centrada na virada.
@export var day_night_transition_sec: float = 150.0
## O Campo de Treino fica sempre de dia (preferência do dono). O comando de teste que força a noite vale
## também ali.
@export var day_night_training_always_day: bool = true
## De quanto em quanto tempo (s) o servidor reenvia o relógio aos clientes (correção de deriva).
@export var day_night_sync_interval_sec: float = 30.0

@export_group("Atroz form")
## TITULOS-E-SKILLS §3.0 item 5 e GDD §10.7: o chefe à noite vira a forma atroz (MonsterDef: estágio 4).
## Atributos (vida, ATQ, ATQM, DEF, DEFM) = os do chefe × isto (MonsterDef.atroz_stat_multiplier > 0 troca).
@export var atroz_stat_multiplier: float = 2.0
## Ao entrar em combate, chama o bando que estiver a até isto (células) para cima do mesmo alvo.
@export var atroz_call_escort_radius_cells: float = 16.0
## De quanto em quanto tempo (s) a forma atroz troca de alvo para o jogador mais fraco por perto.
@export var atroz_retarget_interval_sec: float = 2.0

@export_group("Cast & cooldown")
## GDD §8.1 "Tempo de uso na barra" (28/09/2026) e §11.3. Fórmulas em CastTiming (scripts/shared/cast_timing.gd).
## Conjuração da skill = base × (1 + cast_time_per_skill_level × (nível_skill − 1)) × (1 − redução):
## skill evoluída fica mais forte e um pouco mais lenta; base 0 continua instantânea.
@export var cast_time_per_skill_level: float = 0.06
## Redução da conjuração pelos atributos: DES × cast_reduction_per_dex + INT × cast_reduction_per_int,
## limitada a cast_reduction_attr_cap; somada ao cast_reduction (%) dos itens equipados, limite total
## cast_reduction_total_cap.
@export var cast_reduction_per_dex: float = 0.005
@export var cast_reduction_per_int: float = 0.003
@export var cast_reduction_attr_cap: float = 0.50
@export var cast_reduction_total_cap: float = 0.60
## Recarga = base × (1 − min(ESP × cooldown_reduction_per_spi + cooldown_reduction (%) dos itens, cap)).
@export var cooldown_reduction_per_spi: float = 0.004
@export var cooldown_reduction_cap: float = 0.40
## Poções de vida e de mana (consumíveis com heal_hp/heal_mp): uso instantâneo, sem conjuração e sem
## recarga (substitui a recarga compartilhada de 10 s do §11.3).
@export var potions_instant: bool = true
## Demais usáveis (pergaminhos etc.): ItemDef.use_effect "cast_sec"/"cooldown_sec"/"cooldown_group";
## sem a chave, estes padrões. Também sofrem as reduções de atributo e de item.
@export var item_default_cast_sec: float = 1.0
@export var item_default_cooldown_sec: float = 10.0
## Pergaminho de Retorno (use_effect "return_city", 30/09/2026): fora de combate é na hora; em combate, leitura
## de tanto (s), interrompida por dano, por andar ou atordoamento.
@export var return_scroll_combat_cast_sec: float = 1.0

@export_group("Dona Ana")
## Viagem entre cidades com a Dona Ana (WaystoneService): Estrelas cobradas por viagem (0 = grátis).
@export var waystone_teleport_stars: int = 0

@export_group("Companheiros e montarias")
@export var mount_min_ms_per_cell: int = 130
@export var mount_cast_sec: float = 1.5
@export var mount_lockout_after_hit_sec: float = 5.0
@export var companion_swap_cooldown_sec: float = 60.0
@export var follower_teleport_cells: float = 8.0
