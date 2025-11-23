#!/bin/bash

source shell/utils

packages=(
  bat       # A cat(1) clone with syntax highlighting and Git integration
  fzf       # Fuzzy finder for files, history, etc.
  git-delta # Syntax highlighter for git and diff output
  scmpuff   # Add numbered shortcuts to common git commands
  tree      # Display directories as trees
  wget      # Internet file retriever
  # httpie    # Command line HTTP client
  # gh        # GitHub command-line tool
  # fx        # Command-line JSON processing tool
  # ripgrep   # Fast grep alternative (rg command)
)

if [ "$(which_os)" == "macos" ]; then
  packages+=(
    stow # GNU Stow for symlink management (on Linux, use system stow via apt)
    coreutils
    findutils
  )
fi

# Check for Homebrew and install it if missing
if ! exists brew; then
  if [ "$(which_os)" == "macos" ]; then
    print_step "Installing Homebrew for macOS" &&
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    print_step "Installing Homebrew for Linux" &&
      git clone --depth 1 https://github.com/Homebrew/brew.git ~/.linuxbrew &&
      export PATH="$HOME/.linuxbrew/bin:$PATH"
  fi
else
  print_info "Homebrew installed. Skipping."
fi

# Set up Homebrew in PATH (macOS only - Linux path is set during clone above)
if [ "$(which_os)" == "macos" ]; then
  # Determine Homebrew prefix (Apple Silicon vs Intel)
  if [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
  else
    BREW_PREFIX="/usr/local"
  fi
  echo "eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\"" >>"$HOME/.zprofile"
  eval "$(${BREW_PREFIX}/bin/brew shellenv)"
fi

print_step "Updating Homebrew" && brew update
print_step "Installing Homebrew packages" && brew install "${packages[@]}"
print_info "Cleaning outdating brew packages" && brew cleanup
