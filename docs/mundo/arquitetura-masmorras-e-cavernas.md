# Arquitetura e Diretrizes de Cavernas e Masmorras

> **Status:** `[FECHADO]` — Diretriz canônica de design para todas as cavernas, masmorras, criptas e labirintos subterrâneos do jogo.  
> **Base:** GDD §4.0, §4.2, §10.6; `docs/mundo/atlas.md`; referências visuais de masmorras clássicas (Ragnarok Online: Byalan iz_dun, Sphinx, Pirâmide, Payon Cave).

---

## 1. Princípios Fundamentais

As cavernas e masmorras de Contária representam os maiores desafios de exploração, caça e cooperação em grupo do jogo. Para garantir profundidade tática, sensação de perigo e autenticidade visual de MMORPG clássico, todas as instâncias subterrâneas seguem rigorosamente quatro regras de ouro:

### 1.1 Progressão Vertical Descendente Obrigatória
- **Cavernas e masmorras sempre descem.** A entrada fica na superfície (ex: sob as raízes de uma floresta, na fenda de uma serra, ou no portal de uma ruína antiga) e cada nível se aprofunda no subsolo.
- **Nomenclatura padrão:**
  - `Andar 1` (`F1` / Térreo Subterrâneo)
  - `Andar 2` (`F2` / Profundezas I)
  - `Andar 3` (`F3` / Profundezas II)
  - `Andar 4` (`F4` / Covil do Chefe / Câmara Abissal)

### 1.2 Regra do Mínimo de 4 Andares
Nenhuma masmorra ou caverna pode ter menos de **4 andares**. A estrutura de progressão é dividida em 4 etapas funcionais:

```
[ Superfície: Entrada da Masmorra ]
         │
         ▼
[ 1º Andar (F1) — Transição e Bifurcações ] 
  • Iluminação tênue natural/tochas, monstros comuns da espécie (estágio 1).
  • Pelo menos 2 rotas principais que se dividem (ex: Setor Oeste e Setor Leste).
         │
         ▼
[ 2º Andar (F2) — Corredores Estreitos e Labirinto Inicial ]
  • Corredores sinuosos, passagens estreitas entre rochas/paredes antigas.
  • Maior densidade de monstros; surgem os primeiros monstros médios (estágio 2).
         │
         ▼
[ 3º Andar (F3) — Fendas Profundas e Salões do Abismo ]
  • Topologia desafiadora: passarelas sobre precipícios, ilhas de pedra sobre o vazio ou água escura.
  • Alto perigo: monstros médios agressivos em bando, emboscadas naturais.
  • Múltiplas saídas e conexões: atalhos, salas secundárias com tesouros/desafios.
         │
         ▼
[ 4º Andar (F4) — O Covil do Chefe (Boss / MVP Floor) ]
  • Clímax da masmorra: salão monumental (caverna colossal ou câmara cerimonial de alvenaria).
  • Covil fixo do Chefe (`BossLairs/`), com escolta e mecânica de dia/noite (forma atroz à noite).
  • Portal de retorno ao 3º Andar e Portal Místico de Fuga/Retorno à Superfície após a vitória.
```

### 1.3 Múltiplas Saídas e Conexões por Andar
- **Proibido layout linear em tubo reto:** Uma masmorra não é uma linha reta entre a entrada e a saída.
- Cada andar possui **bifurcações, rotas alternativas e múltiplos pontos de transição**:
  - **Rotas Paralelas:** Exemplo: um caminho largo patrulhado por bandos pesados vs. uma fenda estreita com monstros esguios e venenosos.
  - **Atalhos e Saídas Rápidas:** Portais secundários, buracos na rocha ou degraus desgastados que permitem descer para setores diferentes do andar seguinte.
  - **Salas Secundárias (Nichos de Caça):** Câmaras laterais sem saída destinadas a grupos descansarem, farmarem recursos raros ou enfrentarem monstros de elite.

---

## 2. Topologia dos Mapas (Layout Estilo Ragnarok Online)

Inspirado diretamente na estética dos dungeons clássicos do Ragnarok Online (como demonstrado nas referências da Ilha Byalan e Sphinx):

```
       [Câmara Norte]
          ▲     │
          │     ▼
    [Túnel Estreito O] ──── [Salão Central] ──── [Corredor L]
          │                        │                 ▲
          ▼                        ▼                 │
   [Câmara Sudoeste] ─────── [Fenda Sul] ────────────┘
     (com saída F2)            (saída F2)
```

1. **Salas e Câmaras Orgânicas:**
   - As áreas transitáveis não são retângulos lisos, mas conjuntos de salões arredondados ou poligonais interligados por passagens estreitas.
   - Paredes com silhuetas rochosas esculpidas, desníveis e colunas que bloqueiam a visão e o deslocamento reto, incentivando o combate tático de células.
