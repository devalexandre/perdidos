# Proposta de Monetização — Projeto Isekai

> **Versão:** 0.1 — 27/09/2026
> **Base:** GDD §1, §2 (pilar 6), §3.2, §3.3, §4.0, §6.1, §8.5, §12.4, §13, §14, §15.6, §15.7, §17.4 e `TITULOS-E-SKILLS.md` §1.1.
> **Status:** proposta. As regras de §14.1 do GDD são `[FECHADO]` e este documento **não as altera**, só as detalha. Tudo que é legal aqui é `[PROVISÓRIO — requer validação jurídica por advogado]`.
> **Pesquisa legal:** feita em 27/09/2026. Cada afirmação legal tem link e data de acesso (seção 11). Onde a regra ainda depende de regulamento, isso está escrito.

> ⚠️ **Aviso:** este documento é pesquisa de design e **não é parecer jurídico**. **Requer validação jurídica por advogado** (consumidor, proteção de dados e direito digital) e **validação tributária por contador** antes de qualquer loja entrar no ar.

---

## 1. Resumo executivo

1. **Modelo:** jogo 100% gratuito; receita só com **cosméticos com preço fixo em reais** e um **passe de temporada cosmético** (trilha gratuita + trilha paga), tudo determinístico.
2. **Sem moeda premium:** cada item mostra o preço em R$ e é comprado direto (Pix ou cartão). Sem "gemas", sem pacotes de moedas, sem sobra de saldo.
3. **Zero aleatoriedade paga para qualquer idade:** nada de caixas de recompensa (loot boxes), roletas, gacha ou "chance aumentada". Isso nos tira do art. 20 do ECA Digital e dispensa a verificação de idade que o Decreto 12.880/2026 exige de quem tem loot box.
4. **Dinheiro nunca compra poder:** gameplay, skills, títulos, proteção de itens (§12.4) e toda a personalização básica (§6.1) ficam gratuitos para sempre.
5. **Passe sem FOMO:** o passe comprado **não expira**; passes antigos voltam à venda; o progresso vem de jogar (quests, feitos), **nunca de tempo logado** nem de login diário.
6. **Menores:** compras **bloqueadas por padrão** para menores de 18; só um responsável vinculado pode liberar, com limite de gasto definido por ele; nada de publicidade dirigida nem de notificações de loja para menores.
7. **Consumidor:** arrependimento de 7 dias sem perguntas pelo próprio jogo, recibo imediato, preço total em R$, sem contadores de urgência.
8. **Objetivo financeiro:** cobrir servidor e custos fixos (estimativa: R$ 500 a R$ 1.000/mês), não gerar lucro.
9. **Quando:** só **depois do playtest do MVP** (GDD §3.2 e §3.3). No MVP, apenas a camada de aparência (§14.3/§17.4) e campos de conta preparados.
10. **Ordem:** loja no PC com Pix → passe de temporada → Android com Google Play Billing.

---

## 2. Princípios e linha vermelha

### 2.1 Princípios (vindos do GDD)

| Princípio | Origem |
|---|---|
| Objetivo do projeto é **divertir, não lucrar**. A meta de receita é pagar a conta do servidor. | GDD §1, §14.1 |
| **Justo com todos:** dinheiro compra aparência, nunca poder. | GDD §2 (pilar 6) |
| Receita só por **cosméticos** e **passe de batalha cosmético**. | GDD §1, §14.1 `[FECHADO]` |
| **Sem RMT**: sem venda de itens entre jogadores por dinheiro real, sem mercados externos. | GDD §14.1 `[FECHADO]` |
| **Nenhuma recompensa aleatória ligada a dinheiro.** | GDD §14.2 |
| **Títulos** nunca vendidos nem acelerados; no máximo uma moldura cosmética para título já conquistado jogando. | GDD §8.5; `TITULOS-E-SKILLS.md` §1.1 |
| **Proteção de itens** só se obtém jogando, nunca comprando. | GDD §12.4 |
| Cosméticos comprados ficam **presos à conta**. | GDD §14.2 |
| Cosméticos respeitam as **regras culturais** (sem nomes de divindades de religiões vivas, fontes do próprio povo). | GDD §4.0, §8.5 |

### 2.2 Linha vermelha (o que nunca fazemos)

| # | Nunca | Por quê |
|---|---|---|
| 1 | Vender poder: atributos, XP, nível, pontos de skill, skills, títulos, drop, proteção de itens, espaço de inventário/armazém que dê vantagem, atalhos de quest, revive, teleporte pago | GDD §14.1, §12.4 |
| 2 | Loot box, gacha, roleta, "baú misterioso", chance de drop aumentada, sorteio pago (para **qualquer** idade) | ECA Digital art. 20; Decreto 12.880 art. 15 §1º VII e art. 23 |
| 3 | Moeda premium que esconda o preço real ou deixe sobra obrigatória | CDC art. 31 e 39; Decreto 5.903 art. 2º |
| 4 | Venda ou troca de itens pagos entre jogadores; qualquer ponte com dinheiro real | GDD §14.1; Lei 14.852 art. 5º, parágrafo único |
| 5 | Timers de urgência ("só hoje!", "restam 02:13:44"), ofertas relâmpago, preço "de/por" fictício | Decreto 12.880 art. 10, II; Portaria MJSP 1.048/2025 art. 52, XIX; CDC art. 37 |
| 6 | Recompensa por tempo logado ou login diário em sequência ("streak") | ECA Digital art. 17 §4º II; Decreto 12.880 art. 9º, III |
| 7 | Publicidade de terceiros no jogo, anúncios dirigidos a menores, perfilamento para vender | ECA Digital art. 22 e 26; Decreto 12.880 art. 33 |
| 8 | Pop-up de loja interrompendo o jogo, notificação push de oferta, loja na tela de morte/túmulo | Decreto 12.880 art. 9º e 10; CDC art. 39, IV |
| 9 | Dificultar reembolso, cancelamento ou o controle parental (confirmshaming, caminhos confusos) | Decreto 12.880 art. 10, I e III; Decreto 7.962 art. 5º |
| 10 | Vender cosmético que imite item conquistável de prestígio (ex.: visual do chefe Boitatá) sem que a versão conquistada seja diferente e reconhecível | Pilar 6 do GDD (prestígio de quem jogou) |

