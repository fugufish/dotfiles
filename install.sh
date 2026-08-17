#!/usr/bin/env bash
#
# Bootstrap an Ubuntu workstation from this dotfiles repo.
#
#   ./install.sh                 run every step, in order
#   ./install.sh docker zellij   run only the named steps
#   ./install.sh --list          show the available steps
#   ./install.sh --dry-run       print what would run, change nothing
#
# Every step is idempotent: it detects what is already installed and skips it,
# so re-running this script is the normal way to apply updates.
#
# Env:
#   NONINTERACTIVE=1   take the default at every prompt (CI / container builds)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS_DIR="$ROOT/install"

# shellcheck source=install/lib/common.sh
source "$STEPS_DIR/lib/common.sh"

DRY_RUN=0
declare -a REQUESTED=()

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,2\} \{0,1\}//'
}

list_steps() {
  local f
  printf '%sAvailable steps:%s\n' "$C_BOLD" "$C_RESET"
  for f in "$STEPS_DIR"/[0-9][0-9]-*.sh; do
    [[ -e "$f" ]] || continue
    local base name desc
    base="$(basename "$f" .sh)"
    name="${base#*-}"
    desc="$(sed -n '3s/^# \{0,1\}//p' "$f")"
    printf '  %-12s %s%s%s\n' "$name" "$C_DIM" "$desc" "$C_RESET"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    -l|--list)    list_steps; exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -*)           die "unknown option: $1" ;;
    *)            REQUESTED+=("$1"); shift ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] && die "run this as your normal user, not root (it uses sudo where needed)"
[[ -r /etc/os-release ]] || die "cannot read /etc/os-release — this script targets Ubuntu"
grep -qi ubuntu /etc/os-release || warn "this is tuned for Ubuntu; proceeding anyway"

# Collect the steps to run, preserving numeric order even when named explicitly.
declare -a TO_RUN=()
for f in "$STEPS_DIR"/[0-9][0-9]-*.sh; do
  [[ -e "$f" ]] || continue
  if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    TO_RUN+=("$f")
  else
    base="$(basename "$f" .sh)"; name="${base#*-}"
    for want in "${REQUESTED[@]}"; do
      [[ "$name" == "$want" || "$base" == "$want" ]] && TO_RUN+=("$f") && break
    done
  fi
done

if [[ ${#TO_RUN[@]} -eq 0 ]]; then
  die "no matching steps for: ${REQUESTED[*]-} (try --list)"
fi

printf '%sUbuntu %s (%s) — %d step(s)%s\n' \
  "$C_BOLD" "$UBUNTU_VERSION" "$UBUNTU_CODENAME" "${#TO_RUN[@]}" "$C_RESET"

if [[ $DRY_RUN -eq 1 ]]; then
  for f in "${TO_RUN[@]}"; do info "would run $(basename "$f")"; done
  exit 0
fi

# One sudo prompt up front rather than a surprise one mid-download.
require_sudo

FAILED=()
for f in "${TO_RUN[@]}"; do
  if bash "$f"; then :; else
    warn "step failed: $(basename "$f")"
    FAILED+=("$(basename "$f")")
  fi
done

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
  printf '%s%d step(s) failed:%s %s\n' "$C_RED" "${#FAILED[@]}" "$C_RESET" "${FAILED[*]}"
  exit 1
fi

printf '%sAll steps complete.%s\n' "$C_GREEN" "$C_RESET"
info "open a new terminal (or: exec zsh) to pick up PATH and group changes"
