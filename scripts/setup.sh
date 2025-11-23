#!/bin/bash

source scripts/vars
source shell/utils

echo -e "Installing dotfiles for $(which_os)…"

continue_or_exit \
  'Warning: this will modify your dotfiles configuration.'

continue_or_skip \
  'Install Homebrew and useful packages? This may take a while.' &&
  source "$DOTFILES_DIR/scripts/install/brew.sh" ||
  print_info 'Skipping Homebrew'

if [ "$(which_os)" == "macos" ]; then
  continue_or_skip \
    'Install brew cask (macOS apps via Homebrew)?' &&
    source "$DOTFILES_DIR/scripts/install/brew-cask.sh" ||
    print_info 'Skipping Brew Cask'

  # Disable prompt when quitting iTerm
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
fi

print_step 'Setting up zsh' &&
  source "$DOTFILES_DIR/scripts/zsh.sh"

print_step 'Symlinking dotfiles' &&
  source "$DOTFILES_DIR/scripts/stow.sh"

print_step 'Installing Vim plugins' &&
  source "$DOTFILES_DIR/scripts/install/vim.sh"

# Add reference to dotfiles directory
>"$HOME/.dotfilesrc" && echo "export DOTFILES_DIR=$DOTFILES_DIR" >>"$HOME/.dotfilesrc"

# Prepend source line to ~/.zshrc if not already present
print_step 'Configuring zsh'
ZSHRC_SOURCE_LINE='[ -f ~/.dotfilesrc ] && source ~/.dotfilesrc && source $DOTFILES_DIR/zsh/config.zsh'
if ! grep -qF "source \$DOTFILES_DIR/zsh/config.zsh" "$HOME/.zshrc" 2>/dev/null; then
  # Prepend to .zshrc
  TEMP_ZSHRC=$(mktemp)
  echo "# Dotfiles configuration" > "$TEMP_ZSHRC"
  echo "$ZSHRC_SOURCE_LINE" >> "$TEMP_ZSHRC"
  echo "" >> "$TEMP_ZSHRC"
  cat "$HOME/.zshrc" >> "$TEMP_ZSHRC" 2>/dev/null || true
  mv "$TEMP_ZSHRC" "$HOME/.zshrc"
  print_success 'Added dotfiles source line to ~/.zshrc'
else
  print_info 'Dotfiles source line already in ~/.zshrc'
fi

print_success 'dotfiles are installed! Start a new shell session.'
