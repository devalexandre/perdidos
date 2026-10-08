# Magias vivas — apresentação de combate

> Etapa atual: [contato, volume e mira rúnica](magias-vivas-v2.md).

Referência de ritmo: [Mage’s new ability: Jagged Ground](https://www.youtube.com/watch?v=7RRZ1Om6Mco). A leitura usada é preparação → surgimento em sequência → contato → dissipação. Os desenhos, shaders e volumes são próprios do jogo.

## Resultado

- Preparação na cor da magia ou skill: fogo laranja, gelo/cristal azul, vaga-lume verde luminoso, natureza/suporte verde e lâmina dourada. Habilidades sem elemento explícito usam a identidade da escola. O fluxo, o brilho existente e as partículas de preparação recebem a mesma cor.
- Conjurações longas preservam a cadência de preparar e liberar; os quadros intermediários sustentam a energia em vez de esticar toda a animação.
- Projéteis arcanos e sagrados deixam uma fita que acompanha a trajetória real e se dissolve depois da chegada.
- Contato mágico adiciona duas ondas fragmentadas, partículas e dissipação. Gelo, energia, fogo e suporte recebem cores e movimentos próprios. Os cones mantêm a orientação do lançamento.
- A Muralha de Cristal usa gemas facetadas com profundidade, alturas variadas e crescimento sequencial, substituindo as figuras planas repetidas. As bases permanecem no chão e os cristais afundam ao terminar.
- O áudio de impacto e a reação do alvo acompanham o contato visual. Cancelamentos e lançamentos substituídos não liberam efeitos atrasados sobre uma conjuração nova.

## Capturas no cliente real

[Prancha das cinco magias](magias-vivas/board.png).

| Magia | Animação |
| --- | --- |
| Faísca | [GIF](magias-vivas/arcane_spark.gif) |
| Fogo-Fátuo | [GIF](magias-vivas/arcane_will_o_wisp.gif) |
| Rajada Gélida | [GIF](magias-vivas/arcane_frost_burst.gif) |
| Muralha de Cristal | [GIF](magias-vivas/arcane_crystal_wall.gif) |
| Garrafada | [GIF](magias-vivas/support_bottle_brew.gif) |

Os GIFs mostram o cliente em 1280×720 e não contêm áudio. A captura amostra a cada 80 ms; esse intervalo não representa a quantidade de quadros do jogo. Rastros, ondas e crescimento dos volumes são atualizados continuamente.

Essas capturas precedem o ajuste da carga para a cor de cada habilidade; nelas a preparação ainda aparece azul.

## Implementação e validação

`spell_impact_layers.gd` cria ondas, cristais e partículas; `spell_trail.gd` acompanha os projéteis. A integração fica em `skill_fx.gd`. São camadas locais de apresentação, sem alteração de dano, alcance, colisão ou regras do servidor.

A qualidade alta usa oito cristais, 14 partículas e até 14 pontos de rastro. As outras qualidades usam cinco cristais, seis partículas e até sete pontos. Os nós temporários são removidos após a dissipação; a muralha também sai quando o conjurador deixa a cena ou morre.

Validação em Godot 4.7.2:

- `test_skill_fx`: 634/634 verificações, incluindo contato, receitas, cancelamento e limpeza.
- `test_direction`: 194 verificações, sem falhas, incluindo sustentação e liberação de carga longa.
- `test_skill_charge_audio`: 19 verificações, sem falhas.
- `test_spell_layers`: 12 verificações, sem falhas, incluindo volume, direção do cone, base no chão, limites de qualidade e limpeza quando o conjurador sai.
- `test_skill_charge_flow`: passou novamente após a mudança de cores, incluindo fogo, gelo, Fogo-Fátuo, suporte e arco, consistência entre brilho e fluxo, acompanhamento, cancelamento e morte.
- Cinco magias capturadas com servidor e cliente reais.

A captura terminou com código 0 e sem `SCRIPT ERROR`. O encerramento do cliente ainda registra avisos de recursos de textura/fonte do renderizador; as animações foram capturadas antes dessa etapa.

Para reproduzir as capturas:

```bash
GODOT="$PWD/godot" PORT=9136 \
ONLY=arcane_spark,arcane_will_o_wisp,arcane_frost_burst,arcane_crystal_wall,support_bottle_brew \
bash game/tests/client/run_skill_fx_capture.sh "$PWD/.work/spell-review"
```
