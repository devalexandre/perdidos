#!/usr/bin/env bash
# Capturas do controle (joypad) no cliente real (tests/client/gamepad_capture.gd): servidor local + um cliente
# por resolução, com controle "conectado" simulado. Desktop 1280x720 e celular em paisagem 1600x720 (antes e
# depois de conectar: os controles de toque somem e aparecem as dicas dos botões).
# Uso: GODOT=/caminho/godot [OUT=.work/gamepad] [PORT=8214] [SIZES="1280x720 m1600x720"] tests/client/run_gamepad_capture.sh
# Tamanho com "m" na frente = modo celular (controles de toque ligados).
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/gamepad}"
PORT="${PORT:-8214}"
SIZES="${SIZES:-1280x720 m1600x720}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
for S in $SIZES; do
	EXTRA=()
	RES="$S"
	if [[ "$S" == m* ]]; then EXTRA+=(--ui-mobile); RES="${S#m}"; fi
	xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" -- --name=PadCap \
		--body=female --port="$PORT" --autotest --autotest-script=res://tests/client/gamepad_capture.gd \
		--shot-dir="$OUT" "${EXTRA[@]}" >"$LOG_DIR/client_$S.log" 2>&1
	echo "=== $S (log: $LOG_DIR/client_$S.log)"
	grep -h "gamepad_capture\|SCRIPT ERROR" "$LOG_DIR/client_$S.log" | head -20
done
