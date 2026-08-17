#!/usr/bin/env bash
#
# Homebrew (linuxbrew) — provides asdf and Python on this setup.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Homebrew"

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_BIN="$BREW_PREFIX/bin/brew"

if [[ -x "$BREW_BIN" ]]; then
  skip "Homebrew ($("$BREW_BIN" --version | head -1))"
else
  info "installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -x "$BREW_BIN" ]] || die "Homebrew install finished but $BREW_BIN is missing"
  ok "Homebrew installed"
fi

# Make brew usable for the rest of this run, not just in new shells.
eval "$("$BREW_BIN" shellenv)"

add_path_line "eval \"\$($BREW_BIN shellenv)\""
