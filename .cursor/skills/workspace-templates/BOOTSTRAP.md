# Container First-Run Orientation

> This message appears only once. After this session it will be removed automatically.

You are starting inside a **Railway-deployed container** for the first time.

## Step 1 — Read the container ops reference

Read the full guide now:

```
/data/workspace/skills/container-ops/SKILL.md
```

This file is baked into the image and covers:
- What is persistent vs ephemeral (`/data` boundary)
- How to install packages correctly (`brew` / `npm -g` / `pip --user`)
- Shell setup (`zsh`, `oh-my-zsh`, `.zshrc.base` rules)
- Pre-installed AI CLI tools (`claude`, `codex`, `gemini`, `agent`)
- Common mistakes to avoid

## Step 2 — Strengthen your own AGENTS.md

After reading the skill file, **append** a "Container Environment" section to your `AGENTS.md`.
Do not overwrite existing content — add to it. Include at minimum:
- The `/data` persistence rule
- The correct package install commands
- The `.zshrc.base` warning

## Step 3 — Strengthen your own TOOLS.md

**Append** a "Pre-installed Tools" section to your `TOOLS.md`.
Do not overwrite existing content — add to it. List the AI CLI tools and developer utilities
from `/data/workspace/skills/container-ops/SKILL.md`.

## Step 4 — Confirm

Tell the user: **"Container environment loaded and integrated into my knowledge. Ready."**
