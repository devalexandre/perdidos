# Contratos — Marco "Passeio no Porto do Despertar" (PC)

Objetivo e critério de pronto: `docs/proximos-passos.md` §1. Arquitetura: §2. Conteúdo: §3.
Continua valendo tudo de `docs/phase1-contracts.md` que não for alterado aqui.
Engine Godot 4.7.2, GDScript tipado, identificadores em inglês, comentários e documentos em português.

## Já criado pelo coordenador (não editar sem avisar)

- `scripts/shared/data/`: `ItemDef`, `DialogueDef`/`DialogueNode`/`DialogueOption`, `ShopDef`, `NpcDef`, `AudioZoneDef`.
  Se precisar de um campo novo, **adicione no fim da classe** e cite no relatório.
- Autoload `Content` (`scripts/shared/content.gd`): `Content.item(id)`, `.npc(id)`, `.dialogue(id)`,
  `.shop(id)`, `.audio_zone(id)`, `.all(kind)`. Carrega `data/{items,npcs,dialogues,shops,audio}/*.tres`.
- Traduções: `localization/strings.csv` (interface, **B**) e `localization/content.csv` (nomes, falas e itens, **C**).
  Os dois já estão no `project.godot`.
- `Balance.cfg` continua sendo do coordenador. Constantes novas vão como `const` nomeada no próprio
  script; cite no relatório para migrarmos.

## Donos

| Agente | Arquivos |
|---|---|
| **A — Sistemas/servidor** | `scripts/main.gd`, `scripts/shared/net.gd`, `scripts/shared/entities/**` (novo), `scripts/shared/player_entity.gd` (vira fino ou some), `scenes/entities/**`, `scripts/server/**`, `tools/*.sh`, `tests/server/**` |
| **B — Cliente/interface** | `scripts/client/**`, `scenes/ui/**`, `localization/strings.csv`, `tests/client/**`, `export_presets.cfg` |
| **C — Conteúdo/arte/áudio** | `assets/**`, `data/{items,npcs,dialogues,shops,audio,regions,maps}/**`, `scenes/maps/**`, `scripts/shared/map.gd`, `localization/content.csv`, `tools/art/**` |

## Entidades (A)

- `NetEntity` (`scripts/shared/entities/net_entity.gd`) é a base de toda entidade replicada. Ela generaliza o `PlayerEntity`.
- Propriedades replicadas:
  - `entity_id: int`: jogador = peer_id; NPC = 1 000 000 + n.
  - `kind: StringName`: &"player" ou &"npc".
  - `display_name: String`: jogador = nome; NPC = `tr(name_key)` no cliente.
  - `def_id: StringName`: jogador = body_type; NPC = id do NpcDef.
  - `instance_id`, `net_position`, `facing_yaw`, `anim` (&"idle", &"walk", &"sit").
- **`NavMover`** é o componente de servidor que segue o caminho do navmesh (código tirado do PlayerEntity). NPCs usam o mesmo componente com a velocidade do `NpcDef`.
- No cliente, a entidade cria o visual chamando `EntityVisualFactory.create(entity) -> Node3D` (de B).
  - Esse nó tem `facing_yaw`, `anim`, `show_emote(emote_id: StringName)` e `show_chat(text: String)`.
  - A entidade repassa `facing_yaw` e `anim` a cada quadro.
  - A chama `show_emote` e `show_chat` quando chegam os eventos.
- Folhas de sprite:
  - jogador: `res://assets/characters/chr_traveler_<body>`;
  - NPC: `NpcDef.sprite_base`;
  - sufixos `_idle.png`, `_walk.png` e opcionalmente `_sit.png` (1 quadro × 5 linhas).
- Rotinas de NPC no servidor: IDLE, WANDER (pontos aleatórios alcançáveis dentro de `wander_radius` a partir do spawn, com pausas), PATROL e SIT. **Quando um jogador fala com o NPC, ele para e se vira para o jogador.**
- NPCs pertencem à instância do mapa (`map_id` do NpcDef) e usam o mesmo filtro de visibilidade.

## Clique e interação

- **Colisão:**
  - camada 1 = chão (continua igual);
  - **camada 2 = coisas clicáveis:** o visual de cada entidade tem um `Area3D`/shape do tamanho do sprite com meta `target_id`, e os objetos do mapa (bancos, portões) também.
- **`target_id`** (String):
  - `"e:<entity_id>"` para entidades;
  - `"m:<interact_id>"` para objetos do mapa.
- **Clique (B):** o `ClientView` testa primeiro a camada 2. Se acertar, emite `interact_requested(target_id: String)` e mostra o cursor de interação; se não, faz o `move_requested` de sempre.
- **Servidor (A):** `req_interact(target_id)` valida o alvo na mesma instância. Se estiver longe, anda até `Balance.cfg.interact_range` e executa ao chegar:
  - NPC com diálogo → abre o diálogo;
  - `sit` → anim sit, virado para o yaw do marcador;
  - `portal` → mensagem "Recomendado: nível X" (os portões ficam fechados neste marco).
