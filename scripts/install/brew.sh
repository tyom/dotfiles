#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

packages=(
  'bat|cat(1) clone with syntax highlighting and Git integration'
  'fzf|Fuzzy finder for files, history, etc.'
  'git-delta|Syntax highlighter for git and diff output'
  'scmpuff|Numbered shortcuts for common git commands'
  'tree|Display directories as trees'
  'wget|Internet file retriever'
  'tyom/tap/ungit|Download a repo/dir/file from GitHub'
  # 'httpie|Command line HTTP client'
  # 'gh|GitHub command-line tool'
  # 'fx|Command-line JSON processing tool'
  # 'ripgrep|Fast grep alternative (rg command)'
)

if [ "$(which_os)" == "macos" ]; then
  packages+=(
    'stow|GNU Stow for symlink management'
    'coreutils|GNU core utilities'
    'findutils|GNU find utilities'
    'tyom/tap/kcm|Keychain-based secrets manager'
  )
fi

echo ""
print_step "Homebrew packages:"
pick_from_list 'Install Homebrew and all of these packages? This may take a while.' "${packages[@]}"

if [ ${#PICKED[@]} -eq 0 ]; then
  print_info 'Skipping Homebrew packages'
  SUMMARY+=('Homebrew packages: skipped')
else
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
    BREW_SHELLENV="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
    grep -qxF "$BREW_SHELLENV" "$HOME/.zprofile" 2>/dev/null ||
      echo "$BREW_SHELLENV" >>"$HOME/.zprofile"
    eval "$(${BREW_PREFIX}/bin/brew shellenv)"
  fi

  # Trust own tap so tap-trust-enabled brew installs its packages without prompts
  brew trust tyom/tap &>/dev/null || true

  print_step "Updating Homebrew" && brew update
  print_step "Installing Homebrew packages" && brew install "${PICKED[@]}"

  # repo-intel (standalone tool: github.com/tyom/repo-intel). Installed non-fatally
  # so a tap/network hiccup can't abort the core packages above. brew.sh runs on
  # both macOS and Linux (Linuxbrew), so this is the sole install path.
  print_step "Installing repo-intel (tap: tyom/tap)" &&
    brew install tyom/tap/repo-intel ||
    print_info "Skipping repo-intel — install manually: curl -fsSL https://tyom.github.io/repo-intel/install.sh | sh"

  print_info "Cleaning outdating brew packages" && brew cleanup

  SUMMARY+=("Homebrew packages: installed (${#PICKED[@]})")
fi
