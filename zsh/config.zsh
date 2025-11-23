# Dotfiles ZSH Configuration
# This file is sourced from ~/.zshrc BEFORE oh-my-zsh

# Ensure DOTFILES_DIR is set
if [ -z "$DOTFILES_DIR" ]; then
  echo "\e[0;31m ✖ \$DOTFILES_DIR is not set. Source ~/.dotfilesrc first.\e[0m\n"
  return
fi

# Source shell modules first (for PATH and utility functions)
source $DOTFILES_DIR/shell/utils.sh
source $DOTFILES_DIR/shell/exports.sh
source $DOTFILES_DIR/shell/aliases.sh
source $DOTFILES_DIR/shell/functions.sh
source $DOTFILES_DIR/shell/config.sh

# Set FZF_BASE for oh-my-zsh fzf plugin (must be set BEFORE oh-my-zsh loads)
if exists brew; then
  FZF_BREW_PATH="$(brew --prefix)/opt/fzf"
  [ -d "$FZF_BREW_PATH" ] && export FZF_BASE="$FZF_BREW_PATH"
fi

# Set plugins array (overrides oh-my-zsh template's plugins=(git))
# This must be set BEFORE oh-my-zsh sources (which happens after this file)
plugins=(git z colored-man-pages docker npm extract gh)

# Only add fzf plugin if fzf is installed
[ -n "$FZF_BASE" ] && plugins+=(fzf)

# Note: oh-my-zsh will be sourced by the template ~/.zshrc after this file
