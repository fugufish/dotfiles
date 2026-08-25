#!/usr/bin/env bash
#
# WSL integration — clipboard bridge to Windows. A no-op on native Ubuntu.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "WSL integration"

if ! is_wsl; then
  skip "not running under WSL"
  exit 0
fi

ok "WSL detected (${WSL_DISTRO_NAME:-unnamed distro})"

# --- the bridge itself ------------------------------------------------------
# WSLg, not WSL, is what mirrors the Linux clipboard to Windows. With it, the
# ordinary Wayland tools are also the correct Windows-clipboard tools; without
# it there is nothing to bridge and the dispatcher falls back to clip.exe.
if has_wslg; then
  ok "WSLg session present — the Wayland clipboard mirrors to Windows"
else
  warn "no WSLg session (/mnt/wslg missing, or no DISPLAY/WAYLAND_DISPLAY)"
  warn "clipboard will fall back to clip.exe, which mangles non-ASCII text"
fi

# --- backends ---------------------------------------------------------------
# From apt, deliberately: the dispatcher searches /usr/bin before the Homebrew
# prefix, so this keeps the clipboard working even if brew is absent or broken.
# xclip covers the XWayland case and native X11 sessions.
apt_refresh
apt_install wl-clipboard xclip

# --- the hardcoded path in zellij's config ----------------------------------
# zellij's copy_command cannot expand $HOME (KDL has no variables), so the path
# is spelled out. Catch the mismatch here rather than as a silently dead
# clipboard for a different user.
ZELLIJ_CFG="$DOTFILES_ROOT/zellij/.config/zellij/config.kdl"
if [[ -f "$ZELLIJ_CFG" ]]; then
  configured="$(sed -n 's/^copy_command "\(.*\)"/\1/p' "$ZELLIJ_CFG" | tail -1)"
  if [[ -n "$configured" && "$configured" != "$HOME/.local/bin/clipboard-copy" ]]; then
    warn "zellij copy_command points at: $configured"
    warn "but this user's home is $HOME — edit $ZELLIJ_CFG to match"
  fi
fi

# --- prove it, end to end ---------------------------------------------------
# Run the repo copies, not ~/.local/bin: 90-stow.sh has not linked them yet on a
# first run.
COPY="$DOTFILES_ROOT/bin/.local/bin/clipboard-copy"
PASTE="$DOTFILES_ROOT/bin/.local/bin/clipboard-paste"

if [[ -x "$COPY" && -x "$PASTE" ]]; then
  info "testing the clipboard round-trip (this overwrites your clipboard)"
  token="dotfiles-clipboard-check-$$"
  if printf '%s' "$token" | "$COPY" && [[ "$("$PASTE" 2>/dev/null)" == "$token" ]]; then
    ok "clipboard round-trip works — copies reach the Windows clipboard"
  else
    warn "clipboard round-trip failed"
    warn "if this ran outside a WSLg session, WAYLAND_DISPLAY is unset and that"
    warn "is expected; test again from a Ghostty window"
  fi
else
  warn "clipboard dispatcher missing at $COPY"
fi

# --- interop note -----------------------------------------------------------
if grep -qs 'appendWindowsPath\s*=\s*false' /etc/wsl.conf; then
  info "/etc/wsl.conf sets appendWindowsPath=false — Windows binaries are off"
  info "PATH by design; the clipboard scripts call them by absolute path"
fi
