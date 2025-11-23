# Dotfiles ZSH Configuration
# Sources config in order: dotfilesrc -> config.zsh -> oh-my-zsh -> original

# Load dotfiles directory path
[ -f ~/.dotfilesrc ] && source ~/.dotfilesrc

# Pre oh-my-zsh configuration (exports, aliases, functions, plugins list)
[ -n "$DOTFILES_DIR" ] && source "$DOTFILES_DIR/zsh/config.zsh"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tyom"
source "$ZSH/oh-my-zsh.sh"

# scmpuff for easier Git commits
if command -v scmpuff &>/dev/null; then
  eval "$(scmpuff init -s --aliases=false)"
fi

# Source original zshrc if present
[ -f ~/.zshrc.bak ] && source ~/.zshrc.bak
