#!/bin/bash

source shell/utils

packages=(
  # fasd # CLI quick access to files and dirs
  # fzf # CLI fuzzy finder
  bat # A cat(1) clone with syntax highlighting and Git integration.
  git-delta # Syntax highlighter for git and diff output
  scmpuff # Add numbered shortcuts to common git commands
  tree # Display directories as trees
  wget # Internet file retriever
  httpie # Command line HTTP client
  gh # GitHub command-line tool
#  node # Node
  n # Node version manager
  fx  # Command-line JSON processing tool
  yarn --ignore-dependencies # JS package manager (skip Node in favour of currently used node via version manager, e.g. n)
  # saulpw/vd/visidata # tool that lets you open, explore, summarise and analyse datasets in terminal
  # bash-completion2
  # git-extras
  # hub
  # source-highlight
  # the_silver_searcher
  # mtr
  # imagemagick --with-webp
  # python
  # ffmpeg --with-libvpx
  # wifi-password
)

if [ "$(which_os)" == "macos" ]; then
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
  if [ "$(which_os)" == "macos" ]; then
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

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

print_step "Updating Homebrew" && brew update
print_step "Installing Homebrew packages" && brew install "${packages[@]}"
print_info "Cleaning outdating brew packages" && brew cleanup
