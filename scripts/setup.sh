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
    # source "$DOTFILES_DIR/scripts/install/brew-cask.sh" ||
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

# Configure zsh: prepend pre-omz config, append post-omz config
print_step 'Configuring zsh'

PRE_OMZ_LINE='[ -f ~/.dotfilesrc ] && source ~/.dotfilesrc && source $DOTFILES_DIR/zsh/config.zsh'
POST_OMZ_LINE='[ -f $DOTFILES_DIR/zsh/post-omz.zsh ] && source $DOTFILES_DIR/zsh/post-omz.zsh'

# Remove oh-my-zsh template's plugins line (we set plugins in config.zsh)
if grep -q '^plugins=(git)$' "$HOME/.zshrc" 2>/dev/null; then
  TEMP=$(mktemp)
  grep -v '^plugins=(git)$' "$HOME/.zshrc" > "$TEMP"
  mv "$TEMP" "$HOME/.zshrc"
fi

if ! grep -qF "zsh/config.zsh" "$HOME/.zshrc" 2>/dev/null; then
  # Prepend pre-omz config
  TEMP=$(mktemp)
  echo "# Dotfiles pre-omz configuration" >"$TEMP"
  echo "$PRE_OMZ_LINE" >>"$TEMP"
  echo "" >>"$TEMP"
  cat "$HOME/.zshrc" >>"$TEMP"
  mv "$TEMP" "$HOME/.zshrc"

  print_success 'Added pre-omz config to ~/.zshrc'
fi

if ! grep -qF "zsh/post-omz.zsh" "$HOME/.zshrc" 2>/dev/null; then
  # Append post-omz config
  echo "" >>"$HOME/.zshrc"
  echo "# Dotfiles post-omz configuration" >>"$HOME/.zshrc"
  echo "$POST_OMZ_LINE" >>"$HOME/.zshrc"
  print_success 'Added post-omz config to ~/.zshrc'
fi

print_success 'dotfiles are installed! Start a new shell session.'