---

## 3. O que vendemos

### 3.1 Catálogo proposto

| Categoria | Exemplos | Camada técnica | Observações |
|---|---|---|---|
| **Chapéus e adornos de cabeça** (carro-chefe) | chapéu de palha de festa junina, coroa de flores de ipê, capuz de renda de bilro, chapéu de couro de vaqueiro | `head_gear` sobreposto (§17.4) | Principal forma de expressão. Opção "esconder visual" já existe via camada |
| **Roupas sobrepostas** | trajes regionais, roupas de festa, visuais de temporada | `outfit` (+ `boots`) sobreposto | O equipamento real continua valendo; só muda o desenho |
| **Estilos de cabelo extras** | penteados de temporada | `hair` | **Ver 3.3:** o conjunto de criação continua completo e gratuito |
| **Emotes extras** | dança de frevo, capoeira (ginga), sanfona | balão/animação (GDD §13) | Os 6 emotes básicos continuam gratuitos |
| **Molduras de nome** | moldura de título (só para título já conquistado) | UI | Nunca vende o título; `TITULOS-E-SKILLS.md` §1.1 |
| **Balões de chat** | balão de cordel, balão de azulejo | UI | Texto sempre legível; moderação (§13) não muda |
| **Temas de interface / minimapa** | moldura de minimapa em xilogravura | UI local | Sem informação extra de gameplay |
| **Pets visuais** (futuro, pós-pets no jogo) | filhote de capivara que só segue | sprite próprio | **Sem** coleta, buff, inventário ou qualquer função. Só depois que pets existirem (GDD §3.2) |

**Regra de validação:** todo cosmético passa pelo checklist de arte (§17.10) e por uma pergunta obrigatória: *"isso dá qualquer vantagem, inclusive visual (camuflagem, esconder hitbox, poluir a tela de outros)?"* Se sim, não vai à loja. Exemplos proibidos: roupa que se confunde com o chão de um mapa, efeitos de partícula que tapam monstros.

### 3.2 Como os cosméticos usam a camada de aparência (§14.3 e §17.4)

- Cada espaço visível (`outfit`, `boots`, `hair`, `head_gear`, e depois `weapon_*`) ganha um **visual sobreposto opcional**: `appearance.overlay[slot] = cosmetic_id | null`.
- O **equipamento real** define atributos; o **overlay** define só o desenho. Morrer e perder o equipamento (§12) **não afeta** o cosmético.
- O **servidor é autoritativo**: ao carregar o personagem e a cada troca, o `game-server` confere se a conta tem o direito (`entitlement`) àquele `cosmetic_id`. Sem direito → overlay vazio.
- A aparência replicada aos outros jogadores é a mesma de hoje (`characters.appearance`, §6.1); o overlay só entra no JSON.
- Cosmético comprado é **da conta** (todos os personagens podem usar) e **intransferível**.

### 3.3 O que fica gratuito para sempre

| Gratuito para sempre | Detalhe |
|---|---|
| Todo o gameplay | mapas, quests, chefes, PVP, grupos, chat, amigos |
| Todas as skills e escolas | só por quest com Mestre (§8.1) |
| Todos os títulos e ramos | conquistados jogando (§8.5) |
| Proteção de itens | só jogando (§12.4) |
| Personalização de criação | todos os tons de pele, cores de olhos, **todos os estilos de cabelo da criação × 10 cores**, brincos e acessórios de rosto da criação, as 3 roupas de Viajante (§6.1). A meta do GDD de 8 estilos por corpo continua gratuita |
| Emotes básicos | os 6 do §13 |
| Recursos de conta | espaços de personagem, armazém, troca de nome por erro de digitação na 1ª semana |
| Cosméticos conquistados | recompensas de feitos, alcunhas (`TITULOS-E-SKILLS.md` §7, item 10), trilha gratuita do passe |

**Estilos de cabelo pagos (pergunta do briefing):** permitir **só** estilos novos de temporada, **sem** retirar nada do conjunto de criação, e com pelo menos um estilo equivalente obtido jogando a cada temporada. Assim ninguém se sente "feio de graça".

---

## 4. Passe de temporada (cosmético)

### 4.1 Como encaixa em "temporadas"

As temporadas (fora do MVP, §3.2) são **temáticas**, ligadas às regiões e ao folclore (§4.0): ex. "Temporada das Festas Juninas", "Temporada do Boitatá". Cada temporada traz um evento de gameplay **gratuito** e um passe cosmético com a mesma estética.

