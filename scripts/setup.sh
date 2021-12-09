#!/bin/bash

source scripts/vars
source shell/utils

echo -e "Installing dotfiles for $(which_os)…"

continue_or_exit \
  'Warning: this will overwrite your current dotfiles. They will be backed up.'

source "$DOTFILES_DIR/scripts/backup.sh"

continue_or_skip \
  'Install Homebrew and useful packages? This may take a while.' \
  && source "$DOTFILES_DIR/scripts/install/brew.sh" \
  || print_info 'Skipping Homebrew'

if [ "$(which_os)" == "macos" ]; then
  continue_or_skip \
    'Install brew cask (macOS apps via Homebrew)?' \
    && source "$DOTFILES_DIR/scripts/install/brew-cask.sh" \
    || print_info 'Skipping Brew Cask'

  # Disable prompt when quitting iTerm
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
fi

print_step 'Setting up zsh' \
  && source "$DOTFILES_DIR/scripts/zsh.sh"

print_step 'Symlinking dotfiles' \
  && source "$DOTFILES_DIR/scripts/symlinks.sh"

print_step 'Installing Vim plugins' \
  && source "$DOTFILES_DIR/scripts/install/vim.sh"

print_success 'dotfiles are installed! Start a new shell session.'

# Add reference to dotfiles directory
> "$HOME/.dotfilesrc" && echo "export DOTFILES_DIR=$DOTFILES_DIR" >> "$HOME/.dotfilesrc"
