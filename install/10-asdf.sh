#!/usr/bin/env bash
#
# asdf + the runtimes pinned in .tool-versions (Node, Ruby, Go, Neovim).

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "asdf and pinned runtimes"

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
[[ -x "$BREW_BIN" ]] && eval "$("$BREW_BIN" shellenv)"

# --- asdf itself ---------------------------------------------------------
# This is asdf >= 0.16, the Go rewrite. There is no asdf.sh to source; the only
# activation needed is putting the shim dir on PATH. Subcommands use the new
# spelling ("asdf plugin list", not "asdf plugin-list").
if have asdf; then
  skip "asdf ($(asdf version 2>/dev/null))"
else
  have brew || die "Homebrew missing — run ./install.sh brew first"
  info "installing asdf via Homebrew"
  brew install asdf
  ok "asdf installed"
fi

ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
export ASDF_DATA_DIR
export PATH="$ASDF_DATA_DIR/shims:$PATH"

add_path_line 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"'

# --- plugins -------------------------------------------------------------
# postgres and python are installed as plugins but deliberately left unpinned
# in .tool-versions; Python comes from Homebrew instead (see 15-python.sh).
PLUGINS=(nodejs ruby golang neovim postgres python)

existing_plugins="$(asdf plugin list 2>/dev/null || true)"
for p in "${PLUGINS[@]}"; do
  if grep -qx "$p" <<<"$existing_plugins"; then
    skip "plugin $p"
  else
    info "adding plugin $p"
    asdf plugin add "$p" && ok "plugin $p"
  fi
done

# --- runtimes ------------------------------------------------------------
# .tool-versions is the single source of truth for versions. It ships in the
# asdf/ stow package, but may not be linked into $HOME yet on a first run, so
# read it from the repo.
TOOL_VERSIONS="$DOTFILES_ROOT/asdf/.tool-versions"
if [[ ! -f "$TOOL_VERSIONS" ]]; then
  warn "no $TOOL_VERSIONS — skipping runtime installs"
  warn "create it, or copy your current one: cp ~/.tool-versions \"$TOOL_VERSIONS\""
  exit 0
fi

installed_list="$(asdf list 2>/dev/null || true)"
while read -r tool version _rest; do
  [[ -z "${tool:-}" || "$tool" == \#* ]] && continue

  # `asdf list <tool>` marks the current version with * and indents entries.
  if asdf list "$tool" 2>/dev/null | sed 's/[* ]//g' | grep -qx "$version"; then
    skip "$tool $version"
    continue
  fi

  info "installing $tool $version (this compiles from source and is slow)"
  if asdf install "$tool" "$version"; then
    ok "$tool $version"
  else
    warn "failed to install $tool $version — continuing"
  fi
done < "$TOOL_VERSIONS"

asdf reshim >/dev/null 2>&1 || true
ok "shims refreshed"

info "node: $(asdf where nodejs 2>/dev/null || echo 'not active')"
