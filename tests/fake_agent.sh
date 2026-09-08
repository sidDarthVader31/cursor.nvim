#!/usr/bin/env bash
# Fake Cursor ACP agent for cursor.nvim tests.
# Reads newline-delimited JSON-RPC from stdin, writes responses to stdout.
set -euo pipefail

LOG_FILE="${CURSOR_NVIM_FAKE_AGENT_LOG:-}"
SESSION_ID="sess_test_001"
INIT_COUNT=0

log() {
  if [[ -n "$LOG_FILE" ]]; then
    echo "$1" >> "$LOG_FILE"
  fi
}

load_config_options() {
  local fixture="${CURSOR_NVIM_FIXTURE_DIR:-$(dirname "$0")/fixtures}/session_new.json"
  if [[ -f "$fixture" ]]; then
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(json.dumps(data.get('configOptions', [])))
" "$fixture" 2>/dev/null || echo '[]'
  else
    echo '[]'
  fi
}

CONFIG_OPTIONS=$(load_config_options)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  method=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('method',''))" 2>/dev/null || echo "")
  id=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
  config_id=$(echo "$line" | python3 -c "import json,sys; p=json.load(sys.stdin).get('params',{}); print(p.get('configId',''))" 2>/dev/null || echo "")

  log "REQ method=$method id=$id configId=$config_id"

  case "$method" in
    initialize)
      INIT_COUNT=$((INIT_COUNT + 1))
      log "INIT_COUNT=$INIT_COUNT"
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"protocolVersion\":1}}"
      ;;
    authenticate)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"authenticated\":true}}"
      ;;
    session/new)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"sessionId\":\"$SESSION_ID\",\"configOptions\":$CONFIG_OPTIONS}}"
      ;;
    session/load)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"sessionId\":\"$SESSION_ID\",\"configOptions\":$CONFIG_OPTIONS}}"
      ;;
    session/set_config_option)
      if [[ -z "$config_id" || "$config_id" == "None" ]]; then
        printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32603,\"message\":\"Internal error\"}}"
      else
        printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"configOptions\":$CONFIG_OPTIONS}}"
      fi
      ;;
    session/prompt)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      ;;
    session/cancel)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      ;;
    *)
      if [[ -n "$id" && "$id" != "None" ]]; then
        printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32601,\"message\":\"Method not found: $method\"}}"
      fi
      ;;
  esac
done
