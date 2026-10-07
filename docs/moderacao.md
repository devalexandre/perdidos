# Moderação do chat — censura de palavrões e sanção progressiva

> Implementa o GDD §13 (Social: censura e sanção progressiva) com os cuidados da §14.2.
> Status: **[PROVISÓRIO — requer validação jurídica]** nos pontos marcados abaixo.
> Dono: Agente S (chat e moderação). Última revisão: 27/09/2026.

## 1. Resumo

1. Toda mensagem de chat passa pelo **filtro** no servidor. Palavrões e ofensas, em **qualquer
   idioma** e em **qualquer forma de burla**, viram `***` e a mensagem **segue** para os outros.
2. Quem **insiste** recebe **strikes**. Cada strike sobe um degrau da escada:
   **aviso → 1 h → 6 h → 24 h → 7 dias → 30 dias → perda do personagem.**
3. Os **dois últimos degraus** (30 dias e perda do personagem) **não valem sozinhos**: abrem um
   caso para **revisão humana**. Até a decisão, o chat do jogador fica bloqueado. **Nada é apagado
   automaticamente.**
4. O histórico **diminui com bom comportamento** (1 degrau a cada 30 dias limpos).
5. Tudo fica num **log de moderação** (quem, o quê, quando), guardando só o **hash** da mensagem
   original e o texto **já filtrado**.

## 2. Onde está cada coisa

| O quê | Arquivo |
|---|---|
| Filtro (normalização + busca) | `game/scripts/server/moderation/profanity_filter.gd`, `text_normalizer.gd` |
| Listas de termos (dados) | `game/data/chat/profanity/<idioma>.txt`, `slurs.txt`, `whitelist.txt` |
| Sanções (regras) | `game/scripts/server/moderation/moderation_service.gd` |
| Números da escada (sem código) | `game/data/chat/sanctions.tres` (`SanctionConfig`) |
| Estado por conta e log | `user://moderation/records/<conta>.json`, `user://moderation/log.jsonl` |
| Ligação com o chat | `game/scripts/server/chat_service.gd` |
| Aviso no cliente (contador) | `game/scripts/client/ui/chat_box.gd` |
| Textos (pt-BR) | `game/localization/moderation.csv` |
| Ferramenta de revisão | `game/tools/moderation_review.py` |
| Testes | `game/tests/moderation/` (`run_moderation_autotest.sh`) |

`user://` no Linux é `~/.local/share/godot/app_userdata/Projeto Isekai/`.

## 3. Como o filtro funciona

O servidor monta um "esqueleto" do texto e procura os termos nele; o trecho encontrado é trocado
por `***` no texto **original**.

**Normalização** (`TextNormalizer`):
- minúsculas; acentos e diacríticos removidos (`cáráƚho` → `caralho`); `ß` → `ss`, `æ` → `ae`...;
- letras de outros alfabetos parecidas com as latinas (cirílico `р`, `а`, `о`; grego `υ`, `ο`...);
- formas de compatibilidade (equivalente prático da NFKC): largura cheia (`ｆｕｃｋ`), letras
  matemáticas (`𝐟𝐮𝐜𝐤`, `𝓯𝓾𝓬𝓴`), circuladas/quadradas (`ⓕⓤⓒⓚ`, `🅵🆄🅲🅺`), sobrescritos, ligaduras;
- caracteres invisíveis removidos (largura zero, hífen suave, seletores de variação...);
- katakana → hiragana, meia largura → largura normal (`ﾊﾞｶ` → `ばか`);
- letras soltas separadas por espaço (3 ou mais) viram uma palavra (`p o r r a` → `porra`).

**Busca** (`ProfanityFilter`): cada termo vira uma expressão que aceita
- **leet**: `0→o`, `1→i/l`, `3→e`, `4/@/^→a`, `5/$→s`, `7/+→t`, `8→b`, `6/9→g`, `2→z`, `ph→f`, `v→u`, `k/q↔c`;
- **letras repetidas** (`fuuuuck`, `porrrraaa`);
- **separadores** entre as letras (`f.u.c.k`, `p-o-r-r-a`, `p_o_r_r_a`, `F*U*C*K`);
- **abreviações** conhecidas (`pqp`, `vsf`, `fdp`, `krl`, `tnc`, `vtnc`, `wtf`, `stfu`, `hdp`...),
  que estão nas próprias listas.

