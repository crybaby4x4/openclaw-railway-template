#!/bin/bash
# OpenClaw CLI shim for Railway wrapper environment
#
# Problem: The wrapper (server.js) manages the gateway process via
# childProcess.spawn, but `openclaw gateway restart/stop` CLI commands
# use PID file lookup which doesn't find the wrapper-managed process.
# OpenClaw's AI agents read official docs and try these CLI commands,
# causing repeated failures.
#
# Solution: Intercept gateway lifecycle commands and redirect them to
# the wrapper's HTTP API. All other commands pass through to the real
# OpenClaw CLI transparently.

REAL_OPENCLAW="${OPENCLAW_REAL_ENTRY:-/usr/local/lib/node_modules/openclaw/dist/entry.js}"
WRAPPER_PORT="${PORT:-8080}"
WRAPPER_URL="http://127.0.0.1:${WRAPPER_PORT}"

call_wrapper_api() {
  local method="$1"
  local endpoint="$2"

  # Build Basic auth header from SETUP_PASSWORD
  if [ -n "$SETUP_PASSWORD" ]; then
    local auth_header
    auth_header="Authorization: Basic $(printf ':%s' "$SETUP_PASSWORD" | base64 -w0 2>/dev/null || printf ':%s' "$SETUP_PASSWORD" | base64)"
    curl -s -X "$method" "${WRAPPER_URL}${endpoint}" \
      -H "$auth_header" \
      -H "Content-Type: application/json" 2>&1
  else
    curl -s -X "$method" "${WRAPPER_URL}${endpoint}" \
      -H "Content-Type: application/json" 2>&1
  fi
}

if [ "$1" = "gateway" ]; then
  case "$2" in
    restart|restart-gateway)
      echo "[openclaw-shim] Redirecting 'gateway restart' to wrapper API..."
      RESULT=$(call_wrapper_api POST "/setup/api/gateway/restart")
      echo "$RESULT"
      echo "$RESULT" | grep -q '"ok":true' && exit 0 || exit 1
      ;;
    stop)
      echo "[openclaw-shim] Redirecting 'gateway stop' to wrapper API..."
      RESULT=$(call_wrapper_api POST "/setup/api/gateway/stop")
      echo "$RESULT"
      echo "$RESULT" | grep -q '"ok":true' && exit 0 || exit 1
      ;;
    status)
      echo "[openclaw-shim] Checking gateway status via wrapper API..."
      RESULT=$(call_wrapper_api GET "/setup/healthz")
      echo "$RESULT"
      exit 0
      ;;
  esac
fi

# All other commands: pass through to real OpenClaw CLI
exec node "${REAL_OPENCLAW}" "$@"