- **Objetos do mapa (C):** nó `Interactables` no mapa, com filhos `Area3D` na camada 2 e metas:
  - `interact_id` (único no mapa);
  - `interact_type` (&"sit" ou &"portal");
  - `facing_yaw` (para sit);
  - `target_map` e `recommended_level` (para portal).
  `GameMap.get_interactables() -> Dictionary` (id → {type, position, meta}) é a função que o servidor usa.

## Mensagens de rede (A implementa; B chama e escuta)

**Intenções do cliente** (todas pelo `Net`, com validação e limite de taxa):

| Chamada | Validação no servidor |
|---|---|
| `Net.send_interact(target_id)` | alvo existe, mesma instância |
| `Net.send_dialogue_choice(option_index)` / `Net.send_dialogue_close()` | diálogo aberto com esse NPC, opção visível |
| `Net.send_inventory_move(from_slot, to_slot)` | espaços válidos; junta pilhas iguais |
| `Net.send_use_item(slot)` | consumível, recarga do grupo |
| `Net.send_equip(slot)` / `Net.send_unequip(equip_slot)` | item equipável; inventário com espaço para desequipar |
| `Net.send_shop_buy(item_id, qty)` / `Net.send_shop_sell(slot, qty)` | loja aberta e perto; Estrelas suficientes; item vendável |
| `Net.send_chat(channel, text)` | canal &"local" (grupo e sussurro depois); ≤ 200 caracteres; 1 msg/s; filtro de palavrões (lista em `data/chat/banned_words.txt`, de A) |
| `Net.send_emote(emote_id)` | &"wave", &"sit", &"laugh", &"cry", &"angry", &"heart"; &"sit" alterna a animação de sentar |

**Sinais do `Net` no cliente** (B escuta e desenha a interface):

- `inventory_changed(slots: Array)`: 40 posições, cada uma `{}` ou `{"item": StringName, "qty": int}`.
- `equipment_changed(equip: Dictionary)`: chaves weapon, offhand, head, body, feet, accessory_1 e accessory_2, com o `item_id` ou &"".
- `stats_changed(stats: Dictionary)`: level, hp, max_hp, mp, max_mp, atk, matk, def, mdef, str, dex, vit, int, spi.
- `currency_changed(stars: int)`.
- `dialogue_opened(npc_entity_id: int, speaker_key: String, text_key: String, options: Array[String])` e `dialogue_closed()`. O servidor já filtrou as opções.
- `shop_opened(shop_id: StringName, items: Array[StringName])` e `shop_closed()`.
- `chat_received(channel: StringName, from_name: String, text: String, from_entity_id: int)`.
- `emote_received(entity_id: int, emote_id: StringName)`.
- `system_message(key: String, args: Array)`: erros ("Estrelas insuficientes", "Longe demais") e avisos, como chave de tradução + argumentos. **B adiciona as chaves em strings.csv:** A lista as chaves que usa no relatório e B cria as que faltarem.

**Regras de inventário (servidor):**
- 40 espaços, empilháveis até `max_stack`.
- Equipamento com os 7 espaços do GDD §11.1.
- Atributos: base 5 em cada; derivados pelas fórmulas §6.4 e §10.2, somando os `stats` dos itens equipados.
- Personagem novo começa com 100 Estrelas, 2 poções de vida pequenas e a roupa de Viajante (sem item).
- Estado salvo em `user://server_saves/<nome>.json` ao sair e a cada 60 s. É provisório: o banco entra na Fase 2, por trás de uma interface `CharacterStore` para trocar depois.
- `protocol_version` já está em **2** no `Balance`.

## Tela de título e entrada (B + A)

- Sem `--name` na linha de comando, `main.gd` (A) mostra `res://scenes/ui/title_screen.tscn` (B).
- Ela emite `play_requested(name: String, body: StringName, host: String, port: int)`, e A conecta com `Net.start_client(...)`.
- Com `--name`, tudo continua como hoje (testes automáticos).

## Áudio (B toca, C fornece)

- **Zonas:** o mapa tem `AudioZones/` com `Area3D` e meta `zone_id`. Cada `zone_id` tem um `AudioZoneDef` em `data/audio/<map_id>_<zone_id>.tres`. `<map_id>_default` vale para o mapa inteiro.
- **`AudioDirector`** (B, só cliente) segue o jogador local. Ele:
  - troca a música com transição de 2 s;
  - mistura o ambiente em camadas;
  - toca efeitos 2D e 3D pelo nome (`AudioDirector.play_sfx(&"ui_click")`).
