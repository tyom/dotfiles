#!/bin/bash

source shell/utils.sh

if [ "$(which_os)" != "macos" ]; then
  print_info "Skipping Quick Look plugins (macOS only)"
  exit 0
fi

print_step "Installing macOS Quick Look plugins"

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
casks=(
  qlmarkdown         # Preview Markdown files
  qlcolorcode        # Syntax highlighting for source code
  qlstephen          # Preview plain text files without extensions
  quicklook-json     # Pretty-print JSON files
  suspicious-package # Inspect macOS installer packages .pkg
  apparency          # Show app code signing info and entitlements
  quicklook-csv      # Preview CSV files as tables
)

brew install --cask "${casks[@]}"
