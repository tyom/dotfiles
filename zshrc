# Symlink to this file from ~/.zshrc
# You should also symlink ~/.zshenv to zsh/env in this directory

. ~/bin/dotfiles/zsh/config
. ~/bin/dotfiles/shared/env
. ~/bin/dotfiles/shared/aliases

[[ -s "/Users/tsemonov/.rvm/scripts/rvm" ]] && source "/Users/tsemonov/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
