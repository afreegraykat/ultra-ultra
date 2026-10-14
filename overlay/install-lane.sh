#!/bin/bash
# Run ON THE STUDIO as root:  sudo bash /Users/aubrey/ultra-ultra/overlay/install-lane.sh
# Installs the ultra LaunchDaemon and disables (does not delete) the ds4 one. Rollback: overlay/rollback-lane.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
ROOT=/Users/aubrey/ultra-ultra
OLD=/Library/LaunchDaemons/com.aubrey.studio-ds4-tensorfold.plist
NEW=/Library/LaunchDaemons/com.aubrey.studio-ultra.plist
# merge overlay values into env.local.sh (keeps MAIN_REV/WORKER_REV written by bin/pin-revisions.sh)
sudo -u aubrey bash -c "grep -E '^(MAIN_REV|WORKER_REV)=' '$ROOT/bin/env.local.sh' 2>/dev/null > '$ROOT/bin/env.local.sh.new' || true; cat '$ROOT/overlay/studio-ultra.env.sh' >> '$ROOT/bin/env.local.sh.new'; mv '$ROOT/bin/env.local.sh.new' '$ROOT/bin/env.local.sh'"
sudo -u aubrey mkdir -p /Users/aubrey/llm/lane/ultra-state
cp "$ROOT/overlay/com.aubrey.studio-ultra.plist" "$NEW"; chown root:wheel "$NEW"; chmod 644 "$NEW"; plutil -lint "$NEW"
# stop the old lane: hold it so its own loop does not fight, then boot it out
sudo -u aubrey bash -c 'echo "replaced by com.aubrey.studio-ultra $(date +%F)" > /Users/aubrey/llm/lane/ds4.hold'
if launchctl print system/com.aubrey.studio-ds4-tensorfold >/dev/null 2>&1; then
  launchctl bootout system "$OLD" || true
fi
[ -f "$OLD" ] && mv "$OLD" "$OLD.disabled"
pkill -TERM -f "tensorfold serve" 2>/dev/null || true
for i in $(seq 1 30); do lsof -nP -iTCP:11504 -sTCP:LISTEN >/dev/null 2>&1 || break; sleep 2; done
launchctl bootstrap system "$NEW"
echo "ultra lane bootstrapped; main back as flashnext on :11504 in ~45 s:"
for i in $(seq 1 40); do curl -sf -m 2 http://127.0.0.1:11504/v1/models && break; sleep 3; done; echo
curl -sf -m 2 http://127.0.0.1:11505/v1/models; echo
launchctl print system/com.aubrey.studio-ultra | egrep "^\s*(state|pid|program) ="
