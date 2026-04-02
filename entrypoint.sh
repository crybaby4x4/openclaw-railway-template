#!/bin/bash
set -e

chown -R openclaw:openclaw /data
chmod 700 /data

# Persist Linuxbrew to volume
if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew 2>/dev/null || true
fi
if [ -d /data/.linuxbrew ]; then
  rm -rf /home/linuxbrew/.linuxbrew 2>/dev/null || true
  ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew 2>/dev/null || true
fi

# Start persistent Chromium CDP instance for OpenClaw browser tool
CHROMIUM_CDP_PORT=${CHROMIUM_CDP_PORT:-9223}
if [ "${CHROMIUM_ENABLED:-true}" = "true" ] && command -v chromium >/dev/null 2>&1; then
  mkdir -p /data/.chromium-profile
  chown openclaw:openclaw /data/.chromium-profile
  gosu openclaw chromium \
    --remote-debugging-port="$CHROMIUM_CDP_PORT" \
    --remote-debugging-address=127.0.0.1 \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --disable-setuid-sandbox \
    --no-first-run \
    --no-default-browser-check \
    --user-data-dir=/data/.chromium-profile \
    --disable-extensions \
    about:blank &
  echo "[entrypoint] Chromium CDP started on port $CHROMIUM_CDP_PORT (PID=$!)"
fi

exec gosu openclaw node src/server.js
