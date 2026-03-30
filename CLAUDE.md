# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Railway deployment wrapper for **OpenClaw** (an AI coding assistant platform). It provides:

- A web-based setup wizard at `/setup` (protected by `SETUP_PASSWORD`)
- Automatic reverse proxy from public URL → internal OpenClaw gateway
- Persistent state via Railway Volume at `/data`
- Optional web-based TUI terminal access
- Structured logging with SSE streaming and file rotation

The wrapper manages the OpenClaw lifecycle: onboarding → gateway startup → traffic proxying.

## Development Commands

```bash
# Local development (requires OpenClaw installed globally or OPENCLAW_ENTRY set)
npm run dev        # same as npm start

# Production start
npm start

# Syntax check (no linter configured)
npm run lint
```

**Package manager**: pnpm (with workspace config). Uses `corepack enable` in Docker.

## Docker Build & Local Testing

```bash
# Build the container
docker build -t openclaw-railway-template .

# Run locally with volume
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e SETUP_PASSWORD=test \
  -e OPENCLAW_STATE_DIR=/data/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
  -v $(pwd)/.tmpdata:/data \
  openclaw-railway-template

# Access setup wizard
open http://localhost:8080/setup  # password: test
```

## Architecture

### Request Flow

1. **User → Railway → Wrapper (Express 5 on PORT)** → routes to:
   - `/setup/*` → setup wizard (auth: Basic with `SETUP_PASSWORD`)
   - `/tui` → web terminal (auth: Basic, requires `ENABLE_WEB_TUI=true`)
   - `/logs` → log viewer (auth: Basic)
   - All other routes → proxied to internal gateway

2. **Wrapper → Gateway** (localhost:18789 by default)
   - HTTP/WebSocket reverse proxy via `http-proxy`
   - Automatically injects `Authorization: Bearer <token>` header (except `/hooks/*` paths)

### Lifecycle States

1. **Unconfigured**: No `openclaw.json` exists
   - All non-`/setup` routes redirect to `/setup`
   - User completes setup wizard → runs `openclaw onboard --non-interactive`

2. **Configured**: `openclaw.json` exists
   - On boot: runs `openclaw doctor --fix`, then spawns `openclaw gateway run`
   - Waits for gateway readiness (polls endpoints every 250ms, 60s timeout)
   - Proxies all traffic with injected bearer token
   - Auto-restarts gateway on crash (2s delay)

### Key Files

