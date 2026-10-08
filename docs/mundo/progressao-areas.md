# Regiões de caça com vários mapas

A Terra de Pindorama tem dez mapas de caça carregados separadamente, ligados por portais de ida e volta. Cada lugar do atlas agrupa seus setores por `WorldPlaceDef.map_ids`; os nomes dos setores aparecem no HUD e no minimapa.

| Lugar | Setores, na ordem da travessia | Níveis | Chefes |
|---|---|---|---|
| Campos de Pindorama | Estrada dos Viajantes → Veredas do Buriti → Passo dos Ipês | 1–10 | Não; estágio máximo 1 |
| Mata Encantada | Entrada da Mata → Clareira dos Vaga-lumes → Bosque das Raízes → Coração da Mata | 6–12 | Não; estágio máximo 2 |
| Chapada do Céu Partido | Subida Vermelha → Cristas do Vento → Alto das Brasas | 12–25 | Sim: chefes fixos nos covis; formas atrozes à noite |

A rota começa no portão norte do Porto do Despertar. O último setor dos Campos leva à entrada da Mata; o Coração da Mata leva à Subida Vermelha. Na volta, o jogador aparece no marcador norte do setor anterior. Os níveis são recomendações, não bloqueios. Cada setor continua usando as regras existentes de instância de caça.

## Trilhas e cenário

A faixa retangular foi substituída por uma malha curva com largura variável, textura de terra e bordas transparentes irregulares. Os dez percursos têm curvas próprias. O minimapa usa as mesmas amostras da curva e mostra as ilhas de vegetação/pedra excluídas da navegação. Árvores, rochas, samambaias e capim reutilizam assets locais. O chão clicável permanece contínuo e a navegação autoritativa permite sair da trilha para caçar.

Os cenários ainda usam terreno plano; relevo e composição artística mais detalhada podem ser trabalhados posteriormente. Porto, treino e regiões culturais ainda planejadas não foram subdivididos neste incremento.

## Monstros novos ativos

Foram instalados os sprites nativos de **Queixada de Buriti**, **Serpente-Fagulha** e **Mula de Brasa**: cinco animações, cinco direções, formas normal, chefe e atroz. Os arquivos Blender editáveis foram preservados com `--no-blend`.

Cada espécie tem dados próprios, atributos, recompensas, drops de itens existentes e comportamento de combate. O estágio 2 é veterano: usa a arte normal com escala de 1,15; não existia um modelo médio na coleção preparada. As variantes `highland_*` elevam a dificuldade dos encontros comuns na Chapada. As formas atrozes têm alcance de perseguição maior, golpes mais rápidos e recompensas superiores às dos chefes, além do multiplicador noturno existente.

As espécies anteriores continuam disponíveis para manter as quests realizáveis.

## Chefes fixos

Decisão do dono (30/09/2026): não há evolução nem chefe por contagem de abates. Cada chefe mora num covil fixo
(`BossLairs/` da cena) com um bando de 4 normais e 2 médios da espécie, e renasce 10 min depois de derrotado.

| Setor | Covis |
|---|---|
| Subida Vermelha | Tatu-Montanha (leste), Rainha-Lume do Brejo (centro), Ventania do Gorro Vermelho (oeste); os três chefes de Pindorama pedidos pelos anciãos |
| Cristas do Vento | Queixada de Buriti |
| Alto das Brasas | Serpente-Fagulha (leste), Mula de Brasa (oeste) |

Campos (estágio 1) e Mata (estágio 2) não têm chefe. Os pontos comuns de monstros nunca pedem chefe: o gerador
`game/tools/world/build_hunt_areas.py` põe os chefes só nos covis.

## Reprodução

Na raiz do projeto:

```bash
# Reexportar arte, somente se os modelos mudarem:
bash game/tools/world/export_pindorama_monsters.sh
# Regerar cenas, zonas, minimapas, nomes e dados das espécies:
python3 game/tools/world/build_hunt_areas.py
# O gerador do atlas também preserva o agrupamento dos setores:
python3 docs/mundo/gerar_dados_atlas.py
make import
```

Validações:

```bash
.tools/godot-4.7.2 --headless --path game res://tests/world/test_hunt_areas.tscn
.tools/godot-4.7.2 --headless --path game res://tests/beta/test_content_links.tscn
.tools/godot-4.7.2 --headless --path game res://tests/monsters/test_night.tscn
QUICK_ROUTE=1 bash game/tests/world/run_hunt_route.sh
```

`QUICK_ROUTE=1` usa o teleporte de desenvolvimento para aproximar o cliente dos portais, mas executa as transferências reais e verifica chegada, população replicada e retorno. Sem a variável, o cliente anda até os portais. A acessibilidade pela navegação é verificada separadamente em `test_hunt_areas`. `--shots` nesse teste, com renderização habilitada, grava vistas gerais em `/tmp/hunt_<map_id>.png`.
