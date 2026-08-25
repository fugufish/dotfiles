#!/usr/bin/env bash
# Shared helpers for all install/NN-*.sh steps.
# Sourced, never executed directly.

set -euo pipefail

# ---------------------------------------------------------------- output ----

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=
fi

step()  { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()  { printf '    %s•%s %s %s(already present, skipping)%s\n' \
            "$C_DIM" "$C_RESET" "$*" "$C_DIM" "$C_RESET"; }
warn()  { printf '    %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '    %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# --------------------------------------------------------------- detection --

# have <cmd> — is this command on PATH?
have() { command -v "$1" >/dev/null 2>&1; }

# dpkg_installed <pkg> — is this .deb installed?
dpkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'
}

# apt_install <pkg>... — install only the packages not already present.
# This is the idempotency workhorse: a re-run with nothing missing is a no-op
# and never touches the network.
apt_install() {
  local pkg missing=()
  for pkg in "$@"; do
    if dpkg_installed "$pkg"; then
      skip "$pkg"
    else
      missing+=("$pkg")
    fi
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  info "installing: ${missing[*]}"
  sudo apt-get install -y -qq "${missing[@]}"
  for pkg in "${missing[@]}"; do ok "$pkg"; done
}

# apt_refresh — update package lists at most once per run.
_APT_REFRESHED=0
apt_refresh() {
  [[ $_APT_REFRESHED -eq 1 ]] && return 0
  info "refreshing apt package lists"
  sudo apt-get update -qq
  _APT_REFRESHED=1
}

# ----------------------------------------------------------------------- wsl --

# is_wsl — are we inside WSL? Tests the kernel string rather than
# $WSL_DISTRO_NAME, which is empty in contexts that matter here: systemd units,
# and GUI apps launched by WSLg (Ghostty is one, and it passes its environment
# down to zellij).
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

# has_wslg — is WSLg's Wayland/X11 bridge present? This, not WSL itself, is what
# mirrors the Linux clipboard to Windows, so clipboard setup keys off this.
has_wslg() {
  is_wsl && [[ -d /mnt/wslg ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]
}

# win_exe <name> — absolute path to a Windows executable, or empty.
# Never rely on PATH for these: /etc/wsl.conf may set appendWindowsPath=false
# (it does on this machine), which keeps clip.exe and powershell.exe off PATH.
win_exe() {
  local name="$1" root
  for root in /mnt/c/Windows/System32 /mnt/c/Windows; do
    [[ -x "$root/$name" ]] && { printf '%s\n' "$root/$name"; return 0; }
  done
  [[ "$name" == powershell.exe ]] &&
    [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]] &&
    { printf '%s\n' /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe; return 0; }
  return 1
}

# ------------------------------------------------------------------ prompts --

# NONINTERACTIVE=1 makes every prompt take its default without blocking,
# so the whole script can run in CI or a container build.
is_interactive() {
  [[ "${NONINTERACTIVE:-0}" != "1" ]] && [[ -t 0 ]]
}

# confirm <question> [default:y|n]
confirm() {
  local q="$1" default="${2:-y}" reply
  if ! is_interactive; then
    info "$q -> $default (non-interactive)"
    [[ "$default" == "y" ]]
    return
  fi
  local hint="[Y/n]"; [[ "$default" == "n" ]] && hint="[y/N]"
  read -r -p "    $q $hint " reply || reply=""
  reply="${reply:-$default}"
  [[ "${reply,,}" == y* ]]
}

# ------------------------------------------------------------------- system --

# shellcheck disable=SC1091
UBUNTU_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
UBUNTU_VERSION="$(. /etc/os-release && echo "${VERSION_ID:-}")"
export UBUNTU_CODENAME UBUNTU_VERSION

# Repo root, regardless of where a step is invoked from.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTFILES_ROOT

# Ask for sudo once up front so later steps don't stall on a password prompt
# in the middle of a download.
require_sudo() {
  sudo -v || die "this step needs sudo"
}

# add_path_line <line> — append a line to ~/.zshrc only if it isn't there yet.
add_path_line() {
  local line="$1" rc="$HOME/.zshrc"
  [[ -f "$rc" ]] || touch "$rc"
  if grep -Fqx "$line" "$rc"; then
    skip "~/.zshrc already contains: $line"
  else
    printf '%s\n' "$line" >> "$rc"
    ok "appended to ~/.zshrc: $line"
  fi
}
