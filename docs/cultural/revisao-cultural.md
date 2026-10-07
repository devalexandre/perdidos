# Revisão cultural de nomes e textos (todos os idiomas)

Aplica o GDD §4.0 (regras de inspiração cultural, em especial a regra 3) e o §0 regra 5 (nada de Ragnarok ou outros jogos).

## Regra

Nenhum título, skill, item, monstro, NPC, lugar ou fala usa **divindades, figuras sagradas, santos, profetas, orixás, espíritos cultuados ou termos litúrgicos de religiões praticadas hoje**, em **nenhum idioma** do jogo. O folclore de domínio público (Saci, Curupira, Boitatá, yokai, trolls…) pode ser usado, sempre com respeito e sem caricatura.

## Processo

1. **Ao criar conteúdo:** conferir o nome contra `game/data/cultural/sensitive_terms.txt` e rodar `make check-names`.
2. **Checagem automática:** `make check-names`, também incluída em `make test`.
   - Termo **proibido (!)** nas traduções ou nos dados do jogo → **erro**: o texto não pode ser publicado.
   - Termo **sensível (?)** → aviso: uma pessoa revisa o contexto. Pode ser uma palavra comum ou uma criatura mitológica antagonista (ex.: Fenrir, Apep, Balor, que o GDD usa como chefes).
   - **Ragnarok (~)** → aviso: não usar como título ou skill.
3. **Ao traduzir para um novo idioma:**
   - O tradutor recebe esta página e a lista de termos.
   - Cada nome é verificado **no idioma de destino**: significado, conotação religiosa, gíria ofensiva, marca registrada, nomes de outros jogos daquele mercado.
   - O nome pode ser **adaptado**, não só transliterado.
   - Os termos sensíveis daquele idioma entram na lista.
   - Cada linha revisada fica registrada na coluna de observações da planilha de tradução.
4. **Antes de cada lançamento:** revisão humana por idioma, feita de preferência por falantes nativos, e consulta às comunidades de origem quando o conteúdo usa cultura de povos específicos (ex.: organizações indígenas para termos de origem tupi).
5. **Arte:** a mesma regra vale para símbolos. Nada de iconografia religiosa real como elemento de poder, inimigo ou piada. Igrejas, templos e outros elementos de cenário, quando existirem, aparecem só como arquitetura respeitosa.

## Ampliar a lista

Cada linha de `sensitive_terms.txt` tem o formato `<nível> <termo>`:
- `!` = proibido;
- `?` = sensível;
- `~` = Ragnarok.

Linhas que começam com `re!`, `re?` ou `re~` são expressões regulares, aplicadas ao texto original. A comparação ignora acentos e maiúsculas e pega palavras inteiras.
