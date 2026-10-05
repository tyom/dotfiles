# Dotfiles ZSH Configuration
# Sourced from ~/.zshrc with DOTFILES_DIR already exported

# Pre oh-my-zsh configuration (exports, aliases, functions, plugins list)
source "$DOTFILES_DIR/zsh/config.zsh"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tyom"
source "$ZSH/oh-my-zsh.sh"

# Claude Code shells: pass unmatched globs through (`grep --include=*.ts`)
# and keep plain git output, without scmpuff's status screen after add/commit.
if [[ -n $CLAUDECODE ]]; then
  setopt nonomatch
# scmpuff for easier Git commits
elif command -v scmpuff &>/dev/null; then
  eval "$(scmpuff init -s --aliases=false)"
else
  # Fallback when scmpuff is not installed
  scmpuff_status() { git status; }
fi
