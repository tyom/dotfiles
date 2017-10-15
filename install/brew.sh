#!/bin/bash

# Installs Homebrew and some of the common dependencies needed/desired for software development

# Ask for the administrator password upfront
sudo -v

# Check for Homebrew and install it if missing
if test ! $(which brew)
then
  echo "Installing Homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Make sure we’re using the latest Homebrew
brew update

# Upgrade any already-installed formulae
brew upgrade

apps=(
    bash-completion2
    coreutils
    moreutils
    findutils
    ffmpeg
    git
    git-extras
    hub
    gnu-sed --with-default-names
    grep --with-default-names
    homebrew/completions/brew-cask-completion
    homebrew/dupes/grep
    homebrew/dupes/openssh
    mtr
    fasd
    imagemagick --with-webp
    python
    source-highlight
    the_silver_searcher
    tree
    ffmpeg --with-libvpx
    wget
    wifi-password
)

brew install "${apps[@]}"

# Remove outdated versions from the cellar
brew cleanup