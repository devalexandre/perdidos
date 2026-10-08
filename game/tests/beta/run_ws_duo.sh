#!/usr/bin/env bash
# Teste local do transporte WebSocket (o mesmo do `make serve-ngrok`, sem abrir túnel nenhum):
# servidor --transport=ws + 2 clientes em ws://127.0.0.1:PORT. Os dois se veem no Porto, formam grupo pelo chat
# (/grupo), entram nos Campos de Pindorama (mapa compartilhado desde 30/09/2026), se veem, lutam, ganham XP e pegam o drop.
# Uso: GODOT=/caminho/godot [OUT=.work/beta/ws] [PORT=8395] game/tests/beta/run_ws_duo.sh   (SHOTS=0 = headless)
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/beta/ws}"
PORT="${PORT:-8395}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state" "$OUT"
for n in WsAna WsBia; do
	low=$(echo "$n" | tr '[:upper:]' '[:lower:]')
	cat >"$TMP/saves/$low.json" <<JSON
{"format": 1, "name": "$n", "body": "female", "level": 5, "attributes": {}, "hp": 200, "mp": 60,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true, "home_map": "city_awakening"}
JSON
done
"$GODOT" --headless --path "$GAME_DIR" -- --server --transport=ws --port="$PORT" --save-dir="$TMP/saves" \
	--state-dir="$TMP/state" --dev-commands --drop-chance-mult=50 >"$TMP/server.log" 2>&1 &
SP=$!
PIDS=()
trap 'for p in "${PIDS[@]}"; do kill $p 2>/dev/null; done; kill $SP 2>/dev/null; wait 2>/dev/null' EXIT
sleep 4
run_client() { # nome outro display
	local cmd=("$GODOT" --path "$GAME_DIR")
	if [[ "${SHOTS:-1}" == "1" ]]; then
		cmd=(xvfb-run -n "$3" -s "-screen 0 1280x720x24" "$GODOT" --path "$GAME_DIR" --resolution 1280x720)
	else
		cmd=("$GODOT" --headless --path "$GAME_DIR")
	fi
	timeout 400 "${cmd[@]}" -- --name="$1" --body=female --host="ws://127.0.0.1:$PORT" --autotest \
		--autotest-script=res://tests/beta/beta_route_client.gd --beta-role=duo --watch-name="$2" \
		--shot-dir="$OUT" >"$TMP/$1.log" 2>&1
}
run_client WsAna WsBia $((PORT + 11)) &
PIDS+=($!); A=$!
run_client WsBia WsAna $((PORT + 12)) &
PIDS+=($!); B=$!
wait "$A"; RA=$?
wait "$B"; RB=$?
grep -h "beta_route_check" "$TMP"/Ws*.log | sed -E 's/^\[client\] beta_route_check //'
grep -c '"transport":"ws"' "$TMP/server.log" | sed 's/^/  servidor ws iniciado: /'
grep -o '"peer_joined[^}]*' "$TMP/server.log" | head -2
cp "$TMP/server.log" "$OUT/ws_server.log"; cp "$TMP"/Ws*.log "$OUT/"
rm -rf "$TMP"
if [[ $RA -eq 0 && $RB -eq 0 ]]; then echo "WS DUO: PASS"; exit 0; fi
echo "WS DUO: FAIL (ana=$RA bia=$RB)"; exit 1
