#!/bin/bash
# Stop main then worker (reverse of up). Only kills PIDs this recipe recorded, and only if the process
# is still the tensorfold we started (start-time check), never a stranger on the same port.
set -u
. "$(dirname "$0")/env.sh"
stop_one() {
  local label=$1 pidf="$STATE_DIR/$1.pid" pid
  [ -f "$pidf" ] || { echo "== $label: no pid file"; return 0; }
  pid=$(cat "$pidf")
  if pid_alive "$pid" && ps -o args= -p "$pid" | grep -q "tensorfold-native serve"; then
    echo "== $label: stopping pid $pid"; kill -TERM "$pid"
    for _ in $(seq 1 30); do pid_alive "$pid" || break; sleep 1; done
    pid_alive "$pid" && { echo "   still alive, SIGKILL"; kill -KILL "$pid"; }
  else
    echo "== $label: pid $pid not ours or already gone"
  fi
  rm -f "$pidf" "$STATE_DIR/$label.started"
}
stop_one main
stop_one worker
echo "== down. free RAM: $(free_gib) GiB"
