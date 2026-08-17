#!/usr/bin/env bash
#
# Symlink every stow package into $HOME. Runs last.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Stowing dotfiles"

have stow || die "stow missing — run ./install.sh apt first"

cd "$DOTFILES_ROOT"

# A stow package is any top-level dir that isn't repo machinery.
mapfile -t PACKAGES < <(
  find . -maxdepth 1 -mindepth 1 -type d \
    -not -name '.git' -not -name 'install' -not -name '.github' \
    -printf '%f\n' | sort
)

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  warn "no stow packages found in $DOTFILES_ROOT"
  info "a package is a dir mirroring \$HOME, e.g. zsh/.zshrc or ghostty/.config/ghostty/config"
  exit 0
fi

info "packages: ${PACKAGES[*]}"

BACKUP_DIR="$HOME/.dotfiles-backup"

for pkg in "${PACKAGES[@]}"; do
  # Dry run first: stow refuses to clobber a real file, and on a machine that
  # already has configs that is the common case rather than the exception.
  if stow -n -t "$HOME" "$pkg" >/dev/null 2>&1; then
    stow -t "$HOME" "$pkg"
    ok "stowed $pkg"
    continue
  fi

  warn "$pkg conflicts with existing files in \$HOME"
  conflicts="$(stow -n -t "$HOME" "$pkg" 2>&1 | grep -oP '(?<=over existing target )\S+' || true)"

  if [[ -z "$conflicts" ]]; then
    warn "could not parse the conflict; run manually: stow -n -v -t ~ $pkg"
    continue
  fi

  echo "$conflicts" | sed 's/^/        /'

  if confirm "Back these up to $BACKUP_DIR and stow $pkg?" n; then
    while read -r rel; do
      [[ -z "$rel" ]] && continue
      src="$HOME/$rel"
      [[ -e "$src" ]] || continue
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      mv "$src" "$BACKUP_DIR/$rel"
      info "backed up $rel"
    done <<<"$conflicts"

    stow -t "$HOME" "$pkg" && ok "stowed $pkg (originals in $BACKUP_DIR)"
  else
    warn "skipped $pkg"
  fi
done

echo
info "verify a package with: stow -n -v -t ~ <package>"
info "undo one with:         stow -D -t ~ <package>"