- **Barramentos:** Master, Music, Ambience, SFX, UI (B cria o `default_bus_layout.tres`).
- **Passos:** os `StaticBody3D` da camada 1 têm meta `surface` (&"stone", &"wood", &"grass" ou &"sand"). O cliente lança um raio para baixo sob o jogador local e toca `sfx_step_<surface>_<n>` a cada passo da animação de andar.
- **Arquivos:**
  - música: `assets/audio/music/mus_<nome>.ogg`;
  - ambiente: `assets/audio/sfx/amb_<nome>.ogg`;
  - efeitos: `assets/audio/sfx/sfx_<nome>.ogg`.
  C registra fonte e licença de cada arquivo em `assets/audio/LICENSES.md`. Só CC0, ou licença que permita uso comercial.
- **Efeitos com nome fixo (C fornece, B usa):**
  - `sfx_ui_click`, `sfx_ui_open`, `sfx_ui_close`;
  - `sfx_buy`, `sfx_sell`, `sfx_equip`, `sfx_pickup`;
  - `sfx_chat`, `sfx_emote`, `sfx_sit`;
  - `sfx_step_{stone,wood,grass,sand}_{1..4}`;
  - `sfx_crystal_hum` (loop 3D).

## Conteúdo (C)

- **NPCs:** os 8 de `proximos-passos.md` §3.1.
  - Cada um tem `NpcDef` e `DialogueDef` em data, marcador em `NpcPoints/` no mapa, e arte idle+walk em 5 direções.
  - A arte segue o pipeline de `tools/art/character_pipeline/` (mesmo estilo e prompt base do Viajante v2).
  - Guarda, Mestres e mercador: idle obrigatório, walk desejável. Os que vagam: walk obrigatório.
- **Loja:** `data/shops/market.tres`. O diálogo do mercador tem a opção com `action = &"open_shop"`.
- **Itens:** os 16 de §3.2, cada um com `ItemDef` e ícone 32x32 em `assets/items/icons/icon_item_<id>.png`, no estilo da Âncora 5.
- **Viajante:** `chr_traveler_<body>_sit.png` (1 quadro × 5 linhas).
- **Emotes:** `assets/ui/emotes/emote_<id>.png` (balão 24x24 ou 32x32).
- **Kit de interface:** `assets/ui/` (9-slice de painel, botão, espaço de item, tooltip, caixa de diálogo, cursores normal/interagir). Enquanto não existir, B usa o tema padrão.
- **Mapa:**
  - `NpcPoints/`, `Interactables/` (os 3 bancos dos mirantes + 3 portões) e `AudioZones/` (default, docks, market);
  - metas `surface` no chão;
  - passe visual guiado pela Âncora 4.
- **Chave da IA de imagem:** está em `~/.zshrc` como `BRIA_API_KEy` (com "y" minúsculo). Leia com
  `export BK=$(grep -oP 'BRIA_API_KEy=["'\'']?\K[^"'\'' ]+' ~/.zshrc)` e **nunca** imprima o valor.

## Testes obrigatórios de cada agente

- `godot --headless --import` sem erros nos seus arquivos.
- **A:** autoteste headless (estender o `--autotest`):
  - falar com o mercador, comprar uma poção, equipar o facão (comprar antes), vender, mandar chat e emote;
  - checar que o segundo cliente recebe o chat e o emote e **não** recebe o inventário do outro;
  - checar que o NPC WANDER se move e para ao falar.
- **B:** cena de teste com dados falsos (sem rede) abrindo inventário, loja, diálogo e chat. Capturas via xvfb e cursor sobre um NPC.
- **C:** script headless que carrega todos os `.tres` pelo `Content` e checa referências:
  - ícones e sprites existem;
  - chaves de tradução existem;
  - marcadores de NPC existem no mapa e ficam no navmesh.
  Também: validador de paleta/tamanho nas imagens novas e captura da cidade renderizada.

## ADENDO 1 (27/09/2026) — Aparência visível: equipamento e cosméticos mudam o personagem

Decisão do dono: **cosméticos mudam a aparência, e alguns itens também quando equipados.** Entra neste marco.

### Dados (já no `ItemDef`)
- `visual_id`: visual do item equipado; vazio significa que o item não muda a aparência.
- `is_cosmetic`: o item só muda a aparência e nunca dá atributos.

### Servidor (A)
- O `Equipment` ganha os espaços `cosmetic_head`, `cosmetic_body` e `cosmetic_weapon`.
  Só aceitam itens com `is_cosmetic = true`, e itens cosméticos só entram nesses espaços.
- O `NetEntity` replica para **todos** da instância o campo `appearance: Dictionary`:
  - chaves `body` (&"male"/&"female"), `outfit`, `head`, `weapon` e `offhand`;
  - valor = `visual_id` ou &"";
  - `outfit` padrão = &"traveler".
- Regra: o cosmético do espaço, se houver, **sobrepõe** o visual do equipamento real (GDD §14.3).
- Recalcula ao equipar ou desequipar.

