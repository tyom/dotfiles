#!/bin/bash

source shell/utils

NODE_VERSION=lts

# Globally install with npm
packages=(
  git-recent
  git-open
  npm-check-updates
  nodemon
)

function install_nvm {
  nvm install $NODE_VERSION
  nvm use node
  nvm alias default node
}

function install_node {
  if !exists nvm; then
    curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

    export NVM_DIR="$HOME/.nvm"

    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
  fi
}

function install_npm_packages {
  # All `npm install <pkg>` commands will pin to the version
  # that was available at the time you run the command
  npm config set save-exact = true

  npm install -g "${packages[@]}"
}

print_step 'Installing NVM' && install_nvm
print_step 'Installing Node' && install_node
print_step 'Installing useful global NPM packages' && install_npm_packages
