FROM node:22-bookworm

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    procps \
    python3 \
    sudo \
    build-essential \
    zip \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@2026.3.8
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

RUN useradd -m -s /bin/bash openclaw \
  && usermod -aG sudo openclaw \
  && echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw \
  && chmod 0440 /etc/sudoers.d/openclaw \
  && chown -R openclaw:openclaw /app \
  && mkdir -p /data && chown openclaw:openclaw /data \
  && mkdir -p /home/linuxbrew/.linuxbrew && chown -R openclaw:openclaw /home/linuxbrew

USER openclaw
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
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
