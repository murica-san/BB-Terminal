#!/usr/bin/env bash
set -euo pipefail

API_PORT=6900
UI_PORT=5173

cleanup() {
  if [ -n "${API_PID:-}" ]; then
    kill "$API_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

openbb-api --host 0.0.0.0 --port "$API_PORT" &
API_PID=$!

for i in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:$API_PORT/openapi.json"; then
    break
  fi
  if [ "$i" = "60" ]; then
    echo "ERROR: OpenBB API failed to start within 60s" >&2
    exit 1
  fi
  sleep 1
done

exec npx vite preview --host 0.0.0.0 --port "$UI_PORT"