**Problema de Scunthorpe** (falso positivo quando um termo aparece dentro de uma palavra
legítima) é tratado de três formas:
1. por padrão um termo só casa no **começo de palavra** (`computador` e `disputa` não casam `puta`);
2. termos curtos/ambíguos casam só como **palavra inteira** (`=cu` não pega `cuidado`, `escuro`);
3. a **whitelist** cobre o resto (`scunthorpe`, `cocktail`, `shiitake`, `ばかり`...).

O filtro é o mesmo para **nomes** (`ProfanityFilter.check_name`, mais rígido: termos com 4+
letras valem dentro do nome, ex. `XxPorraxX`). Hoje o nome suspeito só vai para o log
(`name_flagged`) para revisão; bloquear na criação é uma ligação de 1 linha em `Net._srv_hello`
quando a tela de criação de personagem tiver o fluxo de recusa. Nomes de guilda usam a mesma função.

Desempenho: ~0,6 ms por mensagem de 200 caracteres (medido no teste).

## 4. Listas de termos — formato e como estender

Uma entrada por linha em `game/data/chat/profanity/<idioma>.txt`:

```
<severidade> <modo><termo>
```

| Severidade | Significado | Efeito |
|---|---|---|
| 1 | leve (`idiota`, `wtf`, `baka`) | só censura, não conta para sanção |
| 2 | palavrão | censura + conta na janela |
| 3 | ofensa de ódio (racismo, homofobia, intolerância religiosa, assédio) | censura + **strike imediato** |

| Modo (prefixo) | Casa | Exemplo |
|---|---|---|
| (nada) | começo de palavra (pega plurais e derivados) | `2 porra` pega `porras` |
| `=` | só a palavra inteira | `2 =fdp`, `1 =cu` |
| `*` | em qualquer lugar, até dentro de outra palavra | `2 *caralho` pega `docaralho` |

- Termos com espaço (`filho da puta`) aceitam qualquer separador entre as palavras, inclusive
  nenhum (`filhodaputa`).
- **Escreva só a forma base**: acento, maiúscula, leet, repetição e separadores já são cobertos.
- `slurs.txt` é **sempre severidade 3**, em todos os idiomas. Cuidado redobrado com falsos
  positivos ali: eles punem na hora.
- Japonês (e outras línguas sem espaço): use `*` e ponha palavras legítimas que contêm o termo na
  whitelist (ex.: `ばか` × `ばかり`). Escreva kana em hiragana.
- Comentários: linhas com `#` (ou ` #` no fim da linha).

**Adicionar um idioma:** criar `game/data/chat/profanity/<código>.txt` (ex.: `pl.txt`) — é lido
automaticamente, sem código. Depois:
1. rodar o autoteste de moderação (abaixo) e acrescentar em `tests/moderation/test_moderation.gd`
   exemplos do idioma em `MUST_FILTER` (com burlas) e palavras comuns em `MUST_PASS`;
2. conferir colisões com os outros idiomas (as listas valem para todas as mensagens: `con` é
   palavrão em francês e "com" em espanhol, por isso não está na lista);
3. pedir revisão de um falante nativo (mesmo processo da revisão cultural, GDD §4.0 regra 3).

Idiomas atuais: pt-BR (completo, com gírias regionais e siglas), en, es, fr, de, it, ja (romaji +
kana/kanji) e ofensas de ódio multilíngues.

## 5. Sanção progressiva

Regras (valores em `game/data/chat/sanctions.tres`, todos [PROVISÓRIO]):

| Parâmetro | Padrão | O quê |
|---|---|---|
| `window_sec` | 600 (10 min) | janela móvel de contagem |
| `filtered_msgs_per_strike` | 3 | mensagens censuradas (sev. ≥ 2) na janela = 1 strike |
| `count_min_severity` | 2 | severidade mínima que conta |
| `immediate_strike_severity` | 3 | ofensa de ódio = strike imediato |
| `ladder_mute_sec` | 0, 1 h, 6 h, 24 h, 7 d, 30 d, -1 | degraus (0 = aviso, -1 = perda do personagem) |
| `review_from_level` | 6 | a partir deste degrau, só com revisão humana |
| `decay_clean_sec` | 30 dias | tempo limpo para descer 1 degrau |
| `log_retention_days` | 365 | guarda do log (usado pelo `purge`) |

