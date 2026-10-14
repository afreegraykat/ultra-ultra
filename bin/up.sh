#!/bin/bash
# Bring up worker then main, each gated on measured free RAM. Idempotent: a server already listening on
# its port with a live recorded PID is left alone. Logs in $LOG_DIR, PIDs in $STATE_DIR.
set -euo pipefail
. "$(dirname "$0")/env.sh"
[ -x "$TF_BIN" ] || { echo "run bin/setup.sh first" >&2; exit 1; }

floor_gib() {  # TensorFold's own memory floor for a cached repo, in GiB (weights + runtime margin)
  local f; f=$("$TF_BIN" info "$1" 2>/dev/null | awk '/memory floor/{print int($3)}'); echo "${f:-0}"
}

wait_ready() {  # $1 port, $2 pid, $3 label, $4 timeout s
  local t=0
  until listening "$1"; do
    pid_alive "$2" || { echo "   $3 exited during load; see $LOG_DIR/$3.log" >&2; tail -5 "$LOG_DIR/$3.log" >&2; return 1; }
    sleep 3; t=$((t+3)); [ "$t" -lt "$4" ] || { echo "   $3 not listening after ${4}s" >&2; return 1; }
  done
  curl -sf "http://$BIND_HOST:$1/v1/models" >/dev/null
}

start_one() {  # $1 label, $2 repo, $3 port, $4 name, rest = serve args
  local label=$1 repo=$2 port=$3 name=$4; shift 4
  local pidf="$STATE_DIR/$label.pid"
  if [ -f "$pidf" ] && pid_alive "$(cat "$pidf")" && listening "$port"; then
    echo "== $label already up (pid $(cat "$pidf"), :$port)"; return 0
  fi
  listening "$port" && { echo "== :$port is taken by something this recipe did not start; pick another $(echo "$label" | tr a-z A-Z)_PORT" >&2; return 1; }
  local need=$(( $(floor_gib "$repo") + MIN_FREE_GIB )) have; have=$(free_gib)
  echo "== $label: needs ~${need} GiB free (floor + ${MIN_FREE_GIB} margin), have ${have} GiB"
  [ "$have" -ge "$need" ] || { echo "   refusing to load; free RAM first or lower contexts (docs/memory.md)" >&2; return 1; }
  echo "   $TF_BIN serve $repo --host $BIND_HOST --port $port --name $name $*" | tee -a "$LOG_DIR/$label.log"
  # No nohup: it fails under launchd ("can't detach from console"). A subshell with stdin from /dev/null,
  # SIGHUP ignored, and its own process group is detached enough for both a terminal and a daemon.
  ( trap '' HUP; cd /; exec "$TF_BIN" serve "$repo" --host "$BIND_HOST" --port "$port" --name "$name" --backend mlx --no-update-check "$@" ) \
    </dev/null >>"$LOG_DIR/$label.log" 2>&1 &
  echo $! >"$pidf"; date +%s >"$STATE_DIR/$label.started"
  wait_ready "$port" "$(cat "$pidf")" "$label" 600
  echo "   $label ready at http://$BIND_HOST:$port/v1 ($(grep -o 'loaded in [0-9.]*s' "$LOG_DIR/$label.log" | tail -1))"
}

# Worker first: smaller, and its shared rounds are what the pool depends on.
w_args=(--context "$WORKER_CONTEXT" --parallel "$WORKER_PARALLEL" --prompt-cache-gib "$WORKER_PROMPT_CACHE_GIB" --no-thinking --temperature 0)
[ -n "$WORKER_EXTRA_ARGS" ] && read -r -a _x <<<"$WORKER_EXTRA_ARGS" && w_args+=("${_x[@]}")
start_one worker "$WORKER_REPO" "$WORKER_PORT" "$WORKER_NAME" "${w_args[@]}"

m_args=(--context "$MAIN_CONTEXT" --thinking --thinking-budget "$MAIN_THINKING_BUDGET" --temperature 0)
[ -n "$MAIN_PROMPT_CACHE_GIB" ] && m_args+=(--prompt-cache-gib "$MAIN_PROMPT_CACHE_GIB")
[ -n "$MAIN_EXTRA_ARGS" ] && read -r -a _x <<<"$MAIN_EXTRA_ARGS" && m_args+=("${_x[@]}")
start_one main "$MAIN_REPO" "$MAIN_PORT" "$MAIN_NAME" "${m_args[@]}"

echo "== up. free RAM now: $(free_gib) GiB. bin/status.sh for details; bin/guard.sh to babysit memory."
