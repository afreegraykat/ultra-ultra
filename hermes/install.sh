#!/bin/bash
# Create (or refresh) the self-contained Hermes profile home for this recipe at $ULTRA_HERMES_HOME.
# Requires a working `hermes` on PATH (https://hermes-agent.nousresearch.com/docs). Never touches ~/.hermes.
set -euo pipefail
. "$(dirname "$0")/../bin/env.sh"
need hermes
H="$ULTRA_HERMES_HOME"; src="$ULTRA_ROOT/hermes"
mkdir -p "$H"
# Rewrite ports from env.sh so the profile matches the servers up.sh starts.
sed -e "s#http://127.0.0.1:11520/v1#http://$BIND_HOST:$MAIN_PORT/v1#g" \
    -e "s#http://127.0.0.1:11521/v1#http://$BIND_HOST:$WORKER_PORT/v1#g" \
    -e "s#default_model: main#default_model: $MAIN_NAME#; s#^  default: main#  default: $MAIN_NAME#; s#^      main:#      $MAIN_NAME:#" \
    -e "s#default_model: worker#default_model: $WORKER_NAME#; s#^  model: worker#  model: $WORKER_NAME#; s#^      worker:#      $WORKER_NAME:#" \
    -e "s#max_concurrent_children: 8#max_concurrent_children: $WORKER_PARALLEL#" \
    "$src/config.yaml" >"$H/config.yaml"
cp "$src/SOUL.md" "$H/SOUL.md"
echo "== profile home: $H"
echo "== check"
HERMES_HOME="$H" hermes config check 2>&1 | tail -5 || true
cat <<EOF
== use it
   export HERMES_HOME=$H        # or: alias ultra='HERMES_HOME=$H hermes'
   hermes chat -q "Delegate three workers to each compute 17*23 with a tool and report RESULT: <n>."
EOF
