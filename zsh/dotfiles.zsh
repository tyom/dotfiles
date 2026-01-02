# Dotfiles ZSH Configuration
# Sourced from ~/.zshrc with DOTFILES_DIR already exported

# Pre oh-my-zsh configuration (exports, aliases, functions, plugins list)
source "$DOTFILES_DIR/zsh/config.zsh"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tyom"
source "$ZSH/oh-my-zsh.sh"

# scmpuff for easier Git commits
if command -v scmpuff &>/dev/null; then
  eval "$(scmpuff init -s --aliases=false)"
else
  # Fallback when scmpuff is not installed
  scmpuff_status() { git status; }
fi
