#!/bin/bash

install_zsh() {
  platform=$(which_os)

  SUDO_CMD=""
  if [ "$(id -u)" != "0" ]; then
    SUDO_CMD="sudo"
  fi

  if [[ $platform == 'redhat' ]]; then
    ${SUDO_CMD} yum install zsh -y
  elif [[ $platform == 'debian' ]]; then
    ${SUDO_CMD} apt-get install zsh -y
  elif [[ $platform == 'macos' ]]; then
    brew install zsh
  fi
}

if exists zsh; then
  print_info "zsh is already installed. Skipping."
else
  install_zsh
  print_success "zsh installed. Re-run this script to continue."
  exit
fi

# Install Oh My Zsh if it isn't already present
if [[ ! -d $HOME/.oh-my-zsh/ ]]; then
  # RUNZSH=no: Don't start zsh after install
  # KEEP_ZSHRC=yes: Don't overwrite .zshrc
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
else
  print_info 'oh-my-zsh is already installed. Skipping.'
fi

# Set up .zshrc to source our dotfiles config
DOTFILES_SOURCE_LINE='source "$HOME/.dotfiles.zsh"'

if grep -qF "$DOTFILES_SOURCE_LINE" "$HOME/.zshrc" 2>/dev/null; then
  print_info "Dotfiles already sourced in .zshrc"
else
  # Always append to existing .zshrc or create if it doesn't exist
  if [[ -f "$HOME/.zshrc" ]]; then
    # Append to existing .zshrc (never overwrite)
    echo "" >>"$HOME/.zshrc"
    echo "# Dotfiles" >>"$HOME/.zshrc"
    echo "$DOTFILES_SOURCE_LINE" >>"$HOME/.zshrc"
    print_success "Added dotfiles source line to .zshrc"
  else
    # Create new .zshrc if it doesn't exist
    echo "$DOTFILES_SOURCE_LINE" >"$HOME/.zshrc"
    print_success "Created .zshrc"
  fi

  # If user needs manual action, provide instructions
  if [[ ! -w "$HOME/.zshrc" ]]; then
    print_error "Cannot write to .zshrc. Please manually add the following line to your .zshrc:"
    print_info "$DOTFILES_SOURCE_LINE"
    exit 1
  fi
fi

# Create/update the dotfiles zsh config
cp "$DOTFILES_DIR/zsh/dotfiles.zsh" "$HOME/.dotfiles.zsh"

print_success "Created ~/.dotfiles.zsh"
