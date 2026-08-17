#!/usr/bin/env bash
#
# Docker Engine + Compose plugin, from Docker's official apt repo.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Docker"

if have docker && dpkg_installed docker-ce; then
  skip "docker ($(docker --version | awk '{print $3}' | tr -d ,))"
else
  require_sudo

  # Docker publishes per-suite. New Ubuntu releases lag, so fall back to the
  # most recent LTS suite Docker actually ships for rather than 404ing on a
  # codename that has no repo yet.
  suite="$UBUNTU_CODENAME"
  if ! curl -fsIL "https://download.docker.com/linux/ubuntu/dists/$suite/Release" >/dev/null 2>&1; then
    warn "Docker publishes no repo for '$UBUNTU_CODENAME' yet — using 'noble'"
    suite="noble"
  fi

  info "adding Docker apt repository ($suite)"
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $suite stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -qq
  apt_install docker-ce docker-ce-cli containerd.io \
              docker-buildx-plugin docker-compose-plugin
fi

# Compose v2 is a plugin subcommand ("docker compose"), not docker-compose.
if docker compose version >/dev/null 2>&1; then
  ok "compose $(docker compose version --short 2>/dev/null)"
else
  warn "docker compose plugin not working"
fi

step "Docker group membership"

if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  skip "$USER is in the docker group"
else
  info "adding $USER to the docker group"
  sudo groupadd -f docker
  sudo usermod -aG docker "$USER"
  ok "added"
  warn "group changes do not apply to this shell"
  warn "log out and back in (or run: newgrp docker) before using docker without sudo"
fi

if systemctl is-enabled docker >/dev/null 2>&1; then
  skip "docker service enabled"
else
  sudo systemctl enable --now docker && ok "docker service enabled"
fi