### 4.2 Regras do passe

| Regra | Proposta | Motivo |
|---|---|---|
| Conteúdo | Só cosméticos; zero poder | GDD §14.1 |
| Recompensas | **Determinísticas**: o jogador vê todas as recompensas de todos os níveis antes de comprar | ECA Digital art. 2º IV e 20; CDC art. 31 |
| Bônus extra | Se houver, **fragmentos** trocáveis por um cosmético **escolhido** numa lista fixa (GDD §14.2). Nunca sorteio | GDD §14.2 |
| Trilhas | **Gratuita** (todos) + **paga** (R$) | GDD §14.1 |
| Como avança | Pontos de passe por **atividades de jogo** (quests, derrotar chefes, resgatar túmulo de amigo, explorar mapa). **Sem pontos por tempo logado, sem login diário, sem sequência** | ECA art. 17 §4º II; Decreto 12.880 art. 9º |
| Duração | **~12 semanas** de temporada ativa | Ritmo razoável para quem joga pouco |
| Tamanho | Completável jogando ~3 a 4 h por semana | Evita "segundo emprego" |
| **Expiração** | **O passe comprado nunca expira.** Quem comprou pode continuar avançando nele depois que a temporada acaba | Elimina a principal fonte de FOMO |
| Passes antigos | Voltam à venda depois (ex.: "arquivo de temporadas" 6 meses depois), com o mesmo preço | Sem escassez artificial |
| Comprar níveis | **Não vender níveis do passe.** No máximo, um "pacote completo" que já entrega a trilha paga inteira, com preço fixo | Evita pagar para pular grind criado de propósito |
| Pressão | Sem contagem regressiva na tela, sem aviso "faltam X dias!" em vermelho; a data de fim fica numa linha discreta de informação | Decreto 12.880 art. 10, II |
| Menores | Passe pago segue a mesma regra de compras (seção 6) | Lei 14.852 art. 17 |

---

## 5. Moeda: usar moeda premium?

### 5.1 Análise

| | Com moeda premium ("Gemas") | Sem moeda premium (preço em R$) |
|---|---|---|
| Transparência (CDC art. 31; Decreto 5.903 art. 2º: preço claro "sem necessidade de interpretação ou cálculo") | Ruim: o jogador precisa converter gemas → R$ | Ótima: "R$ 9,90" |
| Sobra de saldo | Pacotes que nunca batem com o preço criam sobra e induzem nova compra (pode ser vista como prática abusiva, CDC art. 39) | Não existe |
| Arrependimento (CDC art. 49) | Complexo: reembolsar gemas já gastas? parte do pacote? | Simples: 1 compra = 1 item = 1 estorno |
| Menores | Distância psicológica do dinheiro real; risco sob art. 39, IV do CDC e art. 10, II do Decreto 12.880 | Preço real sempre visível |
| Classificação indicativa | "Microtransações" é fator de risco (Lei 14.852 art. 3º §2º; Decreto 12.880 art. 12 §2º IV) | Continua sendo microtransação, mas sem agravante de opacidade |
| Taxas de pagamento | Menos transações (compra-se um pacote) | Mais transações pequenas → taxa fixa por transação pesa mais |
| Contabilidade | Saldo de gemas vira passivo a controlar | Receita por item, mais simples |
| Preço regional futuro | Fácil ajustar pacote | Fácil ajustar preço do item |

### 5.2 Recomendação

**Não usar moeda premium.** Todo item e o passe têm preço fixo em R$, comprados direto. É o modelo mais simples de explicar, reembolsar e auditar, e o mais alinhado a "divertir, não lucrar".

Para reduzir o peso da taxa fixa por transação, oferecer **conjuntos com preço próprio** (ex.: chapéu + roupa do mesmo tema) e um **carrinho** (vários itens em um só pagamento, com o total em R$ antes de pagar).

Se no futuro uma moeda premium for inevitável (ex.: exigência de uma plataforma), as regras seriam: preço em R$ sempre ao lado; pacotes em valores que casem exatamente com os preços dos itens; comprar a quantidade exata que falta; saldo sem validade; reembolso proporcional do saldo não usado. **Hoje não recomendamos.**

---

## 6. Menores de idade

### 6.1 O que a lei exige (resumo)

