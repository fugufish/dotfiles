#!/usr/bin/env bash
#
# Python toolchain — from Homebrew, not asdf (see CLAUDE.md).

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Python"

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
[[ -x "$BREW_BIN" ]] || die "Homebrew missing — run ./install.sh brew first"
eval "$("$BREW_BIN" shellenv)"

# Deliberate: python3 resolves to Homebrew's, while node and ruby come from
# asdf shims. The asdf python plugin exists but is intentionally unpinned in
# .tool-versions. Don't "unify" this without a reason.

# Python needs a brew-specific check: Ubuntu always ships a system python3, so
# `have python3` would be true even with no brew Python at all.
if brew list --formula python >/dev/null 2>&1; then
  skip "python (Homebrew)"
else
  info "installing python"
  brew install python
  ok "python"
fi

# uv only needs to exist somewhere. It has a standalone installer as well as a
# brew formula, and installing the formula over a working standalone copy just
# creates a second binary that shadows the first.
if have uv; then
  skip "uv $(uv --version 2>/dev/null | awk '{print $2}') at $(command -v uv)"
else
  info "installing uv"
  brew install uv
  ok "uv"
fi

if have python3; then
  ok "python3 $(python3 --version 2>&1 | awk '{print $2}') at $(command -v python3)"
  case "$(command -v python3)" in
    /home/linuxbrew/*) : ;;
    *) warn "python3 is NOT the Homebrew one — check PATH order in ~/.zshrc" ;;
  esac
fi
