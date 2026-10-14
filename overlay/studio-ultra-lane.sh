#!/bin/bash
# studio-llm ultra lane supervisor, run by the LaunchDaemon com.aubrey.studio-ultra as aubrey.
# Never exits on its own: brings the stack up, babysits memory, restarts after any exit.
# Hold: while ~/llm/lane/ultra.hold exists the stack stays down (and is taken down if up).
set -u
ROOT=/Users/aubrey/ultra-ultra
LANE=/Users/aubrey/llm/lane
LOG=/Users/aubrey/llm/logs/svc-ultra-lane.log
export PATH=/Users/aubrey/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export TENSORFOLD_NO_LIVE=1 TENSORFOLD_NO_UPDATE_CHECK=1
log() { echo "[$(date '+%F %T')] $*" >>"$LOG"; }
guard_pid=
stop_all() { [ -n "$guard_pid" ] && kill "$guard_pid" 2>/dev/null; guard_pid=; bash "$ROOT/bin/down.sh" >>"$LOG" 2>&1; }
trap 'log "supervisor exiting; stopping stack"; stop_all; exit 0' TERM INT
while true; do
  if [ -f "$LANE/ultra.hold" ]; then
    log "lane held: $(head -1 "$LANE/ultra.hold")"; stop_all
    while [ -f "$LANE/ultra.hold" ]; do sleep 10; done
    log "hold released"
  fi
  log "up.sh"
  if ! bash "$ROOT/bin/up.sh" >>"$LOG" 2>&1; then log "up.sh failed; retry in 30s"; sleep 30; continue; fi
  bash "$ROOT/bin/guard.sh" >>"$LOG" 2>&1 & guard_pid=$!
  . "$ROOT/bin/env.sh"
  main_pid=$(cut -d' ' -f1 "$STATE_DIR/main.pid" 2>/dev/null)
  # wait until main exits or a hold appears
  while kill -0 "$main_pid" 2>/dev/null && [ ! -f "$LANE/ultra.hold" ]; do sleep 10; done
  if [ -f "$LANE/ultra.hold" ]; then continue; fi
  log "main pid $main_pid exited; restarting stack in 10s"; stop_all; sleep 10
done
