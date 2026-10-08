# Conferência de 03/10/2026

O direcional mobile passou de raio 80 para 100 e o manípulo de 29 para 36 (unidades na escala de UI). A margem inferior passou de 20 para 76, elevando o controle.

Portais agora verificam a posição autoritativa após o movimento, no servidor. Atravessar o ponto caminhável de entrada ativa o mesmo fluxo de transferência usado pelo clique, em qualquer plataforma. As restrições de título inicial, conexões permitidas e portões fechados continuam valendo. Uma entrada ocupada não repete a ação; nascer sobre uma entrada exige sair e voltar, evitando transferências em ciclo. Durante a carga do próximo mapa e enquanto morto, não há ativação automática.

## Conteúdo encontrado

- 39 definições de itens em `game/data/items`.
- Armas novas: Lâmina Longa de Pindorama, Arco de Buriti, Facão de Brasa, Varinha Vaga-lume, Sabre do Mito e Cajado Trama-Raiz. O mercado libera parte delas por graduação de Causos; o diálogo de Zé Ferreiro também tem concessões de armas.
- Luvas de Couro, Coroa de Musgo, Diadema de Ipê e anéis de Buriti e Cinza Viva cadastrados e vinculados ao mercado por graduação.
- Materiais raros `eternal_ember`, `pequi_root` e `ancient_shell_shard` têm vínculos com drops de monstros.
- Lâmina do Vendaval e Cajado da Alma Atroz estão ligados ao serviço de drops de chefes (chances base de 2% e 5%, respectivamente).
- Armadura de torso: apenas o Gibão de Couro (`leather_jerkin`, comum). Não há coleção nova de armaduras raras de torso. Alguns novos equipamentos reutilizam ícones e visuais existentes.
- Caverna: três mapas conectados, com pisos 2 e 3 herdando a cena do primeiro. O prólogo e as rotas resumidas do Lobisomem existem; o arco completo, cenários distintos e mecânicas de ritual/combate não letal continuam incompletos. A ficha regional foi corrigida para não afirmar que só existe um piso.

Validação de referências: `tests/beta/test_content_links.tscn` passou com 5.188 verificações, sem falhas; seis avisos incluem a arena PVP futura, NPCs com arte de reserva, posição de NPC ajustada e a arena de provações fora do atlas.

Teste de travessia real sem clique (inclui caverna e seus três pisos):

```sh
QUICK_ROUTE=1 WALK_PORTALS=1 bash game/tests/world/run_hunt_route.sh
```

O modo rápido aproxima o personagem do portal usando o comando de teste; a entrada final ocorre por uma requisição normal de movimento, sem `send_interact`.

Resultado: 26 travessias sem clique, incluindo descida e retorno pelos três pisos da caverna, sem falhas. Verificações adicionais cobriram repetição na mesma entrada, saída/reentrada, morte, carregamento e chegada sobre um portal. O direcional foi conferido em áreas de 800×450, 1280×720 e 1600×900. Builds Android, Linux e Windows recompilados. O servidor em execução precisa ser reiniciado para carregar o comportamento novo dos portais.
