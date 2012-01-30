# Symlink to this file from ~/.zshrc
# You should also symlink ~/.zshenv to zsh/env in this directory

. ~/bin/dotfiles/zsh/config
. ~/bin/dotfiles/shared/env
. ~/bin/dotfiles/shared/aliases

[[ -s "~/.rvm/scripts/rvm" ]] && source "~/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
