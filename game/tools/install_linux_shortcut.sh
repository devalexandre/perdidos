#!/usr/bin/env bash
# Executar na pasta do jogo exportado. Não precisa de root.
set -euo pipefail
game_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test -f "$game_dir/Perdidos.x86_64"
test -f "$game_dir/perdidos.png"
python3 - "$game_dir" <<'PY'
import os
import shutil
import sys
from pathlib import Path

game = Path(sys.argv[1])
data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
apps = data / 'applications'
icons = data / 'icons/hicolor/512x512/apps'
apps.mkdir(parents=True, exist_ok=True)
icons.mkdir(parents=True, exist_ok=True)
shutil.copyfile(game / 'perdidos.png', icons / 'perdidos.png')

def value(text):
    return str(text).replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')

def argument(text):
    # Exec tem dois níveis de escape: argumento entre aspas e valor desktop.
    text = str(text).replace('%', '%%')
    for char in ('\\', '"', '`', '$'):
        text = text.replace(char, '\\' + char)
    return value('"' + text + '"')

entry = '\n'.join([
    '[Desktop Entry]', 'Type=Application', 'Name=Perdidos',
    'Comment=Explore o mundo de Perdidos',
    'Exec=' + argument(game / 'Perdidos.x86_64'),
    'Path=' + value(game), 'Icon=perdidos', 'Terminal=false',
    'Categories=Game;RolePlaying;', 'StartupWMClass=Perdidos', ''
])
(apps / 'perdidos.desktop').write_text(entry, encoding='utf-8')
print('Atalho instalado em ' + str(apps / 'perdidos.desktop'))
PY
if command -v update-desktop-database >/dev/null; then
    update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
fi
