#!/bin/bash
# Memory guard. Run in the background (or under launchd) while the stack is up. If free+inactive RAM
# falls under GUARD_FLOOR_GIB for 3 consecutive samples, stop the stack cleanly rather than let macOS
# wire itself into a stall. Logs to $LOG_DIR/guard.log.
set -u
. "$(dirname "$0")/env.sh"
interval=${GUARD_INTERVAL_S:-10}; strikes=0
echo "[$(date '+%F %T')] guard start floor=${GUARD_FLOOR_GIB}GiB interval=${interval}s" >>"$LOG_DIR/guard.log"
while true; do
  f=$(free_gib)
  if [ "$f" -lt "$GUARD_FLOOR_GIB" ]; then
    strikes=$((strikes+1)); echo "[$(date '+%F %T')] free=${f}GiB strike $strikes/3" >>"$LOG_DIR/guard.log"
    if [ "$strikes" -ge 3 ]; then
      echo "[$(date '+%F %T')] floor breached; stopping stack" >>"$LOG_DIR/guard.log"
      "$ULTRA_ROOT/bin/down.sh" >>"$LOG_DIR/guard.log" 2>&1; exit 3
    fi
  else strikes=0; fi
  sleep "$interval"
done
