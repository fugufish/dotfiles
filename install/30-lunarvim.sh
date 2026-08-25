#!/usr/bin/env bash
#
# LunarVim. Depends on the Neovim that 10-asdf.sh installs.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "LunarVim"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$HOME/.local/bin:$PATH"

# Detect a *complete* install, not just the shim. LunarVim writes
# ~/.local/bin/lvim before it installs plugins, and that shim simply execs nvim,
# so both `have lvim` and `lvim --version` succeed on a half-finished install
# and would make this step skip a repair it needs to do. lazy.nvim only exists
# once the plugin bootstrap actually ran.
LV_LAZY="$HOME/.local/share/lunarvim/site/pack/lazy/opt/lazy.nvim"
if have lvim && [[ -d "$LV_LAZY" ]]; then
  skip "lvim at $(command -v lvim)"
  exit 0
elif have lvim; then
  warn "found an incomplete LunarVim (shim present, plugins missing) — reinstalling"
  rm -rf "$HOME/.local/share/lunarvim" "$HOME/.local/bin/lvim"
fi

have nvim || die "neovim missing — run ./install.sh asdf first"

NVIM_VERSION="$(nvim --version | head -1 | awk '{print $2}')"
ok "neovim $NVIM_VERSION"

# LunarVim needs Neovim 0.10 or newer, and the branch name is actively
# misleading about it: the branch called release-1.4/neovim-0.9 gates its shell
# installer on has("nvim-0.9"), then refuses at the Lazy setup step with
# "Lunarvim requires v0.10+". Trusting the branch name and pinning neovim to
# 0.9.x produces an install that gets as far as writing the lvim shim and then
# dies. Check the real requirement here, before anything is written.
nvim_num="${NVIM_VERSION#v}"
nvim_major="${nvim_num%%.*}"
nvim_rest="${nvim_num#*.}"
nvim_minor="${nvim_rest%%.*}"

if (( nvim_major == 0 && nvim_minor < 10 )); then
  die "LunarVim needs Neovim 0.10+, found $NVIM_VERSION — raise the neovim pin in asdf/.tool-versions"
fi
ok "neovim $NVIM_VERSION satisfies LunarVim's 0.10+ requirement"

# LunarVim's installer wants these at runtime.
#
# Detect by capability, not by installer: on this setup Python and pip come from
# Homebrew, so `apt_install python3-pip` would report the deb missing and install
# a second, apt-provided pip that shadows the working one. `have pip3` is the
# correct test, and it also keeps this step from needing sudo at all on a
# machine that is already set up.
if have pip3; then
  ok "pip3 $(pip3 --version 2>/dev/null | awk '{print $2}') at $(command -v pip3)"
else
  apt_install python3-pip
fi
if have npm; then
  ok "npm $(npm --version)"
else
  warn "npm missing — LunarVim's LSP installs will fail; run ./install.sh asdf"
fi

# LunarVim's release branches target specific Neovim versions and lag behind
# current Neovim. Override with LV_BRANCH if the default refuses to install.
LV_BRANCH="${LV_BRANCH:-release-1.4/neovim-0.9}"

# Pin every install path explicitly. LunarVim otherwise derives them from
# $XDG_*, so where it lands depends on the environment the step happens to run
# in — and the config dir in particular has to be predictable, see below.
export LUNARVIM_RUNTIME_DIR="${LUNARVIM_RUNTIME_DIR:-$HOME/.local/share/lunarvim}"
export LUNARVIM_CONFIG_DIR="${LUNARVIM_CONFIG_DIR:-$HOME/.config/lvim}"
export LUNARVIM_CACHE_DIR="${LUNARVIM_CACHE_DIR:-$HOME/.cache/lvim}"
export LUNARVIM_BASE_DIR="${LUNARVIM_BASE_DIR:-$LUNARVIM_RUNTIME_DIR/lvim}"

# $LUNARVIM_CONFIG_DIR is also the lvim stow package's target, so the two can
# collide in both directions:
#
#   - Already stowed (this machine): the dir is a symlink into this repo, so the
#     installer writes config.lua straight into the repo. That is the intended
#     end state, but it means an install can dirty your working tree.
#   - Fresh box (30 runs before 90): the installer creates real files, and
#     90-stow.sh then hits a conflict and offers to back them up.
#
# Neither case is a failure; both are confusing when unannounced.
if [[ -L "$LUNARVIM_CONFIG_DIR" ]]; then
  info "$LUNARVIM_CONFIG_DIR is a symlink into $(readlink -f "$LUNARVIM_CONFIG_DIR")"
  info "LunarVim will write its config there — expect repo changes"
elif [[ -e "$LUNARVIM_CONFIG_DIR" ]]; then
  info "$LUNARVIM_CONFIG_DIR exists as real files — 90-stow.sh will offer to back it up"
fi

info "installing LunarVim (branch: $LV_BRANCH)"
info "runtime: $LUNARVIM_RUNTIME_DIR"
info "config:  $LUNARVIM_CONFIG_DIR"
warn "if this rejects your Neovim version, retry with:"
warn "  LV_BRANCH=master ./install.sh lunarvim"

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/LunarVim/LunarVim/${LV_BRANCH}/utils/installer/install.sh" \
  -o "$installer"

# LunarVim's own confirm() calls `read -p`, so an unattended run blocks forever
# on its prompt. Honour this repo's NONINTERACTIVE contract by answering yes for
# it, and keep the prompts when a human is actually watching.
LV_ARGS=(--no-install-dependencies)
is_interactive || LV_ARGS+=(--yes)

if bash "$installer" "${LV_ARGS[@]}"; then
  ok "LunarVim installed"
else
  # The installer also exits non-zero for a cosmetic reason: its last step
  # verifies every plugin against a pinned snapshot and fails on any drift
  # ("mismatch at [indent-blankline.nvim]: expected [...], got [...]") even
  # though the install completed and works. Tell that apart from a real failure
  # by asking whether the plugin bootstrap actually produced lazy.nvim.
  if [[ -d "$LV_LAZY" ]]; then
    warn "LunarVim installed, but its plugin snapshot check reported drift"
    warn "run :Lazy sync the first time you start lvim"
  else
    warn "LunarVim installer failed — see the branch note above"
    exit 1
  fi
fi

add_path_line 'export PATH="$HOME/.local/bin:$PATH"'
