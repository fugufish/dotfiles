#!/usr/bin/env bash
#
# Base apt packages, build toolchain, and GNU stow.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Base system packages"

apt_refresh

# stow is what deploys every config in this repo — without it 90-stow.sh is a no-op.
# The rest is the build toolchain asdf needs to compile Ruby and friends.
apt_install \
  stow \
  build-essential \
  curl \
  wget \
  git \
  unzip \
  ca-certificates \
  gnupg \
  pkg-config \
  procps \
  file \
  zsh \
  autoconf \
  bison \
  libssl-dev \
  libreadline-dev \
  zlib1g-dev \
  libyaml-dev \
  libffi-dev \
  libgdbm-dev \
  libncurses-dev \
  libdb-dev \
  uuid-dev \
  shellcheck

if [[ "$SHELL" != *zsh ]]; then
  warn "login shell is $SHELL, not zsh"
  info "change it with: chsh -s \"\$(command -v zsh)\"  (takes effect next login)"
else
  ok "login shell is zsh"
fi