2. **Minimapa Fiel à Grade (`WalkGrid`):**
   - O minimapa no canto superior direito reflete com clareza a silhueta das salas andáveis (claro), paredes e bordas (escuro) e o vazio intransitável, exatamente como a navegação por células clássica.

---

## 3. Identidades Visuais de Interiores

O jogo conta com duas famílias estéticas principais para interiores subterrâneos:

### 3.1 Tipo A: Cavernas e Abismos Naturais / Aquáticos (Ref.: Byalan / Payon)
- **Chão e Bordas:**
  - Piso de cascalho, pedras úmidas e terra compactada.
  - As bordas das passarelas caem diretamente para **abismos escuros** ou **águas profundas azul-turquesa** (ilhas de rocha suspensas sobre a escuridão).
- **Decorações e Atmosfera:**
  - Estalagmites pontiagudas e colunas naturais unindo chão e teto.
  - Aglomerados de cristais luminescentes (azuis e esmeraldas) que fornecem iluminação pontual.
  - Cogumelos fosforescentes e musgo nas reentrâncias úmidas.
  - Em cavernas aquáticas/marinhas: estrelas do mar, conchas, corais e poças de maré nas pedras.
- **Iluminação:**
  - Luz ambiente fria e azulada com névoa volumétrica baixa (`fog_density` calibrado).
  - Fachos de luz solar que penetram por fendas do teto nos primeiros andares, desaparecendo completamente nos andares 3 e 4.

### 3.2 Tipo B: Masmorras Antigas, Ruínas e Criptas (Ref.: Sphinx / Pirâmide / Catacumbas)
- **Chão e Paredes:**
  - Chão revestido de lajotas de pedra talhada desgastadas pelo tempo, com rachaduras e lajes desniveladas.
  - Paredes de cantaria maciça com baixos-relevos talhados na pedra, contando lendas e inscrições antigas.
- **Decorações e Arquitetura:**
  - Pilares monumentais quadrados de sustentação formando naves e corredores.
  - Tocheiros de ferro forjado fincados no piso e candelabros com chamas vivas.
  - Portais cerimoniais em arco de pedra, com runas arcanas luminosas.
  - Grades de ferro antigas, sarcófagos de pedra e nichos nas paredes.
- **Iluminação:**
  - Contraste dramático entre a escuridão dos corredores e o calor dourado das tochas e braseiros.

---

## 4. Estrutura da Masmorra MVP: Caverna do Reino Encoberto

A primeira masmorra completa da Terra de Pindorama implementa integralmente este padrão:

| Andar | Nome Canônico | Nível | Tipo de Interior | Destaques de Topologia e Conteúdo |
|---|---|---|---|---|
| **1º Andar (F1)** | `cave_reino_encoberto` | 12–16 | Caverna de Raízes | Entrada sob as raízes da Mata Encantada. Dois setores separados por pilar de pedra. Vagalumes encantados e pegadas na lama. |
| **2º Andar (F2)** | `cave_reino_encoberto_2` | 16–20 | Fendas e Estalagmites | Corredores labirínticos estreitos. Passagens rochosas com colunas de pedra e primeiras criaturas agressivas. |
| **3º Andar (F3)** | `cave_reino_encoberto_3` | 20–24 | Caverna do Abismo | Passarelas rochosas sobre abismo escuro. Múltiplas saídas e salas secundárias com bandos de lobos menores. |
| **4º Andar (F4)** | `cave_reino_encoberto_4` | 25–30 | Covil do Lobisomem | Salão colossal com altar de pedra antigo. **Covil do Chefe (`BossLairs/werewolf`)** com bando. Portal de retorno e Fenda de Luz para a superfície. |

---

## 5. Próximas Masmorras Planejadas do Atlas

Seguindo este mesmo padrão de 4 andares e Chefe no F4:

1. **Brejo do Corpo-Seco (Pindorama):** 4 andares subterrâneos sob as águas paradas; F4 abriga o Chefe Corpo-Seco Ancestral.
2. **Remanso da Iara (Pindorama):** 4 andares de palácio submerso estilo Byalan; F4 abriga o Santuário da Iara no fundo do rio.
3. **Toca do Mapinguari (Pindorama):** 4 andares de grutas de terra vermelha e ossadas; F4 abriga o Mapinguari Titânico.
4. **Labirinto do Minotauro (Costa das Colunas):** 4 andares de masmorra clássica de alvenaria e pilares; F4 abriga o Minotauro Ancestral.
5. **Galerias da Esfinge (Areias do Nilo):** 4 andares de cripta e corredores de arenito talhado; F4 abriga a Câmara da Esfinge.
