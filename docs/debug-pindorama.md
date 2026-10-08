# Comandos de teste — Terra de Pindorama (títulos, árvores e anciãos)

Para o dono testar as árvores de skills, os títulos de combinação e as quests dos anciãos
(`TITULOS-E-SKILLS.md` §3, v0.4) no **jogo real**, sem editar save.

## Como ligar

```
make run-dev
```

O servidor sobe com `--dev-commands` e os comandos são digitados **no chat** do jogo. Eles nunca existem num servidor normal (`make run`, `make up`). A resposta volta como mensagem de sistema `[dev] ...`.

> Os comandos mexem **só no personagem que digitou**, e a mudança vai para o save desse personagem como qualquer progresso do jogo (título, skill, nível de skill). Nenhum arquivo de save é editado por fora.

## Comandos `/dev` (progressão, agente Q)

| Comando | O que faz |
|---|---|
| `/dev help` | Lista os comandos. |
| `/dev grant_title <título>` | Concede o título e os pais (herança). Ex.: `/dev grant_title pindorama_bow_gaviao` também dá `pindorama_bow_cerrado`. |
| `/dev learn_tree <título> [nível=3]` | Aprende as 5 skills da árvore com pelo menos esse nível, cumprindo os pré-requisitos. Os títulos automáticos entram na hora (os de combinação não). |
| `/dev skill_level <skill> <nível>` | Põe a skill direto no nível (aprende se não conhecia). |
| `/dev skill_points <n>` | Soma pontos de skill. |
| `/dev learn <skill>` | Aprende uma skill sem conferir pré-requisitos. |
| `/dev give_item <item> [qtd]` | Dá um item (ex.: `simple_bow`, `eternal_ember 2`). |
| `/dev equip_item <item>` | Dá e equipa (ex.: `simple_bow`). |
| `/dev spawn_boss <espécie> [atroz 0/1] [dx] [dz]` | Chefe (estágio 3, **sem bando**) ao lado; `1` = já em forma atroz, mesmo de dia. (O `/chefe` traz o bando.) |
| `/dev spawn_rare <espécie> [dx] [dz]` | Variante rara do estágio 1 (drops raros). |
| `/dev set_hour <0–24>` | Muda a hora do mundo (o dia vai das 6h às 18h; à noite o chefe vira atroz). |
| `/dev kill_variant <espécie ou *> <any/rare/boss/atroz>` | Conta uma derrota com essa variante para as quests (atalho para testar os passos dos anciãos). |
| `/dev quest_step <quest> <etapa>` | Pula a quest ativa para a etapa (0 = primeira). |
| `/dev quest_accept <quest>` · `/dev quest_turn_in <quest>` · `/dev quest_trial <quest>` | Aceita, entrega ou começa a provação sem ir até o NPC (os requisitos valem igual). Ex.: `lesson_bow_low_shot`, `elder_ze_steel_song`. |
| `/dev set_hp <n>` | Vida atual (para testar cura). |
| `/dev hurt_protected <dano>` · `/dev kill_protected [n]` · `/dev trial_time <s>` | Provação da Vó Aninha: fere ou derruba suas mudas; faz a provação acabar em s segundos. |
| `/dev grant_xp <n>`, `/dev set_mp <n>`, `/dev reset_cooldowns`, `/dev teleport <x> <z>` | Os de sempre do teste de progressão. |
| `/dev goto <map_id> [marcador]` | Troca de mapa direto (SpawnPoint por padrão). Usado no teste do Pergaminho de Retorno. |

Espécies de Pindorama: `stone_armadillo` (Tatu-Pedra), `enchanted_firefly` (Vaga-lume Encantado), `prank_whirlwind` (Redemoinho Arteiro).

## Comandos do agente de monstros (mesmo `make run-dev`)

`/chefe`, `/covil`, `/atroz`, `/noite`, `/dia`, `/hora`, `/anoitecer`, `/amanhecer`, `/abates`, `/derrubar` e `/ajuda` (ver `docs/chefes-dia-noite.md`). O `/derrubar chefe` derruba o chefe mais perto como golpe seu: conta para as quests com a variante certa.

## Roteiro rápido (DevAlexandre, nível 10)

1. **Arco:** `/dev equip_item simple_bow` e fale com o **Mestre Taquari** (praça, frente da casa do nordeste). A lição do Tiro Rasante aparece sem título. Para pular: `/dev learn_tree pindorama_bow_cerrado` → ganha **Flecha do Cerrado**.
2. **Árvores por título:** abra a janela de skills (K). Os botões de cima são as árvores; as skills que faltam aparecem apagadas com o que falta.
3. **Combinação (Raiz do Cerrado):** `/dev grant_title pindorama_arcane_crystal` e `/dev grant_title pindorama_bow_cerrado`, depois fale com a **Vó Aninha** (frente da casa do sudoeste). Sem os três títulos ela só conta a lenda; com eles, oferece *A Raiz Debaixo do Fogo*.
   - Itens raros: `/dev give_item pequi_root 3` (ou derrote raros: `/dev spawn_rare prank_whirlwind`).
   - Chefe sem cair: `/dev spawn_boss stone_armadillo` e derrote (ou `/derrubar chefe`).
   - Chefe atroz: `/dev set_hour 22` e `/dev spawn_boss enchanted_firefly 1`.
   - Provação: fale com a Vó e aguente 60 s de pé.
4. **Casco de Jabuti** (Velho Tião, casa do nordeste) e **Brasa no Facão** (Seu Zé Ferreiro, casa do sudeste) seguem o mesmo roteiro.
