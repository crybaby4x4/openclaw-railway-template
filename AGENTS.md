# AGENTS.md

## Cursor Cloud specific instructions

### Overview

This is the **OpenClaw Railway Template** — a Node.js/Express wrapper that provides a web-based setup wizard and reverse proxy for the OpenClaw AI assistant gateway. See `CLAUDE.md` for detailed architecture documentation.

### Running the dev server

```bash
SETUP_PASSWORD=test PORT=8080 OPENCLAW_STATE_DIR=/tmp/openclaw-dev OPENCLAW_WORKSPACE_DIR=/tmp/openclaw-dev/workspace node src/server.js
```

- The server requires `SETUP_PASSWORD` to be set (otherwise `/setup` returns 500).
- Without the OpenClaw binary installed, the wrapper still starts and serves the setup wizard UI. The gateway-related features (proxy, gateway lifecycle) require the OpenClaw binary which is only available inside the Docker container.
- Set `OPENCLAW_ENTRY` to a non-existent path (e.g. `/nonexistent/entry.js`) to prevent the wrapper from attempting to run OpenClaw CLI commands that would hang.

### Key commands

- **Lint**: `pnpm run lint` — runs `node -c src/server.js` (syntax check only, no ESLint)
- **Dev**: `pnpm run dev` — starts `node src/server.js`
- **No automated tests** exist in this repository
- **No build step** — vanilla JS, no transpilation

### Gotchas

- `node-pty` is a native module requiring `python3` and `build-essential` for compilation. These are pre-installed in the Cloud VM.
- The project requires **Node.js >= 24** (specified in `package.json` engines and `.mise.toml`). Use `nvm use 24` if needed.
- Package manager is **pnpm** (lockfile: `pnpm-lock.yaml`). Native dependency build policy is configured via `pnpm.onlyBuiltDependencies` in `package.json`.
- Full end-to-end testing (onboarding, gateway proxy) requires building the Docker image, as the OpenClaw binary is only installed inside the container.
