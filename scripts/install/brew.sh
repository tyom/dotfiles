#!/bin/bash

source scripts/vars.sh
source scripts/versions.sh
source shell/utils.sh

# Homebrew 6 asks before installing dependencies by default; the setup
# checklist is our single decision point. Older brews ignore this var.
export HOMEBREW_NO_ASK=1

packages=(
  'bat|cat(1) clone with syntax highlighting and Git integration'
  'fzf|Fuzzy finder for files, history, etc.'
  'git-delta|Syntax highlighter for git and diff output'
  'herdr|Agent multiplexer that lives in your terminal'
  'jq|Command-line JSON processor'
  'scmpuff|Numbered shortcuts for common git commands'
  'tree|Display directories as trees'
  'wget|Internet file retriever'
  'tyom/tap/ungit|Download a repo/dir/file from GitHub'
  'tyom/tap/agent-ctx|What a coding agent loads when it opens a repo'
  'tyom/tap/git-owns|Line ownership per directory, top contributors first'
  # 'httpie|Command line HTTP client'
  # 'gh|GitHub command-line tool'
  # 'fx|Command-line JSON processing tool'
  # 'ripgrep|Fast grep alternative (rg command)'
)

if [ "$(which_os)" == "macos" ]; then
  packages+=(
    'coreutils|GNU core utilities'
    'findutils|GNU find utilities'
    'tyom/tap/kcm|Keychain-based secrets manager'
  )
fi

# Check for Homebrew and install it if missing
if ! exists brew; then
  if [ "$(which_os)" == "macos" ]; then
    print_step "Installing Homebrew for macOS"
  else
    print_step "Installing Homebrew for Linux"
  fi

  HOMEBREW_INSTALLER=$(mktemp)
  if download_verified "$HOMEBREW_INSTALL_URL" "$HOMEBREW_INSTALL_SHA256" "$HOMEBREW_INSTALLER" &&
    /bin/bash "$HOMEBREW_INSTALLER"; then
    rm -f "$HOMEBREW_INSTALLER"
  else
    rm -f "$HOMEBREW_INSTALLER"
    print_error 'Homebrew installation failed'
    exit 1
  fi

  # The official installer does not update the current process. Find its
  # documented locations so the rest of this run can use it.
  if ! exists brew; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew \
      "$HOME/.linuxbrew/bin/brew" /home/linuxbrew/.linuxbrew/bin/brew; do
      if [ -x "$brew_bin" ]; then
        export PATH="${brew_bin%/*}:$PATH"
        break
      fi
    done
  fi
else
  print_info "Homebrew installed. Skipping."
fi

if ! exists brew; then
  print_error 'Homebrew installation completed but brew is not available'
  exit 1
fi

# Add Homebrew to the current and future macOS login shells.
if [ "$(which_os)" == "macos" ]; then
  BREW_BIN=$(command -v brew)
  BREW_SHELLENV="eval \"\$(${BREW_BIN} shellenv)\""
  grep -qxF "$BREW_SHELLENV" "$HOME/.zprofile" 2>/dev/null ||
    echo "$BREW_SHELLENV" >>"$HOME/.zprofile"
  eval "$("$BREW_BIN" shellenv)"
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