- **src/server.js** (1,283 lines, main entry): Express wrapper, proxy setup, gateway lifecycle, setup API, web TUI, logging
- **src/public/** (static assets):
  - **setup.html**: Setup wizard UI (Alpine.js, multi-step onboarding)
  - **styles.css**: Shared CSS (light/dark mode via CSS variables, Space Grotesk font)
  - **tui.html**: Web terminal UI (xterm.js-based)
  - **loading.html**: Loading/error fallback page (shown when gateway unavailable)
  - **logs.html**: Real-time log viewer (SSE-based)
- **Dockerfile**: Node 22-bookworm base, installs OpenClaw `2026.3.8`, Linuxbrew, creates non-root `openclaw` user
- **entrypoint.sh**: Persists Linuxbrew to volume, runs server as `openclaw` user via `gosu`
- **railway.toml**: Railway deployment config (Dockerfile builder, health check at `/setup/healthz`)

### Environment Variables

**Required:**
- `SETUP_PASSWORD` — protects `/setup` wizard and web TUI

**Recommended (Railway template defaults):**
- `OPENCLAW_STATE_DIR=/data/.openclaw` — config + credentials
- `OPENCLAW_WORKSPACE_DIR=/data/workspace` — agent workspace

**Optional:**
- `OPENCLAW_GATEWAY_TOKEN` — auth token for gateway (auto-generated and persisted if unset)
- `PORT` — wrapper HTTP port (default 8080)
- `INTERNAL_GATEWAY_PORT` — gateway internal port (default 18789)
- `INTERNAL_GATEWAY_HOST` — gateway bind host (default 127.0.0.1)
- `OPENCLAW_ENTRY` — path to `entry.js` (default `/openclaw/dist/entry.js`)
- `OPENCLAW_NODE` — node executable (default `node`)
- `OPENCLAW_CONFIG_PATH` — override config file path (default `${STATE_DIR}/openclaw.json`)
- `ENABLE_WEB_TUI` — enable web terminal at `/tui` (default `false`)
- `TUI_IDLE_TIMEOUT_MS` — TUI idle timeout (default 300000 = 5 min)
- `TUI_MAX_SESSION_MS` — TUI max session duration (default 1800000 = 30 min)
- `RAILWAY_PUBLIC_DOMAIN` — auto-set by Railway, used for allowed origins sync

### Authentication Flow

The wrapper manages a **two-layer auth scheme**:

1. **Setup wizard auth**: Basic auth with `SETUP_PASSWORD`, timing-safe comparison via `crypto.timingSafeEqual` (src/server.js:338-370)
2. **Gateway auth**: Bearer token (auto-generated or from `OPENCLAW_GATEWAY_TOKEN` env)
   - Token is auto-injected into proxied HTTP requests (src/server.js:1136-1141)
   - Token is auto-injected into proxied WebSocket upgrades (src/server.js:1143-1146)
   - Persisted to `${STATE_DIR}/gateway.token` if not provided via env (src/server.js:71-91)
   - **Exception**: Requests to `/hooks/*` paths skip token injection (src/server.js:1137)

3. **Rate limiting**: 50 requests per 60s per IP on setup endpoints (src/server.js:313-336)

### Onboarding Process

When the user runs setup (src/server.js:640-776):

1. Validates payload (auth choice, string fields)
2. Calls `openclaw onboard --non-interactive` with user-selected auth provider
3. Sets gateway config: `allowInsecureAuth=true`, auth token, trusted proxies
4. Optionally sets model via `openclaw models set`
5. Writes channel configs (Telegram/Discord/Slack) directly via `openclaw config set --json`
6. Restarts gateway process
7. Waits for gateway readiness

**Important**: Channel setup bypasses `openclaw channels add` and writes config directly because `channels add` is flaky across different OpenClaw builds.

### Gateway Token Injection

The wrapper **always** injects the bearer token into proxied requests so browser clients don't need to know it:

- HTTP requests: via `proxy.on("proxyReq")` event handler (src/server.js:1136)
- WebSocket upgrades: via `proxy.on("proxyReqWs")` event handler (src/server.js:1143)
- Both also set `Origin` header to `RAILWAY_PUBLIC_DOMAIN` or gateway target (src/server.js:1132-1134)

**Important**: Token injection uses `http-proxy` event handlers (`proxyReq` and `proxyReqWs`) rather than direct `req.headers` modification. Direct header modification does not reliably work with WebSocket upgrades, causing intermittent `token_missing` or `token_mismatch` errors.

The Control UI at `/openclaw` auto-redirects to include the token as a query parameter (src/server.js:1171-1173).

### Logging System

Structured logging with three outputs (src/server.js:22-69):

- **Console**: stdout/stderr with timestamps, levels, and categories
- **Ring buffer**: Last 1000 lines in memory, served to SSE clients
- **Log file**: `${STATE_DIR}/server.log`, auto-rotated at 5MB (halved)

SSE streaming available at `/setup/api/logs/stream`. Log history at `/setup/api/logs`.

### Web TUI

Optional web-based terminal (disabled by default, set `ENABLE_WEB_TUI=true`):

- Single concurrent session only (409 Conflict if session exists)
- Spawns `openclaw tui` via `node-pty`
- Idle timeout (default 5 min) and max session duration (default 30 min)
- Basic auth required (same `SETUP_PASSWORD`)
- WebSocket at `/tui/ws`, UI at `/tui`

### Setup API Endpoints

All under `/setup/api/*`, require Basic auth:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/setup/api/status` | GET | OpenClaw version, auth providers, TUI status |
| `/setup/api/run` | POST | Execute onboarding |
| `/setup/api/reset` | POST | Delete config file |
| `/setup/api/doctor` | POST | Run `openclaw doctor --repair` |
| `/setup/api/devices` | GET | List paired devices |
| `/setup/api/devices/approve` | POST | Approve device pairing |
| `/setup/api/devices/reject` | POST | Reject device pairing |
| `/setup/api/pairing/approve` | POST | Approve channel pairing code |
| `/setup/api/export` | GET | Download password-protected zip of state |
| `/setup/api/logs` | GET | Get log history (query: `?lines=500`) |
| `/setup/api/logs/stream` | GET | SSE log stream |
| `/setup/api/debug` | GET | Debug info (versions, paths, config state) |

## Common Development Tasks

### Testing the setup wizard

1. Delete `${STATE_DIR}/openclaw.json` (or use Reset in the UI)
2. Visit `/setup` and complete onboarding
3. Check logs for gateway startup and channel config writes

### Testing authentication

- Setup wizard: Clear browser auth, verify Basic auth challenge
- Gateway: Remove `Authorization` header injection (src/server.js:1138) and verify requests fail
- Hooks: Verify `/hooks/*` paths work without token injection

### Debugging gateway startup

Check logs for:
- `[gateway] starting with command: ...` (src/server.js:247)
- `[gateway] ready at <endpoint>` (src/server.js:193)
- `[gateway] failed to become ready after 60 seconds` (src/server.js:207)
- `[gateway] exited code=... signal=...` (src/server.js:258) — triggers auto-restart

If gateway doesn't start:
- Verify `openclaw.json` exists and is valid JSON
- Check `STATE_DIR` and `WORKSPACE_DIR` are writable
- Ensure bearer token is set in config
- Check `openclaw doctor --fix` output in boot logs

### Modifying onboarding args

Edit `buildOnboardArgs()` (src/server.js:528-576) to add new CLI flags or auth providers. Update `VALID_AUTH_CHOICES` array (src/server.js:602-618) accordingly.

### Adding new channel types

1. Add channel-specific fields to `/setup` HTML (src/public/setup.html)
2. Add config-writing logic in the `configureChannel` calls within `/setup/api/run` handler (src/server.js:713-759)
3. The setup.html uses Alpine.js for client-side state management

### Adding new auth providers

1. Add to `authGroups` array in `/setup/api/status` handler (src/server.js:421-516)
2. Add CLI flag mapping in `buildOnboardArgs` (src/server.js:554-567)
3. Add to `VALID_AUTH_CHOICES` array (src/server.js:602-618)

## Railway Deployment Notes

- Template must mount a volume at `/data`
- Must set `SETUP_PASSWORD` in Railway Variables
- Public networking must be enabled (assigns `*.up.railway.app` domain)
- OpenClaw is installed via `npm install -g openclaw@2026.3.8` during Docker build
- Health check at `/setup/healthz` with 300s timeout
- Linuxbrew is persisted to `/data/.linuxbrew` via entrypoint.sh symlink
- Container runs as non-root `openclaw` user via `gosu`

## Tech Stack

- **Runtime**: Node.js 22 (Docker) / 24 (local via .mise.toml)
- **Framework**: Express 5 (ES modules)
- **Proxy**: http-proxy
- **Terminal**: node-pty + ws (WebSocket)
- **Frontend**: Alpine.js (setup wizard), xterm.js (web TUI), vanilla CSS
- **Package manager**: pnpm
- **No build step**: All JS served directly, no transpilation

## Quirks & Gotchas

1. **Gateway token must be stable across redeploys** → persisted to volume if not in env
2. **Channels are written via `config set --json`, not `channels add`** → avoids CLI version incompatibilities
3. **Gateway readiness check polls multiple endpoints** (`/openclaw`, `/`, `/health`) → some builds only expose certain routes (src/server.js:184)
4. **Discord bots require MESSAGE CONTENT INTENT** → documented in setup wizard
5. **Gateway spawn inherits stdio** → logs appear in wrapper output (src/server.js:236)
6. **WebSocket auth requires proxy event handlers** → Direct `req.headers` modification doesn't work for WebSocket upgrades with http-proxy; must use `proxyReqWs` event (src/server.js:1143) to reliably inject Authorization header
7. **Control UI requires allowInsecureAuth to bypass pairing** → Set `gateway.controlUi.allowInsecureAuth=true` during onboarding to prevent "disconnected (1008): pairing required" errors. Wrapper already handles bearer token auth, so device pairing is unnecessary.
8. **Hooks paths bypass auth injection** → `/hooks/*` requests are proxied without Bearer token (src/server.js:1137) to avoid overwriting webhook-specific auth
9. **Gateway auto-restarts on crash** → 2s delay before restart attempt (src/server.js:260-269)
10. **Allowed origins auto-sync** → `RAILWAY_PUBLIC_DOMAIN` is synced to `gateway.controlUi.allowedOrigins` before each gateway start (src/server.js:151-171)
11. **Doctor runs on boot** → `openclaw doctor --fix` executes before gateway start when already configured (src/server.js:1187-1193)
12. **Single TUI session** → Only one web terminal session at a time; returns 409 if occupied
