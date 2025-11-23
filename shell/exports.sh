source $DOTFILES_DIR/scripts/vars.sh
source $DOTFILES_DIR/shell/utils.sh

export ZSH=$HOME/.oh-my-zsh

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Bun (if installed via curl)
if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"

  # bun completions
  [ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

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
  "$DOTFILES_DIR/bin"
  "$HOME/bin"
  "$HOME/.yarn/bin"
  "$HOME/.config/yarn/global/node_modules/.bin"
)

if exists brew; then
  dirs_to_prepend+=(
    "$(brew --prefix ruby)/bin"
    "$(brew --prefix coreutils)/libexec/gnubin" # Add brew-installed GNU core utilities bin
    "$(brew --prefix)/share/npm/bin"            # Add npm-installed package bin
  )
fi

for dir in ${dirs_to_prepend[@]}; do
  [ -d ${dir} ] && PATH+=":$dir"
done

unset dirs_to_prepend

export PATH

# Default to Vim
export EDITOR="vim"

# Prefer British English and use UTF-8
export LC_ALL="en_GB.UTF-8"
export LANG="en_GB"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

export TERM=xterm-256color

# LS colors, made with http://geoff.greer.fm/lscolors/
export LSCOLORS="exfxcxdxbxegedabagacad"
export LS_COLORS='di=34;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=34;46:cd=34;43:su=0;41:sg=0;46:tw=0;42:ow=0;43:'
export GREP_COLOR='1;33'
