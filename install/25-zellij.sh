#!/usr/bin/env bash
#
# Rust toolchain + zellij. Must run before Ghostty, which launches zellij.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "zellij"

# The Ghostty config hardcodes ~/.cargo/bin/zellij as its shell command, so
# zellij must land there specifically — a brew-installed zellij would leave
# Ghostty starting nothing. Keep this and ghostty/config in sync.
ZELLIJ_VERSION="${ZELLIJ_VERSION:-0.44.3}"
CARGO_BIN="$HOME/.cargo/bin"

if [[ -x "$CARGO_BIN/zellij" ]]; then
  skip "zellij ($("$CARGO_BIN/zellij" --version | awk '{print $2}')) at $CARGO_BIN/zellij"
else
  if have rustup || [[ -x "$CARGO_BIN/cargo" ]]; then
    skip "rust toolchain"
  else
    info "installing rustup (zellij is built from source)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    ok "rustup installed"
  fi

  export PATH="$CARGO_BIN:$PATH"
  have cargo || die "cargo not found after rustup install"

  # Pinned: the committed config.kdl uses the zellij >= 0.43 Styling format for
  # its inline ghostty-dark theme. An older zellij fails to parse it.
  info "building zellij $ZELLIJ_VERSION (this takes several minutes)"
  cargo install --locked --version "$ZELLIJ_VERSION" zellij
  ok "zellij $ZELLIJ_VERSION"
fi

add_path_line 'export PATH="$HOME/.cargo/bin:$PATH"'

export PATH="$CARGO_BIN:$PATH"
if have zellij && [[ -f "$HOME/.config/zellij/config.kdl" ]]; then
  if zellij setup --check 2>&1 | grep -q 'Well defined'; then
    ok "config.kdl parses cleanly"
  else
    warn "zellij config did not validate — run: zellij setup --check"
  fi
fi
