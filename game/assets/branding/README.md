# Identidade de abertura

- `icon.png` e `icon.ico`: identidade existente do launcher, copiada de `launcher/build/`.
- `android_icon.png`: versão de 192 × 192 do ícone.
- `android_foreground.png`: ícone centralizado em 432 × 432 com margem transparente para máscaras adaptativas.
- `android_background.png`: fundo opaco do ícone adaptativo.
- `android_monochrome.png`: letra P da identidade existente, em branco com transparência, para temas do Android.
- `splash.png`: abertura do jogo, gerada pela ferramenta integrada imagegen a partir de `assets/ui/title/title_bg_painted.png`.

O projeto usa a splash desde a inicialização da engine, sem adicionar espera artificial. O Android também recebe um ícone próprio para sua abertura nativa. Windows usa o ICO no executável e na janela; Linux usa o PNG na janela. O pacote Linux inclui `instalar-atalho.sh` para registrar o ícone no menu do usuário, sem root; execute novamente se mover a pasta do jogo.

Prompt da splash (imagegen, edição com referência):

> Create a finished landscape 16:9 boot splash for the fantasy game PERDIDOS, using the provided existing game title illustration as the background. Preserve its painterly portal, floating castle, waterfalls and warm pastel fantasy world. Remove the foreground circular character-selection platform and its UI-like arrows, blending into the natural landscape. Integrate a prominent, beautiful, very legible centered game wordmark reading exactly "PERDIDOS" in warm ivory-gold fantasy serif lettering with restrained dark shadow. The wordmark should be centered in the middle of the canvas with ample margin so it works across screen aspect ratios. A subtle dark vignette near edges supports readability. No other text, no loading bar, no Godot mark, no watermarks, no border. This is production splash artwork, not a device mockup. Save the resulting file in the workspace if possible.

Para recompilar: `make build-windows build-linux build-apk` na raiz do repositório.
