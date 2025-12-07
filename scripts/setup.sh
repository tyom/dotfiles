#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

echo -e "Installing dotfiles for $(which_os)…"

continue_or_exit \
  'This will install dotfiles for your system and update your .zshrc file.' 'y'

continue_or_skip \
  'Install Homebrew and useful packages? This may take a while.' 'y' &&
  source "$DOTFILES_DIR/scripts/install/brew.sh" ||
  print_info 'Skipping Homebrew'

if [ "$(which_os)" == "macos" ]; then
  continue_or_skip \
    'Install brew cask (macOS apps via Homebrew)?' 'y' &&
    source "$DOTFILES_DIR/scripts/install/brew-cask.sh" ||
    print_info 'Skipping Brew Cask'
fi

continue_or_skip \
  'Install tools via curl (Bun, etc.)?' 'y' &&
  source "$DOTFILES_DIR/scripts/install/curl.sh" ||
  print_info 'Skipping curl-based installs'

print_step 'Setting up zsh' &&
  source "$DOTFILES_DIR/scripts/zsh.sh"

print_step 'Symlinking dotfiles' &&
  source "$DOTFILES_DIR/scripts/stow.sh"

print_step 'Installing Vim plugins' &&
  source "$DOTFILES_DIR/scripts/install/vim.sh"

print_step 'Validating installation'
"$DOTFILES_DIR/scripts/validate.sh"

echo ""
print_success 'dotfiles are installed! Start a new shell session.'
