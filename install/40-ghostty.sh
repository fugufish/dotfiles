#!/usr/bin/env bash
#
# Ghostty terminal, from the mkasberg/ghostty-ubuntu PPA.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Ghostty"

if have ghostty; then
  skip "ghostty ($(ghostty --version 2>/dev/null | head -1 | awk '{print $2}'))"
else
  require_sudo

  # Ghostty is not in the Ubuntu archive; this PPA is the maintained Ubuntu build.
  apt_install software-properties-common
  info "adding ppa:mkasberg/ghostty-ubuntu"
  sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
  sudo apt-get update -qq
  apt_install ghostty
fi

# The committed config sets `command = <path>/zellij`, so a Ghostty without
# zellij opens a window that immediately dies.
if [[ -x "$HOME/.cargo/bin/zellij" ]]; then
  ok "zellij present — Ghostty's configured shell command will work"
else
  warn "zellij is MISSING but ghostty/config launches it as its shell command"
  warn "Ghostty windows will fail to open. Run: ./install.sh zellij"
fi
