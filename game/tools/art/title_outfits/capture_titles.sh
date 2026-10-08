#!/usr/bin/env bash
# Captura do CLIENTE REAL no ponto de nascimento (cidade) com um personagem de cada título, 2 corpos.
# Servidor local com saves prontos (título conquistado e exibido) + um cliente em janela (xvfb 1920x1080) por
# personagem; `import -window root` depois de WAIT s. Mata só os próprios PIDs.
# Uso: tools/art/title_outfits/capture_titles.sh <saida> [titulo ...]   (padrão: todos os de data/titles com traje)
# WEAPON=<item> equipa a arma no save (ex.: WEAPON=simple_bow para ver o arco na mão).
set -uo pipefail
OUT=${1:?saida}; shift || true; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
G="${GODOT:-$ROOT/.tools/godot-4.7.2}"; P="$ROOT/game"
PORT="${PORT:-8391}"; DISP="${DISP:-93}"; WAIT="${WAIT:-14}"
mkdir -p "$OUT/saves"
EQUIP="{}"
[[ -n "${WEAPON:-}" ]] && EQUIP="{\"weapon\": {\"item\": \"$WEAPON\", \"qty\": 1, \"protected\": false}}"
TITLES=("$@")
if [[ ${#TITLES[@]} -eq 0 ]]; then
	for f in "$P"/data/titles/pindorama_*.tres; do TITLES+=("$(basename "$f" .tres)"); done
fi
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
i=0
for t in "${TITLES[@]}"; do
	for body in male female; do
		i=$((i + 1)); name="T${i}x"
		hair=$([[ $body == male ]] && echo spiky || echo ponytail)
		cat >"$OUT/saves/$(echo "$name" | tr '[:upper:]' '[:lower:]').json" <<JSON
{"format": 1, "name": "$name", "body": "$body", "level": 10, "attributes": {}, "hp": 200, "mp": 200, "stars": 0,
 "inventory": [], "equipment": $EQUIP, "once_flags": [], "left_training": true, "home_map": "city_awakening",
 "appearance": {"skin": 1, "hair_style": "$hair", "hair_color": 1, "eye_color": 0, "nationality": "pindorama"},
 "progression": {"titles": {"$t": 1}, "displayed_title": "$t"}}
JSON
	done
done
"$G" --headless --path "$P" -- --server --port="$PORT" --save-dir="$OUT/saves" >"$OUT/server.log" 2>&1 & PIDS+=($!)
Xvfb ":$DISP" -screen 0 1920x1080x24 >/dev/null 2>&1 & PIDS+=($!)
sleep 3
i=0
for t in "${TITLES[@]}"; do
	for body in male female; do
		i=$((i + 1)); name="T${i}x"
		DISPLAY=":$DISP" "$G" --path "$P" --resolution 1920x1080 --position 0,0 -- --name="$name" --body="$body" \
			--port="$PORT" >"$OUT/client_${t}_${body}.log" 2>&1 & CP=$!
		sleep "$WAIT"
		import -display ":$DISP" -window root "$OUT/${t}_${body}.png"
		kill "$CP" 2>/dev/null; wait "$CP" 2>/dev/null
		sleep "${GAP:-8}"   # o servidor tira o personagem anterior do mundo antes do próximo entrar
		echo "captura $OUT/${t}_${body}.png"
	done
done
