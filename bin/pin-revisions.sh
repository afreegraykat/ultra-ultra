#!/bin/bash
# Record the exact HF revisions on disk into bin/env.local.sh (MAIN_REV/WORKER_REV) so a published
# results table names the checkpoints it measured.
set -euo pipefail
. "$(dirname "$0")/env.sh"
rev_of() {  # repo -> commit hash from the HF cache's refs/main
  local d="$HF_HUB_CACHE/models--${1//\//--}"; cat "$d/refs/main" 2>/dev/null || echo unknown
}
m=$(rev_of "$MAIN_REPO"); w=$(rev_of "$WORKER_REPO")
echo "MAIN_REV=$m"; echo "WORKER_REV=$w"
{ grep -vE '^(MAIN_REV|WORKER_REV)=' "$ULTRA_ROOT/bin/env.local.sh" 2>/dev/null || true; echo "MAIN_REV=$m"; echo "WORKER_REV=$w"; } >"$ULTRA_ROOT/bin/env.local.sh.tmp"
mv "$ULTRA_ROOT/bin/env.local.sh.tmp" "$ULTRA_ROOT/bin/env.local.sh"
