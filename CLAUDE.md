# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal dotfiles repo that bootstraps a fresh **Ubuntu** workstation to match the
maintainer's existing environment: Node, Ruby, Python, Docker + Compose, LazyVim,
Ghostty, zellij, git/GitHub CLI, and Claude Code — plus the config files for each.

**Status:** `install.sh` and all `install/` steps exist and are tested. Six stow packages
are populated — `zsh`, `ghostty`, `zellij`, `nvim`, `asdf`, `bin` — `zsh`, `ghostty` and
`zellij` copied **verbatim** from the live machine, so the cruft documented below is still
present in `zsh/.zshrc` and the hardcoded zellij path is still in `ghostty/config`. Still
not packaged: `git/.gitconfig`.

`asdf/.tool-versions` now exists and pins four runtimes — **neovim, nodejs, ruby,
golang**. Until it did, `10-asdf.sh` found no `.tool-versions`, warned, and installed **no
runtimes at all**: that is what left `nvim` missing and the editor step dying with
"neovim missing", and left `node` unresolvable ("No version is set for command node")
despite nodejs 26.7.0 being installed.

**The editor is LazyVim, and it is config rather than an installed program.** LunarVim
was here first and was removed: it is effectively unmaintained, its release branches lag
current Neovim, and on the pinned 0.12.4 its nvim-treesitter died at file open with
`E5113 ... Overriding existing predicate has-ancestor?`.

That swap changes the shape of the install step. There is no vendor installer and no
`lvim`-style shim to detect — LazyVim *is* `nvim/.config/nvim`, and lazy.nvim bootstraps
itself on first launch. So `30-lazyvim.sh` only guarantees what the config cannot: a
Neovim at or above LazyVim's 0.11 floor, the CLI tools its pickers shell out to, and a
warmed plugin cache via headless `Lazy! sync`. If the config is not stowed yet the step
says so and exits 0, because the first real launch will bootstrap anyway.

`fd` is the one dependency with a trap: Ubuntu's apt package installs the binary as
`fdfind` to dodge a name collision, and LazyVim looks for `fd`. Homebrew ships the right
name, so the step prefers brew.

postgres and python remain plugins-without-pins; Python still comes from Homebrew.

## Two conventions drive the whole repo

### 1. GNU stow packages — one directory per tool

Each top-level directory is a *stow package* whose interior mirrors `$HOME` exactly.
Deployment is `stow -t ~ <package>`; there is no custom symlink/backup code anywhere in
this repo, and none should be added.

```
zsh/.zshrc                              -> ~/.zshrc
bin/.local/bin/clipboard-copy           -> ~/.local/bin/clipboard-copy
git/.gitconfig                          -> ~/.gitconfig
ghostty/.config/ghostty/config          -> ~/.config/ghostty/config
zellij/.config/zellij/config.kdl        -> ~/.config/zellij/config.kdl
nvim/.config/nvim/init.lua              -> ~/.config/nvim/init.lua
asdf/.tool-versions                     -> ~/.tool-versions
```

Adding a config file means placing it at its `$HOME`-relative path inside a package —
never editing a link list. `stow -D <pkg>` unlinks, `stow -R <pkg>` restows after a rename.

