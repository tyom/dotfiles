# Dotfiles ZSH Configuration
# This file is sourced from ~/.zshrc

# Ensure DOTFILES_DIR is set
if [ -z "$DOTFILES_DIR" ]; then
  echo "\e[0;31m ✖ \$DOTFILES_DIR is not set. Source ~/.dotfilesrc first.\e[0m\n"
  return
fi

# Oh-my-zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tyom"
plugins=(z fzf colored-man-pages docker npm extract gh ripgrep)

# Source shell modules (before oh-my-zsh for PATH setup)
source $DOTFILES_DIR/shell/exports
source $DOTFILES_DIR/shell/aliases
source $DOTFILES_DIR/shell/functions
source $DOTFILES_DIR/shell/config

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Completions
autoload -Uz compinit; compinit

# npm tab completion
if exists npm; then
  source <(npm completion)
fi

# Bash completions
if exists brew; then
  [ -f $(brew --prefix)/etc/bash_completion ] \
    && source $(brew --prefix)/etc/bash_completion
fi

# Source local extra (private) settings specific to the machine
[ -f ~/.zsh.local ] && source ~/.zsh.local

# scmpuff for easier Git commits
if exists scmpuff; then
  eval "$(scmpuff init -s --aliases=false)"
fi
