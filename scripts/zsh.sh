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
  # Check if .zshrc is default oh-my-zsh (sources oh-my-zsh.sh and has ZSH_THEME)
  if grep -q 'source.*oh-my-zsh.sh' "$HOME/.zshrc" 2>/dev/null &&
    grep -q 'ZSH_THEME=' "$HOME/.zshrc" 2>/dev/null; then
    # Replace default oh-my-zsh .zshrc (our dotfiles.zsh handles everything)
    echo "$DOTFILES_SOURCE_LINE" >"$HOME/.zshrc"
    print_success "Replaced default oh-my-zsh .zshrc"
  elif [[ -f "$HOME/.zshrc" ]]; then
    # Append to existing custom .zshrc
    echo "" >>"$HOME/.zshrc"
    echo "# Dotfiles" >>"$HOME/.zshrc"
    echo "$DOTFILES_SOURCE_LINE" >>"$HOME/.zshrc"
    print_success "Added dotfiles source line to .zshrc"
  else
    echo "$DOTFILES_SOURCE_LINE" >"$HOME/.zshrc"
    print_success "Created .zshrc"
  fi
fi

# Create/update the dotfiles zsh config
cp "$DOTFILES_DIR/zsh/dotfiles.zsh" "$HOME/.dotfiles.zsh"

print_success "Created ~/.dotfiles.zsh"
