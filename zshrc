# Symlink to this file from ~/.zshrc
# You should also symlink ~/.zshenv to zshenv in this directory

. ~/.dotfiles/zsh/config
. ~/.dotfiles/zshenv
. ~/.dotfiles/aliases

source ~/.dotfiles/tools/z/z.sh
source ~/.dotfiles/tools/app-adenosine-prefab/adenosine-exports

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
