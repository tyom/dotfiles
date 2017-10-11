#!/bin/bash

# Install Caskroom
brew tap caskroom/cask

# Install macOS packages
apps=(
    rowanj-gitx
    # dash
    # visual-studio-code
    # firefox
    # firefoxnightly
    # google-chrome
    # google-chrome-canary
    # spotify
    # skype
    # slack
    # elmedia-player
)

brew cask install "${apps[@]}"

# Quick Look Plugins (https://github.com/sindresorhus/quick-look-plugins)
brew cask install qlcolorcode qlstephen qlmarkdown quicklook-json qlprettypatch quicklook-csv betterzipql qlimagesize webpquicklook suspicious-package