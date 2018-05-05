#!/bin/bash

source shell/utils

brew tap caskroom/cask

print_step "Installing macOS packages"

brew cask install rowanj-gitx

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
brew cask install \
  qlcolorcode \
  qlstephen \
  qlmarkdown \
  quicklook-json \
  qlprettypatch \
  quicklook-csv \
  betterzipql \
  qlimagesize \
  webpquicklook \
  suspicious-package
