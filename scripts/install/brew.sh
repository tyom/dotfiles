#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

# Homebrew 6 asks before installing dependencies by default; the setup
# checklist is our single decision point. Older brews ignore this var.
export HOMEBREW_NO_ASK=1

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

# Check for Homebrew and install it if missing
if ! exists brew; then
  if [ "$(which_os)" == "macos" ]; then
    print_step "Installing Homebrew for macOS" &&
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    # Clone and PATH export are separate so a re-run (~/.linuxbrew already
    # cloned) still gets brew on PATH
    if [ ! -x "$HOME/.linuxbrew/bin/brew" ]; then
      print_step "Installing Homebrew for Linux"
      git clone --depth 1 https://github.com/Homebrew/brew.git ~/.linuxbrew
    fi
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

print_step "Updating Homebrew" && brew update

# Trust own tap so tap-trust-enabled brew installs its packages without
# warnings. Must run after `brew update`: older brews (e.g. the homebrew/brew
# Docker image) lack the trust command until updated.
brew trust tyom/tap &>/dev/null || true

print_step "Installing Homebrew packages"
# Retried once: transient network drops surface as "Error: Broken pipe";
# brew skips already-installed formulae so the retry is cheap.
if brew install "${packages[@]%%|*}" ||
  brew install "${packages[@]%%|*}"; then
  SUMMARY+=("Homebrew packages: installed (${#packages[@]})")
else
  SUMMARY+=('Homebrew packages: install failed')
fi

# repo-intel (standalone tool: github.com/tyom/repo-intel). Installed non-fatally
# so a tap/network hiccup can't abort the core packages above. brew.sh runs on
# both macOS and Linux (Linuxbrew), so this is the sole install path.
print_step "Installing repo-intel (tap: tyom/tap)" &&
  brew install tyom/tap/repo-intel ||
  print_info "Skipping repo-intel — install manually: curl -fsSL https://tyom.github.io/repo-intel/install.sh | sh"

print_info "Cleaning outdating brew packages" && brew cleanup
