#!/bin/bash
# Full measured run. Writes results/*.jsonl|json. Both servers must be up (bin/up.sh).
set -uo pipefail
. "$(dirname "$0")/../bin/env.sh"
R="$ULTRA_ROOT/results"; mkdir -p "$R"; T="$ULTRA_ROOT/tests"
{ echo "host: $(sysctl -n machdep.cpu.brand_string), $(ram_gib) GB, macOS $(sw_vers -productVersion)"
  echo "tensorfold: $("$TF_BIN" --version)"; echo "hermes: $(PATH=$HOME/.local/bin:$PATH HERMES_HOME=$ULTRA_HERMES_HOME hermes --version 2>/dev/null | head -1)"
  echo "main: $MAIN_REPO @ ${MAIN_REV:-unpinned}  ctx=$MAIN_CONTEXT"; echo "worker: $WORKER_REPO @ ${WORKER_REV:-unpinned}  ctx=$WORKER_CONTEXT parallel=$WORKER_PARALLEL"
  echo "date: $(date -u +%FT%TZ)"; } >"$R/host.txt"; cat "$R/host.txt"
M="http://$BIND_HOST:$MAIN_PORT/v1"; W="http://$BIND_HOST:$WORKER_PORT/v1"
: >"$R/bench.jsonl"
echo "== tool calling"; python3 "$T/toolcall.py" "$M" "$MAIN_NAME" | tee "$R/toolcall-main.txt"; python3 "$T/toolcall.py" "$W" "$WORKER_NAME" | tee "$R/toolcall-worker.txt"
echo "== worker alone"; for c in 1 4 8; do python3 "$T/bench.py" "$W" "$WORKER_NAME" "$c" --tag "worker-c$c-main-idle" >>"$R/bench.jsonl"; done
echo "== main alone";   python3 "$T/bench.py" "$M" "$MAIN_NAME" 1 --max-tokens 400 --tag main-solo-worker-idle >>"$R/bench.jsonl"
echo "== both busy";    ( python3 "$T/bench.py" "$M" "$MAIN_NAME" 1 --max-tokens 400 --tag main-WHILE-worker-c8 >>"$R/bench.jsonl" ) & ( python3 "$T/bench.py" "$W" "$WORKER_NAME" 8 --tag worker-c8-WHILE-main >>"$R/bench.jsonl" ) & wait
echo "   free RAM after both-busy: $(free_gib) GiB" | tee "$R/memory-floor.txt"
echo "== hermes fan-out"; for n in 4 8 16; do python3 "$T/fanout.py" "$n" --out "$R/fanout-$n.json" || echo "   fanout $n FAILED"; done
echo "== summary"; python3 "$T/summarize.py" "$R" | tee "$R/summary.md"
