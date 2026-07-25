# Sourced by zsh/config.zsh after shell/utils.sh (provides `exists`)

export ZSH=$HOME/.oh-my-zsh

# PATH entry is added by dirs_to_prepend below, which skips it if Volta is absent
export VOLTA_HOME="$HOME/.volta"

# Bun (if installed via curl)
if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"

  # bun completions — via fpath, not source: sourcing _bun runs a second
  # compinit before oh-my-zsh's, doubling completion-dump rebuilds
  [ -s "$BUN_INSTALL/_bun" ] && fpath=("$BUN_INSTALL" $fpath)

fi

# Initialize Homebrew if not already in PATH
if ! exists brew; then
  # Apple Silicon
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  # Intel Mac
  [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
  # Linux
  [ -x "$HOME/.linuxbrew/bin/brew" ] && eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

# Directories to be prepended to $PATH
declare -a dirs_to_prepend
dirs_to_prepend=(
  "$VOLTA_HOME/bin"
  "/usr/local/sbin"
  "/usr/local/git/bin"
  "$HOME/bin" # stow links the repo's stow/bin scripts here
  "$HOME/.yarn/bin"
  "$HOME/.config/yarn/global/node_modules/.bin"
)

if exists brew; then
  # ponytail: $HOMEBREW_PREFIX avoids ~25ms per `brew --prefix` fork at startup
  : "${HOMEBREW_PREFIX:=$(brew --prefix)}"
  dirs_to_prepend+=(
    "$HOMEBREW_PREFIX/opt/ruby/bin"
    "$HOMEBREW_PREFIX/share/npm/bin" # npm-installed package bin
  )
fi

# Build the prefix in one pass, then prepend once: keeps array order as priority
# order (first listed wins) and lets ~/bin shadow system tools, which is the point.
prefix=""
for dir in "${dirs_to_prepend[@]}"; do
  [ -d "$dir" ] && prefix+="$dir:"
done
PATH="$prefix$PATH"

unset dirs_to_prepend prefix dir

# ┌─ TOGGLE: GNU coreutils vs macOS BSD ────────────────────────────────────┐
# │ true  → brew's gnubin wins: date, stat, readlink, cp, du, head… are GNU │
# │         (GNU `date -d`/`stat -c`/`readlink -f` work; BSD flags break)   │
# │ false → macOS BSD tools stay first. This is the default because         │
# │         oh-my-zsh aliases `ls='ls -G'` on darwin, and under GNU ls      │
# │         `-G` means --no-group: you lose colours and the group column.   │
# │ Flip below, or per-shell: GNU_COREUTILS_FIRST=true exec zsh             │
# │ Note: GNU sed is NOT here — that's the gnu-sed formula, `gsed`.         │
# └─────────────────────────────────────────────────────────────────────────┘
: "${GNU_COREUTILS_FIRST:=false}"
GNUBIN="$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin"
if [ -n "$HOMEBREW_PREFIX" ] && [ -d "$GNUBIN" ]; then
  if [ "$GNU_COREUTILS_FIRST" = true ]; then
    PATH="$GNUBIN:$PATH"
  else
    PATH="$PATH:$GNUBIN"
  fi
fi
unset GNUBIN

export PATH

# Default to Vim
export EDITOR="vim"

# Prefer British English and use UTF-8
export LC_ALL="en_GB.UTF-8"
export LANG="en_GB.UTF-8"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

export TERM=xterm-256color

# LS colors, made with http://geoff.greer.fm/lscolors/
export LSCOLORS="exfxcxdxbxegedabagacad"
export LS_COLORS='di=34;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=34;46:cd=34;43:su=0;41:sg=0;46:tw=0;42:ow=0;43:'
export GREP_COLOR='1;33'