A escada:

| Strike | Efeito | Revisão? |
|---|---|---|
| 1 | aviso | não |
| 2 | chat bloqueado 1 h | não |
| 3 | 6 h | não |
| 4 | 24 h | não |
| 5 | 7 dias | não |
| 6 | 30 dias | **sim** — bloqueado até a decisão |
| 7 | perda do personagem | **sim** — bloqueado até a decisão |

- O strike é por **conta** (hoje a conta é o nome do personagem; quando existir login de conta, a
  chave passa a ser o id da conta — `ChatService.account_id`). O registro fica fora do save do
  personagem, então sobrevive à perda do personagem.
- **Bloqueado não fala**: o servidor recusa a mensagem e responde `SYS_MOD_MUTED` com o tempo
  restante. Ao entrar no jogo com bloqueio ativo, o aviso chega na hora. O cliente mostra uma
  faixa acima do chat com contagem regressiva e não envia enquanto durar.
- **Decaimento**: conta a partir do **fim** do último bloqueio (ou do último strike); cada 30 dias
  limpos = −1 degrau. Casos em revisão não decaem.
- **Perda do personagem aprovada** = o personagem é **bloqueado** (desconectado ao entrar, com
  `SYS_MOD_CHARACTER_LOST`). O save **não é apagado** pelo jogo: a exclusão definitiva, se houver,
  é um procedimento manual fora do servidor, depois do prazo de apelação.

## 6. Revisão humana e apelação

Ferramenta: `python3 game/tools/moderation_review.py` (roda com o servidor ligado; o servidor relê
o registro alterado).

```
moderation_review.py list                                   # casos pendentes
moderation_review.py show <conta>                           # estado + últimas ações (texto filtrado)
moderation_review.py approve <case_id> --reviewer <nome> --note "motivo"
moderation_review.py reject  <case_id> --reviewer <nome> --note "falso positivo: ..."
moderation_review.py pardon  <conta>   --reviewer <nome> --note "apelação aceita"
moderation_review.py purge [--days 365]                     # apaga log vencido
```

**Processo de revisão (recomendado):**
1. `list` mostra o caso (degrau, sanção proposta, motivo).
2. `show <conta>` mostra as mensagens que geraram os strikes **já filtradas** e os **termos**
   encontrados (ex.: `pt_BR:porra`). O revisor julga pelo contexto e pelos termos se foi insistência
   real ou falso positivo.
3. `approve` aplica a sanção a partir da decisão; `reject` desfaz o strike (volta 1 degrau e libera
   o chat). Sempre com `--reviewer` e `--note` (ficam no log).
4. Se possível, dois revisores para "perda do personagem" (recomendação).

**Apelação:** o jogador contesta pelo suporte (canal a definir). Para provar qual foi a mensagem,
o log guarda o **hash com sal** do original (`msg_hash`): se o jogador apresentar o texto, o
servidor consegue confirmar se é o mesmo sem ter guardado o texto. Apelação aceita → `pardon`
(−1 degrau, libera o chat e desfaz a perda do personagem). Prazo sugerido de resposta: 15 dias.

## 7. Falsos positivos

- Relato de palavra legítima censurada → acrescentar em `whitelist.txt` (ou mudar o termo para
  `=` palavra inteira) + um caso em `MUST_PASS` no teste.
- Severidade 1 nunca pune; só 2 e 3 contam. Termos ambíguos ficam em 1 (ex.: `=cu` também é
  "see you" em inglês; `=ass` é abreviação de "assinado").
- Os degraus graves passam por um humano; `reject` e `pardon` desfazem strikes indevidos.
- Censura não é perfeita: burlas novas aparecem. Monitorar `show`/log e atualizar as listas.

## 8. Log de moderação (o que é guardado)

