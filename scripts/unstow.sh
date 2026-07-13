#!/bin/bash

# Remove symlinks using GNU Stow
# This cleanly removes all dotfile symlinks

source "$DOTFILES_DIR/scripts/vars.sh"
source "$DOTFILES_DIR/shell/utils.sh"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
# On macOS, use Homebrew stow
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

print_step "Removing dotfile symlinks..."

$STOW_CMD -v -d "$DOTFILES_DIR" -t "$HOME" -D stow 2>&1 | grep -v "^BUG" || true

print_success "Symlinks removed"
