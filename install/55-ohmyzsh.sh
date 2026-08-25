#!/usr/bin/env bash
#
# oh-my-zsh. The stowed .zshrc sources it, so this must run before 90-stow.sh.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "oh-my-zsh"

OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"

# Detect by capability (the directory), not by installer: oh-my-zsh has no
# binary on PATH, and `have omz` would be false for a perfectly good install.
if [[ -d "$OMZ_DIR" ]]; then
  skip "oh-my-zsh ($OMZ_DIR)"
else
  apt_install zsh git curl

  info "installing oh-my-zsh"
  # --keep-zshrc is load-bearing, not a preference. Without it the installer
  # overwrites ~/.zshrc with its own template — and on this setup ~/.zshrc is
  # the stow symlink into this repo, so the default behaviour would replace a
  # tracked config with boilerplate. RUNZSH=no stops it dropping into an
  # interactive zsh and stalling the rest of install.sh.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc

  [[ -d "$OMZ_DIR" ]] || die "installer finished but $OMZ_DIR is missing"
  ok "oh-my-zsh installed"
fi

# --- plugins the .zshrc asks for --------------------------------------------
# plugins=(git rails ruby npm node bundler asdf) are all bundled with oh-my-zsh,
# so nothing to clone — but a missing one fails silently at shell startup, which
# is worth catching here instead of wondering why an alias vanished.
missing=()
for p in git rails ruby npm node bundler asdf; do
  [[ -d "$OMZ_DIR/plugins/$p" ]] || missing+=("$p")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  warn "plugins named in .zshrc but not present: ${missing[*]}"
else
  ok "all plugins named in .zshrc are present"
fi

# --- login shell ------------------------------------------------------------
if [[ "${SHELL:-}" == *zsh ]]; then
  ok "login shell is already zsh"
elif confirm "Make zsh your login shell?" y; then
  if chsh -s "$(command -v zsh)"; then
    ok "login shell set to zsh (takes effect on next login)"
  else
    warn "chsh failed — set it manually: chsh -s $(command -v zsh)"
  fi
fi
