# Mapas, Cavernas e Campo de Treinamento — Perdidos MMO

> **Status**: ✅ Implementado e Validado em Produção  
> **Data de Homologação**: Outubro de 2026  
> **Testes Automatizados**: `game/tests/progression/test_instructor_bento.tscn` (143/143 checks aprovados)  
> **Alinhamento**: GDD §5 (Instâncias e Mapas), §9 (NPCs e Diálogos) e §17 (Direção de Arte de Cenários)

Este documento descreve a organização e o refinamento dos mapas da primeira região, com foco no **Campo de Treinamento**, seu mentor **Instrutor Bento**, os **Altares de Crendice**, o padrão visual dos biomas de campos e as galerias de caverna.

---

## 1. O Campo de Treinamento (`training_field.tscn`)

O Campo de Treinamento é a zona onde os novos Viajantes aprendem as disciplinas fundamentais antes de desbravarem as rotas dos Campos de Pindorama e as matas profundas.

### O Instrutor Bento
- **Arquivo de Dados**: `game/data/npcs/instructor_bento.tres`
- **Árvore de Diálogos**: `game/data/dialogues/instructor_bento.tres`
- **Visual**: Veterano com chapéu de palha e barba branca (`npc_elder_tiao`).
- **Posicionamento**: No acampamento central `(x: 2.4, y: 0.0, z: 1.8)`, voltado para a fogueira e o ponto de respawn do jogador.
- **Tópicos Ensinados no Diálogo**:
  1. *Combate e Atributos*: Papel de FOR, DES, INT, SAB, VIT e SOR.
  2. *Armas de Projéteis*: Destaque obrigatório de que **arcos exigem munição equipada na mão secundária (slot de escudo)**.
  3. *Sistema de Títulos*: Explicação de que não há classes pré-definidas; o progresso se dá por Títulos aprendidos com Mestres, cujas habilidades são arrastadas para a barra de atalhos.
  4. *Sistema de Crendices*: Encaixes nos equipamentos, amuletos folclóricos obtidos exclusivamente por caça/troca, e suas regras de superstição.
  5. *Sono da Sorte e Altares*: Como a morte adormece certos amuletos e como reconsagrá-los gratuitamente nos altares.
  6. *Sinergias*: Benefícios de combinar amuletos de crenças complementares.

### Altar de Crendice do Acampamento
- **Localização**: Sob `Interactables/altar_crendice` em `(x: -2.5, y: 0.5, z: 0.5)`.
- **Propósito**: Permite ao jogador iniciante testar imediatamente o encaixe de amuletos obtidos nas caças e reconsagrar a sorte caso seja derrotado pelos monstros de treino.

---

## 2. Cavernas e Galerias Subterrâneas (`cave_pindorama_mine.tscn`)

As cavernas e galerias de mineração abandonadas representam as primeiras masmorras da Terra de Pindorama.

### Ecologia e Habitantes Subterrâneos
- **Esqueletos de Garimpeiros**: Antigos mineradores que empunham picaretas enferrujadas e realizam ataques em arremetida rápida.
- **Mortos-Vivos Caipiras**: Cadáveres errantes com passos pesados que aplicam lentidão caso alcancem o jogador.
- **Morcegos das Sombras**: Criaturas ágeis de teto que atacam em bando, drenando vida e aplicando cegueira temporária.

### Direção de Iluminação e Atmosfera
- Túneis com pedras pontiagudas, trilhos de vagonetes de madeira escura e veios minerais com brilho ambarino.
- Pontos de luz bruxuleante em lamparinas a óleo nas paredes, criando sombras dinâmicas que favorecem emboscadas.

---

## 3. Padrão Visual dos Campos e Veredas

- **Campos Abertos**: Gramíneas douradas, buritis altos e ipês com copas vibrantes (amarelas e roxas).
- **Trilhas e Veredas**: Solo de terra batida avermelhada intercalado com vegetação rasteira nativa do cerrado.
- **Transição de Dificuldade**:
  - `Campos de Pindorama`: Monstros em forma comum (níveis 1 a 8).
  - `Mata Encantada`: Criaturas de porte médio e maior agressividade (níveis 8 a 16).
  - `Chapada do Céu Partido`: Covis de chefes e variantes atrozes noturnas (níveis 16 a 25).