| Regra | Fonte | Situação |
|---|---|---|
| Loot boxes proibidas em jogos direcionados ou de **acesso provável** por crianças e adolescentes | Lei 15.211/2025 (ECA Digital) art. 20 | Em vigor desde 17/03/2026 (art. 41-A) |
| Jogo com loot box precisa de **verificação de idade** para bloquear a função a menores; versões **sem** loot box ficam **dispensadas** dessa verificação | Decreto 12.880/2026 art. 23 e §1º | Em vigor |
| Loot box é tratada como "serviço proibido" a menores (ao lado de apostas) | Decreto 12.880 art. 15 §1º VII | Em vigor |
| Ferramentas de compra do jogo devem **restringir por padrão** compras de crianças, garantindo consentimento dos responsáveis | Lei 14.852/2024 art. 17 | Em vigor |
| Supervisão parental deve permitir **restringir compras e transações financeiras**, em português, com aviso visível quando ativa | ECA Digital art. 17 e 18 | Em vigor; ANPD ainda vai editar padrões mínimos (art. 17 §1º) |
| Configuração **mais protetiva por padrão** (privacidade e dados) | ECA Digital art. 7º | Em vigor |
| Padrões contra uso compulsivo; sem **recompensa por tempo de uso**, notificações excessivas etc. | ECA Digital art. 8º IV e 17 §4º II; Decreto 12.880 art. 9º | Em vigor |
| Proibido design manipulativo (urgência fabricada, obstrução, esconder controles) | ECA Digital art. 18 §2º; Decreto 12.880 art. 10 | Em vigor; ANPD vai regulamentar |
| Proibido perfilamento para publicidade a menores | ECA Digital art. 22 e 26; Decreto 12.880 art. 33 | Em vigor |
| Jogos com chat acessíveis a menores: interação **limitada por padrão** até consentimento dos responsáveis; denúncia, recurso, moderação | ECA Digital art. 21; Lei 14.852 art. 16 | Em vigor (afeta §13 do GDD, não só a loja) |
| Contas de até **16 anos vinculadas** à conta de um responsável | ECA Digital art. 24 | **Incerto para jogos:** o artigo está no capítulo de redes sociais, mas o texto fala em "produtos ou serviços direcionados... ou de acesso provável". Tratar como aplicável até o advogado dizer o contrário |
| Dados de **crianças (<12)**: consentimento específico e em destaque de um dos pais; não exigir dados além do necessário para jogar | LGPD art. 14 §1º e §4º; Enunciado CD/ANPD nº 1/2023 | Em vigor |
| Aferição de idade: autodeclaração **não pode ser a única barreira** para funcionalidades inadequadas | Decreto 12.880 art. 2º VII, 18 e 24; notícia da ANPD de 16/09/2026 | **Pendente:** guia definitivo da ANPD ainda não publicado (previsto após tomada de subsídios); fiscalização mais intensa a partir do início de 2027 |
| Sanções: advertência; multa de até 10% do faturamento ou R$ 10 a R$ 1.000 por usuário cadastrado (teto R$ 50 mi); suspensão | ECA Digital art. 35 | Em vigor; porte do fornecedor conta na dosimetria (art. 35 §1º III e art. 39) |

### 6.2 Precisamos de loot boxes? Não.

O projeto não ganha nada com elas e perde muito: exigiriam verificação de idade de alta confiabilidade (Decreto 12.880 art. 23), elevariam a classificação indicativa, contrariariam §14.2 do GDD e ainda arriscariam enquadramento como aposta (a Lei 14.852 art. 5º, parágrafo único, exclui do conceito de "jogo eletrônico" o que tem aposta com prêmio em ativos virtuais e resultado aleatório). **Recomendação: nenhuma mecânica aleatória paga, para nenhuma idade.** Drops aleatórios de monstros continuam existindo porque não envolvem dinheiro.

### 6.3 Desenho proposto para menores

| Item | Proposta |
|---|---|
| **Portão de idade** | No cadastro, data de nascimento em campo neutro (sem dica de "idade mínima", sem idade pré-preenchida). Guardar a data (necessária para mudar de faixa com o tempo) e derivar `age_band`: `<12`, `12–15`, `16–17`, `18+` |
| **Menores de 12** | Cadastro só com consentimento do responsável (LGPD art. 14 §1º): e-mail do responsável + confirmação por link. Coletar o mínimo (§4º) |
| **12 a 15** | Conta vinculada a um responsável (postura conservadora para o art. 24 do ECA Digital) |
| **16 e 17** | Vínculo recomendado; compras continuam bloqueadas por padrão |
| **Compras para <18** | **Bloqueadas por padrão.** Só se desbloqueiam quando o responsável vinculado (conta adulta) ativa, no **painel do responsável**, com **limite mensal** escolhido por ele (padrão sugerido: R$ 0; opções R$ 20/R$ 50/R$ 100). Cada compra do menor gera aviso ao responsável. Alternativa mais simples para a v1: **menor não compra; o responsável presenteia** o item a partir da conta dele |
| **Quem paga é adulto** | O pagamento é feito pelo responsável (Pix/cartão no nome dele). Recibo vai para o e-mail do responsável |
| **Aferição de idade** | Como o jogo **não tem loot box nem conteúdo proibido**, não recomendamos coletar documento de todo jogador (minimização, Decreto 12.880 art. 24). Mas, para **liberar compras** e para a **conta de responsável**, a autodeclaração sozinha não basta: usar sinal de idade do sistema/loja (Android, Decreto 12.880 art. 25) e, no PC, um método confiável aceito pela ANPD (ex.: solução pública gov.br quando existir, art. 28; ou provedor certificado). **Pendente:** esperar o guia definitivo da ANPD e decidir com o advogado |
| **Divergência de idade** | Se sinal da loja e cadastro divergirem, usar a opção mais protetiva (Decreto 12.880 art. 25 §4º); permitir contestação (art. 27) |
| **Painel do responsável** | Em português, fácil de achar (link no site e no menu): ver/limitar compras, ver histórico de gastos, ver tempo de jogo, limitar tempo, ligar/desligar chat e convites, ver com quais adultos o menor conversa (ECA art. 18). Aviso visível no jogo do menor: "Supervisão ativa: compras bloqueadas" (art. 17, III) |
| **Publicidade** | Nenhuma publicidade de terceiros no jogo. Nada de perfilamento para oferta. A vitrine da loja é igual para todos (sem "recomendado para você") |
| **Notificações** | Nenhuma notificação de loja/oferta para ninguém; para menores, nenhuma notificação push de engajamento |
| **Dados** | Dados de idade usados só para idade (ECA art. 13). Sem analytics de compra por perfil de menor |
| **Chat (dependência)** | Para <18: chat global e sussurro de desconhecidos **desligados por padrão**, grupo/amigos ligados só após consentimento do responsável (ECA art. 21 parágrafo único). Isso afeta §13 do GDD e deve ser decidido antes do playtest aberto |

