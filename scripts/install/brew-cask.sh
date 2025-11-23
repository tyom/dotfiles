#!/bin/bash

source shell/utils.sh

print_step "Installing macOS Quick Look plugins"

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
brew install --cask
qlmarkdown \          # Preview Markdown files
qlcolorcode \         # Syntax highlighting for source code
qlstephen \           # Preview plain text files without extensions
quicklook-json \      # Pretty-print JSON files
suspicious-package \  # Inspect macOS installer packages .pkg
apparency \           # Show app code signing info and entitlements
quicklook-csv \       # Preview CSV files as tables