### Arquivos de aparência (C produz)
- **Roupa = folha inteira do personagem**, porque a roupa cobre o corpo:
  `assets/characters/outfits/chr_<body>_<outfit>_{idle,walk,sit}.png`.
  O outfit `traveler` continua sendo o `chr_traveler_<body>_*` atual.
- **Camadas sobrepostas** (cabeça, arma, mão secundária) vêm **já alinhadas quadro a quadro** com as folhas do corpo: mesmo tamanho de quadro, mesmas linhas S/SE/L/NE/N, mesmas colunas, transparente fora do item.
  `assets/equipment/<slot>/<visual_id>/<body>_{idle,walk,sit}.png`.
  Para armas e escudos vistos de costas, a variante `_back` (ex.: `male_walk_back.png`) é desenhada **atrás** do corpo.
- Alinhamento (recomendado): editar o quadro-base com a IA ("add a straw hat") e extrair só os pixels do item pela diferença com o quadro original. A alternativa é posicionar um sprite do item por direção usando pontos de âncora por quadro.
- **Mínimo deste marco:**
  - roupas `traveler` e `leather_jerkin`;
  - cabeça `straw_hat`;
  - armas `blade` (facão e espada curta compartilham) e `staff` (cajado e varinha compartilham);
  - cosmético `ipe_flower_crown`: coroa de flores de ipê, item novo com `is_cosmetic = true`, que a criança curiosa dá de presente numa opção de diálogo. O diálogo usa `action = &"give_item"` com `action_args = {"item_id": &"ipe_flower_crown", "qty": 1, "once": true}` (campo novo em `DialogueOption`; A implementa a ação; C cria o item e o diálogo).

### Cliente (B)
- `EntityVisualFactory` monta o personagem em camadas na ordem do GDD §17.4:
  sombra → offhand_back → weapon_back → roupa/corpo → cabeça → weapon_front → offhand_front.
  Todas as camadas usam o mesmo quadro, espelhamento e animação.
- Nas linhas N/NE (e espelhos), as variantes `_back` vão atrás do corpo; nas outras, na frente.
- `set_appearance(appearance: Dictionary)` reconstrói as camadas quando o valor replicado muda. Arquivo ausente → a camada é omitida com aviso, sem travar.
- Janela de equipamento: os 3 espaços cosméticos aparecem separados dos 7 normais.

### NPCs têm identidade própria
Cada NPC precisa ter visual próprio: idade, corpo, roupa medieval com sabor brasileiro, cabelo e cores diferentes, seguindo as descrições do GDD §17.7 e do `proximos-passos.md` §3.1. **Nada de moletom, mochila ou rosto do Viajante.** Só o *estilo de desenho* é compartilhado (proporção, contorno, sombreamento). As folhas atuais em `assets/npcs/` são cópias provisórias do Viajante e **devem ser substituídas**.


## ADENDO 2 (27/09/2026) — Personalização do personagem (GDD §6.1)

- `appearance` (NetEntity) ganha as chaves: `skin` (0–5), `hair_style` (StringName), `hair_color` (0–9), `eye_color` (0–5), `earrings` (StringName, &"" = nenhum). Valores padrão reproduzem o Viajante atual.
- **Camadas do jogador** (ordem GDD §17.4): sombra → offhand_back → weapon_back → **corpo-base** (com máscaras de pele e olhos) → roupa → **cabelo** → **acessório de rosto** → cabeça (chapéu/cosmético) → weapon_front → offhand_front. Chapéu cobre o cabelo (o cabelo continua desenhado; a arte do chapéu é feita por cima).
- **Arquivos** (mesmo formato de folha: quadro 96x96, linhas S/SE/L/NE/N):
  - corpo-base: `assets/characters/base/chr_<body>_base_{idle,walk,sit}.png` + máscaras `..._mask_{idle,walk,sit}.png` (canal R = pele, G = olhos; B livre).
  - cabelo: `assets/characters/hair/<style>/<body>_{idle,walk,sit}.png` em **rampa de cinza** (4–6 tons) recolorida por shader.
  - acessórios de rosto: `assets/characters/face/<id>/<body>_{idle,walk,sit}.png`.
  - paletas: `data/customization/palettes.tres` (6 peles, 10 cabelos, 6 olhos — subconjunto da paleta mestra v2) e `data/customization/options.tres` (estilos e acessórios por corpo, chaves de tradução).
- **Shader** `assets/shaders/char_palette_swap.gdshader`: recebe a rampa escolhida e troca os tons da máscara/rampa de cinza, mantendo contorno e pixels nítidos.
- **Servidor:** valida as escolhas contra `options.tres` na criação; salva junto do personagem; aparência não muda depois da criação (mudança paga/obtida jogando = futuro, só visual).

## ADENDO 3 (27/09/2026) — Movimento por células (GDD §10.1)

