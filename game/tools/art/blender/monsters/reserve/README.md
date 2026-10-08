# Expansão regional — modelos preparados

30 espécies novas, três em cada uma das dez áreas culturais. Cada espécie tem **Normal (s1), Boss (s3) e Atroz (s4)**: 90 arquivos `.blend`, ao lado dos modelos nativos em `../blend/`. O s2 é deliberadamente omitido: esta entrega prepara as três formas solicitadas.

Abra `index.html` para comparar as três formas e acessar cada modelo. As dez pranchas JPG servem para revisão por região. As imagens são **prévias 3D**, não sprites finais. A câmera das prévias se ajusta ao modelo para mostrar detalhes, portanto as imagens não comparam tamanho físico.

## Conteúdo dos modelos

- Geometria editável e hierarquia de pivôs para corpo, cabeça, cauda, membros e acessórios.
- Materiais extraídos das rampas da paleta do pipeline nativo.
- Cinco animações gravadas na timeline: `idle` 1–8, `walk` 13–20, `attack` 25–32, `hit` 37–40, `death` 45–52. Marcadores e propriedade de cena `animation_clips` identificam cada trecho. Loops usam os intervalos exatos indicados, sem incluir as lacunas.
- Boss ganha peças próprias por anatomia e ampliação dos detalhes da espécie; Atroz acrescenta lâminas dorsais, presas, olhos luminosos e partículas animadas, além da paleta noturna.
- O rig é feito de objetos e pivôs, como os monstros procedurais nativos; não depende de armature externa ou de texturas baixadas.
- Cada módulo `../<id>.py` expõe `build`, `pose`, `FRAME`, `STAGES` e `ANIMS` para o renderizador existente. O modelo salvo usa materiais visuais; o pipeline reconstrói os materiais de passes a partir do módulo.

## Integração atual e uso futuro

As três espécies de Pindorama (`buriti_boar`, `cinder_serpent`, `ember_mule`) foram autorizadas para uso e integradas: sprites s1/s3/s4, dados de combate, drops, spawns e variantes da Chapada. O estágio médio reutiliza a arte normal. As três das Ilhas do Sol Nascente (`pond_kappa`, `mountain_tengu`, `paper_lantern`) foram refeitas no padrão do Tatu-Pedra (módulos reescritos + `../sol_common.py`; revisão em `.work/sol-pilot/`) e integradas como dados: folhas s1/s3/s4 instaladas por `post.py` a partir de `.work/sol-pilot/npz`, MonsterDef com estágios 1–4 na região `japao` e nomes em `localization/content.csv`, **sem spawn** em nenhum mapa até a nação abrir. As outras 24 espécies continuam apenas preparadas. Para reproduzir a exportação de Pindorama, execute `bash game/tools/world/export_pindorama_monsters.sh` na raiz. Para reinstalar as folhas do Sol Nascente sem tocar nos `.blend`: `.tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py <id> <1|3|4> --work .work/sol-pilot` (o render, se precisar refazer, sempre com `--no-blend`).

```bash
# Recriar modelos e prévias (raiz do projeto; pode passar IDs após --)
xvfb-run -a .tools/blender/blender -b --python game/tools/art/blender/monsters/export_reserve.py
.tools/pyvenv/bin/python game/tools/art/blender/monsters/reserve/gallery.py

# Gerar sprites no pipeline nativo sem instalar (exemplo)
.tools/blender/blender -b --python game/tools/art/blender/monsters/render_monster.py -- pond_kappa 4 --work .work/regional-reserve-check --no-blend
.tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py pond_kappa 4 --work .work/regional-reserve-check --no-install
```

Ao regenerar sprites, mantenha `--no-blend` para preservar os arquivos coloridos com animações gravadas. Sem essa opção, o renderizador nativo substitui o `.blend` pela sua versão de passes em repouso.

## Direção cultural e procedência

As fichas em `catalog.json` descrevem a inspiração de cada espécie e distinguem releituras folclóricas de fauna e criaturas originais. Referências locais: `GDD-projeto-isekai.md` §4.0 e `docs/mundo/atlas.md` §3. Não foram transformados em inimigos Curupira, mouras guardiãs, aluxes, nahuales ou divindades. Referência complementar para a cauda-mão da criatura aquática: [Ahuizotl](https://en.wikipedia.org/wiki/Ahuizotl_%28mythology%29).

Geometria nova criada por scripts para este projeto. Os packs CC0 locais e seus adaptadores foram consultados; este lote usa formas procedurais para sustentar as anatomias de objetos, artrópodes, serpentes e suas alterações de boss/atroz sem dependência externa. Não foram copiadas novas malhas ou texturas de terceiros. A paleta e a biblioteca `mon_rig` pertencem ao pipeline existente.
