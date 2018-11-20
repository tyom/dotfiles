#!/bin/bash

source shell/utils

packages=(
  fasd
  fzf
  diff-so-fancy
  scmpuff
  tree
  wget
  yarn --without-node
  # bash-completion2
  # git-extras
  # hub
  # httpie
  # source-highlight
  # the_silver_searcher
  # mtr
  # imagemagick --with-webp
  # python
  # ffmpeg --with-libvpx
  # wifi-password
)

if [ $(which_os) == "macos" ]; then
  packages+=(
    coreutils
    findutils
    # moreutils
  )
fi

# Ask for the administrator password upfront
sudo -v

# Check for Homebrew and install it if missing
if ! exists brew; then
  if [ $(which_os) == "macos" ]; then
    print_step "Installing Homebrew for macOS" && \
      ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  else
    print_step "Installing Linuxbrew" && \
      git clone --depth 1 https://github.com/Linuxbrew/brew.git ~/.linuxbrew && \
      export PATH="$HOME/.linuxbrew/bin:$PATH"
  fi
else
  print_info "Homebrew installed. Skipping."
fi

print_step "Updating Homebrew" && brew update
print_step "Installing Homebrew packages" && brew install "${packages[@]}"
print_info "Cleaning outdating brew packages" && brew cleanup
