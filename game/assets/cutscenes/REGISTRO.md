# Registro — ilustrações das cinemáticas

Cinemática da travessia (GDD §9.3; roteiro em `docs/lore/chegada-do-viajante.md`).
Dados dos planos: `cutscenes/arrival/shots.json`. Cena: `scenes/cutscenes/arrival.tscn`.

- **Ferramenta:** Bria (`tools/art/character_pipeline/gen.py`, endpoint v2 text→image), 27/09/2026.
- **Proporção:** 16:9 (saída 1024x576). 4 seeds por prompt; escolhida a melhor (vista uma a uma;
  rejeitadas as com letreiros/pseudo-texto, ex.: `s2m_1`, `s2m_3`, `s2f_3`, ou cabelo exagerado).
- **Tratamento:** redução BOX para 960x540 + quantização adaptativa 96 cores (FASTOCTREE, sem
  dithering) com `_reference/cutscenes/downscale_quantize.py`. (MEDIANCUT apagava o dourado da pétala.)
- **Originais e prompts:** `assets/_reference/cutscenes/` (`*_raw.png`, `p_*.txt`, `neg.txt`).
- Prompt negativo (todas): conteúdo de `neg.txt` (texto, logos, fotorrealismo, 3D, gradientes suaves, horror).
- Seeds: gen.py usa `SEED + i` (i = 0..3). Base por prompt abaixo.

| Arquivo final | Prompt | Seed base | Escolhida (i) | Seed final |
|---|---|---|---|---|
| arrival/city_male.png | p_s1m.txt | 30100 | 3 | 30103 |
| arrival/city_female.png | p_s1f.txt | 30200 | 3 | 30203 |
| arrival/petal_male.png | p_s2m.txt | 30300 | 2 | 30302 |
| arrival/petal_female.png | p_s2f.txt | 30400 | 2 | 30402 |
| arrival/fall.png | p_s4.txt | 30500 | 2 | 30502 |
| arrival/land.png | p_s5.txt | 30600 | 3 | 30603 |
| arrival/cerrado.png | p_s6.txt | 30700 | 0 | 30700 |
| arrival/riverbank_male.png | p_s8m.txt | 30800 | 0 | 30800 |
| arrival/riverbank_female.png | p_s8f.txt | 30900 | 0 | 30900 |

Para refazer um plano: `export BK=...; NEG=assets/_reference/cutscenes/neg.txt SEED=30600 python3
tools/art/character_pipeline/gen.py /tmp/s5 assets/_reference/cutscenes/p_s5.txt 4 16:9`, escolher,
e rodar `python downscale_quantize.py <raw> assets/cutscenes/arrival/<nome>.png`.

**Pendências de arte (não bloqueiam):** o Viajante das ilustrações é gerado por prompt (não é o
sprite do jogo), então o rosto/cabelo varia um pouco entre planos; o cabelo masculino está mais
volumoso que na âncora 2. O redemoinho do plano "legends" tem um gorrinho pequeno, mais para
castanho-avermelhado. Uma repintura manual (ou geração com imagem de referência) melhoraria a
consistência. Paralaxe por camadas ainda não usada (só pan/zoom + partículas + brilho).
