#!/bin/bash

# Set up git configuration
# Adds an include line to user's ~/.gitconfig to load dotfiles config
# Copies .gitignore if it doesn't exist

source "$DOTFILES_DIR/shell/utils.sh"

GITCONFIG_PATH="$DOTFILES_DIR/git/.gitconfig"
GITIGNORE_PATH="$DOTFILES_DIR/git/.gitignore"

# Add include line to user's ~/.gitconfig
INCLUDE_LINE="[include]
    path = $GITCONFIG_PATH"

if grep -qF "path = $GITCONFIG_PATH" "$HOME/.gitconfig" 2>/dev/null; then
  print_info "Dotfiles gitconfig already included in ~/.gitconfig"
else
  if [[ -f "$HOME/.gitconfig" ]]; then
    # Append to existing .gitconfig
    echo "" >>"$HOME/.gitconfig"
    echo "# Dotfiles" >>"$HOME/.gitconfig"
    echo "$INCLUDE_LINE" >>"$HOME/.gitconfig"
    print_success "Added dotfiles include to ~/.gitconfig"
  else
    # Create new .gitconfig
    echo "# Dotfiles" >"$HOME/.gitconfig"
    echo "$INCLUDE_LINE" >>"$HOME/.gitconfig"
    print_success "Created ~/.gitconfig with dotfiles include"
  fi
fi

# Copy .gitignore if it doesn't exist (user can customise it)
if [ ! -f "$HOME/.gitignore" ]; then
  cp "$GITIGNORE_PATH" "$HOME/.gitignore"
  print_success "Copied .gitignore to ~/.gitignore"
else
  print_info "~/.gitignore already exists, skipping"
fi
