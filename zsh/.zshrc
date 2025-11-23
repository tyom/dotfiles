[ -f ~/.dotfilesrc ] \
  && source ~/.dotfilesrc \
  || echo "\e[0;31m ✖ ~/.dotfilesrc file which exports \$DOTFILES_DIR path is missing\e[0m\n"

plugins=(z fzf colored-man-pages docker npm extract gh ripgrep)

source $DOTFILES_DIR/shell/exports
source $DOTFILES_DIR/shell/aliases
source $DOTFILES_DIR/shell/functions
source $DOTFILES_DIR/shell/config
source $ZSH/oh-my-zsh.sh

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
