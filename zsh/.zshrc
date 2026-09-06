if [[ ":$FPATH:" != *":/home/fugufish/.zsh/completions:"* ]]; then export FPATH="/home/fugufish/.zsh/completions:$FPATH"; fi
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git rails ruby npm node bundler asdf)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$PATH:$HOME/.cargo/bin"

export EDITOR=nvim

export DENO_INSTALL="/home/fugufish/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
export PATH="/usr/local/bin:$PATH"

# bun completions
[ -s "/home/fugufish/.bun/_bun" ] && source "/home/fugufish/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/erlang/bin:$PATH"
export PATH="/opt/elixir/bin:$PATH"


eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
alias wezterm='flatpak run org.wezfurlong.wezterm'
alias v="nvim"

export DISABLE_AUTO_TITLE=true

export FLYCTL_INSTALL="/home/fugufish/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

. "/home/fugufish/.deno/env"

function cursor {
        /usr/local/bin/cursor.AppImage $@ --no-sandbox
}
export PATH="$HOME/.yarn/bin:$PATH"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export DIP_CURRENT_USER=$(id -u):$(id -g)


# pnpm
export PNPM_HOME="/home/fugufish/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


# Credentials: one secret per file, none of them committed — only the variable
# names live here. On a fresh box none of these files exist, so read each one
# only if it's there rather than letting six `cat` errors spray across startup.
# `$(<file)` is a shell builtin read, so this costs no subprocesses.
# These are exported (unlike the plain assignments they replace) because MCP
# servers, editors and scripts expect to find them in the environment.
for _token_pair in \
  GITHUB_PERSONAL_ACCESS_TOKEN:.github-token \
  OPENAI_API_KEY:.openai-token \
  TIPTAP_PRO_TOKEN:.tiptap-pro-token \
  VERCEL_TOKEN:.vercel-token \
  OPENROUTER_API_KEY:.openrouter-token \
  SHADCN_IO_TOKEN:.shadcn-token
do
  _token_file="$HOME/${_token_pair#*:}"
  if [[ -r "$_token_file" ]]; then
    export "${_token_pair%%:*}=$(<"$_token_file")"
  fi
done
unset _token_pair _token_file

. ${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.zsh

export NODE_OPTIONS=--max_old_space_size=8192

# opencode
export PATH=/home/fugufish/.opencode/bin:$PATH

alias wrangler="pnpm dlx wrangler"
alias m="../../main && git pull"
export PATH="$HOME/.cargo/bin:$PATH"

# ----------------------------------------------------------------------- WSL
# Guarded so this same file still works on a native Ubuntu box. $WSL_DISTRO_NAME
# alone is not a reliable test — it is unset in systemd units and in GUI apps
# launched by WSLg — so fall back to the kernel string.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  export IS_WSL=1

  # Same dispatcher zellij copies through, so the shell and the terminal agree
  # on what "the clipboard" means. Both ends reach the Windows clipboard via
  # WSLg's Wayland bridge.
  alias pbcopy='clipboard-copy'
  alias pbpaste='clipboard-paste'

  # /etc/wsl.conf sets appendWindowsPath=false, which keeps Windows binaries off
  # PATH by design. Spell out the few that are genuinely useful from Linux.
  alias explorer='/mnt/c/Windows/explorer.exe'
fi

# WSL has no browser; ~/.local/bin/xdg-open hands URLs to the Windows shell.
# Set BROWSER too, since many CLIs (gh, cargo doc, bundle open) prefer it.
export BROWSER="$HOME/.local/bin/xdg-open"
