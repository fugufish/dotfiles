#!/usr/bin/env bash
#
# Claude Code CLI and its status line.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "Claude Code"

export PATH="$HOME/.local/bin:$PATH"

if have claude; then
  skip "claude ($(claude --version 2>/dev/null | awk '{print $1}')) at $(command -v claude)"
  info "update in place with: claude update"
else
  info "installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
  have claude || die "claude not on PATH after install — expected ~/.local/bin/claude"
  ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"
fi

add_path_line 'export PATH="$HOME/.local/bin:$PATH"'

info "authenticate on first run: claude"

# --------------------------------------------------------------- status line --

# The script itself is a stow package (claude/.claude/statusline.py), so 90-stow
# symlinks it into place. Only the settings key pointing at it is patched here:
# ~/.claude/settings.json also holds credentials-adjacent machine state, so the
# file is deliberately not tracked in this repo.

STATUSLINE="$HOME/.claude/statusline.py"
SETTINGS="$HOME/.claude/settings.json"

if [[ ! -e "$STATUSLINE" ]]; then
  info "status line not stowed yet — run ./install.sh stow, then re-run this step"
elif ! have /usr/bin/python3; then
  warn "/usr/bin/python3 missing — cannot patch $SETTINGS"
else
  # System python on purpose, here and in the command written below: the status
  # line runs in a bare non-interactive shell where brew's shellenv has not been
  # applied, so `python3` may not resolve at all. Ubuntu always ships this one.
  # The script needs nothing beyond the standard library.
  mkdir -p "$HOME/.claude"

  rc=0
  /usr/bin/python3 - "$SETTINGS" "$STATUSLINE" <<'PY' || rc=$?
import collections, json, os, sys

settings_path, script_path = sys.argv[1], sys.argv[2]
wanted = collections.OrderedDict([
    ("type", "command"),
    ("command", f"/usr/bin/python3 {script_path}"),
    ("padding", 0),
    # Services come and go without a Claude event, so poll for the dots.
    ("refreshInterval", 10),
])

try:
    with open(settings_path) as fh:
        settings = json.load(fh, object_pairs_hook=collections.OrderedDict)
except FileNotFoundError:
    settings = collections.OrderedDict()
except (json.JSONDecodeError, ValueError):
    sys.exit(f"{settings_path} is not valid JSON — refusing to overwrite it")

if settings.get("statusLine") == wanted:
    sys.exit(9)  # already correct; nothing written

settings["statusLine"] = wanted
tmp = settings_path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(settings, fh, indent=2)
    fh.write("\n")
os.replace(tmp, settings_path)  # never leave a half-written settings file
PY

  # 9 is the patcher's "already correct" signal; anything else is a real error.
  if [[ $rc -eq 0 ]]; then
    ok "status line wired into ${SETTINGS/#$HOME/\~}"
  elif [[ $rc -eq 9 ]]; then
    skip "status line already wired"
  else
    die "could not patch $SETTINGS"
  fi
fi
