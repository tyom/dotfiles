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

# Backup existing .zshrc before oh-my-zsh installation
if [[ -f $HOME/.zshrc ]] && [[ ! -f $HOME/.zshrc.bak ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
  print_info "Backed up existing .zshrc to .zshrc.bak"
fi

# Install Oh My Zsh if it isn't already present
if [[ ! -d $HOME/.oh-my-zsh/ ]]; then
  # RUNZSH=no: Don't start zsh after install
  # KEEP_ZSHRC=yes: Don't overwrite .zshrc (we'll create our own)
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
else
  print_info 'oh-my-zsh is already installed. Skipping.'
fi

# Create our .zshrc that sources everything in the right order
cat > "$HOME/.zshrc" << 'EOF'
# Dotfiles ZSH Configuration
# Sources config in order: dotfilesrc -> pre-omz -> oh-my-zsh -> post-omz -> original

# Load dotfiles directory path
[ -f ~/.dotfilesrc ] && source ~/.dotfilesrc

# Pre oh-my-zsh configuration (exports, aliases, functions, plugins list)
[ -n "$DOTFILES_DIR" ] && source "$DOTFILES_DIR/zsh/config.zsh"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tyom"
source "$ZSH/oh-my-zsh.sh"

# Post oh-my-zsh configuration
[ -n "$DOTFILES_DIR" ] && [ -f "$DOTFILES_DIR/zsh/post-omz.zsh" ] && source "$DOTFILES_DIR/zsh/post-omz.zsh"

# Source original zshrc if present
[ -f ~/.zshrc.bak ] && source ~/.zshrc.bak
EOF

print_success "Created new .zshrc"
