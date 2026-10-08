#!/usr/bin/env bash
# Extrai do git as folhas ORIGINAIS (4/6 quadros) que o rollout.py deforma: personagens e equipamentos do commit
# f328083, o último antes do rollout de mais quadros (07–08/10/2026). Destino padrão: .work/char-frames-pilot/
# backup_originals (fora do git; ROLLOUT_SRC troca). Uso: game/tools/art/character_pipeline/fetch_rollout_sources.sh
set -euo pipefail
SOURCE_COMMIT="${SOURCE_COMMIT:-f328083}"
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
DEST="${ROLLOUT_SRC:-$ROOT/.work/char-frames-pilot/backup_originals}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -C "$ROOT" archive "$SOURCE_COMMIT" game/assets/characters game/assets/equipment | tar -x -C "$TMP"
mkdir -p "$DEST"
# Só as folhas (.png); os .import do Godot não servem ao rollout.
(cd "$TMP/game/assets" && find characters equipment -name '*.png' -print0 | xargs -0 -I{} cp --parents {} "$DEST/")
echo "originais de $SOURCE_COMMIT em $DEST ($(find "$DEST" -name '*.png' | wc -l) folhas)"
