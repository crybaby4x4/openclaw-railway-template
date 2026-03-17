#!/bin/bash
set -euo pipefail

PERSISTENT_HOME="/data/home/openclaw"
ZSHRC_PATH="${PERSISTENT_HOME}/.zshrc"

mkdir -p /data
mkdir -p /data/home
mkdir -p /data/pkg/npm-global
mkdir -p /data/pkg/npm-cache
mkdir -p /data/pkg/pnpm
mkdir -p /data/pkg/pnpm-store
mkdir -p /data/pkg/python-user
mkdir -p /data/pkg/pip-cache
mkdir -p "${PERSISTENT_HOME}/.config"
mkdir -p "${PERSISTENT_HOME}/.cache"
mkdir -p "${PERSISTENT_HOME}/.local/share"
mkdir -p "${PERSISTENT_HOME}/.local/state"

chown -R openclaw:openclaw /data
chmod 700 /data

if [ ! -f "${PERSISTENT_HOME}/.bootstrap-complete" ]; then
  cp -a /home/openclaw/. "${PERSISTENT_HOME}/" 2>/dev/null || true
  touch "${PERSISTENT_HOME}/.bootstrap-complete"
fi

if [ ! -f "${ZSHRC_PATH}" ]; then
  printf '%s\n' 'export PATH="/data/pkg/npm-global/bin:/data/pkg/pnpm:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"' > "${ZSHRC_PATH}"
  printf '%s\n' 'export SHELL="/bin/zsh"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export ZDOTDIR="${HOME}"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export XDG_CONFIG_HOME="${HOME}/.config"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export XDG_CACHE_HOME="${HOME}/.cache"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export XDG_DATA_HOME="${HOME}/.local/share"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export XDG_STATE_HOME="${HOME}/.local/state"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export NPM_CONFIG_PREFIX="/data/pkg/npm-global"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export NPM_CONFIG_CACHE="/data/pkg/npm-cache"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export NPM_CONFIG_USERCONFIG="${HOME}/.npmrc"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export PNPM_HOME="/data/pkg/pnpm"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export PNPM_STORE_DIR="/data/pkg/pnpm-store"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export PYTHONUSERBASE="/data/pkg/python-user"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export PIP_CACHE_DIR="/data/pkg/pip-cache"' >> "${ZSHRC_PATH}"
  printf '%s\n' 'export HOMEBREW_CACHE="${HOME}/.cache/Homebrew"' >> "${ZSHRC_PATH}"
fi

chown -R openclaw:openclaw "${PERSISTENT_HOME}"

rm -rf /home/openclaw
ln -sfn "${PERSISTENT_HOME}" /home/openclaw

if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi

rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

export HOME=/home/openclaw
export SHELL=/bin/zsh
export ZDOTDIR=/home/openclaw
export XDG_CONFIG_HOME=/home/openclaw/.config
export XDG_CACHE_HOME=/home/openclaw/.cache
export XDG_DATA_HOME=/home/openclaw/.local/share
export XDG_STATE_HOME=/home/openclaw/.local/state
export NPM_CONFIG_PREFIX=/data/pkg/npm-global
export NPM_CONFIG_CACHE=/data/pkg/npm-cache
export NPM_CONFIG_USERCONFIG=/home/openclaw/.npmrc
export PNPM_HOME=/data/pkg/pnpm
export PNPM_STORE_DIR=/data/pkg/pnpm-store
export PYTHONUSERBASE=/data/pkg/python-user
export PIP_CACHE_DIR=/data/pkg/pip-cache
export HOMEBREW_CACHE=/home/openclaw/.cache/Homebrew
export PATH="/data/pkg/npm-global/bin:/data/pkg/pnpm:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

exec gosu openclaw node src/server.js
