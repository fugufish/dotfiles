#!/usr/bin/env python3
"""Claude Code status line.

Line 1: model, cwd/branch, context-window usage, 5-hour and weekly rate-limit usage.
Line 2+: one cell per dev service in this checkout, coloured by whether the port
        is listening. The URL is shown in full so the terminal's own matcher
        linkifies it, and is wrapped in an OSC 8 hyperlink as well.

Ports come from the checkout's own apps/web/.env* files, so a git worktree on a
non-zero slot reports its own ports rather than slot 0's.

Env knobs:
  CC_STATUSLINE_COMPACT=1    show `name:port` instead of the full URL
  CC_STATUSLINE_COLUMNS=N    width to wrap service cells at (default 110)
  CC_STATUSLINE_NO_LINKS=1   emit plain text instead of OSC 8 hyperlinks
  CC_STATUSLINE_NO_COLOR=1   emit no ANSI colour (NO_COLOR is honoured too)
"""

import json
import os
import re
import sys
import time

# ---------------------------------------------------------------- formatting

NO_COLOR = bool(os.environ.get("NO_COLOR") or os.environ.get("CC_STATUSLINE_NO_COLOR"))
LINKS = not os.environ.get("CC_STATUSLINE_NO_LINKS")
COMPACT = bool(os.environ.get("CC_STATUSLINE_COMPACT"))

SEP_WIDTH = 2  # two spaces between service cells
try:
    # stdout is a pipe here, so COLUMNS is the only hint available.
    COLUMNS = max(40, int(os.environ.get("CC_STATUSLINE_COLUMNS") or 110))
except ValueError:
    COLUMNS = 110

DIM = 244
GREY = 240
SEP_COLOR = 238


def c(text, color, bold=False):
    if NO_COLOR:
        return text
    prefix = "\x1b[1m" if bold else ""
    return f"{prefix}\x1b[38;5;{color}m{text}\x1b[0m"


def link(text, url):
    """OSC 8 hyperlink, BEL-terminated.

    Claude Code sanitises any escape in a status line that is neither an SGR
    colour code nor a BEL-terminated OSC 8, so the ST form is not an option
    here. Terminals without OSC 8 support render just `text`.
    """
    if not LINKS or NO_COLOR:
        return text
    return f"\x1b]8;;{url}\x07{text}\x1b]8;;\x07"


def heat(pct):
    """Colour for a 0-100 utilisation figure."""
    if pct < 50:
        return 114  # green
    if pct < 75:
        return 179  # yellow
    if pct < 90:
        return 215  # orange
    return 203  # red


def bar(pct, width=8):
    filled = max(0, min(width, round(pct / 100 * width)))
    return c("█" * filled, heat(pct)) + c("░" * (width - filled), SEP_COLOR)


def compact(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M".replace(".0M", "M")
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)


def until(epoch):
    """`resets_at` -> a short countdown like 2h14m / 4d3h / 45m."""
    if not epoch:
        return None
    if epoch > 1e11:  # milliseconds
        epoch /= 1000
    secs = int(epoch - time.time())
    if secs <= 0:
        return None
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return f"{d}d{h}h"
    if h:
        return f"{h}h{m:02d}m"
    return f"{m}m"


# ------------------------------------------------------------------ services

SUPABASE_API_BASE = 54321
SUPABASE_BLOCK = 10
WEB_PORT_BASE = 3000
# apps/dev-tool follows the slot layout now (tooling/.../slots.mjs). It reads
# DEV_TOOL_PORT from the managed env block, so prefer that and only fall back
# to the base. 3010 is not a dev-tool port at all any more - it is slot 10's
# web port.
DEV_TOOL_PORT_BASE = 3020

ENV_LINE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$")


def listening_ports():
    """Ports in LISTEN state, read straight from /proc (no connect probes)."""
    ports = set()
    for path in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(path) as fh:
                next(fh, None)
                for line in fh:
                    cols = line.split()
                    if len(cols) > 3 and cols[3] == "0A":
                        ports.add(int(cols[1].rsplit(":", 1)[1], 16))
        except (OSError, ValueError):
            continue
    return ports


def find_root(start):
    """Nearest ancestor that looks like this monorepo (or any git checkout)."""
    path = os.path.abspath(start)
    fallback = None
    while True:
        if os.path.exists(os.path.join(path, "apps/web/supabase/config.toml")):
            return path
        if fallback is None and os.path.exists(os.path.join(path, ".git")):
            fallback = path
        parent = os.path.dirname(path)
        if parent == path:
            return fallback
        path = parent


def read_env(root):
    """Merge apps/web/.env then .env.local, exactly as the Supabase CLI does."""
    env = {}
    for name in (".env", ".env.local"):
        try:
            with open(os.path.join(root, "apps/web", name)) as fh:
                for line in fh:
                    if not line.strip() or line.lstrip().startswith("#"):
                        continue
                    match = ENV_LINE.match(line)
                    if match:
                        env[match.group(1)] = match.group(2).strip("'\"")
        except OSError:
            continue
    return env


def port(env, key):
    try:
        return int(env[key])
    except (KeyError, ValueError):
        return None