Stow refuses to link over a pre-existing real file. On a machine that already has configs
(such as the maintainer's current one), installers must move the existing file aside
before stowing; a fresh Ubuntu box won't hit this.

### 2. Numbered, independently runnable installers

`install.sh` is an orchestrator only. Each tool gets `install/NN-<tool>.sh`, run in
numeric order, and `./install.sh <name>` runs a single one.

```
install/lib/common.sh    shared helpers — sourced by every step, never run
install/00-apt.sh        base packages, build toolchain, stow itself
install/05-brew.sh       Homebrew (asdf and Python come from it)
install/10-asdf.sh       asdf + plugins + .tool-versions runtimes
install/15-python.sh     Python + uv, via brew (not asdf)
install/20-docker.sh     engine, compose plugin, docker group
install/25-zellij.sh     rust/cargo + zellij (must precede 40 — Ghostty launches it)
install/30-lazyvim.sh    LazyVim deps + plugin bootstrap (depends on 10 — needs neovim)
install/40-ghostty.sh    terminal, from ppa:mkasberg/ghostty-ubuntu
install/45-wsl.sh        WSL clipboard bridge (no-op off WSL)
install/50-git-gh.sh     git, gh, and the GitHub PAT / OAuth walkthrough
install/55-ohmyzsh.sh    oh-my-zsh (must precede 90 — the stowed .zshrc sources it)
install/60-claude.sh     Claude Code CLI
install/90-stow.sh       stow every package (runs last)
```

`./install.sh --list` prints this list with descriptions, read from each file's
third line — so keep that line a one-line summary. `--dry-run` shows what would run.

Idempotency comes from `common.sh`: `have`, `dpkg_installed`, `apt_install` (which
installs only what's missing), and `add_path_line` (which appends to `~/.zshrc` only on an
exact-line miss). **Detect by capability, not by installer.** A check like
`brew list --formula uv` reports false for a working non-brew `uv` and installs a second
copy that shadows the first; `have uv` is the correct test. Use an installer-specific
check only where a generic one can't work — `15-python.sh` must ask brew about `python`
because Ubuntu always ships a system `python3`, and `25-zellij.sh` tests
`~/.cargo/bin/zellij` by path because the Ghostty config hardcodes that path.

Every installer must be **idempotent** — re-running the full script on a configured
machine is the normal way to apply updates, so guard each step with a
"already installed?" check rather than assuming a clean box.

Ordering is load-bearing in three places: `30-lazyvim.sh` needs the neovim that
`10-asdf.sh` installs, `40-ghostty.sh` is useless without the zellij from `25-zellij.sh`
(Ghostty launches it as its shell command), and `90-stow.sh` runs last so configs land
after the tools that read them exist.

## Environment facts that are easy to get wrong

These were verified on the maintainer's current machine and are the target the installers
must reproduce.

**asdf is the version manager, and it's the 0.18 Go rewrite.** This is not the old shell
function. There is no `asdf.sh` to source; activation is putting the shim dir on `PATH`:

```sh
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
```

Subcommands are the new spelling — `asdf plugin list`, `asdf plugin add`, *not*
`asdf plugin-list`. Installed plugins: golang, neovim, nodejs, postgres, python, ruby.
asdf itself is **installed via Homebrew** (`/home/linuxbrew/.linuxbrew/bin/asdf`), which is
why `05-brew.sh` must run before `10-asdf.sh`.

**`.tool-versions` pins only four of them** — neovim, nodejs, ruby, golang. The postgres
and python plugins are installed but unpinned, which is deliberate, not an oversight:

**Python does not come from asdf.** `python3` resolves to
`/home/linuxbrew/.linuxbrew/bin/python3` (3.14.5), and `pip3` likewise. **Homebrew is part
of this Ubuntu setup** — `.zshrc` runs `brew shellenv` — so the Python installer step
should go through brew, not add a python entry to `.tool-versions`. Node and Ruby *do*
come from asdf shims. Don't "fix" this inconsistency by unifying it without asking.

**Ghostty does not launch a shell.** Its config sets `command` to zellij, so every window
starts a zellij session that then spawns zsh:

```
command = /home/fugufish/.cargo/bin/zellij
working-directory = inherit
```

Two consequences: zellij is a real dependency of the Ghostty step, and that absolute path
is machine-specific — it needs to become `$HOME`-relative or templated before this config
is portable.

**This machine is WSL, and the clipboard chain is three layers deep.** WSLg's bridge works
in both directions on its own — `wl-copy` reaches the Windows clipboard and `wl-paste`
reads it, verified. What breaks is the layer above: because Ghostty launches zellij,
**zellij owns the terminal and captures mouse selection**, so Ghostty's own copy never
sees it. With no `copy_command`, zellij falls back to OSC 52, which does not survive the
Ghostty → zellij nesting, and copies silently go nowhere.

So `copy_command` in `config.kdl` is load-bearing, and it points at
`~/.local/bin/clipboard-copy` (the `bin` package) rather than naming a backend. Two
reasons, both easy to get wrong:

- **KDL has no conditionals**, so WSL-vs-native detection has to happen at runtime, in a
  script. The dispatcher tries Wayland, then X11, then `clip.exe`.
- **Ghostty launches zellij with the bare system PATH** — no brew, no `~/.cargo/bin`, no
  `~/.local/bin`. Anything zellij shells out to must be an absolute path, and the
  dispatcher itself resolves its backends absolutely for the same reason. This is the
  same constraint that forces the absolute zellij path in the Ghostty config.

The dispatcher sends every backend's stdout to `/dev/null` on purpose: `wl-copy` and
`xclip` fork and stay resident to serve the selection, and a resident child holding the
caller's stdout makes `$(... | clipboard-copy)` hang forever.

`/etc/wsl.conf` sets `appendWindowsPath=false`, so `clip.exe` and `powershell.exe` are
**not on PATH**. Call them by absolute path (`win_exe` in `common.sh` does this).

**zellij is a heavily customized, load-bearing config — not a default install.**
`~/.config/zellij/config.kdl` is ~21KB and diverges from stock in ways that will look
broken if reproduced only partially:

- `keybinds clear-defaults=true` — the entire keymap is hand-defined. A partial or
  reset config leaves the terminal with almost no working bindings.
- `default_mode "locked"` — sessions start locked, so normal zellij prefixes do nothing
  until unlocked. This is intentional; don't "fix" it.
- A custom `ghostty-dark` theme is defined inline in the `themes` block and selected via
  `theme "ghostty-dark"`. **The zellij and Ghostty configs are colour-coupled** — changing
  one without the other breaks the matched look.
- That theme uses the **zellij >= 0.43 Styling format**, so the version matters. The
  maintainer runs **0.44.3**; `25-zellij.sh` should pin rather than install latest, and an
  older zellij will fail to parse the themes block.

Install path: the binary lives at `~/.cargo/bin/zellij`, i.e. `cargo install zellij`, which
implies a Rust toolchain. Homebrew is already part of this setup and `brew install zellij`
would avoid pulling in Rust — but it would move the binary and break the absolute path in
the Ghostty config, so change both together or not at all.

Three stale backups sit next to the live config (`config.kdl.bak`,
`config.kdl.pre-contrast-fix`, `config.kdl.pre-ghostty-dark`). Only `config.kdl` belongs in
the stow package; the rest should be gitignored.

**git authenticates through `gh`, not a stored credential.** `.gitconfig` sets
`credential.https://github.com.helper` to `!/usr/bin/gh auth git-credential`. So
`50-git-gh.sh` must install `gh` *and* run `gh auth login`, or every push on a new box
fails. The empty `helper = ` line before it is intentional — it clears inherited helpers.

**LazyVim config is the starter template plus one deliberate change.**
`lua/config/options.lua` pins `vim.g.clipboard` to the `clipboard-copy`/`clipboard-paste`
dispatcher instead of letting Neovim autodetect a tool through `$PATH` — zellij's
`EditScrollback` launches the editor with the server's bare PATH, which has no linuxbrew
and therefore no `wl-copy`. `lua/config/lazy.lua` also sets `rocks = { enabled = false }`,
without which `:checkhealth lazy` fails hard on a missing hererocks luarocks. Commit
`lazy-lock.json` alongside the config so plugin versions reproduce.

**Docker needs the group, and it's a re-login.** The maintainer's user is in the `docker`
group with Compose v2 as a plugin (`docker compose`, not `docker-compose`). Group
membership doesn't apply to the current shell — the installer says so rather than
appearing to have failed.

**This machine is Ubuntu 26.04 (`resolute`), which is ahead of several upstream repos.**
Docker publishes no `resolute` suite, so the installed `docker-ce` is the `noble` build and
the dist-upgrade left `/etc/apt/sources.list.d/docker.list.save` disabled. `20-docker.sh`
probes for the codename's `Release` file and falls back to `noble` rather than adding a
repo that 404s. Expect the same class of problem for other third-party repos on this
release. Ghostty is unaffected — its PPA does publish for `resolute`.

## Known cruft to clean up when porting `.zshrc`

The live `.zshrc` (138 lines, oh-my-zsh, `robbyrussell` theme,
`plugins=(git rails ruby npm node bundler asdf)`) has accumulated duplication that should
not be copied in verbatim:

- `export PATH="$PATH:$HOME/.rvm/bin"` appears **four times** (lines 109, 142, 145, 148),
  and RVM is not installed — Ruby comes from asdf. Drop all four.
- Many `PATH` prepends are absolute (`/home/fugufish/...`) rather than `$HOME`-relative,
  which breaks portability to another user or machine.

**Credentials are read from files, and the assignments are missing `export`.** Lines
167–172 do:

```sh
GITHUB_PERSONAL_ACCESS_TOKEN=$(cat /home/fugufish/.github-token)
OPENAI_API_KEY=$(cat /home/fugufish/.openai-token)
# ...and .tiptap-pro-token, .vercel-token, .openrouter-token, .shadcn-token
```

Two consequences worth knowing before changing anything here:

1. No secret value is *in* `.zshrc`, which is why it is safe to commit. The six token
   files themselves must never enter the repo — `.gitignore` denies `*-token`, `*.token`,
   and each name explicitly.
2. These are plain shell assignments, **not** `export`s, so the variables are not in the
   environment of any child process. Any tool expecting `OPENAI_API_KEY` in its env will
   not see it. That looks unintended, but it is the maintainer's call — ask before adding
   `export`.

On a fresh machine none of those six files exist, so every new shell prints six
`cat: No such file or directory` errors. Guard the reads or create the files during setup.

## Verifying a change

There is no test suite. Note that neither `stow` nor `shellcheck` is installed on the
maintainer's machine yet — `00-apt.sh` is responsible for stow, and shellcheck is a
development dependency you may need to `apt install` before the first command below works.
The meaningful checks are real ones:

```sh
# Lint every installer before running anything
shellcheck install.sh install/*.sh

# Preview what stow would link, without touching $HOME
stow -n -v -t ~ <package>

# Prove idempotency — the second run must be clean and change nothing
./install.sh && ./install.sh

# Verify the toolchain resolves to the intended providers
command -v node ruby   # -> ~/.asdf/shims/*
command -v python3     # -> /home/linuxbrew/.linuxbrew/bin/python3
command -v zellij      # -> ~/.cargo/bin/zellij (matches the path in ghostty/config)
docker compose version

# Parse-check the zellij config after any edit — catches themes-block format errors
zellij setup --check   # want: [CONFIG FILE]: Well defined.
```

Test full runs in a container (`docker run -it ubuntu:24.04`), not on the live machine —
`90-stow.sh` writes into `$HOME`.
