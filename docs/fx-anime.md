# Efeitos de skill "anime" (alta resolução) — como fazer o próximo

Piloto: 07/10/2026, **Faísca (`arcane_spark`) virou Lança de Fogo**. Referência de estilo (só inspiração):
animação "Lança de Fogo" do Defeat the Evil. Personagens e monstros seguem pixel art; **só os efeitos de
skill** saem dela.

## O que faz o efeito não parecer carimbo
1. **Resolução maior que o personagem** (quadros de 192–448 px, filtro linear + mipmaps), degradê e alfa suaves.
2. **Camadas**: corpo em blend normal (toon com contorno, lê em chão claro) + **brilho aditivo** separado
   (núcleo estoura em branco-amarelo) + **partículas** do Godot (brasas, estrelinhas, pedrinhas).
3. **Encenação**: clarão na conjuração → projétil (a lança cai do céu) → explosão em cogumelo → fumaça em
   bolinhas → brasas; nome gritado acima do conjurador (já era para todas as skills), números de dano
   empilhados (`CombatFx._stack_slot`) e **tremor curto de câmera** (`SkillFx._shake`).

## Passo a passo
1. **Blender** (`game/tools/art/fx/anime/fire_lance_blender.py`, use como molde):
   formas por metaball/malha animadas quadro a quadro em Python; material `toon_material()` = emissão com
   rampa **constante** sobre (luz pintada · normal + quanto a face olha para a câmera + "calor" + ruído);
   contorno = casco invertido (`set_hull`, material com backface culling); câmera ortográfica, fundo
   transparente, sem luz. Grava `<OUT>/<peça>/NNNN.png` + `meta.json` (pivô do chão e metros por px).
   `.tools/blender/blender -b --factory-startup -P …/fire_lance_blender.py -- .work/fx-pilot/raw`
2. **Montagem** (`build_anime_fx.py`): grade de 6 colunas, fim do efeito some aos poucos, brilho aditivo tirado
   das partes quentes (meia resolução), clarão de conjuração com texturas **CC0 do Kenney Particle Pack**.
   Escreve em `game/assets/fx/anime/` `<peça>.png` (+ `.import` com mipmaps) e `<peça>.json`:
   `frames, cols, size, pivot, texel, fps, loop, blend (mix|add|glow), plane, filter: "linear"`.
   `.tools/pyvenv/bin/python game/tools/art/fx/anime/build_anime_fx.py .work/fx-pilot/raw ["…/PNG (Transparent)"]`
3. **Cliente**: `SkillFxSprite` acha o `.json` em `assets/fx/anime/` sozinho (grade + shaders
   `skill_fx_*_smooth`; `blend: glow` = só aditivo). Em `SkillFx`: ponha a skill em `RECIPE_ANIME` com uma
   receita nova e escreva a função dela (molde: `_lance_cast_glow`, `_fire_lance`, `_lance_impact`,
   `_impact_particles`, `_particles`, `_shake`). Nomes das peças começam com o id da skill (o teste exige).
4. **Comparar**: cliente com `--classic-fx` volta às folhas em pixel art.
5. **Validar no cliente real**: `PORT=8047 ONLY=<skill> MONSTER=buriti_boar [CLIENT_ARGS=--classic-fx]
   GODOT=$PWD/.tools/godot-4.7.2 xvfb-run -a game/tests/client/run_skill_fx_capture.sh .work/fx-pilot/cap_new`
   e `godot --headless --path game res://tests/client/test_skill_fx.tscn`.
6. **Origem**: registre em `game/assets/fx/anime/ORIGEM.md` (pacotes só CC0; referências de outros jogos só
   como inspiração, nunca quadro/arte).

## Regras
- `validate_art.py` não varre `assets/fx/` — a pasta anime é isenta de paleta/alfa binário de propósito.
- Cores: rampas quentes coerentes com a paleta-mestra, sem quantizar.
- Memória: grade ≤ 2048 px de lado por folha (a explosão de 24×320 px dá 1920×1280).