`NavMover` foi substituído por **`GridMover`** (`scripts/shared/entities/grid_mover.gd`) sobre `WalkGrid` + `GridPathfinder` + `MovePath` + `NetClock` (`scripts/shared/grid/`). O `NetEntity` replica `move_state` (caminho de células + horário de início no relógio do servidor + ms por célula) em vez de posições interpoladas; `net_position` só no spawn. `Balance.cfg.client_interp_delay_ms` e `player_move_speed` não são mais usados. Velocidade: `walk_ms_per_cell`; NPCs: `NpcDef.move_speed` (m/s) convertido em ms por célula.

## ADENDO 4 (30/09/2026) — Terra do Sabiá: efeitos de status, cura e arco (Q → agente de efeitos)

Desenho: `TITULOS-E-SKILLS.md` §3 (v0.4). O servidor (Q: `scripts/server/progression/`) aplica as mecânicas; o cliente só desenha. Nada muda em `skill_cast` e `cast_cancelled` (continuam como no Apêndice Q).

### Sinais novos (servidor → todos da instância)

| Autoload | Sinal | Quando |
|---|---|---|
| `NetCombat` | `healed(source_id: int, target_id: int, amount: int)` | Toda cura aplicada por `CombatService.heal()` (skills de cura, cura contínua a cada tique, roubo de vida). `source_id` = entidade que curou (0 = sem fonte). Só sai se `amount > 0`. |
| `NetProgress` | `status_changed(entity_id: int, status_id: StringName, skill_id: StringName, active: bool, duration_sec: float)` | Um efeito começou (`active = true`, `duration_sec` = duração total) ou acabou (`active = false`, `0.0`): fim do tempo, escudo gasto, contragolpe usado, invisibilidade quebrada ao atacar, limpeza (Emplastro). Renovar o mesmo efeito da mesma skill manda `active = true` de novo com a duração nova. |

`status_id` (um por tipo de efeito; `skill_id` diz qual skill):

| `status_id` | Efeito | Skills (exemplos) |
|---|---|---|
| `buff` | reforço genérico (ATQ, MATQ, DEF, crítico, esquiva, alcance, dano recebido, roubo de vida, imunidade a controle, não cair, lâmina encantada, críticos garantidos) | Amolar o Facão, Casca Grossa, Mutirão, Raiz que Segura, Aguentar Firme, Fúria |
| `debuff` | enfraquecimento (ATQ, MATQ, DEF, dano recebido, cura recebida) | Rugido da Onça, Flecha de Aviso, Assobio Agourento, Agouro, Urro, Fumaça Amarga |
| `taunt` | provocado (monstro preso ao alvo de quem provocou) | Chamado do Tronco, Batida no Casco |
| `root` | preso (não anda; ataca) | Raiz Presa, Armadilha de Cipó, Visgo, Tocaia |
| `stun` | atordoado | Investida, Prisão de Cristal, Pisada de Anta, Mergulho do Gavião, Empurrão de Casco |
| `stealth` | invisível para monstros | Lama no Corpo |
| `shield`, `def_buff`, `slow`, `dot` | os do MVP (escudo, Postura de Ferro, lentidão, dano contínuo) | Barreira, Cristal Repartido, Rajada Gélida, Flecha de Espinho |
| `hot`, `mp_regen` | cura/mana contínua | Garrafada, Seiva que Corre, Paciência de Jabuti, Brilho do Cristal |
| `counter` | contragolpe armado | Resposta da Aroeira |

- **Família visual:** `SkillDef.vfx` das skills novas usa `heal`, `buff`, `debuff`, `taunt`, `root`, `stun`, `arrow`, `slash`, `spark`, `flame`, `shield`, `guard`, `blink`, `stealth`, `cleanse`, `mana`, `counter`, `dash`, `knock`, `poison`. Escolas (`SkillDef.school`): `blade`, `arcane`, `bow`, `support`, `tank`, `hybrid`.
- **Deslocamentos** (empurrar, puxar, recuo, Passo Estelar, avanço): o servidor usa `GridMover.place()` na célula final; o cliente vê o `move_state` novo (sem sinal próprio).
- **Arco:** `ItemDef.weapon_kind = BOW` (3), `simple_bow` com `visual_id = &"simple_bow"`; o `EntityVisual.weapon_attack_style()` manda todo visual que termina em `bow` para o estilo `&"bow"` (folha `_attack_bow`). Ataque básico físico a 8 células.
- **ATQ pela arma** (GDD §6.2, 30/09/2026): `Net.stats_changed` traz `atk_attr` = índice em `CharacterStats.ATTRIBUTES` do atributo que deu o ATQ (FOR, DES ou INT); as janelas mostram "ATQ 34 (DES)".

### Servidor (para quem mexe no combate)

