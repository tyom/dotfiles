#!/bin/bash

source scripts/vars.sh
source shell/utils.sh

if [ "$(which_os)" != "macos" ]; then
  print_info "Skipping casks (macOS only)"
  exit 0
fi

# Apps and Quick Look plugins (https://github.com/sindresorhus/quick-look-plugins)
casks=(
  'ghostty|Fast GPU-accelerated terminal emulator'
  'quicklook-json|Pretty-print JSON files'
  'suspicious-package|Inspect macOS installer packages .pkg'
  'quicklook-csv|Preview CSV files as tables'
  # 'apparency|Show app code signing info and entitlements'
  # 'qlmarkdown|Preview Markdown files'
  # 'qlcolorcode|Syntax highlighting for source code'
  # 'qlstephen|Preview plain text files without extensions'
)

echo ""
print_step "macOS casks:"
pick_from_list 'Install all of these casks?' "${casks[@]}"

if [ ${#PICKED[@]} -eq 0 ]; then
  print_info 'Skipping Brew Cask apps'
  SUMMARY+=('Brew Cask apps: skipped')
else
  brew install --cask "${PICKED[@]}"
  SUMMARY+=("Brew Cask apps: installed (${#PICKED[@]})")
fi
