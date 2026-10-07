# Sistema de Crendices e Amuletos Folclóricos — Perdidos MMO

> **Status**: ✅ Implementado e Validado em Produção  
> **Data de Homologação**: Outubro de 2026  
> **Testes Automatizados**: `game/tests/crendice/test_crendice.tscn` (197/197 checks aprovados)  
> **Alinhamento**: GDD §8 (Equipamentos e Encaixes), §10 (Ecologia de Drops) e §17 (Identidade Cultural Brasileira)

O **Sistema de Crendices** é a mecânica central de personalização de equipamentos de *Perdidos*. Em vez de gemas, runas ou cartas genéricas, os equipamentos possuem **Encaixes de Crendice** (slots) onde o Viajante insere **Amuletos Folclóricos** carregados de superstição popular brasileira.

---

## 1. Pilares de Design

1. **Condição de Superstição**:
   - Cada amuleto possui uma regra comportamental e temática. O poder do amuleto atinge seu valor máximo apenas se o jogador respeitar a crença tradicional em combate (ex: a Figa protege mais no desespero de vida baixa; a Arruda não tolera sujeira, lama ou veneno).
2. **Obtenção Exclusiva por Despojo e Troca**:
   - **Nenhum comerciante ou NPC vende amuletos de crendice**.
   - Os amuletos são obtidos exclusivamente como drops raros de criaturas lendárias sob condições específicas de superstição, ou através de comércio livre entre jogadores.
3. **Sono da Sorte e Altares de Crendice**:
   - Ao tombar derrotado em combate carregando amuletos de fortuna (como a Pata de Quati), a superstição é quebrada e o amuleto torna-se **Adormecido** (seus bônus cessam).
   - Para reavivar o amuleto ou engastar novos amuletos nos equipamentos, o jogador visita gratuitamente um **Altar de Crendice** presente em acampamentos, encruzilhadas e cidades.
4. **Sinergias Folclóricas Temáticas**:
   - Equipar 2 ou 3 amuletos de tradições compatíveis ativa automaticamente bônus de conjunto (*Proteção Total*, *Espírito da Caça*, *Ancestralidade Mística*, *Vigília da Noite*).

---

## 2. Catálogo Oficial dos 20 Amuletos de Crendice

| Amuleto | Slot | Efeito Base | Condição de Superstição | Origem do Drop |
|---|---|---|---|---|
| **Figa de Madeira** | Armadura / Acessório | +15% resistência a dano sombrio e maldições | O bônus dobra para +30% se o HP estiver abaixo de 30% ("protege no desespero") | Assombração da Vila (2,5%) · abatida em desespero |
| **Guia de Arruda Seca** | Capa / Manto | Imunidade a veneno e +5% regeneração de HP | Perde todo o efeito se pisar em água/lama ou sofrer veneno durante a luta | Aranha-Marrom Fantasma (1,5%) · mantendo o corpo limpo |
| **Dente de Onça-Pintada** | Arma | +8% chance crítica e +5% dano físico | Só ativa no período noturno ou no interior de florestas e matas densas | Onça-Pintada Sombria (1,0%) |
| **Pata de Quati da Sorte** | Calçado | +15% taxa de drop e +5 de Sorte (SOR) | Se o jogador morrer, o amuleto **Adormece** até ser reconsagrado num Altar | Quati Raivoso (4,0%) · caçado durante o dia ou com golpe crítico |
| **Moeda Furada de Réis** | Acessório | +10% de Esquiva (FLEE) contra o 1º golpe de combate | O jogador não pode iniciar o combate (o monstro deve desferir o primeiro golpe) | Bandido do Peabiru (2,0%) |
| **Saquinho de Sal Grosso** | Armadura | +10% de Defesa física e imunidade a Lentidão (Slow) | Mantém o passo firme; anula efeitos de pegada ou amarrações no solo | Zumbi Caipira (3,0%) |
| **Dente de Cascavel** | Arma | Golpes físicos têm 10% de chance de aplicar Veneno (DoT) | Ativa com golpes rápidos de destreza em combate próximo | Cascavel do Cerrado (1,5%) |
| **Lasca de Cristal de Ratanabá** | Arma ou Escudo | +10% dano mágico e converte 5% do dano em escudo protetor | O escudo temporário ganha 50% mais potência em ruínas e masmorras | Sentinela de Obsidiana (0,5%) |
| **Pedra de Raio (Fulgurito)** | Acessório | +10% de dano do elemento Trovão / Relâmpago | Ressonância elétrica pura que atrai faíscas arcanas | Pássaro Trovão (0,8%) |
| **Cuia de Água de Cachoeira** | Acessório | +10% de eficácia em poções de cura e +10% regen de SP | Potencializa o fluxo natural das águas limpas no organismo | Ninfas do Rio / Iara Menor (1,2%) |
| **Casca do Escorpião Atroz** | Armadura | +8% de resistência a dano físico e reflete veneno ao atacante | Só pode ser forjada a partir da carapaça de escorpiões enfurecidos da noite | Escorpião-Amarelo Atroz (1,0%) |
| **Presa de Lobisomem Noturno** | Arma | +12% de dano físico e +5% roubo de vida (Lifesteal) | O poder só canaliza durante a noite ou sob a luz da lua | Lobisomem de Encruzilhada (0,8%) |
| **Teia da Armadeira Rainha** | Calçado / Luvas | Ataques aplicam 20% de lentidão por 3s ao inimigo | A lentidão dissipa se o jogador errar um ataque consecutivo | Aranha-Armadeira Rainha (0,5%) |
| **Veneno Cristalizado da Surucucu** | Arma | Golpes venenosos espalham dano contínuo em área | Só propaga em área se estiver chovendo no mapa ou em terreno úmido | Surucucu da Mata Atlântica (0,5%) |
| **Cera de Abelha Mandaçaia** | Armadura / Escudo | Barreira que absorve acertos críticos | Requer 30 segundos fora de combate para a cera recompor a barreira | Enxame de Abelha Mandaçaia (1,0%) |
| **Casulo de Lonomia Urticante** | Armadura | Reflete espinhos hemorrágicos em atacantes físicos | Só ativa se o jogador combater de mãos livres ou arma de duas mãos (sem escudo) | Lagarta Lonomia das Árvores (1,0%) |
| **Coração de Obsidiana do Arquiteto** | Escudo / Armadura | Imunidade a Petrificação e -30% de dano de explosões | Só ressoa em plena potência enquanto o jogador estiver em movimento constante | O Arquiteto de Ratanabá (Drop Lendário Chefe) |
| **Máscara Ritual de Kuarahy** | Elmo / Acessório | Converte 15% do dano causado em cura imediata | Só canaliza roubo de vida sob a luz direta do dia (céu aberto com sol) | Kuarahy, o Soberano de Z (Drop Lendário Chefe) |
| **Lenço do Pregoeiro do Silêncio** | Capa / Manto | Imunidade a Atordoamento (Stun) e Silenciamento | O jogador deve manter ao menos 20% de mana total para conter os ecos do lenço | O Pregoeiro do Silêncio (Drop Lendário Chefe) |
| **Olho do Titã das Profundezas** | Acessório / Escudo | Escudo rochoso emergencial de 500 HP ao chegar em 15% de vida | O escudo só ativa se o jogador estiver firme e imóvel no instante do impacto | Titã das Profundezas (Drop Lendário Chefe) |

