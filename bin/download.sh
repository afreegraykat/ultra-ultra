#!/bin/bash
# Pull both checkpoints with TensorFold's own puller (16 connections, sha256-verified, resumable).
# ~165 GB total. Re-running resumes.
set -euo pipefail
. "$(dirname "$0")/env.sh"
[ -x "$TF_BIN" ] || { echo "run bin/setup.sh first" >&2; exit 1; }
which=${1:-both}
pull() { echo "== pull $1"; "$TF_BIN" pull "$1"; }
case "$which" in
  main)   pull "$MAIN_REPO" ;;
  worker) pull "$WORKER_REPO" ;;
  both)   pull "$WORKER_REPO"; pull "$MAIN_REPO" ;;   # small one first so a worker smoke can start early
  *) echo "usage: download.sh [main|worker|both]" >&2; exit 2 ;;
esac
echo "== on disk"; "$TF_BIN" models
