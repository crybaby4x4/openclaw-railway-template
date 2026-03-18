---
name: container-ops
description: Background knowledge for agents operating inside the openclaw Railway container. Use when installing packages, editing shell config, managing files, troubleshooting environment issues, or doing any system-level operation inside the running container.
---

# Container Operations Guide

This container runs on Railway with a persistent volume mounted at `/data`. Only `/data` survives redeployments — everything else resets.

## Persistent vs Ephemeral

| Path | Persistent | Notes |
|------|-----------|-------|
| `/data/**` | ✅ | The only persistent storage |
| `/data/home/openclaw` | ✅ | User home dir (symlinked from `/home/openclaw`) |
| `/data/.openclaw` | ✅ | OpenClaw state, config, extensions |
| `/data/workspace` | ✅ | Agent workspace |
| `/data/.linuxbrew` | ✅ | Homebrew (symlinked from `/home/linuxbrew/.linuxbrew`) |
| `/data/pkg/npm-global` | ✅ | Global npm packages |
| `/data/pkg/pnpm` | ✅ | Global pnpm packages |
| `/data/pkg/python-user` | ✅ | pip --user packages |
| `/usr/**`, `/etc/**` | ❌ | Resets on redeploy |
| `/home/openclaw` | symlink → `/data/home/openclaw` | Effectively persistent |

## Shell Environment

- Default shell: **zsh** with **oh-my-zsh** (`/opt/oh-my-zsh`, baked into image)
- `~/.zshrc` → sources `~/.zshrc.base` + user customizations
- `~/.zshrc.base` → **auto-regenerated every container start** (do not edit manually)
- To add permanent customizations: edit `~/.zshrc` below the `# --- your customizations ---` line

## Key Environment Variables

```
HOME=/home/openclaw                          → /data/home/openclaw
SHELL=/bin/zsh
ZSH=/opt/oh-my-zsh

NPM_CONFIG_PREFIX=/data/pkg/npm-global       → npm -g installs here
NPM_CONFIG_CACHE=/data/pkg/npm-cache
PNPM_HOME=/data/pkg/pnpm                     → pnpm global installs here
PNPM_STORE_DIR=/data/pkg/pnpm-store
PYTHONUSERBASE=/data/pkg/python-user         → pip --user installs here
PIP_CACHE_DIR=/data/pkg/pip-cache
HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew   → brew installs here
```

## Installing Packages

### Persistent after redeploy ✅

```bash
npm install -g <pkg>          # → /data/pkg/npm-global
pnpm add -g <pkg>             # → /data/pkg/pnpm
pip install --user <pkg>      # → /data/pkg/python-user
brew install <pkg>            # → /data/.linuxbrew
```

### Lost on redeploy ❌

```bash
sudo apt install <pkg>        # writes to /usr — DO NOT use for runtime installs
apt-get install <pkg>         # same
pip install <pkg>             # without --user, writes to /usr
npm install -g <pkg> --prefix /usr/local  # wrong prefix
```

**Rule**: Use `apt` only for system tools that belong in the Dockerfile. For runtime tool installs, always use `brew` / `npm -g` / `pnpm -g` / `pip --user`.

System packages already baked into the image (no need to reinstall):
- Browser automation: `chromium`, `xvfb`, `libnss3`, `libatk-bridge2.0-0`, `libgtk-3-0`
- Use `chromium --no-sandbox` or set `CHROMIUM_PATH=/usr/bin/chromium` in browser automation tools

Global npm tools baked into the image (available as commands directly):
- `claude` — Claude Code CLI (`@anthropic-ai/claude-code`)
- `codex` — OpenAI Codex CLI (`@openai/codex`)
- `gemini` — Google Gemini CLI (`@google/gemini-cli`)
- `agent` — Cursor Agent CLI (installed via official install script)
- `openclaw`, `clawhub` — OpenClaw suite

All of the above are in the image layer under `/usr/local/bin/` and do NOT need to be reinstalled.

## zshrc Rules

Wrong order causes `compdef: command not found`:

```
✅ Correct order in .zshrc.base:
  1. env vars (PATH, XDG_*, NPM_CONFIG_*, ...)
  2. source oh-my-zsh
  3. compinit guard
  4. source completions (openclaw.zsh, etc.)

❌ Never source completions before oh-my-zsh is loaded
```

If `compdef` errors appear, add this before any completion `source` line:
```zsh
if ! (( $+functions[compdef] )); then autoload -Uz compinit && compinit; fi
```

## npm Global Directory

npm expects `lib/` and `bin/` subdirectories to exist:
```
/data/pkg/npm-global/
  ├── lib/        ← must exist
  └── bin/        ← must exist
```
These are created by `entrypoint.sh` on every start. If missing (old container), create manually:
```bash
mkdir -p /data/pkg/npm-global/lib /data/pkg/npm-global/bin
```

## OpenClaw Specifics

| Path | Purpose |
|------|---------|
| `/data/.openclaw/openclaw.json` | Main config — presence means "configured" |
| `/data/.openclaw/gateway.token` | Gateway bearer token (stable across redeploys) |
| `/data/.openclaw/extensions/` | User plugins (persistent) |
| `/data/.openclaw/completions/openclaw.zsh` | Shell completions (auto-generated) |
| `/usr/local/lib/node_modules/openclaw/` | OpenClaw itself (image layer, owned by `openclaw` user) |

The `openclaw` user owns `/usr/local/lib/node_modules/openclaw/` so plugins can install into `extensions/acpx/node_modules/` at runtime without sudo.

## Common Mistakes to Avoid

- **Never edit `~/.zshrc.base`** — it's overwritten every restart
- **Never `apt install` at runtime** — use `brew` instead
- **Never write to `/tmp` for anything that needs to persist** — use `/data`
- **Never move or delete `/home/openclaw`** — it's a symlink to `/data/home/openclaw`
- **Never move or delete `/home/linuxbrew/.linuxbrew`** — it's a symlink to `/data/.linuxbrew`
- **Don't use `pip install` without `--user`** — it will try to write to system dirs and fail or get lost
