# Combate, Atributos e Mira Mobile — Perdidos MMO

> **Status**: ✅ Implementado e Validado em Produção  
> **Data de Homologação**: Outubro de 2026  
> **Testes Automatizados**: `game/tests/combat/test_formulas.tscn` (364/364 checks aprovados)  
> **Alinhamento**: GDD §6 (Fórmulas de Combate e Dano), §7 (Atributos e Balanço) e §9.2 (Controles e Interface Mobile)

Este documento especifica a matemática de combate, a divisão e papel de cada atributo primário, os requisitos de empunhadura e munição para armas de projéteis, e o sistema inteligente de mira tática para plataformas móveis (estilo *Albion Online*).

---

## 1. Atributos Primários e Escalamento

A cada subida de nível, o Viajante recebe **3 pontos de atributo** para distribuir livremente entre os 6 pilares:

```
[FOR] ──► Dano Físico Corpo a Corpo & Impacto
[DES] ──► Dano de Longo Alcance (Arcos / Projéteis) & Esquiva & Precisão (Exige Munição na Mão Secundária)
[INT] ──► Dano Mágico Arcano Elemental & Reserva Máxima de Mana (SP)
[SAB] ──► Magias Sagradas, Bênçãos (Buffs), Maldições (Debuffs), Potência de Curas & Regen de SP
[VIT] ──► Vida Máxima (HP), Defesa Física & Resiliência a Atordoamento
[SOR] ──► Taxa de Acerto Crítico, Probabilidade de Drops Raros & Encontros Anômalos
```

### Detalhamento dos Atributos

### 🗡️ FOR (Força)
- **Papel**: Potência muscular e vigor nos golpes com facões, espadas, machados e porretes.
- **Escalamento**:
  - `Ataque Físico Melee = Base da Arma + (FOR × Multiplicador_Arma) + Nível`
  - Aumenta ligeiramente a capacidade de quebra de postura e empurrão (*knockback*).

### 🏹 DES (Destreza)
- **Papel**: Precisão, velocidade e pontaria de armas de longo alcance (arcos e armas de arremesso).
- **Mecânica Vital de Munição**:
  - **Arcos exigem munição equipada na mão secundária (offhand / slot de escudo)**.
  - Se o jogador equipar um arco sem equipar flechas ou virotes no espaço secundário, disparos com arco não poderão ser realizados.
- **Escalamento**:
  - `Ataque Físico de Projéteis = Base do Arco + Base da Flecha + (DES × Multiplicador_Arco)`
  - Concede Esquiva passiva (`FLEE`) e velocidade de ataque (`ASPD`).

### 🔮 INT (Inteligência)
- **Papel**: Domínio das energias elementais arcanas (raio, gelo, fogo e estrelas).
- **Escalamento**:
  - `Ataque Mágico Arcano = Base da Arma Mágica + (INT × 1.8) + (Nível × 1.2)`
  - Expansão direta da reserva máxima de Mana: `SP Máximo += INT × 6`.

### 🕊️ SAB (Sabedoria / Espírito)
- **Papel**: Conexão com os saberes populares, energias sagradas e ritos medicinais.
- **Escalamento**:
  - `Potência de Cura = Base da Habilidade + (SAB × 2.0)`
  - `Magnitude de Buffs e Debuffs = Base + (SAB × 0.5%)`
  - `Dano Sagrado = Base Sagrada + (SAB × 1.6)`
  - Regeneração passiva de SP por segundo.

### 🛡️ VIT (Vitalidade)
- **Papel**: Constituição corporal e tenacidade.
- **Escalamento**:
  - `HP Máximo += VIT × 14`
  - `Defesa Física (DEF) += VIT × 0.8`
  - Reduz a duração de atordoamentos e efeitos de sangramento.

### 🍀 SOR (Sorte)
- **Papel**: O favorecimento do acaso e intuição nas trilhas.
- **Escalamento**:
  - `Chance de Acerto Crítico (%) = Base + (SOR × 0.3%)`
  - `Multiplicador de Drop Raro = 1.0 + (SOR × 0.01)`
  - Aumenta a chance de spawnar variantes de criaturas anômalas (brilhantes ou líderes de bando).

---

## 2. Sistema de Mira e Controles Mobile (Estilo Albion)

Para garantir paridade competitiva e fluidez em telas sensíveis ao toque (smartphones e tablets), o sistema de mira móvel foi projetado com base nos seguintes princípios:

### 1. Mira Inteligente por Proximidade (Botão de Mira / Trava)
- Ao pressionar o botão de mira virtual, o cliente busca o monstro vivo mais próximo dentro do raio de combate (`combat_range`).
- O monstro é travado como alvo principal (`target_id`), orientando automaticamente o arco e habilidades de alvo direto.

### 2. Retargeting Automático ao Abater o Alvo
- Quando a criatura atualmente alvejada tem seu HP zerado e morre:
  - O sistema limpa imediatamente o alvo morto.
  - Varre o entorno e **seleciona automaticamente o inimigo vivo mais próximo** em raio de até 12 metros.
  - Elimina a necessidade de o jogador ter que tocar na tela novamente para continuar a rotação de ataque.

### 3. Seleção Tática Manual por Toque Direto
- O jogador pode tocar diretamente sobre qualquer criatura visível na tela para focar o ataque nela (priorizar magos, chefes ou adds perigosos).

### 4. Retículo Visual Limpo no Solo
- A mira é sinalizada por um anel projetado no plano do solo (em torno da base do modelo 3D).
- O indicador não projeta sombras bloqueadas, caixas pretas ou oclusões em torno do modelo, garantindo nitidez visual mesmo em combate frenético à noite.

---

## 3. Títulos de Mestria e Barra de Atalhos

Em *Perdidos*, não há árvores de classes fixas ou escolhas irreversíveis:
- **Títulos de Mestria**: Ao cumprir provações e desafios com os Mestres espalhados pelo mundo (como Jatobá, Candeia, Guiomar, Nicandro e Taquari), o jogador desbloqueia Títulos.
- **Vestimentas Temáticas**: Equipar um título altera a indumentária do personagem para a vestimenta representativa daquela tradição (preservando rosto, tom de pele e olhos).
- **Habilidades Ativas**: Cada título concede 5 habilidades temáticas que o jogador pode arrastar e soltar livremente nos 10 slots da barra de atalhos (teclas 1 a 0 no PC, ou slots radiais no Mobile).
