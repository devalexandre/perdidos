# Site do Perdidos

Site estático, sem build, todo em pt-BR.

## Como abrir

- Direto: abra `index.html` no navegador.
- Com servidor local (recomendado), de qualquer pasta:
  ```
  cd /home/devalexandre/projects/devalexandre/game-mmo/site && python3 -m http.server 8000
  ```
  e acesse http://localhost:8000. Para parar, use Ctrl+C.
  Se o navegador mostrar imagens antigas, recarregue com Ctrl+F5.

## Estrutura

- `index.html` — portal: novidades, mundo, títulos, galeria e downloads
- `guia.html` — almanaque completo, com as árvores, bestiário e trilha
- `css/portal.css` — identidade em pergaminho, verde e dourado; layouts responsivos
- `css/style.css` — componentes detalhados do guia
- `js/main.js` — menu no celular, pétalas, troca de nacionalidade, filtro do bestiário, ampliação das capturas, formulário
- `img/` — capturas e sprites do jogo · `audio/` — 4 faixas da trilha em MP3 · `fonts/` — Open Sans

## Marcadores para outros agentes

- `<!-- TITLE_OUTFIT:<id> -->` em cada título (seção Títulos): as imagens `img/titles/<id>_m.png` e `_f.png` são a
  roupa própria do título. Para refazê-las: `xvfb-run -a godot --path game
  res://tools/art/title_outfits/render_site_titles.tscn -- --out=$PWD/site/img/titles` (ver
  `game/tools/art/title_outfits/README.md`).
- Títulos v0.4 (30/09): caminho do Arco, Suporte e Tanque (combinação, borda tracejada roxa `#8e66c4`) entraram com o
  mesmo marcador. Enquanto um título não tiver `.tres` com `outfit_id`, gere a imagem com
  `--pairs=<título>:<outfit_id>,...` no mesmo comando.
- `<!-- NPCS_PORTO -->` (seção Terra do Sabiá, Porto): `img/npcs/<id>.png` é o quadro parado de frente de
  `game/assets/npcs/npc_<id>_idle.png`, recortado em 76x92 com os pés embaixo.
- Os efeitos das skills (`img/fx/<skill>.webp`) já entraram, vindos de `.work/fx/best/`, com os nomes de teste apagados.

- **Seção Títulos (30/09):** um bloco de abas (`.trees[data-tabs]` + `.skilltree`, JS em `js/main.js`), uma aba por
  título. Cada aba traz a roupa (`img/titles/<id>_m.png` e `_f.png`; sem o arquivo, mostra o Viajante com o aviso
  "Roupa em produção"), o que o título faz, como conquistar e as 5 skills (`img/skills/<skill>.png`). O bloco de
  árvores da seção Combate foi incorporado aqui.

## O formulário

A página inicial direciona à pasta pública de versões configurada no launcher. Os botões identificam a plataforma; não prometem download direto nem versões que possam ainda não estar publicadas. O formulário de lista de espera foi retirado do site.

## Licenças e origem

- Fonte Open Sans — SIL Open Font License 1.1 (`fonts/OFL.txt`). É a mesma família da fonte padrão da Godot
  que o jogo usa hoje (`game/assets/fonts/` está vazia).
- Imagens: arte e capturas do próprio jogo (ver `game/assets/*/LICENSES.md` e `REGISTRO.md`).
- Músicas: faixas do jogo (`game/assets/audio/LICENSES.md`, ElevenLabs, licença comercial sem atribuição).

## Progressão por áreas (30/09/2026)

O bloco `#progressao-areas` apresenta a rota Porto ↔ Campos (1–10) ↔ Mata (6–12) ↔ Chapada (12–25). São protótipos jogáveis, não cenários finais. Chefes na Chapada; outras nove regiões e Ninho do Boitatá continuam planejados. O bestiário distingue as 21 espécies do treino dos 30 modelos adicionais ainda reservados. Manter números alinhados com `docs/mundo/progressao-areas.md`.

## Reformulação de UI/UX (07/10/2026)

Referências de organização: Ragnarok Online (https://ragnarokonline.gungho.jp/) e Tree of Savior (https://treeofsavior.com/page/main/?lang=en). A arte é do próprio Perdidos. O portal reduz a navegação inicial a cinco entradas e mantém a documentação em `guia.html`. Abas de títulos operam por clique e teclas de seta/Home/End; galeria usa diálogo nativo com Escape; FAQ não depende de JavaScript. Nenhuma música toca automaticamente. Testado no Chromium a 390, 768 e 1440 px, incluindo menu, abas, diálogo, imagens e ausência de rolagem horizontal.
