#!/bin/bash

#
# This script configures my Node.js development setup. Note that
# nvm is installed by the Homebrew install script.

if test ! $(which nvm)
then
  curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

  export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  echo "Installing a stable version of Node..."

  # Install the latest stable version of node
  nvm install stable

  # Switch to the installed version
  nvm use node

  # Use the stable version of node by default
  nvm alias default node
fi

# All `npm install <pkg>` commands will pin to the version that was available at the time you run the command
npm config set save-exact = true

# Globally install with npm
packages=(
  diff-so-fancy
  git-recent
  git-open
  npm-check-updates
  nodemon
)

echo "Installing useful global Node packages: ${packages[@]}"
npm install -g "${packages[@]}"
