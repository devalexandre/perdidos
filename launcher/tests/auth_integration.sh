#!/usr/bin/env bash
# Integração ponta a ponta do login (sem ngrok, portas próprias, nada do servidor real é tocado):
#   API de contas + porteiro (Go)  ->  servidor Godot WebSocket com --require-auth  <-  clientes headless
# Casos: token de verdade entra no mundo; sem token é recusado; token de outra conta não pega o
# nome de quem já é dono; token adulterado é recusado; senha/token não aparecem nos logs.
#
# Uso: GODOT=/caminho/godot [GO=go] [GAME_PORT=17791] [AUTH_PORT=18091] launcher/tests/auth_integration.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GO="${GO:-go}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GAME_PORT="${GAME_PORT:-17791}"
AUTH_PORT="${AUTH_PORT:-18091}"
TMP="$(mktemp -d)"
SECRETS="$TMP/secrets.env"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
fail=0
need() { if [[ "$1" == "0" ]]; then echo "  [pass] $2"; else echo "  [FAIL] $2"; fail=1; fi; }

# Use only the temporary secret; an inherited value would skip creating secrets.env.
unset PERDIDOS_JWT_SECRET
(cd "$ROOT/launcher/server" && CGO_ENABLED=0 "$GO" build -buildvcs=false -o "$TMP/perdidos-auth" .) || { echo "build da API falhou"; exit 1; }
"$TMP/perdidos-auth" ensure-secret -secrets="$SECRETS" >/dev/null
SECRET_VALUE="$(sed -n 's/^PERDIDOS_JWT_SECRET=//p' "$SECRETS")"

"$GODOT" --headless --path "$ROOT/game" -- --server --transport=ws --port="$GAME_PORT" --require-auth \
	--auth-secrets="$SECRETS" --save-dir="$TMP/saves" >"$TMP/server.log" 2>&1 &
PIDS+=($!)
"$TMP/perdidos-auth" -addr="127.0.0.1:$AUTH_PORT" -game="127.0.0.1:$GAME_PORT" -db="$TMP/accounts.db" \
	-secrets="$SECRETS" -latest="$TMP/latest.json" >"$TMP/auth.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 1 60); do
	curl -sf "http://127.0.0.1:$AUTH_PORT/api/health" >/dev/null && grep -q server_started "$TMP/server.log" && break
	sleep 0.5
done
API="http://127.0.0.1:$AUTH_PORT/api"
token_of() { python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))'; }
PW_A="senha-da-ana-123"
TOKEN_A=$(curl -s -X POST "$API/register" -d "{\"email\":\"ana@teste.dev\",\"password\":\"$PW_A\"}" | token_of)
TOKEN_B=$(curl -s -X POST "$API/register" -d '{"email":"bia@teste.dev","password":"senha-da-bia-123"}' | token_of)
TOKEN_A2=$(curl -s -X POST "$API/login" -d "{\"email\":\"ANA@teste.dev\",\"password\":\"$PW_A\"}" | token_of)
echo "=== API"
[[ -n "$TOKEN_A" && -n "$TOKEN_B" && -n "$TOKEN_A2" ]]; need $? "cadastro de 2 contas e login devolvem JWT"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/login" -d '{"email":"ana@teste.dev","password":"errada-123"}')
[[ "$code" == "401" ]]; need $? "senha errada -> 401 (veio $code)"

# client <log> <nome> [token]
client() {
	local args=(--host="ws://127.0.0.1:$AUTH_PORT" --name="$2")
	[[ -n "${3:-}" ]] && args+=(--token="$3")
	timeout 40 "$GODOT" --headless --path "$ROOT/game" -- "${args[@]}" >"$TMP/$1.log" 2>&1 &
	echo $!
}
wait_for() { # arquivo padrão segundos
	for _ in $(seq 1 $(($3 * 2))); do grep -q -- "$2" "$1" 2>/dev/null && return 0; sleep 0.5; done
	return 1
}

echo "=== jogo com --require-auth (via porteiro ws://127.0.0.1:$AUTH_PORT)"
P=$(client ana Ana "$TOKEN_A"); PIDS+=("$P")
wait_for "$TMP/server.log" 'peer_handshake_ok .*"name":"Ana"' 30; need $? "Ana com token de verdade passa no handshake"
wait_for "$TMP/ana.log" 'local_player_spawned' 30; need $? "Ana entra no mundo (local_player_spawned)"
kill "$P" 2>/dev/null

P=$(client semtoken Zeca); PIDS+=("$P")
wait_for "$TMP/server.log" '"reason":"auth_required"' 30; need $? "sem token: servidor recusa (auth_required)"
wait_for "$TMP/semtoken.log" 'rejected {"reason":"auth_required"' 30; need $? "sem token: cliente recebe a recusa"
kill "$P" 2>/dev/null

sleep 1
P=$(client roubo Ana "$TOKEN_B"); PIDS+=("$P")
wait_for "$TMP/server.log" '"reason":"name_owned"' 30; need $? "outra conta não pega o nome Ana (name_owned)"
kill "$P" 2>/dev/null

BAD="${TOKEN_A%?}x"
P=$(client falso Dado "$BAD"); PIDS+=("$P")
wait_for "$TMP/server.log" '"reason":"auth_invalid"' 30; need $? "token adulterado é recusado (auth_invalid)"
kill "$P" 2>/dev/null

P=$(client ana2 Ana "$TOKEN_A2"); PIDS+=("$P")
n=0
for _ in $(seq 1 60); do
	n=$(grep -c 'peer_handshake_ok .*"name":"Ana"' "$TMP/server.log"); [[ "$n" -ge 2 ]] && break; sleep 0.5
done
[[ "$n" -ge 2 ]]; need $? "a dona entra de novo com Ana (novo login)"
kill "$P" 2>/dev/null

sleep 1
P=$(client segundo Jurema "$TOKEN_A"); PIDS+=("$P")
wait_for "$TMP/server.log" '"reason":"slot_full"' 30; need $? "1 slot por conta: a conta da Ana não cria Jurema (slot_full)"
wait_for "$TMP/segundo.log" 'rejected {"detail":"ana","reason":"slot_full"' 30; need $? "o cliente recebe o nome do personagem da conta"
kill "$P" 2>/dev/null

echo "=== donos dos nomes"
python3 -c "import json,sys; d=json.load(open('$TMP/saves/character_owners.json')); print('  ', d); sys.exit(0 if d.get('ana')==1 and 'zeca' not in d else 1)"
need $? "character_owners.json: ana -> conta 1; Zeca (recusado) não ganhou dono"

echo "=== segredos fora dos logs"
leak=0
for f in "$TMP"/*.log; do
	grep -qF -- "$TOKEN_A" "$f" && { echo "  token em $(basename "$f")"; leak=1; }
	grep -qF -- "$PW_A" "$f" && { echo "  senha em $(basename "$f")"; leak=1; }
	grep -qF -- "$SECRET_VALUE" "$f" && { echo "  segredo em $(basename "$f")"; leak=1; }
done
[[ $leak == 0 ]]; need $? "nenhum log tem token, senha ou segredo"

if [[ $fail == 0 ]]; then echo "AUTH INTEGRATION: PASS"; exit 0; fi
echo "--- server.log (fim)"; tail -30 "$TMP/server.log"
echo "AUTH INTEGRATION: FAIL"; exit 1
