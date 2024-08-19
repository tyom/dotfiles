#!/bin/bash

source shell/utils

print_step "Installing macOS packages"

brew install --cask gitx

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
brew install \
  qlcolorcode \
  qlstephen \
  qlmarkdown \
  quicklook-json \
  suspicious-package \
  apparency \
  qlvideo \
  qlprettypatch \
  quicklook-csv \
  webpquicklook
