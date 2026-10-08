# Novos monstros regionais — 30 espécies / 90 modelos

Três espécies novas por área cultural, cada uma com Normal, Boss e Atroz. Os arquivos Blender ficam **junto dos modelos nativos**, em `game/tools/art/blender/monsters/blend/`. As três espécies da Terra do Sabiá estão ativas nos dez mapas de caça, com sprites normal/chefe/atroz, dados e drops. As três das Ilhas do Sol Nascente (`pond_kappa`, `mountain_tengu`, `paper_lantern`) foram refeitas no padrão do Tatu-Pedra (módulos `<id>.py` + `sol_common.py`, folhas aprovadas pelo dono em 07/10) e integradas **só como dados**: sprites s1/s3/s4 em `game/assets/monsters/<id>/`, `game/data/monsters/<id>.tres` (região `japao`, estágios 1–4, s2 veterano reaproveita a arte s1 com escala 1,15), nomes em `localization/content.csv` e entrada no bestiário do site. **Não nascem em nenhum mapa** até a nação abrir. As outras 24 permanecem preparadas para integração futura.

[Abrir galeria visual](../game/tools/art/blender/monsters/reserve/index.html) · [Instruções, animações e procedência](../game/tools/art/blender/monsters/reserve/README.md)

| Área | Normal | Boss | Atroz |
|---|---|---|---|
| Terra do Sabiá | Mula de Brasa | Mula da Queimada | Mula da Noite Ardente |
| Terra do Sabiá | Queixada de Buriti | Queixada do Veredão | Queixada das Raízes Negras |
| Terra do Sabiá | Serpente-Fagulha | Serpente do Fogo Errante | Serpente da Cinza Viva |
| Reino das Mouras | Draguinha da Charneca | Dragoa das Ruínas | Dragoa do Breu |
| Reino das Mouras | Pedregulho da Maré | Colosso do Cabo | Colosso da Maré Negra |
| Reino das Mouras | Fuso Saltitante | Roca do Tesouro | Roca dos Fios Sombrios |
| Ilhas do Sol Nascente | Kappa da Lagoa | Kappa do Remanso | Kappa do Poço Escuro |
| Ilhas do Sol Nascente | Corvo da Montanha | Tengu do Vendaval | Tengu da Asa Noturna |
| Ilhas do Sol Nascente | Lanterna Travessa | Lanterna do Desfile | Lanterna da Chama Violeta |
| Fiordes de Gelo | Lobo da Geada | Lobo da Aurora | Lobo da Aurora Sombria |
| Fiordes de Gelo | Caranguejo do Fiorde | Couraça do Iceberg | Couraça do Abismo Frio |
| Fiordes de Gelo | Armadura à Deriva | Vigia do Naufrágio | Vigia do Mar Morto |
| Costa das Colunas | Touro de Bronze | Touro do Labirinto | Touro da Forja Negra |
| Costa das Colunas | Hidrinha do Charco | Hidra dos Juncos | Hidra do Pântano Negro |
| Costa das Colunas | Harpia do Penhasco | Harpia das Colunas | Harpia da Tempestade |
| Areias do Nilo | Escaravelho de Vidro | Escaravelho das Dunas | Escaravelho do Eclipse |
| Areias do Nilo | Naja de Areia | Naja da Duna Rubra | Naja da Noite de Vidro |
| Areias do Nilo | Crocodilo dos Juncos | Crocodilo do Banco de Areia | Crocodilo do Lodo Negro |
| Brumas Verdes | Cão da Bruma | Cão do Urzal | Cão da Névoa Negra |
| Brumas Verdes | Luz do Brejo | Candeeiro da Turfeira | Lume da Turfa Negra |
| Brumas Verdes | Gato do Urzal | Gato da Pedra Antiga | Gato da Lua Velada |
| Estepe de Ferro | Ave-Fagulha | Ave da Pluma Ardente | Ave da Brasa Azul |
| Estepe de Ferro | Pilão Saltador | Pilão da Floresta | Pilão do Bosque Sombrio |
| Estepe de Ferro | Aranha de Bétula | Tecelã do Bosque Branco | Tecelã da Geada Negra |
| Império de Jade | Nian das Colinas | Nian do Vale Rubro | Nian da Noite Ruidosa |
| Império de Jade | Louva-a-deus de Jade | Foice do Bambuzal | Foice da Jade Negra |
| Império de Jade | Carpa de Tinta | Carpa da Cascata | Carpa do Rio Noturno |
| Selvas de Obsidiana | Cão do Cenote | Fera da Cauda-Mão | Fera do Cenote Negro |
| Selvas de Obsidiana | Axolote de Turquesa | Axolote da Gruta | Axolote da Fenda Negra |
| Selvas de Obsidiana | Morcego do Cacau | Asa da Caverna | Asa da Obsidiana Viva |

## Entrega e validação

- 90 modelos `.blend` editáveis, com cinco animações gravadas em cada um.
- 90 prévias e dez pranchas comparativas por área.
- Módulos compatíveis com o pipeline nativo, nos estágios 1, 3 e 4.
- Verificação dos modelos salvos registrada em `reserve/validation.json`.
- Teste de exportação completa: Kappa Atroz, cinco animações × cinco direções, sem cortes nos quadros. Saída de teste em `.work/regional-reserve-check`, sem instalação.

As prévias da galeria são renders de modelagem 3D. As espécies do Sabiá já têm sprites pixel art e integração de dados, drops e spawns; as do Sol Nascente têm sprites e dados, sem spawn; as demais aguardam uso. Consulte [progressão por áreas](mundo/progressao-areas.md).
