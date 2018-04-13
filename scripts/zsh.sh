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
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
else
  print_info 'oh-my-zsh is already installed. Skipping.'
fi
