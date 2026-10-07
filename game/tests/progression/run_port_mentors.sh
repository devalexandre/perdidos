#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT:-$project_dir/../.tools/godot-4.7.2}"
run_dir="${LOG_DIR:-$(mktemp -d /tmp/port-mentors.XXXXXX)}"
port="${PORT:-8954}"
mkdir -p "$run_dir/saves" "$run_dir/state"
"$godot_bin" --headless --path "$project_dir" -- --server --port="$port" --autotest --dev-commands --save-dir="$run_dir/saves" --state-dir="$run_dir/state" > "$run_dir/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
sleep 3
set +e
timeout 130 "$godot_bin" --headless --path "$project_dir" -- --name=PortMentorTest --port="$port" --autotest --autotest-script=res://tests/progression/port_mentors_client.gd > "$run_dir/client.log" 2>&1
result=$?
set -e
rg 'PORT_MENTOR|ERROR:' "$run_dir/client.log" || true
printf 'Logs: %s\n' "$run_dir"
exit "$result"