def services(root):
    """[(name, port, url or None)] for this checkout, in display order."""
    if not root:
        return []
    env = read_env(root)
    api = port(env, "SUPABASE_API_PORT")
    if api is None:
        return []

    # The whole stack is the default block shifted by ten per worktree slot.
    slot = (api - SUPABASE_API_BASE) // SUPABASE_BLOCK
    if not 0 <= slot <= 19:
        slot = 0
    web = WEB_PORT_BASE + slot

    found = [("web", web, f"http://localhost:{web}")]
    for name, key, scheme in (
        ("api", "SUPABASE_API_PORT", "http"),
        ("studio", "SUPABASE_STUDIO_PORT", "http"),
        ("mail", "SUPABASE_SMTP_WEB_PORT", "http"),
        ("db", "SUPABASE_DB_PORT", None),
    ):
        value = port(env, key)
        if value:
            found.append((name, value, f"{scheme}://127.0.0.1:{value}" if scheme else None))

    if os.path.isdir(os.path.join(root, "apps/dev-tool")):
        dev_tool = port(env, "DEV_TOOL_PORT") or DEV_TOOL_PORT_BASE + slot
        found.append(("devtool", dev_tool, f"http://localhost:{dev_tool}"))
    return found


def services_lines(root):
    """Service cells, wrapped into rows that fit the terminal.

    The visible text is the full `http://host:port` URL on purpose. Every
    terminal linkifies a bare URL with its own matcher, whereas OSC 8 only
    works where the emulator supports it - and this one reports a plain
    `xterm-256color` with no TERM_PROGRAM, which is the profile where it
    typically does not. The OSC 8 wrapper is kept as well, so terminals that
    do support it get a proper link rather than a heuristic match.

    Set CC_STATUSLINE_COMPACT=1 for the narrower `name:port` form instead.
    """
    found = services(root)
    if not found:
        return []

    live = listening_ports()
    cells = []
    for name, value, url in found:
        up = value in live
        dot = c("●", 114) if up else c("○", GREY)
        # Without a scheme a terminal will not auto-detect it, so unlinkable
        # services (postgres) stay in the short form regardless of mode.
        label = f"{name}:{value}" if (COMPACT or not url) else f"{name} {url}"
        width = len(label) + 2  # dot + space
        text = c(label, 252) if up else c(label, GREY)
        cells.append((f"{dot} {link(text, url) if url else text}", width))

    rows, row, used = [], [], 0
    for rendered, width in cells:
        if row and used + SEP_WIDTH + width > COLUMNS:
            rows.append("  ".join(row))
            row, used = [], 0
        row.append(rendered)
        used += width + (SEP_WIDTH if used else 0)
    if row:
        rows.append("  ".join(row))
    return rows


# --------------------------------------------------------------------- line 1


def branch_of(root, cwd):
    """Read HEAD directly - a `git` subprocess is too slow for every render."""
    git = os.path.join(root or cwd, ".git")
    try:
        if os.path.isfile(git):  # worktree: ".git" is a pointer file
            with open(git) as fh:
                git = fh.read().split(":", 1)[1].strip()
        with open(os.path.join(git, "HEAD")) as fh:
            head = fh.read().strip()
    except (OSError, IndexError):
        return None
    if head.startswith("ref: refs/heads/"):
        return head[len("ref: refs/heads/"):]
    return head[:7] or None


def pretty_dir(cwd, root):
    label = os.path.basename(cwd.rstrip("/")) or cwd
    if root and os.path.basename(root) != label:
        return f"{os.path.basename(root)}/{label}"
    return label


def usage_cell(label, window):
    if not isinstance(window, dict):
        return None
    pct = window.get("used_percentage")
    if pct is None:
        return None
    pct = max(0.0, min(100.0, float(pct)))
    cell = f"{c(label, DIM)} {c(f'{pct:.0f}%', heat(pct), bold=pct >= 90)}"
    left = until(window.get("resets_at"))
    return f"{cell} {c('↻' + left, SEP_COLOR)}" if left else cell


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        data = {}

    workspace = data.get("workspace") or {}
    cwd = workspace.get("current_dir") or data.get("cwd") or os.getcwd()
    root = find_root(cwd)

    parts = []

    model = (data.get("model") or {}).get("display_name")
    if model:
        parts.append(c(model, 110, bold=True))

    location = c(pretty_dir(cwd, root), 252)
    branch = branch_of(root, cwd)
    if branch:
        location += " " + c(f"⎇ {branch}", 108)
    parts.append(location)

    window = data.get("context_window") or {}
    used, total = window.get("used_tokens"), window.get("max_tokens")
    if used is not None and total:
        pct = max(0.0, min(100.0, used / total * 100))
        parts.append(
            f"{c('ctx', DIM)} {bar(pct)} {c(f'{pct:.0f}%', heat(pct))} "
            f"{c(f'{compact(used)}/{compact(total)}', SEP_COLOR)}"
        )

    limits = data.get("rate_limits") or {}
    for label, key in (("5h", "five_hour"), ("wk", "seven_day")):
        cell = usage_cell(label, limits.get(key))
        if cell:
            parts.append(cell)

    lines = [c(" │ ", SEP_COLOR).join(parts)]
    lines.extend(services_lines(root))
    sys.stdout.write("\n".join(lines))


if __name__ == "__main__":
    main()
