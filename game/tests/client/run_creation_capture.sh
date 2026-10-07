#!/usr/bin/env bash
# Capturas da tela de criação de personagem (tests/client/creation_capture.gd) em várias resoluções.
# Uso: GODOT=/caminho/godot [OUT=.work/creation] [PREFIX=shot] [SIZES="1280x720 t2400x1080 t800x360"] \
#      tests/client/run_creation_capture.sh
# Tamanho com "t" na frente = layout de toque (celular). SLOT=1 = modo seleção (personagem salvo falso).
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/creation}"
PREFIX="${PREFIX:-shot}"
SIZES="${SIZES:-1280x720 1920x1080 t2400x1080 t1280x720 t800x360}"
mkdir -p "$OUT"
for S in $SIZES; do
	EXTRA=()
	RES="$S"
	if [[ "$S" == t* ]]; then EXTRA+=(--touch); RES="${S#t}"; fi
	if [[ "${SLOT:-0}" == 1 ]]; then EXTRA+=(--slot); fi
	echo "=== $S"
	xvfb-run -a -s "-screen 0 2560x1440x24" "$GODOT" --path "$P" --resolution "$RES" \
		res://tests/client/creation_capture.tscn -- --out="$OUT" --prefix="$PREFIX" "${EXTRA[@]}" 2>&1 \
		| grep -E "saved|SCRIPT ERROR|ERROR" | head -20
done