Uma linha JSON por ação em `user://moderation/log.jsonl`:
`ts`, `time` (UTC), `action` (`filtered`, `strike`, `pending_review`, `chat_blocked`, `decay`,
`review_approved`, `review_rejected`, `appeal_pardoned`, `name_flagged`), `actor` (`system` ou o
revisor), `account`, `character`, `level`, `mute_until`, e quando aplicável `msg_hash`,
`filtered_text`, `terms`, `severity`, `reason`, `case_id`, `note`.

**Não** guardamos o texto original da mensagem, IP, nem dados de outros jogadores. O log do
servidor (stdout) também só registra o texto filtrado.

## 9. Notas legais `[PROVISÓRIO — requer validação jurídica]`

Estas são recomendações técnicas; **precisam ser validadas por um advogado** antes do lançamento.

**LGPD (Lei 13.709/2018)**
- **Minimização**: só o necessário para a moderação — hash com sal do original, texto filtrado,
  termos, conta/personagem e horário. Sem texto original, sem IP no log de moderação.
- **Finalidade e base legal**: segurança da comunidade e cumprimento dos Termos de Uso (a definir
  com o jurídico: legítimo interesse e/ou execução de contrato). Informar na Política de
  Privacidade que o chat é filtrado e que sanções são registradas.
- **Retenção**: 365 dias por padrão (`log_retention_days`, `moderation_review.py purge`). Rodar o
  purge periodicamente (ex.: cron mensal).
- **Direitos do titular**: acesso e contestação (apelação, §6); decisões automatizadas graves
  (30 dias e perda do personagem) **têm revisão humana**, em linha com o art. 20.
- **Segurança**: `secret.key` (sal do hash) e o log ficam só no servidor, com acesso restrito à
  equipe de moderação. Na Fase 2 migrar para o banco com controle de acesso e trilha de auditoria.

**ECA e ECA Digital (Lei 15.211/2025) — proteção de crianças e adolescentes** (recomendações)
- Para contas de **menores** (quando houver verificação de idade/controle parental, GDD §14.2):
  - filtro **mais rígido por padrão** (severidade 1 também conta; `count_min_severity = 1`);
  - chat **restrito** por padrão (só grupo/amigos) e sussurro de desconhecidos desligado;
  - **nunca** esconder sanções dos responsáveis; canal de denúncia visível;
  - nada de conteúdo sexual: termos sexuais já são severidade 2 (considerar 3 para contas de
    menores);
  - aliciamento/assédio: além do filtro, prever **denúncia** por jogador e fila de revisão
    prioritária; incidentes graves podem exigir comunicação às autoridades (a validar).
- Sugestão técnica: um segundo `SanctionConfig` (ex.: `sanctions_minor.tres`) escolhido pela
  faixa etária da conta.

**Outros cuidados**
- Termos de Uso devem descrever a escada de sanções, a revisão humana e a apelação.
- As listas contêm termos ofensivos **apenas como dados de moderação**; não aparecem no jogo.
- Religiões vivas (GDD §4.0 regra 3): intolerância religiosa (ex.: `macumbeiro` como ofensa) está
  em `slurs.txt`.

## 10. Testes

```
GODOT=/caminho/godot game/tests/moderation/run_moderation_autotest.sh
```
- `test_moderation.tscn`: ~260 verificações — burlas em 7 idiomas (leet, `f.u.c.k`, `fvck`, `ƒuck`,
  `p0rr4`, `p o r r a`, `cáráƚho`, largura cheia, largura zero, cirílico, letras matemáticas),
  falsos positivos (whitelist, palavras do jogo), nomes, escada completa com **relógio falso**
  (janela, aviso, 1 h … 7 d, revisão de 30 d e da perda, rejeição, decaimento), persistência, log.
- Servidor real + cliente headless: 6 palavrões → aviso → bloqueio de 1 h → mensagem limpa
  recusada com tempo restante → faixa no ChatBox → reentrada com o mesmo nome continua bloqueada.
- O autoteste geral (`game/tools/run_autotest.sh`) continua passando (a mensagem com palavrão do
  shopper é censurada e só conta 1 na janela).
