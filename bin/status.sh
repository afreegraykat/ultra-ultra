#!/bin/bash
# One screen: both servers, their footprints, free RAM, and the two /v1/models answers.
set -u
. "$(dirname "$0")/env.sh"
printf "%-7s %-6s %-8s %-10s %s\n" label port pid footprint state
for label in main worker; do
  port=$([ "$label" = main ] && echo "$MAIN_PORT" || echo "$WORKER_PORT")
  pid=$(cat "$STATE_DIR/$label.pid" 2>/dev/null || echo -)
  fp=$(curl -sf "http://$BIND_HOST:$port/memory" 2>/dev/null | python3 -c 'import sys,json;print("%.1f GiB"%(json.load(sys.stdin)["process"]["physical_footprint_bytes"]/2**30))' 2>/dev/null || echo -)
  st=$(listening "$port" && echo listening || echo down)
  printf "%-7s %-6s %-8s %-10s %s\n" "$label" "$port" "$pid" "$fp" "$st"
done
echo "RAM: $(ram_gib) GiB total, $(free_gib) GiB free+inactive"
for port in "$MAIN_PORT" "$WORKER_PORT"; do
  curl -sf "http://$BIND_HOST:$port/v1/models" 2>/dev/null | python3 -c 'import sys,json;[print("  :'"$port"'", m["id"], "ctx", m.get("context_length")) for m in json.load(sys.stdin)["data"]]' 2>/dev/null
done
