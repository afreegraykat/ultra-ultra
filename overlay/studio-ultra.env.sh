# Production env for studio-llm (copied to bin/env.local.sh by overlay/install-lane.sh).
# Main keeps the legacy port and model name so every existing client/tunnel works unchanged.
MAIN_PORT=11504
MAIN_NAME=flashnext
WORKER_PORT=11505
# Exact served id: the PR-swarm gate (agent-ops gn100_models_check) pins this string.
WORKER_NAME=nemotron35-lightning-30b-a3b-mlx4
MAIN_CONTEXT=262144
MAIN_THINKING_BUDGET=8192
WORKER_CONTEXT=131072
WORKER_PARALLEL=8
WORKER_PROMPT_CACHE_GIB=8
MIN_FREE_GIB=12
GUARD_FLOOR_GIB=10
STATE_DIR=/Users/aubrey/llm/lane/ultra-state
LOG_DIR=/Users/aubrey/llm/logs