---

## 7. Reembolso, recibos, transparência e padrões obscuros

### 7.1 Arrependimento (7 dias)

- **Regra legal:** o consumidor pode desistir em até **7 dias** de compra feita fora do estabelecimento, com devolução imediata e atualizada de tudo que pagou (CDC art. 49). No comércio eletrônico, o fornecedor deve informar de forma clara como desistir, aceitar a desistência **pela mesma ferramenta da compra**, comunicar a operadora do cartão para não lançar ou estornar, e confirmar imediatamente o pedido (Decreto 7.962/2013 art. 5º).
- **Ponto incerto:** não há no Brasil uma exceção legal expressa para conteúdo digital já "consumido" (diferente da União Europeia). A atualização do CDC para comércio eletrônico (PL 3.514/2015) continua parada na Câmara. **Não contar com exceção.**
- **Proposta:** botão **"Desistir da compra"** no histórico de compras, dentro do jogo e no site, por 7 dias, **sem perguntas**, mesmo que o item tenha sido usado. Ao desistir: o direito ao cosmético é removido (o overlay volta ao equipamento real) e o valor é devolvido pelo mesmo meio (Pix devolvido / estorno no cartão). Para o passe: devolução integral em 7 dias; os cosméticos da trilha paga voltam a ficar bloqueados.
- **Abuso:** se alguém compra e desiste em série, **não** negar o direito; no máximo, depois de análise humana, avisar e limitar compras novas. Validar com advogado.
- **Depois dos 7 dias:** política própria mais generosa é opcional (ex.: compra por engano de criança, com o responsável pedindo). Recomendado analisar caso a caso com boa vontade.

### 7.2 Recibos e informações

Antes de pagar (Decreto 7.962 art. 2º e 4º):
- Nome/CNPJ ou CPF do fornecedor, endereço, e-mail de contato (em local visível: rodapé da loja e site).
- O que é o item (prévia animada, em quais personagens funciona, que é só visual e preso à conta).
- **Preço total à vista em R$** (Decreto 5.903 art. 3º), sem taxas escondidas.
- Resumo das condições (inclui "você pode desistir em 7 dias").
- Tela de revisão com botão "voltar" (correção de erros, art. 4º II).

Depois de pagar:
- Confirmação imediata na tela e **recibo por e-mail** (art. 4º III e IV) com número do pedido, item, valor, data, meio de pagamento e link para desistir.
- **Nota fiscal** conforme o regime da empresa (ver seção 9.4).
- Atendimento por e-mail/formulário com resposta em até **5 dias** (art. 4º parágrafo único).

### 7.3 Probabilidades

**Não se aplica:** não há nenhum elemento aleatório pago. Se algum dia um bônus aleatório gratuito existir num evento, as chances serão públicas mesmo assim.

### 7.4 Checklist anti-padrões obscuros (usar em cada tela da loja e do passe)

| ☐ | Verificação |
|---|---|
| ☐ | O preço em R$ aparece junto do item, no mesmo tamanho do nome? |
| ☐ | O botão "Comprar" não é o único destacado; "Voltar/Cancelar" tem o mesmo peso visual? |
| ☐ | Não há contagem regressiva, "últimas unidades", "X pessoas compraram agora"? |
| ☐ | Não há preço "de/por" que nunca foi praticado? |
| ☐ | Recusar não usa texto culpabilizante ("Não, prefiro ficar feio")? |
| ☐ | A loja só abre quando o jogador pede (sem pop-up ao logar, subir de nível ou morrer)? |
| ☐ | Nenhuma recompensa depende de tempo logado ou login diário? |
| ☐ | Cancelar/desistir tem no máximo o mesmo número de cliques que comprar? |
| ☐ | O painel do responsável está a 1 clique do menu de conta, e o jogo não sugere desativar salvaguardas? |
| ☐ | Nada de pré-seleção (itens extras ou "doação" já marcados no carrinho)? |
| ☐ | Tudo em português claro, legível por uma criança de 10 anos? |
| ☐ | O item comprado não dá nenhuma vantagem, nem visual? |
| ☐ | A classificação indicativa aparece na instalação, no login e no carregamento (Portaria MJSP 1.048/2025 art. 50)? |

---

## 8. Preços em R$ e conta de custos

### 8.1 Faixas de preço (proposta)