- `CombatService.deal_damage` chama `CombatBridges.pre_hit` (reforços, contragolpe, esquiva, crítico) antes da fórmula e `CombatBridges.post_hit` (roubo de vida, lâmina encantada) no fim; `_apply_hp_loss` chama `lethal_guard`; `heal()` usa `heal_multiplier` e emite `healed`; `is_valid_victim` ignora quem está invisível; monstro preso não anda.
- Quests: `QuestStep.variant` (`any`/`rare`/`boss`/`atroz`), `distinct_species`, `no_death`, `trial_mode = survive` e `protect`.
- **Mudas protegidas** (`trial_mode = protect`, Vó Aninha): são entidades `kind = monster` com `def_id = &"pequi_seedling"` (folhas em `assets/quest_props/pequi_seedling/`, mesmo formato dos monstros, `_death` segura o último quadro: muda caída). Jogador não ataca (clicar seleciona: `attack_target_changed` + mensagem com a vida); monstros atacam (`is_valid_victim`); cura/escudo/reforço do dono valem (`NetCombat.healed`, `status_changed`). Ao cair, sai `entity_died` e o corpo murcho fica até a provação acabar. A variante vem de `CombatService.last_kill` (agente de monstros) ou, sem ele, do `MonsterBrain` que acabou de morrer.

## ADENDO 6 (30/09/2026) — Mapas compartilhados e grupo (decisão do dono; GDD §5)

"Vamos remover o esquema de instância e pôr o recurso de grupo, tanto na UI quanto usando o chat /grupo nome."

### Instâncias

- `MapTransfer.instance_id_for(map_id)` devolve sempre `Net.make_instance_id(map_id)` = `map_id`. Não existe mais `solo_*` nem `party_*`; o filtro de visibilidade por `instance_id` (GDD §5.6) continua, agora por mapa. `Net.make_instance_id(map, sufixo)` só é usado pelos testes que criam uma instância extra para conferir o filtro.
- `BossKillTracker`: contador por mapa; contadores antigos `mapa:x` somam no do mapa ao carregar (`merge_into_maps`).

### Disputa justa (servidor)

- `MonsterBrain.damage_by_peer` (peer → dano; zera ao voltar para casa) e `top_damage_peer()`. O `killer_peer` de `monster_killed` / `last_kill.killer_peer` é o **dono** (maior dano). `last_kill` ganhou `position` e `trial_owner`; o log `monster_killed` traz `last_hitter`, `damage` e `owner`.
- `Progression._on_monster_killed`: `PartyService.credit_peers(dono, instância, posição)` = dono + membros do grupo vivos no mesmo mapa a até `party_share_range_cells`; cada um recebe `PartyService.share_xp(xp, n)` = `xp × (1 + party_xp_bonus_per_member × (n − 1)) / n` e o crédito de quest (com o "sem cair" de cada um). Log `party_kill_shared`.
- `DropService`: o drop é do dono e do grupo por `drop_owner_sec`; depois livre (`may_pick`). Recusa `pickup_not_owner` / `SYS_DROP_NOT_YOURS`.
- Provação: `QuestService` só fecha a provação de derrotar com o monstro dela (`kill_info.entity_id == trial.entity`).
- Aliados (suporte): `CombatBridge.allies_near` / `is_ally` e `SkillCaster` (alvo aliado) = o próprio jogador, os membros do grupo e os protegidos da provação dele ou do grupo (`Progression.is_protected_ally`).

### Rede: autoload `NetParty` (`scripts/shared/net_party.gd`, `/root/NetParty`)

`Balance.cfg.protocol_version` subiu para **3** (cliente antigo recebe "atualize o jogo").

| Direção | Chamada / sinal | Validação e uso |
|---|---|---|
| cliente → servidor | `send_command(cmd, arg)` (`_srv_command`) — `cmd` ∈ `invite`, `accept`, `decline`, `leave`, `kick`, `leader`, `list`, `online`; atalhos `send_invite(nome)`, `send_accept()`, `send_decline()`, `send_leave()`, `send_kick(nome)`, `send_make_leader(nome)` | `Net._accept_world_intent` (taxa, handshake, no mundo); tipos; `arg` ≤ 64; comando desconhecido = `party_bad_args`. Regras no `PartyService`. |
| servidor → dono | `party_changed(state)` (`_cli_party_state`) | `{}` = sem grupo; senão `{"leader": nome, "max": 5, "members": [{"name", "level", "hp", "max_hp", "mp", "max_mp", "map", "online", "is_leader", "entity_id"}]}` na ordem de entrada. Reenviado a cada `party_state_interval_sec` só se mudou. Cache: `NetParty.client_party`. |
| servidor → convidado | `invite_received(from_name, timeout_sec)` / `invite_closed()` | Janela Aceitar/Recusar. Cache: `NetParty.client_invite_from`. |
| servidor → quem pediu | `player_list_received(kind, entries)` | `kind` = `online` (todos, ordem alfabética) ou `party`; `entries` = `[{"name", "level", "map", "is_leader", "online"}]`. |
| só cliente | `player_menu_requested(entity_id, name)` | Clique (esquerdo, pelo `NetCombat.route_interact`, ou direito sem arrastar, pelo `ClientView`) em outro jogador; o `GameUI` abre o `PlayerMenu`. |

