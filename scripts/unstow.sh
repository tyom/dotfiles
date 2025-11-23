#!/bin/bash

# Remove symlinks using GNU Stow
# This cleanly removes all dotfile symlinks

source "$DOTFILES_DIR/scripts/vars"
source "$DOTFILES_DIR/shell/utils"

# Use system stow on Linux (Homebrew stow has Perl dependency issues)
# On macOS, use Homebrew stow
if [[ "$(uname)" == "Linux" ]] && [[ -x /usr/bin/stow ]]; then
  STOW_CMD="/usr/bin/stow"
else
  STOW_CMD="stow"
fi

print_step "Removing dotfile symlinks..."

for package in "${STOW_PACKAGES[@]}"; do
  if [ -d "$DOTFILES_DIR/$package" ]; then
    echo "   Unstowing $package..."
    $STOW_CMD -v -d "$DOTFILES_DIR" -t "$HOME" -D "$package" 2>&1 | grep -v "^BUG" || true
  fi
done

print_success "Symlinks removed"
