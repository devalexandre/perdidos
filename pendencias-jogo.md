# Pendências do jogo

## Combate
- O combate precisa ter movimento.
- Quando o personagem estiver armado e desarmado, devem existir animações de ataque diferentes.
- Deve haver som de ataque e impacto.
- O personagem não pode ficar maior que os monstros.

## UI / HUD
- A tela deve ocupar toda a área visível.
- Os demais elementos devem ficar sobre a tela sem deixar partes cinzas ou vazios visuais.
- Menus podem ficar em um botão/engrenagem mantendo o atalho e abrindo espaço na tela.
- Revisar a organização dos menus para manter clareza e conforto de uso.
- **Tela de Criação de Personagem:** [CONCLUÍDO] Reformulada com pedestal de pedra e moldura dourada, painel rúnico escuro estilo Sun Haven, seleção de atributos com swatches coloridos, brasões das 10 nacionalidades e botão JOGAR esmeralda.
- **Sprites e Roupas dos Títulos:** atualmente todos os títulos parecem ter a mesma roupa porque compartilham a mesma malha base 3D (`branch_coat`) do pipeline do Blender, variando apenas o shader de recoloração de paleta. Criar silhuetas e cortes visuais únicos por arquétipo (Tanque com armadura pesada/carapaça, Ágil/Lâmina com couro e faixas, Arcano com túnica e mangas largas, Xamânico com penas/peles).
- **Cenário 2.5D (estilo Ragnarok Online):** Cenário 100% poligonal 3D (terreno em malha, prédios, árvores e praças) combinado com personagens e monstros em sprites 2D pixel-art com alinhamento vertical via shader `billboard_y_sprite.gdshader`.

## Progressão / atributos
- Ao chegar no nível 10, cada mestre deve ter a opção de falar sobre o título que passa.
- Atributos devem incluir: DES para velocidade, esquiva e chance de acerto.
- Precisamos ter sorte nos atributos.
- Sorte deve aumentar: chance de crítico, drop de itens e chance de encontrar monstros raros.
- Tudo ligado a sorte deve estar integrado no sistema de atributos e loot.

## Ideias para quando tivermos hospedagem paga (VPS)
- **Chat de voz no grupo** (anotado em 07/10/2026). Recomendação: só dentro do grupo, desligado por padrão, "aperte para falar", Opus ~24 kbps, repassado pelo nosso servidor (sem mixagem, sem TURN, sem serviço pago).
  - Custo no aparelho: ~1–3% de CPU, alguns MB de memória, +5–10% de bateria por hora com o microfone aberto; ~24 kbps de envio e o mesmo por pessoa falando de recebimento.
  - Custo no servidor: CPU quase zero; banda ~480 kbps por grupo de 5 falando (~200 MB/h). O ngrok gratuito não aguenta (limite de tráfego) → exige VPS (~R$ 30–60/mês).
  - Técnica: o Godot captura o microfone, mas precisa de GDExtension de Opus (testar no Android).
  - Moderação e privacidade: o filtro de palavrões não pega voz → botão de silenciar por membro e denúncia; permissão de microfone no Android e consentimento claro (LGPD).

## Observações gerais
- O personagem DevAlexandre já deve receber 999 poções.
- Manter o controle das pendências para evitar esquecer itens importantes de gameplay, UI e balance.