### Chat

- `ChatService.CHANNELS` = `local`, `party`. Comandos (antes do bloqueio de chat e do limite de 1/s): `/grupo` (lista), `/grupo <nome>`, `/grupo aceitar|recusar|sair`, `/grupo expulsar <nome>`, `/grupo líder <nome>` (também `lider`, `convidar`, `lista`, `ajuda`), `/online` (e `/quem`). `/g <mensagem>` (ou `/p`) e o canal `party` (aba "Grupo") vão só para os membros online, em qualquer mapa, passando pelo filtro, pelo bloqueio e pelo limite de 1/s.
- Mensagens em `localization/party.csv` (`PARTY_*`, `SYS_TRIAL_NOT_YOURS`, `UI_PARTY_*`, `UI_CHAT_TAB_*`, `UI_ONLINE_HEADER`, `UI_PLAYER_LIST_*`).
- Recusas no log (`invalid_message`): `party_invite_not_found`, `party_invite_self`, `party_invite_not_leader`, `party_invite_full`, `party_invite_target_in_party`, `party_invite_too_fast`, `party_invite_pending`, `party_accept_without_invite`, `party_accept_already_in_party`, `party_accept_full`, `party_decline_without_invite`, `party_leave_without_party`, `party_kick_*`, `party_leader_*`, `chat_party_without_party`, `online_list_disabled`, `attack_not_owner`.

### Cliente (UI)

- `PartyPanel` (`scripts/client/ui/party_panel.gd`): lateral esquerda abaixo das barras; linha por membro (coroa, nome, nível, vida, mana, mapa se outro / "desconectado"); botão "Sair do grupo"; o líder clica num membro para o menu.
- `PartyInviteDialog` (Aceitar/Recusar com contagem), `PlayerMenu` (Convidar / Passar a liderança / Expulsar), abas "Todos"/"Grupo" no `ChatBox`, nome dos membros sobre a cabeça em `UIKit.COLOR_NAME_PARTY` (`EntityVisual.refresh_party_color`).

### Números (`balance_config.gd`, grupo "Party & instances")

`party_max_size` 5, `leader_reconnect_grace_sec` 180, `party_xp_bonus_per_member` 0,1, `party_share_range_cells` 30, `drop_owner_sec` 10, `party_invite_timeout_sec` 60, `party_invite_cooldown_sec` 3, `party_state_interval_sec` 0,5, `online_list_public` true (false = `/online` só com `--dev-commands`).

### Teste

`game/tests/party/run_party_test.sh` (3 clientes reais; fases `training` e `hunt`; capturas em `.work/grupo/`).

## ADENDO 7 (30/09/2026) — Troca entre personagens (pedido do dono; GDD §13.1)

### Servidor — `TradeService` (`scripts/server/trade/trade_service.gd`, `world.trade`)

- Pedido → aceite → janela → ofertas → confirmações → "Trocar" dos dois → troca atômica. Estado só em memória (cai com o servidor; nada é trocado pela metade).
- Condições (`_pair_problem`): mesmo `instance_id`, distância ≤ `trade_range_cells`, vivos, fora de combate (`trade_blocked_in_combat`, regra dos 6 s). Conferidas no pedido, no aceite, a cada 250 ms durante a troca e na hora de trocar.
- Oferta por **espaço do inventário** (`slot`, `qty`): pilha precisa existir com o mesmo item e quantidade suficiente; `ItemDef.tradeable` (novo, padrão `true`) e `ItemStack.protected` barram. Até `trade_max_items` entradas. Estrelas ≤ `CharacterData.stars`.
- Qualquer mudança desfaz `confirmed` e `committed` dos dois; o `Inventory.changed` de quem troca é observado (item usado, movido ou equipado sai da oferta ou diminui) e as Estrelas são limitadas ao que a pessoa tem.
- Execução: confere tudo de novo, simula em cópias dos dois inventários (remove o que dá, adiciona o que recebe; `Inventory.add` marca com a zona de quem recebe), aplica, ajusta as Estrelas, marca inventário e moeda para replicar e grava os dois saves. Falha = nada muda (`TRADE_FAILED` / `TRADE_ERR_NO_SPACE`).
- Logs: `trade_request`, `trade_declined`, `trade_opened`, `trade_offer` (cada mudança, com as duas ofertas), `trade_confirm`, `trade_commit`, `trade_closed` (motivo), `trade_done` (registro completo) e uma linha JSON por troca em `user://server_state/trades.jsonl` (`--state-dir` muda a pasta). Recusas (`invalid_message`): `trade_request_*` (`not_found`, `self`, `busy_self`, `target_busy`, `far`, `combat`, `dead`, `too_fast`), `trade_accept_*`, `trade_decline_without_request`, `trade_cancel_without_trade`, `trade_item_bad_args`, `trade_item_not_owned`, `trade_item_not_tradeable`, `trade_item_too_many`, `trade_stars_not_owned`, `trade_commit_not_confirmed`, `trade_execute_refused`, `trade_execute_no_space`, `trade_bad_args`.