| Faixa | Preço | Exemplos |
|---|---|---|
| Pequeno | **R$ 4,90** | emote extra, balão de chat, moldura de nome |
| Médio | **R$ 9,90** | chapéu/adorno de cabeça, estilo de cabelo de temporada, tema de minimapa |
| Grande | **R$ 14,90** | roupa sobreposta completa |
| Conjunto temático | **R$ 19,90** | chapéu + roupa + emote do mesmo tema (mais barato que separado) |
| Passe de temporada (trilha paga) | **R$ 19,90** | ~12 semanas, não expira |
| Pacote de apoiador (opcional) | **R$ 29,90** | conjunto exclusivo "Apoiador do servidor" + moldura; comunicado com transparência: "ajuda a pagar o servidor" |

Referências: preços abaixo da faixa comum de grandes free-to-play no Brasil, de propósito. Sem preços terminados em sobra de moeda (não há moeda). **Preço regional** (outros países) fica para depois; usar a tabela de preços por país da loja/provedor quando houver venda fora do Brasil.

### 8.2 Custos mensais estimados (a confirmar com orçamentos reais)

| Item | Estimativa/mês | Observação |
|---|---|---|
| VPS São Paulo 2 vCPU / 4 GB / 40–80 GB SSD (§15.7) | R$ 100 a R$ 350 | varia muito entre provedores; cotar |
| Backup externo (§15.7) | R$ 10 a R$ 40 | armazenamento de objetos |
| Domínio + e-mail transacional | R$ 10 a R$ 50 | recibos e confirmações |
| Contador (se abrir CNPJ) | R$ 150 a R$ 500 | depende do regime |
| Taxas do meio de pagamento | variável | Pix costuma ser mais barato que cartão; cotar |
| Tributos sobre a venda | variável | ver 9.4 |
| Anuais rateados (certificado de assinatura de código Windows, conta Google Play única, etc.) | R$ 50 a R$ 200 | opcionais em parte |
| **Total fixo aproximado** | **R$ 500 a R$ 1.000** | meta de receita |

### 8.3 Conta de sanidade

- Ticket médio líquido estimado (depois de taxas e tributos): **~R$ 8 por compra**.
- Para cobrir R$ 750/mês: **~95 compras/mês**, ou ~40 passes + ~50 itens.
- Com 2% a 4% dos jogadores ativos comprando algo no mês, isso pede **~2.500 a 5.000 jogadores ativos mensais**. Abaixo disso, o autor continua bancando o servidor (como hoje); acima, o excedente vira **reserva** para meses fracos e melhorias do servidor, coerente com "divertir, não lucrar".
- **Recomendação:** publicar no Discord um "placar do servidor" simples (custo do mês × arrecadado), sem nomes nem valores individuais. Transparência reforça que ninguém está sendo explorado.

*(Números são estimativas de ordem de grandeza, não previsão.)*

---

## 9. Plano de implementação

### 9.1 Quando

| Fase | Quando | O que entra |
|---|---|---|
| **0 — Preparação** | **Durante o MVP** (já previsto em §14.3) | Camada de aparência sobreposta por espaço (§17.4); campo `appearance.overlay` no JSON; campo de data de nascimento / `age_band` na conta; nenhum pagamento |
| **1 — Loja PC** | Só **depois** do playtest do MVP atingir os critérios de §3.3 e de o dono decidir seguir | Loja de cosméticos, Pix, recibos, arrependimento, painel do responsável, classificação indicativa exibida |
| **2 — Passe** | Quando existirem temporadas (§3.2) | Trilha gratuita + paga, pontos por atividades, arquivo de passes |
| **3 — Android** | Com a versão Android | Google Play Billing, sinal de idade da loja, classificação IARC |

### 9.2 Sistemas necessários

| Sistema | Onde | Função |
|---|---|---|
| **Catálogo** | dados (`data/cosmetics/*.tres` + tabela `products`) | id, nome, camada, preço em R$, tema, se é comprável/conquistável |
| **Serviço de direitos (entitlements)** | extensão da `accounts-api` (§15.6) | tabelas `orders`, `order_items`, `entitlements`, `refunds`; o jogo só consulta "a conta X tem o cosmético Y?" |
| **Webhook de pagamento** | `accounts-api` | recebe confirmação do provedor, com assinatura verificada e **idempotência** (mesmo evento 2× não duplica) |
| **Validação no servidor de jogo** | `game-server` | recusa overlay sem direito; nunca confia no cliente |
| **Loja (UI)** | cliente Godot + página web espelho | vitrine igual para todos, prévia no boneco, carrinho, revisão, recibo |
| **Histórico e desistência** | cliente + site | lista de compras, botão "Desistir" por 7 dias |
| **Painel do responsável** | site (web) | vínculo, limites, bloqueios, histórico, tempo de jogo |
| **Passe** | `game-server` + dados | pontos por eventos de gameplay, trilhas, fragmentos determinísticos |
| **Registro/auditoria** | logs JSON (§15.7) | quem comprou, quem desistiu, mudanças de controle parental; sem dados além do necessário |

Nada disso fica no mesmo processo do jogo: se o provedor de pagamento cair, o jogo continua funcionando.

### 9.3 Meios de pagamento

