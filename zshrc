# Symlink to this file from ~/.zshrc
# You should also symlink ~/.zshenv to zshenv in this directory

. ~/.dotfiles/zsh/config
. ~/.dotfiles/zshenv
. ~/.dotfiles/aliases

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
