#!/usr/bin/env bash
#
# LazyVim. Depends on the Neovim that 10-asdf.sh installs.
#
# Unlike the LunarVim step this replaces, there is no vendor installer to run:
# LazyVim *is* the config in the nvim stow package, and lazy.nvim bootstraps
# itself on first launch. So this step only has to guarantee the two things the
# config cannot provide for itself — a new enough Neovim, and the CLI tools its
# pickers shell out to — and then warm the plugin cache so the first real launch
# is not a several-minute clone.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "LazyVim"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$HOME/.local/bin:$PATH"

have nvim || die "neovim missing — run ./install.sh asdf first"

NVIM_VERSION="$(nvim --version | head -1 | awk '{print $2}')"
nvim_num="${NVIM_VERSION#v}"
nvim_major="${nvim_num%%.*}"
nvim_rest="${nvim_num#*.}"
nvim_minor="${nvim_rest%%.*}"

# LazyVim tracks current Neovim closely and drops old versions without much
# ceremony. 0.11 is the floor at the time of writing; asdf/.tool-versions pins
# well above it.
if (( nvim_major == 0 && nvim_minor < 11 )); then
  die "LazyVim needs Neovim 0.11+, found $NVIM_VERSION — raise the neovim pin in asdf/.tool-versions"
fi
ok "neovim $NVIM_VERSION"

# Telescope/fzf-lua shell out to these. Neither is fatal, but both are the
# difference between the file pickers working well and working badly, so a
# missing one is a warning rather than a silent omission.
#
# fd is a special case on Debian/Ubuntu: the apt package installs the binary as
# `fdfind` to avoid a name collision, and LazyVim looks for `fd`. Homebrew ships
# it under the right name, which is why brew is preferred here.
for tool in rg fd lazygit; do
  if have "$tool"; then
    ok "$tool at $(command -v "$tool")"
  elif have brew; then
    info "installing $tool"
    brew install "$tool" || warn "brew install $tool failed — LazyVim will degrade, not break"
  else
    warn "$tool missing and no brew to install it with"
  fi
done

# The config has to be in place before the bootstrap can mean anything, and on a
# fresh box 90-stow.sh has not run yet.
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [[ ! -e "$NVIM_CONFIG/init.lua" ]]; then
  info "no config at $NVIM_CONFIG yet — 90-stow.sh links the nvim package"
  info "plugins will bootstrap on the first nvim launch instead"
  exit 0
fi

# Warm the plugin cache. Headless `Lazy! sync` is the documented way to do this
# unattended; the bang makes it non-interactive and it exits on its own.
if [[ -f "$NVIM_CONFIG/lazy-lock.json" ]] \
   && [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim" ]]; then
  skip "lazy.nvim already bootstrapped"
else
  info "bootstrapping plugins (this clones a few dozen repos)"
  if nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3; then
    ok "LazyVim plugins installed"
  else
    warn "plugin bootstrap reported an error — run :Lazy sync inside nvim"
  fi
fi

add_path_line 'export PATH="$HOME/.local/bin:$PATH"'
