#!/bin/bash

NODE_VERSION=lts

# Globally install with npm
packages=(
  git-recent
  git-open
  npm-check-updates
  nodemon
)

function install_n {
  curl -L https://git.io/n-install | bash
  source ~/.zshrc
}

function install_npm_packages {
  # All `npm install <pkg>` commands will pin to the version
  # that was available at the time you run the command
  npm config set save-exact = true

  npm install -g "${packages[@]}"
}

print_step 'Installing Node manager' && install_n
print_step 'Installing useful global NPM packages' && install_npm_packages
