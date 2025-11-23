# Dotfiles ZSH Post-OMZ Configuration
# This file is sourced AFTER oh-my-zsh in ~/.zshrc

# Load our custom theme
ZSH_THEME="tyom"
source "$ZSH/custom/themes/tyom.zsh-theme"

# Source local extra (private) settings specific to the machine
[ -f ~/.zsh.local ] && source ~/.zsh.local

# scmpuff for easier Git commits
if exists scmpuff; then
  eval "$(scmpuff init -s --aliases=false)"
fi
