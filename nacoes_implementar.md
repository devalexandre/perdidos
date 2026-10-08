# Nações de Perdidos

Este documento acompanha as nações previstas no atlas, as referências culturais usadas pelo projeto e o estado real da implementação. Uma nação só deve ser marcada como **implementada** quando possuir rota jogável, mapas conectados, conteúdo e validação; aparecer no atlas não significa que já esteja pronta.

## Situação atual

| Nação | Países e referências principais | Estado | O que existe hoje |
|---|---|---|---|
| Terra de Pindorama | Brasil | **Implementada / jogável** | Porto do Despertar, Campo de Treino, Campos de Pindorama, Mata Encantada, Chapada do Céu Partido, cavernas e outras rotas brasileiras. Ainda pode receber polimento e conteúdo. |
| Reino das Mouras | Portugal | **Planejada** | Região, lugares e progressão definidos no atlas; evento e cosméticos preparados no painel, porém inativos. Não há rota regional completa jogável. |
| Ilhas do Sol Nascente | Japão | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. |
| Fiordes de Gelo | Noruega e Islândia | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. |
| Costa das Colunas | Grécia, com inspiração na Grécia Antiga | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. |
| Areias do Nilo | Egito, com inspiração no Egito Antigo | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. |
| Brumas Verdes | Irlanda e Escócia | **Protótipo técnico** | Há mapas experimentais de pântano e charneca, além da região no atlas. Falta consolidar rota, conteúdo, conexão e validação antes de liberar. |
| Estepe de Ferro | Povos eslavos da Europa Central e Oriental, com referências de Polônia, Ucrânia e Rússia | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. O recorte cultural deve ser revisto antes da produção final. |
| Império de Jade | China | **Planejada** | Região e lugares definidos no atlas; evento e cosméticos preparados no painel, porém inativos. |
| Selvas de Obsidiana | México e culturas mesoamericanas históricas | **Protótipo técnico** | Há mapas experimentais de selvas, ruínas, Ratanabá e Cidade de Z. A rota oficial, o conteúdo e a representação cultural ainda precisam ser consolidados e validados. |

## Critérios para habilitar uma nação

1. Definir a pesquisa cultural, o período histórico e os limites da inspiração, evitando misturar povos distintos como se fossem uma única cultura.
2. Concluir uma cidade-base, rotas externas, masmorras, conexões e pontos no mapa global.
3. Implementar missões, criaturas, NPCs, itens, equipamentos e progressão adequados à faixa de nível.
4. Produzir e testar os cosméticos e as mudanças visuais dos eventos. Os registros no painel são um catálogo de preparação e não substituem os recursos visuais no jogo.
5. Validar servidor, cliente, minimapa, mapa global, navegação, desempenho mobile e localização.
6. Só então habilitar os eventos e cosméticos daquela nação no painel administrativo.

## Eventos preparados no painel

Todos os novos modelos entram **inativos**. O catálogo inclui celebrações brasileiras — Festa Junina, Folclore, Florada dos Ipês, Carnaval das Águas, Semana dos Caminhos Livres, Dia das Brincadeiras, Natal e Virada das Estrelas — e um evento inicial para cada uma das demais nações. Cada registro informa região, países de referência, período, bônus, cosméticos e a mudança visual planejada.

Ao ativar um evento, confirme antes que seus cenários e cosméticos já possuem recursos no cliente. Os multiplicadores de XP e drop já são lidos pelo servidor; decoração e cosmético dependem de seus recursos e pontos de aplicação existirem no jogo.

## Monstros planejados por nação

A lista de monstros, espécies regionais e chefes de arco de cada nação está em `docs/mundo/monstros-por-nacao.md`. Decisão do dono (07/10/2026): nenhuma nação nova entra em produção antes do Arco 1 da Terra de Pindorama terminar.
