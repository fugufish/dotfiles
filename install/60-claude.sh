#!/usr/bin/env bash
#
# Claude Code CLI.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Claude Code"

export PATH="$HOME/.local/bin:$PATH"

if have claude; then
  skip "claude ($(claude --version 2>/dev/null | awk '{print $1}')) at $(command -v claude)"
  info "update in place with: claude update"
else
  info "installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
  have claude || die "claude not on PATH after install — expected ~/.local/bin/claude"
  ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"
fi

add_path_line 'export PATH="$HOME/.local/bin:$PATH"'

info "authenticate on first run: claude"
