#!/bin/bash
# ultra-ultra: every knob in one place. Source this; override anything with an env var before sourcing
# or by editing env.local.sh (gitignored) next to it.
#
# Design: one TensorFold 1.0.x native binary serves BOTH models. Nothing here assumes the maintainer's
# machine: paths derive from $HOME and the repo, and all memory decisions are made from measured RAM.

set -u
ULTRA_ROOT="${ULTRA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -f "$ULTRA_ROOT/bin/env.local.sh" ] && . "$ULTRA_ROOT/bin/env.local.sh"

# ---- TensorFold (pinned) ----------------------------------------------------------------------------
TF_VERSION="${TF_VERSION:-1.0.11}"
TF_HOME="${TF_HOME:-$HOME/.local/share/tensorfold}"          # release archive lands here
TF_BIN="${TF_BIN:-$TF_HOME/$TF_VERSION/tensorfold-$TF_VERSION-macos-arm64/bin/tensorfold-native}"
# If `brew install ashhart/tensorfold/tensorfold` was used instead, point TF_BIN at that binary.

# ---- Models (pinned) --------------------------------------------------------------------------------
# Main agent: Qwen3.8 Flash Next, the MLX 6-bit/group-32 MTP checkpoint 1.0.x qualifies on M5 Ultra.
MAIN_REPO="${MAIN_REPO:-TensorFold/Qwen3.8-Flash-Next-MLX-6bit-MTP}"
MAIN_REV="${MAIN_REV:-}"                                       # filled by bin/pin-revisions.sh
# Worker pool: Nemotron 3.5 Lightning 30B-A3B, the 1.0.x model with shared-round concurrency on Metal.
WORKER_REPO="${WORKER_REPO:-TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit}"
WORKER_REV="${WORKER_REV:-}"
HF_HUB_CACHE="${HF_HUB_CACHE:-$HOME/.cache/huggingface/hub}"
export HF_HUB_CACHE

# ---- Serving ----------------------------------------------------------------------------------------
BIND_HOST="${BIND_HOST:-127.0.0.1}"
MAIN_PORT="${MAIN_PORT:-11520}";     MAIN_NAME="${MAIN_NAME:-main}"
WORKER_PORT="${WORKER_PORT:-11521}"; WORKER_NAME="${WORKER_NAME:-worker}"

MAIN_CONTEXT="${MAIN_CONTEXT:-262144}"        # prompt + reply window
MAIN_THINKING_BUDGET="${MAIN_THINKING_BUDGET:-8192}"
MAIN_PROMPT_CACHE_GIB="${MAIN_PROMPT_CACHE_GIB:-}"   # empty = TensorFold's own cap math (5.7 GiB on 256 GB)
MAIN_EXTRA_ARGS="${MAIN_EXTRA_ARGS:-}"

WORKER_CONTEXT="${WORKER_CONTEXT:-131072}"
WORKER_PARALLEL="${WORKER_PARALLEL:-8}"       # concurrent subagent streams sharing each decode round
WORKER_PROMPT_CACHE_GIB="${WORKER_PROMPT_CACHE_GIB:-8}"
WORKER_EXTRA_ARGS="${WORKER_EXTRA_ARGS:-}"

# ---- Memory guard -----------------------------------------------------------------------------------
# up.sh refuses to load a model unless free+inactive RAM >= the model's floor + MIN_FREE_GIB, and the
# guard stops the stack if free RAM drops under GUARD_FLOOR_GIB (macOS wires model memory; starving it
# stalls the whole Mac rather than just the server).
MIN_FREE_GIB="${MIN_FREE_GIB:-12}"
GUARD_FLOOR_GIB="${GUARD_FLOOR_GIB:-6}"

# ---- State ------------------------------------------------------------------------------------------
STATE_DIR="${STATE_DIR:-$ULTRA_ROOT/.state}"
LOG_DIR="${LOG_DIR:-$ULTRA_ROOT/logs}"
mkdir -p "$STATE_DIR" "$LOG_DIR"

# ---- Hermes -----------------------------------------------------------------------------------------
# The recipe never touches ~/.hermes. It installs a self-contained profile home here.
ULTRA_HERMES_HOME="${ULTRA_HERMES_HOME:-$HOME/.hermes-ultra}"

export TENSORFOLD_NO_UPDATE_CHECK=1 TENSORFOLD_NO_LIVE=1

ram_gib()       { echo $(( $(sysctl -n hw.memsize) / 1073741824 )); }
free_gib()      { vm_stat | awk '/Pages free/{f=$3}/Pages inactive/{i=$3}END{printf "%d",(f+i)*16384/1073741824}'; }
pid_alive()     { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
listening()     { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
need()          { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