---

## 3. Mecânica de Dormência e Altares de Crendice

### Sono da Sorte
Quando um jogador é derrotado e enviado ao renascimento com a **Pata de Quati da Sorte** (ou amuletos similares com gatilho de morte), a superstição é quebrada. O amuleto passa para o estado `dormant: true`. Enquanto dorme:
- O amuleto não concede bônus de Sorte nem de Taxa de Drop.
- O slot permanece ocupado, exibindo a etiqueta visual **Adormecido**.

### Reconsagração Gratuita
Para reativar amuletos adormecidos ou engastar/desencaixar peças:
- O jogador se aproxima de um **Altar de Crendice** (interação do tipo `altar_crendice`).
- A interface `CrendiceAltarWindow` se abre no cliente.
- A consagração é **totalmente gratuita**, reavivando imediatamente todos os amuletos adormecidos do inventário e dos equipamentos equipados.

### Localização dos Altares no Mundo
1. **Porto do Despertar**: Centro do vilarejo, próximo à praça central.
2. **Campos do Sabiá**: Encruzilhada da Vereda Grande (`fields_sabia_crossroads.tscn`).
3. **Campo de Treinamento**: Ao lado da fogueira do acampamento inicial (`training_field.tscn`), próximo ao **Instrutor Bento**.

---

## 4. Sinergias de Amuletos

Quando o jogador equipa simultaneamente combinações temáticas de amuletos, o servidor detecta as tags e ativa bônus passivos adicionais:

1. **Proteção Total (Bênção das Benzedeiras)**:
   - *Requisitos*: Figa de Madeira + Guia de Arruda Seca (ou Saquinho de Sal Grosso).
   - *Efeito*: +15% de Defesa Geral, 50% de redução no tempo de duração de debuffs e imunidade total a Maldições.
2. **Espírito da Caça (Caminho da Mata)**:
   - *Requisitos*: Dente de Onça + Pata de Quati (ou Dente de Cascavel).
   - *Efeito*: +10% de Dano Crítico, +10% de Taxa de Drop adicional e +5% de Dano Físico.
3. **Ancestralidade Mística (Força dos Elementos)**:
   - *Requisitos*: Cristal de Ratanabá + Pedra de Raio (ou Cuia de Cachoeira).
   - *Efeito*: +15% de Dano Mágico, +5 de Mana recuperada por acerto e +20% de regeneração contínua de MP.
4. **Vigília da Noite (Predador do Plenilúnio)**:
   - *Requisitos*: Presa de Lobisomem + Casca do Escorpião Atroz.
   - *Efeito*: +10% de Roubo de Vida adicional e +10% de velocidade de corrida sob a luz da lua.

---

## 5. Arquitetura Técnica

- `game/scripts/shared/crendice_system.gd`: Motor central de validação de superstições, cálculo de bônus, verificação de condições contextuais (dia/noite, clima, HP, terreno) e sinergias.
- `game/scripts/shared/data/crendice_data.gd`: Banco de dados estruturado dos 20 amuletos, regras folclóricas e chaves de localização.
- `game/scripts/client/ui/crendice_altar_window.gd`: Interface de consagração e engaste no cliente.
- `game/scripts/server/server_world.gd`: Tratamento de pacotes de engaste, desencaixe, consagração e disparo de dormência na morte do jogador.
- `game/tests/crendice/test_crendice.gd`: Suíte automatizada com 197 verificações cobrindo slots, dormência, ativação de regras e sinergias.
