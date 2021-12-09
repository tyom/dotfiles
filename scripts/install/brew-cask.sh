#!/bin/bash

source shell/utils

brew tap homebrew/cask

print_step "Installing macOS packages"

brew install rowanj-gitx betterzip

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
brew install \
  qlcolorcode \
  qlstephen \
  qlmarkdown \
  quicklook-json \
  qlimagesize \
  suspicious-package \
  apparency \
  quicklookase \
  qlvideo \
  qlprettypatch \
  quicklook-csv \
  webpquicklook