### Rede: autoload `NetTrade` (`scripts/shared/net_trade.gd`, `/root/NetTrade`)

| Direção | Chamada / sinal | Uso |
|---|---|---|
| cliente → servidor | `send_command(cmd, a, b)` (`_srv_trade`); atalhos `send_request(nome)`, `send_accept()`, `send_decline()`, `send_item(slot, qty)` (qty 0 tira), `send_stars(n)`, `send_confirm(on)`, `send_commit()`, `send_cancel()` | `Net._accept_world_intent` (taxa, no mundo) e tipos (`item`: int, int; `stars`: int; `request`: texto ≤ 64). |
| servidor → convidado | `request_received(from_name, timeout_sec)` / `request_closed()` | Janela Aceitar/Recusar (`PartyInviteDialog` com as chaves de troca). Cache `NetTrade.client_request_from`. |
| servidor → os dois | `trade_changed(state)` | `{}` = fechada; senão `{"partner", "mine", "theirs"}`, lado = `{"items": [{"slot", "item", "qty"}], "stars", "confirmed", "committed"}` (`slot` = -1 no lado do outro). Cache `NetTrade.client_trade`. |

### Chat e interface

- `/troca <nome>`, `/troca aceitar|recusar|cancelar` (`/trade` também). Mensagens em `localization/trade.csv` (`TRADE_*`, `UI_TRADE_*`).
- `PlayerMenu` ganhou "Propor troca" (`ITEM_TRADE`). `TradeWindow` (`scripts/client/ui/trade_window.gd`, `GameWindow`): abre ao lado do inventário; o lado "Você" aceita arrasto do inventário; botão direito no inventário (`InventoryWindow.trade_open`) põe a pilha; botão direito num item da própria oferta tira; campo de Estrelas (manda 0,5 s depois de parar de mexer); "Confirmar"/"Mudar", "Trocar" (só com os dois confirmados), "Cancelar" e o X (cancelam; Esc também).

### Números (`balance_config.gd`, grupo "Trade")

`trade_range_cells` 6, `trade_request_timeout_sec` 30, `trade_request_cooldown_sec` 3, `trade_max_items` 10, `trade_blocked_in_combat` true.

### Teste

`game/tests/trade/run_trade_test.sh` (2 clientes reais no Porto; capturas em `.work/troca/`).

## ADENDO 8 (30/09/2026) — Pergaminho de Retorno (pedido do dono; GDD §11.3)

- Item `data/items/return_scroll.tres`: consumível empilhável (99), `buy_price` 20, `sell_price` 5, `use_effect` = `{return_city: true, cast_sec: 0, cooldown_sec: 10, cooldown_group: return_scroll}`. Ícone `assets/items/icons/icon_item_return_scroll.png` (desenhado por `tools/art/icons/draw_icons.py return_scroll`). Textos em `localization/return.csv`. No mercado do Porto (`data/shops/market.tres`) e no kit inicial (`CharacterData.STARTING_ITEMS`, 3).
- `CharacterData.last_city` (save `"last_city"`): gravado por `MapTransfer.on_player_placed` quando o mapa é de zona `CITY`. `MapTransfer.return_city_of(c)` = `last_city` se o mapa existe, senão `home_map_of(c)` (cidade inicial).
- `ItemService.use_item`: com `return_city`, `return_block(session)` recusa (`use_return_dead|training|trial|trade`, mensagens `SYS_RETURN_*`); fora de combate é na hora; em combate a leitura dura `Balance.cfg.return_scroll_combat_cast_sec` (1 s) e o uso pendente tem `interrupt_on_damage` (o `ItemService` ouve `CombatEvents.damage_applied`; andar e atordoamento já interrompiam). No fim confere de novo, gasta 1, começa a recarga e chama `MapTransfer.transfer(session, cidade, &"SpawnPoint")`; avisa `SYS_RETURN_DONE` com o nome da cidade. Logs `item_used` (`return_to`) e `return_scroll` (`from`, `to`, `last_city`).
- `QuestService.has_trial(peer)` (provação em andamento). Comando de teste novo: `/dev goto <map_id> [marcador]` (`ProgressionDebug`).
- Teste: `game/tests/return/run_return_test.sh` (personagem novo no treino + save pronto no Porto; capturas em `.work/retorno/`).

