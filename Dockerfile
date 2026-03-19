FROM node:22-bookworm

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    procps \
    python3 \
    python3-pip \
    sudo \
    build-essential \
    zsh \
    zip \
    unzip \
    wget \
    ripgrep \
    fd-find \
    jq \
    openssh-client \
    sqlite3 \
    htop \
    lsof \
    net-tools \
    dnsutils \
    vim \
    nano \
    less \
    file \
    tree \
    tmux \
    xvfb \
    chromium \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
  && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    openclaw@2026.3.13 \
    clawhub@latest \
    @anthropic-ai/claude-code \
    @openai/codex \
    @google/gemini-cli \
    @pierre/diffs

RUN curl -fsSL https://cursor.com/install | bash
RUN set -eux; \
  OPENVSCODE_TAG="$(curl -fsSL https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' | head -n1)"; \
  ARCH="$(dpkg --print-architecture)"; \
  case "$ARCH" in \
    amd64) OPENVSCODE_ARCH="x64" ;; \
    arm64) OPENVSCODE_ARCH="arm64" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/gitpod-io/openvscode-server/releases/download/${OPENVSCODE_TAG}/${OPENVSCODE_TAG}-linux-${OPENVSCODE_ARCH}.tar.gz" -o /tmp/openvscode-server.tar.gz; \
  tar -xzf /tmp/openvscode-server.tar.gz -C /opt; \
  ln -s "/opt/${OPENVSCODE_TAG}-linux-${OPENVSCODE_ARCH}/bin/openvscode-server" /usr/local/bin/openvscode-server; \
  rm -f /tmp/openvscode-server.tar.gz

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile --prod

COPY src ./src
COPY --chmod=755 entrypoint.sh ./entrypoint.sh
COPY --chmod=755 scripts/openclaw-gateway-restart /usr/local/bin/openclaw-gateway-restart
COPY .cursor/skills/container-ops/SKILL.md /opt/skills/container-ops/SKILL.md
COPY .cursor/skills/workspace-templates/BOOTSTRAP.md /opt/skills/workspace/BOOTSTRAP.md

RUN useradd -m -s /bin/zsh openclaw \
  && usermod -aG sudo openclaw \
  && echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw \
  && chmod 0440 /etc/sudoers.d/openclaw \
  && chown -R openclaw:openclaw /app \
  && mkdir -p /data && chown openclaw:openclaw /data \
  && mkdir -p /home/linuxbrew/.linuxbrew && chown -R openclaw:openclaw /home/linuxbrew \
  && chown -R openclaw:openclaw /usr/local/lib/node_modules/openclaw \
  && (chown -R openclaw:openclaw /usr/local/lib/node_modules/clawhub 2>/dev/null; true) \
  && (chown -R openclaw:openclaw /usr/local/lib/node_modules/@anthropic-ai 2>/dev/null; true) \
  && (chown -R openclaw:openclaw /usr/local/lib/node_modules/@openai 2>/dev/null; true) \
  && (chown -R openclaw:openclaw /usr/local/lib/node_modules/@google 2>/dev/null; true)

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh \
  && chmod -R 755 /opt/oh-my-zsh

USER openclaw
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

ENV HOME=/home/openclaw
ENV SHELL=/bin/zsh
ENV ZDOTDIR=/home/openclaw
ENV XDG_CONFIG_HOME=/home/openclaw/.config
ENV XDG_CACHE_HOME=/home/openclaw/.cache
ENV XDG_DATA_HOME=/home/openclaw/.local/share
ENV XDG_STATE_HOME=/home/openclaw/.local/state
ENV NPM_CONFIG_PREFIX=/data/pkg/npm-global
ENV NPM_CONFIG_CACHE=/data/pkg/npm-cache
ENV NPM_CONFIG_USERCONFIG=/home/openclaw/.npmrc
ENV PNPM_HOME=/data/pkg/pnpm
ENV PNPM_STORE_DIR=/data/pkg/pnpm-store
ENV PYTHONUSERBASE=/data/pkg/python-user
ENV PIP_CACHE_DIR=/data/pkg/pip-cache
ENV HOMEBREW_CACHE=/home/openclaw/.cache/Homebrew
ENV ZSH=/opt/oh-my-zsh
ENV ZSH_THEME=robbyrussell
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV PATH="/data/pkg/npm-global/bin:/data/pkg/pnpm:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

ENV PORT=8080
ENV OPENCLAW_ENTRY=/usr/local/lib/node_modules/openclaw/dist/entry.js
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/setup/healthz || exit 1

USER root
ENTRYPOINT ["./entrypoint.sh"]
