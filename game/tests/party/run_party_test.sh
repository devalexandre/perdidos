#!/usr/bin/env bash
# Autoteste do grupo e dos mapas compartilhados (decisão do dono em 30/09/2026): servidor + 3 clientes reais
# (PAna líder, PBia membro, PCaio de fora), com janela (xvfb) para as capturas.
#   fase training: personagens novos no Campo de Treino — se veem, convite por /grupo (recusado) e pelo menu
#     (aceito na janela), painel com vida, erros (já tem grupo, não encontrado, sem grupo, não é líder), chat do
#     grupo (/g e aba), /online, XP dividida, drop com posse, provação não roubável, líder/expulsar/sair.
#   fase hunt: saves prontos no Porto — grupo pelo chat, painel com o mapa do outro, os três nos Campos de
#     Pindorama, Ana e Bia lutam juntas (XP dividida), /online com o mapa.
# Uso: GODOT=/caminho/godot [OUT=.work/grupo] [PORT=8461] [PHASES="training hunt"] [SHOTS=1] game/tests/party/run_party_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/grupo}"
PORT="${PORT:-8461}"
PHASES="${PHASES:-training hunt}"
mkdir -p "$OUT"
FAIL=0

run_phase() { # fase nomes(ana,bia,caio)
	local phase="$1" names="$2"
	local TMP; TMP="$(mktemp -d)"
	mkdir -p "$TMP/saves" "$TMP/state" "$TMP/sync"
	if [[ "$phase" == "hunt" ]]; then
		for n in ${names//,/ }; do
			low=$(echo "$n" | tr '[:upper:]' '[:lower:]')
			cat >"$TMP/saves/$low.json" <<JSON
{"format": 1, "name": "$n", "body": "female", "level": 5, "attributes": {}, "hp": 200, "mp": 60,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true, "home_map": "city_awakening"}
JSON
		done
	fi
	"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$TMP/saves" \
		--state-dir="$TMP/state" --dev-commands --drop-chance-mult=50 >"$TMP/server.log" 2>&1 &
	local SP=$!
	local PIDS=()
	sleep 4
	local roles=(ana bia caio) i=0 d=$((PORT + 20))
	IFS=',' read -ra NM <<<"$names"
	for role in "${roles[@]}"; do
		local cmd
		if [[ "${SHOTS:-1}" == "1" ]]; then
			cmd=(xvfb-run -n "$((d + i))" -s "-screen 0 1280x720x24" "$GODOT" --path "$GAME_DIR" --resolution 1280x720)
		else
			cmd=("$GODOT" --headless --path "$GAME_DIR")
		fi
		timeout 1200 "${cmd[@]}" -- --name="${NM[$i]}" --body=$([[ $role == bia ]] && echo male || echo female) \
			--port="$PORT" --autotest --autotest-script=res://tests/party/party_client.gd --party-role="$role" \
			--party-names="$names" --party-phase="$phase" --sync-dir="$TMP/sync" --shot-dir="$OUT" \
			>"$TMP/$role.log" 2>&1 &
		PIDS+=($!)
		i=$((i + 1))
		sleep 1
	done
	local rc=0
	for p in "${PIDS[@]}"; do wait "$p" || rc=1; done
	kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
	echo "== fase $phase"
	grep -h "party_check" "$TMP"/{ana,bia,caio}.log | sed -E 's/^\[client\] party_check //'
	grep -h "party_done" "$TMP"/{ana,bia,caio}.log | sed -E 's/^\[client\] //'
	grep -h "SCRIPT ERROR" -A2 "$TMP"/*.log | head -20
	for f in server ana bia caio; do cp "$TMP/$f.log" "$OUT/${phase}_$f.log"; done
	rm -rf "$TMP"
	if [[ $rc -ne 0 ]]; then FAIL=1; echo "fase $phase: FAIL"; else echo "fase $phase: PASS"; fi
}

for ph in $PHASES; do
	if [[ "$ph" == "hunt" ]]; then run_phase hunt "HAna,HBia,HCaio"; else run_phase training "PAna,PBia,PCaio"; fi
done
if [[ $FAIL -eq 0 ]]; then echo "PARTY TEST: PASS"; exit 0; fi
echo "PARTY TEST: FAIL"; exit 1
