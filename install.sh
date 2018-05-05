#!/usr/bin/env bash

# This is remote install script
# Use make install to install locally

command -v curl >/dev/null 2>&1 || \
  echo "No curl installed. Aborting."
  echo "Install curl and try again or clone repository and install locally."

echo "Installing dotfiles"
mkdir -p "$HOME/.dotfiles" && \
eval "curl -#L https://github.com/tyom/dotfiles/tarball/updates | tar -xzv -C ~/.dotfiles --strip-components=1 --exclude='{.gitignore}'"

cd ~/.dotfiles && make install
