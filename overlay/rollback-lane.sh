#!/bin/bash
# Run ON THE STUDIO as root:  sudo bash /Users/aubrey/ultra-ultra/overlay/rollback-lane.sh
# Stops the ultra lane and restores the ds4 (TensorFold 0.6.0) lane exactly as it was.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
OLD=/Library/LaunchDaemons/com.aubrey.studio-ds4-tensorfold.plist
NEW=/Library/LaunchDaemons/com.aubrey.studio-ultra.plist
launchctl bootout system "$NEW" 2>/dev/null || true
[ -f "$NEW" ] && mv "$NEW" "$NEW.disabled"
sudo -u aubrey bash /Users/aubrey/ultra-ultra/bin/down.sh || true
[ -f "$OLD.disabled" ] && mv "$OLD.disabled" "$OLD"
rm -f /Users/aubrey/llm/lane/ds4.hold
launchctl bootstrap system "$OLD"
echo "ds4 lane bootstrapped; flashnext back on :11504 in ~60 s:"
for i in $(seq 1 40); do curl -sf -m 2 http://127.0.0.1:11504/v1/models && break; sleep 3; done; echo