| Plataforma | Opções | Notas |
|---|---|---|
| **PC (distribuição própria)** | Intermediador de pagamento brasileiro ou internacional que aceite **Pix** e cartão (ex.: Mercado Pago, PagBank, Stripe, Asaas, Efí — **cotar taxas atuais**) | Começar **só com Pix** (mais barato, estorno simples via devolução Pix). Usar checkout do provedor: o jogo **nunca** toca em dados de cartão |
| **PC via Steam** (se o dono decidir publicar lá) | Sistema de pagamento da própria Steam | Verificar regras e taxa da Steam para microtransações antes de decidir |
| **Android** | **Google Play Billing** | Taxa da Google em transição em 2026: a Google anunciou redução e novo modelo, com datas para EUA/UK/EEE e "resto do mundo" depois; **valores para o Brasil ainda não divulgados** em março/2026. Hoje, o programa de 15% sobre o primeiro US$ 1 mi/ano é a referência. Confirmar no Play Console na época |

Pix Automático (recorrência) **não é necessário**: não teremos assinatura.

### 9.4 Impostos e nota fiscal (alto nível — **procurar contador**)

- Para vender com recibo e nota, o caminho natural é abrir **CNPJ**; o regime (MEI, Simples Nacional etc.) depende da atividade e do faturamento. A Lei 14.852/2024 (art. 7º §4º) prevê CNAE específico para desenvolvedoras de jogos; verificar com o contador se já existe e qual usar.
- Venda de conteúdo digital hoje tende a envolver ISS (serviço), e a **reforma tributária** está em transição: em 2026, CBS de 0,9% e IBS de 0,1% em fase de teste (LC 214/2025, art. 343 e 346), com mudanças até 2033. Isso afeta preço líquido e emissão de nota.
- Nas lojas (Google Play), verificar quem é o responsável pela emissão de documento fiscal ao consumidor.
- **Nada aqui é orientação tributária.** Contador antes da Fase 1.

### 9.5 Classificação indicativa

- Jogos só digitais podem se **autoclassificar pelo sistema IARC** ou meio autorizado pelo MJSP (Portaria MJSP 1.048/2025 art. 45). No Android, o IARC é feito no Play Console.
- Para o PC com distribuição própria, **confirmar com a ClassInd** o caminho (IARC em loja parceira, sistema próprio aprovado, ou requerimento).
- Os critérios agora incluem **interatividade**: chat entre usuários, **compras on-line**, e mecanismos como "recompensas variáveis", "gamificação", "promoções e ofertas limitadas" (Portaria art. 52, VI, IX e XIX; Decreto 12.880 art. 12 §2º). Nosso desenho (sem aleatoriedade paga, sem ofertas limitadas, sem streak) ajuda a manter a faixa etária baixa; **chat e compras vão aparecer como elementos interativos**.
- Exibir a classificação na página de instalação, no login e no carregamento (Portaria art. 50) e nos termos de uso (Decreto 12.880 art. 12 §4º).

---

## 10. Riscos e perguntas para o dono

### 10.1 Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Guia definitivo da ANPD sobre aferição de idade ainda não publicado; fiscalização mais intensa prevista para 2027 | Regras podem mudar o fluxo de idade/compras | Não lançar loja antes de revisar com advogado; manter idade isolada num módulo |
| Aplicação do art. 24 do ECA Digital (vínculo até 16 anos) a jogos é incerta | Retrabalho de contas | Já implementar vínculo com responsável |
| Receita não cobre o servidor | Autor continua pagando | Ok pelo objetivo do projeto; placar transparente; custos enxutos |
| Pressão futura para "monetizar mais" (moeda, loot box, venda de níveis) | Quebra dos pilares | Este documento + §14.1 `[FECHADO]` como trava |
| Fraude/estorno de cartão | Perda de receita | Começar com Pix; cartão só via checkout do provedor com antifraude |
| Arrependimento usado de má-fé | Pequena perda | Aceitar; tratar abuso só com análise humana |
| Cosmético visto como vantagem (camuflagem, poluição visual) | Quebra do "justo com todos" | Pergunta obrigatória no checklist (3.1) |
| Chat com menores sem salvaguarda (ECA art. 21) | Sanção e risco real a crianças | Resolver antes do playtest aberto, junto com §13 |
| Tributação mal enquadrada | Multas | Contador antes da Fase 1 |

### 10.2 Perguntas para o dono

1. **Pessoa física ou CNPJ?** Vender exige decidir quem é o fornecedor (nome no rodapé, recibos, notas).
2. **Menores podem comprar na v1?** Recomendação: **não**; só presentes do responsável. Depois, limites configuráveis.
3. **Idade mínima para jogar?** Aceitar menores de 12 exige consentimento parental na criação da conta (LGPD art. 14). Alternativa: 12+ na v1.
4. **Steam ou distribuição própria no PC?** Muda meio de pagamento, taxa e caminho da classificação indicativa.
5. **Pacote de apoiador** (R$ 29,90) faz sentido ou soa como "pedir dinheiro"?
6. **Estilos de cabelo pagos:** aceita a regra "só estilos de temporada, com um equivalente gratuito"?
7. **Cosméticos obtidos jogando** poderão ser trocados por moeda do jogo quando houver comércio (§14.2) — manter? (os comprados continuam presos à conta).
8. **Placar público do servidor** no Discord: ok?
9. **Duração da temporada** de ~12 semanas e passe que **nunca expira**: ok?
10. Cross-play PC + mobile está `[FECHADO]` no GDD §1; a ordem "PC primeiro, Android depois" deste plano está de acordo?

> **Requer validação jurídica por advogado** (direito do consumidor, proteção de dados/ECA Digital, direito digital) **e validação tributária por contador** antes de qualquer venda.

---

## 11. Fontes (acessadas em 27/09/2026)

