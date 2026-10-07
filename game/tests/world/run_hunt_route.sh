#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT:-$project_dir/../.tools/godot-4.7.2}"
run_dir="${LOG_DIR:-$(mktemp -d /tmp/hunt-route.XXXXXX)}"
port="${PORT:-8943}"
mkdir -p "$run_dir/saves" "$run_dir/state"
"$godot_bin" --headless --path "$project_dir" -- --server --port="$port" --autotest --dev-commands --save-dir="$run_dir/saves" --state-dir="$run_dir/state" > "$run_dir/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
sleep 3
timeout 1520 "$godot_bin" --headless --path "$project_dir" -- --name=HuntRoute --port="$port" --autotest --autotest-script=res://tests/world/hunt_route_client.gd ${QUICK_ROUTE:+--quick-route} ${WALK_PORTALS:+--walk-portals} > "$run_dir/client.log" 2>&1
rg 'HUNT_ROUTE_' "$run_dir/client.log"
printf 'Logs: %s\n' "$run_dir"
