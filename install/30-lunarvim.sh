#!/usr/bin/env bash
#
# LunarVim. Depends on the Neovim that 10-asdf.sh installs.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "LunarVim"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$HOME/.local/bin:$PATH"

if have lvim; then
  skip "lvim ($(lvim --version 2>/dev/null | head -1)) at $(command -v lvim)"
  exit 0
fi

have nvim || die "neovim missing — run ./install.sh asdf first"
ok "neovim $(nvim --version | head -1 | awk '{print $2}')"

# LunarVim's installer wants these at runtime.
apt_install python3-pip
if have npm; then
  ok "npm $(npm --version)"
else
  warn "npm missing — LunarVim's LSP installs will fail; run ./install.sh asdf"
fi

# LunarVim's release branches target specific Neovim versions and lag behind
# current Neovim. Override with LV_BRANCH if the default refuses to install.
LV_BRANCH="${LV_BRANCH:-release-1.4/neovim-0.9}"

info "installing LunarVim (branch: $LV_BRANCH)"
warn "if this rejects your Neovim version, retry with:"
warn "  LV_BRANCH=master ./install.sh lunarvim"

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/LunarVim/LunarVim/${LV_BRANCH}/utils/installer/install.sh" \
  -o "$installer"

if bash "$installer" --no-install-dependencies; then
  ok "LunarVim installed"
else
  warn "LunarVim installer failed — see the branch note above"
  exit 1
fi

add_path_line 'export PATH="$HOME/.local/bin:$PATH"'