| # | Fonte | Uso |
|---|---|---|
| 1 | [Lei 15.211/2025 — ECA Digital (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm) | art. 2º IV (definição de caixa de recompensa), 7º, 8º, 13, 17, 18, 20, 21, 22, 24, 26, 35, 39, 41-A (vigência 17/03/2026) |
| 2 | [Decreto 12.880, de 18/03/2026 — regulamenta o ECA Digital (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2026/decreto/D12880.htm) | art. 2º, 9º, 10, 12, 15, 18, 23, 24, 25, 27, 28, 31, 33 |
| 3 | [Lei 14.852/2024 — Marco Legal dos Jogos Eletrônicos (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/l14852.htm) | art. 3º §2º (microtransações na classificação), 5º parágrafo único, 7º §4º (CNAE), 16 (salvaguardas com chat), 17 (compras de crianças restritas por padrão) |
| 4 | [Lei 8.078/1990 — Código de Defesa do Consumidor (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/l8078compilado.htm) | art. 31, 37 §2º, 39 IV, 49 |
| 5 | [Decreto 7.962/2013 — comércio eletrônico (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2013/decreto/d7962.htm) | art. 2º, 4º, 5º (arrependimento pela mesma ferramenta, estorno) |
| 6 | [Decreto 5.903/2006 — informação de preços (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2004-2006/2006/decreto/d5903.htm) e [Lei 10.962/2004](https://www.planalto.gov.br/ccivil_03/_ato2004-2006/2004/lei/l10.962.htm) | preço claro, sem cálculo, total à vista; moeda estrangeira só com conversão em R$ |
| 7 | [Lei 13.709/2018 — LGPD (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm) | art. 14 (dados de crianças e adolescentes) |
| 8 | [ANPD — Enunciado CD/ANPD nº 1/2023 (notícia gov.br)](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes) | bases legais para dados de menores |
| 9 | [ANPD — "ECA Digital completa um ano..." (gov.br, publicado 16/09/2026, modificado 22/09/2026)](https://www.gov.br/anpd/pt-br/assuntos/noticias/eca-digital-completa-um-ano-e-e-marco-na-protecao-de-criancas-e-adolescentes-na-internet) | guia definitivo de aferição de idade ainda por publicar; fiscalização mais intensa no início de 2027; consulta pública do regulamento de fiscalização até 26/10 |
| 10 | [ANPD — página ECA Digital](https://www.gov.br/anpd/pt-br/assuntos/eca-digital) e [notícia do cronograma de aferição de idade](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-publica-orientacoes-preliminares-e-cronograma-para-afericao-de-idade-no-ambiente-digital) | cronograma (páginas instáveis no acesso de 27/09/2026; conteúdo confirmado pela fonte 9 e por [resumo da HDPO](https://hdpo.com.br/eca-digital-etapa-ii-fiscalizacao-anpd-agosto-2026/): adaptação ago–nov/2026, fiscalização jan/2027) |
| 11 | [Portaria MJSP 1.048/2025 — classificação indicativa (PDF)](https://igamingbrazil.com/wp-content/uploads/2025/10/PORTARIA-MJSP-No-1.048-DE-15-DE-OUTUBRO-DE-2025-PORTARIA-MJSP-No-1.pdf); registro oficial no [DSpace MJ](https://dspace.mj.gov.br/handle/1/15993) | art. 45 (IARC/autoclassificação), 50 (exibir faixa etária no login/carregamento), 52 (interatividade: compras on-line, chat, recompensas variáveis, ofertas limitadas) |
| 12 | [MJSP — Jogos e Apps (ClassInd)](https://www.gov.br/mj/pt-br/assuntos/seus-direitos/classificacao-1/paginas-classificacao-indicativa/jogos-e-apps) e [TJDFT sobre a Portaria 1.048/2025](https://www.tjdft.jus.br/institucional/imprensa/noticias/2025/novembro/jogos-eletronicos-aplicativos-shows-nova-portaria-de-classificacao-indicativa-reforca-protecao-a-criancas-e-adolescentes) | vigência (17/11/2025; arts. 48–57 em 17/03/2026) |
| 13 | [Lei Complementar 214/2025 — IBS/CBS (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm) | alíquotas de teste de 2026 (art. 343 e 346) |
| 14 | [Câmara — tramitação ligada ao PL 3.514/2015](https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2052488) | atualização do CDC para comércio eletrônico ainda não aprovada |
| 15 | [Google Play Console — taxas de serviço](https://support.google.com/googleplay/android-developer/answer/112622?hl=pt-BR) e [Mobile Time, 04/03/2026](https://www.mobiletime.com.br/noticias/04/03/2026/google-play-fim-monopoli/) | taxas em transição; Brasil ainda sem valores divulgados |
| 16 | [Senado — ECA Digital proíbe caixa de recompensa em games (27/03/2026)](https://www12.senado.leg.br/radio/1/noticia/2026/03/27/eca-digital-proibe-rolagem-infinita-e-caixa-de-recompensa-em-games-infantojuvenis) | contexto |

**Não encontrado na pesquisa:** decisão do STJ ou norma da Senacon específica sobre compras dentro de jogos eletrônicos (as ações da Senacon localizadas tratam de apostas). Pedir ao advogado uma checagem de jurisprudência recente sobre arrependimento em itens digitais e compras de menores.
